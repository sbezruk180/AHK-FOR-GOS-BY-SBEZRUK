#!/usr/bin/env python3
"""Generate a disposable native GUI review fixture from production AHK sources.

Build: python tools/build_gui_review_fixture.py --output /tmp/ahk-gui-review
Run gui_review.ahk with AutoHotkey v1 Unicode using --ui-preview and an explicit
Windows --data-dir pointing to disposable data. Write a supported phase name to
phase.txt; phase.log records completion, errors and the settings palette.

Only the generated scratch source loses the ANSI x86 startup guard. All actual
GUI builders/renderers remain intact. No game, keyboard hook or automation is
simulated by this visual review fixture; ID values are presentation examples.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "build"))
from source_graph import SourceGraph

GUARD = '''if (A_PtrSize != 4 || A_IsUnicode)
{
    MsgBox, 16, Ошибка, Этот скрипт нужно запускать только через AutoHotkey 1.1 ANSI 32-bit.
    ExitApp, 2
}'''
STARTUP_MARKER = 'LogError("System", "Script start", "INFO")'
PRECONDITION = r'''
; SCRATCH GUI REVIEW ONLY. Never distribute this source as the application.
if (!HasCommandLineArg("--ui-preview") || AppHost_ArgumentValue("--data-dir") = "") {
    MsgBox, 16, GUI review fixture, Use --ui-preview and --data-dir with disposable data.
    ExitApp, 2
}
FileEncoding, CP1251
'''
STARTUP = r'''
global GuiReviewFixtureLastPhase := ""
global GuiReviewFixtureTimer := Func("GuiReviewFixture_Tick")
FileDelete, % A_ScriptDir . "\phase.log"
SetTimer, % GuiReviewFixtureTimer, 250
GuiReviewFixture_Tick()
'''
FIXTURE = r'''

; The phase file is a fixed whitelist, never an arbitrary command or code path.
GuiReviewFixture_Tick() {
    global GuiReviewFixtureLastPhase, hSettingsWnd, UIStyleWindows
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor
    global CurrentProfile, AutomationEpoch, current_doc, BindListVisible, HUDVisible
    FileRead, phase, % "*P65001 " . A_ScriptDir . "\phase.txt"
    if (ErrorLevel)
        return
    phase := Trim(phase, " `t`r`n" . Chr(0xFEFF))
    if (phase = "" || phase = GuiReviewFixtureLastPhase)
        return
    GuiReviewFixtureLastPhase := phase
    try {
        if !InStr("|profile|safety|appearance|documents|builder|law|service|idcapture|autoid|bindlist|hud|guide-signals|guide-pdp|guide-svu|exit|", "|" . phase . "|") {
            GuiReviewFixture_Log("ERROR unknown phase: " . phase)
            return
        }
        if (phase = "exit") {
            GuiReviewFixture_Log("PASS exit")
            ExitApp, 0
        }
        GuiReviewFixture_HideWindows()
        if (phase = "profile" || phase = "safety" || phase = "appearance" || phase = "documents") {
            Settings_SwitchPage(SettingsPageIndex(phase))
            ShowSettingsWindow()
            if (phase = "profile") {
                GetThemeColors(colorBG, colorPanel, colorText, colorAccent, colorMuted)
                entry := "ThemeMode=" . ThemeMode . " CustomMenuColor=" . CustomMenuColor
                    . " CustomTextColor=" . CustomTextColor . " CustomBorderColor=" . CustomBorderColor
                    . " OutputBG=" . colorBG . " OutputPanel=" . colorPanel
                    . " OutputText=" . colorText . " OutputAccent=" . colorAccent . " OutputMuted=" . colorMuted
                GuiReviewFixture_Log(entry)
                palette := UIStyleWindows[hSettingsWnd]
                if IsObject(palette) {
                    for key, value in palette
                        if !IsObject(value)
                            GuiReviewFixture_Log("UIStyleWindows[hSettingsWnd]." . key . "=" . value)
                } else
                    GuiReviewFixture_Log("ERROR missing settings palette")
            }
        } else if (phase = "builder") {
            OpenCustomFunctionBuilder()
        } else if (phase = "law") {
            CloseAllDocs()
            current_doc := 0
            ToggleLawDoc(5, "flter1", "ter1")
        } else if (phase = "guide-signals" || phase = "guide-pdp" || phase = "guide-svu") {
            id := phase = "guide-signals" ? 21 : (phase = "guide-pdp" ? 22 : 23)
            current_doc := 0
            Guide_Toggle(id)
            if (id = 22)
                Guide_ShowPage(id, 4)
            else if (id = 23)
                Guide_ShowPage(id, 2)
        } else if (phase = "service") {
            ServiceUI_ShowDetails("Диагностика и сведения", "AHK FOR GOS`r`n`r`nСведения отображаются в отдельном окне.`r`nНастройки и пользовательские профили сохраняются между запусками.`r`n`r`nЭто пример текста для визуальной проверки интерфейса.", true)
        } else if (phase = "idcapture") {
            ; Real passive builder, presentation-only state: no keyboard hook or timer.
            ownerHwnd := DllCall("GetForegroundWindow", "Ptr")
            reviewState := IDCapture_NewState(AutomationEpoch, ownerHwnd, 3, TickNow(), CurrentProfile)
            IDCapture_CreateGui(reviewState)
            GuiControl, IDCapture:, IDCaptureValueText, 125
            GuiControl, IDCapture:, IDCaptureCountdownText, 3 сек.
        } else if (phase = "autoid") {
            ContextAssistant_ShowConfirmationOverlay("Auto ID", "ID 125 (Alex_Smirnov) — подставить?", "F1 — принять   /   F2 — отклонить")
        } else if (phase = "bindlist") {
            BindListVisible := 1
            CreateBindList()
            UpdateBindList()
        } else if (phase = "hud") {
            HUDVisible := 1
            CreateHUD()
            UpdateHUD()
        }
        GuiReviewFixture_Log("PASS " . phase)
    } catch error {
        GuiReviewFixture_Log("ERROR " . phase . " | " . error.Message . " | " . error.What . " | line " . error.Line)
    }
}

GuiReviewFixture_HideWindows() {
    global UIStyleWindows
    for _, name in ["2", "40", "1", "16", "17", "13", "12", "42", "ServiceDetails", "IDCapture", "TerritoryMaps", "TerritoryMapView"]
        Gui, %name%:Hide
    for hwnd, palette in UIStyleWindows
        if DllCall("IsWindow", "Ptr", hwnd)
            DllCall("ShowWindow", "Ptr", hwnd, "Int", 0)
}

GuiReviewFixture_Log(text) {
    path := A_ScriptDir . "\phase.log"
    entry := A_TickCount . " | " . text . "`r`n"
    FileAppend, %entry%, %path%, UTF-8
}
'''


def build(output: Path) -> Path:
    output = output.expanduser().resolve()
    if output == ROOT or output.is_relative_to(ROOT):
        raise ValueError("--output must be a scratch directory outside the project")
    if output.exists() and not output.is_dir():
        raise ValueError("--output must name a directory, not a file")
    graph = SourceGraph(ROOT)
    source = graph.flatten().replace("\r\n", "\n")
    if source.count(GUARD) != 1:
        raise ValueError("Expected exactly one original ABI guard; fixture not generated")
    if source.count(STARTUP_MARKER) != 1:
        raise ValueError("Expected exactly one bootstrap startup marker")
    source = source.replace(GUARD, PRECONDITION, 1)
    source = source.replace(STARTUP_MARKER, STARTUP_MARKER + "\n" + STARTUP, 1)
    source += FIXTURE
    laws = sorted((ROOT / "laws").glob("*.txt"))
    if len(laws) != 20:
        raise ValueError(f"Expected 20 corpus documents, found {len(laws)}")
    output.mkdir(parents=True, exist_ok=True)
    law_output = output / "laws"
    law_output.mkdir(exist_ok=True)
    for path in laws:
        shutil.copyfile(path, law_output / path.name)
    target = output / "gui_review.ahk"
    target.write_bytes(source.replace("\n", "\r\n").encode("utf-8-sig"))
    phase_file = output / "phase.txt"
    if not phase_file.exists():
        phase_file.write_text("profile\n", encoding="utf-8")
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="scratch directory outside the project")
    args = parser.parse_args()
    try:
        target = build(args.output)
    except (OSError, ValueError) as error:
        parser.exit(2, f"error: {error}\n")
    print(target)
    print("Phases: profile safety appearance documents builder law service idcapture autoid bindlist hud guide-signals guide-pdp guide-svu exit")
    print("Run with --ui-preview --data-dir WINDOWS_ABSOLUTE_DISPOSABLE_PATH; write phase.txt to switch.")


if __name__ == "__main__":
    main()
