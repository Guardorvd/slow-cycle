import unittest
import tempfile
from pathlib import Path
from q2a import cjson
from q2a import extract, envinfo


class Observations(unittest.TestCase):
    def test_capture_reference_provenance_and_missing_malformed_metadata(self):
        with tempfile.TemporaryDirectory() as d:
            check = Path(d); manifest = check / 'audit/session/manifest.json'
            source = manifest.with_name('frame.json')
            config = {'randomize_on_start': False}
            frame = {'metadata': 'frame.json', 'png': 'frame.png', 'seed': 42}
            content = {'frames': [frame], 'sessions': [{'actual_generator_seed': 42, 'generation_config': config}]}
            meta = {'seeds': {**{k: 42 for k in ['actual_generator_seed', 'expected_effective_seed', 'manager_seed', 'streamer_seed']}, 'generation_config': config}, 'geometry_checkpoint': {'signature': 'a' * 64, 'range_m': [0, 100], 'step_m': 2}, 'png': 'frame.png', 'run_id': 'session'}
            cjson.write(source, meta)
            before = source.read_bytes()
            row = extract.capture_values(manifest, check, content)[0]
            self.assertEqual((row['status'], row['signature'], row['source_relpath'], row['source_sha256'], row['seed'], row['generation_config']), ('OBSERVED', 'a' * 64, 'audit/session/frame.json', cjson.sha(source), 42, config))
            self.assertEqual(source.read_bytes(), before)
            frame['metadata'] = 'C:/old/root/audit/session/frame.json'
            self.assertEqual(extract.capture_values(manifest, check, content)[0]['signature'], 'a' * 64)
            frame['metadata'] = '../frame.json'
            self.assertEqual(extract.capture_values(manifest, check, content)[0]['status'], 'NOT_COMPARABLE')
            frame['metadata'] = 'absent.json'
            row = extract.capture_values(manifest, check, content)[0]
            self.assertEqual((row['status'], row['signature'], row['source_sha256']), ('NOT_OBSERVED', None, None))
            frame['metadata'] = 'frame.json'; source.write_text('{broken', encoding='utf-8')
            row = extract.capture_values(manifest, check, content)[0]
            self.assertEqual((row['status'], row['signature']), ('NOT_COMPARABLE', None))
            cjson.write(source, {**meta, 'seeds': {**meta['seeds'], 'actual_generator_seed': 777}})
            self.assertEqual(extract.capture_values(manifest, check, content)[0]['status'], 'NOT_COMPARABLE')

    def test_microsecond_compatibility_does_not_scale_or_mutate_raw(self):
        raw = {'user_data_listing': [{'name': 'log', 'bytes': 20, 'mtime_ns': 1791048844364556}]}
        before = cjson.canonical(raw)
        view = envinfo.reporting_view(raw)
        self.assertEqual(view['user_data_listing'][0]['mtime_us'], 1791048844364556)
        self.assertNotIn('mtime_ns', view['user_data_listing'][0])
        self.assertEqual(cjson.canonical(raw), before)

    def test_real_calibration_metric_formats(self):
        samples = cjson.load(Path(__file__).parent / 'samples/calibration_adapters.json')
        self.assertEqual(len(samples['rows']), 12)
        text = '\n'.join(row['excerpt'] for row in samples['rows']).encode('utf-8')
        expected = {'branch_commit_avg_ms': '0.804', 'branch_commit_max_ms': '0.997', 'carver_math_ms': '104.56', 'carver_mesh_ms': '35.18', 'carver_trimesh_ms': '11.04', 'grammar_generation_total_ms': '212.307', 'grammar_generation_avg_ms': '1.062', 'grammar_validator_total_ms': '13.089', 'grammar_validator_avg_ms': '0.065', 'road_validation_ms': '6.425', 'rider_progress_m': '303.9', 'rider_integrity': 'YES'}
        for name, value in expected.items():
            with self.subTest(name=name):
                self.assertIn(value, extract.metric(text, extract.PATTERNS[name])['values'])

    def test_missing_metric_is_not_zero(self):
        self.assertEqual(extract.metric(b'no benchmark', extract.PATTERNS['carver_math_ms']), {'status': 'NOT_OBSERVED', 'values': []})

    def test_decode_error_never_has_a_comparison_hash(self):
        self.assertEqual(extract.text_identity(b'ROUTE mode=x \xff', '^ROUTE')['status'], 'NOT_COMPARABLE(decode_error)')

    def test_soak_memory_removed_from_structure_only(self):
        a = extract.text_identity(b'[MILESTONE] 50 | RAM: 50.0 MB | Pos Y: -1.0', r'\[MILESTONE\]', soak=True)
        b = extract.text_identity(b'[MILESTONE] 50 | RAM: 90.0 MB | Pos Y: -1.0', r'\[MILESTONE\]', soak=True)
        self.assertEqual(a['sha256'], b['sha256'])

    def test_uncontrolled_even_coincidentally_equal_is_ineligible(self):
        a = {'suite_id': 'q2a_soak_asis', 'configuration': {}, 'engine_sha256': 'e', 'seed_context': [184729], 'seed_trusted': True}
        self.assertEqual(extract.eligibility(a, a, 'RI-SOAKSTRUCT'), 'EXCLUDED_FROM_EQUALITY')
        a['suite_id'] = 'q2a_rider_s42'
        self.assertEqual(extract.eligibility(a, a, 'RI-RIDE'), 'REPEATABILITY_OBSERVATION')
        self.assertEqual(extract.eligibility(a, a, 'RI-OPEN'), 'EQUALITY_ELIGIBLE')

    def test_statistics_keep_all_five_and_outlier(self):
        s = extract.stats(['1.0', '1.1', '99.0', '0.9', '1.2'])
        self.assertEqual((s['n'], s['median'], s['min'], s['max']), (5, '1.1', '0.9', '99.0'))
        self.assertEqual(s['raw'][2], '99.0')
        self.assertNotIn('p95', s)
