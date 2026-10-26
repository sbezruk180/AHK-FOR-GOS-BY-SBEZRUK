; Profile-scoped GPS keyboard calibration. AHK v1.1 ANSI x86.
; The same validated plan powers preview, offline training and live execution.
; No dialog-memory offsets, synthetic success acknowledgement or automatic retries.
global GPSSettings := ""
global GPSCalibrationHwnd := 0
global GPSCalibrationProfile := ""
global GPSCalibrationTrial := ""
global GPSCalibrationTimer := ""
global GPSCalibrationStatus := ""
global GPSCal_HomeDown := "", GPSCal_OrganizationDown := "", GPSCal_OpenMs := "", GPSCal_FieldMs := ""
global GPSCal_ConfirmMs := "", GPSCal_KeyDelay := "", GPSCal_KeyDuration := "", GPSCal_Category := ""
global GPSCal_Number := "", GPSCal_Preview := ""

GPS_Defaults() {
    return {HomeDown: 15, OrganizationDown: 16, OpenMs: 500, FieldMs: 200
        , ConfirmMs: 50, KeyDelay: 10, KeyDuration: 20}
}

GPS_FieldCatalog() {
    static fields := [{Key: "HomeDown", Caption: "Стрелок вниз: дом", Minimum: 0, Maximum: 80}
        , {Key: "OrganizationDown", Caption: "Стрелок вниз: организация", Minimum: 0, Maximum: 80}
        , {Key: "OpenMs", Caption: "После /gps, мс", Minimum: 100, Maximum: 5000}
        , {Key: "FieldMs", Caption: "После выбора пункта, мс", Minimum: 30, Maximum: 5000}
        , {Key: "ConfirmMs", Caption: "После ввода номера, мс", Minimum: 0, Maximum: 1000}
        , {Key: "KeyDelay", Caption: "Пауза между клавишами, мс", Minimum: 0, Maximum: 500}
        , {Key: "KeyDuration", Caption: "Удержание клавиши, мс", Minimum: 5, Maximum: 200}]
    return fields
}

GPS_ValidateSettings(settings, ByRef errorText) {
    errorText := ""
    if !IsObject(settings) {
        errorText := "Не заданы настройки GPS."
        return false
    }
    for _, field in GPS_FieldCatalog() {
        value := settings[field.Key]
        if (!RegExMatch(value . "", "^[0-9]+$") || StrLen(value . "") > 6
            || value + 0 < field.Minimum || value + 0 > field.Maximum) {
            errorText := field.Caption . ": целое число от " . field.Minimum . " до " . field.Maximum . "."
            return false
        }
    }
    return true
}

GPS_GetSettings(override := "") {
    global GPSSettings
    source := IsObject(override) ? override : GPSSettings
    defaults := GPS_Defaults(), settings := {}
    for _, field in GPS_FieldCatalog() {
        value := IsObject(source) && source.HasKey(field.Key) ? source[field.Key] : defaults[field.Key]
        if (!RegExMatch(value . "", "^[0-9]+$") || StrLen(value . "") > 6
            || value + 0 < field.Minimum || value + 0 > field.Maximum)
            value := defaults[field.Key]
        settings[field.Key] := value + 0
    }
    return settings
}

GPS_LoadProfile(fileName, section) {
    global GPSSettings
    settings := GPS_Defaults()
    for _, field in GPS_FieldCatalog() {
        key := "GPS_" . field.Key
        IniRead, value, %fileName%, %section%, %key%, % settings[field.Key]
        settings[field.Key] := value
    }
    GPSSettings := GPS_GetSettings(settings)
    return true
}

GPS_WriteProfile(fileName, section, settings := "") {
    settings := GPS_GetSettings(settings)
    for _, field in GPS_FieldCatalog()
        CheckedIniWrite(settings[field.Key], fileName, section, "GPS_" . field.Key)
    return !ConfigWriteFailed
}

GPS_ResolveDownCount(actionName, defaultDownCount, settings := "") {
    settings := GPS_GetSettings(settings)
    ; Preserve the public RunGpsDialogAction signature and other callers' counts.
    ; Category is recognised from its original count, not a translated UI label.
    if (defaultDownCount = 15)
        return settings.HomeDown
    if (defaultDownCount = 16)
        return settings.OrganizationDown
    return defaultDownCount
}

