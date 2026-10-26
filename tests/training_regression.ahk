RunTrainingRegression() {
    model := Training_NewModel()
    AuditAssert("Training fresh model owns a distinct ledger", IsObject(model.Ledger) && model.Ledger.Length() = 0 && model.GPS.Stage = "closed")
    Training_ModelRecord(model, "Здравия желаю, проверка русского текста.")
    AuditAssert("Training normal messages preserve Cyrillic in bounded ledger", InStr(model.Ledger[1], "проверка русского текста") && model.GPS.Stage = "closed")
    Training_ModelRecord(model, "/gps")
    AuditAssert("Training /gps opens independent simulated list", model.GPS.Stage = "list" && model.GPS.Selected = 0)
    Loop, 15
        Training_ModelRecord(model, "[INPUT Event] {Down}")
    Training_ModelRecord(model, "[INPUT Event] {Enter}")
    Training_ModelRecord(model, "[INPUT Event] ^a{Backspace}")
    Training_ModelRecord(model, "[INPUT Event] {1}")
    Training_ModelRecord(model, "[INPUT Event] {5}")
    Training_ModelRecord(model, "[INPUT Event] {5}")
    AuditAssert("Training consumes actual SafeSend menu output in order", model.GPS.Stage = "number" && model.GPS.Selected = 15 && model.GPS.Digits = "155")
    Training_ModelRecord(model, "[INPUT Event] {Enter}")
    AuditAssert("Training completes GPS only after digits and confirmation", model.GPS.Stage = "complete" && InStr(model.GPS.Result, "155") && InStr(model.GPS.Result, "15"))
    Training_ModelRecord(model, "/gps")
    Training_ModelKeys(model, "{Up}{Up}")
    AuditAssert("Training Up cannot create negative menu selection", model.GPS.Selected = 0)
    Training_ModelKeys(model, "{Enter}{Enter}")
    AuditAssert("Training GPS rejects empty destination", model.GPS.Stage = "number" && model.GPS.Error != "")
    Training_ModelKeys(model, "0{Enter}")
    AuditAssert("Training GPS rejects zero destination", model.GPS.Stage = "number" && model.GPS.Error != "")
    Training_ModelKeys(model, "^a{Backspace}123456")
    AuditAssert("Training GPS caps number length", model.GPS.Digits = "12345" && model.GPS.Error != "")
    Training_ModelKeys(model, "{Backspace}{Backspace}55")
    AuditAssert("Training GPS supports correction before confirmation", model.GPS.Digits = "12355")
    Training_ModelKeys(model, "{Escape}")
    AuditAssert("Training GPS Escape closes menu safely", model.GPS.Stage = "closed")

    AuditAssert("Training target zero is accepted as a valid ID", Training_ModelOffer(model, "0", "Zero_Player") && model.Pending.ID = 0)
    Training_ModelOffer(model, "27", "First_Player")
    Training_ModelOffer(model, "63", "Second_Player")
    AuditAssert("Training new target immediately replaces pending offer", model.Pending.ID = 63 && model.Pending.Nickname = "Second_Player")
    selected := Training_ModelResolveTarget(model, true)
    AuditAssert("Training accepts only latest offered target", IsObject(selected) && selected.ID = 63 && !IsObject(model.Pending) && model.Accepted.ID = 63)
    Training_ModelOffer(model, "88", "Third_Player")
    Training_ModelResolveTarget(model, false)
    AuditAssert("Training reject preserves previously accepted target", model.Rejected.ID = 88 && model.Accepted.ID = 63 && !IsObject(model.Pending))
    AuditAssert("Training rejects malformed/out-of-range IDs", !Training_ModelOffer(model, "-1") && !Training_ModelOffer(model, "1004") && !Training_ModelOffer(model, "1x"))
    other := Training_NewModel()
    Training_ModelRecord(other, "/gps")
    AuditAssert("Training models never share mutable GPS or ledger state", other.GPS.Stage = "list" && model.GPS.Stage = "closed" && other.Ledger.Length() = 1)
    Loop, 600
        Training_ModelAppend(model, "bounded row " . A_Index)
    AuditAssert("Training history retains at most 240 rows", model.Ledger.Length() = 240 && InStr(model.Ledger[240], "600"))
    chunk := ""
    Loop, 4096
        chunk .= "я"
    Loop, 50
        Training_ModelAppend(model, chunk)
    AuditAssert("Training history also bounds retained text memory", model.LedgerChars <= 98304 && model.Ledger.Length() <= 240)
}

