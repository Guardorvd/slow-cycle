"""Fixed Q2A v1.1 definition and Git freeze proof."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from . import cjson

BASE = '02b7b5816d488877181872ab3f04bf2f094bd0df'
S7 = [184729, 42, 77777, 351697566, 1027766269, 874341432, 9954360]
ROOTS = ['scripts'] + ['scripts/' + s for s in ['player', 'camera', 'world', 'core', 'test', 'ui', 'audio']] + [
    'scenes', 'assets', 'project.godot', 'default_bus_layout.tres', 'icon.svg',
    '.antigravity/rules/test-integrity.md', 'docs/TEST_MATRIX.md', 'AGENTS.md',
    'scripts/world/AGENTS.md', 'scripts/player/AGENTS.md', 'scripts/test/AGENTS.md']
DOM = ['q2a_world_session_seed', 'q2a_branch_streaming', 'q2a_terrain_carver',
       'q2a_road_grammar', 'q2a_road_contract', 'q2a_macro_profile']
RIDE = ['q2a_rider_s%d' % s for s in S7]
VIS = ['q2a_capture_s%d' % s for s in S7] + ['q2a_capture_seed_audit', 'q2a_surface_contract']
SOAK = ['q2a_soak_asis', 'q2a_soak_pin184729']
OBJ = ['virtual_rider', 'route_branch_integration', 'session_diagnostics', 'replay_session']
PERF = ['road_graph', 'q2a_terrain_carver', 'q2a_road_grammar', 'q2a_road_contract', 'q2a_branch_streaming']
MEM = ['virtual_rider', 'route_branch_integration', 'q2a_soak_pin184729', 'capture_visual_vulkan']
CALIBRATION = DOM + ['q2a_rider_s42', 'q2a_capture_s42', 'q2a_capture_seed_audit', 'q2a_surface_contract'] + SOAK
ARTIFACT_MODEL = {'approval': 'HUMAN AMENDMENT A1', 'payload_index': 'aggregate/artifact_index_full.txt', 'payload_excluded': ['aggregate/artifact_index_full.txt', 'SHA256SUMS', 'aggregate/baseline.json', 'aggregate/repository_artifact_index.txt'], 'artifact_root_digest': 'SHA256(raw bytes of payload index)', 'closure_index': 'repository artifact_index.txt; never hashes itself', 'closure_files': ['aggregate/artifact_index_full.txt', 'SHA256SUMS', 'aggregate/baseline.json'], 'freeze_receipt': 'campaign/freeze_receipt.json; canonical external receipt bound before CAMPAIGN_START'}


def git(repo, *args):
    p = subprocess.run(['git', '-C', str(repo), *args], capture_output=True)
    if p.returncode:
        raise RuntimeError('Git failed: ' + p.stderr.decode('utf-8', 'replace'))
    return p.stdout.decode('utf-8').strip()


def seeded(spec, sid, seed, timeout):
    s = copy.deepcopy(spec)
    s['id'] = sid
    s['launch'].update(timeout_s=timeout, user_args=['--seed=%d' % seed])
    s['seeds'] = {'requested': [seed], 'observed': {'glob': 'diag/*/manifest.json', 'field': 'effective_seed'}, 'require_observed': True}
    s['seed_policy'] = 'CLI certified; header labels are not effective-seed evidence'
    return s


def additions(data, matrix_text):
    by = {s['id']: s for s in data['suites']}
    categories = dict(re.findall(r'^\|\s*([A-Z][A-Za-z0-9_-]*)\s+·\s+L\d+\s*\|\s*([A-Z_]+)', matrix_text, re.M))
    out = [seeded(by['virtual_rider'], 'q2a_rider_s%d' % n, n, 240) for n in S7]
    for n in S7:
        s = seeded(by['capture_visual_vulkan'], 'q2a_capture_s%d' % n, n, 180)
        s['coverage'][1]['id'] = 'captured_seed_%d_frames_8' % n
        s['coverage'][1]['pattern'] = r'^\[CAPTURED\] seed=%d s=([\d.]+) camera=(\w+)' % n
        s['coverage'][1]['basis'] = 'effective CLI seed from per-frame output'
        out.append(s)
    specs = [
        ('capture_seed_audit', 'capture_seed_audit.gd', ['CAP-SEED'], 'vulkan', 180, r'^AUDIT_COMPLETE status=CAPTURE_COMPLETE reason= frames=9/9 ', None),
        ('surface_contract', 'test_surface_audit_contract.gd', ['SURFACE-NEG', 'SURFACE-LIVE'], 'vulkan', 180, r'^SURFACE_CONTRACT_SUMMARY status=\w+ checks=\d+ failures=\d+', r'^SURFACE_CONTRACT_SUMMARY status=\w+ checks=(\d+) failures=(\d+)'),
        ('world_session_seed', 'test_world_session_seed.gd', ['SESSION-SEED'], 'headless', 120, r'^WORLD_SESSION_SEED_SUMMARY checks=\d+ failures=\d+', r'^WORLD_SESSION_SEED_SUMMARY checks=(\d+) failures=(\d+)'),
        ('branch_streaming', 'test_branch_streaming.gd', ['BRANCH-MESH', 'BRANCH-FSM', 'BRANCH-DRESS', 'BRANCH-PERF', 'BRANCH-NOPOST', 'BRANCH-DAG', 'BRANCH-NOPOST2', 'BRANCH-SEED'], 'headless', 300, r'^\s*OVERALL VERDICT\s*:', r'^\s*FAILED\s*:\s*(\d+)\s*$'),
        ('terrain_carver', 'test_terrain_carver.gd', ['CARVER-LAYOUT', 'CARVER-NOPOST', 'CARVER-ANCHOR', 'CARVER-CLASS', 'CARVER-LAYER', 'CARVER-PERF'], 'headless', 240, r'^\s*OVERALL VERDICT\s*:', r'^\s*FAILED\s*:\s*(\d+)\s*$'),
        ('road_grammar', 'test_road_grammar.gd', ['GRAMMAR-DET', 'GRAMMAR-SAFE', 'GRAMMAR-PERF', 'GRAMMAR-BIOME'], 'headless', 240, r'^\s*OVERALL VERDICT:', None),
        ('road_contract', 'test_road_contract.gd', ['ROAD-VALID', 'ROAD-GEN', 'ROAD-PERF'], 'headless', 240, r'^\s*TOTAL TESTS EVALUATED: \d+ / \d+ PASSED', None),
        ('macro_profile', 'test_macro_profile_road_integration.gd', ['MACRO-ROAD', 'MACRO-TERR'], 'headless', 240, r'^MACRO_PROFILE_ROAD_INTEGRATION_SUMMARY checks=\d+ failures=\d+ seeds=\d+', r'^MACRO_PROFILE_ROAD_INTEGRATION_SUMMARY checks=(\d+) failures=(\d+) seeds=(\d+)'),
        ('soak_asis', 'test_soak_run.gd', ['SOAK-STATE', 'SOAK-MEM'], 'headless', 1500, r'ALL SOAK TESTS PASSED|\[FAIL\] SOAK TEST FAILED', None)]
    for name, entry, rows, mode, ceiling, pattern, summary in specs:
        s = {'id': 'q2a_' + name, 'kind': 'check', 'origin': 'repo', 'entry': 'res://scripts/test/' + entry,
             'launch': {'mode': mode, 'timeout_s': ceiling, 'user_args': []},
             'matrix': {'rows': rows, 'categories': {r: categories[r] for r in rows}, 'role': 'existing runner; Q2 baseline', 'e_capability': ['E3'] if mode == 'vulkan' else ['E1']},
             'completion': [{'id': 'runner_summary', 'kind': 'stdout_regex', 'pattern': pattern}],
             'fail_markers': [r'\[FAIL[^\]]*\]', 'CHECKS FAILED', 'SUITE FAILED', 'WORLD_SESSION_SEED_FAIL', 'SURFACE_CHECK_FAIL', 'MACRO_PROFILE_ROAD_INTEGRATION_FAIL'],
             'engine_policy': {'errors': 'zero_unexpected', 'leaks': 'record'}, 'limitations': ['existing TEST_MATRIX limitations retained; no E5/E7 acceptance']}
        if summary:
            fg = 1 if name in ('branch_streaming', 'terrain_carver') else 2
            s['summaries'] = [{'id': 'failed', 'pattern': summary, 'failures_group': fg, 'loose_pattern': pattern.split(' checks=')[0]}]
            actual = r'^\s*TOTAL ASSERTIONS\s*:\s*(\d+)' if fg == 1 else summary
            s['assertions'] = {'expected': None, 'actual_from': {'kind': 'counter_regex', 'pattern': actual}}
        if name == 'world_session_seed':
            s['coverage'] = [{'id': 'seven_checks', 'kind': 'counter_min', 'pattern': r'^WORLD_SESSION_SEED_SUMMARY checks=(\d+)', 'min': 7}]
        if name == 'capture_seed_audit':
            s['artifacts'] = [{'glob': 'audit/*/*.png', 'role': 'capture_png', 'min_count': 9, 'checks': ['png_header'], 'png_size': [1280, 720]}, {'glob': 'audit/*/manifest.json', 'role': 'capture_manifest', 'min_count': 1}]
            s['evidence_gate'] = copy.deepcopy(by['capture_visual_vulkan']['evidence_gate'])
            s['coverage'] = [{'id': 'nine_frames', 'kind': 'counter_min', 'pattern': r'^AUDIT_COMPLETE .* frames=(\d+)/9 ', 'min': 9}]
        if name == 'soak_asis':
            s['coverage'] = [{'id': 'three_completed_seeds', 'kind': 'distinct_min', 'pattern': r'\[SUCCESS\] Seed (\d+): Completed', 'min': 3}]
            s['seed_policy'] = 'uncontrolled random effective seeds; C08'
        out.append(s)
    pinned = seeded(out[-1], 'q2a_soak_pin184729', 184729, 1500)
    out.append(pinned)
    return out


def schedule(pilot, probes):
    rows = [('P1-I01', 'P1', probes, 'probe', 'OFF', 'probes')]
    groups = [pilot, DOM, RIDE, VIS, SOAK]
    rows += [('A-I%02d' % i, 'P2', g, 'A', 'OFF', 'pilot' if i == 1 else None) for i, g in enumerate(groups, 1)]
    rows += [('OBJ-%02d' % i, 'P3', OBJ, 'OBJ-%02d' % i, 'OFF', None) for i in range(1, 11)]
    rows += [('PERF-W', 'P4', PERF, 'warmup', 'OFF', None)]
    rows += [('PERF-%d' % i, 'P4', PERF, 'measured-%d' % i, 'OFF', None) for i in range(1, 6)]
    rows += [('MEM-%d' % i, 'P5', MEM, 'memory-%d' % i, 'POLL-250ms', None) for i in range(1, 3)]
    rows += [('B-I%02d' % i, 'P6', g, 'B', 'OFF', 'pilot' if i == 1 else None) for i, g in enumerate(groups, 1)]
    return rows


def seed_config(sid):
    m = re.search(r'_s(\d+)$', sid)
    n = int(m[1]) if m else (184729 if sid == 'q2a_soak_pin184729' else None)
    return {'policy': 'CLI_CERTIFIED' if n is not None else ('UNCONTROLLED' if sid in ['q2a_soak_asis', 'q2a_branch_streaming'] else 'SUITE_DEFAULT'), 'requested': n, 'cli_arg': '--seed=%d' % n if n is not None else None}


def build(data):
    from .extract import METRICS, IDENTITIES
    inv, attempts = [], []
    for iid, phase, suites, rnd, mode, setname in schedule(data['sets']['pilot'], data['sets']['probes']):
        inv.append({'invocation_id': iid, 'phase': phase, 'suites': suites, 'set': setname, 'round': rnd, 'observer_mode': mode})
        for sid in suites:
            n = len(attempts) + 1
            attempts.append({'ordinal': n, 'invocation_id': iid, 'attempt_id': 'Q2A-%03d' % n, 'row_id': sid, 'suite_id': sid, 'round': rnd, 'required': n > 22, 'statistics_role': 'probe' if n <= 22 else ('warmup_excluded' if iid == 'PERF-W' else ('measured' if iid.startswith('PERF-') else 'baseline'))})
    return {'schema': 'slow-cycle.baseline.campaign/1', 'task': 'Q2A', 'plan_version': 'v1.1; human approved 2026-10-03, D1-D6, A-H, HUMAN AMENDMENTS A1/A2', 'runtime_base_revision': BASE, 'runtime_roots': ROOTS, 'artifact_model': ARTIFACT_MODEL,
            'seeds': {'canonical': S7[:3], 'additional': {'rule': 'SHA256 slow-cycle/q2a/additional-seed/<i>, first four bytes big-endian & 0x7fffffff; exclude matrix bound seeds', 'values': S7[3:]}, 'S7': S7},
            'entries': {s['id']: {'matrix': s['matrix'], 'seed_config': seed_config(s['id']), 'mode': s['launch']['mode'], 'timeout_s': s['launch']['timeout_s'], 'role': 'SEED_EXTENSION_OBSERVATION' if seed_config(s['id'])['requested'] not in (None, 184729) else 'BASELINE'} for s in data['suites'][42:]},
            'invocations': inv, 'attempts': attempts, 'metrics': METRICS, 'identities': IDENTITIES,
            'objectdb': {'block': 'P3', 'N': 10, 'order': OBJ}, 'observer': {'interval_ms': 250, 'api': 'WinAPI Toolhelp32, OpenProcess, K32GetProcessMemoryInfo, GetProcessTimes, retained handle post-exit', 'enabled_phases': ['M2', 'P5'], 'A2_role_identity': 'exact QueryFullProcessImageNameW console/main paths and parent relationship; helpers diagnostic only'},
            'stop_rules': ['source_revision_change', 'dirty_tree', 'digest_mismatch', 'engine_identity_change', 'probe_expectation_mismatch', 'ledger_chain_break', 'evidence_root_failure', 'three_consecutive_infra_failed_invocations', 'user_request'],
            'reattempt_policy': {'max_per_attempt': 1, 'new_ordinals_from': 189, 'immediate': True, 'allowed': ['ENGINE_UNAVAILABLE', 'LOG_INCOMPLETE', 'CONTAINMENT_UNVERIFIED', 'ORPHAN_PROCESS', 'HARNESS_*', 'VULKAN_EVIDENCE_MISSING_without_device', 'evidence_root_IO', 'P5_observer_failure'], 'never': ['product_FAIL', 'TIMEOUT', 'RUNNER_TIMEOUT', 'COMPLETION_NOT_PROVEN', 'COVERAGE_MISSING', 'SEED_NOT_CERTIFIED', 'UNKNOWN_ENGINE_MESSAGE', 'NONZERO_EXIT_UNEXPLAINED', 'NEGATIVE_*', 'leaks']}}


def validate(c, data):
    cjson.validate(c)
    expected = build(data)
    for key in expected:
        if c[key] != expected[key]:
            raise ValueError('campaign differs from approved definition: ' + key)
    if len(c['invocations']) != 29 or len(c['attempts']) != 188 or len(c['entries']) != 24:
        raise ValueError('wrong matrix size')
    computed = [int.from_bytes(hashlib.sha256(('slow-cycle/q2a/additional-seed/%d' % i).encode()).digest()[:4], 'big') & 0x7fffffff for i in range(1, 5)]
    if computed != S7[3:]:
        raise ValueError('seed rule differs')


def proof(repo, candidate='HEAD', working=False):
    data = json.loads((Path(repo) / 'tools/verify/suites.json').read_text(encoding='utf-8')) if working else json.loads(git(repo, 'show', candidate + ':tools/verify/suites.json'))
    old = json.loads(git(repo, 'show', BASE + ':tools/verify/suites.json'))
    if len(old['suites']) != 42 or len(data['suites']) != 66 or old['suites'] != data['suites'][:42]:
        raise ValueError('existing suites changed or wrong additive count')
    if {k: v for k, v in old.items() if k != 'suites'} != {k: v for k, v in data.items() if k != 'suites'}:
        raise ValueError('protected manifest blocks changed')
    if set(s['id'] for s in data['suites'][42:]) != set(DOM + RIDE + VIS + SOAK):
        raise ValueError('wrong appended suites')
    paths = git(repo, 'diff', '--name-only', BASE, candidate).splitlines()
    if working:
        paths = sorted(set(paths + git(repo, 'diff', 'HEAD', '--name-only').splitlines() + [l[3:] for l in git(repo, 'status', '--porcelain=v1', '--untracked-files=all').splitlines() if l.startswith('?? ')]))
    if any(p not in ['implementation_plan.md', 'tools/verify/suites.json'] and not p.startswith('tools/baseline/') for p in paths):
        raise ValueError('freeze scope violation')
    roots = {p: {'base': git(repo, 'rev-parse', BASE + ':' + p), 'candidate': git(repo, 'rev-parse', candidate + ':' + p)} for p in ROOTS}
    if any(v['base'] != v['candidate'] for v in roots.values()):
        raise ValueError('protected root changed')
    if git(repo, 'diff', BASE, candidate, '--', 'tools/verify', ':(exclude)tools/verify/suites.json'):
        raise ValueError('Q1 code changed')
    if working and git(repo, 'diff', 'HEAD', '--', *ROOTS, 'tools/verify', ':(exclude)tools/verify/suites.json'):
        raise ValueError('protected worktree changed')
    return {'roots': roots, 'changed_paths': paths, 'existing_suites': 42, 'appended_suites': 24}


def receipt(repo, freeze, definition_digest):
    identities = {}
    for path in ['implementation_plan.md', 'tools/baseline/q2a_campaign.json', 'tools/verify/suites.json']:
        raw = subprocess.run(['git', '-C', str(repo), 'show', freeze + ':' + path], check=True, capture_output=True).stdout
        identities[path] = {'git_blob': git(repo, 'rev-parse', freeze + ':' + path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    return {'schema': 'slow-cycle.baseline.freeze-receipt/1', 'timestamp_utc': cjson.utc(), 'runtime_base_revision': BASE, 'campaign_freeze_revision': freeze, 'campaign_definition_digest': definition_digest, 'git_blob_identities': identities, 'protected_runtime_identity_proof': proof(repo, freeze)}


def validate_receipt(repo, path, freeze, definition_digest):
    observed = cjson.load(path)
    expected = receipt(repo, freeze, definition_digest)
    if any(observed.get(k) != v for k, v in expected.items() if k != 'timestamp_utc'):
        raise ValueError('freeze receipt identity/proof mismatch')
    if Path(path).read_bytes() != cjson.canonical(observed) + b'\n':
        raise ValueError('freeze receipt noncanonical bytes')
    return {'relpath': 'campaign/freeze_receipt.json', 'bytes': Path(path).stat().st_size, 'sha256': cjson.sha(path), 'schema': observed['schema']}
