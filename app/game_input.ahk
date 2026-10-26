; Owned, paced keyboard transactions for game menus. No speculative offsets.
global GameMenuLease := ""
global GameMenuStarting := ""

GameMenu_Reserve(source, epoch := 0, target := "") {
    global GameMenuStarting, PhysicalInputBusy, MockMode
    if (!epoch)
        epoch := AutomationEpoch
    previous := A_IsCritical
    Critical, On
    try {
        if (source = "" || epoch != AutomationEpoch || PhysicalInputBusy || ChatQueueBusy
            || IsObject(IDCaptureState) || ServiceUI_IsInputActive() || IsObject(GameMenuStarting) || IsObject(GameMenuLease))
            return false
        if (MockMode != "On" && !AuditTestMode && !Training_IsActive() && !GameLocator_IsActive())
            return false
        reservation := {Epoch: epoch, Hwnd: WinExist("A"), Profile: CurrentProfile, Source: source, Target: target}
        GameMenuStarting := reservation
        return reservation
    } finally {
        Critical, %previous%
    }
}

GameMenu_ReservationIsCurrent(reservation) {
    global GameMenuStarting, MockMode
    if (!IsObject(reservation) || GameMenuStarting != reservation || reservation.Epoch != AutomationEpoch
        || reservation.Profile != CurrentProfile || (reservation.Target != "" && "ID:" . reservation.Target != "ID:" . UserID))
        return false
    return (MockMode = "On" || AuditTestMode || Training_IsActive()) || (reservation.Hwnd = WinExist("A") && GameLocator_IsActive())
}

GameMenu_Prepare(reservation) {
    global MockMode
    if !GameMenu_ReservationIsCurrent(reservation)
        return false
    lease := GameMenu_Acquire(reservation.Epoch)
    if !IsObject(lease)
        return false
    try {
        if (MockMode = "On" || AuditTestMode || Training_IsActive())
            return true
        chatState := isInChat()
        if (chatState < 0)
            return false
        ; A memory command does not dismiss the already open input box.
        ; Close it before requesting the dialog, while no dialog can be dismissed.
        if (chatState = 1 && !GameMenu_Tap(lease, "Escape"))
            return false
        return GameMenu_WaitChatClosed(lease)
    } finally {
        GameMenu_Release(lease)
    }
}

GameMenu_SendCommand(reservation, command, settleMs := 650, verifyChatClosed := true) {
    global GameMenuLease
    if !GameMenu_ReservationIsCurrent(reservation)
        return false
    if (IsObject(GameMenuLease) && GameMenuLease.Reservation == reservation)
        GameMenu_Release(GameMenuLease)
    if (SendChatForEpoch(reservation.Epoch, command, reservation.Source) != 1 || !GameMenu_ReservationIsCurrent(reservation))
        return false
    lease := GameMenu_Acquire(reservation.Epoch)
    if !IsObject(lease)
        return false
    return (!verifyChatClosed || GameMenu_WaitChatClosed(lease)) && GameMenu_Wait(lease, settleMs) ? lease : false
}

GameMenu_Close(reservation) {
    global GameMenuStarting, GameMenuLease
    if !IsObject(reservation)
        return
    if (IsObject(GameMenuLease) && GameMenuLease.Reservation == reservation)
        GameMenu_Release(GameMenuLease)
    if (GameMenuStarting == reservation)
        GameMenuStarting := ""
}

GameMenu_TypeDigits(lease, digits) {
    if (!RegExMatch(digits . "", "^[0-9]{1,20}$") || !GameMenu_IsCurrent(lease))
        return false
    ; Numeric game dialogs need actual keys, independently of clipboard support.
    if !SafeSend("^a{Backspace}", "Event", lease.Epoch, lease)
        return false
    Loop, Parse, digits
        if !GameMenu_Tap(lease, A_LoopField)
            return false
    return GameMenu_IsCurrent(lease)
}

GameMenu_Acquire(epoch) {
    global GameMenuLease, PhysicalInputBusy, MockMode
    previous := A_IsCritical
    Critical, On
    try {
        if (epoch != AutomationEpoch || PhysicalInputBusy || IsObject(IDCaptureState) || ServiceUI_IsInputActive() || IsObject(GameMenuLease))
            return false
        if (MockMode != "On" && !AuditTestMode && !Training_IsActive() && !GameLocator_IsActive())
            return false
        if (IsObject(GameMenuStarting) && !GameMenu_ReservationIsCurrent(GameMenuStarting))
            return false
        lease := {Epoch: epoch, Hwnd: WinExist("A"), Profile: CurrentProfile, Reservation: GameMenuStarting}
        GameMenuLease := lease
        PhysicalInputBusy := 1
        return lease
    } finally {
        Critical, %previous%
    }
}

