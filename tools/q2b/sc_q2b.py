#!/usr/bin/env python3
"""Q2B diagnostic facts and execution only; no suite verdict engine."""
import argparse
import collections
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / 'tools/verify'))
from harness.process import run_bounded, utc_now
from harness.evidence import LEAK
from harness.identity import source_identity, engine_identity

WARNING = re.compile(r'^WARNING: (\d+) ObjectDB instances? (?:was|were) leaked at exit', re.M)
INSTANCE = re.compile(r'^Leaked instance: ([^:\s]+):(-?\d+)(.*)$', re.M)
OWNED = re.compile(r'^Q2B_OWNED cycle=(\d+) group=(\S+) role=(\S+) class=(\S+) id=(\d+) playing=(\S+)$', re.M)
EXPECTED_ENGINE = '2445d009a5e0474fc7064b9767100e9d2c09521890ac5625476bfb81cf03f2d4'
LIMITATION = 'Non-verbose count compatibility infers semantic membership from D1; a different-class leak with the same count cannot be excluded.'

def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for part in iter(lambda: f.read(1048576), b''): h.update(part)
    return h.hexdigest()

def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()

def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(obj, indent=2, sort_keys=True) + '\n')

def read(path):
    return path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''

def engine_object_paths(extra):
    """Only explicitly emitted path fields; never infer from references or owners."""
    pattern = r'(?:^\s*(?:-\s+)?|\s+-\s+)(Node path|Resource path):\s*(.*?)(?=\s+-\s+(?:Reference count|Node path|Resource path):|$)'
    return [{'kind': kind, 'value': value.strip()} for kind, value in re.findall(pattern, extra) if value.strip()]

def normalise_tree(entries, owned, cycle, live_chunks):
    """Identify the unique streamer by recorded composition/ownership, not its name."""
    tree = dict(item.rsplit('|', 1) for item in entries)
    if len(tree) != len(entries): raise ValueError('FROZEN_TREE_EVIDENCE_INSUFFICIENT: duplicate paths')
    roles = [o for o in owned if o['cycle'] == cycle and o['group'] == 'T-WORLD']
    managers = [o for o in roles if o['role'] == 'WorldManager']
    streamers = [o for o in roles if o['role'] == 'ChunkStreamer']
    chunks = [o for o in roles if o['role'] == 'RoadChunk']
    if len(managers) != 1 or len(streamers) != 1 or tree.get('WorldManager') != managers[0]['class']:
        raise ValueError('FROZEN_TREE_EVIDENCE_INSUFFICIENT: owner-role evidence')
    candidates = [p for p, cl in tree.items() if '/' in p and p.rsplit('/', 1)[0] == 'WorldManager' and cl == streamers[0]['class']]
    if len(candidates) != 1: raise ValueError('FROZEN_TREE_EVIDENCE_INSUFFICIENT: ambiguous direct owned child')
    streamer = candidates[0]
    children = [p for p in tree if '/' in p and p.rsplit('/', 1)[0] == streamer]
    if live_chunks < 1 or len(children) != live_chunks or len(chunks) < live_chunks or any(not re.fullmatch(r'Chunk_\d+', p.rsplit('/', 1)[1]) or tree[p] not in {o['class'] for o in chunks} for p in children):
        raise ValueError('FROZEN_TREE_EVIDENCE_INSUFFICIENT: RoadChunk composition witness')
    excluded = [p for p in tree if p.startswith(streamer + '/')]
    canonical_streamer = 'WorldManager/ChunkStreamer'
    if canonical_streamer in tree and canonical_streamer != streamer: raise ValueError('FROZEN_TREE_EVIDENCE_INSUFFICIENT: canonical role collision')
    normalised = sorted((canonical_streamer if p == streamer else p) + '|' + cl for p, cl in tree.items() if p not in excluded)
    return {'streamer_raw_path': streamer, 'canonical_streamer_role': canonical_streamer,
            'identity_basis': 'unique direct WorldManager child matching recorded ChunkStreamer class; same-cycle owner roles and live RoadChunk composition corroborate',
            'direct_candidates': candidates, 'live_chunks': live_chunks, 'observed_chunk_ids': len(chunks),
            'excluded_descendants': sorted(excluded), 'normalised_entries': normalised,
            'digest': hashlib.sha256('\n'.join(normalised).encode()).hexdigest()}

