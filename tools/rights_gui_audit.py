#!/usr/bin/env python3
"""Run production guide regressions in native ANSI x86 source and EXE hosts."""
import argparse
import json
from pathlib import Path
import shutil
import deep_audit as audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    work = out.parent / (out.name + '-work')
    ahk, exe, _, proof = audit.prepare(work / 'hosts')
    summary = {'provenance': proof, 'release_sha256': audit.sha(audit.ROOT / 'release/AHK_FOR_GOS.exe'),
               'game': 'NOT_TESTED', 'OBS_frames': 'NOT_TESTED', 'cases': []}
    for form, command in [('exe', [exe]), ('source', [ahk, '/ErrorStdOut', '/CP1251',
                                                   audit.ROOT / 'AHK_FOR_GOS_BY_SBEZRUK.ahk'])]:
        for flag, report in [('runtime-info', 'runtime_info_report.txt'),
                             ('audit-selftest', 'audit_selftest_report.txt'),
                             ('desktop-smoke', 'desktop_smoke_report.txt')]:
            data = work / form / flag
            row, text = audit.invoke(command + ['--' + flag, '--data-dir', data], data, report, 300)
            if flag == 'runtime-info':
                assert 'SystemCodepage=1251' in text and 'PointerSize=4' in text and 'Unicode=0' in text
            if form == 'source' and flag == 'desktop-smoke' and row['exit_code'] == 2:
                expected = ('compiled standalone host', '20 documents available without external laws folder')
                if len(row['failures']) == 2 and all(any(x in f for x in expected) for f in row['failures']):
                    row['status'] = 'EXPECTED_EXE_ONLY_ASSERTIONS'
            for suffix in ('', '.console.txt'):
                path = data / (report + suffix)
                if path.exists():
                    shutil.copyfile(path, out / (form + '_' + report + suffix))
            row.update(form=form, mode=flag, report=form + '_' + report)
            summary['cases'].append(row)
            (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
            print(json.dumps(row), flush=True)
    summary['completed'] = True
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    if any(r['status'] not in ('PASS', 'EXPECTED_EXE_ONLY_ASSERTIONS') for r in summary['cases']):
        raise SystemExit('Native guide checks failed; raw reports retained')


if __name__ == '__main__':
    main()
