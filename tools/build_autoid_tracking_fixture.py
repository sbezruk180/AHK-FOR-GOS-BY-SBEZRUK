#!/usr/bin/env python3
"""Build a native AHK v1 fixture from the current production functions.

Usage: python tools/build_autoid_tracking_fixture.py OUTPUT.ahk
Run OUTPUT.ahk with AHK v1 at 100% DPI. It opens a disposable input window.
The game resolver, input state, capture API and execution side effects are
explicit seams; polling, prompt replacement and confirmation UI are real.
Synthetic F1/F2 exercise the production dispatch labels. No game is accessed.
"""
from pathlib import Path
import sys
r = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit(__doc__)
output = Path(sys.argv[1])
s=(r/'AHK_FOR_GOS_BY_SBEZRUK.ahk').read_bytes().decode('cp1251').replace('\r\n','\n')
def fn(name):
 i=s.index('\n'+name+'(')+1; return s[i:s.index('\n}',i)+2]
names=['AutoTargetID_Poll','AutoTargetID_ResetCandidate','AutoTargetID_ClearFailure','AutoTargetID_RequestConfirmation','AutoTargetID_TargetKey','ContextAssistant_Close','ContextAssistant_ShowConfirmationOverlay','ContextAssistant_GetOverlayPosition','ContextAssistant_MakeWindowPassive','ContextAssistant_GetConfirmationPrompt','ContextAssistant_Submit','ContextAssistant_ConfirmHotkeysActive']
funcs='\n'.join(fn(n) for n in names).replace('GetKeyState("RButton", "P")','FixtureAimHeld()')
source=r'''#NoEnv
#SingleInstance Force
SetBatchLines, -1
FileEncoding, UTF-8-RAW
global AutoTargetIDEnabled := "On", MockMode := "Off", AutoTargetOfferedKey := "", AutoTargetPendingKey := ""
global AutoTargetCandidateID := -1, AutoTargetCandidateReads := 0, AutoTargetCandidatePed := 0, AutoTargetCandidateMatchType := 0
global AutoTargetLastScanTick := 0, UserID := 75, ActiveID := 1, TargetIsMask := 0
global ContextAssistantMode := "", ContextAssistantAction := "", ContextAssistantInput := "", ContextAssistantVariant := "", ContextAssistantTargetName := "", ContextAssistantStatus := ""
global hContextAssistantWnd := 0, AutoTargetConfirmationPrompt := "", UIRoundness := 10
global ContextNotificationMode := "Плашка", ContextNotificationTimeoutSec := 8
global IDCaptureState := "", PhysicalInputBusy := 0, AutomationEpoch := 1
global Held := 1, Focus := 1, Chat := 0, Reads := 0, Requests := 0, AppliedName := ""
global TargetID := 42, TargetPed := 0x200000, Mask := 0, Match := 1, MutateVerify := 0, ChangeEpoch := 0, LoseFocus := 0
global Passed := 0, Failed := 0, LogPath := A_ScriptDir . "\autoid_tracking_report.txt", CaptureCalls := 0
FileDelete, %LogPath%
Gui, 1:+HwndFixtureWindow
Gui, 1:Show, w640 h480, Auto ID game input fixture
WinActivate, ahk_id %FixtureWindow%
Sleep, 100
Reset()
PollNow()
Check("exact target opens on first poll with two reads",Requests=1 && Reads=2 && ContextAssistantInput=42 && UserID=75)
firstWindow:=hContextAssistantWnd
WinGetPos, gx,gy,gw,gh, ahk_id %firstWindow%
Check("original 310x54 overlay geometry",gw=310 && gh=54)
Check("overlay keeps foreground game window",WinActive("ahk_id " . FixtureWindow))
WinGet, exStyle, ExStyle, ahk_id %firstWindow%
Check("overlay remains passive and click-through",(exStyle & 0x08000020)=0x08000020)
before:=Reads
PollNow()
Check("same target performs one read without rebuilding",Reads=before+1 && Requests=1 && hContextAssistantWnd=firstWindow)
TargetID:=43,TargetPed:=0x300000
PollNow()
GuiControlGet, prompt, 42:, AutoTargetConfirmationPrompt
Check("another player replaces pending proposal in first poll",ContextAssistantInput=43 && InStr(prompt,"ID 43"))
Check("replacement retains HWND and capture registration",hContextAssistantWnd=firstWindow && CaptureCalls=1 && Requests=1)
Check("replacement still leaves selection unchanged",UserID=75)
Hotkey, F1, DoConfirmID
Hotkey, F2, DoRejectID
SendInput, {F1}
Sleep, 80
Check("F1 accepts latest visible player",UserID=43 && AppliedName="Fixture_Player" && ContextAssistantMode="")
PollNow()
Check("accepted target is not offered again",Requests=1 && ContextAssistantMode="")
TargetID:=44,TargetPed:=0x400000
PollNow()
SendInput, {F2}
Sleep, 80
Check("F2 declines and preserves accepted ID",ContextAssistantMode="" && UserID=43 && AutoTargetPendingKey="")
PollNow()
Check("declined target remains suppressed while held",Requests=2 && ContextAssistantMode="")
TargetID:=45,TargetPed:=0x500000
PollNow()
Check("new target is proposed after decline without releasing RMB",ContextAssistantInput=45 && Requests=3)
TargetID:=44,TargetPed:=0x400000
PollNow()
Check("return to previously declined target replaces new proposal",ContextAssistantInput=44)
TargetID:=43,TargetPed:=0x300000
PollNow()
Check("aiming at selected target clears obsolete proposal",ContextAssistantMode="" && UserID=43)
Reset()
Mask:=1,Match:=4,TargetID:="12345678901234567890"
PollNow()
Check("fallback mask requires another timer observation",Requests=0 && AutoTargetCandidateReads=1)
PollNow()
Check("long mask survives scan and confirmation unchanged","M" . ContextAssistantInput="M__MASK__:12345678901234567890")
ContextAssistant_Submit()
Check("long mask accepted without numeric overflow","M" . UserID="M12345678901234567890" && TargetIsMask)
Reset()
MutateVerify:=1
PollNow()
Check("changed target during final read never opens proposal",Requests=0 && AutoTargetCandidateReads=0)
Reset()
ContextAssistantMode:="confirm",ContextAssistantAction:="Chase",ContextAssistantInput:=88
PollNow()
Check("unrelated action confirmation is never replaced",Reads=0 && ContextAssistantInput=88)
Reset()
ContextAssistantMode:="input"
PollNow()
Check("manual assistant input is never replaced",Reads=0)
Reset()
IDCaptureState:={}
PollNow()
Check("digit capture suppresses memory reads",Reads=0)
Reset()
PhysicalInputBusy:=1
PollNow()
Check("active typing suppresses memory reads",Reads=0)
Reset()
Chat:=1
PollNow()
Check("open chat suppresses memory reads",Reads=0)
Reset()
Chat:=-1
AutoTargetCandidateReads:=1
PollNow()
Check("unknown chat suppresses reads and resets candidate",Reads=0 && AutoTargetCandidateReads=0)
Reset()
Focus:=0
PollNow()
Check("inactive game suppresses memory reads",Reads=0)
Reset()
MockMode:="On"
PollNow()
Check("mock mode suppresses memory reads",Reads=0)
Reset()
AutoTargetIDEnabled:="Off"
PollNow()
Check("disabled auto ID suppresses memory reads",Reads=0)
Reset()
Held:=0
PollNow()
Check("RMB release skips reads and clears offer lock",Reads=0 && AutoTargetOfferedKey="" && AutoTargetLastScanTick=0)
Reset()
AutoTargetLastScanTick:=A_TickCount
AutoTargetID_Poll()
Check("30ms throttle limits repeated scans",Reads=0)
Reset()
ChangeEpoch:=1
PollNow()
Check("cancellation during scan suppresses stale proposal",Requests=0)
Reset()
LoseFocus:=1
PollNow()
Check("focus loss during scan suppresses stale proposal",Requests=0)
Reset()
TargetID:=-1
PollNow()
Check("absent player never changes selected ID",Requests=0 && UserID=75)
Reset()
Mask:=1,Match:=4
PollNow()
TargetPed:=0x300000
PollNow()
Check("new PED cannot inherit previous fallback stability",Requests=0 && AutoTargetCandidateReads=1)
Reset()
Held:=0
SetTimer, PollTimer, 30
Sleep, 120
Check("idle timer performs zero memory reads",Reads=0)
Held:=1
Sleep, 95
Check("actual 30ms timer opens proposal quickly",ContextAssistantInput=42 && Requests=1)
TargetID:=49,TargetPed:=0x900000
Sleep, 95
Check("actual timer replaces unanswered proposal",ContextAssistantInput=49 && Requests=1)
SetTimer, PollTimer, Off
ContextAssistant_Close()
FileAppend, % "SUMMARY PASS=" . Passed . " FAIL=" . Failed . "`n", %LogPath%
ExitApp, %Failed%
PollTimer:
AutoTargetID_Poll()
return
ContextAssistantTimeoutLabel:
ContextAssistant_Close()
return
Reset() {
 global
 ContextAssistant_Close()
 Held:=1,Focus:=1,Chat:=0,Reads:=0,Requests:=0,AppliedName:="",CaptureCalls:=0
 TargetID:=42,TargetPed:=0x200000,Mask:=0,Match:=1,MutateVerify:=0,ChangeEpoch:=0,LoseFocus:=0
 AutoTargetIDEnabled:="On",MockMode:="Off",AutoTargetOfferedKey:="",AutoTargetPendingKey:="",AutoTargetLastScanTick:=0,UserID:=75,ActiveID:=1,TargetIsMask:=0
 IDCaptureState:="",PhysicalInputBusy:=0,AutomationEpoch:=1
 AutoTargetID_ResetCandidate()
}
PollNow() {
 global AutoTargetLastScanTick
 AutoTargetLastScanTick:=0
 AutoTargetID_Poll()
}
Check(label,ok) {
 global Passed,Failed,LogPath
 if ok
  Passed++
 else
  Failed++
 FileAppend, % (ok ? "PASS":"FAIL") . " | " . label . "`n", %LogPath%
}
FixtureAimHeld() {
 return Held
}
GameLocator_IsActive() {
 return Focus
}
isInChat() {
 return Chat
}
AZMP_TickElapsed(start) {
 return A_TickCount-start
}
AutoTargetID_ReadAimedID(ByRef ped, ByRef angle, ByRef name, ByRef isMask, ByRef kind) {
 global Reads,AutomationEpoch,Focus
 Reads++
 ped:=TargetPed,angle:=-1,name:="Fixture_Player",isMask:=Mask,kind:=Match
 if (ChangeEpoch)
  AutomationEpoch++
 if (LoseFocus)
  Focus:=0
 return MutateVerify && Mod(Reads,2)=0 ? 43 : TargetID
}
AutoTargetID_RecordFailure(code,detail,ped) {
}
ContextAssistant_Request(action,value,variant,name) {
 global Requests,ContextAssistantAction,ContextAssistantInput,ContextAssistantVariant,ContextAssistantTargetName,ContextAssistantMode,ContextAssistantStatus
 ContextAssistant_Close()
 Requests++
 ContextAssistantAction:=action,ContextAssistantInput:=value,ContextAssistantVariant:=variant,ContextAssistantTargetName:=name,ContextAssistantMode:="confirm",ContextAssistantStatus:="F1 - Да    F2 - Нет"
 return ContextAssistant_ShowConfirmationOverlay("",ContextAssistant_GetConfirmationPrompt(action,value,variant,name),ContextAssistantStatus)
}
ContextAssistant_Execute(action,value,variant,name) {
 global UserID,AppliedName,TargetIsMask
 if RegExMatch(value,"^__MASK__:([0-9]{5,20})$",m)
  UserID:=m1,TargetIsMask:=1
 else
  UserID:=value,TargetIsMask:=0
 AppliedName:=name
 return action="EnterID"
}
ContextAssistant_ValidateNumber(value,max,ByRef normalized,min) {
 return false
}
ContextAssistant_ShowStatus(text) {
}
Notify(text) {
}
GetThemeColors(ByRef bg,ByRef panel,ByRef textColor,ByRef accent,ByRef muted) {
 bg:="10141C",panel:="18202C",textColor:="F3F5F8",accent:="68B0FF",muted:="B6C2D0"
}
Capture_BeforeShow(guiNumber) {
 global CaptureCalls
 CaptureCalls++
}
ApplyRoundedCorners(hwnd,radius) {
}
GameNotify(text,level) {
}
LogError(source,text,level) {
}
'''
labels = s[s.index('\nDoConfirmID:') + 1:s.index('\nDoResetID:')]
output.write_bytes((source+'\n'+funcs+'\n'+labels).replace('\n','\r\n').encode('cp1251'))
