; GPS settings/plan/config and real desktop control tests. No real game required.
GPS_RunRegression() {
    global GPSSettings, ConfigWriteFailed, ConfigReadOnly, GPSCalibrationTrial
    previous := GPSSettings, previousFailed := ConfigWriteFailed, previousReadOnly := ConfigReadOnly
    GPSSettings := GPS_Defaults(), errorText := ""
    AuditAssert("GPS default navigation and pacing preserved", GPSSettings.HomeDown = 15 && GPSSettings.OrganizationDown = 16
        && GPSSettings.OpenMs = 500 && GPSSettings.FieldMs = 200 && GPSSettings.ConfirmMs = 50
        && GPSSettings.KeyDelay = 10 && GPSSettings.KeyDuration = 20)
    AuditAssert("GPS default settings validate", GPS_ValidateSettings(GPSSettings, errorText) && errorText = "")
    custom := GPS_GetSettings(), custom.HomeDown := 3, custom.OrganizationDown := 7, custom.OpenMs := 750
    AuditAssert("GPS settings are a detached snapshot", GPSSettings.HomeDown = 15 && custom.HomeDown = 3)
    AuditAssert("GPS home category uses configured count", GPS_ResolveDownCount("GPS Д", 15, custom) = 3)
    AuditAssert("GPS organization category uses configured count", GPS_ResolveDownCount("GPS ОС", 16, custom) = 7)
    AuditAssert("GPS non-category caller count preserved", GPS_ResolveDownCount("Other", 4, custom) = 4)
    plan := GPS_BuildPlan(3, "125", custom), downs := 0
    for _, step in plan
        if (step.Kind = "Key" && step.Value = "Down")
            downs++
    AuditAssert("GPS plan starts at Home and has exact down count", plan[1].Value = "Home" && downs = 3)
    AuditAssert("GPS plan confirms selection before digits", plan[5].Value = "Enter" && plan[6].Kind = "Wait"
        && plan[7].Kind = "Digits" && plan[7].Value = "125" && plan[9].Value = "Enter")
    AuditAssert("GPS plan uses independently configured field pauses", plan[6].Value = 200 && plan[8].Value = 50)
    AuditAssert("GPS zero down count selects first entry", GPS_BuildPlan(0, "1").Length() = 6)
    AuditAssert("GPS invalid values reject before plan execution", !GPS_BuildPlan(81, "1").Length()
        && !GPS_BuildPlan(-1, "1").Length() && !GPS_BuildPlan(1, "0").Length()
        && !GPS_BuildPlan(1, "10001").Length() && !GPS_BuildPlan(1, "1{Enter}").Length())
    invalid := GPS_GetSettings(), invalid.OpenMs := "fast"
    AuditAssert("GPS validates text and identifies invalid field", !GPS_ValidateSettings(invalid, errorText) && InStr(errorText, "/gps"))
    invalid := GPS_GetSettings(), invalid.KeyDuration := 0
    AuditAssert("GPS zero key hold rejected", !GPS_ValidateSettings(invalid, errorText))
    loaded := GPS_GetSettings(invalid)
    AuditAssert("GPS invalid persisted values use bounded default", loaded.KeyDuration = 20)
    preview := GPS_PreviewText("home", "125", custom)
    AuditAssert("GPS preview matches configured route", InStr(preview, "Down x 3") && InStr(preview, "750 мс") && InStr(preview, "125"))
    AuditAssert("GPS preview does not claim game acknowledgement", InStr(preview, "не проверяет") && InStr(preview, "оценка"))
    scratch := A_Temp . "\gps_profile_test_" . DllCall("GetCurrentProcessId") . "_" . TickNow() . ".ini"
    ConfigWriteFailed := 0, ConfigReadOnly := 0
    try {
        GPS_WriteProfile(scratch, "Profile_One", custom)
        other := GPS_GetSettings(), other.HomeDown := 11
        GPS_WriteProfile(scratch, "Profile_Two", other)
        GPS_LoadProfile(scratch, "Profile_One")
        AuditAssert("GPS settings roundtrip through INI", GPSSettings.HomeDown = 3 && GPSSettings.OrganizationDown = 7 && GPSSettings.OpenMs = 750)
        GPS_LoadProfile(scratch, "Profile_Two")
        AuditAssert("GPS settings are isolated by profile", GPSSettings.HomeDown = 11 && GPSSettings.OpenMs = 500)
        GPS_LoadProfile(scratch, "Profile_Missing")
        AuditAssert("GPS old profiles receive original defaults", GPSSettings.HomeDown = 15 && GPSSettings.OrganizationDown = 16)
        GPSCalibrationTrial := {Epoch: AutomationEpoch - 1, Profile: CurrentProfile, Mock: MockMode}
        AuditAssert("GPS cancelled trial cannot run", !GPS_CalibrationTrialFire() && !IsObject(GPSCalibrationTrial))
        GPSCalibrationTrial := {Epoch: AutomationEpoch, Profile: CurrentProfile . " changed", Mock: MockMode}
        AuditAssert("GPS profile change cancels pending trial", !GPS_CalibrationTrialFire() && !IsObject(GPSCalibrationTrial))
        GPSCalibrationTrial := {Epoch: AutomationEpoch, Profile: CurrentProfile, Mock: MockMode = "On" ? "Off" : "On"}
        AuditAssert("GPS test-mode change cancels pending trial", !GPS_CalibrationTrialFire() && !IsObject(GPSCalibrationTrial))
        oldTrial := {Epoch: AutomationEpoch - 1}
        GPSCalibrationTrial := {Epoch: AutomationEpoch}
        AuditAssert("GPS old callback cannot consume new trial", !GPS_CalibrationTrialFire(oldTrial) && IsObject(GPSCalibrationTrial))
        GPS_CancelTrial()
        AuditAssert("GPS stop clears delayed trial", !IsObject(GPSCalibrationTrial))
    } finally {
        FileDelete, %scratch%
        GPSSettings := previous, ConfigWriteFailed := previousFailed, ConfigReadOnly := previousReadOnly
        GPS_CancelTrial()
    }
    GPS_RunRuntimeRegression()
}

