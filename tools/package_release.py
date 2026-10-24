from pathlib import Path
import zipfile,sys,hashlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from source_graph import SourceGraph
graph=SourceGraph(ROOT);graph.flatten()
out=ROOT/'dist/publish';out.mkdir(parents=True,exist_ok=True)
for name in ['AHK_FOR_GOS.exe','AHK_FOR_GOS_Setup.exe','AHK_FOR_GOS_Uninstall.exe']:(out/name).write_bytes((ROOT/'release'/name).read_bytes())
with zipfile.ZipFile(out/'AHK_FOR_GOS_AHK_v1.1.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in graph.files:z.write(p,p.relative_to(ROOT))
 for folder in ['laws','assets']:
  for p in (ROOT/folder).rglob('*'):
   if p.is_file():z.write(p,p.relative_to(ROOT))
 # Runtime and its matching license/source are already pinned by the installer.
 sys.path.insert(0,str(ROOT/'tools'))
 from build_installer import payload_inputs
 for name,(_,data) in payload_inputs(None).items():
  if name.startswith(('runtime\\','licenses\\')):z.writestr(name.replace('\\','/'),data)
 z.writestr('Инструкция.txt','Рекомендуется установщик. Для переносимой AHK-копии запустите Запуск.cmd. F10 — настройки. Требуется совместимая CP1251.\r\n')
 z.writestr('Запуск.cmd','@echo off\r\ncd /d "%~dp0"\r\nstart "" "%~dp0runtime\\AutoHotkeyA32.exe" /CP1251 "%~dp0AHK_FOR_GOS_BY_SBEZRUK.ahk"\r\n')
files=sorted(p for p in out.iterdir() if p.name!='SHA256SUMS.txt')
(out/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in files))
print('Release files:',[p.name for p in out.iterdir()])
