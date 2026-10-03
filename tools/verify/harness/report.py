"""Atomic JSON writing and a minimal stdlib validator for the result/run schemas (type/required/enum/const/items)."""
import json
import os

TYPES = {"string": str, "integer": int, "number": (int, float), "boolean": bool, "array": list, "object": dict, "null": type(None)}


def write_json(path, obj):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(obj, fh, indent=2, sort_keys=True, ensure_ascii=True)
        fh.write("\n")
    os.replace(tmp, path)


def validate(obj, schema, path="$"):
    """Return a list of violations (empty = valid)."""
    errs = []
    t = schema.get("type")
    if t:
        allowed = [t] if isinstance(t, str) else t
        ok = any(isinstance(obj, TYPES[a]) and not (a in ("integer", "number") and isinstance(obj, bool)) for a in allowed)
        if not ok:
            return ["%s: expected %s, got %s" % (path, allowed, type(obj).__name__)]
    if "const" in schema and obj != schema["const"]:
        errs.append("%s: expected const %r" % (path, schema["const"]))
    if "enum" in schema and obj not in schema["enum"]:
        errs.append("%s: %r not in %s" % (path, obj, schema["enum"]))
    if isinstance(obj, dict):
        for key in schema.get("required", []):
            if key not in obj:
                errs.append("%s: missing required '%s'" % (path, key))
        for key, sub in schema.get("properties", {}).items():
            if key in obj:
                errs += validate(obj[key], sub, "%s.%s" % (path, key))
    if isinstance(obj, list) and "items" in schema:
        for i, item in enumerate(obj):
            errs += validate(item, schema["items"], "%s[%d]" % (path, i))
    return errs


def load_schema(schema_dir, name):
    return json.load(open(os.path.join(schema_dir, name), encoding="utf-8"))