GameMenu_IsCurrent(lease) {
    global GameMenuLease, MockMode
    if (!IsObject(lease) || GameMenuLease != lease || lease.Epoch != AutomationEpoch || lease.Profile != CurrentProfile)
        return false
    if (IsObject(lease.Reservation) && !GameMenu_ReservationIsCurrent(lease.Reservation))
        return false
    return (MockMode = "On" || AuditTestMode || Training_IsActive()) || (lease.Hwnd = WinExist("A") && GameLocator_IsActive())
}

GameMenu_Release(lease) {
    global GameMenuLease, PhysicalInputBusy
    previous := A_IsCritical
    Critical, On
    if (IsObject(GameMenuLease) && GameMenuLease == lease) {
        GameMenuLease := ""
        PhysicalInputBusy := 0
    }
    Critical, %previous%
}

GameMenu_Wait(lease, delayMs) {
    global MockMode
    if (MockMode = "On" || AuditTestMode || Training_IsActive())
        return GameMenu_IsCurrent(lease)
    started := TickNow()
    while (TickNow() - started < delayMs) {
        if !GameMenu_IsCurrent(lease)
            return false
        Sleep, 20
    }
    return GameMenu_IsCurrent(lease)
}

GameMenu_Tap(lease, key) {
    if !GameMenu_IsCurrent(lease)
        return false
    return SafeSend("{" . key . "}", "Event", lease.Epoch, lease) && GameMenu_IsCurrent(lease)
}

GameMenu_WaitChatClosed(lease, timeoutMs := 1800) {
    global MockMode
    if (MockMode = "On" || AuditTestMode || Training_IsActive())
        return GameMenu_IsCurrent(lease)
    started := TickNow(), stable := 0
    while (TickNow() - started < timeoutMs) {
        if !GameMenu_IsCurrent(lease)
            return false
        state := isInChat()
        if (state < 0)
            return false
        stable := state = 0 ? stable + 1 : 0
        if (stable >= 3)
            return true
        Sleep, 30
    }
    return false
}

GameMenu_Run(source, command, steps, settleMs := 650, inputEpoch := 0, target := "") {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    reservation := GameMenu_Reserve(source, inputEpoch, target)
    if !IsObject(reservation)
        return false
    try {
        if !GameMenu_Prepare(reservation)
            return false
        lease := GameMenu_SendCommand(reservation, command, settleMs)
        if !IsObject(lease)
            return false
        for _, step in steps {
            if !GameMenu_IsCurrent(lease)
                return false
            if (step.Kind = "Command") {
                lease := GameMenu_SendCommand(reservation, step.Text, step.Delay)
                if !IsObject(lease)
                    return false
            } else if (step.Kind = "Radial") {
                if !SendRadialNumberTwice(step.Value, step.Delay, step.Gap, inputEpoch, lease)
                    return false
            } else if (step.Kind = "Select") {
                if !SendListSelection(step.Value, step.Gap, step.Delay, inputEpoch, lease)
                    return false
            } else if (step.Kind = "Digits") {
                if !GameMenu_TypeDigits(lease, step.Value)
                    return false
            } else if (step.Kind = "Paste") {
                if !PasteOnly(step.Value, 1, Func("GameMenu_IsCurrent").Bind(lease), lease.Hwnd, lease)
                    return false
            } else if (step.Kind = "Layout") {
                if !SafeLayout(step.Value, lease.Hwnd, inputEpoch)
                    LogError(source, "Ќе удалось восстановить раскладку после действи€.", "WARN")
            } else if (step.Kind = "Key") {
                if !GameMenu_Tap(lease, step.Value)
                    return false
            } else
                return false
            if ((step.Kind = "Key" || step.Kind = "Digits" || step.Kind = "Paste") && !GameMenu_Wait(lease, step.Delay))
                return false
        }
        return GameMenu_IsCurrent(lease)
    } finally {
        GameMenu_Close(reservation)
    }
}

GameUi_ShouldShowPassive() {
    global FullscreenSafeGui, MockMode
    if (FullscreenSafeGui = "Off")
        return false
    if (FullscreenSafeGui = "On")
        return true
    if (MockMode = "On" || AuditTestMode || Training_IsActive())
        return false
    if !GameLocator_IsActive()
        return false
    hwnd := WinExist("A")
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    SysGet, monitors, MonitorCount
    Loop %monitors% {
        SysGet, bounds, Monitor, %A_Index%
        if (x <= boundsLeft + 8 && y <= boundsTop + 8 && x + w >= boundsRight - 8 && y + h >= boundsBottom - 8)
            return true
    }
    return false
}
