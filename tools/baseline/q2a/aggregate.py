"""Reconcile immutable bindings and summarise observations; suite outcomes belong to Q1."""
import itertools
from pathlib import Path
from . import cjson, ledger, extract, envinfo, campaign as definition


def artifact_closure(root, baseline):
    root = Path(root)
    model = definition.ARTIFACT_MODEL
    payload = [row for row in cjson.inventory(root, model['payload_excluded']) if Path(row[0]).name not in ['artifact_index.txt', 'repository_artifact_index.txt']]
    raw = ''.join('%s %d %s\n' % (sha, size, path) for path, size, sha in payload).encode('utf-8')
    index = root / model['payload_index']
    index.parent.mkdir(parents=True, exist_ok=True)
    index.write_bytes(raw)
    baseline['artifact_manifest'] = {'payload_evidence_digest': {'artifact_root_digest': cjson.sha(index), 'relpath': model['payload_index'], 'bytes': len(raw), 'files': len(payload)}, 'closure_metadata_paths': model['closure_files'], 'excluded_from_payload': model['payload_excluded'], 'closure_digests_location': 'repository artifact_index.txt; no self-dependent hash in baseline.json'}
    cjson.write(root / 'aggregate/baseline.json', baseline)
    sums = ''.join('%s  %s\n' % (sha, path) for path, size, sha in cjson.inventory(root, ['SHA256SUMS', 'aggregate/repository_artifact_index.txt']) if Path(path).name not in ['artifact_index.txt', 'repository_artifact_index.txt'])
    (root / 'SHA256SUMS').write_bytes(sums.encode('utf-8'))
    return [{'relpath': p, 'bytes': (root / p).stat().st_size, 'sha256': cjson.sha(root / p)} for p in model['closure_files']]


def reconcile(root, campaign, allow_partial=False):
    root = Path(root)
    records, head = ledger.read(root / 'ledger.jsonl', cjson.digest(campaign))
    if records[0].get('freeze_receipt'):
        receipt = records[0]['freeze_receipt']
        p = root / receipt['relpath']
        if not p.is_file() or p.stat().st_size != receipt['bytes'] or cjson.sha(p) != receipt['sha256']:
            raise ValueError('freeze receipt changed')
    starts = [r for r in records if r['type'] in ['INVOCATION_START', 'REATTEMPT_START']]
    ends = [r for r in records if r['type'] == 'INVOCATION_END']
    if len(starts) != len(ends):
        raise ValueError('started invocation without end evidence')
    declared = [r['invocation_id'] for r in starts if r['type'] == 'INVOCATION_START']
    expected = [r['invocation_id'] for r in campaign['invocations']]
    if declared != expected[:len(declared)] or (not allow_partial and declared != expected):
        raise ValueError('invocation matrix/order mismatch')
    refs = [a for r in ends for a in r['attempts']]
    actual_dirs = {p.name for p in (root / 'runs').iterdir() if p.is_dir()}
    bound_dirs = {r['q1_run_id'] for r in ends}
    if actual_dirs != bound_dirs or len(bound_dirs) != len(ends):
        raise ValueError('missing or extra Q1 run directory')
    planned = {a['ordinal']: a for a in campaign['attempts']}
    declared_ordinals = [a['attempt_ordinal'] for a in refs if a['retry_of'] is None]
    if declared_ordinals != list(range(1, len(declared_ordinals) + 1)) or (not allow_partial and len(declared_ordinals) != 188):
        raise ValueError('attempt matrix/order mismatch')
    for start, end in zip(starts, ends):
        if start['invocation_id'] != end['invocation_id'] or start['argv'] != end['argv']:
            raise ValueError('invocation binding differs')
        run = cjson.load(root / 'runs' / end['q1_run_id'] / 'run.json')
        if run['selected'] != [a['suite_id'] for a in end['attempts']] or run.get('not_run'):
            raise ValueError('Q1 selected matrix differs')
        for a in end['attempts']:
            p = root / a['q1_check_relpath']
            r = cjson.load(p / 'result.json')
            if cjson.sha(p / 'result.json') != a['q1_result_json_sha256']:
                raise ValueError('result.json changed')
            if cjson.digest(cjson.inventory(p)) != a['directory_digest']:
                raise ValueError('attempt raw artifact changed')
            if any(a[k] != r[q] for k, q in [('q1_result', 'result'), ('q1_reason_code', 'reason_code'), ('q1_reasons', 'reasons')]):
                raise ValueError('Q1 verdict/reason copy mismatch')
            if a['retry_of'] is None and any(a[k] != planned[a['attempt_ordinal']][v] for k, v in [('suite_id', 'suite_id'), ('invocation_id', 'invocation_id'), ('attempt_id', 'attempt_id')]):
                raise ValueError('attempt differs from declaration')
            if any(a[k] != records[0][k] for k in ['campaign_definition_digest', 'campaign_freeze_revision', 'runtime_base_revision']):
                raise ValueError('attempt revision/digest binding differs')
    return {'status': 'RECONCILED', 'ledger_head': head, 'declared_executed': len(declared_ordinals), 'executed_attempts': len(refs), 'infrastructure_retries': sum(a['retry_of'] is not None for a in refs), 'refs': refs, 'records': records}


