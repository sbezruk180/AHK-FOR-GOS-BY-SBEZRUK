#!/usr/bin/env python3
"""Exercise compiled resource/old distribution/custom override precedence on disk."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('exe', type=Path)
p.add_argument('--wine')
p.add_argument('--wineserver')
p.add_argument('--wine-prefix')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
if a.wine and not (a.wineserver and a.wine_prefix):
    p.error('Wine needs an explicit disposable prefix and wineserver')
a.output.parent.mkdir(parents=True, exist_ok=True)
results = []
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='law-upgrade-', dir=root / '.build') as temp:
    work = Path(temp)
    exe = work / a.exe.name
    shutil.copy2(a.exe, exe)
    data = work / 'data'
    laws = data / 'laws'
    laws.mkdir(parents=True)
    originals = {}
    for row in json.loads((root / 'laws/import_2026-10-19.json').read_text())['documents']:
        if row['previous_sha256'] == row['bundled_sha256']:
            continue
        source = root / 'tests/fixtures/previous_laws' / row['file']
        assert digest(source) == row['previous_sha256']
        shutil.copy2(source, laws / row['file'])
        originals[row['file']] = row['previous_sha256']
    def run(expected):
        if a.wine:
            env = {**os.environ, 'WINEPREFIX': a.wine_prefix}
            stop = subprocess.run([a.wineserver, '-k'], env=env, capture_output=True)
            assert stop.returncode in (0, 1) and not stop.stderr, stop.stderr
            subprocess.run([a.wineserver, '-w'], env=env, check=True)
            win = lambda path: 'Z:' + str(path.resolve()).replace('/', '\\')
            cmd = [a.wine, win(exe), '--runtime-info', '--data-dir', win(data)]
        else:
            cmd = [str(exe.resolve()), '--runtime-info', '--data-dir', str(data)]
        subprocess.run(cmd, check=True, capture_output=True, timeout=40)
        text = (data / 'runtime_info_report.txt').read_text('utf-8-sig')
        assert f'LawBundledMatches={expected}\n' in text, text
        assert 'LawDocuments=20\n' in text
    run(20)
    results.append('PASS | all seven byte-identical old laws resolve to the new embedded edition')
    assert all(digest(laws / name) == sha for name, sha in originals.items())
    results.append('PASS | the old files are not rewritten or deleted')
    custom = laws / 'KON.txt'
    custom.write_bytes(custom.read_bytes() + b'\r\nCUSTOM USER NOTE MUST SURVIVE\r\n')
    edited_digest = digest(custom)
    run(19)
    assert digest(custom) == edited_digest
    results.append('PASS | edited user law remains authoritative and unchanged')
    custom.unlink()
    run(20)
    results.append('PASS | removing the override restores the embedded edition')
a.output.write_text('\n'.join(results) + '\n', encoding='utf8')
print('\n'.join(results))
