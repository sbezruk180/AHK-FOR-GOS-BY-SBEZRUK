; Local service messages and input. No game-chat, layout, or clipboard writes.
global ServiceUIInputState := ""
global ServiceUILastInputError := ""
global ServiceUINoticeHwnd := 0
global ServiceUINoticeDeadline := 0
global ServiceUINoticeTimer := ""
global ServiceUIDetailsHwnd := 0
global ServiceUIAuditInputs := []
global ServiceUIConfirmState := ""
global ServiceUIAuditConfirmations := []

ServiceUI_IsInputActive() {
    global ServiceUIInputState, ServiceUIConfirmState
    return IsObject(ServiceUIInputState) || IsObject(ServiceUIConfirmState)
}

ServiceUI_IsTest() {
    global AuditTestMode, MockMode
    return AuditTestMode || MockMode = "On"
}

ServiceUI_NormalizeSeverity(severity) {
    StringUpper, severity, severity
    return severity = "ERROR" || severity = "WARN" ? severity : "INFO"
}

ServiceUI_Position(width, height, ByRef x, ByRef y) {
    SysGet, monitorIndex, MonitorPrimary
    SysGet, area, MonitorWorkArea, %monitorIndex%
    x := Max(areaLeft + 12, areaRight - width - 24)
    y := Max(areaTop + 12, areaBottom - height - 24)
}

