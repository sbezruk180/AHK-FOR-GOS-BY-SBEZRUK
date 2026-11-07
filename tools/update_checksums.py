"""Refresh the manifest of tracked files after an intentional build or edit."""
from pathlib import Path
from hashlib import sha256
import subprocess
root=Path(__file__).resolve().parents[1]
files=sorted(p for p in subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0') if p and p!='CHECKSUMS.sha256')
(root/'CHECKSUMS.sha256').write_text(''.join(sha256((root/p).read_bytes()).hexdigest()+'  '+p+'\n' for p in files))
