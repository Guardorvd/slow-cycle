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
from q2a import aggregate, cjson, ledger


class Integrity(unittest.TestCase):
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