GPS_BuildPlan(downCount, gpsNumber, settings := "") {
    if (!RegExMatch(downCount . "", "^[0-9]+$") || downCount + 0 > 80
        || !RegExMatch(gpsNumber . "", "^[0-9]{1,5}$") || gpsNumber + 0 < 1 || gpsNumber + 0 > 10000)
        return []
    settings := GPS_GetSettings(settings)
    plan := [{Kind: "Key", Value: "Home", Stage: "начало списка"}]
    Loop % downCount
        plan.Push({Kind: "Key", Value: "Down", Stage: "выбор пункта " . A_Index . "/" . downCount})
    plan.Push({Kind: "Key", Value: "Enter", Stage: "открытие поля номера"})
    plan.Push({Kind: "Wait", Value: settings.FieldMs, Stage: "ожидание поля номера"})
    plan.Push({Kind: "Digits", Value: gpsNumber, Stage: "ввод номера"})
    plan.Push({Kind: "Wait", Value: settings.ConfirmMs, Stage: "пауза перед подтверждением"})
    plan.Push({Kind: "Key", Value: "Enter", Stage: "подтверждение"})
    return plan
}

GPS_PreviewText(category, number, settings := "") {
    settings := GPS_GetSettings(settings)
    down := category = "organization" ? settings.OrganizationDown : settings.HomeDown
    plan := GPS_BuildPlan(down, number, settings)
    if !plan.Length()
        return "Укажите номер от 1 до 10000."
    text := "/gps > ожидание " . settings.OpenMs . " мс`r`nHome > Down x " . down
        . " > Enter > ожидание " . settings.FieldMs . " мс`r`nCtrl+A / Backspace > цифры " . number
        . " > ожидание " . settings.ConfirmMs . " мс > Enter`r`n`r`n"
    keyCount := down + 3 + StrLen(number) + 2
    text .= "Клавиши: пауза " . settings.KeyDelay . " мс, удержание " . settings.KeyDuration . " мс.`r`n"
        . "Оценка после отправки /gps: около " . (settings.OpenMs + settings.FieldMs + settings.ConfirmMs
        + keyCount * (settings.KeyDelay + settings.KeyDuration)) . " мс. Это оценка; задержка сервера неизвестна.`r`n"
        . "Проба не проверяет, что сервер построил маршрут. Если выбран не тот пункт, исправьте число стрелок."
    return text
}

GPS_Run(actionName, downCount, gpsNumber, inputEpoch := 0, settingsOverride := "") {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch)
        return false
    gpsNumber := Trim(gpsNumber)
    settings := GPS_GetSettings(settingsOverride)
    downCount := GPS_ResolveDownCount(actionName, downCount, settings)
    plan := GPS_BuildPlan(downCount, gpsNumber, settings)
    if !plan.Length() {
        Notify("warn")
        return false
    }
    if !CanRunAction(actionName, false, false)
        return false
    reservation := GameMenu_Reserve("GPS", inputEpoch)
    if !IsObject(reservation)
        return SafeWarn("GPS: ввод занят другим действием.")
    ok := false, stage := "закрытие чата", traceId := 0, traceStep := 0
    if IsFunc("ActionTrace_Begin")
        traceId := ActionTrace_Begin("GPS: " . actionName, plan.Length() + 1)
    try {
        if !GameMenu_Prepare(reservation)
            return false
        stage := "открытие /gps"
        if (traceId) {
            traceStep := ActionTrace_Add(traceId, "command", "/gps", false)
            ActionTrace_Update(traceId, traceStep, "running")
        }
        ; Amazing GPS uses keys. Do not wait for SA-MP dialog or chatlog messages.
        lease := GameMenu_SendCommand(reservation, "/gps", settings.OpenMs, false)
        if !IsObject(lease)
            return false
        if (traceId)
            ActionTrace_Update(traceId, traceStep, "done", "Команда отправлена; выдержана пауза открытия.")
        lease.KeyDelay := settings.KeyDelay, lease.KeyDuration := settings.KeyDuration
        for _, step in plan {
            ok := false
            stage := step.Stage
            if (traceId) {
                traceStep := ActionTrace_Add(traceId, step.Kind, stage, false)
                ActionTrace_Update(traceId, traceStep, "running")
            }
            if (step.Kind = "Key")
                ok := GameMenu_Tap(lease, step.Value)
            else if (step.Kind = "Digits")
                ok := GameMenu_TypeDigits(lease, step.Value)
            else if (step.Kind = "Wait")
                ok := GameMenu_Wait(lease, step.Value)
            else
                ok := false
            if (!ok)
                return false
            if (traceId)
                ActionTrace_Update(traceId, traceStep, "done", "Клавиша/пауза выполнена локально; ответ сервера не проверяется.")
        }
        return true
    } finally {
        GameMenu_Close(reservation)
        if (traceId) {
            traceStatus := ok ? "done" : (inputEpoch != AutomationEpoch ? "cancelled" : "failed")
            if (!ok && traceStep)
                ActionTrace_Update(traceId, traceStep, traceStatus, "Остановлено: " . stage . ". Повтор отключён.")
            ActionTrace_Finish(traceId, traceStatus, ok ? "Клавиши выполнены. Маршрут проверяет пользователь в игре." : "Остановлено: " . stage)
        }
        if (!ok) {
            LogError("GPS", "Остановлено: " . stage . "; поколение " . inputEpoch . ". Повтор /gps не выполнялся.", "WARN")
            if (inputEpoch = AutomationEpoch)
                ServiceUI_Notify("GPS остановлен: " . stage . ". Проверьте активное окно игры.", 3500, "WARN")
        }
    }
}