GPS_RunDesktopChecks() {
    global GPSSettings, GPSCalibrationProfile, GPSCalibrationHwnd, CurrentProfile
    savedSettings := GPSSettings, savedProfile := CurrentProfile
    GPSSettings := GPS_Defaults()
    GPS_OpenCalibration()
    try {
        DesktopSmoke_Assert("GPS calibration opens native window", DllCall("IsWindow", "Ptr", GPSCalibrationHwnd))
        GuiControl, GpsCalibration:, GPSCal_HomeDown, 4
        GuiControl, GpsCalibration:, GPSCal_Number, 212
        DesktopSmoke_Assert("GPS calibration previews current unsaved controls", GPS_CalibrationPreview())
        GuiControlGet, preview, GpsCalibration:, GPSCal_Preview
        DesktopSmoke_Assert("GPS calibration preview reflects count and number", InStr(preview, "Down x 4") && InStr(preview, "212"))
        DesktopSmoke_Assert("GPS calibration preview leaves live settings intact", GPSSettings.HomeDown = 15)
        Gui, GpsCalibration:Hide
        originalHwnd := GPSCalibrationHwnd
        GPS_OpenCalibration()
        GuiControlGet, draftDown, GpsCalibration:, GPSCal_HomeDown
        DesktopSmoke_Assert("GPS calibration reopening preserves unsaved trial draft", GPSCalibrationHwnd = originalHwnd && draftDown = 4)
        GuiControl, GpsCalibration:, GPSCal_KeyDuration, 0
        DesktopSmoke_Assert("GPS calibration refuses invalid controls", !GPS_CalibrationPreview())
        GuiControl, GpsCalibration:, GPSCal_KeyDuration, 20
        CurrentProfile := savedProfile . " changed"
        DesktopSmoke_Assert("GPS calibration refuses stale profile window", !GPS_CalibrationPreview())
        CurrentProfile := savedProfile
        GPS_CalibrationDefaults()
        GuiControlGet, down, GpsCalibration:, GPSCal_HomeDown
        DesktopSmoke_Assert("GPS calibration restores defaults in editor", down = 15)
    } finally {
        GPS_CalibrationClose()
        CurrentProfile := savedProfile, GPSSettings := savedSettings
    }
    DesktopSmoke_Assert("GPS calibration closes cleanly", !GPSCalibrationHwnd && !IsObject(GPSCalibrationTrial))
}

