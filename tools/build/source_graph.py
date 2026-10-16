"""AHK v1 include graph. No execution or dependency discovery through the game."""
from pathlib import Path
import re

ENTRY = 'AHK_FOR_GOS_BY_SBEZRUK.ahk'

def read_source(path):
    return path.read_bytes().decode('cp1251').replace('\r\n', '\n')

class SourceGraph:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.files = []
        self.edges = []
        self._seen = set()

    def flatten(self):
        return self._expand(self.root / ENTRY, self.root).replace('\r\n', '\n').replace('\n', '\r\n')

    def _expand(self, path, include_dir):
        path = path.resolve()
        if not path.is_relative_to(self.root):
            raise ValueError(f'Include outside project: {path}')
        if path in self._seen:
            raise ValueError(f'Repeated include (would hide duplicate initialization): {path}')
        self._seen.add(path)
        self.files.append(path)
        output = []
        for line in read_source(path).splitlines():
            match = re.match(r'\s*#include\s+(.+)$', line, re.I)
            if not match:
                output.append(line)
                continue
            spec = match[1].strip().replace('%A_ScriptDir%', str(self.root)).replace('\\', '/')
            if '%' in spec or spec.startswith(('*', '<')):
                raise ValueError(f'Unsupported dynamic include: {line}')
            target = Path(spec)
            if not target.is_absolute():
                target = include_dir / target
            if target.is_dir():
                include_dir = target.resolve()
                continue
            self.edges.append((str(path.relative_to(self.root)), str(target.relative_to(self.root))))
            output.append('; included: ' + str(target.relative_to(self.root)).replace('\\', '/'))
            output.append(self._expand(target, include_dir))
        return '\n'.join(output) + '\n'
