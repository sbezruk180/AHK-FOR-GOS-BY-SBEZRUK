#!/usr/bin/env python3
"""Exercise actual application registration, Alt+T and hotstrings against a Win32 edit.

Full application startup/profile/binding/UI code is retained. Game chat status and
capture API are explicit fixture seams; no game process or OBS frames are tested.
"""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from source_graph import SourceGraph
from ahk_symbols import functions
BOOT=r'''
FileEncoding, CP1251
if (A_IsUnicode && DllCall("GetACP") != 1251) {
    for _, path in [ConfigFile, ThemesFile, AppHost_DataDir() . "\custom_functions.ini"] {
        if !FileExist(path) {
            stream := FileOpen(path, "w", "UTF-16")
            stream.Write("; Native Unicode fixture`r`n")
            stream.Close()
        }
    }
}
InitProfiles()
MigrateConfigIfNeeded()
LoadUISettings()
LoadLastProfile()
LoadCustomFunctions()
ownRuntime := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
SplitPath, ownRuntime, ownProcess
GameProcessName := ownProcess, GameWindowTitle := "Text binding fixture"
GameLocator_Configure(GameWindowTitle, GameProcessName)
SetKeyDelay, 20, 20
Gui, TextTarget:New, +HwndTextTargetHwnd
Gui, TextTarget:Add, Edit, w400 h70 hwndTextTargetEdit
Gui, TextTarget:Show, x550 y200 w440 h110, Text binding fixture
WinActivate, ahk_id %TextTargetHwnd%
global TextChatOpen := 0, TextWhileAltHeld := 0, TextAltEscape := 0, TextPrivateCommand := "", TextPrivateSent := 0, TextCleanupEscSeen := 0
global TextChecks := 0, TextFailures := 0, TextReport := "Native application text bindings`r`nGame chat status and capture API are fixture seams; no game or OBS test.`r`n", TextWindowSeen := 0
SetTimer, TextFixture_Run, -150
return
'''
PROBE=r'''
TextFixture_Run:
Bind_TextCommandInput := "!t"
TextTriggerInputMode := "Игровой чат"
Trig_GuideSignals := "!сигналы"
ApplyAllBinds()
TextCheck("Alt+T is in actual dispatch map", HotkeyDispatchMap[NormalizeHotkeyId("!t")] = "TextCommandInput")
SetTimer, TextFixture_ObserveInput, 25
SendLevel, 2
SendEvent, !t
SendLevel, 0
Sleep, 500
SetTimer, TextFixture_ObserveInput, Off
TextCheck("physical Alt+T reaches the private native input window", TextWindowSeen)
TextCheck("private opener releases state after Esc", !ServiceUI_IsInputActive() && !PrivateTextInputBusy && !PhysicalInputBusy)

TextPreviousLayout := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
TextRussianLayout := DllCall("LoadKeyboardLayoutW", "WStr", "00000419", "UInt", 0, "Ptr")
TextEnglishLayout := DllCall("LoadKeyboardLayoutW", "WStr", "00000409", "UInt", 0, "Ptr")
if ((TextRussianLayout & 0xFFFF) = 0x419 && (TextEnglishLayout & 0xFFFF) = 0x409) {
    for _, keyboardLayout in [TextEnglishLayout, TextRussianLayout] {
        DllCall("ActivateKeyboardLayout", "Ptr", keyboardLayout, "UInt", 0)
        TextWindowSeen := 0
        SetTimer, TextFixture_ObserveInput, 25
        SendLevel, 2
        SendEvent, {Alt down}{vk54sc014 down}{vk54sc014 up}{Alt up}
        SendLevel, 0
        Sleep, 500
        SetTimer, TextFixture_ObserveInput, Off
        TextCheck("physical Alt+T in layout " . Format("{:04X}", keyboardLayout & 0xFFFF), TextWindowSeen)
    }
} else
    TextReport .= "SKIP | real RU/US physical Alt+T layouts unavailable on this host`r`n"
DllCall("ActivateKeyboardLayout", "Ptr", TextPreviousLayout, "UInt", 0)

; A real held activation chord with an open chat. Escape must not become Alt+Esc.
TextChatOpen := 1, TextWindowSeen := 0, TextWhileAltHeld := 0, TextAltEscape := 0, TextPrivateCommand := "!сигналы", TextPrivateSent := 0, TextCleanupEscSeen := 0, TextGuardChecked := 0
CloseAllDocs()
current_doc := 0
TextEscAddress := RegisterCallback("TextFixture_EscapeObserver", "Fast", 3)
TextEscHook := DllCall("SetWindowsHookExW", "Int", 13, "Ptr", TextEscAddress, "Ptr", 0, "UInt", 0, "Ptr")
TextCheck("Escape observer installed", !!TextEscHook)
SetTimer, TextFixture_ObserveInput, 25
SetTimer, TextFixture_ReleaseAlt, -1500
SendLevel, 2
SendEvent, {Alt down}{t down}{t up}
SendLevel, 0
Sleep, 1800
SetTimer, TextFixture_ObserveInput, Off
DllCall("UnhookWindowsHookEx", "Ptr", TextEscHook)
DllCall("GlobalFree", "Ptr", TextEscAddress)
TextCheck("private window is visible while activation Alt is held", TextWhileAltHeld)
TextCheck("open-chat cleanup never sends Alt+Escape", !TextAltEscape)
TextCheck("held activation keeps foreground and releases input", WinActive("ahk_id " . TextTargetHwnd) && !PrivateTextInputBusy && !PhysicalInputBusy)
TextCheck("open-chat activation accepts a command after releasing Alt", TextFixture_WaitDoc(21) && TextPrivateSent)
TextCheck("chat cleanup runs before capture under input ownership", TextCleanupEscSeen)
TextChatOpen := 0, TextPrivateCommand := ""
CloseAllDocs()
current_doc := 0
TextFixture_Type("!сигналы")
TextCheck("chat command waits for Space", current_doc = 0)
TextFixture_Type(" ")
TextCheck("registered chat command dispatches on Space", TextFixture_WaitDoc(21))
for _, item in [{Text: "!сигналы", Doc: 21}, {Text: "!signals", Doc: 21}, {Text: "!cbuyfks", Doc: 21}, {Text: "!ышптфды", Doc: 21}] {
    CloseAllDocs()
    current_doc := 0
    TextFixture_Type(item.Text . " ")
    TextCheck("chat alias opens its guide " . item.Text, TextFixture_WaitDoc(item.Doc))
}
CloseAllDocs()
current_doc := 0
TextTriggerInputMode := "Окно AHK"
TextFixture_Type("!signals ")
TextCheck("private-only mode preserves chat suppression", current_doc = 0)
TextWindowSeen := 0
SetTimer, TextFixture_ObserveInput, 25
SendLevel, 2
SendEvent, !t
SendLevel, 0
Sleep, 500
SetTimer, TextFixture_ObserveInput, Off
TextCheck("Alt+T also opens in private-only mode", TextWindowSeen)
for _, opener in ["!bind", "!,byl"] {
    TextWindowSeen := 0
    SetTimer, TextFixture_ObserveInput, 25
    TextFixture_Type(opener . " ")
    Sleep, 500
    SetTimer, TextFixture_ObserveInput, Off
    TextCheck("private opener alias works independently of chat mode " . opener, TextWindowSeen)
}
; Editing must not disable the very input used to leave the editor.
TextTriggerInputMode := "Игровой чат"
BindMenuEditMode := true, BindMenuVisible := true
ApplyAllBinds()
TextWindowSeen := 0
SetTimer, TextFixture_ObserveInput, 25
SendLevel, 2
SendEvent, !t
SendLevel, 0
Sleep, 500
SetTimer, TextFixture_ObserveInput, Off
TextCheck("Alt+T remains available while editing binds", TextWindowSeen)
TextFixture_Type("!menu ")
TextCheck("chat close-menu command remains registered while editing", !BindMenuEditMode && !BindMenuVisible)
ForceCloseBindMenuEditMode("")
TextTriggerInputMode := "Окно AHK"
; Type through the actual passive InputHook, not only the pure resolver.
if (!HasCommandLineArg("--baseline")) {
for _, command in ["!signals", "!cbuyfks"] {
    CloseAllDocs()
    current_doc := 0
    ControlGetText, beforePrivate, , ahk_id %TextTargetEdit%
    TextPrivateCommand := command, TextPrivateSent := 0
    SetTimer, TextFixture_ObserveInput, 25
    SendLevel, 2
    SendEvent, !t
    SendLevel, 0
    Sleep, 500
    SetTimer, TextFixture_ObserveInput, Off
    ControlGetText, afterPrivate, , ahk_id %TextTargetEdit%
    TextCheck("private hook dispatches alias " . command, TextFixture_WaitDoc(21) && TextPrivateSent)
    TextCheck("private alias never reaches foreground edit " . command, beforePrivate == afterPrivate)
    TextCheck("private alias releases ownership " . command, !ServiceUI_IsInputActive() && !PrivateTextInputBusy && !PhysicalInputBusy)
}
}
; Natural-language phrases must keep spaces and use Enter, through the real hook.
for _, command in ["сигналы спецоперации", "сигналы спецоперции"] {
    CloseAllDocs()
    current_doc := 0
    TextPrivateCommand := command, TextPrivateSent := 0
    ControlGetText, beforePalette, , ahk_id %TextTargetEdit%
    SetTimer, TextFixture_ObserveInput, 25
    SendLevel, 2
    SendEvent, !t
    SendLevel, 0
    Sleep, 550
    SetTimer, TextFixture_ObserveInput, Off
    ControlGetText, afterPalette, , ahk_id %TextTargetEdit%
    TextCheck("palette executes a multiword natural phrase " . command, TextFixture_WaitDoc(21) && TextPrivateSent)
    TextCheck("palette phrase never leaks or retains input", beforePalette == afterPalette && !PrivateTextInputBusy && !PhysicalInputBusy)
}
TextPrivateCommand := ""
TextTriggerInputMode := "Игровой чат"
Trig_GuideSignals := "!medic"
Trig_UK := "!signals"
ApplyAllBinds()
CloseAllDocs()
current_doc := 0
TextFixture_Type("!cbuyfks ")
TextCheck("profile rebind removes the old layout alias", current_doc = 0)
TextFixture_Type("!signals ")
TextCheck("explicit command wins over an optional English alias", TextFixture_WaitDoc(8))
action := PrivateText_Resolve("!signals")
TextCheck("private resolver uses the same explicit-command precedence", IsObject(action) && action.Token = "UK")
CloseAllDocs()
current_doc := 0
TextFixture_Type("!medic ")
TextCheck("new configured command works after re-registration", TextFixture_WaitDoc(21))
FileDelete, %A_ScriptDir%\text_bind_report.txt
TextReport .= "Checks=" . TextChecks . " | Failed=" . TextFailures . "`r`n"
FileAppend, %TextReport%, %A_ScriptDir%\text_bind_report.txt, UTF-8
ExitApp, %TextFailures%
TextFixture_ReleaseAlt:
SendLevel, 2
SendEvent, {Alt up}
SendLevel, 0
return
TextFixture_ObserveInput:
if (IsObject(ServiceUIInputState) && ServiceUIInputState.GuiHwnd) {
    ; Latch observed visibility: cleanup can destroy the HWND before state release.
    if DllCall("IsWindowVisible", "Ptr", ServiceUIInputState.GuiHwnd)
        TextWindowSeen := 1
    if (!TextGuardChecked && TextChatOpen) {
        TextGuardChecked := 1
        TextCheck("private ownership blocks text even with the preparation lease", !SafeSend("x", "Event", AutomationEpoch, ServiceUIInputState))
        TextCheck("private ownership blocks Escape without its lease", !SafeSend("{Esc}", "Event", AutomationEpoch))
    }
    if (DllCall("GetAsyncKeyState", "Int", 0x12, "Short") & 0x8000) {
        TextWhileAltHeld := TextWindowSeen
        return
    }
    ; The early protected window may be painted before its hook starts.
    if (!IsObject(ServiceUIInputState.Hook) || !ServiceUIInputState.Hook.InProgress)
        return
    SendLevel, 2
    if (TextPrivateCommand != "" && !TextPrivateSent) {
        TextPrivateSent := 1
        SendEvent, % "{Raw}" . TextPrivateCommand
        if (SubStr(TextPrivateCommand, 1, 1) = "!")
            SendEvent, {Space}
        else
            SendEvent, {Enter}
    } else if (TextPrivateCommand = "")
        SendEvent, {Escape}
    SendLevel, 0
}
return
TextFixture_EscapeObserver(code, message, data) {
    global TextAltEscape, TextChatOpen, TextCleanupEscSeen
    if (code >= 0 && message = 0x100 && NumGet(data + 0, 0, "UInt") = 0x1B && !(DllCall("GetAsyncKeyState", "Int", 0x12, "Short") & 0x8000)) {
        TextChatOpen := 0
        if (IsObject(ServiceUIInputState) && ServiceUIInputState.Preparing)
            TextCleanupEscSeen := 1
    }
    if (code >= 0 && message = 0x100 && NumGet(data + 0, 0, "UInt") = 0x1B && (DllCall("GetAsyncKeyState", "Int", 0x12, "Short") & 0x8000))
        TextAltEscape := 1
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", code, "Ptr", message, "Ptr", data, "Ptr")
}
TextFixture_WaitDoc(expected) {
    global current_doc
    started := A_TickCount
    while (current_doc != expected && A_TickCount - started < 1500)
        Sleep, 10
    return current_doc = expected
}
TextFixture_Type(value) {
    SendLevel, 2
    SendEvent, % "{Raw}" . value
    SendLevel, 0
    Sleep, 300
}
TextCheck(name, ok) {
    global TextChecks, TextFailures, TextReport
    TextChecks++
    if (!ok)
        TextFailures++
    TextReport .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
    FileAppend, % (ok ? "PASS" : "FAIL") . " | " . name . "`r`n", %A_ScriptDir%\text_bind_progress.txt, UTF-8
}
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--source-root',type=Path,default=ROOT);a=p.parse_args();out=a.output.resolve();root=a.source_root.resolve()
 if out.is_relative_to(ROOT):p.error('Fixture must be outside repository')
 src=SourceGraph(root).flatten().replace('\r\n','\n')
 guard='if (A_PtrSize != 4 || A_IsUnicode)\n{\n    MsgBox, 16, Ошибка, Этот скрипт нужно запускать только через AutoHotkey 1.1 ANSI 32-bit.\n    ExitApp, 2\n}'
 assert src.count(guard)==1;src=src.replace(guard,'if (AppHost_ArgumentValue("--data-dir") = "") {\n    MsgBox, 16, Native fixture, An explicit disposable --data-dir is required.\n    ExitApp, 2\n}')
 bootstrap=(root/'app/bootstrap.ahk').read_text('cp1251');assert src.count(bootstrap)==1;src=src.replace(bootstrap,BOOT)
 for name,replacement in [('isInChat','isInChat() {\n    global TextChatOpen\n    return TextChatOpen ; no game-memory read\n}'),('Capture_ApplyWindow','Capture_ApplyWindow(hwnd, environment := "") {\n    return true ; capture API seam, not OBS verification\n}')]:
  matches=[(x,y) for n,x,y,_ in functions(src) if n==name];assert len(matches)==1;x,y=matches[0];src=src[:x]+replacement+src[y:]
 out.parent.mkdir(parents=True,exist_ok=True)
 import shutil
 shutil.copytree(root/'laws',out.parent/'laws',dirs_exist_ok=True)
 out.write_text(src+'\n'+PROBE,encoding='utf-8-sig');print(out)
if __name__=='__main__':main()
