#!/usr/bin/env python3
"""Build the standalone ANSI x86 application with Python 3.10+ and WinAPI.

Windows: python tools/build_exe.py
Linux validation/build: add --wine /path/to/wine --runtime /verified/runtime/dir
No third-party Python packages or installed AutoHotkey are needed on Windows.
"""
from pathlib import Path
import argparse
import ctypes
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent / 'build'))
from source_graph import SourceGraph
from pe_resources import PE

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / 'tools/build/toolchain.lock.json').read_text())

def digest(data):
    return hashlib.sha256(data).hexdigest()

def verified_runtime(explicit, cache):
    if explicit:
        runtime = Path(explicit).resolve()
    else:
        runtime = cache / LOCK['version']
        archive = cache / ('AutoHotkey_' + LOCK['version'] + '.zip')
        cache.mkdir(parents=True, exist_ok=True)
        if not archive.is_file():
            request = urllib.request.Request(LOCK['url'], headers={'User-Agent':'AHK-FOR-GOS-build'})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
            if digest(data) != LOCK['sha256']:
                raise ValueError('Official runtime archive SHA-256 mismatch')
            archive.write_bytes(data)
        if digest(archive.read_bytes()) != LOCK['sha256']:
            raise ValueError('Cached runtime archive SHA-256 mismatch')
        runtime.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            # Only known build inputs. No untrusted archive paths are extracted.
            for name in [LOCK['base'], 'Compiler/Unicode 64-bit.bin', 'AutoHotkeyU64.exe', 'license.txt']:
                target = runtime / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(name))
    for name, expected in LOCK['files'].items():
        if digest((runtime/name).read_bytes()) != expected:
            raise ValueError('Pinned toolchain file mismatch: ' + name)
    base = runtime / LOCK['base']
    if digest(base.read_bytes()) != LOCK['base_sha256']:
        raise ValueError('ANSI x86 compiler base does not match the pinned official runtime')
    source = ROOT / 'third_party/AutoHotkey-1.1.37.02-source.zip'
    if digest(source.read_bytes()) != LOCK['source_sha256']:
        raise ValueError('Corresponding AutoHotkey engine source SHA-256 mismatch')
    return runtime

def winpath(path):
    return 'Z:' + str(path.resolve()).replace('/', '\\')

def update_windows(output, resources):
    k = ctypes.WinDLL('kernel32', use_last_error=True)
    k.BeginUpdateResourceW.argtypes = [ctypes.c_wchar_p, ctypes.c_int]
    k.BeginUpdateResourceW.restype = ctypes.c_void_p
    k.UpdateResourceW.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ushort, ctypes.c_void_p, ctypes.c_uint]
    k.UpdateResourceW.restype = ctypes.c_int
    k.EndUpdateResourceW.argtypes = [ctypes.c_void_p, ctypes.c_int]
    k.EndUpdateResourceW.restype = ctypes.c_int
    handle = k.BeginUpdateResourceW(str(output), 0)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        for type_id, name, data in resources:
            name_buffer = ctypes.create_unicode_buffer(name) if isinstance(name, str) else None
            pointer = ctypes.cast(name_buffer, ctypes.c_void_p) if name_buffer is not None else ctypes.c_void_p(name)
            value = ctypes.create_string_buffer(data)
            if not k.UpdateResourceW(handle, type_id, pointer, 1033, value, len(data)):
                raise ctypes.WinError(ctypes.get_last_error())
    except BaseException:
        k.EndUpdateResourceW(handle, 1)
        raise
    if not k.EndUpdateResourceW(handle, 0):
        raise ctypes.WinError(ctypes.get_last_error())

def update_wine(output, resources, wine, runtime, scratch):
    manifest = scratch / 'resources.tsv'
    rows = []
    for i, (type_id, name, data) in enumerate(resources):
        path = scratch / f'{i}.resource'
        path.write_bytes(data)
        name_text = name if isinstance(name, str) else '#' + str(name)
        rows.append(f'{type_id}\t{name_text}\t{winpath(path)}')
    manifest.write_text('\r\n'.join(rows), encoding='utf-8-sig')
    subprocess.run([wine, winpath(runtime/'AutoHotkeyU64.exe'), '/ErrorStdOut',
                    winpath(ROOT/'tools/build/compile_resources.ahk'), winpath(output), winpath(manifest)], check=True)

