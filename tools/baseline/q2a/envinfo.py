"""Read-only environment metadata; missing fields remain UNKNOWN."""
import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from . import cjson


def collect(godot, locator):
    fields = {'Win32_OperatingSystem': 'Caption,Version,BuildNumber,OSArchitecture', 'Win32_Processor': 'Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed', 'Win32_ComputerSystem': 'TotalPhysicalMemory,Manufacturer,Model', 'Win32_VideoController': 'Name,DriverVersion,DriverDate,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate,AdapterRAM', 'Win32_Battery': 'BatteryStatus,EstimatedChargeRemaining'}
    out = {'timestamp': cjson.utc(), 'python': {'executable': sys.executable, 'version': sys.version}, 'platform': platform.platform(), 'evidence_root_locator': str(locator), 'AdapterRAM_note': 'raw reported counter may be unreliable above 4 GB', 'uncontrolled': ['background load', 'thermal state', 'display sleep']}
    for cls, names in fields.items():
        try:
            p = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-Command', 'Get-CimInstance ' + cls + ' | Select-Object ' + names + ' | ConvertTo-Json -Compress'], capture_output=True, timeout=30)
            out[cls] = json.loads(p.stdout.decode('utf-8-sig'), parse_float=str) if p.returncode == 0 and p.stdout.strip() else 'UNKNOWN'
        except (OSError, ValueError, subprocess.TimeoutExpired):
            out[cls] = 'UNKNOWN'
    p = subprocess.run(['powercfg', '/getactivescheme'], capture_output=True)
    out['power_plan'] = p.stdout.decode('utf-8', 'replace').strip() if p.returncode == 0 else 'UNKNOWN'
    p = subprocess.run([str(godot), '--version'], capture_output=True, timeout=60)
    out['godot'] = {'path': str(godot), 'sha256': cjson.sha(godot), 'version': (p.stdout + p.stderr).decode('utf-8', 'replace').strip()}
    userdata = Path(os.environ.get('APPDATA', '')) / 'Godot/app_userdata/Slow Cycle'
    try:
        out['user_data_listing'] = [{'name': p.relative_to(userdata).as_posix(), 'bytes': p.stat().st_size, 'mtime_us': p.stat().st_mtime_ns // 1000} for p in userdata.rglob('*') if p.is_file()]
    except OSError:
        out['user_data_listing'] = 'UNKNOWN'
    return out


def reporting_view(raw):
    out = {**raw}
    if isinstance(raw.get('user_data_listing'), list):
        out['user_data_listing'] = [{('mtime_us' if k == 'mtime_ns' else k): v for k, v in row.items()} for row in raw['user_data_listing']]
    out['timestamp_compatibility'] = 'A3: historical mtime_ns values were microseconds; renamed mtime_us without scaling; raw env evidence unchanged'
    return out
