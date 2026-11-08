"""Publish evidence; downloads exist only when all native gates succeeded."""
from pathlib import Path
import os,json,shutil
root=Path(__file__).resolve().parents[1]
art=root/'artifacts'
group=os.environ.get('RESULT_GROUP','usability-20261106')
if group not in {'usability-20261106','context-gps-20261108'}:raise ValueError('Unknown result group')
out=root/'docs/desktop/reports'/group;out.mkdir(parents=True,exist_ok=True)
passed=all(os.environ.get(k)=='success' for k in ['BUILD_RESULT','NATIVE_RESULT','INSTALLER_RESULT'])
for folder in art.iterdir():
 if folder.name=='usability-build':continue
 target=out/folder.name;target.mkdir(exist_ok=True)
 for p in folder.rglob('*'):
  if p.is_file() and (p.name in {'summary.json','runtime-provenance.json','phase.log'} or p.suffix=='.png' or (p.suffix=='.txt' and 'coverage' not in p.name)):
   shutil.copyfile(p,target/p.name)
(out/'result.json').write_text(json.dumps({'passed':passed,'run':os.environ['RUN_ID'],'real_game':'NOT_TESTED','actual_OBS_recording':'NOT_TESTED'},indent=2)+'\n')
download=root/'downloads'/group;download.mkdir(parents=True,exist_ok=True)
(download/'STATUS.txt').write_text('Verified downloads' if passed else 'Verification failed: binary publication blocked')
if passed:
 for p in (art/'usability-build/release').iterdir():shutil.copyfile(p,root/'release'/p.name)
 for p in (art/'usability-build/dist/publish').iterdir():shutil.copyfile(p,download/p.name)
