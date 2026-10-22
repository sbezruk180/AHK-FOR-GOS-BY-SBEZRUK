#!/usr/bin/env python3
"""Targeted second-instance dialog and ordinary portable-source diagnostics."""
from pathlib import Path
import argparse,json,os,shutil
import deep_audit as audit


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    work=out.parent/(out.name+'-work');work.mkdir(parents=True,exist_ok=True)
    ahk,exe,runtime,proof=audit.prepare(work/'hosts')
    source=work/'portable-source'
    shutil.copytree(audit.ROOT,source,ignore=shutil.ignore_patterns('.git','.build','dist','__pycache__'),dirs_exist_ok=True)
    result={'provenance':proof,'startup':[],'portable_source':[],'game':'NOT_TESTED'}
    for form,cmd in [('exe',[exe]),('source',[ahk,'/ErrorStdOut','/CP1251',source/'AHK_FOR_GOS_BY_SBEZRUK.ahk'])]:
        for repeat in (1,2,3):
            data=work/(form+'-'+str(repeat))
            if form=='source':data=source
            row=audit.startup_check(cmd,data,dict(os.environ));row.update(form=form,repeat=repeat)
            result['startup'].append(row);print(json.dumps(row),flush=True)
            if form=='source':
                for flag,report in [('selftest','selftest_report.txt'),('diagnostics','diagnostics_report.txt')]:
                    item,text=audit.invoke(cmd+['--'+flag,'--data-dir',data],data,report,300)
                    target=out/('source-'+str(repeat)+'-'+report)
                    if (data/report).exists():shutil.copyfile(data/report,target)
                    item.update(form=form,repeat=repeat,mode=flag,report=target.name)
                    result['portable_source'].append(item);print(json.dumps(item),flush=True)
            (out/'startup_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    result['completed']=True
    (out/'startup_summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
