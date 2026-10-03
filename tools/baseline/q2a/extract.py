"""Extract observations only; Q1 verdict/reason fields are copied without interpretation."""
import hashlib
import json
import re
import struct
from decimal import Decimal
from pathlib import Path
from . import cjson

PATTERNS = {
    'graph_topology_ms': r'Topology benchmark .*?finished in ([\d.]+) ms',
    'graph_geometry_ms': r'Geometry conversion benchmark .*?finished in ([\d.]+) ms',
    'carver_math_ms': r'TerrainCarver 2500 samples pure math: ([\d.]+) ms',
    'carver_mesh_ms': r'20 chunks mesh generation & commit: ([\d.]+) ms',
    'carver_trimesh_ms': r'20 chunks trimesh shape creation: ([\d.]+) ms',
    'grammar_generation_total_ms': r'Generation \(Logic \+ Validator\): ([\d.]+) ms total',
    'grammar_generation_avg_ms': r'Generation \(Logic \+ Validator\): [\d.]+ ms total \(avg ([\d.]+) ms',
    'grammar_validator_total_ms': r'Validator Alone:\s*([\d.]+) ms total',
    'grammar_validator_avg_ms': r'Validator Alone:\s*[\d.]+ ms total \(avg ([\d.]+) ms',
    'road_validation_ms': r'Benchmarked 100 chunks .*?: ([\d.]+) ms',
    'branch_commit_avg_ms': r'Commit Phase: Avg = ([\d.]+) ms',
    'branch_commit_max_ms': r'Commit Phase: Avg = [\d.]+ ms, Max = ([\d.]+) ms',
    'rider_progress_m': r'Distance Covered:\s*([\d.]+)m /',
    'rider_lateral_m': r'Max Lateral Deviation:\s*([\d.]+)m',
    'rider_roll_deg': r'Peak Bike Roll Bank:\s*([\d.]+)',
    'rider_events': r'Active Cornering Roll Events:\s*(\d+)',
    'rider_density_per_km': r'Roll Events Density:\s*([\d.]+)',
    'rider_integrity': r'Track Integrity Kept:\s*(YES|NO)'}
METRICS = {k: {'source': 'stdout.log', 'pattern': v, 'groups': [1], 'unit': 'ms' if k.endswith('_ms') else 'printed', 'label_class': 'microbenchmark_ms' if k.endswith('_ms') else 'rider_observation', 'statistics_allowed': ['all_raw', 'median', 'min', 'max'] if k.endswith('_ms') else ['all_raw']} for k, v in PATTERNS.items()}
IDENTITIES = {
    'RI-OPEN': {'source': 'diag manifest replay_steps CHECKPOINT automatic_opening', 'filter': 'signature verbatim; first 100m only', 'canonicalisation': 'producer formatting', 'eligibility': 'certified effective seed + generation_config + engine + command'},
    'RI-SESSION': {'source': 'diag manifest', 'filter': 'opening/selected_arm signatures and route_choices', 'canonicalisation': 'CJSON selected content', 'eligibility': 'same as RI-OPEN'},
    'RI-CAP': {'source': 'audit manifest frames geometry_checkpoint.signature', 'filter': 'producer signature verbatim', 'canonicalisation': 'producer formatting', 'eligibility': 'same as RI-OPEN'},
    **{k: {'source': 'stdout.log and stderr.log', 'filter': v, 'canonicalisation': 'strict UTF8, trailing CR/spaces removed, LF join, SHA256', 'eligibility': e} for k, v, e in [
        ('RI-ROUTE', r'^ROUTE mode=', 'REPEATABILITY_OBSERVATION'), ('RI-ROUTEFAIL', r'\[ROUTE FAIL\]', 'REPEATABILITY_OBSERVATION; sorted UTF8 bytes'),
        ('RI-FORKC', r'^FORK_PROFILE_CONTINUITY', 'source_constant'), ('RI-SOAKSTRUCT', r'\[MILESTONE\]', 'pinned only; remove RAM field'),
        ('RI-DIV', r'^\s*\d+\s*\|', 'source_constant'), ('RI-MONO', r'^.*[Ss]eed.*(?:[Vv]iolation|[Dd]ead|[Rr]elief)', 'source_constant'),
        ('RI-RIDE', r'Distance Covered:|Max Lateral Deviation:|Peak Bike Roll Bank:|Active Cornering Roll Events:|Track Integrity Kept:|Roll Events Density:', 'REPEATABILITY_OBSERVATION')]} }