GPS_OpenCalibration(params*) {
    global GPSCalibrationHwnd, GPSCalibrationProfile, GPSCalibrationStatus
    global CurrentProfile, GAME_PROCESS_NAME, UIRoundness
    GPS_CancelTrial()
    ; Reopening after a trial preserves its unsaved draft and result.
    if (GPSCalibrationProfile = CurrentProfile && GPSCalibrationHwnd && DllCall("IsWindow", "Ptr", GPSCalibrationHwnd)) {
        Capture_BeforeShow("GpsCalibration")
        Gui, GpsCalibration:Show, % GameUi_ShouldShowPassive() ? "NoActivate" : ""
        return true
    }
    settings := GPS_GetSettings(), GPSCalibrationProfile := CurrentProfile
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    Gui, GpsCalibration:Destroy
    Gui, GpsCalibration:New, +HwndGPSCalibrationHwnd +AlwaysOnTop -Resize +ToolWindow +DPIScale
    Gui, GpsCalibration:Color, %panel%, %surface%
    Gui, GpsCalibration:Margin, 0, 0
    Gui, GpsCalibration:Font, s16 Bold c%fg%, Segoe UI
    Gui, GpsCalibration:Add, Text, x24 y20 w650 h32 BackgroundTrans, Настройка GPS под ваш клиент
    Gui, GpsCalibration:Font, s9 Norm c%muted%, Segoe UI
    caption := "Профиль: " . CurrentProfile . " | Клиент: " . GAME_PROCESS_NAME
    Gui, GpsCalibration:Add, Text, x24 y58 w650 h24 BackgroundTrans, %caption%
    Gui, GpsCalibration:Add, Text, x24 y88 w650 h40 +Wrap BackgroundTrans, 1. Задайте число стрелок и паузы. 2. Проверьте схему. 3. Выполните пробу и сохраните рабочие значения.
    Gui, GpsCalibration:Font, s9 Norm c%fg%, Segoe UI
    for index, field in GPS_FieldCatalog() {
        column := index > 4 ? 1 : 0, row := index > 4 ? index - 5 : index - 1
        x := 24 + column * 340, y := 144 + row * 42, editX := x + 230
        control := "GPSCal_" . field.Key, value := settings[field.Key]
        Gui, GpsCalibration:Add, Text, x%x% y%y% w222 h26 BackgroundTrans, % field.Caption
        Gui, GpsCalibration:Add, Edit, x%editX% y%y% w80 h28 v%control% Number Limit6, %value%
    }
    Gui, GpsCalibration:Add, Text, x24 y322 w150 h24 BackgroundTrans, Проверить маршрут:
    Gui, GpsCalibration:Add, DropDownList, x178 y318 w240 vGPSCal_Category Choose1, Дом|Организация
    Gui, GpsCalibration:Add, Edit, x434 y318 w100 h28 vGPSCal_Number Number Limit5, 1
    Gui, GpsCalibration:Add, Button, x548 y318 w136 h30 gGPS_CalibrationPreview, Схема
    Gui, GpsCalibration:Font, s9 Norm c%inputFg%, Segoe UI
    Gui, GpsCalibration:Add, Edit, x24 y362 w660 h142 vGPSCal_Preview ReadOnly -Wrap, % GPS_PreviewText("home", "1", settings)
    Gui, GpsCalibration:Font, s9 Norm c%muted%, Segoe UI
    Gui, GpsCalibration:Add, Text, x24 y518 w660 h42 +Wrap BackgroundTrans vGPSCalibrationStatus, Проба скроет это окно. За 3 секунды вернитесь в игру. Автоповтора нет; отмена — общей клавишей остановки.
    Gui, GpsCalibration:Font, s9 Norm c%fg%, Segoe UI
    Gui, GpsCalibration:Add, Button, x24 y574 w200 h36 gGPS_CalibrationTrialStart, Проба через 3 секунды
    Gui, GpsCalibration:Add, Button, x238 y574 w136 h36 gGPS_CalibrationSave, Сохранить
    Gui, GpsCalibration:Add, Button, x388 y574 w142 h36 gGPS_CalibrationDefaults, По умолчанию
    Gui, GpsCalibration:Add, Button, x544 y574 w140 h36 gGPS_CalibrationClose, Закрыть
    Capture_BeforeShow("GpsCalibration")
    Gui, GpsCalibration:Show, % "w708 h632" . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), AHK FOR GOS - GPS
    ApplyRoundedCorners(GPSCalibrationHwnd, UIRoundness)
    return !!GPSCalibrationHwnd
}

