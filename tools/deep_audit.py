#!/usr/bin/env python3
"""Disposable native ANSI x86 audit hosts. Never patches the distributed EXE."""
from pathlib import Path
import argparse
import ctypes
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/build'))
from build_exe import verified_runtime, update_windows, LOCK
from pe_resources import PE
from function_index import instrument, HOOK

CASES = [
 ('runtime-info','runtime_info_report.txt'), ('selftest','selftest_report.txt'),
 ('audit-selftest','audit_selftest_report.txt'), ('context-mocktest','context_assistant_test.txt'),
 ('autoreport-mocktest','autoreport_mocktest_report.txt'), ('law-search-test','law_search_test_report.txt'),
 ('v1-mocktest','v1_mocktest_report.txt'), ('desktop-smoke','desktop_smoke_report.txt'),
 ('diagnostics','diagnostics_report.txt'),
]
FIXTURES = [
 ('private_input','build_private_input_fixture.py','private_input_report.txt'),
 ('chat_route','build_chat_route_fixture.py','chat_route_report.txt'),
 ('memory_sequence','build_memory_sequence_fixture.py','memory_sequence_report.txt'),
 ('game_menu','build_game_menu_fixture.py','game_menu_report.txt'),
 ('text_bind','build_text_bind_fixture.py','text_bind_report.txt'),
 ('autoid_tracking','build_autoid_tracking_fixture.py','autoid_tracking_report.txt'),
]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def decode(raw):
    if raw.startswith(b'\xef\xbb\xbf'):
        return raw.decode('utf-8-sig')
    if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
        return raw.decode('utf-16')
    return raw.decode('cp1251')


def locale_host(source, target):
    """Windows 11+/Server 2025 per-process ACP; original .text/payload unchanged."""
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    before = PE(Path(source).read_bytes())
    manifest = before.resource(1, 24).decode('utf-8').rstrip('\0 ')
    marker = '</v3:windowsSettings>'
    if manifest.count(marker) != 1:
        raise ValueError('Unexpected official runtime manifest')
    manifest = manifest.replace(marker, '<activeCodePage xmlns="http://schemas.microsoft.com/SMI/2019/WindowsSettings">ru-RU</activeCodePage>' + marker)
    update_windows(target, [(24, 1, manifest.encode('utf-8'))])
    after = PE(target.read_bytes())
    assert before.machine == after.machine == 0x14c
    assert {k: v for k, v in before.resources.items() if k[0] != 24} == {k: v for k, v in after.resources.items() if k[0] != 24}
    # Every mapped section outside resources must retain its complete bytes.
    for rva, size, offset in before.sections:
        if offset <= before.resource_base < offset + size:
            continue
        other = after.offset(rva)
        assert before.data[offset:offset + min(size, len(before.data)-offset)] == after.data[other:other + min(size, len(before.data)-offset)]
    return {'original_sha256': sha(source), 'test_host_sha256': sha(target), 'only_resource_type_changed': 24, 'activeCodePage': 'ru-RU'}


def prepare(output):
    output.mkdir(parents=True, exist_ok=True)
    runtime = verified_runtime(None, ROOT / '.build/toolchain')
    archive = ROOT / '.build/toolchain' / ('AutoHotkey_' + LOCK['version'] + '.zip')
    assert sha(archive) == LOCK['sha256']
    plain = output / 'AutoHotkeyA32_official.exe'
    with zipfile.ZipFile(archive) as z:
        plain.write_bytes(z.read('AutoHotkeyA32.exe'))
    ahk = output / 'AutoHotkeyA32_TEST_CP1251.exe'
    exe = output / 'AHK_FOR_GOS_TEST_CP1251.exe'
    provenance = {'source_runtime': locale_host(plain, ahk), 'compiled_host': locale_host(ROOT / 'release/AHK_FOR_GOS.exe', exe), 'runtime_archive_sha256': LOCK['sha256']}
    return ahk, exe, runtime, provenance


def invoke(cmd, folder, report_name, timeout=240, env=None):
    folder.mkdir(parents=True, exist_ok=True)
    report = folder / report_name
    if report.exists():
        report.unlink()
    began = time.monotonic()
    with (folder / (report_name + '.console.txt')).open('wb') as log:
        try:
            process = subprocess.run([str(x) for x in cmd], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, env=env)
            code = process.returncode
        except subprocess.TimeoutExpired:
            code = -999
    text = decode(report.read_bytes()) if report.exists() else ''
    failures = re.findall(r'(?m)^(?:FAIL\s*\|.*|\[FAIL\].*)$', text)
    return {'exit_code': code, 'seconds': round(time.monotonic()-began, 2), 'report': str(report), 'failures': failures, 'status': 'PASS' if code == 0 and text and not failures else 'FAIL'}, text


