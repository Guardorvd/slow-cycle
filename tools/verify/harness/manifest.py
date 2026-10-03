"""suites.json loading and validation, plus the TEST_MATRIX cross-check (harness never reclassifies rows)."""
import json
import os
import re

from . import identity

KINDS = ("check", "expected_negative")
REQUIRED = ("id", "kind", "origin", "entry", "launch", "matrix")
ROW = re.compile(r"^\|\s*([A-Z][A-Za-z0-9_-]*)\s+·\s+L\d+\s*\|\s*([A-Z_]+|N/A)")


class ManifestError(Exception):
    def __init__(self, code, detail):
        super().__init__("%s: %s" % (code, detail))
        self.code, self.detail = code, detail


def load(path):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ManifestError("HARNESS_MANIFEST_INVALID", "cannot parse %s: %s" % (path, exc))
    seen = set()
    for s in data.get("suites", []):
        for key in REQUIRED:
            if key not in s:
                raise ManifestError("HARNESS_MANIFEST_INVALID", "suite %s missing '%s'" % (s.get("id"), key))
        if s["id"] in seen or not identity.SAFE_ID.match(s["id"]):
            raise ManifestError("HARNESS_MANIFEST_INVALID", "bad or duplicate id %r" % s["id"])
        seen.add(s["id"])
        if s["kind"] not in KINDS or s["origin"] not in ("repo", "probe"):
            raise ManifestError("HARNESS_MANIFEST_INVALID", "suite %s: bad kind/origin" % s["id"])
        for group in ("completion", "coverage", "summaries"):
            for item in s.get(group, []):
                for key in ("pattern",):
                    if key in item:
                        _compile(s["id"], item[key])
        for pat in s.get("fail_markers", []) + s.get("engine_policy", {}).get("expected", []):
            _compile(s["id"], pat)
        if s["kind"] == "expected_negative" and "expected_negative" not in s:
            raise ManifestError("HARNESS_MANIFEST_INVALID", "suite %s lacks expected_negative" % s["id"])
        if s["origin"] == "probe" and "expected_verdict" not in s:
            raise ManifestError("HARNESS_MANIFEST_INVALID", "probe %s lacks expected_verdict" % s["id"])
    for name, ids in data.get("sets", {}).items():
        for i in ids:
            if i not in seen:
                raise ManifestError("HARNESS_UNKNOWN_SUITE", "set %s references unknown suite %s" % (name, i))
    for e in data.get("environment_allowlist", []):
        if not e.get("text") or not e.get("rationale") or not e.get("scope"):
            raise ManifestError("HARNESS_MANIFEST_INVALID", "allowlist entries need exact text, rationale and scope")
        if e.get("regex") or "permission" == e["text"].strip().lower():
            raise ManifestError("HARNESS_MANIFEST_INVALID", "allowlist is exact-text only; rejected %r" % e["text"])
    return data


def _compile(sid, pattern):
    try:
        re.compile(pattern)
    except re.error as exc:
        raise ManifestError("HARNESS_MANIFEST_INVALID", "suite %s: bad regex %r: %s" % (sid, pattern, exc))


def matrix_rows(repo, rel):
    rows = {}
    for line in open(os.path.join(repo, rel), encoding="utf-8").read().splitlines():
        m = ROW.match(line)
        if m:
            rows[m.group(1)] = m.group(2)
    return rows


def check_matrix(repo, data, suites=None):
    """Raise MANIFEST_MATRIX_MISMATCH unless the matrix is the accepted one and every row/category agrees."""
    mx = data["matrix"]
    ident = identity.file_identity(repo, mx["path"])
    problems = []
    if ident["dirty"]:
        problems.append("matrix file differs from HEAD (dirty)")
    if ident["git_blob_head"] != mx["git_blob"]:
        problems.append("git blob %s != declared %s" % (ident["git_blob_head"], mx["git_blob"]))
    if ident["compat_lf_sha256"] != mx["accepted_lf_sha256"]:
        problems.append("LF-compat sha256 %s != accepted %s" % (ident["compat_lf_sha256"], mx["accepted_lf_sha256"]))
    rows = matrix_rows(repo, mx["path"])
    for s in (suites if suites is not None else data["suites"]):
        if s["origin"] == "probe":
            continue
        if not os.path.isfile(os.path.join(repo, s["entry"].replace("res://", ""))):
            problems.append("%s: entry %s not found" % (s["id"], s["entry"]))
        for rid, cat in s["matrix"].get("categories", {}).items():
            if rid not in rows:
                problems.append("%s: matrix row %s not found" % (s["id"], rid))
            elif rows[rid] != cat:
                problems.append("%s: row %s category %s != matrix %s" % (s["id"], rid, cat, rows[rid]))
    if problems:
        raise ManifestError("MANIFEST_MATRIX_MISMATCH", "; ".join(problems))
    return {"matrix_identity": ident, "rows_in_matrix": len(rows)}
