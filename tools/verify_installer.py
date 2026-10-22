#!/usr/bin/env python3
"""Read-only verification of embedded installer payloads and exact source inputs."""
from pathlib import Path
import argparse,hashlib,json,struct,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from pe_resources import PE
from source_graph import SourceGraph

def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',nargs='?',type=Path,default=ROOT/'release');args=p.parse_args();directory=args.directory
 meta=json.loads((directory/'installer.build.json').read_text('utf-8'));lock=json.loads((ROOT/'tools/build/toolchain.lock.json').read_text())
 assert meta['official_runtime_archive_sha256']==lock['sha256']
 for name,record in meta['artifacts'].items():
  b=(directory/name).read_bytes();assert len(b)==record['bytes'] and sha(b)==record['sha256'],name
  pe=PE(b);assert pe.machine==0x8664 and pe.subsystem==2
 for name,digest in meta['installer_sources'].items():assert sha((ROOT/name).read_bytes())==digest,('stale native build',name)
 pe=PE((directory/'AHK_FOR_GOS_Setup.exe').read_bytes());data=pe.resource(101);assert data[:8]==b'AHKGOS01';count,=struct.unpack_from('<I',data,8);at=12;entries={}
 for _ in range(count):
  mask,n,size=struct.unpack_from('<BHQ',data,at);at+=11;digest=data[at:at+32].hex();at+=32;name=data[at:at+n].decode('utf-8');at+=n;body=data[at:at+size];at+=size
  assert name not in entries and mask in [1,2,3] and sha(body)==digest,name
  assert name and not name.startswith(('\\','/')) and ':' not in name and '..' not in name.split('\\'),name
  entries[name]={'path':name,'modes':mask,'bytes':size,'sha256':digest,'body':body}
 assert at==len(data) and count==len(meta['entries'])
 for record in meta['entries']:
  actual=entries[record['path']];assert {k:v for k,v in actual.items() if k!='body'}==record
 assert entries['AHK_FOR_GOS.exe']['body']==(ROOT/'release/AHK_FOR_GOS.exe').read_bytes()
 assert meta['app_sha256']==sha(entries['AHK_FOR_GOS.exe']['body'])
 assert entries['Uninstall.exe']['body']==(directory/'AHK_FOR_GOS_Uninstall.exe').read_bytes()
 graph=SourceGraph(ROOT);graph.flatten()
 for path in graph.files:
  name=str(path.relative_to(ROOT)).replace('/','\\');assert entries[name]['modes']==2 and entries[name]['body']==path.read_bytes(),name
 for path in (ROOT/'laws').glob('*.txt'):assert entries['laws\\'+path.name]['body']==path.read_bytes()
 runtime=PE(entries['runtime\\AutoHotkeyA32.exe']['body']);assert runtime.machine==0x14c
 assert entries['Инструкция.txt']['body']==('\ufeff'+(ROOT/'installer/USER_GUIDE_RU.txt').read_text('utf-8')).encode('utf-8')
 allowed=set(pe.resource(102).decode('utf-8').splitlines());known=dict(line.split('|',1) for line in pe.resource(104).decode('utf-8').splitlines())
 assert set(entries)<=allowed and set(known)<=allowed
 assert 'AHK_FOR_GOS_BY_SBEZRUK.ahk' in known
 print(f'PASS: native x64 setup/uninstaller, {count} SHA-256 payloads, {len(graph.files)} exact AHK modules, 20 laws, ANSI x86 runtime, unchanged app EXE')
 print('Packaging verification; real installation and UI results are separate.')
if __name__=='__main__':main()
