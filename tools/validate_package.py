#!/usr/bin/env python3
"""Validate release bytes, required includes, helper synchronization and checksums."""
from pathlib import Path
import hashlib
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
sources = sorted(root.rglob('*.ahk'))
for path in sources:
    data = path.read_bytes()
    if data.startswith((b'\xef\xbb\xbf', b'\xff\xfe', b'\xfe\xff')):
        raise SystemExit(f'{path.name}: unexpected BOM')
    data.decode('cp1251')
    if b'\n' in data.replace(b'\r\n', b''):
        raise SystemExit(f'{path.name}: expected CRLF')

for name in ('UDF.ahk', 'common.ahk', 'runtime_support.ahk', 'tests/audit_regression.ahk'):
    if not (root / name).is_file():
        raise SystemExit(f'Missing required include: {name}')
subprocess.run([sys.executable, str(root / 'tools/sync_helper.py'), '--check'], check=True)

count = 0
for line in (root / 'CHECKSUMS.sha256').read_text().splitlines():
    expected, name = line.split('  ', 1)
    actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Checksum mismatch: {name}')
    count += 1
print(f'Package valid: {len(sources)} CP1251/CRLF sources; {count} verified files')
print('This checks packaging; run --audit-selftest for behavioural tests.')
