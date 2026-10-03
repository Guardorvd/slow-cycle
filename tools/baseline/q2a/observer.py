"""Read-only WinAPI descendant observer. OS peaks and sampled maxima remain distinct."""
import ctypes as ct
import os
import threading
from pathlib import Path
from ctypes import wintypes as wt
from . import cjson


class ProcessEntry(ct.Structure):
    _fields_ = [('dwSize', wt.DWORD), ('cntUsage', wt.DWORD), ('th32ProcessID', wt.DWORD),
                ('th32DefaultHeapID', ct.c_size_t), ('th32ModuleID', wt.DWORD), ('cntThreads', wt.DWORD),
                ('th32ParentProcessID', wt.DWORD), ('pcPriClassBase', wt.LONG), ('dwFlags', wt.DWORD), ('szExeFile', wt.WCHAR * 260)]


class Memory(ct.Structure):
    _fields_ = [('cb', wt.DWORD), ('PageFaultCount', wt.DWORD)] + [(n, ct.c_size_t) for n in [
        'PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage',
        'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage']]


def ticks(ft):
    return (int(ft.dwHighDateTime) << 32) | int(ft.dwLowDateTime)


def targets(memory, wrapper_pid):
    wrapper = [p for p in memory['processes'] if p['pid'] == wrapper_pid and p.get('required') and p['role'] == 'console_wrapper']
    main = [p for p in memory['processes'] if p['parent_pid'] == wrapper_pid and p.get('required') and p['role'] == 'godot_main']
    return wrapper + main if len(wrapper) == 1 and len(main) == 1 else []


def required_errors(memory):
    return [e for e in memory['errors'] if e.get('required', True)]


