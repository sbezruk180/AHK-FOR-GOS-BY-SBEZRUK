#!/usr/bin/env python3
"""Generate a native InputHook/SendEvent fixture outside the repository.

Actual service input, TXT resolver/dispatcher, typing engine and SafeSend are
extracted from production sources. The game predicate, chat-open flag, action
sink and decoration are seams. Wine with only one layout runs the digit timing
case on that layout and explicitly skips mixed RU/US text. No game or OBS test.
"""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from ahk_symbols import functions
NAMES={
 'service_ui.ahk':['ServiceUI_IsInputActive','ServiceUI_IsTest','ServiceUI_NewInputState','ServiceUI_ContextIsCurrent','ServiceUI_CreateInputGui','ServiceUI_InputKeyDown','ServiceUI_InputChar','ServiceUI_InputTick','ServiceUI_ModifierHeld','ServiceUI_Request'],
 'app/private_text.ahk':['PrivateText_Open','PrivateText_Resolve','PrivateText_Dispatch'],
 'app/bindings.ahk':['NormalizeTextTrigger'],
 'app/actions.ahk':['MatchGpsEnterCommand'],
 'runtime_support.ahk':['SafeSend','SafeLayout'],
 'chat_typing.ahk':[name for name,_,_,_ in functions((ROOT/'chat_typing.ahk').read_text(encoding='cp1251'))],
}
START=r'''#NoEnv
#SingleInstance Off
#NoTrayIcon
SetBatchLines, -1
SetKeyDelay, 10, -1
global MockMode := "Off", AuditTestMode := 0, AutomationEpoch := 4, CurrentProfile := "Fixture"
global PhysicalInputBusy := 0, IDCaptureState := "", GameMenuLease := "", ServiceUIInputState := "", ServiceUIConfirmState := ""
global ServiceUIAuditInputs := [], PrivateTextInputBusy := 0, BindMenuEditMode := 0, CustomFunctions := []
global Trig_GpsD := "", Trig_GpsOS := "", FixtureTrigger := "!тест", UIRoundness := 12
global FixtureLayoutFallback := 0
global PrivacyAllowed := 1, ServiceUILastInputError := "", FixtureChatOpen := 0, ChatTypingDelayMs := 0
global Count := 0, Leaked := "", KeyDownTick := 0, KeyDuration := 0, Checks := 0, Failures := 0, Report := "Private input native fixture`r`nGame predicate, action sink and decoration are seams; no game/OBS test.`r`n"
global MainWindow := 0, MainText := 0, OtherWindow := 0, DriverCase := "", PrivateRequested := 0
Gui, Main:New, +HwndMainWindow
Gui, Main:Add, Text,, Native keyboard sink
Gui, Main:Add, Edit, w270 hwndMainText
Gui, Main:Show, x400 y300 w320 h100, Input fixture
WinActivate, ahk_id %MainWindow%
OnMessage(0x102, "SinkChar")

SetTimer, RunFixture, -150
return
RunFixture:
for expected, ending in ["Space", "Enter"] {
    DriverCase := ending
    SetTimer, Emit, -120
    ok := PrivateText_Open()
    Check("TXT confirms on " . ending, ok && Count = expected)
    Check("TXT does not reach foreground chat on " . ending, Leaked = "")
    Check("TXT capture owns no focus on " . ending, WinActive("ahk_id " . MainWindow))
    Check("TXT releases hook/state on " . ending, !PhysicalInputBusy && !ServiceUI_IsInputActive() && !PrivateTextInputBusy)
}
DriverCase := "Escape"
SetTimer, Emit, -120
Check("Escape cancels without action", !PrivateText_Open() && Count = 2)
Check("Escape/text are not leaked", Leaked = "")
DriverCase := "Focus"
SetTimer, Emit, -120
Check("focus loss cancels without action", !PrivateText_Open() && Count = 2 && !PhysicalInputBusy)
Gui, Other:Destroy
WinActivate, ahk_id %MainWindow%
DriverCase := "Epoch"
SetTimer, Emit, -120
Check("generation change cancels without action", !PrivateText_Open() && Count = 2 && !PhysicalInputBusy)
Check("private input asks for capture exclusion", PrivateRequested >= 5)
PrivacyAllowed := 0
Check("privacy refusal cancels before showing text", !PrivateText_Open() && Count = 2 && !PhysicalInputBusy && !ServiceUI_IsInputActive())
Check("privacy refusal explains why input was blocked", ServiceUILastInputError != "")
PrivacyAllowed := 1
KeyDuration := 0
probeAddress := RegisterCallback("ObserveRaw", "Fast", 3)
probeHandle := DllCall("SetWindowsHookExW", "Int", 13, "Ptr", probeAddress, "Ptr", 0, "UInt", 0, "Ptr")
SendLevel, 2
beforeDelay := A_KeyDelay, beforeDuration := A_KeyDuration
Check("paced key accepted", SafeSend("{Down}", "Event", AutomationEpoch))
SendLevel, 0
Sleep, 60
DllCall("UnhookWindowsHookEx", "Ptr", probeHandle)
DllCall("GlobalFree", "Ptr", probeAddress)
Check("paced key has at least 40ms hold", KeyDuration >= 40)
Check("paced key restores caller delay", A_KeyDelay = beforeDelay && A_KeyDuration = beforeDuration)
FixtureChatOpen := 1, Leaked := ""
ControlFocus,, ahk_id %MainText%
GuiControl, Main:, %MainText%,
textStarted := TickNow()
Check("real character typing succeeds", SendChatTyped("12345678901234567890", false, false, "", 0) = 1)
textElapsed := TickNow() - textStarted
Report .= "TypingError=" . ChatTypingLastError . "`r`n"
Sleep, 80
GuiControlGet, typedDigits, Main:, %MainText%
Report .= "TypedDigits=" . typedDigits . "`r`n"
Check("real character typing delivers exact text", ("text:" . typedDigits) == "text:12345678901234567890")
Check("20 characters do not inherit menu key delays", textElapsed < 1400)
Check("typing releases input ownership and restores caller delay", !PhysicalInputBusy && A_KeyDelay = beforeDelay && A_KeyDuration = beforeDuration)
Leaked := ""
GuiControl, Main:, %MainText%,
if (!FixtureLayoutFallback) {
    Check("Russian commands and punctuation use physical typing", SendChatTyped("/m Стоп! ID:42", false, false, "", 0) = 1)
    Sleep, 80
    GuiControlGet, typedRussian, Main:, %MainText%
    Check("Russian command is delivered without corrupted symbols", typedRussian == "/m Стоп! ID:42")
} else
    Report .= "SKIP | Mixed RU/US typing: Wine cannot load both layouts; digit timing uses current layout.`r`n"
Report .= "Typing20CharsMs=" . textElapsed . "`r`n"
Report .= "Checks=" . Checks . " Failed=" . Failures . " KeyHoldMs=" . KeyDuration . "`r`n"
FileDelete, %A_ScriptDir%\private_input_report.txt
FileAppend, %Report%, %A_ScriptDir%\private_input_report.txt, UTF-8
ExitApp, %Failures%
Emit:
if (DriverCase = "Focus") {
    Gui, Other:New, +HwndOtherWindow
    Gui, Other:Show, x750 y300 w200 h100, Other application
    WinActivate, ahk_id %OtherWindow%
    return
}
if (DriverCase = "Epoch") {
    AutomationEpoch++
    return
}
SendLevel, 2
SendEvent, {Raw}!тест
SendEvent, % "{" . DriverCase . "}"
SendLevel, 0
return
Check(name, ok) {
    global Checks, Failures, Report
    Checks++
    if (!ok)
        Failures++
    Report .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
}
SinkChar(w, l, m, hwnd) {
    global Leaked, MainWindow, MainText
    if (hwnd = MainWindow || hwnd = MainText)
        Leaked .= Chr(w)
}
ObserveRaw(code, message, info) {
    global KeyDownTick, KeyDuration, MainWindow
    if (code >= 0 && NumGet(info + 0, 0, "UInt") = 0x28 && DllCall("GetForegroundWindow", "Ptr") = MainWindow) {
        stamp := NumGet(info + 0, 12, "UInt")
        if (message = 0x100)
            KeyDownTick := stamp
        else if (message = 0x101 && KeyDownTick)
            KeyDuration := stamp - KeyDownTick
    }
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", code, "Ptr", message, "Ptr", info, "Ptr")
}
ChatTyping_GetLayouts() {
    global FixtureLayoutFallback
    layouts := Fixture_LoadLayouts()
    if (!IsObject(layouts) && DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "ntdll.dll", "Ptr"), "AStr", "wine_get_version", "Ptr")) {
        ; Wine may expose only its locale layout. Keep the real engine and
        ; event timing; exercise digits on that layout, mark mixed text skipped.
        current := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
        FixtureLayoutFallback := 1
        return {US: current, RU: current}
    }
    return layouts
}
GameLocator_IsActive() {
    global MainWindow
    return WinActive("ahk_id " . MainWindow)
}
TickNow() {
    return A_TickCount
}
GetBindCatalog() {
    return [{Token: "Fixture", TriggerVar: "FixtureTrigger"}]
}
BindCatalog_IsRegistrable(meta) {
    return true
}
GetDynamicGlobalValue(name) {
    global FixtureTrigger
    return FixtureTrigger
}
ExecuteBindToken(token) {
    global Count
    Count++
}
Capture_BeforeShow(name, privacy := false) {
    global PrivateRequested, PrivacyAllowed
    if (privacy)
        PrivateRequested++
    return PrivacyAllowed ; explicit privacy API seam; actual flags are checked by desktop smoke
}
GetThemeColors(ByRef bg, ByRef panel, ByRef fg, ByRef accent, ByRef muted) {
    bg := "10131F", panel := "191C29", fg := "EEEEFF", accent := "8060F8", muted := "AAAABB"
}
GetControlSurfaceColors(ByRef surface, ByRef inputFg, ByRef card, ByRef edge, panel, fg, accent) {
    surface := panel, inputFg := fg, card := panel, edge := accent
}
AddOutlinedPanel(args*) {
}
ApplyRoundedCorners(args*) {
}
UIStyle_SetTextRole(args*) {
}
ServiceUI_Position(w,h,ByRef x,ByRef y) {
    x := 420, y := 460
}
isInChat() {
    global FixtureChatOpen
    return FixtureChatOpen
}
ServiceUI_Notify(args*) {
}
TryHandleBindMenuLine(args*) {
    return false
}
RunGpsDialogAction(args*) {
    return false
}
LawSearch_SelectMode(args*) {
}
LawSearch_GetDocName(code) {
    return code
}
LawSearch_RunActive(args*) {
}
RunCustomFunction(args*) {
}
MockPreview_Append(args*) {
}
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);args=p.parse_args()
 out=args.output.resolve()
 if out.is_relative_to(ROOT):p.error('Fixture must be outside repository')
 pieces=[START]
 for name,wanted in NAMES.items():
  source=(ROOT/name).read_text(encoding='cp1251'); found={n.lower():body for n,a,b,body in functions(source)}
  pieces.extend(found[n.lower()].replace('ChatTyping_GetLayouts() {','Fixture_LoadLayouts() {',1) if n == 'ChatTyping_GetLayouts' else found[n.lower()] for n in wanted)
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_bytes(('\n\n'.join(pieces)).replace('\n','\r\n').encode('utf-8-sig'))
 print(out)
if __name__=='__main__':main()
