; Auto ID status is local, NoActivate, click-through and capture protected.
global AutoTargetStatusText := "Наведите прицел на игрока"
global AutoTargetStatusHwnd := 0
global AutoTargetStatusControl := 0
global AutoTargetStatusRendered := ""
global AutoTargetStatusLastPaint := 0

AutoTargetID_IsAimHeld() {
    ; Physical mouse-hook state alone can miss a press while a #If is false.
    return GetKeyState("RButton", "P") || (DllCall("GetAsyncKeyState", "Int", 2, "Short") & 0x8000)
}

AutoTargetID_ValidateTargetPed(ped) {
    if (!IsLikelyPointer(ped) || Mod(ped, 4) != 0)
        return false
    ; Keep the common GTA-pool path cheap. Exact, freshly checked AZMP
    ; linkage also works if a modified client uses
    ; a different GTA pool stride. Never guess the ID from distance or angle.
    if AZMP_IsPedInGtaPool(ped, slot, 1)
        return true
    return getPlayerDataByPed(ped, exactId, exactName, 0) = 1
}

AutoTargetID_GetHUDStatus() {
    global AutoTargetIDEnabled, MockMode, AutoTargetStatusText, AutoTargetAimStartedTick
    if (AutoTargetIDEnabled != "On")
        return "Auto ID: выключен в профиле"
    if (MockMode = "On")
        return "Auto ID: тестовый режим"
    return "Auto ID: " . (AutoTargetAimStartedTick ? AutoTargetStatusText : "ПКМ — выбрать")
}

AutoTargetID_SetStatus(text) {
    global AutoTargetStatusText, AutoTargetStatusControl, AutoTargetStatusHwnd
    global AutoTargetStatusLastPaint, AutoTargetStatusRendered, AuditTestMode
    AutoTargetStatusText := text
    if (AuditTestMode || !AutoTargetStatusHwnd)
        return
    if (text = AutoTargetStatusRendered || (AutoTargetStatusLastPaint && AZMP_TickElapsed(AutoTargetStatusLastPaint) < 200))
        return
    GuiControl, AutoIDStatus:, %AutoTargetStatusControl%, %text%
    AutoTargetStatusRendered := text
    AutoTargetStatusLastPaint := TickNow()
}

AutoTargetID_ShowStatus() {
    global AutoTargetStatusHwnd, AutoTargetStatusControl, AutoTargetStatusText
    global AutoTargetStatusRendered, AutoTargetStatusLastPaint, AuditTestMode, HudX, HudY, hHUDWnd
    if (AuditTestMode || AutoTargetStatusHwnd)
        return
    GetThemeColors(bg, panel, fg, accent, muted)
    Gui, AutoIDStatus:New, +HwndAutoTargetStatusHwnd +AlwaysOnTop -Caption +ToolWindow +E0x08000020
    Gui, AutoIDStatus:Color, %panel%
    Gui, AutoIDStatus:Margin, 16, 12
    Gui, AutoIDStatus:Font, s10 Bold c%accent%, Segoe UI
    Gui, AutoIDStatus:Add, Text, x16 y10 w408 h22 BackgroundTrans, AUTO ID
    Gui, AutoIDStatus:Font, s9 Norm c%fg%, Segoe UI
    Gui, AutoIDStatus:Add, Text, x16 y36 w408 h44 +0x80 +Wrap BackgroundTrans HwndAutoTargetStatusControl, %AutoTargetStatusText%
    scale := A_ScreenDPI / 96.0
    width := Round(440 * scale), height := Round(92 * scale)
    x := Max(8, Min(HudX + 0, A_ScreenWidth - width - 8))
    y := HudY + 240
    if (hHUDWnd && DllCall("IsWindowVisible", "Ptr", hHUDWnd)) {
        WinGetPos, hx, hy, hw, hh, ahk_id %hHUDWnd%
        y := hy + hh + 8
    }
    y := Max(8, Min(y, A_ScreenHeight - height - 8))
    Gui, AutoIDStatus:-DPIScale
    Capture_BeforeShow("AutoIDStatus")
    Gui, AutoIDStatus:Show, % "x" . x . " y" . y . " w" . width . " h" . height . " NoActivate", AHK Auto ID
    Gui, AutoIDStatus:+DPIScale
    AutoTargetStatusRendered := AutoTargetStatusText
    AutoTargetStatusLastPaint := 0
}

AutoTargetID_HideStatus() {
    global AutoTargetStatusHwnd, AutoTargetStatusControl, AutoTargetStatusRendered, AutoTargetStatusLastPaint
    Gui, AutoIDStatus:Destroy
    AutoTargetStatusHwnd := 0
    AutoTargetStatusControl := 0
    AutoTargetStatusRendered := ""
    AutoTargetStatusLastPaint := 0
}
