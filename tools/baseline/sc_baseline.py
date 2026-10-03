#!/usr/bin/env python3
"""Approved Q2A campaign CLI. Q1 is invoked as a subprocess and owns all suite verdicts."""
import argparse
import json
import os
import subprocess
import sys
import time
from decimal import Decimal
from pathlib import Path
from q2a import cjson, campaign, envinfo, ledger, extract, aggregate
from q2a.observer import Observer, targets, required_errors

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DEFINITION = HERE / 'q2a_campaign.json'


def definition():
    c = json.loads(DEFINITION.read_text(encoding='utf-8'))
    data = json.loads((REPO / 'tools/verify/suites.json').read_text(encoding='utf-8'))
    campaign.validate(c, data)
    return c, data


def outside(path):
    p = Path(path).resolve()
    if p == REPO or REPO in p.parents:
        raise ValueError('evidence root must be outside repository')
    return p


def boundary(c, freeze, godot, engine_sha):
    if campaign.git(REPO, 'rev-parse', 'HEAD') != freeze:
        raise ValueError('source revision change')
    if campaign.git(REPO, 'status', '--porcelain=v1', '--untracked-files=all'):
        raise ValueError('dirty repository at invocation boundary')
    frozen = json.loads(campaign.git(REPO, 'show', freeze + ':tools/baseline/q2a_campaign.json'))
    if cjson.digest(frozen) != cjson.digest(c) or cjson.digest(json.loads(DEFINITION.read_text(encoding='utf-8'))) != cjson.digest(c):
        raise ValueError('campaign digest mismatch')
    if cjson.sha(godot) != engine_sha:
        raise ValueError('Godot identity change')


def argv(inv, godot, runs):
    selection = ['--set', inv['set']] if inv.get('set') else ['--suite', ','.join(inv['suites'])]
    return [sys.executable, '-B', str(REPO / 'tools/verify/sc_verify.py'), 'run', *selection, '--godot', str(godot), '--output-root', str(runs)]