def probe(output):
    ahk, exe, runtime, provenance = prepare(output)
    rows = []
    for form, command in [('exe_stock', [ROOT/'release/AHK_FOR_GOS.exe']), ('exe_cp1251', [exe]), ('source_cp1251', [ahk, '/ErrorStdOut', '/CP1251', ROOT/'AHK_FOR_GOS_BY_SBEZRUK.ahk'])]:
        data = output / form
        row, text = invoke(command + ['--runtime-info', '--data-dir', data], data, 'runtime_info_report.txt')
        row['form'] = form
        print(text, flush=True)
        for key in ('PointerSize', 'Unicode', 'Compiled', 'SystemCodepage'):
            m = re.search(r'^' + key + r'=(\d+)', text, re.M)
            row[key] = int(m[1]) if m else None
        assert row['status'] == 'PASS' and row['PointerSize'] == 4 and row['Unicode'] == 0, row
        if form != 'exe_stock':
            if row['SystemCodepage'] != 1251:
                raise RuntimeError('::error::Per-process ru-RU ACP unavailable: ' + str(row))
            assert row['Compiled'] == (form == 'exe_cp1251'), row
        rows.append(row)
    result = {'provenance': provenance, 'results': rows, 'game': 'NOT_TESTED'}
    (output/'probe.json').write_text(json.dumps(result, indent=2)+'\n')
    return result


def compiled_fixture(script, runtime, output):
    shutil.copyfile(runtime / LOCK['base'], output)
    code = script.read_text('utf-8-sig').encode('utf-8')
    update_windows(output, [(10, '>AUTOHOTKEY SCRIPT<', code)])
    localized = output.with_name(output.stem + '_CP1251.exe')
    locale_host(output, localized)
    return localized


def capture_windows(pid):
    user = ctypes.WinDLL('user32', use_last_error=True)
    found = []
    callback_type = ctypes.WINFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)
    user.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint)]
    user.GetClassNameW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_int]
    def visit(hwnd, extra):
        owner = ctypes.c_uint()
        user.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid:
            name = ctypes.create_unicode_buffer(256)
            user.GetClassNameW(hwnd, name, 256)
            found.append((int(hwnd), name.value))
        return 1
    cb = callback_type(visit)
    user.EnumWindows.argtypes = [callback_type, ctypes.c_void_p]
    user.EnumWindows(cb, None)
    return found


