; Exercise fast replacement and the original confirmation flow without a game or visible GUI.
Audit_AutoIDSource() {
    global UserID, ActiveID, TargetNickname, TargetIsMask, MockMode, AutoTargetPendingKey, AutoTargetOfferedKey
    global ContextAssistantMode, ContextAssistantAction, ContextAssistantInput
    global ContextAssistantVariant, ContextAssistantTargetName, ContextAssistantStatus
    global ContextNotificationMode, ContextNotificationTimeoutSec, hContextAssistantWnd
    global hHUDWnd, hIDOverlayWnd, IDOverlayVisible, IDCaptureState, PhysicalInputBusy
    saved := {ID: UserID, Active: ActiveID, Name: TargetNickname, Mask: TargetIsMask
        , Mock: MockMode, Mode: ContextAssistantMode, Action: ContextAssistantAction
        , Input: ContextAssistantInput, Variant: ContextAssistantVariant
        , TargetName: ContextAssistantTargetName, Status: ContextAssistantStatus
        , Notification: ContextNotificationMode, Timeout: ContextNotificationTimeoutSec
        , ContextHwnd: hContextAssistantWnd, HUD: hHUDWnd, Overlay: hIDOverlayWnd
        , Pending: AutoTargetPendingKey, Offered: AutoTargetOfferedKey
        , OverlayVisible: IDOverlayVisible, Capture: IDCaptureState, Busy: PhysicalInputBusy}
    try {
        MockMode := "On", ContextNotificationMode := "×àò", ContextNotificationTimeoutSec := 8
        hContextAssistantWnd := 0, hHUDWnd := 0, hIDOverlayWnd := 0, IDOverlayVisible := 0
        IDCaptureState := "", PhysicalInputBusy := 0
        AutoTargetPendingKey := "", AutoTargetOfferedKey := ""
        ContextAssistantMode := "", UserID := 75, ActiveID := 1
        TargetNickname := "Previous_Player", TargetIsMask := 0
        requested := AutoTargetID_RequestConfirmation(42, 0x200000, -1, "audit", "First_Player")
        AuditAssert("Auto ID source: found target opens EnterID confirmation", requested && ContextAssistantMode = "confirm" && ContextAssistantAction = "EnterID" && ContextAssistantInput = 42)
        AuditAssert("Auto ID source: pending target leaves previous selection unchanged", UserID = 75 && TargetNickname = "Previous_Player")
        AuditAssert("Auto ID: new target immediately replaces pending confirmation", AutoTargetID_RequestConfirmation(43, 0x300000, -1, "audit", "Second_Player") && ContextAssistantInput = 43 && ContextAssistantTargetName = "Second_Player")
        AuditAssert("Auto ID: same target does not rebuild confirmation", !AutoTargetID_RequestConfirmation(43, 0x300000, -1, "audit", "Second_Player") && ContextAssistantInput = 43)
        ContextAssistant_Close()
        AuditAssert("Auto ID source: rejection preserves previous selection", UserID = 75 && TargetNickname = "Previous_Player" && ContextAssistantMode = "")
        AuditAssert("Auto ID: rejected target is not offered again in the same hold", !AutoTargetID_RequestConfirmation(43, 0x300000, -1, "audit", "Second_Player") && ContextAssistantMode = "")
        AutoTargetID_RequestConfirmation(41, 0x100000, -1, "audit", "Old_Player")
        AutoTargetID_RequestConfirmation(42, 0x200000, -1, "audit", "First_Player")
        AuditAssert("Auto ID source: acceptance applies ID and nickname", ContextAssistant_Submit() && UserID = 42 && TargetNickname = "First_Player" && !TargetIsMask && ContextAssistantMode = "")
        ContextAssistantMode := "confirm", ContextAssistantAction := "Chase", ContextAssistantInput := 88
        AuditAssert("Auto ID: unrelated confirmation is preserved", !AutoTargetID_RequestConfirmation(43, 0x300000, -1, "audit", "Second_Player") && ContextAssistantAction = "Chase" && ContextAssistantInput = 88)
        ContextAssistant_Close()
        IDCaptureState := {}
        AuditAssert("Auto ID: digit capture cannot be interrupted", !AutoTargetID_RequestConfirmation(43, 0x300000) && ContextAssistantMode = "")
        IDCaptureState := ""
        PhysicalInputBusy := 1
        AuditAssert("Auto ID: active input cannot be interrupted", !AutoTargetID_RequestConfirmation(43, 0x300000) && ContextAssistantMode = "")
        PhysicalInputBusy := 0
        mask := "12345678901234567890"
        AutoTargetID_RequestConfirmation(mask, 0x400000, -1, "audit", "", 1)
        AuditAssert("Auto ID source: mask waits for confirmation without changing ID", ContextAssistantMode = "confirm" && "M" . ContextAssistantInput = "M__MASK__:12345678901234567890" && UserID = 42)
        AuditAssert("Auto ID source: acceptance preserves full mask", ContextAssistant_Submit() && "M" . UserID = "M12345678901234567890" && TargetIsMask && TargetNickname = "")
        AuditAssert("Auto ID source: absent target opens no confirmation", !AutoTargetID_RequestConfirmation(-1) && !AutoTargetID_RequestConfirmation("") && ContextAssistantMode = "")
    } finally {
        ContextAssistant_Close()
        UserID := saved.ID, ActiveID := saved.Active, TargetNickname := saved.Name, TargetIsMask := saved.Mask
        MockMode := saved.Mock, ContextAssistantMode := saved.Mode, ContextAssistantAction := saved.Action
        ContextAssistantInput := saved.Input, ContextAssistantVariant := saved.Variant
        ContextAssistantTargetName := saved.TargetName, ContextAssistantStatus := saved.Status
        ContextNotificationMode := saved.Notification, ContextNotificationTimeoutSec := saved.Timeout
        hContextAssistantWnd := saved.ContextHwnd, hHUDWnd := saved.HUD, hIDOverlayWnd := saved.Overlay
        AutoTargetPendingKey := saved.Pending, AutoTargetOfferedKey := saved.Offered
        IDOverlayVisible := saved.OverlayVisible, IDCaptureState := saved.Capture, PhysicalInputBusy := saved.Busy
    }
}