LEAK = re.compile(r'^WARNING:\s*(\d+) ObjectDB instances? (?:was|were) leaked at exit.*$', re.M)


def text_identity(raw, pattern, sorted_lines=False, soak=False):
    try:
        lines = [s.rstrip('\r ') for s in raw.decode('utf-8', 'strict').splitlines() if re.search(pattern, s)]
    except UnicodeDecodeError:
        return {'status': 'NOT_COMPARABLE(decode_error)', 'sha256': None}
    if soak:
        lines = [re.sub(r' \| RAM: [\d.]+ MB', '', s) for s in lines]
    if sorted_lines:
        lines.sort(key=lambda s: s.encode('utf-8'))
    return {'status': 'OBSERVED' if lines else 'NOT_OBSERVED', 'lines': lines, 'sha256': hashlib.sha256('\n'.join(lines).encode('utf-8')).hexdigest() if lines else None}


def metric(raw, pattern):
    hits = re.findall(pattern, raw.decode('utf-8', 'replace'), re.M)
    return {'status': 'OBSERVED' if hits else 'NOT_OBSERVED', 'values': hits}


def png(path):
    raw = Path(path).read_bytes()[:24]
    if len(raw) != 24 or raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('invalid PNG header')
    return list(struct.unpack('>II', raw[16:24]))


