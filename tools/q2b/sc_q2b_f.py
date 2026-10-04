#!/usr/bin/env python3
"""Approved Q2B F1 diagnostic execution/facts; Q1 retains verdict ownership."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sc_q2b as q
SETTLE = re.compile(r'^SC_TEARDOWN_SETTLE requested_ms=(\d+) elapsed_ms=(\d+) frames=(\d+) exit_code=(-?\d+)$', re.M)
SOURCE = ('scripts/test/teardown_settle_support.gd', 'scripts/test/q2b/q2b_lifecycle_probe.gd', 'scripts/test/test_virtual_rider_bot.gd', 'scripts/test/replay_session_diagnostic.gd', 'tools/q2b/sc_q2b_f.py', 'tools/q2b/q2b_stage_f_matrix.json')

def inspect(directory):
    f = q.facts(directory)
    f['settle'] = [dict(zip(('requested_ms','elapsed_ms','frames','exit_code'), map(int, m))) for m in SETTLE.findall(q.read(directory/'stdout.log'))]
    return f

def fidelity(rec):
    lines = rec['facts']['probe_lines']
    trees = [l for l in lines if l.startswith('Q2B_TREE ')]
    streams = [l for l in lines if l.startswith('Q2B_STREAM ')]
    if len(trees) != 1 or len(streams) != 1: raise RuntimeError('STOP-SANITY tree/stream count')
    entries = json.loads(trees[0].split(' entries=',1)[1])
    digest = trees[0].split(' digest=',1)[1].split()[0]
    if entries.count('WorldManager/ChunkStreamer|Node3D') != 1 or any(e.startswith('WorldManager/ChunkStreamer/') for e in entries): raise RuntimeError('STOP-SANITY A1 topology')
    if q.hashlib.sha256('\n'.join(entries).encode()).hexdigest() != digest: raise RuntimeError('STOP-SANITY tree digest')
    owned = [o for o in rec['facts']['owned'] if o['group']=='T-AUDIO']
    if sum(o['class']=='AudioStreamPlayer3D' for o in owned)!=6 or sum(o['class']=='AudioStreamWAV' for o in owned)!=6: raise RuntimeError('STOP-SANITY audio population')
    for role in ('WindPlayer','GravelPlayer','SkidPlayer'):
        for suffix in ('','.stream','.get_stream_playback()'):
            if not any(o['role']==role+suffix and o['playing']=='true' for o in owned): raise RuntimeError('STOP-SANITY live playback')
    return (digest, streams[0])

def validate(rec):
    f, p, row = rec['facts'], rec['proc'], rec
    if not p['spawned'] or p['timed_out'] or p['spawn_error'] or p['post_exit_orphans']: raise RuntimeError('STOP-INFRA STAGE_F_INCOMPLETE / HUMAN_DECISION_REQUIRED')
    if f['script_errors']: raise RuntimeError('STOP-E0/SANITY script error / HUMAN_DECISION_REQUIRED')
    if row['block']=='F-E0':
        if p['exit_code']!=0: raise RuntimeError('STOP-E0 parse / HUMAN_DECISION_REQUIRED')
        return
    probe = row['block'] in ('F-SAN','F-C')
    if probe:
        if p['exit_code']!=0 or 'Q2B_PROBE_COMPLETE cycles=1' not in f['probe_lines']: raise RuntimeError('STOP-SANITY probe completion / HUMAN_DECISION_REQUIRED')
        fidelity(rec)
    modified = row['arm']=='FIXED_SETTLED_QUIT' or row['suite'] in ('verbose_replay','virtual_rider','replay_session','neg_replay_no_manifest')
    if modified:
        if len(f['settle'])!=1: raise RuntimeError('STOP-SETTLE-BOUND missing/duplicate')
        s = f['settle'][0]
        if s['requested_ms']!=250 or not 250<=s['elapsed_ms']<=500 or s['frames']<1 or s['exit_code']!=p['exit_code']: raise RuntimeError('STOP-SETTLE-BOUND evidence')
        if f['leak_lines'] or f['instances']: raise RuntimeError('STOP-RESIDUAL FAIL / HUMAN_DECISION_REQUIRED')
    if probe and row['arm']=='LEGACY_IMMEDIATE_QUIT':
        if f['settle'] or 'Q2B_SETTLE cycle=1 requested_ms=0 elapsed_ms=0 frames=0' not in f['probe_lines']: raise RuntimeError('STOP-SANITY legacy teardown')
    if row['suite']=='verbose_replay':
        text = q.read(Path(rec['absolute_path'])/'stdout.log')
        if p['exit_code']!=0 or not re.search(r'^REPLAY_DIAGNOSTIC_SUMMARY status=PASS reason= checkpoints=3 choices=1$',text,re.M): raise RuntimeError('STOP-BEHAVIOR verbose replay')
        if re.search(r'^WARNING:',q.read(Path(rec['absolute_path'])/'stderr.log'),re.M): raise RuntimeError('STOP-RESIDUAL verbose warning')
    if 'q1_result' in rec:
        r = rec['q1_result']
        if r['result']=='INCOMPLETE': raise RuntimeError('STOP-INFRA Q1 INCOMPLETE / HUMAN_DECISION_REQUIRED')
        if row['suite']!='session_diagnostics' and (r['result'],r['reason_code'])!=('PASS','ALL_REQUIRED_EVIDENCE_SATISFIED'): raise RuntimeError('STOP-BEHAVIOR Q1 verdict')
        if row['suite']=='virtual_rider' and r['measurements'].get('actual_progress')!=355.9: raise RuntimeError('STOP-BEHAVIOR rider distance')
        if row['suite']=='neg_replay_no_manifest' and (r['negative']['reported_reason']!='MANIFEST_MISSING' or not r['negative']['reason_found'] or r['exit_code']!=1): raise RuntimeError('STOP-BEHAVIOR negative semantics')

def save(root,row,directory,proc,source=None):
    rec = dict(row,proc=proc,facts=inspect(directory),path=directory.relative_to(root).as_posix(),absolute_path=str(directory))
    if source:
        rec.update(q1_result=json.loads(q.read(source/'result.json')),q1_source=source.relative_to(root).as_posix())
    q.write(directory/'record.json',rec)
    q.ledger(root,'attempt',{'ordinal':row['ordinal'],'path':rec['path']+'/record.json','sha256':q.sha(directory/'record.json')})
    print('attempt=%d block=%s arm=%s warnings=%s' % (row['ordinal'],row['block'],row['arm'],rec['facts']['warning_counts']),flush=True)
    return rec

def execute(root,row,godot,replay):
    d=root/'attempts'/('%03d-%s-%s'%(row['ordinal'],row['block'],row['arm'])); d.mkdir(parents=True)
    for sub in ('diag','audit'): (d/sub).mkdir()
    argv=[godot,'--headless']+(['--verbose'] if row['verbose'] else [])+(['--check-only'] if row['block']=='F-E0' else [])
    argv+=['--path',str(q.REPO),'--log-file',str(d/'engine.log'),'--script',row['entry'],'--']+row['args']
    argv+=['--diagnostics-root='+str(d/'diag'),'--audit-output-root='+str(d/'audit')]
    if row['block']=='F-RV': argv+=['--replay-manifest='+str(replay)]
    return save(root,row,d,q.run_bounded(argv,q.REPO,d/'stdout.log',d/'stderr.log',row['timeout_s']))

def q1_group(root,rows,godot):
    d=root/'q1'/('group-%03d'%rows[0]['ordinal']); d.mkdir(parents=True)
    argv=[sys.executable,'-B',str(q.REPO/'tools/verify/sc_verify.py'),'run','--suite',','.join(r['suite'] for r in rows),'--godot',godot,'--output-root',str(d)]
    envelope=q.run_bounded(argv,q.REPO,d/'harness.stdout.log',d/'harness.stderr.log',sum(r['timeout_s'] for r in rows)+120)
    q.write(d/'envelope.json',envelope)
    records=[]
    for row in rows:
        sources=list(d.glob('*/checks/'+row['suite']+'/result.json'))
        if len(sources)!=1: raise RuntimeError('STOP-INFRA missing Q1 result ordinal '+str(row['ordinal']))
        s=sources[0].parent; a=root/'attempts'/('%03d-%s-%s'%(row['ordinal'],row['block'],row['arm'])); a.mkdir(parents=True)
        for name in ('stdout.log','stderr.log','engine.log','result.json'): shutil.copyfile(s/name,a/name)
        r=json.loads(q.read(s/'result.json'))
        p=dict(r['process'],timed_out=r['timeout']['timed_out'],exit_code=r['exit_code'])
        records.append(save(root,row,a,p,s))
    if envelope['timed_out'] or envelope['spawn_error'] or envelope['post_exit_orphans']: raise RuntimeError('STOP-INFRA Q1 envelope')
    return records

def observations(records):
    arms={}
    for arm in ('LEGACY_IMMEDIATE_QUIT','FIXED_SETTLED_QUIT'):
        rr=[r for r in records if r['block']=='F-C' and r['arm']==arm]; n=len(rr)
        x=sum(6 in r['facts']['warning_counts'] for r in rr)
        arms[arm]={'n':n,'target':x,'any_leak':sum(bool(r['facts']['leak_lines']) for r in rr),'cp95':q.interval(x,n),'one_sided_upper99':q.invert_tail(x+1,n,.99) if n and x<n else None}
    a,b=arms.values()
    return {'arms':arms,'fisher_one_sided':q.fisher(a['target'],a['n'],b['target'],b['n']) if a['n']==b['n']==30 else None,'nonverbose_limitation':q.LIMITATION,'q1_outcomes':[{'ordinal':r['ordinal'],'suite':r['suite'],'result':r['q1_result']['result'],'reason_code':r['q1_result']['reason_code']} for r in records if 'q1_result' in r]}

def campaign(args):
    root=Path(args.root).resolve(); root.mkdir(parents=True,exist_ok=False)
    matrix=json.loads(q.read(HERE/'q2b_stage_f_matrix.json')); q.write(root/'matrix.json',matrix)
    for src,name in ((args.approved_plan,'approved_plan_F1.md'),(args.approval,'human_F1_approval.txt'),(args.preflight,'preflight_receipt.json')): shutil.copyfile(src,root/name)
    for rel in SOURCE:
        d=root/'executed_source'/rel; d.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(q.REPO/rel,d)
    env={'engine':q.engine_identity(args.godot),'source':q.source_identity(q.REPO),'python':sys.version,'observer':'off','separate_processes':True,'matrix_sha256':q.sha(HERE/'q2b_stage_f_matrix.json')}; q.write(root/'env.json',env)
    q.ledger(root,'preflight',{'env_sha256':q.sha(root/'env.json'),'matrix_sha256':q.sha(root/'matrix.json'),'required_n':[30,30],'infra_tolerance':0,'retries':0})
    records=[]; stop=None; replay=None; i=0
    try:
        if env['engine']['sha256']!=q.EXPECTED_ENGINE: raise RuntimeError('STOP-PRE engine')
        while i<len(matrix['attempts']):
            row=matrix['attempts'][i]; group=matrix['attempts'][i:i+row.get('q1_group_size',1)]
            fresh=q1_group(root,group,args.godot) if row['block'] in ('F-Q','F-N') else [execute(root,row,args.godot,replay)]
            records.extend(fresh)
            for rec in fresh: validate(rec)
            if row['ordinal']==67:
                manifests=sorted((root/fresh[0]['path']/'diag').glob('*/manifest.json'))
                if not manifests: raise RuntimeError('STOP-INFRA producer manifest')
                replay=manifests[0]
            if row['block']=='F-C' and row['ordinal']%2==0 and fidelity(records[-1])!=fidelity(records[-2]): raise RuntimeError('STOP-SANITY pair fidelity')
            if row['ordinal']==66:
                o=observations(records); a,b=o['arms'].values()
                if a['n']!=30 or b['n']!=30: raise RuntimeError('STOP-INFRA exact n')
                if a['target']<7: raise RuntimeError('STOP-CONTROL-LOST INCONCLUSIVE / HUMAN_DECISION_REQUIRED')
                if o['fisher_one_sided']>.01: raise RuntimeError('STOP-CAUSAL FAIL / HUMAN_DECISION_REQUIRED')
            i+=len(fresh)
    except Exception as exc:
        stop=str(exc); print('STOP: '+stop,flush=True)
    q.write(root/'aggregate/observations.json',observations(records))
    q.write(root/'aggregate/execution_status.json',{'stop':stop,'attempts_recorded':len(records),'declared':120,'retries':0,'replacements':0,'unexecuted_ordinals':list(range(len(records)+1,121))})
    q.ledger(root,'execution_end',{'stop':stop,'attempts_recorded':len(records)}); q.retain(root)
    return 2 if stop else 0

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('command',choices=('run','selftest'))
    for flag in ('root','godot','approved-plan','approval','preflight'): p.add_argument('--'+flag)
    a=p.parse_args()
    if a.command=='selftest':
        import unittest
        return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.discover(str(HERE/'selftest'))).wasSuccessful() else 1
    if not all((a.root,a.godot,a.approved_plan,a.approval,a.preflight)): p.error('run requires all five paths')
    return campaign(a)

if __name__=='__main__': sys.exit(main())