def facts(directory):
    channels = {name: read(directory / (name + '.log')) for name in ('stdout', 'stderr', 'engine')}
    text = channels['stdout'] + '\n' + channels['stderr']
    return {'warning_counts': [int(n) for n in WARNING.findall(text)],
            'instances': [{'class': c, 'id': int(i) % (1 << 64), 'path_extra': extra.strip(), 'engine_emitted_paths': engine_object_paths(extra)} for c, i, extra in INSTANCE.findall(text)],
            'owned': [{'cycle': int(c), 'group': g, 'role': r, 'class': cl, 'id': int(i), 'playing': p} for c, g, r, cl, i, p in OWNED.findall(text)],
            'probe_lines': [line for line in text.splitlines() if line.startswith('Q2B_')],
            'leak_lines': [line for line in text.splitlines() if LEAK.search(line)],
            'script_errors': [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or 'Parse Error:' in line],
            'channel_counts': {name: {'warnings': len(WARNING.findall(body)), 'instances': len(INSTANCE.findall(body))} for name, body in channels.items()}}

def ledger(root, kind, payload):
    path = root / 'ledger.jsonl'
    rows = [json.loads(line) for line in read(path).splitlines()]
    previous = rows[-1]['sha256'] if rows else '0' * 64
    row = {'sequence': len(rows) + 1, 'utc': utc_now(), 'previous': previous, 'kind': kind, 'payload': payload}
    row['sha256'] = hashlib.sha256(canonical(row)).hexdigest()
    with path.open('a', encoding='utf-8', newline='\n') as f: f.write(json.dumps(row, sort_keys=True) + '\n')

def fisher(a, n, b, m):
    total = a + b
    return sum(math.comb(n, x) * math.comb(m, total-x) for x in range(a, min(n, total)+1)
               if 0 <= total-x <= m) / math.comb(n+m, total)

def binomial_tail(x, n, p):
    return sum(math.comb(n, i) * p**i * (1-p)**(n-i) for i in range(x, n+1))

def invert_tail(x, n, probability):
    lo, hi = 0.0, 1.0
    for _ in range(80):
        mid = (lo+hi)/2
        if binomial_tail(x, n, mid) < probability: lo = mid
        else: hi = mid
    return (lo+hi)/2

def interval(x, n):
    if not n: return None
    return [0.0 if x == 0 else invert_tail(x, n, .025),
            1.0 if x == n else invert_tail(x+1, n, .975)]

