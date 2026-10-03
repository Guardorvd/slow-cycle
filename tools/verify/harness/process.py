"""Bounded child-process envelope: spawn, raw capture, timeout, process-tree kill, survivor check.

This module only runs a command and reports what happened. It never interprets output.
"""
import os
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone

IS_WINDOWS = os.name == "nt"


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


if IS_WINDOWS:
    import ctypes
    from ctypes import wintypes

    _k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _k32.CreateJobObjectW.restype = wintypes.HANDLE
    _k32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    _k32.SetInformationJobObject.restype = wintypes.BOOL
    _k32.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    _k32.QueryInformationJobObject.restype = wintypes.BOOL
    _k32.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p]
    _k32.AssignProcessToJobObject.restype = wintypes.BOOL
    _k32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    _k32.TerminateJobObject.restype = wintypes.BOOL
    _k32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    _k32.CloseHandle.restype = wintypes.BOOL
    _k32.CloseHandle.argtypes = [wintypes.HANDLE]

    class _BasicLimit(ctypes.Structure):
        _fields_ = [("PerProcessUserTimeLimit", ctypes.c_longlong), ("PerJobUserTimeLimit", ctypes.c_longlong),
                    ("LimitFlags", wintypes.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
                    ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", wintypes.DWORD),
                    ("Affinity", ctypes.c_size_t), ("PriorityClass", wintypes.DWORD), ("SchedulingClass", wintypes.DWORD)]

    class _IoCounters(ctypes.Structure):
        _fields_ = [(n, ctypes.c_ulonglong) for n in (
            "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
            "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]

    class _ExtLimit(ctypes.Structure):
        _fields_ = [("Basic", _BasicLimit), ("Io", _IoCounters), ("ProcessMemoryLimit", ctypes.c_size_t),
                    ("JobMemoryLimit", ctypes.c_size_t), ("PeakProcessMemoryUsed", ctypes.c_size_t),
                    ("PeakJobMemoryUsed", ctypes.c_size_t)]

    _MAX_PIDS = 256

    class _PidList(ctypes.Structure):
        _fields_ = [("NumberOfAssignedProcesses", wintypes.DWORD), ("NumberOfProcessIdsInList", wintypes.DWORD),
                    ("ProcessIdList", ctypes.c_size_t * _MAX_PIDS)]

    def _job_create():
        job = _k32.CreateJobObjectW(None, None)
        if not job:
            return None
        info = _ExtLimit()
        info.Basic.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not _k32.SetInformationJobObject(job, 9, ctypes.byref(info), ctypes.sizeof(info)):
            _k32.CloseHandle(job)
            return None
        return job

    def _job_pids(job):
        buf = _PidList()
        if not _k32.QueryInformationJobObject(job, 3, ctypes.byref(buf), ctypes.sizeof(buf), None):
            return None
        return [int(buf.ProcessIdList[i]) for i in range(buf.NumberOfProcessIdsInList)]


def _pump(stream, path):
    with open(path, "wb") as fh:
        while True:
            chunk = stream.read1(65536) if hasattr(stream, "read1") else stream.read(65536)
            if not chunk:
                break
            fh.write(chunk)
            fh.flush()


def run_bounded(argv, cwd, stdout_path, stderr_path, timeout_s, env=None, poll_s=0.05):
    """Run argv with a hard timeout. Returns a dict describing the envelope; never raises for child failures."""
    rec = {"argv": list(argv), "cwd": str(cwd), "spawned": False, "pid": None, "start_utc": utc_now(), "end_utc": None,
           "duration_s": None, "timeout_s": timeout_s, "timed_out": False, "exit_code": None, "spawn_error": None,
           "kill": {"method": None, "tree_terminated": None, "survivors": [], "job_assigned": None,
                    "containment_established": None},
           "post_exit_orphans": []}
    t0 = time.monotonic()
    job = None
    popen_kw = {}
    if IS_WINDOWS:
        job = _job_create()
        popen_kw["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        popen_kw["start_new_session"] = True
    try:
        proc = subprocess.Popen(list(argv), cwd=str(cwd), env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0, **popen_kw)
    except OSError as exc:
        rec["spawn_error"] = "%s: %s" % (type(exc).__name__, exc)
        rec["end_utc"] = utc_now()
        rec["duration_s"] = round(time.monotonic() - t0, 3)
        open(stdout_path, "wb").close()
        open(stderr_path, "wb").close()
        if job:
            _k32.CloseHandle(job)
        return rec
    rec["spawned"] = True
    rec["pid"] = proc.pid
    if IS_WINDOWS:
        ok = bool(job) and bool(_k32.AssignProcessToJobObject(job, int(proc._handle)))
        rec["kill"]["job_assigned"] = ok
        rec["kill"]["containment_established"] = ok
    else:
        rec["kill"]["containment_established"] = True  # own session; killpg reaches the group (leader-level check only)
    threads = [threading.Thread(target=_pump, args=(proc.stdout, stdout_path), daemon=True),
               threading.Thread(target=_pump, args=(proc.stderr, stderr_path), daemon=True)]
    for th in threads:
        th.start()

    deadline = t0 + timeout_s
    while proc.poll() is None and time.monotonic() < deadline:
        time.sleep(poll_s)
    if proc.poll() is None:
        rec["timed_out"] = True
        _kill_tree(proc, job, rec)
    else:
        rec["exit_code"] = proc.returncode
        _reap_orphans(proc, job, rec)
    proc.wait()
    for th in threads:
        th.join(timeout=10)
    if job:
        _k32.CloseHandle(job)
    rec["end_utc"] = utc_now()
    rec["duration_s"] = round(time.monotonic() - t0, 3)
    return rec


def _kill_tree(proc, job, rec):
    kill = rec["kill"]
    if IS_WINDOWS:
        if kill["job_assigned"]:
            kill["method"] = "job_object_terminate"
            _k32.TerminateJobObject(job, 1)
        else:
            kill["method"] = "taskkill_tree_fallback"
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
    else:
        kill["method"] = "killpg"
        import signal
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass
    if kill["containment_established"]:
        kill["survivors"] = _survivors(proc, job)
        kill["tree_terminated"] = not kill["survivors"]
    else:
        # Never assigned to the job: an empty survivor list would be unverified, so cleanup is reported as unknown.
        kill["survivors"] = ["UNKNOWN"]
        kill["tree_terminated"] = False


def _survivors(proc, job, settle_s=5.0):
    """PIDs of the child tree still alive after the kill; polled briefly because termination is asynchronous."""
    end = time.monotonic() + settle_s
    alive = []
    while True:
        if IS_WINDOWS and job:
            alive = _job_pids(job)
            if alive is None:
                alive = ["UNKNOWN"]
        else:
            alive = [proc.pid] if _pid_alive(proc.pid) else []
        if not alive or time.monotonic() >= end:
            return alive
        time.sleep(0.1)


def _reap_orphans(proc, job, rec):
    """After a normal exit nothing of the tree should remain; anything left is recorded and removed."""
    left = _survivors(proc, job, settle_s=0.5)
    if left:
        rec["post_exit_orphans"] = left
        if IS_WINDOWS and job:
            _k32.TerminateJobObject(job, 1)
        elif not IS_WINDOWS:
            import signal
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass


def _pid_alive(pid):
    if IS_WINDOWS:
        out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/NH"], capture_output=True, text=True).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False
