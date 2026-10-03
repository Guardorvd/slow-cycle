"""Append-only/fsynced hash chain; attempts stay in their original records."""
import hashlib
import json
import os
from pathlib import Path
from . import cjson


def genesis(campaign_digest):
    return hashlib.sha256(('slow-cycle/q2a/ledger-genesis/' + campaign_digest).encode('ascii')).hexdigest()


def read(path, campaign_digest):
    prev, records = genesis(campaign_digest), []
    for line in Path(path).read_bytes().splitlines(keepends=True):
        rec = json.loads(line)
        h = rec.pop('record_sha256')
        if rec['prev_record_sha256'] != prev or h != cjson.digest(rec):
            raise ValueError('ledger chain break')
        rec['record_sha256'] = h
        if cjson.canonical(rec) + b'\n' != line:
            raise ValueError('non-canonical ledger line')
        records.append(rec)
        prev = h
    return records, prev


class Ledger:
    def __init__(self, path, campaign_digest):
        self.path, self.digest = Path(path), campaign_digest
        self.head = read(self.path, campaign_digest)[1] if self.path.exists() else genesis(campaign_digest)

    def append(self, kind, **fields):
        if self.path.exists() and read(self.path, self.digest)[1] != self.head:
            raise ValueError('ledger changed behind writer')
        r = {'schema': 'slow-cycle.baseline.ledger/1', 'type': kind, 'timestamp': cjson.utc(), 'prev_record_sha256': self.head, **fields}
        r['record_sha256'] = cjson.digest(r)
        with self.path.open('ab') as f:
            f.write(cjson.canonical(r) + b'\n')
            f.flush()
            os.fsync(f.fileno())
        self.head = r['record_sha256']
        return r