def startup_check(command, folder, env):
    """Real normal startup, second-instance suppression, tray/menu Exit command."""
    folder.mkdir(parents=True, exist_ok=True)
    p = subprocess.Popen([str(x) for x in command]+['--data-dir',str(folder)], cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    rows = {'started':False,'singleton':False,'clean_exit':False}
    try:
        time.sleep(3)
        windows = capture_windows(p.pid)
        rows['started'] = p.poll() is None and any(cls == 'AutoHotkey' for _,cls in windows)
        second_env = dict(env)
        if second_env.get('AHK_AUDIT_COVERAGE'):
            second_env['AHK_AUDIT_COVERAGE'] += '.second'
        second = subprocess.Popen([str(x) for x in command]+['--data-dir',str(folder)],cwd=ROOT,env=second_env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            second.wait(timeout=8)
            rows['singleton'] = p.poll() is None
        except subprocess.TimeoutExpired:
            second.kill();second.wait()
        user=ctypes.WinDLL('user32',use_last_error=True)
        user.PostMessageW.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_size_t,ctypes.c_ssize_t]
        for hwnd,cls in windows:
            if cls == 'AutoHotkey':
                user.PostMessageW(hwnd,0x111,65405,0)
        try:
            p.wait(timeout=12)
            rows['clean_exit'] = p.returncode == 0
        except subprocess.TimeoutExpired:
            p.kill();p.wait()
        rows['exit_code'] = p.returncode
    finally:
        if p.poll() is None:p.kill();p.wait()
    rows['status'] = 'PASS' if all(rows[k] for k in ('started','singleton','clean_exit')) else 'FAIL'
    return rows


def run_audit(output, form, repeat):
    output.mkdir(parents=True, exist_ok=True)
    work=output.parent/(output.name+'-work');work.mkdir(parents=True,exist_ok=True)
    ahk, exe, runtime, provenance=prepare(work/'hosts')
    probe_row,probe_text=invoke([ahk,'/ErrorStdOut','/CP1251',ROOT/'AHK_FOR_GOS_BY_SBEZRUK.ahk','--runtime-info','--data-dir',work/'cp-probe'],work/'cp-probe','runtime_info_report.txt')
    if 'SystemCodepage=1251' not in probe_text or probe_row['exit_code']:
        raise RuntimeError('Native ANSI CP1251 requirement is not satisfied')
    summary={'form':form,'repeat':repeat,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
      'release_sha256':sha(ROOT/'release/AHK_FOR_GOS.exe'),'provenance':provenance,
      'real_game':'NOT_TESTED','real_OBS':'NOT_TESTED','cases':[]}
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    source_trace=work.parent/(work.name+'-instrumented')
    instrument(ROOT,source_trace)
    trace_exe=None
    if form=='exe':
        subprocess.run([sys.executable,str(source_trace/'tools/build_exe.py'),'--runtime',str(runtime),'--output',str(work/'instrumented.exe')],check=True)
        trace_exe=work/'instrumented_TEST_CP1251.exe';locale_host(work/'instrumented.exe',trace_exe)
    for traced in (False,True):
        phase='traced' if traced else 'original'
        source=source_trace if traced else ROOT
        command=[trace_exe if traced else exe] if form=='exe' else [ahk,'/ErrorStdOut','/CP1251',source/'AHK_FOR_GOS_BY_SBEZRUK.ahk']
        for mode,report_name in CASES:
            data=work/phase/mode
            env=dict(os.environ)
            if traced:env['AHK_AUDIT_COVERAGE']=str(output/(phase+'_'+mode+'.coverage.txt'))
            if mode=='diagnostics':
                data.mkdir(parents=True,exist_ok=True)
                old=work/phase/'selftest'/'selftest_report.txt'
                if old.exists():shutil.copyfile(old,data/'selftest_report.txt')
            row,text=invoke(command+['--'+mode,'--data-dir',data],data,report_name,timeout=300,env=env)
            row.update(mode=mode,phase=phase)
            # Diagnostics reports missing game/process conditions explicitly.
            if mode=='diagnostics' and row['exit_code']==0 and text:row['status']='DIAGNOSTIC_FINDINGS' if row['failures'] else 'PASS'
            for suffix in ('', '.console.txt'):
                f=data/(report_name+suffix)
                if f.exists():shutil.copyfile(f,output/(phase+'_'+report_name+suffix))
            row['report']=phase+'_'+report_name
            summary['cases'].append(row)
            (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
            print(json.dumps({k:row[k] for k in ('mode','phase','status','exit_code','seconds')}),flush=True)
        env=dict(os.environ)
        if traced:env['AHK_AUDIT_COVERAGE']=str(output/(phase+'_startup.coverage.txt'))
        row=startup_check(command,work/phase/'startup',env);row.update(mode='startup-singleton-exit',phase=phase)
        summary['cases'].append(row)
    # Fixture sinks/predicates are explicit; actual IO is Win32/keyboard, not GTA.
    for name,builder,report_name in FIXTURES:
        folder=work/'fixtures'/name;script=folder/'native.ahk';folder.mkdir(parents=True,exist_ok=True)
        subprocess.run([sys.executable,str(source_trace/'tools'/builder),str(script)],check=True)
        # Extracted production functions refer to counters from the disposable copy.
        text=decode(script.read_bytes())
        if '__AuditCoverage_Hit(name)' not in text:script.write_text(text+'\n'+HOOK,encoding='utf-8-sig')
        command=[compiled_fixture(script,runtime,folder/'native.exe')] if form=='exe' else [ahk,'/ErrorStdOut',script]
        data=folder/'data';env=dict(os.environ);env['AHK_AUDIT_COVERAGE']=str(output/('fixture_'+name+'.coverage.txt'))
        row,text=invoke(command+['--data-dir',data],folder,report_name,timeout=150,env=env)
        row.update(mode=name,phase='fixture',report='fixture_'+report_name)
        for suffix in ('','.console.txt'):
            f=folder/(report_name+suffix)
            if f.exists():shutil.copyfile(f,output/('fixture_'+report_name+suffix))
        summary['cases'].append(row)
        print(json.dumps({k:row[k] for k in ('mode','phase','status','exit_code','seconds')}),flush=True)
        (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    # Report and terminate only leaked AHK hosts owned by this audit directory.
    prefix=str(work).replace("'","''")
    ps="$p='"+prefix+"'; @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($p) } | Select-Object ProcessId,Name) | ConvertTo-Json -Compress"
    leak=subprocess.run(['powershell','-NoProfile','-Command',ps],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
    raw=leak.stdout.decode('utf-8-sig',errors='replace').strip()
    summary['remaining_processes']=json.loads(raw) if raw else []
    if summary['remaining_processes']:
        items=summary['remaining_processes'];items=items if isinstance(items,list) else [items]
        for p in items:subprocess.run(['taskkill','/PID',str(p['ProcessId']),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    summary['completed']=True
    summary['original_failures']=[r['mode'] for r in summary['cases'] if r['phase']=='original' and r['status']=='FAIL']
    summary['tracing_failures']=[r['mode'] for r in summary['cases'] if r['phase']=='traced' and r['status']=='FAIL']
    summary['fixture_failures']=[r['mode'] for r in summary['cases'] if r['phase']=='fixture' and r['status']=='FAIL']
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('AUDIT_COMPLETED '+json.dumps({k:summary[k] for k in ('form','repeat','original_failures','tracing_failures','fixture_failures','remaining_processes')}),flush=True)
    # Findings are exported for review, not hidden by stopping after the first case.
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--form',choices=['exe','source'])
    parser.add_argument('--repeat',type=int,default=1)
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Native Windows required; this audit does not substitute Wine64 for ANSI x86')
    if args.probe:
        probe(args.output.resolve())
    elif args.form:
        run_audit(args.output.resolve(),args.form,args.repeat)


if __name__ == '__main__':
    main()
