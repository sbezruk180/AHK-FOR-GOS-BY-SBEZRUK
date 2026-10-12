; Direct aimed-ID selection; no game, input, or GUI is created by these tests.
Audit_AutoIDDirect() {
    global UserID, ActiveID, TargetNickname, TargetIsMask, AutomationEpoch
    global IDCaptureState, PhysicalInputBusy, ContextAssistantMode, hContextAssistantWnd
    global hHUDWnd, hIDOverlayWnd, IDOverlayVisible, AZMP_MAX_PLAYERS
    global AutoTargetStatusText, AutoTargetDiagCode, AutoTargetDiagDetail
    saved := {ID: UserID, Active: ActiveID, Name: TargetNickname, Mask: TargetIsMask
        , Capture: IDCaptureState, Busy: PhysicalInputBusy, Mode: ContextAssistantMode
        , ContextWnd: hContextAssistantWnd, HUD: hHUDWnd, Overlay: hIDOverlayWnd
        , OverlayVisible: IDOverlayVisible, Status: AutoTargetStatusText, Diag: AutoTargetDiagCode, Detail: AutoTargetDiagDetail}
    wasCritical := A_IsCritical
    try {
        IDCaptureState := "", PhysicalInputBusy := 0, ContextAssistantMode := ""
        hContextAssistantWnd := 0, hHUDWnd := 0, hIDOverlayWnd := 0, IDOverlayVisible := 0
        UserID := "", ActiveID := 0, TargetNickname := "", TargetIsMask := 0
        beforeEpoch := AutomationEpoch
        AuditAssert("Auto ID direct: exact target is selected without confirmation", AutoTargetID_ApplyAimedID(42, 0x200000, -1, "audit", "First_Player") && ActiveID && UserID = 42 && TargetNickname = "First_Player" && !TargetIsMask)
        AuditAssert("Auto ID direct: selection opens no context dialog and keeps epoch", ContextAssistantMode = "" && !hContextAssistantWnd && AutomationEpoch = beforeEpoch)
        AuditAssert("Auto ID direct: stable target is recognised and stays unchanged", AutoTargetID_IsCurrentSelection(42, "First_Player") && AutoTargetID_ApplyAimedID(42, 0x200000, -1, "audit", "First_Player") && AutomationEpoch = beforeEpoch)
        AuditAssert("Auto ID direct: another aimed player replaces selection immediately", AutoTargetID_ApplyAimedID(43, 0x300000, -1, "audit", "Second_Player") && UserID = 43 && TargetNickname = "Second_Player")
        AuditAssert("Auto ID direct: changed nickname refreshes selected player", !AutoTargetID_IsCurrentSelection(43, "Renamed_Player") && AutoTargetID_ApplyAimedID(43, 0x300000, -1, "audit", "Renamed_Player") && TargetNickname = "Renamed_Player")
        AuditAssert("Auto ID direct: ID0 is valid and displayed", AutoTargetID_ApplyAimedID(0, 0x400000, -1, "audit", "Zero_Player") && ActiveID && HasCurrentID() && GetCurrentDisplayID() = "0")
        AuditAssert("Auto ID direct: highest player slot remains valid", AutoTargetID_ApplyAimedID(AZMP_MAX_PLAYERS - 1, 0x500000, -1, "audit", "Last_Player") && UserID = AZMP_MAX_PLAYERS - 1)
        AuditAssert("Auto ID direct: invalid IDs cannot overwrite selection", !AutoTargetID_ApplyAimedID(-1) && !AutoTargetID_ApplyAimedID(AZMP_MAX_PLAYERS) && !AutoTargetID_ApplyAimedID("") && !AutoTargetID_ApplyAimedID("text") && UserID = AZMP_MAX_PLAYERS - 1)
        mask := "12345678901234567890"
        AuditAssert("Auto ID direct: full mask number is preserved with no nickname", AutoTargetID_ApplyAimedID(mask, 0x600000, -1, "audit", "hidden", 1) && "M" . UserID = "M12345678901234567890" && TargetIsMask && TargetNickname = "" && GetCurrentDisplayID() = "12345678901234567890")
        AuditAssert("Auto ID direct: mask identity stays distinct from player ID", AutoTargetID_IsCurrentSelection(mask, "ignored", 1) && !AutoTargetID_IsCurrentSelection(mask, "", 0))
        AuditAssert("Auto ID direct: invalid masks cannot overwrite target", !AutoTargetID_ApplyAimedID("1234", 0, -1, "audit", "", 1) && !AutoTargetID_ApplyAimedID("123456789012345678901", 0, -1, "audit", "", 1) && !AutoTargetID_ApplyAimedID("12x45", 0, -1, "audit", "", 1) && "M" . UserID = "M12345678901234567890")
        IDCaptureState := {}
        AuditAssert("Auto ID direct: manual digit entry protects its target", !AutoTargetID_ApplyAimedID(42) && "M" . UserID = "M12345678901234567890")
        IDCaptureState := "", PhysicalInputBusy := 1
        AuditAssert("Auto ID direct: active physical sender blocks selection change", !AutoTargetID_ApplyAimedID(42) && TargetIsMask)
        PhysicalInputBusy := 0, ContextAssistantMode := "confirm"
        AuditAssert("Auto ID direct: existing confirmation retains ownership", !AutoTargetID_ApplyAimedID(42) && ContextAssistantMode = "confirm" && TargetIsMask)
        ContextAssistantMode := ""
        AutoTargetID_SetStatus("ID 42 · First_Player")
        AutoTargetID_SetDiagnostic("TARGET_OK", "ID 42, ped=0x200000")
        AuditAssert("Auto ID status: successful raw diagnostics keep clean ID/name", AutoTargetStatusText = "ID 42 · First_Player" && AutoTargetDiagDetail = "ID 42, ped=0x200000")
        AutoTargetID_SetDiagnostic("NO_CROSSHAIR_PED", "raw target pointers")
        AuditAssert("Auto ID status: absent target gives visible reason without raw pointers", InStr(AutoTargetStatusText, "NO_CROSSHAIR_PED") && !InStr(AutoTargetStatusText, "raw target"))
        Critical, 17
        changed := AutoTargetID_ApplyAimedID(42, 0x200000, -1, "audit", "First_Player")
        restored := A_IsCritical
        Critical, Off
        AuditAssert("Auto ID direct: caller Critical state is restored", changed && restored = 17)
    } finally {
        UserID := saved.ID, ActiveID := saved.Active, TargetNickname := saved.Name, TargetIsMask := saved.Mask
        IDCaptureState := saved.Capture, PhysicalInputBusy := saved.Busy, ContextAssistantMode := saved.Mode
        hContextAssistantWnd := saved.ContextWnd, hHUDWnd := saved.HUD, hIDOverlayWnd := saved.Overlay
        IDOverlayVisible := saved.OverlayVisible
        AutoTargetStatusText := saved.Status, AutoTargetDiagCode := saved.Diag, AutoTargetDiagDetail := saved.Detail
        if (wasCritical)
            Critical, %wasCritical%
        else
            Critical, Off
    }
}
