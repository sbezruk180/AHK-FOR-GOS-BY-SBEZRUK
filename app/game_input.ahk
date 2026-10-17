; Owned, paced keyboard transactions for game menus. No speculative offsets.
global GameMenuLease := ""
global GameMenuStarting := ""

GameMenu_Acquire(epoch) {
    global GameMenuLease, PhysicalInputBusy, MockMode
    previous := A_IsCritical
    Critical, On
    try {
        if (epoch != AutomationEpoch || PhysicalInputBusy || IsObject(IDCaptureState) || ServiceUI_IsInputActive() || IsObject(GameMenuLease))
            return false
        if (MockMode != "On" && !AuditTestMode && !GameLocator_IsActive())
            return false
        lease := {Epoch: epoch, Hwnd: WinExist("A"), Profile: CurrentProfile}
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
    return (MockMode = "On" || AuditTestMode) || (lease.Hwnd = WinExist("A") && GameLocator_IsActive())
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
    if (MockMode = "On" || AuditTestMode)
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
    if (MockMode = "On" || AuditTestMode)
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

GameUi_ShouldShowPassive() {
    global FullscreenSafeGui, MockMode
    if (FullscreenSafeGui = "Off")
        return false
    if (FullscreenSafeGui = "On")
        return true
    if (MockMode = "On" || AuditTestMode)
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
