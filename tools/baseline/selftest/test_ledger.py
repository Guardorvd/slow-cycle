import tempfile
import unittest
from pathlib import Path
from q2a import ledger


class Chain(unittest.TestCase):
    def test_edits_deletions_and_reordering_detected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'ledger.jsonl'
            writer = ledger.Ledger(p, 'a' * 64)
            for n in range(3):
                writer.append('PREFLIGHT', n=n)
            raw = p.read_bytes()
            self.assertEqual(len(ledger.read(p, 'a' * 64)[0]), 3)
            lines = raw.splitlines(keepends=True)
            for bad in [lines[0] + lines[2], lines[1] + lines[0] + lines[2], raw.replace(b'"n":1', b'"n":9')]:
                p.write_bytes(bad)
                with self.assertRaises(ValueError):
                    ledger.read(p, 'a' * 64)

    def test_writer_refuses_changed_chain(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'ledger.jsonl'
            writer = ledger.Ledger(p, 'b' * 64)
            writer.append('PREFLIGHT', n=0)
            p.write_bytes(p.read_bytes().replace(b'"n":0', b'"n":1'))
            with self.assertRaises(ValueError):
                writer.append('PREFLIGHT', n=2)
