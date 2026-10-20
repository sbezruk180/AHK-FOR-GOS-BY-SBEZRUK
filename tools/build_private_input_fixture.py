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
 'service_ui.ahk':['ServiceUI_IsInputActive','ServiceUI_IsTest','ServiceUI_NewInputState','ServiceUI_ContextIsCurrent','ServiceUI_CreateInputGui','ServiceUI_InputKeyDown','ServiceUI_InputChar','ServiceUI_InputTick','ServiceUI_ModifierHeld','ServiceUI_CreateInputHook','ServiceUI_ReleaseInputCapture','ServiceUI_Request'],
 'app/private_text.ahk':['PrivateText_Open','PrivateText_ReportBlocked','PrivateText_PrepareChat','PrivateText_Resolve','PrivateText_ResolveExact','PrivateText_Dispatch','PrivateText_SearchModes'],
 'app/bindings.ahk':['NormalizeTextTrigger'],
 'app/text_commands.ahk':['TextCommands_IsOpener','TextCommands_OpenerTriggers','TextCommands_LayoutVariant','TextCommands_ResolveAlias','TextCommands_GetAliasRoutes','TextCommands_EnglishTrigger'],
 'app/actions.ahk':['MatchGpsEnterCommand','RunGpsInputTrigger','ReadGpsInputNumber'],
 'app/core.ahk':['EraseGpsTypedCommand'],
 'app/game_input.ahk':['GameMenu_Reserve','GameMenu_ReservationIsCurrent','GameMenu_Close','GameMenu_Release'],
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
global ChatTypingSpeedMode := "Fixed", ChatTypingMinCPS := 20, ChatTypingMaxCPS := 40
global FixtureLayoutFallback := 0, GameMenuStarting := "", ChatQueueBusy := 0
global FixtureStatesCreated := 0, FixtureStatesDeleted := 0, CapturedGps := "", GpsBurst := "55"
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
observerState := ServiceUI_NewInputState("probe", "probe", 5, 10, "", true, AutomationEpoch, MainWindow, CurrentProfile, TickNow())
observerState := ""
Check("state lifetime observer detects a released plain state", FixtureStatesCreated = 1 && FixtureStatesDeleted = 1)
for expected, ending in ["Space", "Enter"] {
    DriverCase := ending
    SetTimer, Emit, -120
    ok := PrivateText_Open()
    Check("TXT confirms on " . ending, ok && Count = expected)
    Check("TXT does not reach foreground chat on " . ending, Leaked = "")
    Check("TXT capture owns no focus on " . ending, WinActive("ahk_id " . MainWindow))
    Check("TXT releases hook/state on " . ending, !PhysicalInputBusy && !ServiceUI_IsInputActive() && !PrivateTextInputBusy)
}
Sleep, 60
Check("input states are released after timer and hook cleanup", FixtureStatesCreated = FixtureStatesDeleted)
for _, gpsCase in [{Burst: "55", Expected: "155"}, {Burst: "0000", Expected: "10000"}] {
    FixtureChatOpen := 1, CapturedGps := "", GpsBurst := gpsCase.Burst
    GuiControl, Main:, %MainText%, !gps1
    ControlFocus,, ahk_id %MainText%
    DriverCase := "GpsBurst"
    SetTimer, Emit, -20
    SetTimer, GpsFallback, -1000
    RunGpsInputTrigger("!gps", "GPS", 15, "1")
    SetTimer, GpsFallback, Off
    Check("fast GPS number survives prefix cleanup " . gpsCase.Expected, ("ID:" . CapturedGps) == ("ID:" . gpsCase.Expected))
    Check("fast GPS input releases ownership " . gpsCase.Expected, !PhysicalInputBusy && !ServiceUI_IsInputActive() && !IsObject(GameMenuStarting))
}
Sleep, 60
Check("prefetched GPS states are released too", FixtureStatesCreated = FixtureStatesDeleted)
FixtureChatOpen := 0
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
; A plain Win32 target uses DefWindowProc for language requests. An AHK GUI
; can intercept WM_INPUTLANGCHANGEREQUEST and does not represent a game target.
MainWindow := DllCall("CreateWindowExW", "UInt", 0, "WStr", "STATIC", "WStr", "Native typing target"
    , "UInt", 0x10CF0000, "Int", 400, "Int", 300, "Int", 340, "Int", 150
    , "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
MainText := DllCall("CreateWindowExW", "UInt", 0, "WStr", "EDIT", "WStr", ""
    , "UInt", 0x50010080, "Int", 15, "Int", 15, "Int", 280, "Int", 30
    , "Ptr", MainWindow, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
WinActivate, ahk_id %MainWindow%
FixtureChatOpen := 1, Leaked := ""
ControlFocus,, ahk_id %MainText%
ControlSetText,,, ahk_id %MainText%
textStarted := TickNow()
Check("real character typing succeeds", SendChatTyped("12345678901234567890", false, false, "", 0) = 1)
textElapsed := TickNow() - textStarted
Report .= "TypingError=" . ChatTypingLastError . "`r`n"
Sleep, 80
ControlGetText, typedDigits,, ahk_id %MainText%
Report .= "TypedDigits=" . typedDigits . "`r`n"
Check("real character typing delivers exact text", ("text:" . typedDigits) == "text:12345678901234567890")
Check("20 characters do not inherit menu key delays", textElapsed < 1400)
Check("typing releases input ownership and restores caller delay", !PhysicalInputBusy && A_KeyDelay = beforeDelay && A_KeyDuration = beforeDuration)
Leaked := ""
ControlSetText,,, ahk_id %MainText%
savedSpeed := [ChatTypingDelayMs, ChatTypingSpeedMode, ChatTypingMinCPS, ChatTypingMaxCPS]
ChatTypingDelayMs := 1, ChatTypingSpeedMode := "RandomCPS", ChatTypingMinCPS := 5, ChatTypingMaxCPS := 5
ControlSetText,,, ahk_id %MainText%
slowStarted := TickNow()
slowResult := SendChatTyped("1234567890", false, false)
slowElapsed := TickNow() - slowStarted
ControlGetText, slowText,, ahk_id %MainText%
Check("CPS pacing delivers exact physical text", slowResult = 1 && slowText == "1234567890")
Check("five CPS paces ten characters across nine intervals", slowElapsed >= 1750 && slowElapsed < 3500)
Report .= "FiveCps10CharsMs=" . slowElapsed . "`r`n"
ChatTypingMinCPS := 1, ChatTypingMaxCPS := 1
ControlSetText,,, ahk_id %MainText%
SetTimer, CancelSlowTyping, -350
cancelStarted := TickNow()
cancelResult := SendChatTyped("1234567890", false, false)
cancelElapsed := TickNow() - cancelStarted
SetTimer, CancelSlowTyping, Off
ControlGetText, cancelledText,, ahk_id %MainText%
Check("slow CPS cancellation is prompt", cancelResult = -2 && cancelElapsed < 800 && StrLen(cancelledText) <= 2)
Check("slow CPS cancellation releases input", !PhysicalInputBusy)
ChatTypingDelayMs := savedSpeed[1], ChatTypingSpeedMode := savedSpeed[2], ChatTypingMinCPS := savedSpeed[3], ChatTypingMaxCPS := savedSpeed[4]
if (!FixtureLayoutFallback) {
    russianResult := SendChatTyped("/m Стоп! ID:42", false, false, "", 0)
    Check("Russian physical typing result=" . russianResult . " error=" . ChatTypingLastError . " layout=" . InputLayoutLastError, russianResult = 1)
    Sleep, 80
    ControlGetText, typedRussian,, ahk_id %MainText%
    Check("Russian exact text actual=[" . typedRussian . "]", typedRussian == "/m Стоп! ID:42")
} else
    Report .= "SKIP | Mixed RU/US typing: Wine cannot load both layouts; digit timing uses current layout.`r`n"
Report .= "InputStatesCreated=" . FixtureStatesCreated . " InputStatesDeleted=" . FixtureStatesDeleted . "`r`n"
Report .= "Typing20CharsMs=" . textElapsed . "`r`n"
Report .= "Checks=" . Checks . " Failed=" . Failures . " KeyHoldMs=" . KeyDuration . "`r`n"
FileDelete, %A_ScriptDir%\private_input_report.txt
FileAppend, %Report%, %A_ScriptDir%\private_input_report.txt, UTF-8
ExitApp, %Failures%
CancelSlowTyping:
AutomationEpoch++
return
GpsFallback:
SendLevel, 2
SendEvent, {Escape}
SendLevel, 0
return
Emit:
if (DriverCase = "GpsBurst") {
    SendLevel, 2
    SendEvent, % "{Raw}" . GpsBurst
    SendEvent, {Space}
    SendLevel, 0
    return
}
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
RunGpsDialogAction(name, down, number, epoch := 0) {
    global CapturedGps
    CapturedGps := number
    return true
}
IsGameActive() {
    return GameLocator_IsActive()
}
BindMenuWarn(args*) {
    return false
}
ServiceUI_NewInputState(args*) {
    global FixtureStatesCreated
    state := Fixture_ProductionNewState(args*)
    state.base := {__Delete: Func("FixtureStateDeleted")}
    FixtureStatesCreated++
    return state
}
FixtureStateDeleted(state) {
    global FixtureStatesDeleted
    FixtureStatesDeleted++
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
LogError(args*) {
}
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);args=p.parse_args()
 out=args.output.resolve()
 if out.is_relative_to(ROOT):p.error('Fixture must be outside repository')
 pieces=[START]
 for name,wanted in NAMES.items():
  source=(ROOT/name).read_text(encoding='cp1251'); found={n.lower():body for n,a,b,body in functions(source)}
  for n in wanted:
   body=found[n.lower()]
   if n == 'ChatTyping_GetLayouts':body=body.replace('ChatTyping_GetLayouts() {','Fixture_LoadLayouts() {',1)
   if n == 'ServiceUI_NewInputState':body=body.replace('ServiceUI_NewInputState(','Fixture_ProductionNewState(',1)
   pieces.append(body)
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_bytes(('\n\n'.join(pieces)).replace('\n','\r\n').encode('utf-8-sig'))
 print(out)
if __name__=='__main__':main()
