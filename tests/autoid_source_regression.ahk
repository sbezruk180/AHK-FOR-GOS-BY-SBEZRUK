; Exercise the restored reference confirmation flow without a game or visible GUI.
Audit_AutoIDSource() {
    global UserID, ActiveID, TargetNickname, TargetIsMask, MockMode
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
        , OverlayVisible: IDOverlayVisible, Capture: IDCaptureState, Busy: PhysicalInputBusy}
    try {
        MockMode := "On", ContextNotificationMode := "×àò", ContextNotificationTimeoutSec := 8
        hContextAssistantWnd := 0, hHUDWnd := 0, hIDOverlayWnd := 0, IDOverlayVisible := 0
        IDCaptureState := "", PhysicalInputBusy := 0
        ContextAssistantMode := "", UserID := 75, ActiveID := 1
        TargetNickname := "Previous_Player", TargetIsMask := 0
        requested := AutoTargetID_RequestConfirmation(42, 0x200000, -1, "audit", "First_Player")
        AuditAssert("Auto ID source: found target opens EnterID confirmation", requested && ContextAssistantMode = "confirm" && ContextAssistantAction = "EnterID" && ContextAssistantInput = 42)
        AuditAssert("Auto ID source: pending target leaves previous selection unchanged", UserID = 75 && TargetNickname = "Previous_Player")
        AuditAssert("Auto ID source: second request cannot replace pending confirmation", !AutoTargetID_RequestConfirmation(43, 0x300000, -1, "audit", "Second_Player") && ContextAssistantInput = 42)
        ContextAssistant_Close()
        AuditAssert("Auto ID source: rejection preserves previous selection", UserID = 75 && TargetNickname = "Previous_Player" && ContextAssistantMode = "")
        AutoTargetID_RequestConfirmation(42, 0x200000, -1, "audit", "First_Player")
        AuditAssert("Auto ID source: acceptance applies ID and nickname", ContextAssistant_Submit() && UserID = 42 && TargetNickname = "First_Player" && !TargetIsMask && ContextAssistantMode = "")
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
        IDOverlayVisible := saved.OverlayVisible, IDCaptureState := saved.Capture, PhysicalInputBusy := saved.Busy
    }
}
