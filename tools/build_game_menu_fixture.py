#!/usr/bin/env python3
"""Generate a real-key GPS/menu probe outside the checkout.

The production GPS action, lease, chat routing and clipboard writer are used.
Only the game window, memory sender/chat flag and decoration are fixture seams.
No real game, memory offsets or OBS frames are tested.
"""
from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/build'))
from ahk_symbols import functions

NAMES = {
    'app/actions.ahk': ['RunGpsDialogAction', 'CanRunAction', 'InputAction_DoSOS', 'VehicleLookup_Execute', 'VehicleLookup_GetRegionListPosition'],
    'app/game_input.ahk': None,
    'app/gps_calibration.ahk': ['GPS_Defaults', 'GPS_FieldCatalog', 'GPS_GetSettings', 'GPS_ResolveDownCount', 'GPS_BuildPlan', 'GPS_Run'],
    'app/chat.ahk': ['SendChat', 'ChatTransport_Send', 'ChatTransport_SendCore', 'PasteOnly', 'SendRadialNumberTwice', 'SendListSelection', 'EnsureEnglishLayout', 'EnsureRussianLayout'],
    'runtime_support.ahk': ['SafeSend', 'SafeLayout', 'SendChatForEpoch', 'AutomationEpoch_IsCurrent', 'PasteOnlyForEpoch'],
    'chat_typing.ahk': ['ChatTyping_IsReady', 'ChatTyping_ModeFromLabel'],
}