def derive(records):
    groups = {}
    for rec in records:
        if rec['block'] != 'D1-P' or rec['arm'] != 'NORMAL': continue
        f = rec['facts']
        if len(f['warning_counts']) != 1 or len(f['instances']) != f['warning_counts'][0]: continue
        local = {o['id']: o for o in f['owned']}
        if not all(i['id'] in local and i['class'] == local[i['id']]['class'] for i in f['instances']): continue
        relation = sorted((i['class'], local[i['id']]['group'], local[i['id']]['role']) for i in f['instances'])
        key = json.dumps(relation)
        group = groups.setdefault(key, {'classes': dict(collections.Counter(i['class'] for i in f['instances'])),
                   'owner_relation': relation, 'object_paths': sorted(p['value'] for i in f['instances'] for p in engine_object_paths(i['path_extra'])),
                   'engine_object_path_status': 'OBSERVED' if any(engine_object_paths(i['path_extra']) for i in f['instances']) else 'NOT_OBSERVED',
                   'creation_path': [], 'teardown_path': 'scene.free -> BikeAudioManager._exit_tree -> immediate quit',
                   'per_owner_unit': None, 'nominal_counts': [], 'source_ordinals': []})
        for _, g, role in relation:
            player = role.split('.')[0]
            creators = {'WindPlayer': '_create_wind_audio_stream', 'GravelPlayer': '_create_gravel_audio_stream',
                        'SkidPlayer': '_create_skid_audio_stream', 'BellPlayer': '_create_bell_audio_stream',
                        'FreewheelPlayerA': '_create_click_audio_stream', 'FreewheelPlayerB': '_create_click_audio_stream'}
            if g == 'T-AUDIO' and player in creators:
                source = 'scripts/audio/bike_audio_manager.gd:_ready -> ' + creators[player]
                if 'get_stream_playback' in role: source += ' -> autoplay AudioServer playback'
            else: source = 'UNRESOLVED:' + role
            if source not in group['creation_path']: group['creation_path'].append(source)
        owners = {local[i['id']]['role'].split('.')[0] for i in f['instances']}
        group['per_owner_unit'] = len(f['instances']) / len(owners)
        group['nominal_counts'] = sorted(set(group['nominal_counts'] + f['warning_counts']))
        group['source_ordinals'].append(rec['ordinal'])
    signatures = list(groups.values())
    return {'frozen_utc': utc_now(), 'k': len(signatures), 'adjusted_alpha': .01/len(signatures) if signatures else None,
            'signatures': signatures, 'limitation': LIMITATION, 'basis': 'D1-P NORMAL fully same-process attributed instances only'}

def aggregate(records, frozen):
    output = {'limitation': LIMITATION, 'attempts_recorded': len(records), 'signatures': [],
              'discovery': [r['ordinal'] for r in records if r['block'].startswith('D1')],
              'harness_validation': [r['ordinal'] for r in records if r['block'] == 'D2-R'],
              'multi_cycle': [r for r in records if r['block'] == 'D3']}
    for signature in frozen['signatures']:
        arms = {}
        for arm in ('NORMAL', 'AUDIO_REMOVED', 'WAIT'):
            selected = [r for r in records if r['block'] == 'D2-I' and r['arm'] == arm]
            valid = [r for r in selected if not r['infra']]
            target = sum(any(c in signature['nominal_counts'] for c in r['facts']['warning_counts']) for r in valid)
            any_warning = sum(bool(r['facts']['warning_counts']) for r in valid)
            arms[arm] = {'n': len(valid), 'target': target, 'any_warning': any_warning,
                         'none': len(valid)-any_warning, 'infra': len(selected)-len(valid),
                         'non_target': dict(collections.Counter(str(c) for r in valid for c in r['facts']['warning_counts'] if c not in signature['nominal_counts'])),
                         'target_ci95': interval(target, len(valid)), 'any_warning_ci95': interval(any_warning, len(valid)),
                         'zero_one_sided_upper99': 1-.01**(1/len(valid)) if target == 0 and valid else None}
        n, a, w = (arms[key] for key in ('NORMAL', 'AUDIO_REMOVED', 'WAIT'))
        primary = fisher(n['target'], n['n'], a['target'], a['n']) if n['n'] and a['n'] else None
        secondary = fisher(n['target'], n['n'], w['target'], w['n']) if n['n'] and w['n'] else None
        output['signatures'].append({'signature': signature, 'arms': arms, 'primary_fisher_one_sided': primary,
            'secondary_fisher_one_sided': secondary, 'adjusted_alpha': frozen['adjusted_alpha'],
            'primary_criteria_met': n['n'] == a['n'] == 30 and n['target'] >= 7 and a['target'] == 0 and primary <= frozen['adjusted_alpha']})
    return output