GPS_CalibrationRead(ByRef settings, ByRef category, ByRef number) {
    global GPSCalibrationProfile
    if (GPSCalibrationProfile != CurrentProfile) {
        GPS_CalibrationSetStatus("Профиль сменился. Закройте окно и откройте настройку GPS заново.")
        return false
    }
    settings := {}
    for _, field in GPS_FieldCatalog() {
        control := "GPSCal_" . field.Key
        GuiControlGet, value, GpsCalibration:, %control%
        settings[field.Key] := Trim(value)
    }
    if !GPS_ValidateSettings(settings, errorText) {
        GPS_CalibrationSetStatus(errorText)
        return false
    }
    GuiControlGet, label, GpsCalibration:, GPSCal_Category
    category := label = "Организация" ? "organization" : "home"
    GuiControlGet, number, GpsCalibration:, GPSCal_Number
    if (!RegExMatch(number, "^[0-9]{1,5}$") || number + 0 < 1 || number + 0 > 10000) {
        GPS_CalibrationSetStatus("Номер маршрута: от 1 до 10000.")
        return false
    }
    settings := GPS_GetSettings(settings)
    return true
}

GPS_CalibrationSetStatus(message) {
    global GPSCalibrationHwnd
    if (GPSCalibrationHwnd && DllCall("IsWindow", "Ptr", GPSCalibrationHwnd))
        UIStyle_SetTextIfChanged("GpsCalibration", "GPSCalibrationStatus", message)
    return false
}

GPS_CalibrationPreview(params*) {
    if !GPS_CalibrationRead(settings, category, number)
        return false
    GuiControl, GpsCalibration:, GPSCal_Preview, % GPS_PreviewText(category, number, settings)
    GPS_CalibrationSetStatus("Схема обновлена. Ничего не отправлялось в игру.")
    return true
}

GPS_CalibrationSave(params*) {
    global GPSSettings, ConfigFile, GPSCalibrationProfile, UiPreviewMode
    if !GPS_CalibrationRead(settings, category, number)
        return false
    if (UiPreviewMode)
        return GPS_CalibrationSetStatus("В режиме предпросмотра настройки не сохраняются.")
    profile := GPSCalibrationProfile
    target := ConfigStage(ConfigFile)
    if (target = "")
        return GPS_CalibrationSetStatus("Не удалось начать сохранение. Настройки не изменены.")
    GPS_WriteProfile(target, "Profile_" . profile, settings)
    if !ConfigCommit(target, ConfigFile)
        return GPS_CalibrationSetStatus("Не удалось записать настройки GPS. Рабочие значения сохранены без изменений.")
    if (profile = CurrentProfile)
        GPSSettings := settings
    GPS_CalibrationSetStatus("GPS сохранён в текущем профиле. Проба сама настройки не сохраняет.")
    return true
}

