#!/usr/bin/env python3
"""Disposable native ANSI x86 audit hosts. Never patches the distributed EXE."""
from pathlib import Path
import argparse
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Native Windows required; this audit does not substitute Wine64 for ANSI x86')
    if args.probe:
        probe(args.output.resolve())


if __name__ == '__main__':
    main()