def invoke(inv, root, godot):
    runs = root / 'runs'
    runs.mkdir(exist_ok=True)
    before = {p.name for p in runs.iterdir()}
    cmd = argv(inv, godot, runs)
    obs = None
    (root / 'observer').mkdir(exist_ok=True)
    if inv['observer_mode'] == 'POLL-250ms':
        obs = Observer(0, 0, root / 'observer' / (inv['invocation_id'] + '.jsonl'), godot)
        if not callable(obs.start):
            raise TypeError('observer start is not callable; no subprocess launched')
    with (root / (inv['invocation_id'] + '.harness.stdout.log')).open('xb') as out, (root / (inv['invocation_id'] + '.harness.stderr.log')).open('xb') as err:
        start = time.time_ns() // 100 + 116444736000000000
        p = subprocess.Popen(cmd, cwd=REPO, stdout=out, stderr=err, stdin=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        startup_error = None
        if obs:
            obs.root, obs.invocation_start = p.pid, start
            try:
                obs.start()
            except Exception as exc:
                startup_error = {'reason': 'observer startup failed: ' + str(exc)}
        rc = p.wait()
        memory = ({'interval_ms': 250, 'processes': [], 'errors': [startup_error]} if startup_error else obs.finish()) if obs else None
    if memory is not None:
        cjson.write(root / 'observer' / (inv['invocation_id'] + '.summary.json'), memory)
    added = sorted({p.name for p in runs.iterdir()} - before)
    if len(added) != 1:
        raise ValueError('expected exactly one new Q1 directory, observed %d' % len(added))
    return added[0], rc, memory


def evidence_status(check, result, memory, repo=REPO):
    missing = [s for s in ['result.json', 'stdout.log', 'stderr.log', 'engine.log'] if not (check / s).is_file()]
    if missing:
        return 'PARTIAL', missing
    if memory is not None:
        own = targets(memory, result['process']['pid'])
        if required_errors(memory) or not own or not all(r['sample_count'] and r['exited'] and r.get('exit_100ns') and r['post_exit_query'] != 'NOT_QUERIED' for r in own):
            return 'INFRA_FAILED', ['P5_observer_failure']
    o = extract.extract(check)
    for m in o['manifests'] + o['identities']['RI-CAP']:
        for uri, expected in m.get('source_hashes', {}).items():
            p = repo / uri.removeprefix('res://')
            if not p.is_file() or cjson.sha(p) != expected:
                return 'PARTIAL', ['producer_source_digest_mismatch']
    return 'CAPTURED', []


def binding(a, inv, run_id, root, c, freeze, memory, retry_of=None):
    check = root / 'runs' / run_id / 'checks' / a['suite_id']
    r = cjson.load(check / 'result.json')
    status, problems = evidence_status(check, r, memory)
    return {'campaign_definition_digest': cjson.digest(c), 'campaign_freeze_revision': freeze, 'runtime_base_revision': campaign.BASE, 'invocation_id': inv['invocation_id'], 'attempt_ordinal': a['ordinal'], 'attempt_id': a['attempt_id'], 'row_id': a['row_id'], 'suite_id': a['suite_id'], 'round': a['round'], 'phase': inv['phase'], 'statistics_role': a['statistics_role'], 'required': a['required'], 'seed_config': campaign.seed_config(a['suite_id']), 'argv': r['command']['argv'], 'configuration': r['config']['launch'], 'observer_mode': inv['observer_mode'], 'engine_sha256': r['environment']['engine']['sha256'], 'q1_run_id': run_id, 'q1_check_relpath': check.relative_to(root).as_posix(), 'q1_result_json_sha256': cjson.sha(check / 'result.json'), 'q1_result': r['result'], 'q1_reason_code': r['reason_code'], 'q1_reasons': r['reasons'], 'retry_of': retry_of, 'directory_digest': cjson.digest(cjson.inventory(check)), 'evidence_status': status, 'evidence_problems': problems, 'exit_code': r['exit_code'], 'duration_ms': int(Decimal(r['duration']) * 1000), 'completion': r['completion_marker'], 'prerequisite_verdict': cjson.load(root / 'runs' / run_id / 'checks/session_diagnostics/result.json')['result'] if a['suite_id'] == 'replay_session' else None}


def retry_allowed(a, root):
    if a['q1_result'] == 'FAIL':
        return False
    if a['suite_id'] == 'replay_session':
        return False  # No identical same-invocation manifest prerequisite exists in a single-suite retry.
    reasons = set(a['q1_reasons'])
    forbidden = {'TIMEOUT', 'RUNNER_TIMEOUT', 'COMPLETION_NOT_PROVEN', 'COVERAGE_MISSING', 'SEED_NOT_CERTIFIED', 'UNKNOWN_ENGINE_MESSAGE', 'NONZERO_EXIT_UNEXPLAINED'}
    if reasons & forbidden or any(r.startswith('NEGATIVE_') for r in reasons):
        return False
    if a['evidence_problems'] == ['P5_observer_failure']:
        return True
    if reasons & {'ENGINE_UNAVAILABLE', 'LOG_INCOMPLETE', 'CONTAINMENT_UNVERIFIED', 'ORPHAN_PROCESS'} or any(r.startswith('HARNESS_') for r in reasons):
        return True
    if 'VULKAN_EVIDENCE_MISSING' in reasons:
        return not extract.extract(root / a['q1_check_relpath'])['vulkan_banner']
    return False


def calibration_report(root, runid, rc, memory, suites):
    rows = []
    for sid in suites:
        check = root / 'runs' / runid / 'checks' / sid
        r = cjson.load(check / 'result.json')
        o = extract.extract(check)
        rows.append({'suite_id': sid, 'q1_result': r['result'], 'q1_reason_code': r['reason_code'], 'q1_reasons': r['reasons'], 'duration': r['duration'], 'completion': r['completion_marker'], 'coverage': r['actual_coverage'], 'opening_count': len(o['identities']['RI-OPEN']), 'status': list(evidence_status(check, r, memory)), 'metrics': o['metrics']})
    return {'run_id': runid, 'exit_code': rc, 'rows': rows, 'memory': memory, 'excluded_from_baseline': True, 'raw_index': cjson.inventory(root, ['calibration_report.json'])}


def calibrate(args):
    c, data = definition()
    targeted = args.observer_validation
    root = outside(args.output_root) / (('observer-validation-' if targeted else 'calibration-') + cjson.utc().replace(':', '').replace('.', ''))
    root.mkdir(parents=True, exist_ok=False)
    inv = {'invocation_id': 'A2-OBSERVER-VALIDATION' if targeted else 'M2-CALIBRATION', 'suites': ['q2a_rider_s42', 'q2a_capture_s42'] if targeted else campaign.CALIBRATION, 'observer_mode': 'POLL-250ms', 'set': None}
    cjson.write(root / 'declaration.json', {'campaign_digest_before_calibration': cjson.digest(c), 'selection': inv, 'excluded_from_baseline': True, 'argv': argv(inv, args.godot, root / 'runs')})
    runid, rc, memory = invoke(inv, root, args.godot)
    report = calibration_report(root, runid, rc, memory, inv['suites'])
    cjson.write(root / 'calibration_report.json', report)
    print('calibration_root=' + str(root), flush=True)
    for r in report['rows']:
        print(r['suite_id'], r['q1_result'], r['q1_reason_code'], 'duration=' + r['duration'], 'opening_count=' + '%d' % r['opening_count'], flush=True)
    return 0


def run(args):
    c, data = definition()
    freeze = args.freeze
    engine_sha = cjson.sha(args.godot)
    boundary(c, freeze, args.godot, engine_sha)
    proof = campaign.proof(REPO, freeze)
    receipt_identity = campaign.validate_receipt(REPO, outside(args.freeze_receipt), freeze, cjson.digest(c))
    root = outside(args.output_root) / ('Q2A-' + freeze[:12] + '-' + cjson.utc().replace(':', '').replace('.', ''))
    root.mkdir(parents=True, exist_ok=False)
    (root / 'campaign').mkdir()
    cjson.write(root / 'campaign/definition.json', c)
    (root / receipt_identity['relpath']).write_bytes(Path(args.freeze_receipt).read_bytes())
    cjson.write(root / 'env/pre.json', envinfo.collect(args.godot, root))
    log = ledger.Ledger(root / 'ledger.jsonl', cjson.digest(c))
    log.append('CAMPAIGN_START', baseline_id=root.name, campaign_definition_digest=cjson.digest(c), campaign_freeze_revision=freeze, runtime_base_revision=campaign.BASE, engine_sha256=engine_sha, runtime_identity_proof=proof, freeze_receipt=receipt_identity, environment={'evidence_root_locator': str(root)})
    print('external_evidence_root=' + str(root), flush=True)
    try:
        for cmd in [[sys.executable, '-B', str(REPO / 'tools/verify/sc_verify.py'), s] for s in ['selftest', 'check-manifest']] + [[sys.executable, '-B', str(__file__), 'selftest']]:
            p = subprocess.run(cmd, capture_output=True)
            log.append('PREFLIGHT', argv=cmd, exit_code=p.returncode, stdout=p.stdout.decode('utf-8', 'replace'), stderr=p.stderr.decode('utf-8', 'replace'))
            if p.returncode:
                raise ValueError('preflight failed')
        retry_n, infra_streak, refs = 189, 0, []
        for inv in c['invocations']:
            boundary(c, freeze, args.godot, engine_sha)
            log.append('INVOCATION_START', invocation_id=inv['invocation_id'], argv=argv(inv, args.godot, root / 'runs'), observer_mode=inv['observer_mode'])
            runid, rc, memory = invoke(inv, root, args.godot)
            rows = [binding(a, inv, runid, root, c, freeze, memory) for a in c['attempts'] if a['invocation_id'] == inv['invocation_id']]
            log.append('INVOCATION_END', invocation_id=inv['invocation_id'], argv=argv(inv, args.godot, root / 'runs'), q1_run_id=runid, harness_exit_code=rc, attempts=rows)
            refs.extend(rows)
            print(inv['invocation_id'], runid, 'Q1=' + '%d' % rc, flush=True)
            boundary(c, freeze, args.godot, engine_sha)
            ledger.read(root / 'ledger.jsonl', cjson.digest(c))
            if inv['phase'] == 'P1' and not cjson.load(root / 'runs' / runid / 'run.json')['probe_matrix']['expectations_met']:
                raise ValueError('probe expectations not met')
            infra_streak = infra_streak + 1 if any(a['evidence_status'] != 'CAPTURED' for a in rows) or rc == 3 else 0
            if infra_streak >= 3:
                raise ValueError('three consecutive infrastructure-failed invocations')
            for a in rows:
                if a['required'] and (a['q1_result'] == 'INCOMPLETE' or a['evidence_status'] != 'CAPTURED') and retry_allowed(a, root):
                    ri = {**inv, 'invocation_id': 'RETRY-%d' % retry_n, 'set': None, 'suites': [a['suite_id']]}
                    ra = {**next(p for p in c['attempts'] if p['ordinal'] == a['attempt_ordinal']), 'ordinal': retry_n, 'attempt_id': 'Q2A-%03d' % retry_n}
                    boundary(c, freeze, args.godot, engine_sha)
                    log.append('REATTEMPT_START', invocation_id=ri['invocation_id'], retry_of=a['attempt_ordinal'], argv=argv(ri, args.godot, root / 'runs'))
                    rid, rrc, mem = invoke(ri, root, args.godot)
                    retry = binding(ra, ri, rid, root, c, freeze, mem, a['attempt_ordinal'])
                    log.append('INVOCATION_END', invocation_id=ri['invocation_id'], argv=argv(ri, args.godot, root / 'runs'), q1_run_id=rid, harness_exit_code=rrc, attempts=[retry])
                    refs.append(retry)
                    retry_n += 1
                    boundary(c, freeze, args.godot, engine_sha)
            status, gaps = aggregate.gap_status(refs)
            if gaps:
                log.append('GAP_DECISION_REQUESTED', status=status, ordinals=gaps)
                cjson.write(root / 'env/post.json', envinfo.collect(args.godot, root))
                aggregate.aggregate(root, c, True)
                print(status, gaps, flush=True)
                return 2
        cjson.write(root / 'env/post.json', envinfo.collect(args.godot, root))
        log.append('CAMPAIGN_END', declared_attempts=188, executed_attempts=len(refs))
        aggregate.aggregate(root, c)
        print('campaign evidence captured; durable index and VERIFY remain', flush=True)
        return 0
    except Exception as exc:
        log.append('HARD_STOP', status='INVALID', reason=type(exc).__name__ + ': ' + str(exc))
        print('INVALID; evidence preserved at ' + str(root) + '; ' + str(exc), flush=True)
        return 3


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest='command', required=True)
    for cmd in ['env', 'freeze-check', 'calibrate', 'run', 'aggregate', 'reconcile', 'selftest']:
        p = sp.add_parser(cmd)
        if cmd in ['env', 'calibrate', 'run']:
            p.add_argument('--godot', required=True)
            p.add_argument('--output-root', required=True)
        if cmd == 'calibrate':
            p.add_argument('--observer-validation', action='store_true', help='A2 exact two-suite validation; not another full M2')
        if cmd == 'run':
            p.add_argument('--freeze-receipt', required=True)
        if cmd in ['run', 'freeze-check']:
            p.add_argument('--freeze', default='HEAD')
        if cmd == 'freeze-check':
            p.add_argument('--working', action='store_true')
        if cmd in ['aggregate', 'reconcile']:
            p.add_argument('--root', required=True)
            p.add_argument('--partial', action='store_true')
    args = ap.parse_args()
    if args.command == 'selftest':
        import unittest
        suite = unittest.defaultTestLoader.discover(str(HERE / 'selftest'))
        return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
    if args.command == 'env':
        print(cjson.canonical(envinfo.collect(args.godot, outside(args.output_root))).decode('ascii'))
        return 0
    if args.command == 'calibrate':
        return calibrate(args)
    if args.command == 'run':
        return run(args)
    c, data = definition()
    if args.command == 'freeze-check':
        print(cjson.canonical({'proof': campaign.proof(REPO, args.freeze, args.working), 'campaign_definition_digest': cjson.digest(c), 'invocations': len(c['invocations']), 'attempts': len(c['attempts'])}).decode('ascii'))
    elif args.command == 'reconcile':
        r = aggregate.reconcile(args.root, c, args.partial)
        print(cjson.canonical({k: v for k, v in r.items() if k not in ['refs', 'records']}).decode('ascii'))
    else:
        b = aggregate.aggregate(args.root, c, args.partial)
        print(b['overall_baseline_status'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
