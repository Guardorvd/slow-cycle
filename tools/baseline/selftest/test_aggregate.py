import tempfile
import unittest
import ctypes as ct
import io
import json
from ctypes import wintypes as wt
from types import SimpleNamespace
from unittest.mock import patch
from pathlib import Path
import sc_baseline
from q2a.observer import Observer, Memory
from q2a import aggregate, cjson, ledger, extract


class Integrity(unittest.TestCase):
    def session_pair(self, change):
        steps = [{'label': 'opening', 'signature': 'a' * 64}, {'label': 'selected_arm', 'signature': 'b' * 64}]
        choices = [{'fork_id': 1, 'choice': 0, 'selected_branch_id': 0, 'selected_seed': 42, 'physics_tick': 18}]
        other_steps = json.loads(json.dumps(steps)); other_choices = json.loads(json.dumps(choices))
        change(other_steps, other_choices)
        refs, obs = [], {}
        for ordinal, checkpoints, decisions in [(23, steps, choices), (24, other_steps, other_choices)]:
            attempt = str(ordinal)
            refs.append({'attempt_ordinal': ordinal, 'attempt_id': attempt, 'suite_id': 'session_diagnostics', 'configuration': {}, 'engine_sha256': 'e'})
            session = {**extract.session_identity(checkpoints, decisions), 'effective_seed': 42, 'attempt_id': attempt, 'ordinal': ordinal, 'q1_run_id': 'run-' + attempt, 'source_relpath': 'runs/' + attempt + '/diag/manifest.json', 'source_sha256': 'c' * 64}
            identities = {k: {'sha256': None} for k in extract.IDENTITIES}
            identities.update({'RI-SESSION': [session], 'RI-OPEN': [], 'RI-CAP': []})
            obs[attempt] = {'identities': identities, 'seed': {'certified': True}, 'manifests': [{'effective_seed': 42, 'generation_config': {}}]}
        pairs = aggregate.comparisons(refs, obs)
        result = next(r for r in pairs if r['identity'] == 'RI-SESSION')
        return result, aggregate.session_timing(refs, obs, pairs), obs

    def test_session_tick_only_difference_is_match_and_timing_different(self):
        row, timing, obs = self.session_pair(lambda steps, choices: choices[0].update(physics_tick=99))
        self.assertEqual((row['eligibility'], row['observation']), ('EQUALITY_ELIGIBLE', 'MATCH'))
        self.assertEqual(timing['label'], 'REPEATABILITY_OBSERVATION')
        self.assertFalse(timing['equality_claim'])
        self.assertEqual((timing['comparisons'][0]['observation'], timing['comparisons'][0]['a_ticks'], timing['comparisons'][0]['b_ticks']), ('DIFFERENT', [[42, [18]]], [[42, [99]]]))
        self.assertEqual(timing['values'][0]['source_relpath'], 'runs/23/diag/manifest.json')
        self.assertEqual(set(obs['23']['identities']['RI-SESSION'][0]['decisions'][0]), {'fork_id', 'choice', 'selected_branch_id', 'selected_seed'})

    def test_session_selected_arm_difference_is_mismatch(self):
        row, timing, obs = self.session_pair(lambda steps, choices: steps[1].update(signature='d' * 64))
        self.assertEqual(row['observation'], 'MISMATCH')
        self.assertEqual(timing['comparisons'][0]['observation'], 'IDENTICAL')
        self.assertNotEqual(obs['23']['identities']['RI-SESSION'][0]['checkpoints'][1], obs['24']['identities']['RI-SESSION'][0]['checkpoints'][1])

    def test_session_deterministic_decision_difference_is_mismatch(self):
        for field in ['fork_id', 'choice', 'selected_branch_id', 'selected_seed']:
            with self.subTest(field=field):
                row, timing, obs = self.session_pair(lambda steps, choices: choices[0].update({field: 999}))
                self.assertEqual(row['observation'], 'MISMATCH')
                self.assertEqual(timing['comparisons'][0]['observation'], 'IDENTICAL')

    def test_session_future_incidental_fields_do_not_enter_hash(self):
        row, timing, obs = self.session_pair(lambda steps, choices: choices[0].update(frame_counter=200, timestamp='tomorrow', scheduler={'queue': 99}))
        self.assertEqual(row['observation'], 'MATCH')
        self.assertEqual(obs['23']['identities']['RI-SESSION'][0]['sha256'], obs['24']['identities']['RI-SESSION'][0]['sha256'])
        self.assertEqual(timing['comparisons'][0]['observation'], 'IDENTICAL')

    def test_wall_values_are_stratified_by_observer_and_workload(self):
        refs = [{'suite_id': 's', 'configuration': {'mode': 'headless'}, 'observer_mode': mode, 'statistics_role': role, 'attempt_ordinal': i, 'duration_ms': ms} for i, (mode, role, ms) in enumerate([('OFF', 'measured', 10), ('OFF', 'warmup_excluded', 100), ('POLL-250ms', 'memory', 1000), ('OFF', 'measured', 20)], 1)]
        before = cjson.canonical(refs)
        groups = aggregate.wall_statistics(refs)
        actual = {(g['observer_mode'], g['workload_role']): g['statistics'] for g in groups}
        self.assertEqual(actual[('OFF', 'measured')], {'raw': ['10', '20'], 'n': 2, 'median': '15', 'min': '10', 'max': '20'})
        self.assertEqual(actual[('OFF', 'warmup_excluded')]['raw'], ['100'])
        self.assertEqual(actual[('POLL-250ms', 'memory')]['raw'], ['1000'])
        self.assertEqual(cjson.canonical(refs), before)
        refs[2].update(phase='P5', statistics_role='baseline')
        self.assertEqual([g['workload_role'] for g in aggregate.wall_statistics(refs) if g['observer_mode'] == 'POLL-250ms'], ['memory_evidence'])

    def test_compact_all_attempts_external_hash_budget_and_raw_immutability(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            fields = ['attempt_id', 'invocation_id', 'row_id', 'suite_id', 'round', 'phase', 'statistics_role', 'q1_run_id', 'q1_check_relpath', 'q1_result_json_sha256', 'directory_digest', 'evidence_status', 'observer_mode']
            refs = [{**{k: str(i) for k in fields}, 'attempt_ordinal': i, 'required': i > 22, 'q1_result': 'FAIL' if i == 188 else 'PASS', 'q1_reason_code': 'R', 'q1_reasons': [], 'retry_of': None, 'evidence_problems': [], 'exit_code': 0, 'duration_ms': i, 'seed_config': {'requested': 42}, 'configuration': {'mode': 'headless'}} for i in range(1, 189)]
            full = {'schema_version': 'slow-cycle.baseline/1', 'representation': 'full-external/1', 'baseline_id': 'b', 'campaign_freeze_revision': 'f', 'attempt_plan': [{'ordinal': i} for i in range(1, 189)], 'run_refs': refs, 'determinism': [], 'road_identity': {}, 'environment': {'pre': {'user_data_listing': []}, 'post': {'user_data_listing': []}}, **{k: [] for k in ['branch', 'streaming', 'cross_suite_opening_observations', 'messages']}}
            for path in ['ledger.jsonl', 'env/pre.json', 'observer/series.jsonl', 'runs/r/checks/s/result.json']:
                p = root / path; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b'raw immutable')
            before = cjson.inventory(root)
            aggregate.artifact_closure(root, full)
            compact = aggregate.compact_record(root, full)
            self.assertEqual([r['attempt_ordinal'] for r in compact['run_refs']], list(range(1, 189)))
            self.assertEqual(compact['known_failures'][0]['attempt_ordinal'], 188)
            self.assertEqual(compact['run_refs'][0]['seed_config'], {'requested': 42})
            self.assertEqual(compact['full_external_report']['sha256'], cjson.sha(root / 'aggregate/baseline.json'))
            self.assertEqual(compact['full_external_report']['bytes'], (root / 'aggregate/baseline.json').stat().st_size)
            self.assertLess(aggregate.check_repository_budget(compact, b'index\n', 500), 1000000)
            with self.assertRaisesRegex(ValueError, 'budget exceeded'):
                aggregate.check_repository_budget(compact, b'x' * 1000000)
            for path, size, sha in before:
                self.assertEqual((root / path).stat().st_size, size); self.assertEqual(cjson.sha(root / path), sha)
            full['run_refs'] = refs[:-1]; cjson.write(root / 'aggregate/baseline.json', full)
            with self.assertRaisesRegex(ValueError, 'accountability'):
                aggregate.compact_record(root, full)

    def test_payload_and_closure_hashes_have_no_recursion(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root / 'aggregate').mkdir()
            (root / 'raw.log').write_bytes(b'raw evidence')
            (root / 'aggregate/repository_artifact_index.txt').write_text('derived closure', encoding='utf-8')
            (root / 'artifact_index.txt').write_text('repository index containing payload digest', encoding='utf-8')
            baseline = {'schema_version': 'test'}
            closure = aggregate.artifact_closure(root, baseline)
            index = (root / 'aggregate/artifact_index_full.txt').read_bytes()
            self.assertEqual(index, ('%s 12 raw.log\n' % cjson.sha(root / 'raw.log')).encode())
            self.assertEqual(baseline['artifact_manifest']['payload_evidence_digest']['artifact_root_digest'], cjson.sha(root / 'aggregate/artifact_index_full.txt'))
            for item in closure:
                self.assertEqual(item['sha256'], cjson.sha(root / item['relpath']))
            self.assertNotIn('SHA256SUMS\n', (root / 'SHA256SUMS').read_text())
            baseline['new_metadata'] = 'changed'
            closure2 = aggregate.artifact_closure(root, baseline)
            self.assertEqual(index, (root / 'aggregate/artifact_index_full.txt').read_bytes())
            self.assertNotEqual(closure[-1]['sha256'], closure2[-1]['sha256'])
            (root / 'raw.log').write_bytes(b'changed raw')
            aggregate.artifact_closure(root, baseline)
            self.assertNotEqual(index, (root / 'aggregate/artifact_index_full.txt').read_bytes())

    def test_role_uses_full_executable_identity_and_parent(self):
        observer = Observer(10, 100, Path('unused.jsonl'), sc_baseline.Path('C:/tools/Godot_console.exe'))
        self.assertEqual(observer.classify('C:/tools/Godot_console.exe', 10), ('console_wrapper', True, True))
        observer.records[20] = {'role': 'console_wrapper'}
        self.assertEqual(observer.classify('C:/tools/Godot.exe', 20), ('godot_main', True, True))
        self.assertEqual(observer.classify('C:/tools/Godot.exe', 99), ('godot_main', True, False))
        self.assertEqual(observer.classify('C:/other/Godot.exe', 20), ('incidental_helper', False, True))
        self.assertEqual(observer.classify('C:/tools/git.exe', 20), ('incidental_helper', False, True))

    def test_incidental_access_error_visible_required_error_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for name in ['result.json', 'stdout.log', 'stderr.log', 'engine.log']:
                (root / name).write_bytes(b'')
            parts = [{'pid': 1, 'parent_pid': 0, 'role': 'console_wrapper'}, {'pid': 2, 'parent_pid': 1, 'role': 'godot_main'}]
            parts = [{**p, 'required': True, 'sample_count': 2, 'exited': True, 'exit_100ns': '123', 'post_exit_query': 'OK'} for p in parts]
            error = {'pid': 3, 'name': 'git.exe', 'error': 87, 'role': 'incidental_helper', 'required': False}
            memory = {'processes': parts, 'errors': [error]}
            with patch('sc_baseline.extract.extract', return_value={'manifests': [], 'identities': {'RI-CAP': []}}):
                self.assertEqual(sc_baseline.evidence_status(root, {'process': {'pid': 1}}, memory), ('CAPTURED', []))
                self.assertEqual(memory['errors'], [error])
                memory['errors'].append({**error, 'role': 'required_target_unresolved', 'required': True})
                self.assertEqual(sc_baseline.evidence_status(root, {'process': {'pid': 1}}, memory)[0], 'INFRA_FAILED')
                memory['errors'] = []; memory['processes'] = parts[:1]
                self.assertEqual(sc_baseline.evidence_status(root, {'process': {'pid': 1}}, memory)[0], 'INFRA_FAILED')

    def test_exit_summary_matches_authoritative_raw_event_and_sample(self):
        observer = Observer(0, 100, Path('unused.jsonl'))
        def times(handle, creation, exit_time, kernel, user):
            for pointer, value in zip([creation, exit_time, kernel, user], [100, 200, 3, 4]):
                ct.cast(pointer, ct.POINTER(wt.FILETIME)).contents.dwLowDateTime = value
            return True
        def counters(handle, pointer, size):
            m = ct.cast(pointer, ct.POINTER(Memory)).contents
            m.WorkingSetSize, m.PrivateUsage, m.PeakWorkingSetSize, m.PeakPagefileUsage = 10, 11, 20, 21
            return True
        observer.k = SimpleNamespace(WaitForSingleObject=lambda *args: 0, K32GetProcessMemoryInfo=counters, GetProcessTimes=times, CloseHandle=lambda *args: True)
        observer.thread = SimpleNamespace(join=lambda: None)
        observer.handles = {1: 1}
        observer.records = {1: {'exited': False, 'samples': [], 'exit_100ns': None, 'required': True}}
        out = io.BytesIO(); observer.query(1, out)
        raw = [json.loads(line) for line in out.getvalue().splitlines()]
        summary = observer.finish()['processes'][0]
        self.assertEqual([x['exit_100ns'] for x in raw], ['200', '200'])
        self.assertEqual(summary['exit_100ns'], raw[-1]['exit_100ns'])
        self.assertEqual(summary['post_exit_query'], 'OK')
        self.assertEqual(summary['os_peak_working_set_bytes'], 20)
        self.assertEqual(summary['sampled_peak_working_set_bytes'], 10)
        self.assertEqual(summary['cpu_user_100ns'], 4)

    def test_failed_post_exit_counters_keep_until_last_query_labels(self):
        observer = Observer(0, 100, Path('unused.jsonl'))
        observer.k = SimpleNamespace(WaitForSingleObject=lambda *args: 0, K32GetProcessMemoryInfo=lambda *args: False, CloseHandle=lambda *args: True)
        observer.thread = SimpleNamespace(join=lambda: None)
        previous = {'timestamp': 'before', 'working_set_bytes': 10, 'private_bytes': 11, 'os_peak_working_set_bytes': 20, 'os_peak_commit_bytes': 21}
        observer.handles = {1: 1}
        observer.records = {1: {'exited': False, 'samples': [previous], 'exit_100ns': None, 'required': True}}
        timing = {'creation_100ns': '100', 'exit_100ns': '200', 'cpu_kernel_100ns': 3, 'cpu_user_100ns': 4}
        out = io.BytesIO()
        with patch.object(observer, 'times', return_value=timing), patch('ctypes.get_last_error', return_value=5):
            observer.query(1, out)
        summary = observer.finish()['processes'][0]
        self.assertEqual(summary['post_exit_query'], 'FAILED(5)')
        self.assertEqual(summary['exit_100ns'], json.loads(out.getvalue())['exit_100ns'])
        self.assertEqual(summary['os_peak_working_set_bytes_until_last_query'], 20)
        self.assertEqual(summary['last_query_timestamp'], 'before')
        self.assertNotIn('os_peak_working_set_bytes', summary)

    def test_discovery_records_helper_and_required_access_failures(self):
        observer = Observer(10, 100, Path('unused.jsonl'), Path('C:/tools/Godot_console.exe'))
        observer.k = SimpleNamespace(OpenProcess=lambda *args: None)
        with patch('ctypes.get_last_error', return_value=87):
            observer.discover({11: (10, 'git.exe'), 12: (10, 'Godot_console.exe')})
        self.assertEqual([(e['pid'], e['name'], e['error'], e['role'], e['required']) for e in observer.errors], [(11, 'git.exe', 87, 'incidental_helper', False), (12, 'Godot_console.exe', 87, 'required_target_unresolved', True)])

    def test_calibration_report_producer_serializes_tuple_status_as_list(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            q1 = {'result': 'FAIL', 'reason_code': 'ASSERTION_FAILED', 'reasons': ['assertion'], 'duration': '1.0', 'completion_marker': {'satisfied': False}, 'actual_coverage': []}
            cjson.write(root / 'runs/r/checks/s/result.json', q1)
            with patch('sc_baseline.extract.extract', return_value={'identities': {'RI-OPEN': []}, 'metrics': {}}), patch('sc_baseline.evidence_status', return_value=('INFRA_FAILED', ['P5_observer_failure'])):
                report = sc_baseline.calibration_report(root, 'r', 2, {'errors': []}, ['s'])
            cjson.validate(report)
            cjson.write(root / 'calibration_report.json', report)
            self.assertEqual(cjson.load(root / 'calibration_report.json')['rows'][0]['status'], ['INFRA_FAILED', ['P5_observer_failure']])
            with self.assertRaises(ValueError):
                cjson.canonical({'unexpected': ('INFRA_FAILED', [])})

    def test_observer_start_method_is_not_shadowed_by_timestamp(self):
        observer = Observer(0, 116444736000000000, Path('not-started.jsonl'))
        self.assertTrue(callable(observer.start))
        self.assertEqual(observer.invocation_start, 116444736000000000)

    def test_required_gap_blocks_but_product_fail_does_not(self):
        r = {'attempt_ordinal': 23, 'q1_result': 'FAIL', 'evidence_status': 'CAPTURED', 'retry_of': None}
        self.assertEqual(aggregate.gap_status([r]), ('CAPTURED', []))
        r['q1_result'] = 'INCOMPLETE'
        self.assertEqual(aggregate.gap_status([r]), ('AWAITING_HUMAN_GAP_DECISION', [23]))
        self.assertEqual(aggregate.gap_status([r], [{'ordinal': 23}]), ('CAPTURED_WITH_ACCEPTED_GAPS', []))

    def test_observer_failure_keeps_q1_verdict(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            for f in ['result.json', 'stdout.log', 'stderr.log', 'engine.log']:
                (p / f).write_bytes(b'')
            result = {'process': {'pid': 123}, 'result': 'PASS'}
            status, why = sc_baseline.evidence_status(p, result, {'processes': [], 'errors': [{'reason': 'OpenProcess denied'}]})
            self.assertEqual((status, why, result['result']), ('INFRA_FAILED', ['P5_observer_failure'], 'PASS'))

    def test_run_directory_mismatch_and_result_tamper(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            check = root / 'runs/r1/checks/s'
            check.mkdir(parents=True)
            c = {'invocations': [{'invocation_id': 'i'}], 'attempts': [{'ordinal': 1, 'suite_id': 's', 'invocation_id': 'i', 'attempt_id': 'a'}]}
            cjson.write(check / 'result.json', {'result': 'PASS', 'reason_code': 'R', 'reasons': []})
            cjson.write(root / 'runs/r1/run.json', {'selected': ['s'], 'not_run': []})
            log = ledger.Ledger(root / 'ledger.jsonl', cjson.digest(c))
            identity = {'campaign_definition_digest': cjson.digest(c), 'campaign_freeze_revision': 'f', 'runtime_base_revision': 'b'}
            log.append('CAMPAIGN_START', **identity)
            log.append('INVOCATION_START', invocation_id='i', argv=['q1'])
            log.append('INVOCATION_END', invocation_id='i', argv=['q1'], q1_run_id='r1', attempts=[{**identity, 'q1_check_relpath': 'runs/r1/checks/s', 'q1_result_json_sha256': cjson.sha(check / 'result.json'), 'directory_digest': cjson.digest(cjson.inventory(check)), 'attempt_ordinal': 1, 'suite_id': 's', 'invocation_id': 'i', 'attempt_id': 'a', 'retry_of': None, 'q1_result': 'PASS', 'q1_reason_code': 'R', 'q1_reasons': []}])
            self.assertEqual(aggregate.reconcile(root, c, True)['executed_attempts'], 1)
            (root / 'runs/extra').mkdir()
            with self.assertRaisesRegex(ValueError, 'missing or extra'):
                aggregate.reconcile(root, c, True)
            (root / 'runs/extra').rmdir()
            (root / 'runs/r1').rename(root / 'held')
            with self.assertRaisesRegex(ValueError, 'missing or extra'):
                aggregate.reconcile(root, c, True)
            (root / 'held').rename(root / 'runs/r1')
            cjson.write(check / 'result.json', {'result': 'FAIL', 'reason_code': 'R', 'reasons': []})
            with self.assertRaisesRegex(ValueError, 'result.json changed'):
                aggregate.reconcile(root, c, True)

    def test_product_fail_never_retried(self):
        r = {'q1_result': 'FAIL', 'q1_reasons': ['LOG_INCOMPLETE'], 'suite_id': 's'}
        self.assertFalse(sc_baseline.retry_allowed(r, Path('.')))
