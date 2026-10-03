"""Extract facts from raw engine output and produced artifacts. Facts only: no verdicts live here.

Engine message formats were calibrated against Godot 4.7.2 (selftest/samples/*.log):
  ERROR: ... / WARNING: ... / SCRIPT ERROR: ... followed by indented `at:` / backtrace lines,
  `WARNING: N ObjectDB instances were leaked at exit`.
"""
import glob
import json
import os
import re

MSG_START = re.compile(r"^(SCRIPT ERROR|USER SCRIPT ERROR|USER ERROR|ERROR|USER WARNING|WARNING):\s?(.*)$")
CONTINUATION = re.compile(r"^\s+(at:|GDScript backtrace|\[\d+\])")
LEAK = re.compile(r"ObjectDB instances? (?:was|were) leaked|resources? still in use at exit|RID allocations? of .* leaked|"
                  r"Pages in use exist at exit|leaked at exit", re.I)
PARSE = re.compile(r"Parse Error|with error \"Parse error\"")
ASSERT = re.compile(r"Assertion failed")
PNG_SIG = b"\x89PNG\r\n\x1a\n"


def read_text(path):
    """Decoded text for parsing only (CRLF folded to LF so line anchors work); raw bytes stay untouched on disk."""
    try:
        return open(path, "rb").read().decode("utf-8", "replace").replace("\r\n", "\n")
    except OSError:
        return ""


def parse_messages(stdout_text, stderr_text):
    """Return engine messages from both streams. Category is syntactic only."""
    msgs = []
    for stream, text in (("stdout", stdout_text), ("stderr", stderr_text)):
        cur = None
        for no, line in enumerate(text.splitlines(), 1):
            m = MSG_START.match(line)
            if m:
                kind, body = m.group(1), m.group(2)
                cat = _categorize(kind, body)
                cur = {"stream": stream, "line": no, "kind": kind, "category": cat, "text": line, "detail": []}
                msgs.append(cur)
            elif cur is not None and CONTINUATION.match(line):
                cur["detail"].append(line)
            else:
                cur = None
                if stream == "stderr" and line.strip():
                    msgs.append({"stream": stream, "line": no, "kind": "RAW", "category": "unknown", "text": line, "detail": []})
    return msgs


def _categorize(kind, body):
    if LEAK.search(body):
        return "leak"
    if kind in ("SCRIPT ERROR", "USER SCRIPT ERROR"):
        if PARSE.search(body):
            return "parse_error"
        if ASSERT.search(body):
            return "assertion_failed"
        return "script_error"
    if kind in ("ERROR", "USER ERROR"):
        return "parse_error" if PARSE.search(body) else "error"
    return "warning"


def split_messages(msgs, expected_res, env_allow):
    """Partition messages by declared policy. Matching is exact (env allowlist) or declared regex (expected).

    Nothing is dropped: every message appears in exactly one bucket, original text preserved.
    Kill policy lives in classify.py: a leak is a violation only for a normally completed run.
    """
    out = {"project_errors": [], "parse_errors": [], "script_errors": [], "assertion_failures": [], "warnings": [],
           "objectdb_or_leak_warnings": [], "expected_environment_messages": [], "expected_messages": [],
           "unknown_engine_messages": []}
    exact = {e["text"]: e for e in env_allow}
    for m in msgs:
        m = dict(m)
        if m["text"] in exact:
            m["rationale"] = exact[m["text"]].get("rationale")
            out["expected_environment_messages"].append(m)
            continue
        if any(re.search(p, m["text"]) for p in expected_res):
            out["expected_messages"].append(m)
            continue
        cat = m["category"]
        if cat == "leak":
            out["objectdb_or_leak_warnings"].append(m)
        elif cat == "warning":
            out["warnings"].append(m)
        elif cat == "unknown":
            out["unknown_engine_messages"].append(m)
        else:
            out["project_errors"].append(m)
            key = {"parse_error": "parse_errors", "assertion_failed": "assertion_failures"}.get(cat, "script_errors")
            out[key].append(m)
    return out


def _search(pattern, text):
    return re.search(pattern, text, re.M)


def eval_completion(spec, text, check_dir):
    observed = []
    for item in spec:
        ok, detail = False, None
        if item["kind"] == "stdout_regex":
            m = _search(item["pattern"], text)
            ok, detail = bool(m), (m.group(0)[:200] if m else None)
        elif item["kind"] == "json_file":
            val, found = _json_value(check_dir, item["glob"], item["field"])
            ok = found and (val == item.get("equals"))
            detail = {"value": val, "files_found": found}
        observed.append({"id": item["id"], "kind": item["kind"], "satisfied": ok, "detail": detail})
    return observed