GPS_RunRuntimeRegression() {
    global
    saved := {Settings: GPSSettings, Mock: MockMode, Audit: AuditTestMode, Cooldown: ActionCooldownMs
        , LastAction: LastActionTick, Preview: ChatQueuePreviewText, PreviewCount: ChatQueuePreviewLineCount
        , PreviewLength: ChatQueuePreviewKnownLength, Physical: PhysicalInputBusy, QueueBusy: ChatQueueBusy
        , Starting: GameMenuStarting, Lease: GameMenuLease, IDCapture: IDCaptureState
        , Input: ServiceUIInputState, Confirm: ServiceUIConfirmState}
    try {
        MockMode := "On", AuditTestMode := 1, ActionCooldownMs := 0
        PhysicalInputBusy := 0, ChatQueueBusy := 0, GameMenuStarting := "", GameMenuLease := ""
        IDCaptureState := "", ServiceUIInputState := "", ServiceUIConfirmState := ""
        ChatQueuePreviewText := "", ChatQueuePreviewLineCount := 0, ChatQueuePreviewKnownLength := 0
        GPSSettings := GPS_Defaults(), GPSSettings.HomeDown := 2, GPSSettings.OrganizationDown := 4
        ok := GPS_Run("GPS Д", 15, "23", AutomationEpoch)
        preview := ChatQueuePreviewText
        StrReplace(preview, "[INPUT Event] {Down}", "", downCount)
        startAt := InStr(preview, "/gps"), homeAt := InStr(preview, "[INPUT Event] {Home}")
        firstDigit := InStr(preview, "[INPUT Event] {2}"), lastDigit := InStr(preview, "[INPUT Event] {3}")
        AuditAssert("GPS real runtime mocks configured home sequence", ok && downCount = 2 && startAt && homeAt > startAt
            && firstDigit > homeAt && lastDigit > firstDigit)
        AuditAssert("GPS runtime releases keyboard ownership", !PhysicalInputBusy && !IsObject(GameMenuLease) && !IsObject(GameMenuStarting))
        ChatQueuePreviewText := "", ChatQueuePreviewLineCount := 0, ChatQueuePreviewKnownLength := 0
        ok := RunGpsDialogAction("GPS ОС", 16, "10000", AutomationEpoch)
        StrReplace(ChatQueuePreviewText, "[INPUT Event] {Down}", "", downCount)
        AuditAssert("GPS public wrapper uses configured organization sequence", ok && downCount = 4 && InStr(ChatQueuePreviewText, "/gps"))
        before := ChatQueuePreviewText
        AuditAssert("GPS stale epoch sends no command or keys", !GPS_Run("GPS Д", 15, "23", AutomationEpoch - 1)
            && ChatQueuePreviewText = before)
    } finally {
        GPSSettings := saved.Settings, MockMode := saved.Mock, AuditTestMode := saved.Audit
        ActionCooldownMs := saved.Cooldown, LastActionTick := saved.LastAction
        ChatQueuePreviewText := saved.Preview, ChatQueuePreviewLineCount := saved.PreviewCount
        ChatQueuePreviewKnownLength := saved.PreviewLength, PhysicalInputBusy := saved.Physical
        ChatQueueBusy := saved.QueueBusy, GameMenuStarting := saved.Starting, GameMenuLease := saved.Lease
        IDCaptureState := saved.IDCapture, ServiceUIInputState := saved.Input, ServiceUIConfirmState := saved.Confirm
    }
}
