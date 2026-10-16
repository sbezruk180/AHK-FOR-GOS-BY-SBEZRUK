#!/usr/bin/env python3
"""Verify PE architecture, every embedded payload and the source graph."""
from pathlib import Path
import argparse, hashlib, json, sys, re
sys.path.insert(0,str(Path(__file__).resolve().parent/'build'))
from pe_resources import PE
from source_graph import SourceGraph
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('exe',type=Path)
parser.add_argument('--test-u64',action='store_true')
args=parser.parse_args()
pe=PE(args.exe.read_bytes())
assert pe.machine==(0x8664 if args.test_u64 else 0x14c), 'Unexpected PE architecture'
assert pe.subsystem==2, 'Expected GUI application'
metadata=json.loads(pe.resource('BUILD_MANIFEST'))
assert metadata['architecture']==('TEST_U64' if args.test_u64 else 'ANSI_x86')
for name, expected in metadata['resources'].items():
 assert hashlib.sha256(pe.resource(name)).hexdigest()==expected,name
for path, expected in metadata['sources'].items():
 assert hashlib.sha256((root/path).read_bytes()).hexdigest()==expected,'Source changed: '+path
 assert pe.resource('SOURCE_'+Path(path).name.upper())==(root/path).read_bytes(),path
for path in (root/'laws').glob('*.txt'):
 assert pe.resource('LAW_'+path.stem.upper())==path.read_bytes(),path
code=pe.resource('>AUTOHOTKEY SCRIPT<').decode('utf-8')
assert not re.search(r'(?mi)^\s*#include\s', code), 'Unresolved file include'
if not args.test_u64:
 assert 'if (A_PtrSize != 4 || A_IsUnicode)' in code, 'Missing ABI guard'
graph=SourceGraph(root);graph.flatten()
assert len(graph.files)==len(metadata['source_files'])
assert len([p for p in graph.files if p.name=='helper.ahk'])==1
print(f'PASS: {len(graph.files)} source files, {len(metadata["resources"])} payload hashes, 20 laws, GUI PE; no external script includes')
print('This is artifact verification, not proof of game/GUI integration.')