def gap_status(refs, decisions=()):
    accepted = {d['ordinal'] for d in decisions}
    gaps = [a['attempt_ordinal'] for a in refs if a['attempt_ordinal'] > 22 and (a['q1_result'] == 'INCOMPLETE' or a['evidence_status'] != 'CAPTURED') and a['attempt_ordinal'] not in accepted and not any(b['retry_of'] == a['attempt_ordinal'] and b['q1_result'] != 'INCOMPLETE' and b['evidence_status'] == 'CAPTURED' for b in refs)]
    return ('AWAITING_HUMAN_GAP_DECISION' if gaps else ('CAPTURED_WITH_ACCEPTED_GAPS' if decisions else 'CAPTURED')), gaps


def census(refs, observations, phase=None):
    out = {}
    for a in refs:
        if a['attempt_ordinal'] <= 22 or (phase and a['phase'] != phase):
            continue
        o = observations[a['attempt_id']]
        sid = a['suite_id']
        rec = out.setdefault(sid, {'normally_completed': 0, 'emitted_warning': 0, 'attempts': []})
        normal, warned = o['normally_completed'], bool(o['objectdb']['stderr.log']['lines'] or o['objectdb']['engine.log']['lines'])
        rec['normally_completed'] += int(normal)
        rec['emitted_warning'] += int(normal and warned)
        rec['attempts'].append({'ordinal': a['attempt_ordinal'], 'run_id': a['q1_run_id'], 'phase': a['phase'], 'seed': o['seed'], 'normal': normal, **o['objectdb']})
    total = {'normally_completed': sum(r['normally_completed'] for r in out.values()), 'emitted_warning': sum(r['emitted_warning'] for r in out.values())}
    return {'per_suite': out, 'total': total, 'denominator': 'normally completed attempts only; infrastructure failures excluded'}


def comparisons(refs, obs):
    out = []
    for sid in sorted({r['suite_id'] for r in refs if r['attempt_ordinal'] > 22}):
        group = [r for r in refs if r['suite_id'] == sid and r['attempt_ordinal'] > 22]
        for a, b in itertools.combinations(group, 2):
            oa, ob = obs[a['attempt_id']], obs[b['attempt_id']]
            for identity in extract.IDENTITIES:
                def context(r, o):
                    source = 'source_constant' if sid in ['seed_diversity', 'monotony', 'q2a_macro_profile'] else None
                    if identity == 'RI-CAP':
                        cap = o['identities']['RI-CAP']
                        return {'suite_id': sid, 'configuration': r['configuration'], 'engine_sha256': r['engine_sha256'], 'seed_context': [{'seed': v['seed'], 'config': v['generation_config']} for v in cap], 'seed_trusted': bool(cap) and all(v.get('seed_certified') and v['status'] == 'OBSERVED' for v in cap)}
                    return {'suite_id': sid, 'configuration': r['configuration'], 'engine_sha256': r['engine_sha256'], 'seed_context': source or [{'seed': m['effective_seed'], 'config': m['generation_config']} for m in o['manifests']], 'seed_trusted': bool(source or o['seed'].get('certified'))}
                eligibility = extract.eligibility(context(a, oa), context(b, ob), identity)
                if eligibility == 'EXCLUDED_FROM_EQUALITY':
                    continue
                def identity_value(o):
                    v = o['identities'][identity]
                    if isinstance(v, dict):
                        return v.get('sha256')
                    if identity == 'RI-OPEN':
                        return sorted((v['effective_seed'], v['signature']) for v in v if v.get('signature'))
                    if identity == 'RI-SESSION':
                        return sorted((v['effective_seed'], v['sha256']) for v in v if v.get('sha256'))
                    return [v['signature'] for v in v] if v and all(x['status'] == 'OBSERVED' for x in v) else None
                va, vb = identity_value(oa), identity_value(ob)
                out.append({'identity': identity, 'a': a['attempt_ordinal'], 'b': b['attempt_ordinal'], 'eligibility': eligibility, 'observation': 'NOT_OBSERVED' if not va or not vb else (('MATCH' if va == vb else 'MISMATCH') if eligibility == 'EQUALITY_ELIGIBLE' else ('IDENTICAL' if va == vb else 'DIFFERENT'))})
    return out


