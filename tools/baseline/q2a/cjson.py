"""Approved canonical JSON and raw artifact identities."""
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path


def validate(x):
    if x is None or type(x) in (str, bool):
        return
    if type(x) is int and abs(x) < 2**53:
        return
    if type(x) is list:
        for v in x:
            validate(v)
        return
    if type(x) is dict and all(type(k) is str for k in x):
        for v in x.values():
            validate(v)
        return
    raise ValueError('non-CJSON value: ' + type(x).__name__)


def canonical(x):
    validate(x)
    return json.dumps(x, sort_keys=True, separators=(',', ':'), ensure_ascii=True, allow_nan=False).encode('ascii')


def digest(x):
    return hashlib.sha256(canonical(x)).hexdigest()


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'), parse_float=str)


def write(path, obj):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + '.tmp')
    with tmp.open('wb') as f:
        f.write(canonical(obj) + b'\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, p)


def utc():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def inventory(root, exclude=()):
    root = Path(root)
    return [[p.relative_to(root).as_posix(), p.stat().st_size, sha(p)]
            for p in sorted(root.rglob('*'), key=lambda p: p.relative_to(root).as_posix().encode('utf-8'))
            if p.is_file() and p.relative_to(root).as_posix() not in exclude]
