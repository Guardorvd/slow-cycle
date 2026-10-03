"""Reconcile immutable bindings and summarise observations; suite outcomes belong to Q1."""
import itertools
from pathlib import Path
from . import cjson, ledger, extract, campaign as definition


def artifact_closure(root, baseline):
    root = Path(root)
    model = definition.ARTIFACT_MODEL
    payload = [row for row in cjson.inventory(root, model['payload_excluded']) if Path(row[0]).name not in ['artifact_index.txt', 'repository_artifact_index.txt']]
    raw = ''.join('%s %d %s\n' % (sha, size, path) for path, size, sha in payload).encode('utf-8')
    index = root / model['payload_index']
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
                    return [f.get('geometry_checkpoint', {}).get('signature') for v in v for f in v.get('frames', [])]
                va, vb = identity_value(oa), identity_value(ob)
                out.append({'identity': identity, 'a': a['attempt_ordinal'], 'b': b['attempt_ordinal'], 'eligibility': eligibility, 'observation': 'NOT_OBSERVED' if not va or not vb else (('MATCH' if va == vb else 'MISMATCH') if eligibility == 'EQUALITY_ELIGIBLE' else ('IDENTICAL' if va == vb else 'DIFFERENT'))})
    return out


def aggregate(root, campaign, partial=False):
    root = Path(root)
    rec = reconcile(root, campaign, partial)
    refs = rec['refs']
    obs = {a['attempt_id']: extract.extract(root / a['q1_check_relpath']) for a in refs}
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
                'road_identity': {a['attempt_id']: {k: ([{'seed': x.get('effective_seed'), 'signature': x.get('signature'), 'sha256': x.get('sha256')} for x in v] if isinstance(v, list) else {'sha256': v['sha256'], 'status': v['status']}) for k, v in obs[a['attempt_id']]['identities'].items()} for a in product}, 'determinism': comparisons(product, obs),
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
    baseline['performance']['process_wall_statistics'] = [{'suite_id': sid, 'configuration': group[0]['configuration'], 'statistics': extract.stats(['%d' % a['duration_ms'] for a in group])} for sid in sorted({a['suite_id'] for a in product}) for group in [[a for a in product if a['suite_id'] == sid]]]
    artifact_closure(root, baseline)
    return baseline


def records_id(rec):
    return rec['records'][0]['baseline_id']