def aggregate(root, campaign, partial=False):
    root = Path(root)
    rec = reconcile(root, campaign, partial)
    refs = rec['refs']
    obs = {a['attempt_id']: extract.extract(root / a['q1_check_relpath']) for a in refs}
    for a in refs:
        for value in obs[a['attempt_id']]['identities']['RI-CAP'] + obs[a['attempt_id']]['identities']['RI-SESSION']:
            value.update(attempt_id=a['attempt_id'], ordinal=a['attempt_ordinal'], q1_run_id=a['q1_run_id'])
            if value['source_relpath']:
                value['source_relpath'] = a['q1_check_relpath'] + '/' + value['source_relpath']
    status, gaps = gap_status(refs)
    perf = {}
    for a in refs:
        if a['statistics_role'] == 'measured':
            for k, v in obs[a['attempt_id']]['metrics'].items():
                if k.endswith('_ms'):
                    perf.setdefault(k, []).extend(v['values'])
    perf = {k: extract.stats(v) for k, v in perf.items() if v}
    product = [r for r in refs if r['attempt_ordinal'] > 22]
    counts = {k: sum(r['q1_result'] == k for r in product) for k in ['PASS', 'FAIL', 'INCOMPLETE']}
    opening_table = [{'ordinal': a['attempt_ordinal'], 'suite_id': a['suite_id'], 'round': a['round'], 'seed': m['effective_seed'], 'signature': m['signature'], 'generation_config': m['generation_config'], 'eligibility': 'CROSS_SUITE_OBSERVATION_ONLY'} for a in product for m in obs[a['attempt_id']]['identities']['RI-OPEN']]
    baseline = {'schema_version': 'slow-cycle.baseline/1', 'baseline_id': records_id(rec), 'runtime_base_revision': campaign['runtime_base_revision'], 'campaign_freeze_revision': rec['records'][0]['campaign_freeze_revision'], 'campaign_definition_digest': cjson.digest(campaign), 'ledger_head_sha256': rec['ledger_head'], 'runtime_identity_proof': rec['records'][0]['runtime_identity_proof'], 'campaign_rows': campaign['entries'], 'attempt_plan': campaign['attempts'], 'run_refs': refs, 'environment': {'pre': cjson.load(root / 'env/pre.json'), 'post': cjson.load(root / 'env/post.json') if (root / 'env/post.json').exists() else 'NOT_RUN'},
                'seed_matrix': [{'ordinal': a['attempt_ordinal'], 'suite_id': a['suite_id'], 'declared': a['seed_config'], 'observed': obs[a['attempt_id']]['seed'], 'effective': [m['effective_seed'] for m in obs[a['attempt_id']]['manifests']]} for a in product],
                'road_identity': {a['attempt_id']: {k: (v if k in ['RI-CAP', 'RI-SESSION'] else ([{'seed': x.get('effective_seed'), 'signature': x.get('signature'), 'sha256': x.get('sha256')} for x in v] if isinstance(v, list) else {'sha256': v['sha256'], 'status': v['status']})) for k, v in obs[a['attempt_id']]['identities'].items()} for a in product}, 'determinism': comparisons(product, obs),
                'rider': [{'ordinal': a['attempt_ordinal'], 'suite_id': a['suite_id'], 'metrics': {k: v for k, v in obs[a['attempt_id']]['metrics'].items() if k.startswith('rider_')}, 'contract': obs[a['attempt_id']]['copied_q1']['contract_report']} for a in product if 'rider' in a['suite_id']],
                'branch': [{'ordinal': a['attempt_ordinal'], 'lines': obs[a['attempt_id']]['branch_lines']} for a in product if obs[a['attempt_id']]['branch_lines']['sha256']], 'streaming': [{'ordinal': a['attempt_ordinal'], 'lines': obs[a['attempt_id']]['streaming_lines']} for a in product if 'soak' in a['suite_id']],
                'performance': {'measured': perf, 'warmup': [a['attempt_ordinal'] for a in refs if a['statistics_role'] == 'warmup_excluded'], 'frame_time': 'NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING', 'gpu': 'NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING', 'process_wall_ms': [{'ordinal': a['attempt_ordinal'], 'value': a['duration_ms']} for a in product], 'round_observations': [{'ordinal': a['attempt_ordinal'], 'metrics': obs[a['attempt_id']]['metrics']} for a in product if a['round'] in ['A', 'B']], 'latency': [{'ordinal': a['attempt_ordinal'], 'values': obs[a['attempt_id']]['generation_latency']} for a in product]},
                'memory': [cjson.load(p) for p in sorted((root / 'observer').glob('*.summary.json'))], 'vulkan': [{'ordinal': a['attempt_ordinal'], 'provenance': obs[a['attempt_id']]['vulkan'], 'banner': obs[a['attempt_id']]['vulkan_banner'], 'pngs': obs[a['attempt_id']]['pngs']} for a in product if a['configuration']['mode'] == 'vulkan'],
                'leaks': {'P3': census(refs, obs, 'P3'), 'campaign_wide': census(refs, obs)}, 'known_failures': [a for a in product if a['q1_result'] == 'FAIL'], 'known_incomplete': [a for a in product if a['q1_result'] == 'INCOMPLETE'], 'messages': [{'ordinal': a['attempt_ordinal'], 'engine_messages': obs[a['attempt_id']]['copied_q1']['engine_messages']} for a in product], 'accepted_gaps': [{'decision': 'D4', 'scope': 'frame/GPU timing NOT_MEASURED'}], 'required_gaps': gaps,
                'C10': 'OPEN', 'C12': 'OPEN', 'runtime_acceptance': 'INCOMPLETE', 'e5_human_review': 'NOT_PERFORMED', 'e7': 'NOT_CLAIMED', 'product_counts': counts, 'overall_baseline_status': status if len(product) >= 166 or gaps else 'NOT_COMPLETED', 'limitations': ['same engine/environment only', 'RI-OPEN is sampled first-100m identity', 'RI-RIDE/RI-ROUTE are repeatability observations', 'Q1 purpose remains pilot', 'Q1 NB1/NB2/NB3/NB5/NB6 and N5-N8 retained', 'thermal/background drift', 'ObjectDB occurrence only; no cause claim']}
    cjson.write(root / 'aggregate/extraction_report.json', obs)
    cjson.write(root / 'aggregate/reconcile_report.json', {k: v for k, v in rec.items() if k not in ['refs', 'records']})
    baseline['freeze_receipt'] = rec['records'][0].get('freeze_receipt')
    baseline['cross_suite_opening_observations'] = opening_table
    baseline['product_aggregate'] = 'FAIL' if counts['FAIL'] else ('INCOMPLETE' if counts['INCOMPLETE'] or not product else 'PASS')
    baseline['product_aggregate_basis'] = 'Q1 aggregate policy over copied constituent verdicts; runtime acceptance remains INCOMPLETE'
    baseline['performance']['process_wall_statistics'] = wall_statistics(product)
    baseline['session_timing'] = session_timing(product, obs, baseline['determinism'])
    history = root / 'aggregate/superseded/A3/receipt.json'
    if history.exists():
        baseline['superseded_RI_SESSION'] = {'status': 'SUPERSEDED_BY_A4', 'defect': 'physics_tick and incidental route_choices fields incorrectly included in deterministic identity', 'receipt': {'relpath': history.relative_to(root).as_posix(), 'bytes': history.stat().st_size, 'sha256': cjson.sha(history)}, 'record': cjson.load(history)}
    baseline['representation'] = 'full-external/1'
    baseline['environment'] = {k: envinfo.reporting_view(v) if isinstance(v, dict) else v for k, v in baseline['environment'].items()}
    baseline['environment']['raw_evidence'] = [{'relpath': 'env/' + k + '.json', 'bytes': (root / ('env/' + k + '.json')).stat().st_size, 'sha256': cjson.sha(root / ('env/' + k + '.json'))} for k in ['pre', 'post'] if (root / ('env/' + k + '.json')).exists()]
    sources = ['aggregate.py', 'extract.py', 'envinfo.py']
    baseline['reporting_source'] = {'amendment': 'A3+A4', 'frozen_campaign_unchanged': True, 'files': [{'relpath': 'tools/baseline/q2a/' + p, 'sha256': cjson.sha(Path(__file__).parent / p)} for p in sources], 'RI_CAP_source_compatibility': 'frozen descriptor shorthand resolves via capture manifest referenced per-frame metadata; producer signature unchanged', 'RI_SESSION_semantics': {'checkpoints': ['opening', 'selected_arm'], 'decision_fields': extract.SESSION_DECISION_FIELDS, 'timing': 'physics_tick separate REPEATABILITY_OBSERVATION; excluded from deterministic hash', 'frozen_descriptor_compatibility': 'route_choices means explicit deterministic fields only under approved post-freeze A4; campaign descriptor bytes unchanged'}}
    baseline['reporting_source']['digest'] = cjson.digest(baseline['reporting_source']['files'])
    artifact_closure(root, baseline)
    return baseline


