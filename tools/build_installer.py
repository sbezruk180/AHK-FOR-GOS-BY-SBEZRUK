#!/usr/bin/env python3
"""Build offline native Win32 setup + uninstaller; no .NET, script shell or web UI.

Windows: run from an x64 Visual Studio Developer Prompt (Python 3.10+).
Linux: --cxx /path/to/x86_64-w64-mingw32-g++ --windres /path/to/windres.
The immutable release EXE is embedded without code/manifest modifications.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,struct,subprocess,sys,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from source_graph import SourceGraph
from pe_resources import PE
LOCK=json.loads((ROOT/'tools/build/toolchain.lock.json').read_text())

def digest(b):return hashlib.sha256(b).hexdigest()
def icon(path):
    images=[]
    points=[(.50,.16),(.57,.41),(.84,.50),(.57,.59),(.50,.84),(.43,.59),(.16,.50),(.43,.41)]
    def inside(x,y):
        yes=False;j=len(points)-1
        for i,(xi,yi) in enumerate(points):
            xj,yj=points[j]
            if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi:yes=not yes
            j=i
        return yes
    for n in [16,32,48,64,128]:
        pixels=bytearray()
        for y in range(n-1,-1,-1):
            for x in range(n):
                u=(x+.5)/n;v=(y+.5)/n;r=.19
                alpha=255 if (r<=u<=1-r or r<=v<=1-r or (u-(r if u<.5 else 1-r))**2+(v-(r if v<.5 else 1-r))**2<=r*r) else 0
                red=int(102+35*u);green=int(73+37*v);blue=235
                if inside(u,v):red,green,blue=247,245,255
                pixels+=bytes([blue,green,red,alpha])
        mask=bytes(((n+31)//32)*4*n)
        dib=struct.pack('<IiiHHIIiiII',40,n,n*2,1,32,0,len(pixels),0,0,0,0)+pixels+mask
        images.append((n,dib))
    header=struct.pack('<HHH',0,1,len(images));offset=6+16*len(images)
    for n,b in images:header+=struct.pack('<BBBBHHII',n,n,0,0,1,32,len(b),offset);offset+=len(b)
    path.write_bytes(header+b''.join(b for n,b in images))

def payload_inputs(runtime):
    release=ROOT/'release/AHK_FOR_GOS.exe';pe=PE(release.read_bytes());manifest=json.loads(pe.resource('BUILD_MANIFEST'))
    graph=SourceGraph(ROOT);graph.flatten()
    assert manifest['sources']=={str(p.relative_to(ROOT)).replace('\\','/'):digest(p.read_bytes()) for p in graph.files},'Rebuild the release EXE first'
    inputs={}
    def add(name,mask,data):
        key=name.replace('/','\\');assert key not in inputs,key
        inputs[key]=(mask,data)
    add('AHK_FOR_GOS.exe',1,release.read_bytes())
    for p in graph.files:add(str(p.relative_to(ROOT)),2,p.read_bytes())
    for p in sorted((ROOT/'laws').glob('*.txt')):add(str(p.relative_to(ROOT)),2,p.read_bytes())
    for p in sorted((ROOT/'assets').rglob('*')):
        if p.is_file():add(str(p.relative_to(ROOT)),3,p.read_bytes())
    cache=ROOT/'.build/toolchain';cache.mkdir(parents=True,exist_ok=True)
    archive=Path(runtime) if runtime else cache/f"AutoHotkey_{LOCK['version']}.zip"
    if not archive.exists():
        request=urllib.request.Request(LOCK['url'],headers={'User-Agent':'AHKFORGOS-SetupBuild'})
        with urllib.request.urlopen(request,timeout=60) as r:archive.write_bytes(r.read())
    assert digest(archive.read_bytes())==LOCK['sha256'],'Official runtime archive hash mismatch'
    with zipfile.ZipFile(archive) as z:
        add('runtime/AutoHotkeyA32.exe',2,z.read('AutoHotkeyA32.exe'))
        add('licenses/AutoHotkey-license.txt',3,z.read('license.txt'))
    source=ROOT/'third_party/AutoHotkey-1.1.37.02-source.zip'
    assert digest(source.read_bytes())==LOCK['source_sha256']
    add('licenses/AutoHotkey-1.1.37.02-source.zip',3,source.read_bytes())
    add('licenses/PROJECT-LICENSE.txt',3,(ROOT/'LICENSE').read_bytes())
    add('licenses/THIRD_PARTY.md',3,(ROOT/'docs/desktop/THIRD_PARTY.md').read_bytes() if (ROOT/'docs/desktop/THIRD_PARTY.md').exists() else b'AutoHotkey 1.1.37.02: GPL-2.0-or-later. Corresponding source and license included.\r\n')
    add('Инструкция.txt',3,('\ufeff'+(ROOT/'installer/USER_GUIDE_RU.txt').read_text(encoding='utf-8')).encode('utf-8'))
    return inputs

def compile_program(args,work,allowed,uninstall,payload=None):
    prefix='uninstaller' if uninstall else 'setup'
    rc=work/(prefix+'.rc');obj=work/(prefix+('.res' if os.name=='nt' and not args.cxx else '.o'))
    resource=f'#pragma code_page(65001)\n1 ICON "{(work/"app.ico").as_posix()}"\n1 24 "{(ROOT/"installer/native/app.manifest").as_posix()}"\n102 RCDATA "{allowed.as_posix()}"\n'
    resource+=f'104 RCDATA "{(work/"known-hashes.txt").as_posix()}"\n'
    resource+=f'105 RCDATA "{(work/"legacy-hashes.txt").as_posix()}"\n'
    if payload:resource+=f'101 RCDATA "{payload.as_posix()}"\n'
    resource+='''1 VERSIONINFO
FILEVERSION 1,1,0,0
PRODUCTVERSION 1,1,0,0
FILEOS 0x40004L
FILETYPE 1
BEGIN
 BLOCK "StringFileInfo"
 BEGIN
  BLOCK "040904B0"
  BEGIN
   VALUE "CompanyName", "SBezruk180\\0"
   VALUE "ProductName", "AHK FOR GOS Setup\\0"
   VALUE "FileDescription", "AHK FOR GOS graphical setup and removal\\0"
   VALUE "FileVersion", "1.1.0.0\\0"
  END
 END
 BLOCK "VarFileInfo"
 BEGIN
  VALUE "Translation", 0x409, 1200
 END
END
'''
    rc.write_text(resource,encoding="utf-8")
    sources=[ROOT/'installer/native'/n for n in ['main.cpp','core.cpp','ui.cpp','selftest.cpp']]
    output=Path(args.output).resolve()/('AHK_FOR_GOS_Uninstall.exe' if uninstall else 'AHK_FOR_GOS_Setup.exe')
    if args.cxx:
        subprocess.run([args.windres or 'x86_64-w64-mingw32-windres','--input-format=rc',str(rc),str(obj)],check=True)
        cmd=[args.cxx,'-std=c++17','-O2','-s','-static','-municode','-mwindows','-D_WIN32_WINNT=0x0A00','-DUNICODE','-D_UNICODE']
        if uninstall:cmd+=['-DGOS_UNINSTALLER']
        cmd+=[str(p) for p in sources]+[str(obj),'-o',str(output),'-lgdiplus','-lcomctl32','-ldwmapi','-lbcrypt','-lshell32','-lole32','-luuid','-ladvapi32','-lversion','-lgdi32','-luser32']
    else:
        if not shutil.which('cl'):raise SystemExit('Use an x64 Visual Studio Developer Prompt or supply --cxx/--windres')
        subprocess.run(['rc','/nologo','/fo',str(obj),str(rc)],check=True)
        cmd=['cl','/nologo','/EHsc','/std:c++17','/utf-8','/O2','/MT','/D_WIN32_WINNT=0x0A00','/DUNICODE','/D_UNICODE']
        if uninstall:cmd+=['/DGOS_UNINSTALLER']
        cmd+=[str(p) for p in sources]+[str(obj),'/Fe:'+str(output),'/link','/SUBSYSTEM:WINDOWS','/MANIFEST:NO','gdiplus.lib','comctl32.lib','dwmapi.lib','bcrypt.lib','shell32.lib','ole32.lib','uuid.lib','advapi32.lib','version.lib','gdi32.lib','user32.lib']
    subprocess.run(cmd,cwd=work,check=True)
    pe=PE(output.read_bytes());assert pe.machine==0x8664 and pe.subsystem==2
    return output

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cxx');p.add_argument('--windres');p.add_argument('--runtime-archive');p.add_argument('--output',default=str(ROOT/'release'));args=p.parse_args()
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True);args.output=str(out)
    work=ROOT/'.build/installer';work.mkdir(parents=True,exist_ok=True);icon(work/'app.ico')
    inputs=payload_inputs(args.runtime_archive)
    known={name:(mask,b) for name,(mask,b) in inputs.items()}
    for old in ['uninstall.cmd','uninstall.ps1','AHK_FOR_GOS.sha256','AHK_FOR_GOS.build.json']:
        p=ROOT/old if old.endswith(('.cmd','.ps1')) else ROOT/'release'/old
        if p.exists():known[old]=(3,p.read_bytes())
    (work/'known-hashes.txt').write_text(''.join(name+'|'+digest(b)+'\n' for name,(_,b) in sorted(known.items())),encoding='utf-8',newline='\n')
    legacyCatalog=json.loads((ROOT/'installer/legacy-files.json').read_text('utf-8'))
    legacy=[(name.replace('/','\\'),sha) for section in ['files','repository_blob_variants'] for name,sha in legacyCatalog[section].items()]
    with zipfile.ZipFile(ROOT/'installer/tests/legacy-6b1a595.zip') as z:
        assert {name:digest(z.read(name)) for name in z.namelist() if not name.endswith('/')}==legacyCatalog['files'],'Historical fixture/catalog mismatch'
    (work/'legacy-hashes.txt').write_text(''.join(name+'|'+sha+'\n' for name,sha in sorted(legacy)),encoding='utf-8',newline='\n')
    allowed=work/'owned-files.txt';allowed.write_text('\n'.join(sorted(set([*known,*(name for name,_ in legacy),'Uninstall.exe'])))+'\n',encoding='utf-8',newline='\n')
    uninstaller=compile_program(args,work,allowed,True)
    inputs['Uninstall.exe']=(3,uninstaller.read_bytes())
    pack=bytearray(b'AHKGOS01'+struct.pack('<I',len(inputs)));entries=[]
    for name,(mask,b) in sorted(inputs.items()):
        n=name.encode('utf-8');pack+=struct.pack('<BHQ',mask,len(n),len(b))+hashlib.sha256(b).digest()+n+b
        entries.append({'path':name,'modes':mask,'bytes':len(b),'sha256':digest(b)})
    package=work/'payload.bin';package.write_bytes(pack)
    setup=compile_program(args,work,allowed,False,package)
    data={'architecture':'native_x64','supported_windows':'Windows 10/11 x64','offline':True,'framework_runtime_required':False,'app_runtime':'AHK 1.1.37.02 ANSI x86','app_sha256':digest((ROOT/'release/AHK_FOR_GOS.exe').read_bytes()),'official_runtime_archive_sha256':LOCK['sha256'],'installer_sources':{str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in sorted((ROOT/'installer/native').glob('*')) if p.is_file()},'entries':entries,'artifacts':{f.name:{'bytes':f.stat().st_size,'sha256':digest(f.read_bytes())} for f in [setup,uninstaller]}}
    (out/'installer.build.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for f in [setup,uninstaller]:f.with_suffix('.sha256').write_text(digest(f.read_bytes())+'  '+f.name+'\n')
    print(json.dumps(data['artifacts'],indent=2))
if __name__=='__main__':main()