def _json_value(check_dir, pattern, field):
    for path in sorted(glob.glob(os.path.join(check_dir, pattern), recursive=True)):
        try:
            obj = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for part in field.split("."):
            obj = obj.get(part) if isinstance(obj, dict) else None
        return obj, True
    return None, False


def eval_coverage(spec, text, check_dir):
    actual = []
    for item in spec:
        rec = {"id": item["id"], "kind": item["kind"], "satisfied": False, "observed": None, "basis": item.get("basis")}
        if item["kind"] == "regex":
            m = _search(item["pattern"], text)
            rec["satisfied"], rec["observed"] = bool(m), (m.group(0)[:200] if m else None)
        elif item["kind"] == "distinct_min":
            vals = set(re.findall(item["pattern"], text, re.M))
            rec["observed"] = len(vals)
            rec["satisfied"] = len(vals) >= item["min"]
            rec["required_min"] = item["min"]
        elif item["kind"] == "counter_min":
            vals = [int(v) for v in re.findall(item["pattern"], text, re.M) if v.isdigit()]
            rec["observed"] = max(vals) if vals else None
            rec["satisfied"] = bool(vals) and max(vals) >= item["min"]
            rec["required_min"] = item["min"]
        elif item["kind"] == "json_field_min":
            val, found = _json_value(check_dir, item["glob"], item["field"])
            rec["observed"] = val
            rec["satisfied"] = found and isinstance(val, (int, float)) and val >= item["min"]
            rec["required_min"] = item["min"]
        actual.append(rec)
    return actual


def eval_summaries(spec, text):
    """Runner summary lines. Returns (failures_total, malformed_ids, observed)."""
    failures, malformed, observed = 0, [], []
    for item in spec:
        hits = list(re.finditer(item["pattern"], text, re.M))
        rec = {"id": item["id"], "present": bool(hits), "failures": None, "total": None}
        if hits:
            m = hits[-1]
            try:
                rec["failures"] = int(m.group(item["failures_group"]))
                if item.get("total_group"):
                    rec["total"] = int(m.group(item["total_group"]))
            except (ValueError, IndexError):
                malformed.append(item["id"])
            if rec["failures"]:
                failures += rec["failures"]
        elif item.get("loose_pattern") and _search(item["loose_pattern"], text):
            malformed.append(item["id"])
            rec["present"] = True
        observed.append(rec)
    return failures, malformed, observed


def eval_assertions(spec, text):
    spec = spec or {}
    exp = {"value": spec.get("expected"), "basis": spec.get("expected_basis")}
    src = spec.get("actual_from")
    if not src:
        return {"expected": exp, "actual": {"value": None, "basis": "not_measurable"}}
    if src["kind"] == "counter_regex":
        m = _search(src["pattern"], text)
        if m and m.group(1).isdigit():
            return {"expected": exp, "actual": {"value": int(m.group(1)), "basis": "runner_counter"}}
        return {"expected": exp, "actual": {"value": None, "basis": "not_measurable"}}
    vals = set(re.findall(src["pattern"], text, re.M))
    return {"expected": exp, "actual": {"value": len(vals), "basis": "stdout_label_count"}}


def png_info(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != PNG_SIG:
        return None
    return {"width": int.from_bytes(head[16:20], "big"), "height": int.from_bytes(head[20:24], "big")}


def eval_artifacts(spec, check_dir, start_epoch):
    """Required artifacts must live inside this check's own directory and be newer than the process start."""
    records, missing, stale, invalid = [], [], [], []
    for item in spec:
        files = sorted(glob.glob(os.path.join(check_dir, item["glob"]), recursive=True))
        files = [f for f in files if os.path.isfile(f)]
        fresh = []
        for f in files:
            st = os.stat(f)
            is_fresh = st.st_mtime >= start_epoch
            rec = {"path": os.path.relpath(f, check_dir).replace(os.sep, "/"), "role": item["role"], "bytes": st.st_size,
                   "mtime_epoch": st.st_mtime, "fresh": is_fresh, "checks": {}}
            if is_fresh:
                fresh.append(f)
            if "png_header" in item.get("checks", []):
                info = png_info(f)
                rec["checks"]["png_header"] = info
                if info is None or ("png_size" in item and [info["width"], info["height"]] != item["png_size"]):
                    rec["invalid"] = True
            records.append(rec)
        if len(fresh) < item.get("min_count", 1):
            (stale if files else missing).append({"role": item["role"], "glob": item["glob"], "found": len(files),
                                                  "fresh": len(fresh), "required": item.get("min_count", 1)})
        if any(r.get("invalid") for r in records if r["role"] == item["role"]):
            invalid.append(item["role"])
    return records, missing, stale, invalid