def records_id(rec):
    return rec['records'][0]['baseline_id']


def session_timing(refs, obs, deterministic_comparisons):
    values = [{**{k: v[k] for k in ['attempt_id', 'ordinal', 'q1_run_id', 'source_relpath', 'source_sha256', 'effective_seed']}, **v['timing']} for a in refs for v in obs[a['attempt_id']]['identities']['RI-SESSION']]
    by_ordinal = {a['attempt_ordinal']: obs[a['attempt_id']]['identities']['RI-SESSION'] for a in refs}
    def ticks(ordinal):
        rows = by_ordinal[ordinal]
        return sorted([[v['effective_seed'], v['timing']['physics_tick']] for v in rows], key=lambda v: v[0]) if rows and all(v['timing']['status'] == 'OBSERVED' for v in rows) else None
    pairs = []
    for row in deterministic_comparisons:
        if row['identity'] == 'RI-SESSION':
            a, b = ticks(row['a']), ticks(row['b'])
            pairs.append({'a': row['a'], 'b': row['b'], 'eligibility': 'REPEATABILITY_OBSERVATION', 'observation': 'NOT_OBSERVED' if a is None or b is None else ('IDENTICAL' if a == b else 'DIFFERENT'), 'a_ticks': a, 'b_ticks': b})
    return {'label': 'REPEATABILITY_OBSERVATION', 'equality_claim': False, 'field': 'physics_tick', 'values': values, 'comparisons': pairs}


