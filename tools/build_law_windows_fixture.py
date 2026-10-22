#!/usr/bin/env python3
"""Open/close every legacy law-page function and compare real Win32 text.

MockMode is explicit: no game commands, no claim about OBS. Source GUI/LAW IO
are real; the complete production source tree is flattened without removals.
"""
from pathlib import Path
import sys
import re
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from source_graph import SourceGraph
from ahk_symbols import functions


def main():
    if len(sys.argv)!=2:raise SystemExit('OUTPUT.ahk required')
    out=Path(sys.argv[1]).resolve()
    if out.is_relative_to(ROOT):raise SystemExit('Use disposable path outside source tree')
    graph=SourceGraph(ROOT);src=graph.flatten().replace('\r\n','\n')
    wrappers=[]
    for name,_,_,body in functions((ROOT/'helper.ahk').read_text('cp1251')):
        m=re.search(r'return Law(Doc_ShowPage|Corpus_GetPage)\("([a-z]+)", ([0-9]+)\)',body)
        if m:wrappers.append((name,m[2],int(m[3]),m[1]=='Doc_ShowPage'))
    boot=(ROOT/'app/bootstrap.ahk').read_text('cp1251')
    assert src.count(boot)==1
    src=src.replace(boot,'''MockMode := "On"
InitProfiles()
LoadUISettings()
LoadLastProfile()
MockMode := "On"
OnExit, HandleAppExit
SetTimer, AuditAllLawWindows, -100
return
''')
    cases='\n'.join('    cases.Push({Name: "'+name+'", Prefix: "'+prefix+'", Page: '+str(page)+', Window: '+str(int(window))+'})' for name,prefix,page,window in wrappers)
    prefixes=', '.join('"'+p.stem.lower()+'"' for p in sorted((ROOT/'laws').glob('*.txt')))
    probe=r'''
AuditAllLawWindows:
passed := 0, failed := 0
report := "All legacy law getters and real Win32 page windows; MockMode; NO GAME/OBS test`r`n"
cases := []
__CASES__
for _, prefix in [__PREFIXES__] {
    count := Max(1, LawCorpus_PageCount(prefix))
    Loop %count%
        cases.Push({Name: "actual_" . prefix . "_" . A_Index, Prefix: prefix, Page: A_Index, Window: 2})
}
for _, case in cases {
    expected := LawCorpus_GetPage(case.Prefix, case.Page)
    result := true
    if (case.Window) {
        if (case.Window = 2)
            LawDoc_ShowPage(case.Prefix, case.Page)
        else
            Func(case.Name).Call(1)
        Gui, 1:+LastFound
        hwnd := WinExist()
        result := expected != "" && DllCall("IsWindowVisible", "Ptr", hwnd)
        matched := false
        WinGet, controls, ControlListHwnd, ahk_id %hwnd%
        Loop, Parse, controls, `n, `r
        {
            ControlGetText, value, , ahk_id %A_LoopField%
            if (StrReplace(value, "`r") == StrReplace(expected, "`r"))
                matched := true
        }
        result := result && matched
        if (case.Window = 2)
            LawGui_Close()
        else
            Func(case.Name).Call(0)
        result := result && !DllCall("IsWindow", "Ptr", hwnd)
    } else
        result := expected != "" && Func(case.Name).Call() == expected
    if (result)
        passed++
    else
        failed++
    report .= (result ? "PASS" : "FAIL") . " | " . case.Name . " | " . case.Prefix . ":" . case.Page . "`r`n"
}
report .= "Checks=" . (passed+failed) . " Failed=" . failed . "`r`n"
FileDelete, %A_ScriptDir%\law_windows_report.txt
FileAppend, %report%, %A_ScriptDir%\law_windows_report.txt, UTF-8
ExitApp, %failed%
'''.replace('__CASES__',cases).replace('__PREFIXES__',prefixes)
    out.parent.mkdir(parents=True,exist_ok=True)
    import shutil
    shutil.copytree(ROOT/'laws',out.parent/'laws',dirs_exist_ok=True)
    out.write_text(src+'\n'+probe,encoding='utf-8-sig')
    print(out,'cases',len(wrappers))


if __name__=='__main__':main()
