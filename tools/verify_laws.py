#!/usr/bin/env python3
"""Verify the received corpus, normalization record and previous-edition migration."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
record = json.loads((root / 'laws/import_2026-10-19.json').read_text(encoding='utf-8'))
rows = record['documents']
assert len(rows) == 20
assert {r['file'] for r in rows} == {p.name for p in (root / 'laws').glob('*.txt')}
host = (root / 'app/host.ahk').read_text('cp1251')
changed = 0
for row in rows:
    path = root / 'laws' / row['file']
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == row['bundled_sha256'], path
    text = data.decode('cp1251')
    assert not data.startswith(b'\xef\xbb\xbf') and b'\n' not in data.replace(b'\r\n', b''), path
    if row['previous_sha256'] != row['bundled_sha256']:
        changed += 1
        assert f'previous["{row["file"]}"] := "{row["previous_sha256"].upper()}"' in host
    for before, after in row['character_substitutions'].items():
        assert before not in text and after in text
fsb = (root / 'laws/FSB.txt').read_text('cp1251')
assert 'отсутствует страница 2 (статьи 24–31)' in fsb
assert not re.search(r'(?m)^Статья (?:2[4-9]|3[01])\.', fsb), 'Do not fill gaps with an old edition'
assert changed == 7
print('PASS: 20 corpus digests/encodings; 7 previous-edition digests; FSB gap remains explicit')
