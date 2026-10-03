import unittest
from pathlib import Path
from q2a import cjson
from q2a import extract


class Observations(unittest.TestCase):
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