def version_block(key, value=b'', children=(), text=False):
    key = (key+'\0').encode('utf-16le')
    result = struct.pack('<HHH', 0, len(value)//2 if text else len(value), int(text))+key
    result += b'\0'*((-len(result)) % 4)
    result += value
    result += b'\0'*((-len(result)) % 4)
    for child in children:
        result += child
        result += b'\0'*((-len(result)) % 4)
    return struct.pack('<H', len(result))+result[2:]

def version_resource():
    fields = {'CompanyName':'SBezruk180', 'FileDescription':'AHK FOR GOS', 'FileVersion':'1.1.0.0',
              'InternalName':'AHK_FOR_GOS', 'OriginalFilename':'AHK_FOR_GOS.exe',
              'ProductName':'AHK FOR GOS', 'ProductVersion':'1.1.0.0',
              'LegalCopyright':'SBezruk180; AutoHotkey contributors (GPL-2.0-or-later)'}
    strings = [version_block(k, (v+'\0').encode('utf-16le'), text=True) for k,v in fields.items()]
    table = version_block('040904B0', children=strings, text=True)
    string_info = version_block('StringFileInfo', children=[table], text=True)
    var = version_block('VarFileInfo', children=[version_block('Translation', struct.pack('<HH', 0x409, 1200))], text=True)
    fixed = struct.pack('<13I', 0xFEEF04BD,0x10000,0x10001,0,0x10001,0,0x3f,0,0x40004,1,0,0,0)
    return version_block('VS_VERSION_INFO', fixed, [string_info,var])

def build(args):
    (ROOT/'.build').mkdir(exist_ok=True)
    runtime = verified_runtime(args.runtime, ROOT/'.build/toolchain')
    graph = SourceGraph(ROOT)
    flat = graph.flatten()
    if args.test_u64:
        flat, n = re.subn(r'(?m)^if \(A_PtrSize != 4 \|\| A_IsUnicode\)\r?\n\{\r?\n    MsgBox,[^\n]+\n    ExitApp, 2\r?\n\}', '; TEST ONLY: U64 logic/native GUI validation, not a game build.', flat, count=1)
        if n != 1:
            raise ValueError('Architecture guard not found; refusing test build')
        # Checkpoints exist only in the explicit Unicode test binary. Keep the
        # shipping script and its module resources byte-identical to the source.
        trace = r'FileAppend, % "PROGRESS | bootstrap`r`n", % AppHost_DataDir() . "\desktop_smoke_progress.txt", UTF-8'
        flat = re.sub(r'(?m)^InitProfiles\(\)\r?$', lambda m: trace + '\r\n' + m[0], flat, count=1)
        for call in ['MigrateConfigIfNeeded()', 'LoadLastProfile()']:
            flat = re.sub(r'(?m)^(    )?' + re.escape(call) + r'\r?$', lambda m: (m[1] or '') + trace.replace('bootstrap', call) + '\r\n' + m[0], flat, count=1)
        marker = r'DesktopSmoke_Assert(name, ok) {'
        checkpoint = r'    FileAppend, % (ok ? "PASS" : "FAIL") . " | " . name . "`r`n", % AppHost_DataDir() . "\desktop_smoke_progress.txt", UTF-8'
        flat = flat.replace(marker, marker + '\r\n' + checkpoint, 1)
        for marker, label in [
            ('Capture_ModeChanged(controlHwnd := 0, guiEvent := "", eventInfo := "", eventError := "") {', 'capture-mode entry'),
            ('    Capture_RefreshWindows()\r\n    SaveUISettings()', 'capture-mode before refresh')]:
            flat = flat.replace(marker, trace.replace('bootstrap', label) + '\r\n' + marker if marker.startswith('    ') else marker + '\r\n' + trace.replace('bootstrap', label), 1)
        native_call = '        ok := DllCall("user32\\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", enabled ? 0x11 : 0, "Int")'
        native_before = r'        FileAppend, % "AFFINITY before hwnd=" . hwnd . " enabled=" . enabled . "`r`n", % AppHost_DataDir() . "\desktop_smoke_progress.txt", UTF-8'
        native_after = r'        FileAppend, % "AFFINITY after hwnd=" . hwnd . " result=" . ok . "`r`n", % AppHost_DataDir() . "\desktop_smoke_progress.txt", UTF-8'
        flat = flat.replace(native_call, native_before + '\r\n' + native_call + '\r\n' + native_after, 1)


    output = Path(args.output or (ROOT/'dist'/('AHK_FOR_GOS_TEST_U64.exe' if args.test_u64 else 'AHK_FOR_GOS.exe'))).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.test_u64 and 'TEST_U64' not in output.name:
        raise ValueError('Test-only binary must be named with TEST_U64')
    code = flat.encode('utf-8')
    resources = [(10, '>AUTOHOTKEY SCRIPT<', code), (10, 'SOURCE_MAIN', flat.encode('cp1251'))]
    for path in graph.files:
        resources.append((10, 'SOURCE_'+path.name.upper(), path.read_bytes()))
    for path in sorted((ROOT/'laws').glob('*.txt')):
        resources.append((10, 'LAW_'+path.stem.upper(), path.read_bytes()))
        resources.append((10, 'LAW_DIGEST_'+path.stem.upper(), digest(path.read_bytes()).encode('ascii')))
    resources.append((10, 'DEFAULT_PROFILE', (ROOT/'assets/defaults/profiles.default.ini').read_bytes()))
    resources.extend([(10, 'LICENSE_PROJECT', (ROOT/'LICENSE').read_bytes()),
                      (10, 'LICENSE_ENGINE', (ROOT/'third_party/AutoHotkey-GPL-2.0.txt').read_bytes()),
                      (16, 1, version_resource())])
    names = [(t,n) for t,n,_ in resources]
    if len(names) != len(set(names)):
        raise ValueError('Ambiguous embedded resource name')
    metadata = {'product':'AHK FOR GOS', 'runtime':LOCK['version'], 'architecture':'TEST_U64' if args.test_u64 else 'ANSI_x86',
                'entry':'AHK_FOR_GOS_BY_SBEZRUK.ahk', 'source_files':[str(p.relative_to(ROOT)).replace('\\','/') for p in graph.files],
                'source_sha256':digest(code), 'sources':{str(p.relative_to(ROOT)).replace('\\','/'):digest(p.read_bytes()) for p in graph.files},
                'resources':{str(n):digest(data) for t,n,data in resources if t==10}}
    resources.append((10, 'BUILD_MANIFEST', json.dumps(metadata,sort_keys=True,ensure_ascii=True).encode('utf-8')))
    base = runtime / ('Compiler/Unicode 64-bit.bin' if args.test_u64 else LOCK['base'])
    with tempfile.TemporaryDirectory(prefix='ahk-gos-build-', dir=output.parent) as tmp:
        scratch = Path(tmp)
        staging = scratch/'AHK_FOR_GOS.exe'
        shutil.copyfile(base, staging)
        if os.name == 'nt':
            update_windows(staging, resources)
        elif args.wine:
            # Wine maps /tmp privately. Keep build inputs in the accessible checkout.
            with tempfile.TemporaryDirectory(prefix='resource-build-', dir=ROOT/'.build') as work:
                accessible = Path(work)
                local = accessible/'AHK_FOR_GOS.exe'
                shutil.copyfile(staging, local)
                update_wine(local, resources, args.wine, runtime, accessible)
                shutil.copyfile(local, staging)
        else:
            raise ValueError('Build on Windows or supply --wine and the verified runtime')
        pe = PE(staging.read_bytes())
        expected_machine = 0x8664 if args.test_u64 else 0x14c
        if pe.machine != expected_machine or pe.subsystem != 2:
            raise ValueError('Wrong PE architecture or GUI subsystem')
        for t,n,data in resources:
            if pe.resource(n,t) != data:
                raise ValueError(f'PE resource verification failed: {n}')
        os.replace(staging, output)
    metadata['exe_sha256'] = digest(output.read_bytes())
    metadata['exe_bytes'] = output.stat().st_size
    output.with_suffix('.build.json').write_text(json.dumps(metadata,indent=2,sort_keys=True)+'\n')
    output.with_suffix('.sha256').write_text(metadata['exe_sha256']+'  '+output.name+'\n')
    print(f'Built {output.name}: {metadata["exe_bytes"]:,} bytes; {len(graph.files)} source modules; {len(resources)} verified resources')
    print('SHA-256 '+metadata['exe_sha256'])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', help='Official extracted AutoHotkey 1.1.37.02 archive (base hash checked)')
    parser.add_argument('--wine', help='Linux-only Wine wrapper for build-time WinAPI')
    parser.add_argument('--output', help='EXE output path')
    parser.add_argument('--test-u64', action='store_true', help='Explicitly marked non-game U64 test binary')
    build(parser.parse_args())
