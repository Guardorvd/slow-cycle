"""Source / engine / run identity. Git is canonical; raw SHA256 values are supplemental.

LF-normalised hashes exist only as explicitly labelled compatibility values (`compat_lf_sha256`)
for documentary digests recorded before this harness; they never replace or hide the raw/git identity.
"""
import hashlib
import os
import re
import subprocess
import uuid
from datetime import datetime, timezone

RAW_ROOTS = ("scripts", "scenes", "project.godot")


def git(repo, *args):
    p = subprocess.run(["git", "-C", str(repo)] + list(args), capture_output=True)
    return p.returncode, p.stdout.decode("utf-8", "replace")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def compat_lf_sha256(path):
    """Compatibility only: SHA256 of the file with CRLF folded to LF. Never use to judge dirtiness."""
    data = open(path, "rb").read().replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def git_blob(repo, rel):
    rc, out = git(repo, "rev-parse", "HEAD:" + rel)
    return out.strip() if rc == 0 else None


def worktree_raw_sha256(repo):
    """Supplemental raw digest over the tested-source roots (path + raw bytes), sorted."""
    h = hashlib.sha256()
    count = 0
    for root in RAW_ROOTS:
        base = os.path.join(repo, root)
        files = []
        if os.path.isfile(base):
            files = [base]
        else:
            for d, _dirs, names in os.walk(base):
                files += [os.path.join(d, n) for n in names]
        for f in sorted(files):
            rel = os.path.relpath(f, repo).replace(os.sep, "/")
            h.update(rel.encode() + b"\0" + sha256_file(f).encode() + b"\n")
            count += 1
    return {"sha256": h.hexdigest(), "files": count, "roots": list(RAW_ROOTS), "label": "raw_working_tree_supplemental"}


def harness_digest(repo):
    """Supplemental raw digest of the harness itself (tools/verify, excluding caches and engine import data)."""
    h = hashlib.sha256()
    base = os.path.join(repo, "tools", "verify")
    files = []
    for d, dirs, names in os.walk(base):
        dirs[:] = [x for x in dirs if x not in ("__pycache__", ".godot")]
        files += [os.path.join(d, n) for n in names]
    for f in sorted(files):
        h.update(os.path.relpath(f, repo).replace(os.sep, "/").encode() + b"\0" + sha256_file(f).encode() + b"\n")
    return {"sha256": h.hexdigest(), "files": len(files), "label": "raw_working_tree_supplemental"}


def source_identity(repo):
    _, head = git(repo, "rev-parse", "HEAD")
    _, branch = git(repo, "branch", "--show-current")
    _, tree = git(repo, "rev-parse", "HEAD^{tree}")
    _, status = git(repo, "status", "--porcelain=v1", "--untracked-files=all")
    _, staged = git(repo, "diff", "--cached", "--name-status")
    _, unstaged = git(repo, "diff", "--name-status")
    diff = subprocess.run(["git", "-C", str(repo), "diff", "HEAD", "--binary"], capture_output=True).stdout
    untracked = [l[3:] for l in status.splitlines() if l.startswith("??")]
    return {
        "head": head.strip(), "branch": branch.strip(), "tree": tree.strip(),
        "dirty": bool(status.strip()), "status_porcelain": status.splitlines(),
        "staged": staged.splitlines(), "unstaged": unstaged.splitlines(), "untracked": untracked,
        "tracked_diff_sha256": hashlib.sha256(diff).hexdigest(),
        "worktree_raw": worktree_raw_sha256(repo), "harness_raw": harness_digest(repo),
    }


def engine_identity(exe):
    rec = {"path": str(exe), "exists": os.path.isfile(exe), "sha256": None, "version_output": None}
    if not rec["exists"]:
        return rec
    rec["sha256"] = sha256_file(exe)
    try:
        p = subprocess.run([str(exe), "--version"], capture_output=True, timeout=60)
        rec["version_output"] = (p.stdout + p.stderr).decode("utf-8", "replace").strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        rec["version_output"] = "UNAVAILABLE: %s" % exc
    return rec


def new_run_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]


def file_identity(repo, rel):
    """Git blob at HEAD + raw working-tree hash + dirty flag for one tracked file."""
    path = os.path.join(repo, rel)
    _, status = git(repo, "status", "--porcelain=v1", "--", rel)
    return {"path": rel, "git_blob_head": git_blob(repo, rel),
            "raw_sha256": sha256_file(path) if os.path.isfile(path) else None,
            "compat_lf_sha256": compat_lf_sha256(path) if os.path.isfile(path) else None,
            "dirty": bool(status.strip())}


SAFE_ID = re.compile(r"^[A-Za-z0-9_.-]+$")