ServiceUI_MeasureText(text, width, pointSize := 10) {
    scale := A_ScreenDPI / 96.0
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    font := DllCall("CreateFontW", "Int", -Round(pointSize * A_ScreenDPI / 72.0), "Int", 0
        , "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1
        , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "WStr", "Segoe UI", "Ptr")
    if (!hdc || !font) {
        if (font)
            DllCall("DeleteObject", "Ptr", font)
        if (hdc)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        return 0
    }
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", font, "Ptr")
    try {
        VarSetCapacity(rect, 16, 0)
        NumPut(Round(width * scale), rect, 8, "Int")
        ok := DllCall("DrawTextW", "Ptr", hdc, "WStr", text, "Int", -1, "Ptr", &rect, "UInt", 0xC10, "Int")
        return ok ? Ceil(NumGet(rect, 12, "Int") / scale) : 0
    } finally {
        DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
        DllCall("DeleteObject", "Ptr", font)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
}

ServiceUI_Notify(text, timeoutMs := 5000, severity := "INFO") {
    global ServiceUINoticeHwnd, ServiceUINoticeDeadline, ServiceUINoticeTimer
    text := Trim(text . "")
    if (text = "")
        return false
    severity := ServiceUI_NormalizeSeverity(severity)
    if ServiceUI_IsTest() {
        MockPreview_Append("[AHK " . severity . "] " . text)
        return true
    }
    timeoutMs := Min(30000, Max(800, Round(timeoutMs)))
    bg := "", panel := "", fg := "", accent := "", muted := ""
    GetThemeColors(bg, panel, fg, accent, muted)
    if (severity = "ERROR")
        accent := "E77575"
    else if (severity = "WARN")
        accent := "E4B86A"
    width := 460
    lines := 0
    Loop, Parse, text, `n, `r
        lines += Max(1, Ceil(StrLen(A_LoopField) / 58))
    measuredHeight := ServiceUI_MeasureText(text, 424)
    contentHeight := measuredHeight ? measuredHeight + 10 : lines * 22
    height := Max(96, 50 + contentHeight)
    if (height > 390)
        return ServiceUI_ShowDetails("AHK FOR GOS Ј " . severity, text)
    displayText := text
    Gui, ServiceNotice:Destroy
    Gui, ServiceNotice:New, +HwndServiceUINoticeHwnd +AlwaysOnTop -Caption +ToolWindow +E0x08000020 +DPIScale
    Gui, ServiceNotice:Color, %panel%
    Gui, ServiceNotice:Margin, 0, 0
    Gui, ServiceNotice:Font, s9 Bold c%accent%, Segoe UI
    Gui, ServiceNotice:Add, Text, x18 y12 w424 h20 +0x80 BackgroundTrans, % "AHK FOR GOS  Ј  " . severity
    Gui, ServiceNotice:Font, s10 Norm c%fg%, Segoe UI
    contentHeight := height - 50
    Gui, ServiceNotice:Add, Text, x18 y38 w424 h%contentHeight% +0x80 +Wrap BackgroundTrans, %displayText%
    scale := A_ScreenDPI / 96.0
    pixelW := Round(width * scale), pixelH := Round(height * scale)
    ServiceUI_Position(pixelW, pixelH, showX, showY)
    if IsObject(ServiceUIInputState)
        showY := Max(12, showY - Round(248 * scale))
    Gui, ServiceNotice:-DPIScale
    Capture_BeforeShow("ServiceNotice")
    Gui, ServiceNotice:Show, % "x" . showX . " y" . showY . " w" . pixelW . " h" . pixelH . " NoActivate", AHK service notice
    Gui, ServiceNotice:+DPIScale
    ServiceUINoticeDeadline := TickNow() + timeoutMs
    if !IsObject(ServiceUINoticeTimer)
        ServiceUINoticeTimer := Func("ServiceUI_NoticeTick")
    SetTimer, % ServiceUINoticeTimer, 100
    return !!ServiceUINoticeHwnd
}

ServiceUI_NoticeTick() {
    global ServiceUINoticeDeadline
    if (TickNow() >= ServiceUINoticeDeadline)
        ServiceUI_ClearNotice()
}

ServiceUI_ClearNotice() {
    global ServiceUINoticeHwnd, ServiceUINoticeDeadline, ServiceUINoticeTimer
    if IsObject(ServiceUINoticeTimer)
        SetTimer, % ServiceUINoticeTimer, Off
    Gui, ServiceNotice:Destroy
    ServiceUINoticeHwnd := 0
    ServiceUINoticeDeadline := 0
}

ServiceUI_Message(title, text, severity := "INFO") {
    return ServiceUI_Notify(Trim(title . "") . ": " . text, 6000, severity)
}

ServiceUI_ShowDetails(title, text) {
    global ServiceUIDetailsHwnd
    if ServiceUI_IsTest() {
        MockPreview_Append("[AHK DETAILS] " . title . ": " . text)
        return true
    }
    ServiceUI_CloseDetails()
    bg := "", panel := "", fg := "", accent := "", muted := ""
    GetThemeColors(bg, panel, fg, accent, muted)
    Gui, ServiceDetails:New, +HwndServiceUIDetailsHwnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    Gui, ServiceDetails:Color, %panel%, %surface%
    Gui, ServiceDetails:Font, s12 Bold c%fg%, Segoe UI
    Gui, ServiceDetails:Add, Text, x18 y14 w644 h30 +0x80 BackgroundTrans, %title%
    Gui, ServiceDetails:Font, s10 Norm c%inputFg%, Segoe UI
    Gui, ServiceDetails:Add, Edit, x18 y54 w644 h350 ReadOnly -Wrap +VScroll, %text%
    Gui, ServiceDetails:Add, Button, x542 y416 w120 h32 HwndcloseButton, «акрыть
    closeCallback := Func("ServiceUI_CloseDetails")
    GuiControl, ServiceDetails:+g, %closeButton%, % closeCallback
    Capture_BeforeShow("ServiceDetails")
    Gui, ServiceDetails:Show, w680 h466 NoActivate, AHK service details
    return !!ServiceUIDetailsHwnd
}

ServiceDetailsGuiClose() {
    ServiceUI_CloseDetails()
}

ServiceDetailsGuiEscape() {
    ServiceUI_CloseDetails()
}

ServiceUI_CloseDetails(params*) {
    global ServiceUIDetailsHwnd
    Gui, ServiceDetails:Destroy
    ServiceUIDetailsHwnd := 0
}

ServiceUI_NewInputState(title, prompt, maxLen, timeoutSeconds, seed, confirmOnSpace, epoch, hwnd, profile, now) {
    maxLen := Min(512, Max(1, Round(maxLen)))
    timeoutSeconds := Min(180, Max(1, Round(timeoutSeconds)))
    seed := SubStr(seed . "", 1, maxLen)
    return {Title: title . "", Prompt: prompt . "", MaxLen: maxLen
        , Deadline: now + timeoutSeconds * 1000, Seed: seed, Value: seed
        , ConfirmOnSpace: !!confirmOnSpace, Epoch: epoch, OwnerHwnd: hwnd, Profile: profile
        , Hook: "", Timer: "", Pending: "", OwnsBusy: 1, GuiHwnd: 0
        , LastValue: "", LastSeconds: -1}
}

ServiceUI_ContextIsCurrent(state) {
    global AutomationEpoch, CurrentProfile
    return IsObject(state) && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile
        && state.OwnerHwnd && state.OwnerHwnd = DllCall("GetForegroundWindow", "Ptr")
        && GameLocator_IsActive()
}

ServiceUI_CreateInputGui(state) {
    global ServiceUIInputValue, ServiceUIInputCountdown
    bg := "", panel := "", fg := "", accent := "", muted := ""
    GetThemeColors(bg, panel, fg, accent, muted)
    width := 540, height := 232
    Gui, ServiceInput:New, +HwndinputHwnd +AlwaysOnTop -Caption +ToolWindow +E0x08000020 +DPIScale
    state.GuiHwnd := inputHwnd
    Gui, ServiceInput:Color, %panel%
    Gui, ServiceInput:Font, s12 Bold c%fg%, Segoe UI
    Gui, ServiceInput:Add, Text, x18 y14 w416 h26 +0x80 BackgroundTrans, % state.Title
    Gui, ServiceInput:Font, s9 Norm c%muted%, Segoe UI
    Gui, ServiceInput:Add, Text, x444 y16 w78 h22 Right BackgroundTrans vServiceUIInputCountdown,
    Gui, ServiceInput:Add, Text, x18 y50 w504 h58 +0x80 +Wrap BackgroundTrans, % state.Prompt
    Gui, ServiceInput:Font, s13 Norm c%fg%, Segoe UI
    Gui, ServiceInput:Add, Text, x18 y118 w504 h64 +0x80 +Wrap BackgroundTrans vServiceUIInputValue, % state.Value
    Gui, ServiceInput:Font, s9 Norm c%muted%, Segoe UI
    hint := (state.ConfirmOnSpace ? "ѕробел / Enter" : "Enter") . " Ч подтвердить Ј Backspace Ч стереть Ј Esc Ч отменить"
    Gui, ServiceInput:Add, Text, x18 y196 w504 h22 BackgroundTrans, %hint%
    scale := A_ScreenDPI / 96.0
    pixelW := Round(width * scale), pixelH := Round(height * scale)
    ServiceUI_Position(pixelW, pixelH, showX, showY)
    Gui, ServiceInput:-DPIScale
    Capture_BeforeShow("ServiceInput")
    Gui, ServiceInput:Show, % "x" . showX . " y" . showY . " w" . pixelW . " h" . pixelH . " NoActivate", AHK service input
    Gui, ServiceInput:+DPIScale
    return !!inputHwnd && ServiceUI_ContextIsCurrent(state)
}

ServiceUI_InputKeyDown(state, hook, vk, sc) {
    if (!ServiceUI_ContextIsCurrent(state)) {
        state.Pending := "cancel"
        hook.Stop()
        return
    }
    ; Modified shortcuts pass through. Stop before their next key is translated.
    if (vk = 0x11 || vk = 0x12 || vk = 0x5B || vk = 0x5C
        || vk = 0xA2 || vk = 0xA3 || vk = 0xA4 || vk = 0xA5) {
        state.Pending := "cancel"
        hook.Stop()
        return
    }
    if (vk = 8)
        state.Value := SubStr(state.Value, 1, Max(0, StrLen(state.Value) - 1))
}

ServiceUI_InputChar(state, hook, chars) {
    if (!ServiceUI_ContextIsCurrent(state)) {
        state.Pending := "cancel"
        hook.Stop()
        return
    }
    state.Value .= chars
    if (StrLen(state.Value) > state.MaxLen) {
        state.Pending := "limit"
        hook.Stop()
    }
}

ServiceUI_InputTick(state) {
    global ServiceUIInputState
    if (!IsObject(ServiceUIInputState) || ServiceUIInputState != state)
        return
    if (!ServiceUI_ContextIsCurrent(state) || TickNow() >= state.Deadline) {
        state.Pending := "cancel"
        if IsObject(state.Hook)
            state.Hook.Stop()
        return
    }
    if (state.LastValue != state.Value) {
        displayValue := StrLen(state.Value) > 130 ? "Е" . SubStr(state.Value, -126) : state.Value
        GuiControl, ServiceInput:, ServiceUIInputValue, % state.Value = "" ? "Е" : displayValue
        state.LastValue := state.Value
    }
    seconds := Ceil((state.Deadline - TickNow()) / 1000.0)
    if (state.LastSeconds != seconds) {
        GuiControl, ServiceInput:, ServiceUIInputCountdown, % seconds . " сек."
        state.LastSeconds := seconds
    }
}

ServiceUI_ModifierHeld() {
    for _, vk in [0x11, 0x12, 0x5B, 0x5C]
        if (DllCall("GetAsyncKeyState", "Int", vk, "Short") & 0x8000)
            return true
    return false
}

ServiceUI_Request(title, prompt, ByRef value, maxLen := 180, timeoutSeconds := 45, seed := "", confirmOnSpace := false) {
    global ServiceUIInputState, ServiceUIAuditInputs, PhysicalInputBusy, IDCaptureState, AutomationEpoch, CurrentProfile
    ServiceUILastInputError := ""
    if (ServiceUI_IsInputActive() || PhysicalInputBusy || IsObject(IDCaptureState))
        return false
    if ServiceUI_IsTest() {
        if (!IsObject(ServiceUIAuditInputs) || !ServiceUIAuditInputs.Length())
            return false
        scripted := ServiceUIAuditInputs.RemoveAt(1)
        if (!IsObject(scripted) || !scripted.Confirm || StrLen(scripted.Value . "") > Min(512, Max(1, Round(maxLen))))
            return false
        value := scripted.Value . ""
        return true
    }
    if !GameLocator_IsActive()
        return false
    previousCritical := A_IsCritical
    Critical, On
    if (ServiceUI_IsInputActive() || PhysicalInputBusy || IsObject(IDCaptureState)) {
        Critical, %previousCritical%
        return false
    }
    state := ServiceUI_NewInputState(title, prompt, maxLen, timeoutSeconds, seed, confirmOnSpace
        , AutomationEpoch, DllCall("GetForegroundWindow", "Ptr"), CurrentProfile, TickNow())
    ServiceUIInputState := state
    PhysicalInputBusy := 1
    Critical, %previousCritical%
    try {
        if !ServiceUI_CreateInputGui(state)
            return false
        ; A hotkey's already-held Alt/Ctrl must be released before capture starts.
        started := TickNow()
        while ServiceUI_ModifierHeld() {
            if (!ServiceUI_ContextIsCurrent(state) || state.Pending != "" || TickNow() - started >= 1200)
                return false
            Sleep, 10
        }
        if (!ServiceUI_ContextIsCurrent(state) || state.Pending != "")
            return false
        endKeys := "{Enter}{Escape}" . (state.ConfirmOnSpace ? "{Space}" : "")
        hook := InputHook("T" . Min(180, Max(1, Round(timeoutSeconds))), endKeys)
        state.Hook := hook
        hook.VisibleText := false
        hook.VisibleNonText := true
        ; The displayed buffer owns Backspace, including deletion of a seed.
        hook.BackspaceIsUndo := false
        hook.MinSendLevel := 1
        hook.KeyOpt("{All}", "N")
        hook.KeyOpt("{Enter}{Escape}{Backspace}" . (state.ConfirmOnSpace ? "{Space}" : ""), "S")
        hook.OnKeyDown := Func("ServiceUI_InputKeyDown").Bind(state)
        hook.OnChar := Func("ServiceUI_InputChar").Bind(state)
        state.Timer := Func("ServiceUI_InputTick").Bind(state)
        timerCallback := state.Timer
        SetTimer, % timerCallback, 30
        hook.Start()
        hook.Wait()
        result := state.Value
        endKey := hook.EndKey
        StringLower, endKey, endKey
        if (state.Pending != "" || !ServiceUI_ContextIsCurrent(state) || hook.EndReason != "EndKey"
            || !(endKey = "enter" || (state.ConfirmOnSpace && endKey = "space"))
            || StrLen(result) > state.MaxLen)
            return false
        value := result
        return true
    } catch e {
        ServiceUILastInputError := e.Message
        return false
    } finally {
        if IsObject(state.Timer) {
            timerCallback := state.Timer
            SetTimer, % timerCallback, Off
        }
        if IsObject(state.Hook) {
            state.Hook.Stop()
            state.Hook.OnKeyDown := ""
            state.Hook.OnChar := ""
        }
        Gui, ServiceInput:Destroy
        previousCritical := A_IsCritical
        Critical, On
        if (IsObject(ServiceUIInputState) && ServiceUIInputState == state)
            ServiceUIInputState := ""
        if (state.OwnsBusy) {
            state.OwnsBusy := 0
            PhysicalInputBusy := 0
        }
        Critical, %previousCritical%
    }
}

ServiceUI_CancelInput(reason := "cancel") {
    global ServiceUIInputState
    if !IsObject(ServiceUIInputState)
        return ServiceUI_CancelConfirm()
    state := ServiceUIInputState
    state.Pending := reason = "" ? "cancel" : reason
    if IsObject(state.Timer) {
        timerCallback := state.Timer
        SetTimer, % timerCallback, Off
    }
    if IsObject(state.Hook)
        state.Hook.Stop()
    Gui, ServiceInput:Destroy
    return true
}

ServiceUI_Shutdown() {
    ServiceUI_CancelInput("shutdown")
    ServiceUI_CancelConfirm()
    ServiceUI_ClearNotice()
    ServiceUI_CloseDetails()
}

ServiceUI_Confirm(title, text) {
    global ServiceUIConfirmState, ServiceUIAuditConfirmations, PhysicalInputBusy, IDCaptureState
    global AutomationEpoch, CurrentProfile
    if (ServiceUI_IsInputActive() || PhysicalInputBusy || IsObject(IDCaptureState))
        return false
    if ServiceUI_IsTest() {
        if (!IsObject(ServiceUIAuditConfirmations) || !ServiceUIAuditConfirmations.Length())
            return false
        return ServiceUIAuditConfirmations.RemoveAt(1) = 1
    }
    parentHwnd := DllCall("GetForegroundWindow", "Ptr")
    if (parentHwnd) {
        DllCall("GetWindowThreadProcessId", "Ptr", parentHwnd, "UInt*", parentPID)
        WinGetClass, parentClass, ahk_id %parentHwnd%
        if (parentPID != DllCall("GetCurrentProcessId", "UInt") || parentClass != "AutoHotkeyGUI")
            parentHwnd := 0
    }
    previousCritical := A_IsCritical
    Critical, On
    if (ServiceUI_IsInputActive() || PhysicalInputBusy || IsObject(IDCaptureState)) {
        Critical, %previousCritical%
        return false
    }
    state := {Epoch: AutomationEpoch, Profile: CurrentProfile, ParentHwnd: parentHwnd
        , ParentWasEnabled: parentHwnd ? DllCall("IsWindowEnabled", "Ptr", parentHwnd, "Int") : 0
        , GuiHwnd: 0, Pending: "", Confirmed: 0, OwnsBusy: 1, Deadline: TickNow() + 60000}
    ServiceUIConfirmState := state
    PhysicalInputBusy := 1
    Critical, %previousCritical%
    try {
        bg := "", panel := "", fg := "", accent := "", muted := ""
        GetThemeColors(bg, panel, fg, accent, muted)
        Gui, ServiceConfirm:New, +HwndconfirmHwnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
        state.GuiHwnd := confirmHwnd
        if (parentHwnd)
            Gui, ServiceConfirm:+Owner%parentHwnd%
        Gui, ServiceConfirm:Color, %panel%
        Gui, ServiceConfirm:Font, s12 Bold c%fg%, Segoe UI
        Gui, ServiceConfirm:Add, Text, x18 y14 w484 h28 +0x80 BackgroundTrans, %title%
        Gui, ServiceConfirm:Font, s10 Norm c%fg%, Segoe UI
        Gui, ServiceConfirm:Add, Text, x18 y56 w484 h92 +0x80 +Wrap BackgroundTrans, %text%
        Gui, ServiceConfirm:Add, Button, x234 y168 w128 h34 HwndyesButton, ƒа
        Gui, ServiceConfirm:Add, Button, x374 y168 w128 h34 Default HwndnoButton, Ќет
        yesCallback := Func("ServiceUI_ResolveConfirm").Bind(state, true)
        noCallback := Func("ServiceUI_ResolveConfirm").Bind(state, false)
        GuiControl, ServiceConfirm:+g, %yesButton%, % yesCallback
        GuiControl, ServiceConfirm:+g, %noButton%, % noCallback
        if (state.ParentWasEnabled)
            DllCall("EnableWindow", "Ptr", parentHwnd, "Int", false, "Int")
        Capture_BeforeShow("ServiceConfirm")
        Gui, ServiceConfirm:Show, w520 h222, AHK confirmation
        while (state.Pending = "") {
            if (state.Epoch != AutomationEpoch || state.Profile != CurrentProfile || TickNow() >= state.Deadline
                || !DllCall("IsWindow", "Ptr", confirmHwnd, "Int")
                || DllCall("GetForegroundWindow", "Ptr") != confirmHwnd) {
                state.Pending := "cancel"
                break
            }
            Sleep, 30
        }
        return state.Pending = "confirm" && state.Confirmed && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile
    } finally {
        if (state.ParentWasEnabled && DllCall("IsWindow", "Ptr", state.ParentHwnd, "Int"))
            DllCall("EnableWindow", "Ptr", state.ParentHwnd, "Int", true, "Int")
        Gui, ServiceConfirm:Destroy
        previousCritical := A_IsCritical
        Critical, On
        if (IsObject(ServiceUIConfirmState) && ServiceUIConfirmState == state)
            ServiceUIConfirmState := ""
        if (state.OwnsBusy) {
            state.OwnsBusy := 0
            PhysicalInputBusy := 0
        }
        Critical, %previousCritical%
    }
}

ServiceUI_ResolveConfirm(state, confirmed, params*) {
    global ServiceUIConfirmState, AutomationEpoch, CurrentProfile
    if (!IsObject(ServiceUIConfirmState) || ServiceUIConfirmState != state || state.Pending != ""
        || state.Epoch != AutomationEpoch || state.Profile != CurrentProfile || TickNow() >= state.Deadline
        || DllCall("GetForegroundWindow", "Ptr") != state.GuiHwnd)
        return
    state.Confirmed := !!confirmed
    state.Pending := "confirm"
}

ServiceUI_CancelConfirm() {
    global ServiceUIConfirmState
    if !IsObject(ServiceUIConfirmState)
        return false
    ServiceUIConfirmState.Pending := "cancel"
    return true
}

ServiceConfirmGuiClose() {
    ServiceUI_CancelConfirm()
}

ServiceConfirmGuiEscape() {
    ServiceUI_CancelConfirm()
}