def extract(check):
    check = Path(check)
    r = cjson.load(check / 'result.json')
    raw = {s: (check / s).read_bytes() for s in ['stdout.log', 'stderr.log', 'engine.log']}
    both = raw['stdout.log'] + b'\n' + raw['stderr.log']
    ident = {k: text_identity(both, v['filter'], k == 'RI-ROUTEFAIL', k == 'RI-SOAKSTRUCT') for k, v in IDENTITIES.items() if k not in ['RI-OPEN', 'RI-SESSION', 'RI-CAP']}
    manifests, openings, sessions, captures, latency = [], [], [], [], []
    for p in sorted(check.glob('diag/*/manifest.json')):
        m = cjson.load(p)
        item = {'relpath': p.relative_to(check).as_posix(), 'effective_seed': m.get('effective_seed'), 'generation_config': m.get('generation_config'), 'driver': m.get('driver'), 'renderer': m.get('renderer'), 'display_server': m.get('display_server'), 'source_digest': m.get('source_digest'), 'last_snapshot': m.get('last_snapshot'), 'route_choices': m.get('route_choices', []), 'source_hashes': m.get('source_hashes', {})}
        manifests.append(item)
        steps = [s['details'] for s in m.get('replay_steps', []) if s.get('type') == 'CHECKPOINT']
        openings += [{**item, 'signature': s.get('signature'), 'samples': s.get('samples'), 'range_m': s.get('range_m'), 'precision': 'implicit engine string formatting; 51 first-100m samples'} for s in steps if s.get('label') == 'automatic_opening']
        kept = [{'label': s.get('label'), 'signature': s.get('signature')} for s in steps if s.get('label') in ['opening', 'selected_arm']]
        if kept:
            sessions.append({**item, 'checkpoints': kept, 'sha256': cjson.digest({'checkpoints': kept, 'choices': item['route_choices']})})
        ev = p.parent / 'events.jsonl'
        if ev.exists():
            events = [json.loads(l, parse_float=str) for l in ev.read_text(encoding='utf-8').splitlines()]
            start = next((e['ticks_ms'] for e in events if e.get('type') == 'SESSION_START'), None)
            end = next((e['ticks_ms'] for e in events if e.get('type') == 'CHECKPOINT' and e.get('details', {}).get('label') == 'automatic_opening'), None)
            latency.append({'seed': item['effective_seed'], 'generation_latency_proxy_ms': end - start if end is not None and start is not None else 'NOT_OBSERVED', 'label': 'proxy including setup and frames'})
    vulkan = []
    for p in sorted(check.glob('audit/*/manifest.json')):
        m = cjson.load(p)
        captures.append({'relpath': p.relative_to(check).as_posix(), 'sessions': m.get('sessions', []), 'frames': m.get('frames', []), 'source_digest': m.get('source_digest'), 'source_hashes': m.get('source_hashes', {})})
        vulkan.append({'driver': m.get('driver'), 'renderer': m.get('renderer'), 'display_server': m.get('display_server'), 'manifest': p.relative_to(check).as_posix(), 'source_digest': m.get('source_digest')})
    ident.update({'RI-OPEN': openings, 'RI-SESSION': sessions, 'RI-CAP': captures})
    leaks = {s: {'lines': LEAK.findall(v.decode('utf-8', 'replace')), 'at_lines': [l for l in v.decode('utf-8', 'replace').splitlines() if l.lstrip().startswith('at:')]} for s, v in raw.items() if s != 'stdout.log'}
    leaks['mismatch'] = leaks['stderr.log']['lines'] != leaks['engine.log']['lines']
    normal = r['process']['spawned'] and not r['timeout']['timed_out'] and r['exit_code'] is not None and r['completion_marker']['satisfied'] and not r['process']['post_exit_orphans']
    return {'copied_q1': {k: r[k] for k in ['result', 'reason_code', 'reasons', 'errors', 'warnings', 'leaks', 'engine_messages', 'limitations', 'certified_actual_checks_if_measurable', 'actual_coverage', 'contract_report', 'timeout']}, 'metrics': {k: metric(raw['stdout.log'], p) for k, p in PATTERNS.items()}, 'identities': ident, 'seed': r['seed'], 'manifests': manifests, 'generation_latency': latency, 'vulkan': vulkan,
            'vulkan_banner': [l for l in raw['stdout.log'].decode('utf-8', 'replace').splitlines() if l.startswith('Vulkan ')], 'pngs': [{'relpath': p.relative_to(check).as_posix(), 'bytes': p.stat().st_size, 'sha256': cjson.sha(p), 'dimensions': png(p)} for p in sorted(check.rglob('*.png'))], 'objectdb': leaks, 'normally_completed': normal,
            'branch_lines': text_identity(both, r'^ROUTE |\[ROUTE (?:FAIL|DIAGNOSTIC)\]|FORK_PROFILE_CONTINUITY|\[GEOM\]|FSM|DAG|unload'), 'streaming_lines': text_identity(both, r'\[MILESTONE\]|\[INIT\]|\[SUCCESS\]|\[RECOVERY TEST\]')}


def eligibility(a, b, identity):
    sid = a['suite_id']
    if sid != b['suite_id'] or sid in ['q2a_soak_asis', 'q2a_branch_streaming'] or identity in ['PNG', 'timing', 'memory']:
        return 'EXCLUDED_FROM_EQUALITY'
    if identity in ['RI-RIDE', 'RI-ROUTE', 'RI-ROUTEFAIL']:
        return 'REPEATABILITY_OBSERVATION' if a['configuration'] == b['configuration'] else 'EXCLUDED_FROM_EQUALITY'
    if a['configuration'] != b['configuration'] or a['engine_sha256'] != b['engine_sha256'] or a['seed_context'] != b['seed_context'] or not a['seed_context']:
        return 'EXCLUDED_FROM_EQUALITY'
    return 'EQUALITY_ELIGIBLE' if a['seed_trusted'] and b['seed_trusted'] else 'EXCLUDED_FROM_EQUALITY'


def stats(values):
    nums = sorted(Decimal(v) for v in values)
    n = len(nums)
    return {'raw': values, 'n': n, 'median': format((nums[(n-1)//2] + nums[n//2]) / 2, 'f'), 'min': format(nums[0], 'f'), 'max': format(nums[-1], 'f')} if n else {'raw': [], 'n': 0, 'status': 'NOT_OBSERVED'}
