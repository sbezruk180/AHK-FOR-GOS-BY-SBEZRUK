; Temporary manual ID entry. Only plain digits and editing controls are consumed.
; The low-level hook makes its suppression decision synchronously; GUI work is
; kept on the timer. Modified shortcuts and injected keys remain untouched.

global IDCaptureState := ""
global IDCaptureCallbackAddress := 0
global IDCaptureTimerCallback := ""
global IDCapturePendingHooks := []

IDCapture_Start() {
    global IDCaptureState, IDCaptureCallbackAddress, IDCaptureTimerCallback
    global IDCaptureTimeoutSec, Bind_EnterID, AutomationEpoch, CurrentProfile, PhysicalInputBusy
    if IsObject(IDCaptureState)
        return IDCapture_Complete("confirm")
    if (!IDCapture_RetryUnhooks() || PhysicalInputBusy || !GameLocator_IsActive())
        return false
    chatState := isInChat()
    if (chatState != 0)
        return SafeWarn(chatState = 1 ? "«акрой чат перед перехватом ID." : "Ќе удалось проверить состо€ние чата дл€ перехвата ID.")
    ownerHwnd := DllCall("GetForegroundWindow", "Ptr")
    if (!ownerHwnd)
        return false
    previous := A_IsCritical
    Critical, On
    try {
        state := IDCapture_NewState(AutomationEpoch, ownerHwnd, IDCaptureTimeoutSec, TickNow(), CurrentProfile)
        state.ModifierMask := IDCapture_GetModifierMask()
        state.ActivationVK := IDCapture_ActivationVK(Bind_EnterID)
        state.ActivationHeld := state.ActivationVK && (DllCall("GetAsyncKeyState", "Int", state.ActivationVK, "Short") & 0x8000) ? 1 : 0
        state.InitialKeys := IDCapture_GetInitialKeys(state.ActivationHeld ? state.ActivationVK : 0)
        if (!IDCaptureCallbackAddress)
            IDCaptureCallbackAddress := RegisterCallback("IDCapture_KeyboardProc", "Fast", 3)
        if (!IDCaptureCallbackAddress)
            return false
        IDCaptureState := state
        if !IDCapture_CreateGui(state) {
            IDCapture_Complete("cancel")
            return false
        }
        state.Hook := DllCall("SetWindowsHookExA", "Int", 13, "Ptr", IDCaptureCallbackAddress
            , "Ptr", DllCall("GetModuleHandleA", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
        if (!state.Hook || !IDCapture_ContextIsCurrent(state)) {
            IDCapture_Complete("cancel")
            return false
        }
        if !IsObject(IDCaptureTimerCallback)
            IDCaptureTimerCallback := Func("IDCapture_Tick")
        SetTimer, % IDCaptureTimerCallback, 40
        return true
    } finally {
        Critical, %previous%
    }
}

IDCapture_NewState(epoch, hwnd, timeoutSec, now, profile := "") {
    timeoutSec := IDCapture_NormalizeTimeout(timeoutSec)
    return {Epoch: epoch, OwnerHwnd: hwnd, Profile: profile, Deadline: now + timeoutSec * 1000
        , Value: "", Pending: "", Dirty: 1, Hook: 0, GuiHwnd: 0, OwnedKeys: {}, InitialKeys: {}, ModifierMask: 0, ActivationVK: 0, ActivationHeld: 0
        , LastChatCheck: now, LastCountdown: "", LimitHit: 0, ValueFontSize: 20}
}

IDCapture_NormalizeTimeout(value) {
    if !RegExMatch(value . "", "^[0-9]+$")
        return 3
    return Min(15, Max(1, value + 0))
}

IDCapture_IsValid(value) {
    ; Keep legacy manual-ID semantics: preserve masks/large strings and zeros.
    return RegExMatch(value . "", "^[0-9]{1,20}$") ? true : false
}

IDCapture_Reduce(state, event, value := "") {
    if (!IsObject(state) || state.Pending != "")
        return false
    if (event = "digit" && RegExMatch(value . "", "^[0-9]$")) {
        if (StrLen(state.Value) < 20) {
            state.Value .= value
            state.LimitHit := 0
        } else {
            state.LimitHit := 1
        }
    } else if (event = "erase") {
        state.Value := SubStr(state.Value, 1, Max(0, StrLen(state.Value) - 1))
        state.LimitHit := 0
    } else if (event = "confirm" || event = "cancel") {
        state.Pending := event
    } else {
        return false
    }
    state.Dirty := 1
    return true
}

IDCapture_ContextIsCurrent(state) {
    global AutomationEpoch, CurrentProfile
    return IsObject(state) && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile
        && state.OwnerHwnd = DllCall("GetForegroundWindow", "Ptr")
}

IDCapture_GetModifierMask() {
    mask := 0
    for _, vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
        if (DllCall("GetAsyncKeyState", "Int", vk, "Short") & 0x8000)
            mask |= IDCapture_ModifierBit(vk, 0, 0)
    return mask
}

IDCapture_GetInitialKeys(activationVK := 0) {
    keys := {}
    for _, vk in [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39
        , 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 8, 0xD, 0x1B]
        if (DllCall("GetAsyncKeyState", "Int", vk, "Short") & 0x8000)
            keys[vk] := 1
    if (activationVK)
        keys[activationVK] := 1
    return keys
}

IDCapture_ActivationVK(binding) {
    binding := RegExReplace(Trim(binding), "i)\s+Up$")
    parts := StrSplit(binding, "&")
    binding := RegExReplace(Trim(parts[parts.Length()]), "^[~*$<>^!+#]+")
    vk := binding != "" ? GetKeyVK(binding) : 0
    ; Mouse events do not reach WH_KEYBOARD_LL and cannot release its guard.
    return (vk = 1 || vk = 2 || vk = 4 || vk = 5 || vk = 6) ? 0 : vk
}

IDCapture_IsActivationKey(state, vk) {
    activationVK := state.ActivationVK
    return activationVK && (vk = activationVK
        || (activationVK = 0x10 && (vk = 0xA0 || vk = 0xA1))
        || (activationVK = 0x11 && (vk = 0xA2 || vk = 0xA3))
        || (activationVK = 0x12 && (vk = 0xA4 || vk = 0xA5)))
}

IDCapture_ConfirmationBlocked(state, reason) {
    return reason = "confirm" && state.Pending = "" && state.ActivationHeld
}

IDCapture_ModifierBit(vk, sc, flags) {
    if (vk = 0xA0 || (vk = 0x10 && sc != 0x36))
        return 1
    if (vk = 0xA1 || (vk = 0x10 && sc = 0x36))
        return 2
    if (vk = 0xA2 || (vk = 0x11 && !(flags & 1)))
        return 4
    if (vk = 0xA3 || (vk = 0x11 && (flags & 1)))
        return 8
    if (vk = 0xA4 || (vk = 0x12 && !(flags & 1)))
        return 16
    if (vk = 0xA5 || (vk = 0x12 && (flags & 1)))
        return 32
    if (vk = 0x5B)
        return 64
    return vk = 0x5C ? 128 : 0
}

IDCapture_DigitForKey(vk, modifiers := 0) {
    if (modifiers)
        return ""
    if (vk >= 0x30 && vk <= 0x39)
        return Chr(vk)
    return (vk >= 0x60 && vk <= 0x69) ? Chr(vk - 0x30) : ""
}

IDCapture_KeyboardProc(nCode, wParam, lParam) {
    global IDCaptureState
    ; Fast callbacks borrow the caller's thread; do not change its error state.
    savedError := ErrorLevel
    savedNativeError := A_LastError
    try {
        if (nCode < 0 || !IsObject(IDCaptureState))
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
        flags := NumGet(lParam + 0, 8, "UInt")
        if (flags & 0x12)
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
        state := IDCaptureState
        if !IDCapture_ContextIsCurrent(state) {
            state.Pending := "cancel"
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
        }
        vk := NumGet(lParam + 0, 0, "UInt")
        isUp := wParam = 0x101 || wParam = 0x105
        isDown := wParam = 0x100 || wParam = 0x104
        if IDCapture_HandleKey(state, vk, NumGet(lParam + 0, 4, "UInt"), flags, isDown, isUp, TickNow())
            return 1
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
    } finally {
        DllCall("SetLastError", "UInt", savedNativeError)
        ErrorLevel := savedError
    }
}

IDCapture_HandleKey(state, vk, sc, flags, isDown, isUp, now) {
    if (!IsObject(state) || (flags & 0x12))
        return 0
    if (isUp && IDCapture_IsActivationKey(state, vk)) {
        state.ActivationHeld := 0
        state.InitialKeys.Delete(state.ActivationVK)
    }
    modifierBit := IDCapture_ModifierBit(vk, sc, flags)
    if (modifierBit) {
        if (isUp)
            state.InitialKeys.Delete(vk)
        state.ModifierMask := isUp ? (state.ModifierMask & ~modifierBit) : (state.ModifierMask | modifierBit)
    } else if (state.InitialKeys.HasKey(vk)) {
        ; An activation digit already held at Start must not enter the ID,
        ; including auto-repeat. Its release belongs to the original shortcut.
        if (isUp)
            state.InitialKeys.Delete(vk)
    } else if (isUp && state.OwnedKeys.HasKey(vk)) {
        state.OwnedKeys.Delete(vk)
        return 1
    } else if (isDown && state.Pending = "") {
        if (now >= state.Deadline) {
            state.Pending := "confirm"
        } else if (!state.ModifierMask) {
            digit := IDCapture_DigitForKey(vk)
            event := digit != "" ? "digit" : (vk = 8 ? "erase" : (vk = 0xD ? "confirm" : (vk = 0x1B ? "cancel" : "")))
            if (event != "") {
                IDCapture_Reduce(state, event, digit)
                state.OwnedKeys[vk] := 1
                return 1
            }
            ; Allow opening chat normally, and stop capturing before its digits.
            if (vk = 0x54 || vk = 0x75)
                state.Pending := "cancel"
        }
    }
    return 0
}

IDCapture_CreateGui(state) {
    global IDCaptureValueText, IDCaptureCountdownText, IDCaptureHelpText
    Gui, IDCapture:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 +HwndcaptureHwnd +DPIScale
    state.GuiHwnd := captureHwnd
    Gui, IDCapture:Color, 1B2430
    Gui, IDCapture:Margin, 0, 0
    Gui, IDCapture:Font, s10 Norm cA8B5C7, Segoe UI
    Gui, IDCapture:Add, Text, x16 y12 w216 h20 BackgroundTrans, ¬¬ќƒ ID ÷≈Ћ»
    Gui, IDCapture:Add, Text, x252 y12 w76 h20 Right BackgroundTrans vIDCaptureCountdownText,
    Gui, IDCapture:Font, s20 Norm cEBF0F7, Consolas
    Gui, IDCapture:Add, Text, x16 y38 w312 h34 +0x200 BackgroundTrans vIDCaptureValueText, Ч
    Gui, IDCapture:Font, s9 Norm cA8B5C7, Segoe UI
    Gui, IDCapture:Add, Text, x16 y82 w312 h34 +Wrap BackgroundTrans vIDCaptureHelpText, ѕовтор бинда / Enter Ч сохранить`nBackspace Ч стереть Ј Esc Ч отменить
    scale := A_ScreenDPI / 96
    ownerHwnd := state.OwnerHwnd
    WinGetPos, gameX, gameY, gameW, gameH, ahk_id %ownerHwnd%
    if (gameW > 0 && gameH > 0) {
        showX := gameX + Max(8, Round((gameW - 344 * scale) / 2))
        showY := gameY + Max(8, Round(gameH - 128 * scale - 80 * scale))
    } else {
        showX := Max(8, Round((A_ScreenWidth - 344 * scale) / 2))
        showY := Max(8, Round(A_ScreenHeight - 208 * scale))
    }
    Gui, IDCapture:-DPIScale
    Capture_BeforeShow("IDCapture")
    Gui, IDCapture:Show, % "x" . showX . " y" . showY . " w" . Round(344 * scale) . " h" . Round(128 * scale) . " NoActivate", ¬вод ID
    Gui, IDCapture:+DPIScale
    return DllCall("IsWindow", "Ptr", captureHwnd, "Int") && IDCapture_ContextIsCurrent(state)
}

IDCapture_Tick() {
    global IDCaptureState
    if !IsObject(IDCaptureState)
        return
    state := IDCaptureState
    if (!IDCapture_ContextIsCurrent(state) || !GameLocator_IsActive()) {
        IDCapture_Complete("cancel")
        return
    }
    now := TickNow()
    if (now - state.LastChatCheck >= 120) {
        state.LastChatCheck := now
        if (isInChat() != 0) {
            IDCapture_Complete("cancel")
            return
        }
    }
    if (state.Pending != "" || now >= state.Deadline) {
        IDCapture_Complete(state.Pending = "cancel" ? "cancel" : (now >= state.Deadline ? "timeout" : "confirm"))
        return
    }
    if (state.Dirty) {
        valueFontSize := StrLen(state.Value) > 16 ? 16 : 20
        if (state.ValueFontSize != valueFontSize) {
            Gui, IDCapture:Font, s%valueFontSize% Norm cEBF0F7, Consolas
            GuiControl, IDCapture:Font, IDCaptureValueText
            state.ValueFontSize := valueFontSize
        }
        GuiControl, IDCapture:, IDCaptureValueText, % state.Value = "" ? "Ч" : state.Value
        hint := state.LimitHit ? "ћаксимум 20 цифр Ј Backspace Ч стереть`nѕовтор бинда / Enter Ч сохранить Ј Esc Ч отменить" : "ѕовтор бинда / Enter Ч сохранить`nBackspace Ч стереть Ј Esc Ч отменить"
        GuiControl, IDCapture:, IDCaptureHelpText, %hint%
        state.Dirty := 0
    }
    countdown := Format("{:.1f} с", Max(0, state.Deadline - now) / 1000)
    if (countdown != state.LastCountdown) {
        GuiControl, IDCapture:, IDCaptureCountdownText, %countdown%
        state.LastCountdown := countdown
    }
}

IDCapture_Complete(reason := "confirm") {
    global IDCaptureState, IDCaptureTimerCallback, IDCapturePendingHooks
    previous := A_IsCritical
    Critical, On
    try {
        if !IsObject(IDCaptureState)
            return false
        state := IDCaptureState
        ; Holding the original binding key is not a second intentional press.
        if IDCapture_ConfirmationBlocked(state, reason)
            return false
        commit := (reason = "confirm" || reason = "timeout") && state.Pending != "cancel" && IDCapture_IsValid(state.Value) && IDCapture_ContextIsCurrent(state)
        ; Clear ownership before removing the hook; late notifications are inert.
        IDCaptureState := ""
        if IsObject(IDCaptureTimerCallback)
            SetTimer, % IDCaptureTimerCallback, Off
        if (state.Hook) {
            if !IDCapture_RemoveHook(state.Hook) {
                if !IsObject(IDCapturePendingHooks)
                    IDCapturePendingHooks := []
                IDCapturePendingHooks.Push(state.Hook)
            }
            state.Hook := 0
        }
        Gui, IDCapture:Destroy
        if (commit) {
            ShowIDGui(state.Value)
            Notify("info")
        }
        return commit ? true : false
    } finally {
        Critical, %previous%
    }
}

IDCapture_RemoveHook(handle) {
    DllCall("SetLastError", "UInt", 0)
    return DllCall("UnhookWindowsHookEx", "Ptr", handle, "Int") || A_LastError = 1404
}

IDCapture_RetryUnhooks() {
    global IDCapturePendingHooks
    if !IsObject(IDCapturePendingHooks)
        return true
    pending := []
    for _, handle in IDCapturePendingHooks
        if !IDCapture_RemoveHook(handle)
            pending.Push(handle)
    IDCapturePendingHooks := pending
    return pending.Length() = 0
}

IDCapture_Shutdown() {
    global IDCaptureCallbackAddress, IDCaptureTimerCallback
    IDCapture_Complete("cancel")
    if (IDCaptureCallbackAddress && IDCapture_RetryUnhooks()) {
        DllCall("GlobalFree", "Ptr", IDCaptureCallbackAddress, "Ptr")
        IDCaptureCallbackAddress := 0
    }
    IDCaptureTimerCallback := ""
}
