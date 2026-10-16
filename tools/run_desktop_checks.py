#!/usr/bin/env python3
"""Run standalone-EXE checks in an isolated folder with disposable user data.

Windows: python tools/run_desktop_checks.py release/AHK_FOR_GOS.exe
Wine: add --wine WRAPPER --wineserver SERVER --wine-prefix PREFIX --allow-test-u64
The Wine server reset is explicit and affects only the supplied test prefix.
"""
from pathlib import Path
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time
sys.path.insert(0,str(Path(__file__).resolve().parent/'build'))
from pe_resources import PE
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('exe',type=Path)
parser.add_argument('--wine')
parser.add_argument('--wineserver')
parser.add_argument('--wine-prefix')
parser.add_argument('--allow-test-u64',action='store_true')
parser.add_argument('--output',type=Path,default=ROOT/'.build/desktop-results')
args=parser.parse_args()
meta=json.loads(PE(args.exe.read_bytes()).resource('BUILD_MANIFEST'))
test=meta['architecture']=='TEST_U64'
if test and not args.allow_test_u64:raise SystemExit('Refusing test-only binary without --allow-test-u64')
if args.wine and not (args.wineserver and args.wine_prefix):raise SystemExit('Provide an explicit disposable Wine server/prefix for repeatable native tests')
args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
(ROOT/'.build').mkdir(exist_ok=True)
results=[]
winpath=lambda p:'Z:'+str(p.resolve()).replace('/','\\')
cases=[('--runtime-info','runtime_info_report.txt'),('--desktop-smoke','desktop_smoke_report.txt'),
       ('--audit-selftest','audit_selftest_report.txt'),('--diagnostics','diagnostics_report.txt'),
       ('--selftest','selftest_report.txt'),('--context-mocktest','context_assistant_test.txt'),
       ('--autoreport-mocktest','autoreport_mocktest_report.txt'),('--law-search-test','law_search_test_report.txt'),
       ('--v1-mocktest','v1_mocktest_report.txt')]
with tempfile.TemporaryDirectory(prefix='desktop-check-',dir=ROOT/'.build') as folder:
    work=Path(folder);standalone=work/'standalone';standalone.mkdir()
    exe=standalone/args.exe.name;shutil.copy2(args.exe,exe)
    data=work/'data'
    for flag,report_name in cases:
        print('RUN '+flag,flush=True)
        if args.wine:
            env={**os.environ,'WINEPREFIX':args.wine_prefix}
            stopped=subprocess.run([args.wineserver,'-k'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            if stopped.returncode not in (0,1) or (stopped.returncode==1 and stopped.stderr):
                raise RuntimeError('Wine server reset failed: '+stopped.stderr.decode(errors='replace'))
            subprocess.run([args.wineserver,'-w'],env=env,check=True,stdout=subprocess.DEVNULL)
            cmd=[args.wine,winpath(exe),'--data-dir',winpath(data),flag]
        else:
            cmd=[str(exe),'--data-dir',str(data),flag]
        began=time.monotonic()
        try:
            process=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
            output=process.stdout
            code=process.returncode
        except subprocess.TimeoutExpired as error:
            output=error.stdout or b'';code=-999
        (args.output/(flag[2:]+'.console.txt')).write_bytes(output)
        report=data/report_name
        text=report.read_text(encoding='utf-8-sig',errors='replace') if report.is_file() else ''
        # Legacy reports use the process ANSI CP1251 without BOM.
        if report.is_file() and not report.read_bytes().startswith(b'\xef\xbb\xbf'):
            text=report.read_bytes().decode('cp1251')
        if report.is_file():shutil.copy2(report,args.output/report_name)
        unexpected_failures=re.findall(r'(?m)^(?:FAIL \|.*|\[FAIL\].*)$',text)
        expected_abi=test and flag=='--selftest' and len(unexpected_failures)==1 and 'AHK v1.1 ANSI 32-bit runtime' in unexpected_failures[0]
        status='EXPECTED_ABI_FAILURE' if expected_abi and code==1 else ('PASS' if code==0 and text and not unexpected_failures else 'FAIL')
        if flag=='--runtime-info' and status=='PASS':
            cp=re.search(r'SystemCodepage=(\d+)',text)
            if cp and cp[1]!='1251':
                status='UNSUPPORTED_CODEPAGE'
                results.append({'mode':flag,'status':status,'exit_code':code,'seconds':round(time.monotonic()-began,2)})
                print('STOP: full Cyrillic tests require Windows ANSI codepage 1251',flush=True)
                break
        row={'mode':flag,'status':status,'exit_code':code,'seconds':round(time.monotonic()-began,2),'report':report_name}
        results.append(row);print(json.dumps(row),flush=True)
summary={'architecture':meta['architecture'],'real_game':'NOT_TESTED','real_OBS':'NOT_TESTED','results':results}
(args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
failed=any(row['status'] not in ('PASS','EXPECTED_ABI_FAILURE') for row in results)
print('Results: '+str(args.output))
raise SystemExit(int(failed))