class Observer:
    def __init__(self, root_pid, start_filetime, path, godot=None):
        if os.name != 'nt':
            raise OSError('Windows required for approved observer')
        self.k = ct.WinDLL('kernel32', use_last_error=True)
        for name, args, ret in [
            ('CreateToolhelp32Snapshot', [wt.DWORD, wt.DWORD], wt.HANDLE),
            ('Process32FirstW', [wt.HANDLE, ct.POINTER(ProcessEntry)], wt.BOOL),
            ('Process32NextW', [wt.HANDLE, ct.POINTER(ProcessEntry)], wt.BOOL),
            ('OpenProcess', [wt.DWORD, wt.BOOL, wt.DWORD], wt.HANDLE),
            ('CloseHandle', [wt.HANDLE], wt.BOOL), ('WaitForSingleObject', [wt.HANDLE, wt.DWORD], wt.DWORD),
            ('GetProcessTimes', [wt.HANDLE] + [ct.POINTER(wt.FILETIME)] * 4, wt.BOOL),
            ('QueryFullProcessImageNameW', [wt.HANDLE, wt.DWORD, wt.LPWSTR, ct.POINTER(wt.DWORD)], wt.BOOL),
            ('K32GetProcessMemoryInfo', [wt.HANDLE, ct.POINTER(Memory), wt.DWORD], wt.BOOL)]:
            fn = getattr(self.k, name)
            fn.argtypes, fn.restype = args, ret
        self.root, self.invocation_start, self.path = root_pid, start_filetime, path
        self.target_paths = {} if godot is None else {os.path.normcase(str(Path(godot).resolve())): 'console_wrapper', os.path.normcase(str(Path(str(godot).removesuffix('_console.exe') + '.exe').resolve())): 'godot_main'}
        self.target_names = {Path(p).name.lower() for p in self.target_paths}
        self.records, self.errors, self.handles = {}, [], {}
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self.loop, daemon=True)

    def start(self):
        self.thread.start()

    def snapshot(self):
        h = self.k.CreateToolhelp32Snapshot(2, 0)
        if h == ct.c_void_p(-1).value:
            raise OSError('Toolhelp snapshot failed: %d' % ct.get_last_error())
        pe = ProcessEntry()
        pe.dwSize = ct.sizeof(pe)
        rows = {}
        try:
            ok = self.k.Process32FirstW(h, ct.byref(pe))
            if not ok:
                raise OSError('Process32FirstW failed: %d' % ct.get_last_error())
            while ok:
                rows[int(pe.th32ProcessID)] = (int(pe.th32ParentProcessID), pe.szExeFile)
                ok = self.k.Process32NextW(h, ct.byref(pe))
            if ct.get_last_error() != 18:
                raise OSError('Process32NextW failed: %d' % ct.get_last_error())
        finally:
            self.k.CloseHandle(h)
        return rows

    def times(self, handle):
        a, b, c, d = [wt.FILETIME() for _ in range(4)]
        if not self.k.GetProcessTimes(handle, ct.byref(a), ct.byref(b), ct.byref(c), ct.byref(d)):
            raise OSError('GetProcessTimes failed: %d' % ct.get_last_error())
        return {'creation_100ns': '%d' % ticks(a), 'exit_100ns': '%d' % ticks(b) if ticks(b) else None, 'cpu_kernel_100ns': ticks(c), 'cpu_user_100ns': ticks(d)}

    def executable(self, handle):
        buf, size = ct.create_unicode_buffer(32768), wt.DWORD(32768)
        if not self.k.QueryFullProcessImageNameW(handle, 0, buf, ct.byref(size)):
            raise OSError('QueryFullProcessImageNameW failed: %d' % ct.get_last_error())
        return buf.value

    def classify(self, executable, parent):
        role = self.target_paths.get(os.path.normcase(str(Path(executable).resolve())), 'incidental_helper')
        required = role != 'incidental_helper'
        related = parent == self.root if role == 'console_wrapper' else self.records.get(parent, {}).get('role') == 'console_wrapper'
        return role, required, not required or related

    def discover(self, rows):
        trusted = {self.root} | {pid for pid, r in self.records.items() if not r['exited']}
        changed = True
        while changed:
            changed = False
            for pid, (parent, name) in rows.items():
                if pid in trusted or parent not in trusted:
                    continue
                diagnostic = {'pid': pid, 'parent': parent, 'name': name, 'executable': None, 'role': 'required_target_unresolved' if name.lower() in self.target_names else 'incidental_helper', 'required': name.lower() in self.target_names}
                mask = 0x1000 | 0x10 | 0x100000
                h = self.k.OpenProcess(mask, False, pid)
                if not h:
                    mask &= ~0x10
                    h = self.k.OpenProcess(mask, False, pid)
                if not h:
                    self.errors.append({**diagnostic, 'reason': 'OpenProcess', 'error': ct.get_last_error()})
                    continue
                try:
                    executable = self.executable(h)
                    role, required, related = self.classify(executable, parent)
                    diagnostic.update(executable=executable, role=role, required=required)
                    if not related:
                        raise OSError('required executable has invalid parent relationship')
                    t = self.times(h)
                    parent_creation = int(self.records.get(parent, {}).get('creation_100ns', self.invocation_start))
                    if int(t['creation_100ns']) < max(self.invocation_start, parent_creation):
                        self.errors.append({**diagnostic, 'reason': 'creation attribution invalid'})
                        self.k.CloseHandle(h)
                        continue
                    if pid in self.records:
                        self.errors.append({**diagnostic, 'reason': 'PID reuse; attribution cannot be trusted'})
                        self.k.CloseHandle(h)
                        continue
                    self.records[pid] = {'pid': pid, 'parent_pid': parent, 'name': name, 'executable': executable, 'role': role, 'required': required, 'granted_mask': mask, **t, 'exited': False, 'samples': [], 'post_exit_query': 'NOT_QUERIED'}
                    self.handles[pid] = h
                    trusted.add(pid)
                    changed = True
                except OSError as exc:
                    self.errors.append({**diagnostic, 'reason': str(exc)})
                    self.k.CloseHandle(h)

    def query(self, pid, fh):
        r, h = self.records[pid], self.handles[pid]
        if r['exited']:
            return
        wait = self.k.WaitForSingleObject(h, 0)
        if wait not in (0, 258):
            raise OSError('WaitForSingleObject failed: %d' % ct.get_last_error())
        exited = wait == 0
        m = Memory()
        m.cb = ct.sizeof(m)
        ok = self.k.K32GetProcessMemoryInfo(h, ct.byref(m), ct.sizeof(m))
        memory_error = ct.get_last_error() if not ok else None
        timing = self.times(h)
        r.update(timing)
        if exited:
            r['post_exit_query'] = 'OK' if ok else 'FAILED(%d)' % memory_error
            r['exited'] = True
            fh.write(cjson.canonical({'kind': 'exit', 'pid': pid, 'timestamp': cjson.utc(), 'post_exit_query': r['post_exit_query'], **timing}) + b'\n')
        if ok:
            sample = {'timestamp': cjson.utc(), 'working_set_bytes': int(m.WorkingSetSize), 'private_bytes': int(m.PrivateUsage), 'commit_bytes': int(m.PagefileUsage), 'os_peak_working_set_bytes': int(m.PeakWorkingSetSize), 'os_peak_commit_bytes': int(m.PeakPagefileUsage), **timing}
            r['samples'].append(sample)
            fh.write(cjson.canonical({'pid': pid, 'post_exit': exited, **sample}) + b'\n')
            fh.flush()
        elif not exited:
            self.errors.append({'pid': pid, 'executable': r['executable'], 'role': r['role'], 'required': r['required'], 'reason': 'memory query failed', 'error': memory_error})
        fh.flush()

    def loop(self):
        try:
            with open(self.path, 'xb') as fh:
                while True:
                    self.discover(self.snapshot())
                    for pid in list(self.handles):
                        try:
                            self.query(pid, fh)
                        except OSError as exc:
                            r = self.records[pid]
                            self.errors.append({'pid': pid, 'executable': r['executable'], 'role': r['role'], 'required': r['required'], 'reason': str(exc)})
                    if self.stop_event.is_set():
                        break
                    self.stop_event.wait(0.250)
        except Exception as exc:
            self.errors.append({'reason': type(exc).__name__ + ': ' + str(exc)})

    def finish(self):
        self.stop_event.set()
        self.thread.join()
        for pid, h in self.handles.items():
            r = self.records[pid]
            samples = r.pop('samples')
            r['sample_count'] = len(samples)
            if samples:
                last = samples[-1]
                suffix = '' if r['post_exit_query'] == 'OK' else '_until_last_query'
                for key in ['os_peak_working_set_bytes', 'os_peak_commit_bytes']:
                    r[key + suffix] = last[key]
                r['last_query_timestamp'] = last['timestamp']
                r['sampled_peak_working_set_bytes'] = max(s['working_set_bytes'] for s in samples)
                r['sampled_peak_private_bytes'] = max(s['private_bytes'] for s in samples)
            self.k.CloseHandle(h)
        return {'interval_ms': 250, 'series_relpath': 'observer/' + self.path.name, 'processes': list(self.records.values()), 'errors': self.errors}