def retain(root):
    files = sorted(p for p in root.rglob('*') if p.is_file() and p.name != 'SHA256SUMS')
    with (root / 'SHA256SUMS').open('x', encoding='utf-8', newline='\n') as f:
        for p in files: f.write(sha(p) + '  ' + p.relative_to(root).as_posix() + '\n')

def checksums(root):
    mismatch = []
    for line in read(root / 'SHA256SUMS').splitlines():
        expected, rel = line.split('  ', 1)
        path = root / rel
        if not path.is_file() or sha(path) != expected: mismatch.append(rel)
    return mismatch

def execute(root, row, godot, replay):
    directory = root / 'attempts' / ('%03d-%s-%s' % (row['ordinal'], row['block'], row['arm']))
    directory.mkdir(parents=True, exist_ok=False)
    for sub in ('diag', 'audit'): (directory / sub).mkdir()
    argv = [godot, '--headless'] + (['--verbose'] if row['verbose'] else [])
    argv += ['--path', str(REPO), '--log-file', str(directory/'engine.log'), '--script', row['entry'], '--']
    argv += row['args'] + ['--diagnostics-root='+str(directory/'diag'), '--audit-output-root='+str(directory/'audit')]
    if row['block'] == 'D1-R': argv += ['--replay-manifest='+str(replay)]
    proc = run_bounded(argv, REPO, directory/'stdout.log', directory/'stderr.log', row['timeout_s'])
    f = facts(directory)
    infra = bool(not proc['spawned'] or proc['timed_out'] or proc['spawn_error'] or proc['post_exit_orphans'] or proc['exit_code'] != 0)
    if row['entry'].endswith('q2b_lifecycle_probe.gd'):
        infra = infra or bool(f['script_errors']) or not any(l.startswith('Q2B_PROBE_COMPLETE') for l in f['probe_lines'])
    rec = dict(row, proc=proc, infra=infra, facts=f, path=directory.relative_to(root).as_posix())
    write(directory/'record.json', rec)
    ledger(root, 'attempt', {'ordinal': row['ordinal'], 'path': rec['path']+'/record.json', 'sha256': sha(directory/'record.json')})
    print('attempt=%d block=%s arm=%s warning_counts=%s infra=%s' % (row['ordinal'], row['block'], row['arm'], f['warning_counts'], infra), flush=True)
    return rec

def q1_pair(root, pair, godot):
    ordinal = pair[0]['ordinal']
    directory = root / 'q1' / ('pair-%03d' % ordinal)
    directory.mkdir(parents=True, exist_ok=False)
    argv = [sys.executable, '-B', str(REPO/'tools/verify/sc_verify.py'), 'run', '--suite', 'session_diagnostics,replay_session', '--godot', godot, '--output-root', str(directory)]
    envelope = run_bounded(argv, REPO, directory/'harness.stdout.log', directory/'harness.stderr.log', 510)
    write(directory/'envelope.json', envelope)
    records = []
    for row, suite in zip(pair, ('session_diagnostics', 'replay_session')):
        matches = list(directory.glob('*/checks/'+suite+'/result.json'))
        if len(matches) != 1: raise RuntimeError('STOP-INFRA missing Q1 result at ordinal '+str(row['ordinal']))
        source = matches[0].parent
        attempt = root/'attempts'/('%03d-D2-R-%s' % (row['ordinal'], row['arm']))
        attempt.mkdir(parents=True, exist_ok=False)
        import shutil
        for name in ('stdout.log', 'stderr.log', 'engine.log', 'result.json'): shutil.copyfile(source/name, attempt/name)
        result = json.loads(read(source/'result.json'))
        rec = dict(row, facts=facts(attempt), path=attempt.relative_to(root).as_posix(), q1_result=result,
                   q1_source=source.relative_to(root).as_posix(), infra=result['result'] == 'INCOMPLETE')
        write(attempt/'record.json', rec)
        ledger(root, 'attempt', {'ordinal': row['ordinal'], 'path': rec['path']+'/record.json', 'sha256': sha(attempt/'record.json')})
        records.append(rec)
        print('attempt=%d block=D2-R raw_warning_counts=%s' % (row['ordinal'], rec['facts']['warning_counts']), flush=True)
    return records

