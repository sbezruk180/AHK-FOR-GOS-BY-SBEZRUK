#!/usr/bin/env python3
"""Probe real RP queues; on A32 execute the production call stub in this process.

The target is an owned assembly function, never GTA. U64 uses a counting sender.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/build'))
from ahk_symbols import functions

NAMES = {
    'app/actions.ahk': ['Action_DoRights'],
    'app/chat.ahk': ['SendConfigSequence', 'ChatTransport_Send'],
    'app/automation.ahk': ['ChatQueue_Tick', 'ChatQueue_EnqueueSequence'],
    'runtime_support.ahk': ['ChatQueue_EnqueueBatch', 'ChatQueue_CompleteItem', 'QueueBatch_Prune', 'QueueItem_IsCurrent'],
    'chat_typing.ahk': ['ChatTyping_ModeFromLabel'],
    'UDF.ahk': ['SendChatMemory'],
    'common.ahk': ['callWithParams', 'MemoryInjectionEnter', 'MemoryInjectionLeave', 'MemoryWaitRemote',
                   'MemoryRemotePoll', 'MemoryAttemptResult', 'MemorySetStage', 'MemoryFail',
                   'MemoryTickElapsed', 'IsLikelyPointer', 'writeString', 'writeRaw', 'createRemoteThread', 'closeProcess'],
}

PROBE = r'''#NoEnv
#SingleInstance Off
#NoTrayIcon
SetBatchLines, -1
global MockMode := "Off", AuditTestMode := 0, AutomationEpoch := 10
global IDCaptureState := "", PhysicalInputBusy := 0, GameMenuStarting := "", GameMenuLease := ""
global TextSendMode := "Memory", g_RemoteOperation := "", g_MemoryInjectionBusy := 0, MemoryInjectionOwnerActive := 0
global g_RemoteLaunchSerial := 0, g_MemoryStage := "", g_MemoryStageCode := 0, g_MemoryStageDetail := "", g_MemoryStageTick := 0
global ERROR_OK := 0, ERROR_INVALID_HANDLE := 2, ERROR_ALLOC_MEMORY := 3, ERROR_WRITE_MEMORY := 4, ERROR_WAIT_FOR_OBJECT := 5, ERROR_MEMORY_BUSY := 6
global ChatQueueItems := [], ChatQueueBusy := 0, ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
global ChatQueueMaxItems := 200, ChatQueueMinDelay := 250, ChatQueueMaxRetries := 2
global QueueBatchStates := {}, QueueBatchNextId := 0, QueueFailureGeneration := 0, SequenceLineDelay := 700
global AutoReportSentCount := 0, AutoReportSkippedCount := 0, ChatTransportStatus := ""
global SentLines := [], SendCalls := 0, PasteCalls := 0, ForceResult := "", Notices := 0
global Checks := 0, Failed := 0, Report := "Rights queue and owned process call-stub fixture`r`n"
global hGTA := 0, dwSAMP := 0, pInjectFunc := 0, pParam1 := 0, pParam2 := 0, pParam3 := 0, pParam4 := 0, pParam5 := 0
global OwnedPage := 0, Counter := 0
__RIGHTS_DEFAULT__
Report .= "PointerSize=" . A_PtrSize . "; real game and server NOT tested`r`n"
if (A_PtrSize = 4) {
    hGTA := DllCall("GetCurrentProcess", "Ptr")
    OwnedPage := DllCall("VirtualAlloc", "Ptr", 0, "UPtr", 8192, "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!OwnedPage)
        ExitApp, 99
    Counter := OwnedPage + 512, dwSAMP := OwnedPage + 256 - 0x5820
    pParam1 := OwnedPage + 1024, pParam2 := OwnedPage + 2048, pParam3 := OwnedPage + 3072
    pParam4 := OwnedPage + 4096, pParam5 := OwnedPage + 5120, pInjectFunc := OwnedPage + 6144
    WriteNormalTarget()
    Report .= "NATIVE A32: production injection stub targets owned current process only.`r`n"
} else
    Report .= "SKIP native x86 execution on U64; sender is a counting seam.`r`n"
Check("rights action queues all five original lines", Action_DoRights() = 5 && ChatQueueItems.Length() = 5)
batch := ChatQueueItems[1].Batch
Check("rights preserves the sequence pause", ChatQueueItems[1].DelayAfter = 1000)
Drain()
Check("all five rights lines are sent in order", SentLines.Length() = 5 && JoinLines() == RP_Rights)
Report .= "TRACE first sequence: sent=" . SentLines.Length() . "; state=" . QueueBatchStates[batch].State . "; calls=" . SendCalls . "`r`n"
Check("rights batch completes and releases its sender", QueueBatchStates[batch].State = "sent" && !ChatQueueBusy && !g_MemoryInjectionBusy)
Check("memory rights never invokes clipboard", PasteCalls = 0)
ResetFixture()
Action_DoRights()
batch := ChatQueueItems[1].Batch
g_RemoteOperation := {Thread: 1}
ChatQueue_Tick()
Check("pre-existing memory operation does not consume a line or retry", ChatQueueItems.Length() = 5 && ChatQueueItems[1].Tries = 0 && SendCalls = 0 && QueueBatchStates[batch].State = "queued")
g_RemoteOperation := ""
Drain()
Check("rights resumes after existing operation completes", SentLines.Length() = 5 && QueueBatchStates[batch].State = "sent")
ResetFixture()
Action_DoRights()
batch := ChatQueueItems[1].Batch
ChatQueue_Tick()
AutomationEpoch++
Drain()
Check("stop after first line suppresses all remaining rights", SendCalls = 1 && SentLines.Length() = 1 && QueueBatchStates[batch].State = "cancelled")
ResetFixture()
ForceResult := -2
Action_DoRights()
batch := ChatQueueItems[1].Batch
Drain()
Check("uncertain actual attempt is never retried", SendCalls = 1 && SentLines.Length() = 1 && QueueBatchStates[batch].State = "unknown")
Check("rights transport failure is visible in own notification", Notices = 1)
ResetFixture()
RP_Rights := "custom first`r`n`r`ncustom second`ncustom third"
Check("custom rights lines remain supported", Action_DoRights() = 3)
Drain()
Check("custom rights keeps exact text and order", SentLines.Length() = 3 && JoinLines() == "custom first`ncustom second`ncustom third")
if (A_PtrSize = 4) {
    ; ExitThread bypasses the normal-return marker, like a failing native call.
    VarSetCapacity(leaf, 12, 0)
    NumPut(0x68, leaf, 0, "UChar"), NumPut(0xC0000005, leaf, 1, "UInt")
    NumPut(0xB8, leaf, 5, "UChar")
    NumPut(DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "kernel32.dll", "Ptr"), "AStr", "ExitThread", "Ptr"), leaf, 6, "UInt")
    NumPut(0xD0FF, leaf, 10, "UShort")
    writeRaw(hGTA, OwnedPage + 256, &leaf, 12)
    DllCall("FlushInstructionCache", "Ptr", hGTA, "Ptr", OwnedPage + 256, "UPtr", 12)
    Check("abnormal thread exit still returns uncertain", FixtureNativeMemorySend("failure") = -2 && !IsObject(g_RemoteOperation) && !g_MemoryInjectionBusy)
    DllCall("VirtualFree", "Ptr", OwnedPage, "UPtr", 0, "UInt", 0x8000)
}
Report .= "Checks=" . Checks . " Failed=" . Failed . "`r`n"
FileDelete, %A_ScriptDir%\memory_sequence_report.txt
FileAppend, %Report%, %A_ScriptDir%\memory_sequence_report.txt, UTF-8
ExitApp, %Failed%

WriteNormalTarget() {
    global
    ; Increment an owned counter; return a non-status DWORD normally, pop arg.
    VarSetCapacity(leaf, 14, 0)
    NumPut(0x05FF, leaf, 0, "UShort"), NumPut(Counter, leaf, 2, "UInt")
    NumPut(0xB8, leaf, 6, "UChar"), NumPut(0xFFFFFFFF, leaf, 7, "UInt")
    NumPut(0xC2, leaf, 11, "UChar"), NumPut(4, leaf, 12, "UShort")
    writeRaw(hGTA, OwnedPage + 256, &leaf, 14)
    DllCall("FlushInstructionCache", "Ptr", hGTA, "Ptr", OwnedPage + 256, "UPtr", 14)
}
SendChatMemory(text) {
    global
    SendCalls++
    if (A_PtrSize = 4) {
        before := NumGet(Counter + 0, 0, "UInt")
        result := FixtureNativeMemorySend(text)
        if (NumGet(Counter + 0, 0, "UInt") > before)
            SentLines.Push(text)
    } else {
        SentLines.Push(text)
        result := 1
    }
    return ForceResult == "" ? result : ForceResult
}
ResetFixture() {
    global
    ChatQueueItems := [], ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
    SentLines := [], SendCalls := 0, ForceResult := "", Notices := 0
}
Drain() {
    global
    Loop, 20 {
        if (!ChatQueueItems.Length())
            break
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
        ChatQueue_Tick()
    }
}
JoinLines() {
    global SentLines
    result := ""
    for _, line in SentLines
        result .= (result = "" ? "" : "`n") . line
    return result
}
Check(name, ok) {
    global
    Checks++, Failed += !ok
    Report .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
}
ProcessHandleIsValid(handle, args*) {
    return DllCall("GetProcessId", "Ptr", handle, "UInt") = DllCall("GetCurrentProcessId", "UInt")
}
TickNow() {
    return DllCall("GetTickCount64", "Int64")
}
checkHandles() {
    return true
}
NormalizeNumberRange(ByRef value, fallback, low, high) {
    value := value = "" ? fallback : Max(low, Min(high, value + 0))
}
NormalizeTextSendMode(ByRef value) {
    value := ChatTyping_ModeFromLabel(value)
}
ApplyActionTemplate(text) {
    return text
}
CanRunAction(args*) {
    return true
}
ServiceUI_IsInputActive() {
    return false
}
ServiceUI_Notify(args*) {
    global Notices
    Notices++
}
ChatTransport_SetStatus(text, args*) {
    global ChatTransportStatus
    ChatTransportStatus := text
}
MemoryGetShortError() {
    global g_MemoryStage
    return g_MemoryStage
}
MemoryGetStatusText() {
    return MemoryGetShortError()
}
SendChatKeyboard(args*) {
    global PasteCalls
    PasteCalls++
    return false
}
ChatTyping_ShouldType(args*) {
    return false
}
ChatTyping_ModeLabel(args*) {
}
ChatTransport_TypingDelayOverride(args*) {
}
SendChatTyped(args*) {
    return -1
}
__unicodeToAnsi(text) {
    return text
}
ApplyGameProcessSelector() {
}
GameLocator_IsActive() {
    return true
}
GameMenu_ReservationIsCurrent(args*) {
    return true
}
QueueMenu_Run(args*) {
    return false
}
Evidence_MaybeCaptureReportText(args*) {
}
MockPreview_Append(args*) {
}
UpdateHUD() {
}
LogError(args*) {
}
SafeWarn(args*) {
    return false
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--extract-a32-runtime', type=Path)
    parser.add_argument('--baseline-call-stub', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    if out.is_relative_to(ROOT):
        parser.error('Fixture must be outside repository')
    default = next(line for line in (ROOT / 'app/state.ahk').read_text('cp1251').splitlines() if line.startswith('global RP_Rights := '))
    pieces = [PROBE.replace('__RIGHTS_DEFAULT__', default)]
    for path, names in NAMES.items():
        found = {n: body for n, _, _, body in functions((ROOT / path).read_text('cp1251'))}
        for name in names:
            body = found[name]
            if name == 'SendChatMemory':
                body = body.replace('SendChatMemory(', 'FixtureNativeMemorySend(', 1)
            if name == 'callWithParams' and args.baseline_call_stub:
                # Reproduce the previous stub exactly, without fetching history.
                start = body.index('    ; The game API return value')
                end = body.index('    NumPut(0xC2, injectData', start)
                body = body[:start] + body[end:]
            pieces.append(body)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text('\n\n'.join(pieces), encoding='utf-8-sig')
    if args.extract_a32_runtime:
        lock = json.loads((ROOT / 'tools/build/toolchain.lock.json').read_text())
        archive = ROOT / '.build/toolchain' / ('AutoHotkey_' + lock['version'] + '.zip')
        raw = archive.read_bytes()
        if hashlib.sha256(raw).hexdigest() != lock['sha256']:
            raise ValueError('Official runtime archive hash mismatch')
        with zipfile.ZipFile(archive) as z:
            args.extract_a32_runtime.write_bytes(z.read('AutoHotkeyA32.exe'))
    print(out)


if __name__ == '__main__':
    main()
