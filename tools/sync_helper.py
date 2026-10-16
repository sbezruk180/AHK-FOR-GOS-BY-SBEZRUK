#!/usr/bin/env python3
"""Check the canonical helper is included once (legacy command retained)."""
from pathlib import Path
import argparse
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent/'build'))
from source_graph import SourceGraph
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check',action='store_true')
parser.parse_args()
root=Path(__file__).resolve().parents[1]
graph=SourceGraph(root)
graph.flatten()
if [p.name for p in graph.files].count('helper.ahk') != 1:
    raise SystemExit('helper.ahk must be included exactly once')
print('helper.ahk is canonical and included exactly once')
