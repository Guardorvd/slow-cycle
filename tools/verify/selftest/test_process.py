"""Process envelope self-tests on python children: timeout, process-tree kill, raw capture, spawn failure."""
import os
import sys
import tempfile
import time
import unittest

from harness import process

PY = sys.executable
GRANDCHILD = (
    "import subprocess,sys,time;"
    "p=subprocess.Popen([sys.executable,'-c','import time;time.sleep(300)']);"
    "print('GRANDCHILD_PID=%d'%p.pid,flush=True);time.sleep(300)")


def go(code, timeout=10):
    d = tempfile.mkdtemp()
    out, err = os.path.join(d, "o"), os.path.join(d, "e")
    rec = process.run_bounded([PY, "-c", code], d, out, err, timeout)
    return rec, open(out, "rb").read(), open(err, "rb").read()


class Envelope(unittest.TestCase):
    def test_normal_exit_records_code_and_streams_separately(self):
        rec, out, err = go("import sys;print('o');sys.stderr.write('e\\n');sys.exit(3)")
        self.assertEqual(rec["exit_code"], 3)
        self.assertFalse(rec["timed_out"])
        self.assertEqual((out.strip(), err.strip()), (b"o", b"e"))

    def test_non_utf8_bytes_are_preserved_raw(self):
        _, out, _ = go("import sys;sys.stdout.buffer.write(b'\\xff\\xfe\\x80ok')")
        self.assertEqual(out, b"\xff\xfe\x80ok")

    def test_timeout_kills_and_reports(self):
        t0 = time.monotonic()
        rec, out, _ = go("import time;print('start',flush=True);time.sleep(300)", timeout=2)
        self.assertTrue(rec["timed_out"])
        self.assertIsNone(rec["exit_code"])
        self.assertLess(time.monotonic() - t0, 30)
        self.assertEqual(rec["kill"]["survivors"], [])
        self.assertTrue(rec["kill"]["tree_terminated"])
        self.assertIn(b"start", out)

    def test_two_generation_tree_leaves_no_survivor(self):
        rec, out, _ = go(GRANDCHILD, timeout=3)
        self.assertTrue(rec["timed_out"])
        pid = int(out.split(b"GRANDCHILD_PID=")[1].split()[0])
        time.sleep(0.5)
        self.assertFalse(process._pid_alive(pid), "grandchild %d survived the tree kill" % pid)
        self.assertEqual(rec["kill"]["survivors"], [])

    @unittest.skipUnless(process.IS_WINDOWS, "Job Object assignment is Windows-specific")
    def test_failed_job_assignment_is_reported_as_unverified_not_as_clean(self):
        from unittest import mock
        with mock.patch.object(process._k32, "AssignProcessToJobObject", return_value=0):
            rec, out, _ = go("import time;print('start',flush=True);time.sleep(300)", timeout=2)
        k = rec["kill"]
        self.assertTrue(rec["timed_out"])
        self.assertIs(k["containment_established"], False)
        self.assertEqual(k["survivors"], ["UNKNOWN"])
        self.assertIs(k["tree_terminated"], False)
        self.assertEqual(k["method"], "taskkill_tree_fallback")

    def test_established_containment_is_recorded(self):
        rec, _, _ = go("pass")
        self.assertIs(rec["kill"]["containment_established"], True)

    def test_spawn_failure_is_reported_not_raised(self):
        d = tempfile.mkdtemp()
        rec = process.run_bounded([os.path.join(d, "missing.exe")], d, os.path.join(d, "o"), os.path.join(d, "e"), 2)
        self.assertFalse(rec["spawned"])
        self.assertIn("spawn_error", rec)
        self.assertTrue(rec["spawn_error"])

    def test_orphan_left_after_normal_exit_is_detected_and_removed(self):
        code = ("import subprocess,sys;"
                "p=subprocess.Popen([sys.executable,'-c','import time;time.sleep(300)']);"
                "print('PID=%d'%p.pid,flush=True)")
        rec, out, _ = go(code)
        pid = int(out.split(b"PID=")[1].split()[0])
        self.assertEqual(rec["exit_code"], 0)
        if process.IS_WINDOWS:
            self.assertTrue(rec["post_exit_orphans"])
        time.sleep(0.5)
        self.assertFalse(process._pid_alive(pid))


if __name__ == "__main__":
    unittest.main()