def campaign(args):
    root = Path(args.root).resolve()
    root.mkdir(parents=True, exist_ok=False)
    matrix = json.loads(read(HERE/'q2b_matrix.json'))
    write(root/'matrix.json', matrix)
    import shutil
    shutil.copyfile(args.approved_plan, root/'approved_plan_v1.1.md')
    shutil.copyfile(args.approval, root/'human_G0_approval.txt')
    shutil.copyfile(args.preflight, root/'preflight_receipt.json')
    env = {'utc': utc_now(), 'platform': platform.platform(), 'python': sys.version, 'engine': engine_identity(args.godot), 'source': source_identity(REPO), 'matrix_sha256': sha(HERE/'q2b_matrix.json'), 'observer': 'off'}
    write(root/'env.json', env)
    ledger(root, 'preflight', {'env_sha256': sha(root/'env.json'), 'matrix_sha256': sha(root/'matrix.json')})
    records, frozen, replay, stop = [], None, None, None
    try:
        if env['engine']['sha256'] != EXPECTED_ENGINE: raise RuntimeError('STOP-PRE engine identity')
        for row in matrix['attempts']:
            if row['block'] == 'D2-R':
                if row['ordinal'] % 2 == 1: continue
                records.extend(q1_pair(root, matrix['attempts'][row['ordinal']-1:row['ordinal']+1], args.godot))
                continue
            rec = execute(root, row, args.godot, replay)
            records.append(rec)
            if rec['facts']['script_errors'] and row['entry'].endswith('q2b_lifecycle_probe.gd'): raise RuntimeError('STOP-INFRA probe parse/script error')
            if row['ordinal'] == 21:
                manifests = sorted((root/rec['path']/'diag').glob('*/manifest.json'))
                if not manifests: raise RuntimeError('STOP-INFRA session producer missing manifest')
                replay = manifests[0]
            if row['ordinal'] == 37:
                frozen = derive(records)
                write(root/'aggregate/target_signature.json', frozen)
                ledger(root, 'signature_freeze', {'path': 'aggregate/target_signature.json', 'sha256': sha(root/'aggregate/target_signature.json'), 'k': frozen['k']})
                if not frozen['k']: raise RuntimeError('DIAGNOSIS_INSUFFICIENT_FOR_INTERVENTION')
            if row['block'] == 'D2-I':
                for arm in ('NORMAL', 'AUDIO_REMOVED', 'WAIT'):
                    if sum(r['infra'] for r in records if r['block'] == 'D2-I' and r['arm'] == arm) > 3: raise RuntimeError('STOP-INFRA arm exceeds 10 percent of declared 30')
    except Exception as exc:
        stop = str(exc)
        print('STOP: '+stop, flush=True)
    if frozen is None: frozen = {'signatures': [], 'k': 0, 'adjusted_alpha': None}
    write(root/'aggregate/observations.json', aggregate(records, frozen))
    write(root/'aggregate/execution_status.json', {'stop': stop, 'attempts_recorded': len(records), 'declared': 150, 'retries': 0})
    ledger(root, 'execution_end', {'stop': stop, 'attempts_recorded': len(records)})
    retain(root)
    return 2 if stop else 0

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    run = sub.add_parser('run'); run.add_argument('--root', required=True); run.add_argument('--godot', required=True)
    run.add_argument('--approved-plan', required=True); run.add_argument('--approval', required=True); run.add_argument('--preflight', required=True)
    sub.add_parser('selftest')
    args = parser.parse_args()
    if args.command == 'selftest':
        import unittest
        return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.discover(str(HERE/'selftest'))).wasSuccessful() else 1
    return campaign(args)

if __name__ == '__main__': sys.exit(main())