def wall_statistics(refs):
    groups = {}
    for r in refs:
        role = 'memory_evidence' if r.get('phase') == 'P5' else r['statistics_role']
        key = cjson.canonical([r['suite_id'], r['configuration'], r['observer_mode'], role])
        groups.setdefault(key, []).append(r)
    return [{'suite_id': g[0]['suite_id'], 'configuration': g[0]['configuration'], 'observer_mode': g[0]['observer_mode'], 'workload_role': 'memory_evidence' if g[0].get('phase') == 'P5' else g[0]['statistics_role'], 'ordinals': [r['attempt_ordinal'] for r in g], 'timing_authority': 'P4 measured only; P5 memory evidence is not clean timing', 'statistics': extract.stats([str(r['duration_ms']) for r in g])} for key, g in sorted(groups.items())]


def compact_record(root, full):
    root = Path(root)
    report = root / 'aggregate/baseline.json'
    if cjson.load(report) != full:
        raise ValueError('full report differs from supplied record')
    declared = full['attempt_plan']
    refs = full['run_refs']
    if [r['attempt_ordinal'] for r in refs if r['retry_of'] is None] != [a['ordinal'] for a in declared]:
        raise ValueError('compact attempt accountability mismatch')
    compact = {**full, 'representation': 'compact-repository/1'}
    compact['full_external_report'] = {'schema_version': full['schema_version'], 'representation': full['representation'], 'relpath': 'aggregate/baseline.json', 'bytes': report.stat().st_size, 'sha256': cjson.sha(report), 'baseline_id': full['baseline_id'], 'campaign_freeze_revision': full['campaign_freeze_revision']}
    def detail(field):
        return {'record_ref': 'full_external_report', 'json_pointer': '/' + field}
    fields = ['attempt_ordinal', 'attempt_id', 'invocation_id', 'row_id', 'suite_id', 'round', 'phase', 'statistics_role', 'required', 'q1_run_id', 'q1_check_relpath', 'q1_result_json_sha256', 'q1_result', 'q1_reason_code', 'q1_reasons', 'retry_of', 'directory_digest', 'evidence_status', 'evidence_problems', 'exit_code', 'duration_ms', 'observer_mode', 'seed_config', 'configuration']
    compact['run_refs'] = [{k: r[k] for k in fields} for r in refs]
    compact['run_binding_details'] = detail('run_refs')
    compact['known_failures'] = [r for r in compact['run_refs'] if r['attempt_ordinal'] > 22 and r['q1_result'] == 'FAIL']
    compact['known_incomplete'] = [r for r in compact['run_refs'] if r['attempt_ordinal'] > 22 and r['q1_result'] == 'INCOMPLETE']
    counts = {}
    for row in full['determinism']:
        key = row['identity'] + '/' + row['eligibility'] + '/' + row['observation']
        counts[key] = counts.get(key, 0) + 1
    compact['determinism'] = {'findings': counts, 'comparison_count': len(full['determinism']), 'detail': detail('determinism'), 'scope': 'sampled opening and repeatability only; no full road/world hash'}
    compact['road_identity'] = {'attempt_count': len(full['road_identity']), 'RI_CAP_values': sum(len(row['RI-CAP']) for row in full['road_identity'].values()), 'detail': detail('road_identity')}
    if 'session_timing' in full:
        timing = full['session_timing']
        compact['session_timing'] = {'label': timing['label'], 'equality_claim': False, 'field': timing['field'], 'value_count': len(timing['values']), 'comparison_count': len(timing['comparisons']), 'findings': {k: sum(r['observation'] == k for r in timing['comparisons']) for k in ['IDENTICAL', 'DIFFERENT', 'NOT_OBSERVED']}, 'detail': detail('session_timing')}
    for field in ['branch', 'streaming', 'cross_suite_opening_observations', 'messages']:
        compact[field] = {'attempt_or_observation_count': len(full[field]), 'detail': detail(field)}
    compact['environment'] = {**full['environment']}
    for phase in ['pre', 'post']:
        if isinstance(full['environment'][phase], dict):
            env = {**full['environment'][phase]}
            listing = env.pop('user_data_listing', 'UNKNOWN')
            env['user_data_listing'] = {'entries': len(listing) if isinstance(listing, list) else 'UNKNOWN', 'unit': 'microseconds', 'detail': detail('environment/' + phase + '/user_data_listing')}
            compact['environment'][phase] = env
    return compact


