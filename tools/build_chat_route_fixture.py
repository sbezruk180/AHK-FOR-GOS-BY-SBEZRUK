#!/usr/bin/env python3
"""Exercise production chat routing with explicit counting transport seams.

No game process, physical typing, remote memory or clipboard is used here.
"""
from pathlib import Path
import argparse, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/build'))
from ahk_symbols import functions
NAMES = {
 'app/chat.ahk': ['ChatTransport_SendCore'],
 'chat_typing.ahk': ['ChatTyping_ShouldType', 'ChatTyping_IsFactionCommand', 'ChatTyping_NormalizeCommands', 'ChatTyping_DefaultCommands', 'ChatTyping_ModeFromLabel', 'ChatTyping_ModeLabel'],
}
PROBE = r'''#NoEnv
#SingleInstance Off
#NoTrayIcon
SetBatchLines, -1
global MockMode := "Off", TextSendMode := "Auto", IDCaptureState := "", GameMenuStarting := "", GameMenuLease := "", g_RemoteOperation := ""
global ChatFactionCommands := "/frac /cuff /deject /mdc /chase", ChatTypingLastError := "", ChatKeyboardLastError := ""
global ChatTransportLastMemoryFailureTick := 0, ChatTransportMemoryRetryMs := 1000
global TypedCalls := 0, PasteCalls := 0, MemoryCalls := 0, HandlesReady := 1, MemoryResult := 1
global HandlesRaiseRemote := 0
global Checks := 0, Failed := 0, Report := "Production chat routing; transport functions are counting seams.`r`n"
for _, mode in ["FactionTyping", "FactionTypingMemory"] {
    TextSendMode := mode
    ResetCounts()
    result := ChatTransport_Send("/cuff 42")
    Check("faction command uses physical typing in " . mode, result = 1 && TypedCalls = 1 && PasteCalls = 0 && MemoryCalls = 0)
    ResetCounts()
    result := ChatTransport_Send("/me regular action")
    Check("ordinary text chooses only its configured transport in " . mode, result = 1 && TypedCalls = 0 && (mode = "FactionTyping" ? PasteCalls = 1 && MemoryCalls = 0 : MemoryCalls = 1 && PasteCalls = 0))
    Check("routing never mutates saved mode " . mode, TextSendMode = mode)
}
TextSendMode := "FactionTypingMemory", HandlesReady := 0
ResetCounts()
Check("faction memory refuses unavailable memory without clipboard", ChatTransport_Send("ordinary") = -1 && TypedCalls = 0 && PasteCalls = 0 && MemoryCalls = 0)
HandlesRaiseRemote := 1
ResetCounts()
Check("precheck discovering an in-flight operation never retries", ChatTransport_Send("ordinary") = -2 && MemoryCalls = 0 && PasteCalls = 0 && TypedCalls = 0)
HandlesRaiseRemote := 0, g_RemoteOperation := ""
HandlesReady := 1, MemoryResult := -2
ResetCounts()
Check("uncertain memory send never pastes or retries", ChatTransport_Send("ordinary") = -2 && MemoryCalls = 1 && PasteCalls = 0 && TypedCalls = 0)
MemoryResult := 1, TextSendMode := "FastTyping"
ResetCounts()
Check("all-text mode still types ordinary messages", ChatTransport_Send("ordinary") = 1 && TypedCalls = 1 && MemoryCalls = 0 && PasteCalls = 0)
TextSendMode := "FactionTypingMemory"
ResetCounts()
Check("command prefixes are not confused", ChatTransport_Send("/cuffing 42") = 1 && MemoryCalls = 1 && TypedCalls = 0 && PasteCalls = 0)
Report .= "Checks=" . Checks . " Failed=" . Failed . "`r`n"
FileDelete, %A_ScriptDir%\chat_route_report.txt
FileAppend, %Report%, %A_ScriptDir%\chat_route_report.txt, UTF-8
ExitApp, %Failed%
ResetCounts() {
    global TypedCalls, PasteCalls, MemoryCalls
    TypedCalls := 0, PasteCalls := 0, MemoryCalls := 0
}
Check(name, ok) {
    global Checks, Failed, Report
    Checks++
    Failed += !ok
    Report .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
}
SendChatTyped(args*) {
    global TypedCalls
    TypedCalls++
    return 1
}
SendChatKeyboard(args*) {
    global PasteCalls
    PasteCalls++
    return 1
}
SendChatMemory(args*) {
    global MemoryCalls, MemoryResult
    MemoryCalls++
    return MemoryResult
}
checkHandles() {
    global HandlesReady, HandlesRaiseRemote, g_RemoteOperation
    if (HandlesRaiseRemote)
        g_RemoteOperation := {}
    return HandlesReady
}
ServiceUI_IsInputActive() {
    return false
}
GameMenu_ReservationIsCurrent(args*) {
    return true
}
ApplyGameProcessSelector() {
}
NormalizeTextSendMode(ByRef mode) {
    mode := ChatTyping_ModeFromLabel(mode)
}
ChatTransport_SetStatus(args*) {
}
ChatTransport_TypingDelayOverride(args*) {
    return ""
}
LogError(args*) {
}
MockPreview_Append(args*) {
}
MemoryGetShortError() {
    return "fixture failure"
}
MemoryGetStatusText() {
    return "fixture status"
}
TickNow() {
    return A_TickCount
}
GameLocator_IsActive() {
    return true
}

Training_IsActive(args*) {
    return false
}
ActionTrace_RegisterBatch(args*) {
    return 0
}
ActionTrace_RegisterItem(args*) {
    return 0
}
ActionTrace_QueueAttempt(args*) {
}
ActionTrace_QueueRetryPending(args*) {
}
ActionTrace_QueueTransportResult(args*) {
}
ActionTrace_QueueComplete(args*) {
}
ActionTrace_CancelBatch(args*) {
}
'''
def main():
 p = argparse.ArgumentParser(description=__doc__); p.add_argument('output', type=Path); args = p.parse_args()
 out = args.output.resolve()
 if out.is_relative_to(ROOT): p.error('Fixture must be outside repository')
 pieces = [PROBE]
 for path, names in NAMES.items():
  found = {n: body for n, _, _, body in functions((ROOT / path).read_text('cp1251'))}
  pieces.extend(found[n].replace('ChatTransport_SendCore(', 'ChatTransport_Send(', 1) if n == 'ChatTransport_SendCore' else found[n] for n in names)
 out.parent.mkdir(parents=True, exist_ok=True)
 out.write_text('\n\n'.join(pieces), encoding='utf-8-sig'); print(out)
if __name__ == '__main__': main()
