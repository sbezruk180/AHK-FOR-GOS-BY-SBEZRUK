#!/usr/bin/env python3
"""Import six completed audit records and actual counter hits; never invent coverage."""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import re
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'tools/build'))
from function_index import inventory,write_index
from pe_resources import PE


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('evidence',type=Path)
    p.add_argument('--run',required=True)
    p.add_argument('--startup-evidence',type=Path,help='Completed targeted startup-audit directory')
    p.add_argument('--startup-run',help='Targeted workflow run ID')
    p.add_argument('--output',type=Path,default=ROOT/'docs/desktop/reports/deep-20261022')
    args=p.parse_args()
    source=args.evidence.resolve();out=args.output.resolve()
    expected={(f,r) for f in ('exe','source') for r in (1,2,3)}
    found={};records=[]
    for file in source.glob('deep-*/summary.json'):
        data=json.loads(file.read_text());key=(data['form'],data['repeat'])
        assert key in expected and key not in found,key
        assert data.get('completed'),file
        found[key]=file.parent;records.append(data)
    assert set(found)==expected,(set(found),expected)
    release=ROOT/'release/AHK_FOR_GOS.exe';digest=hashlib.sha256(release.read_bytes()).hexdigest()
    assert all(d['release_sha256']==digest for d in records)
    inv=inventory();canonical={r['name']:r for r in inv['functions']}
    pe=PE(release.read_bytes());manifest=json.loads(pe.resource('BUILD_MANIFEST'))
    assert inv['source_sha256']==manifest['sources'],'Application source changed since audited EXE'
    hits=collections.defaultdict(lambda:collections.Counter())
    runs=collections.defaultdict(lambda:collections.defaultdict(set))
    unknown=collections.Counter();raw_reports=[]
    out.mkdir(parents=True,exist_ok=True)
    for (form,repeat),folder in sorted(found.items()):
        target=out/folder.name
        shutil.copytree(folder,target,dirs_exist_ok=True)
        for file in folder.glob('*.coverage.txt*'):
            for line in file.read_text('utf-8-sig').splitlines():
                if not line:continue
                name,count=line.rsplit('|',1);count=int(count)
                assert count>=0
                if name not in canonical:
                    unknown[name]+=count;continue
                hits[name][form]+=count
                if count:runs[name][form].add(repeat)
        for file in folder.glob('*.txt'):
            if '.coverage.txt' in file.name or file.name.endswith('.console.txt'):continue
            raw=file.read_bytes()
            text=raw.decode('utf-8-sig') if raw.startswith(b'\xef\xbb\xbf') else raw.decode('cp1251')
            failures=re.findall(r'(?m)^(?:FAIL\s*\|.*|\[FAIL\].*)$',text)
            tail=[s for s in text.splitlines()[-7:] if re.search(r'Checks|SUMMARY|Total|Passed|Failed|PASS=',s,re.I)]
            raw_reports.append({'form':form,'repeat':repeat,'file':folder.name+'/'+file.name,'failures':failures,'tail':tail})
    probe=source/'native-locale-probe'
    if probe.is_dir():shutil.copytree(probe,out/probe.name,dirs_exist_ok=True)
    coverage={name:{'EXE':f"{hits[name]['exe']} / {len(runs[name]['exe'])}/3 прогонов",'AHK':f"{hits[name]['source']} / {len(runs[name]['source'])}/3 прогонов"} for name in canonical}
    write_index(ROOT/'docs/desktop/FUNCTIONS_RU.txt',coverage)
    app=[r for r in inv['functions'] if r['kind']=='application']
    stats={'application_functions':len(app),'test_functions':len(canonical)-len(app),'named_labels':len(inv['events']),'catalog_actions':len(inv['catalog']),
      'app_entered_any':sum(bool(hits[r['name']]) for r in app),
      'app_entered_both':sum(bool(hits[r['name']]['exe'] and hits[r['name']]['source']) for r in app),
      'app_entered_three_runs_each':sum(len(runs[r['name']]['exe'])==3 and len(runs[r['name']]['source'])==3 for r in app)}
    missing=[{'name':r['name'],'file':r['file'],'line':r['line']} for r in app if not hits[r['name']]]
    result={'run_id':args.run,'workflow_url':'https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/actions/runs/'+args.run,
      'release_sha256':digest,'statistics':stats,'records':records,'report_findings':raw_reports,
      'not_entered':missing,'unknown_trace_names':dict(unknown),
      'coverage_meaning':'A counter proves entry into an instrumented copy, not branch coverage or successful game action. Original runs are separate.',
      'not_tested':['real Amazing/GTA process, memory offsets and server delivery','OBS capture frames','exclusive fullscreen','long-duration in-game resource use']}
    if args.startup_evidence:
        assert args.startup_run,'--startup-run is required with --startup-evidence'
        follow=json.loads((args.startup_evidence/'startup_summary.json').read_text())
        assert follow.get('completed')
        assert {(r['form'],r['repeat']) for r in follow['startup']}==expected
        assert len(follow['startup'])==6 and len(follow['portable_source'])==6
        if args.startup_evidence.resolve() != (out/'startup-followup').resolve():
            shutil.copytree(args.startup_evidence,out/'startup-followup',dirs_exist_ok=True)
        result['startup_followup']={'run_id':args.startup_run,'results':follow}
        result['review_notes']=[
          'Original raw startup FAIL rows are retained: the first harness did not acknowledge the expected duplicate-warning dialog. Read the targeted startup follow-up for actual behaviour.',
          'Source selftest and diagnostics fail with a separate data directory because they read source paths from AppHost_DataDir. Portable-source follow-up tests the same code with data beside sources.',
          'Source desktop-smoke retains two EXE-only assertion failures; these assertions require a compiled host and embedded law resources.',
          'Optional territory map images are missing (17 assets in 11 groups). No game or OBS test was performed.'
        ]
    (out/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['ФУНКЦИИ БЕЗ ЗАФИКСИРОВАННОГО ВХОДА В ЭТИХ СЦЕНАРИЯХ','Это пробел покрытия, а не доказательство неисправности.']
    lines += [f"{r['name']} | {r['file']}:{r['line']}" for r in missing]
    (ROOT/'docs/desktop/UNCOVERED_FUNCTIONS_RU.txt').write_text('\r\n'.join(lines)+'\r\n',encoding='utf-8-sig',newline='')
    print(json.dumps(stats,ensure_ascii=False,indent=2))
    print('Unentered application functions:',len(missing))


if __name__=='__main__':main()