GPS_CalibrationDefaults(params*) {
    for _, field in GPS_FieldCatalog()
        GuiControl, GpsCalibration:, % "GPSCal_" . field.Key, % GPS_Defaults()[field.Key]
    return GPS_CalibrationPreview()
}

GPS_CalibrationTrialStart(params*) {
    global GPSCalibrationTrial, GPSCalibrationTimer, MockMode
    if !GPS_CalibrationRead(settings, category, number)
        return false
    if (PhysicalInputBusy || ChatQueueBusy || IsObject(GameMenuStarting) || ServiceUI_IsInputActive() || IsObject(IDCaptureState))
        return GPS_CalibrationSetStatus("Ввод занят. Дождитесь завершения действия перед пробой.")
    GPS_CancelTrial()
    GPSCalibrationTrial := {Epoch: AutomationEpoch, Profile: CurrentProfile, Settings: settings
        , Category: category, Number: number, Mock: MockMode}
    GPSCalibrationTimer := Func("GPS_CalibrationTrialFire").Bind(GPSCalibrationTrial)
    Gui, GpsCalibration:Hide
    ServiceUI_Notify("Проба GPS через 3 секунды: вернитесь в игру. Общая остановка отменяет пробу.", 3000)
    SetTimer, % GPSCalibrationTimer, -3000
    return true
}

GPS_CalibrationTrialFire(expectedTrial := "") {
    global GPSCalibrationTrial, GPSCalibrationTimer, MockMode
    ; A delayed callback from an older trial cannot consume a newer request.
    if (IsObject(expectedTrial) && expectedTrial != GPSCalibrationTrial)
        return false
    trial := GPSCalibrationTrial, GPSCalibrationTrial := "", GPSCalibrationTimer := ""
    if (!IsObject(trial) || trial.Epoch != AutomationEpoch || trial.Profile != CurrentProfile || trial.Mock != MockMode) {
        GPS_CalibrationSetStatus("Проба отменена: действие остановлено, профиль или режим изменился. Черновик сохранён в окне.")
        return false
    }
    if (MockMode != "On" && !AuditTestMode && !GameLocator_IsActive()) {
        GPS_CalibrationSetStatus("Проба отменена: окно игры не активно. Ввод не отправлялся. Исправьте условия и повторите пробу.")
        ServiceUI_Notify("Проба GPS отменена: окно игры не активно. Ввод не отправлялся.", 4500, "WARN")
        return false
    }
    down := trial.Category = "organization" ? 16 : 15
    ok := GPS_Run("Проба GPS", down, trial.Number, trial.Epoch, trial.Settings)
    GPS_CalibrationSetStatus(ok ? "Проба завершена. Если маршрут верный, сохраните эти значения. Иначе исправьте их и повторите пробу."
        : "Проба прервана. Черновик сохранён; проверьте фокус, число стрелок и задержки.")
    ServiceUI_Notify(ok ? "Клавиши GPS выполнены. Проверьте маршрут в игре; затем сохраните настройки в мастере."
        : "Проба GPS прервана. Повтор автоматически не выполняется.", 5000, ok ? "INFO" : "WARN")
    return ok
}

GPS_CancelTrial() {
    global GPSCalibrationTrial, GPSCalibrationTimer
    GPSCalibrationTrial := ""
    if IsObject(GPSCalibrationTimer)
        SetTimer, % GPSCalibrationTimer, Off
    GPSCalibrationTimer := ""
}

GPS_CalibrationClose(params*) {
    global GPSCalibrationHwnd, GPSCalibrationProfile
    GPS_CancelTrial()
    Gui, GpsCalibration:Destroy
    GPSCalibrationHwnd := 0, GPSCalibrationProfile := ""
}

GpsCalibrationGuiClose() {
    GPS_CalibrationClose()
}

GpsCalibrationGuiEscape() {
    GPS_CalibrationClose()
}
