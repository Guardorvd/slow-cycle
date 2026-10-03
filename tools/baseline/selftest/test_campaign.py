import copy
import json
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch
import sc_baseline
from q2a import campaign, cjson


class Campaign(unittest.TestCase):
    def test_freeze_receipt_binds_blobs_and_refuses_mutation(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'receipt.json'
            proof = {'roots': {'scripts': {'base': 'same', 'candidate': 'same'}}}
            expected = {'schema': 'slow-cycle.baseline.freeze-receipt/1', 'timestamp_utc': '2026-10-03T00:00:00.000000Z', 'runtime_base_revision': campaign.BASE, 'campaign_freeze_revision': 'f', 'campaign_definition_digest': 'd', 'git_blob_identities': {'implementation_plan.md': {'git_blob': 'blob', 'sha256': 'sha', 'bytes': 10}}, 'protected_runtime_identity_proof': proof}
            cjson.write(path, expected)
            with patch('q2a.campaign.receipt', return_value=expected):
                identity = campaign.validate_receipt('.', path, 'f', 'd')
                self.assertEqual(identity['sha256'], cjson.sha(path))
                edited = copy.deepcopy(expected); edited['campaign_freeze_revision'] = 'other'
                cjson.write(path, edited)
                with self.assertRaisesRegex(ValueError, 'receipt identity'):
                    campaign.validate_receipt('.', path, 'f', 'd')

    def setUp(self):
        self.data = json.loads((sc_baseline.REPO / 'tools/verify/suites.json').read_text(encoding='utf-8'))
        self.c = campaign.build(self.data)

    def test_exact_matrix_and_seeds(self):
        campaign.validate(self.c, self.data)
        self.assertEqual((len(self.c['entries']), len(self.c['invocations']), len(self.c['attempts'])), (24, 29, 188))
        self.assertEqual([a['ordinal'] for a in self.c['attempts']], list(range(1, 189)))
        self.assertEqual([a['suite_id'] for a in self.c['attempts'][48:55]], campaign.RIDE)
        self.assertEqual([a['ordinal'] for a in self.c['attempts'] if a['statistics_role'] == 'measured'], list(range(112, 137)))
        self.assertEqual([i['phase'] for i in self.c['invocations'] if i['observer_mode'] != 'OFF'], ['P5', 'P5'])

    def test_seed_or_order_or_metric_changes_rejected(self):
        for key in ['seeds', 'attempts', 'invocations', 'metrics']:
            c = copy.deepcopy(self.c)
            c[key] = []
            with self.subTest(key=key), self.assertRaises(ValueError):
                campaign.validate(c, self.data)

    def test_dirty_or_moved_head_refused_before_launch(self):
        for head, status in [('other', ''), ('freeze', ' M project.godot')]:
            with patch('q2a.campaign.git', side_effect=[head, status]), patch('subprocess.Popen') as spawn:
                with self.assertRaises(ValueError):
                    sc_baseline.boundary(self.c, 'freeze', 'engine', 'sha')
                spawn.assert_not_called()

    def test_changed_campaign_digest_refused(self):
        changed = copy.deepcopy(self.c)
        changed['task'] = 'altered'
        with patch('q2a.campaign.git', side_effect=['freeze', '', json.dumps(changed)]), self.assertRaises(ValueError):
            sc_baseline.boundary(self.c, 'freeze', 'engine', 'sha')

    def test_additive_proof(self):
        frozen = campaign.git(sc_baseline.REPO, 'ls-tree', 'HEAD', 'tools/baseline/q2a_campaign.json')
        proof = campaign.proof(sc_baseline.REPO, working=not bool(frozen))
        self.assertEqual((proof['existing_suites'], proof['appended_suites']), (42, 24))