START = r'''#NoEnv
#Persistent
#SingleInstance Off
#NoTrayIcon
SetBatchLines, -1
SetWinDelay, -1
SetControlDelay, -1
global MockMode := "Off", AuditTestMode := 0, AutomationEpoch := 10, CurrentProfile := "Fixture"
global PhysicalInputBusy := 0, IDCaptureState := "", GameMenuStarting := "", GameMenuLease := ""
global TextSendMode := "Memory", g_RemoteOperation := "", ChatQueueBusy := 0
global SafeModeEnabled := "Off", SafeBlockWhenChat := "Off", SafeVehicleChecks := "Off", SafeDistanceChecks := "Off"
global ActionCooldownMs := 0, LastActionTick := 0, FixtureChatOpen := 0, ChatTransportStatus := ""
global DialogDelay := 0, DialogReads := 0, DialogWaits := 0, CancelAtSelect := 0
global MainWindow := 0, ListWindow := 0, EditWindow := 0, ChatWindow := 0
global ListProc := 0, EditProc := 0, ListCallback := 0, EditCallback := 0
global Selected := -1, Applied := "", OpenCalls := 0, Escapes := 0, DownCalls := 0, CancelAtDown := 0
global ForeignMemoryCalls := 0, ForeignResult := "", CancelAfterOpen := 0, CancelledAt := 0, KeysAfterCancel := 0
global Checks := 0, Failures := 0, Report := "Native GPS/menu fixture`r`nGame window, chat flag and memory command are explicit seams.`r`n"

MainWindow := DllCall("CreateWindowExW", "UInt", 0, "WStr", "STATIC", "WStr", "Game-menu fixture"
    , "UInt", 0x10CF0000, "Int", 350, "Int", 250, "Int", 420, "Int", 360
    , "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
ListWindow := DllCall("CreateWindowExW", "UInt", 0, "WStr", "LISTBOX", "WStr", ""
    , "UInt", 0x50210001, "Int", 10, "Int", 10, "Int", 360, "Int", 230
    , "Ptr", MainWindow, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
EditWindow := DllCall("CreateWindowExW", "UInt", 0, "WStr", "EDIT", "WStr", ""
    , "UInt", 0x40010080, "Int", 10, "Int", 10, "Int", 360, "Int", 40
    , "Ptr", MainWindow, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
ChatWindow := DllCall("CreateWindowExW", "UInt", 0, "WStr", "EDIT", "WStr", "!gps155"
    , "UInt", 0x40010080, "Int", 10, "Int", 260, "Int", 360, "Int", 30
    , "Ptr", MainWindow, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
Loop, 20
    DllCall("SendMessageW", "Ptr", ListWindow, "UInt", 0x180, "Ptr", 0, "WStr", "Destination " . (A_Index - 1))
ListCallback := RegisterCallback("FixtureListProc", "Fast", 4)
EditCallback := RegisterCallback("FixtureEditProc", "Fast", 4)
ChatCallback := RegisterCallback("FixtureChatProc", "Fast", 4)
setter := A_PtrSize = 8 ? "SetWindowLongPtrW" : "SetWindowLongW"
ListProc := DllCall(setter, "Ptr", ListWindow, "Int", -4, "Ptr", ListCallback, "Ptr")
EditProc := DllCall(setter, "Ptr", EditWindow, "Int", -4, "Ptr", EditCallback, "Ptr")
global ChatProc := DllCall(setter, "Ptr", ChatWindow, "Int", -4, "Ptr", ChatCallback, "Ptr")
WinActivate, ahk_id %MainWindow%
SetTimer, RunFixture, -200
return

RunFixture:
FixtureReset(0)
Check("stale GPS never opens a command", !RunGpsDialogAction("GPS", 15, "155", AutomationEpoch - 1) && OpenCalls = 0)
started := TickNow()
Check("closed-chat GPS completes with real key events", RunGpsDialogAction("GPS", 15, "155"))
Report .= "TRACE house GPS duration ms=" . (TickNow() - started) . "`r`n"
Check("house GPS selects item 15 and types exact number", Selected = 15 && Applied == "155" && DownCalls = 15 && OpenCalls = 1)
Report .= "TRACE closed: selected=" . Selected . " applied=" . Applied . " down=" . DownCalls . " calls=" . OpenCalls . "`r`n"
Check("completed GPS releases all ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(1)
Check("open-chat GPS closes chat before command and completes", RunGpsDialogAction("GPS", 16, "10000"))
Check("organization GPS retains all five digits", Selected = 16 && Applied == "10000" && OpenCalls = 1 && Escapes = 1)
Check("open-chat path releases ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
SetTimer, TryForeignSend, -250
InputAction_DoSOS()
SetTimer, TryForeignSend, Off
Check("SOS navigates with real keys under the shared menu owner", Selected = 1 && DownCalls = 1 && OpenCalls = 1)
Check("SOS blocks unrelated transport until menu input is released", ForeignResult = -1 && ForeignMemoryCalls = 0 && !PhysicalInputBusy && !IsObject(GameMenuStarting))
FixtureReset(0)
CancelAfterOpen := 1
VehicleLookup_Execute(1, 5, "A123AA")
SetTimer, CancelGeneration, Off
Check("cancelled vehicle lookup sends no later radial or list keys", OpenCalls = 1 && CancelledAt > 0 && KeysAfterCancel = 0)
Check("cancelled vehicle lookup releases the menu owner", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
CancelAtDown := 2
Check("cancellation during real scrolling stops GPS", !RunGpsDialogAction("GPS", 15, "42"))
Check("cancelled GPS does not enter number or finish scroll", Applied = "" && DownCalls = 2 && Selected = -1)
Check("cancelled GPS releases all ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
DialogDelay := 300
Check("opening pause lets GPS appear before real navigation", RunGpsDialogAction("GPS", 15, "155") && Selected = 15 && Applied == "155" && DownCalls = 15 && OpenCalls = 1)
Check("GPS runs with unreadable dialog state and never polls it", DialogReads = 0 && DialogWaits = 0)
Check("direct sequence releases ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
CancelAfterOpen := 1
Check("GPS opening pause is cancellable", !RunGpsDialogAction("GPS", 15, "155") && CancelledAt > 0 && DownCalls = 0 && Applied = "" && OpenCalls = 1)
Check("opening cancellation releases ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
CancelAtSelect := 1
Check("GPS stops between selection and digits", !RunGpsDialogAction("GPS", 15, "155") && Selected = 15 && Applied = "" && KeysAfterCancel = 0)
Check("selection cancellation releases ownership", !PhysicalInputBusy && !IsObject(GameMenuStarting) && !IsObject(GameMenuLease))
FixtureReset(0)
Check("GPS works again after cancellation", RunGpsDialogAction("GPS", 16, "1") && Selected = 16 && Applied == "1" && OpenCalls = 1)
Report .= "Checks=" . Checks . " Failed=" . Failures . "`r`n"
FileDelete, %A_ScriptDir%\game_menu_report.txt
FileAppend, %Report%, %A_ScriptDir%\game_menu_report.txt, UTF-8
ExitApp, %Failures%

TryForeignSend:
ForeignResult := ChatTransport_Send("/r unrelated", "fixture-foreign")
return
CancelGeneration:
AutomationEpoch++
CancelledAt := TickNow()
return
ShowDelayedGps:
DllCall("ShowWindow", "Ptr", ListWindow, "Int", 5)
DllCall("SetFocus", "Ptr", ListWindow)
return
GameDialog_ReadState() {
    global DialogReads
    DialogReads++
    return ""
}
GameDialog_Wait(args*) {
    global DialogWaits
    DialogWaits++
    return false
}
FixtureReset(chat) {
    global
    Selected := -1, Applied := "", OpenCalls := 0, Escapes := 0, DownCalls := 0, CancelAtDown := 0
    ForeignMemoryCalls := 0, ForeignResult := "", CancelAfterOpen := 0, CancelledAt := 0, KeysAfterCancel := 0
    DialogDelay := 0, DialogReads := 0, DialogWaits := 0, CancelAtSelect := 0
    FixtureChatOpen := chat
    DllCall("ShowWindow", "Ptr", EditWindow, "Int", 0)
    DllCall("ShowWindow", "Ptr", ListWindow, "Int", 0)
    DllCall("ShowWindow", "Ptr", ChatWindow, "Int", chat ? 5 : 0)
    DllCall("SendMessageW", "Ptr", ListWindow, "UInt", 0x186, "Ptr", 8, "Ptr", 0)
    ControlSetText,,, ahk_id %EditWindow%
    WinActivate, ahk_id %MainWindow%
    DllCall("SetFocus", "Ptr", chat ? ChatWindow : MainWindow)
}
FixtureListProc(hwnd, msg, w, l) {
    global
    if (msg = 0x100 && CancelledAt)
        KeysAfterCancel++
    if (msg = 0x100 && w = 0x28) {
        DownCalls++
        if (CancelAtDown && DownCalls = CancelAtDown)
            AutomationEpoch++
    }
    if (msg = 0x100 && w = 0x0D) {
        Selected := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x188, "Ptr", 0, "Ptr", 0, "Int")
        DllCall("ShowWindow", "Ptr", ListWindow, "Int", 0)
        DllCall("ShowWindow", "Ptr", EditWindow, "Int", 5)
        DllCall("SetFocus", "Ptr", EditWindow)
        if (CancelAtSelect) {
            AutomationEpoch++
            CancelledAt := TickNow()
        }
        return 0
    }
    return DllCall("CallWindowProcW", "Ptr", ListProc, "Ptr", hwnd, "UInt", msg, "Ptr", w, "Ptr", l, "Ptr")
}
FixtureEditProc(hwnd, msg, w, l) {
    global
    if (msg = 0x100 && CancelledAt)
        KeysAfterCancel++
    if (msg = 0x100 && w = 0x0D) {
        VarSetCapacity(value, 128, 0)
        DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", &value, "Int", 64)
        Applied := StrGet(&value, "UTF-16")
        return 0
    }
    return DllCall("CallWindowProcW", "Ptr", EditProc, "Ptr", hwnd, "UInt", msg, "Ptr", w, "Ptr", l, "Ptr")
}
FixtureChatProc(hwnd, msg, w, l) {
    global
    if (msg = 0x100 && w = 0x1B) {
        FixtureChatOpen := 0, Escapes++
        DllCall("ShowWindow", "Ptr", ChatWindow, "Int", 0)
        DllCall("SetFocus", "Ptr", MainWindow)
        return 0
    }
    return DllCall("CallWindowProcW", "Ptr", ChatProc, "Ptr", hwnd, "UInt", msg, "Ptr", w, "Ptr", l, "Ptr")
}
Check(name, ok) {
    global
    Checks++
    if (!ok)
        Failures++
    Report .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
}
SendChatMemory(text) {
    global
    if (PhysicalInputBusy)
        return -1
    if (text != "/gps" && text != "/sos" && text != "/frac") {
        ForeignMemoryCalls++
        return 1
    }
    OpenCalls++
    if (text = "/sos")
        DllCall("SendMessageW", "Ptr", ListWindow, "UInt", 0x186, "Ptr", 0, "Ptr", 0)
    if (CancelAfterOpen)
        SetTimer, CancelGeneration, -80
    if (DialogDelay) {
        delay := -DialogDelay
        SetTimer, ShowDelayedGps, %delay%
    } else {
        DllCall("ShowWindow", "Ptr", ListWindow, "Int", 5)
        DllCall("SetFocus", "Ptr", ListWindow)
    }
    return 1
}
GameLocator_IsActive() {
    global MainWindow
    return WinActive("ahk_id " . MainWindow)
}
EnsureGameActive() {
    return GameLocator_IsActive()
}
isInChat() {
    global FixtureChatOpen
    return FixtureChatOpen
}
checkHandles() {
    return true
}
TickNow() {
    return DllCall("GetTickCount64", "Int64")
}
NormalizeTextSendMode(ByRef mode) {
    mode := ChatTyping_ModeFromLabel(mode)
}
NormalizeNumberRange(ByRef value, fallback, low, high) {
    value := value = "" ? fallback : Max(low, Min(high, value + 0))
}
ServiceUI_IsInputActive() {
    return false
}
ChatTransport_SetStatus(args*) {
}
ApplyGameProcessSelector() {
}
Evidence_MaybeCaptureReportText(args*) {
}
Notify(args*) {
}
ServiceUI_Notify(args*) {
}
LogError(source, message, severity := "") {
    global Report
    Report .= "TRACE | " . source . " | " . message . "`r`n"
}
CheckID(args*) {
    return true
}
GetCrosshairTargetDistance(args*) {
    return 0
}
isPlayerInAnyVehicle(args*) {
    return 1
}
SafeWarn(args*) {
    return false
}
MockPreview_Append(args*) {
}
ChatTyping_ShouldType(args*) {
    return false
}
ChatTyping_ModeLabel(args*) {
    return "Typing"
}
ChatTransport_TypingDelayOverride(args*) {
    return 0
}
SendChatTyped(args*) {
    return -1
}
SendChatKeyboard(args*) {
    return false
}
MemoryGetShortError(args*) {
    return "fixture"
}
MemoryGetStatusText(args*) {
    return "fixture"
}

Training_IsActive(args*) {
    return false
}
Training_CanRunAction(args*) {
    return false
}
ActionTrace_Begin(args*) {
    return 0
}
ActionTrace_Add(args*) {
    return 0
}
ActionTrace_Update(args*) {
}
ActionTrace_Finish(args*) {
}
ActionTrace_RecordTransport(args*) {
}
ActionTrace_Rejected(args*) {
    return false
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    args = parser.parse_args()
    out = args.output.resolve()
    if out.is_relative_to(ROOT):
        parser.error('Fixture must be outside repository')
    pieces = [START]
    for path, wanted in NAMES.items():
        source = (args.source_root / path).read_text(encoding='cp1251')
        for name, _, _, body in functions(source):
            if name in wanted if wanted is not None else name.startswith('GameMenu_'):
                pieces.append(body)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes('\n\n'.join(pieces).replace('\n', '\r\n').encode('utf-8-sig'))
    print(out)


if __name__ == '__main__':
    main()
