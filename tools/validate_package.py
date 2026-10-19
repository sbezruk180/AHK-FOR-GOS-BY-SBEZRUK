#!/usr/bin/env python3
"""Validate exact release bytes, include graph, source preservation and manifest."""
from pathlib import Path
import hashlib
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/build'))
from source_graph import SourceGraph

graph=SourceGraph(root);graph.flatten()
sources=graph.files+[root/'tools/audit_gui.ahk',root/'tools/build/compile_resources.ahk']
for path in sources:
    data=path.read_bytes()
    if data.startswith((b'\xef\xbb\xbf',b'\xff\xfe',b'\xfe\xff')):
        raise SystemExit(f'{path.name}: unexpected BOM')
    data.decode('cp1251')
    if b'\n' in data.replace(b'\r\n',b''):
        raise SystemExit(f'{path.name}: expected CRLF')
for path in (root/'laws').glob('*.txt'):
    data=path.read_bytes();data.decode('cp1251')
    if data.startswith((b'\xef\xbb\xbf',b'\xff\xfe',b'\xfe\xff')) or b'\n' in data.replace(b'\r\n',b''):
        raise SystemExit('Unexpected LAW encoding/newlines: '+path.name)
subprocess.run([sys.executable,str(root/'tools/verify_laws.py')],check=True)
subprocess.run([sys.executable,str(root/'tools/sync_helper.py'),'--check'],check=True)
subprocess.run([sys.executable,str(root/'tools/check_migration.py')],check=True)

listed=set()
for line in (root/'CHECKSUMS.sha256').read_text().splitlines():
    expected,name=line.split('  ',1)
    if name in listed:raise SystemExit('Repeated manifest file: '+name)
    listed.add(name)
    if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:
        raise SystemExit('Checksum mismatch: '+name)
tracked=set(p for p in subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0') if p and p!='CHECKSUMS.sha256')
if listed!=tracked:
    raise SystemExit('Manifest/tracked set mismatch: '+str(sorted(listed^tracked)))
exe=root/'release/AHK_FOR_GOS.exe'
if exe.is_file():
    subprocess.run([sys.executable,str(root/'tools/verify_exe.py'),str(exe)],check=True)
    forbidden=list((root/'release').glob('*TEST_U64*'))
    if forbidden:raise SystemExit('Test-only binary in release directory')
print(f'Package valid: {len(sources)} CP1251/CRLF sources; {len(graph.files)} embedded modules; {len(listed)} verified tracked files')
print('This validates packaging and code correspondence, not the actual game or OBS.')