Training_RunRegression() {
    return RunTrainingRegression()
}

Training_RunDesktopChecks() {
    global MockMode, UserID, ActiveID, TargetNickname, TargetIsMask, TrainingSession, TrainingHwnd, GPSSettings
    savedMode := MockMode, savedID := UserID, savedActive := ActiveID, savedNick := TargetNickname, savedMask := TargetIsMask
    savedGPS := GPSSettings, savedCooldown := ActionCooldownMs
    try {
        MockMode := "Off"
        DesktopSmoke_Assert("training opens an actual native GUI without game", Training_Start() && TrainingHwnd && Training_IsActive())
        DesktopSmoke_Assert("training does not persist its temporary MockMode", MockMode = "On" && Training_PersistedMockMode() = "Off")
        MockMode := "Off" ; The isolation must also survive an accidental settings change.
        DesktopSmoke_Assert("training memory entry point remains blocked", !checkHandles())
        DesktopSmoke_Assert("training actual send remains local", SendChat("Проверка русского текста", "TrainingDesktop") = 1
            && InStr(TrainingSession.Model.Ledger[TrainingSession.Model.Ledger.Length()], "Проверка русского текста"))
        DesktopSmoke_Assert("training cannot arm real evidence screenshots", !Evidence_Arm("REPORT") && !Evidence_RequestScreenshot("REPORT"))
        DesktopSmoke_Assert("training keyboard output remains local with MockMode OFF", SafeSend("{Home}", "Event", AutomationEpoch))
        MockMode := "On"
        Training_ModelOffer(TrainingSession.Model, "27", "Training_Player")
        DesktopSmoke_Assert("training accepts offered target through production display", Training_Accept() && UserID = 27)
        Training_ModelOffer(TrainingSession.Model, "63", "Next_Player")
        Training_ModelOffer(TrainingSession.Model, "64", "Latest_Player")
        DesktopSmoke_Assert("training replaces pending target before confirmation", TrainingSession.Model.Pending.ID = 64 && Training_Accept() && UserID = 64)
        Training_ModelOffer(TrainingSession.Model, "88", "Rejected_Player")
        DesktopSmoke_Assert("training rejection preserves accepted target", Training_Reject() && UserID = 64)
        GPSSettings := GPS_Defaults(), GPSSettings.HomeDown := 2
        LastActionTick := 0
        DesktopSmoke_Assert("training GPS uses real automation into simulator", GPS_Run("GPS Д", 15, "155")
            && TrainingSession.Model.GPS.Stage = "complete" && TrainingSession.Model.GPS.Selected = 2 && TrainingSession.Model.GPS.Digits = "155")
        Training_SetVirtualContext(true, false, 99)
        DesktopSmoke_Assert("training exercises real action precondition rejection", !CanRunAction("training check", false, true))
        Training_SetVirtualContext(false, true, 2)
        DesktopSmoke_Assert("training reset works without ending session", Training_Reset() && Training_IsActive())
        closingHwnd := TrainingHwnd
        PostMessage, 0x10, 0, 0,, ahk_id %closingHwnd%
        Sleep, 80
        DesktopSmoke_Assert("training native window close invokes shutdown", !Training_IsActive())
        DesktopSmoke_Assert("training exit restores real target and mode", !Training_IsActive() && MockMode = "Off"
            && ("ID:" . UserID) = ("ID:" . savedID) && ActiveID = savedActive && TargetNickname = savedNick && TargetIsMask = savedMask)
        DesktopSmoke_Assert("training exit releases window and keyboard context", !TrainingHwnd && !ServiceUI_IsInputActive() && !PhysicalInputBusy)
    } finally {
        Training_Stop()
        MockMode := savedMode, GPSSettings := savedGPS
        UserID := savedID, ActiveID := savedActive, TargetNickname := savedNick, TargetIsMask := savedMask
    }
}