def repository_index(root, full):
    root = Path(root)
    header = ['Q2A artifact index / A1+A3+A4; no self hash', 'baseline_id ' + full['baseline_id']]
    for key in ['runtime_base_revision', 'campaign_freeze_revision', 'campaign_definition_digest', 'ledger_head_sha256']:
        header.append(key + ' ' + full[key])
    header.append('payload_root ' + full['artifact_manifest']['payload_evidence_digest']['artifact_root_digest'])
    header.append('reporting_source_digest ' + full['reporting_source']['digest'])
    if 'superseded_RI_SESSION' in full:
        history = full['superseded_RI_SESSION']
        header.append('RI-SESSION historical composite SUPERSEDED_BY_A4; physics_tick incorrectly included')
        for item in [history['receipt']] + history['record']['files']:
            header.append('%s %d %s' % (item['sha256'], item['bytes'], item['relpath']))
    for item in full['environment']['raw_evidence'] + [full['freeze_receipt']]:
        header.append('%s %d %s' % (item['sha256'], item['bytes'], item['relpath']))
    for a in full['run_refs']:
        header.append('ATTEMPT %d %s %s %s %s %s' % (a['attempt_ordinal'], a['attempt_id'], a['q1_run_id'], a['q1_check_relpath'], a['directory_digest'], a['q1_result_json_sha256']))
    for line in (root / 'aggregate/artifact_index_full.txt').read_text(encoding='utf-8').splitlines():
        path = line.split(' ', 2)[2]
        if Path(path).name in ['result.json', 'stdout.log', 'stderr.log', 'engine.log', 'manifest.json'] or path.endswith('.png'):
            header.append(line)
    for path in definition.ARTIFACT_MODEL['closure_files']:
        header.append('%s %d %s' % (cjson.sha(root / path), (root / path).stat().st_size, path))
    return ('\n'.join(header) + '\n').encode('utf-8')


def check_repository_budget(compact, index, other_bytes=0):
    size = len(cjson.canonical(compact)) + 1 + len(index) + other_bytes
    if size > 1000000:
        raise ValueError('repository baseline budget exceeded: ' + str(size))
    return size
