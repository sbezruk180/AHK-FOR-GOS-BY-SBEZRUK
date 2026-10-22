; actions subsystem. Definitions only; initialization is in bootstrap.

CanRunAction(actionName, needsID := false, checkChatClosed := true, requireVehicle := false, requireChatOpen := false, requireCloseRange := false) {
    if (IsObject(IDCaptureState) || PhysicalInputBusy || IsObject(GameMenuStarting) || IsObject(GameMenuLease))
        return false
    global ActionCooldownMs, LastActionTick
    global SafeModeEnabled, SafeBlockWhenChat, SafeVehicleChecks, SafeRequireChatForEditable
    global SafeDistanceChecks, SafeDistanceLimit

    if !EnsureGameActive()
        return false

    if (needsID && !CheckID())
        return false

    masterSafe := (SafeModeEnabled = "On")
    requireOpenCheck := requireChatOpen && (masterSafe || SafeRequireChatForEditable = "On")
    requireClosedCheck := checkChatClosed && (masterSafe || SafeBlockWhenChat = "On")
    if (requireOpenCheck || requireClosedCheck)
    {
        chatState := isInChat()
        if (requireOpenCheck && chatState != 1)
            return SafeWarn("Открой чат перед действием: " . actionName)
        if (requireClosedCheck && chatState = 1)
            return SafeWarn("Закрой чат перед действием: " . actionName)
    }

    if (requireVehicle && (masterSafe || SafeVehicleChecks = "On") && isPlayerInAnyVehicle() <= 0)
        return SafeWarn("Действие требует транспорт: " . actionName)

    shouldCheckDistance := requireCloseRange || (needsID && SafeDistanceChecks = "On")
    if (shouldCheckDistance && (masterSafe || SafeDistanceChecks = "On"))
    {
        NormalizeNumberRange(SafeDistanceLimit, 12, 2, 50)
        distSource := ""
        dist := GetCrosshairTargetDistance(distSource)
        if (dist < 0)
            return SafeWarn("Не удалось определить расстояние до цели: " . actionName)
        if (dist > SafeDistanceLimit)
            return SafeWarn("Цель слишком далеко: " . Round(dist, 1) . " м, лимит " . SafeDistanceLimit . " м")
        LogError("DistanceCheck", actionName . ": " . Round(dist, 2) . " м | " . distSource, "INFO")
    }

    NormalizeNumberRange(ActionCooldownMs, 250, 0, 5000)
    if (ActionCooldownMs > 0)
    {
        elapsed := TickNow() - LastActionTick
        if (LastActionTick > 0 && elapsed < ActionCooldownMs)
            return false
    }

    LastActionTick := TickNow()
    return true
}

CheckID() {
    global IDCheckEnabled
    if (!IDCheckEnabled)
        return true
    if HasCurrentID()
        return true
    if (GetKeyState("RButton", "P") && AutoTargetID_CaptureNow(0))
        return HasCurrentID()
    Notify("warn")
    GameNotify("ID не задан. Зажми ПКМ, наведи на игрока или используй !цель.", "WARN")
    return false
}

CanRunCuffFollowup() {
    global SafeModeEnabled, SafeBlockWhenChat
    if (PhysicalInputBusy || IsObject(GameMenuStarting) || IsObject(GameMenuLease))
        return false
    if !EnsureGameActive()
        return false
    if !CheckID()
        return false
    if ((SafeModeEnabled = "On" || SafeBlockWhenChat = "On") && isInChat() = 1)
        return SafeWarn("Закрой чат перед действием: cuff follow-up")
    return true
}

DoCuffFollowup(inputEpoch := 0, target := "") {
    global UserID
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (target = "")
        target := UserID
    if (inputEpoch != AutomationEpoch || "ID:" . target != "ID:" . UserID)
        return false
    steps := [{Kind: "Command", Text: "/fracid " . target, Delay: 250}
        , {Kind: "Key", Value: "1", Delay: 80}, {Kind: "Key", Value: "1", Delay: 120}
        , {Kind: "Key", Value: "4", Delay: 80}, {Kind: "Key", Value: "4", Delay: 0}]
    return GameMenu_Run("CuffFollowup", "/frac " . target, steps, 250, inputEpoch, target)
}

CanRunDejectFollowup() {
    global SafeModeEnabled, SafeBlockWhenChat
    if !EnsureGameActive()
        return false
    if !CheckID()
        return false
    if ((SafeModeEnabled = "On" || SafeBlockWhenChat = "On") && isInChat() = 1)
        return SafeWarn("Закрой чат перед RP eject")
    return true
}

SendDejectRPAfterCommand(inputEpoch := 0, target := "") {
    global RP_Deject
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || (target != "" && "ID:" . target != "ID:" . UserID))
        return false
    return SendConfigSequence(ApplyActionTemplate(RP_Deject), 700)
}

ContextAssistant_IsEnabled(actionName) {
    global AssistOOPEnabled, AssistStunEnabled, AssistChaseEnabled
    global AssistHouseEnabled, AssistDrugsEnabled, AssistPDPCuffEnabled

    if (actionName = "OOPSearch")
        return AssistOOPEnabled = "On"
    if (actionName = "Stun")
        return AssistStunEnabled = "On"
    if (actionName = "Chase")
        return AssistChaseEnabled = "On"
    if (actionName = "HouseAlarm")
        return AssistHouseEnabled = "On"
    if (actionName = "DrugsNearby")
        return AssistDrugsEnabled = "On"
    if (actionName = "PDPCuff")
        return AssistPDPCuffEnabled = "On"
    return true
}

ContextAssistant_GetMeta(actionName, ByRef title, ByRef prompt, ByRef confirmText, ByRef maxValue) {
    title := "Контекстный помощник"
    prompt := "Введите ID цели."
    confirmText := "Продолжить"
    maxValue := 999999

    if (actionName = "EnterID")
    {
        title := "ID цели"
        prompt := "Введите ID подозреваемого. Он появится в HUD и будет использоваться другими действиями."
        confirmText := "Сохранить ID"
    }
    else if (actionName = "OOPSearch")
    {
        title := "Пробив ООП"
        prompt := "Введите ID. После подтверждения будет отправлен запрос местоположения /find."
        confirmText := "Запросить"
    }
    else if (actionName = "Stun")
    {
        title := "Оглушение"
        prompt := "Введите ID, затем выберите средство: тазер или дубинка."
        confirmText := "Тазер"
    }
    else if (actionName = "Chase")
    {
        title := "Преследование"
        prompt := "Введите ID. Для обычного и расширенного ID команда будет выбрана автоматически."
        confirmText := "Начать погоню"
    }
    else if (actionName = "HouseAlarm")
    {
        title := "Сигнализация дома"
        prompt := "Введите номер дома. После подтверждения дом будет предложено отметить в GPS."
        confirmText := "Отметить дом"
        maxValue := 10000
    }
    else if (actionName = "DrugsNearby")
    {
        title := "Наркотики рядом"
        prompt := "Введите ID замеченного игрока. ID будет сохранён как текущая цель без отправки команды."
        confirmText := "Сохранить ID"
    }
    else if (actionName = "PDPCuff")
    {
        title := "Наручники после ПДП"
        prompt := "Введите ID спасённого подозреваемого. Наручники надеваются только после подтверждения."
        confirmText := "Надеть наручники"
    }
    else if (actionName = "TrainCrash")
    {
        title := "Крушение поезда"
        prompt := "Выберите место: 1 — пгт. Батырево, 2 — г. Лыткарино, 3 — завод г. Арзамас."
        confirmText := "Отправить доклад"
        maxValue := 3
    }
}

ContextAssistant_ValidateNumber(value, maxValue, ByRef normalizedValue, minValue := 0) {
    normalizedValue := Trim(value)
    if !RegExMatch(normalizedValue, "^\d+$")
        return false
    normalizedValue += 0
    if (normalizedValue < minValue || normalizedValue > maxValue)
        return false
    normalizedValue := "" . normalizedValue
    return true
}

ContextAssistant_ShowStatus(statusText) {
    global ContextAssistantStatus, hContextAssistantWnd
    ContextAssistantStatus := statusText
    if (hContextAssistantWnd)
        GuiControl, 42:, ContextAssistantStatus, %statusText%
}

ContextAssistant_Close(clearState := 1) {
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName
    global ContextAssistantStatus, ContextAssistantMode, hContextAssistantWnd, AutoTargetPendingKey
    previousCritical := A_IsCritical
    Critical, On
    try {
        AutoTargetPendingKey := ""
        SetTimer, ContextAssistantTimeoutLabel, Off
        Gui, 42:Destroy
        hContextAssistantWnd := 0
        if (clearState) {
            ContextAssistantAction := ""
            ContextAssistantInput := ""
            ContextAssistantVariant := ""
            ContextAssistantTargetName := ""
            ContextAssistantStatus := ""
            ContextAssistantMode := ""
        }
    } finally {
        Critical, %previousCritical%
    }
}

ContextAssistant_ConfirmHotkeysActive() {
    global ContextAssistantMode
    return (ContextAssistantMode = "confirm")
}

ContextAssistant_IDHotkeyContext() {
    if (PhysicalInputBusy || IsObject(GameMenuStarting) || IsObject(GameMenuLease) || ServiceUI_IsInputActive())
        return false
    if !ContextAssistant_ConfirmHotkeysActive()
        return false
    if !IsGameActive()
        return false
    return (isInChat() != 1)
}

ContextAssistant_GetOverlayPosition(width, height, ByRef outX, ByRef outY) {
    activeHwnd := WinExist("A")
    if (activeHwnd)
    {
        WinGetPos, winX, winY, winW, winH, ahk_id %activeHwnd%
        if (winW >= width && winH >= height)
        {
            outX := winX + Floor((winW - width) / 2)
            outY := winY + 72
            return true
        }
    }
    outX := Floor((A_ScreenWidth - width) / 2)
    outY := 72
    return true
}

ContextAssistant_MakeWindowPassive(hwnd) {
    if (!hwnd)
        return false

    exStyle := DllCall("GetWindowLong", "UInt", hwnd, "Int", -20, "UInt")
    DllCall("SetWindowLong", "UInt", hwnd, "Int", -20, "UInt", exStyle | 0x08000020)
    return true
}

ContextAssistant_ShowConfirmationOverlay(title, prompt, statusText) {
    global hContextAssistantWnd, UIRoundness, AutoTargetConfirmationPrompt

    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    overlayW := 310
    overlayH := 54
    ContextAssistant_GetOverlayPosition(overlayW, overlayH, overlayX, overlayY)

    Gui, 42:Destroy
    Gui, 42:+HwndhContextAssistantWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000020
    Gui, 42:Color, %panel%
    Gui, 42:Margin, 0, 0
    Gui, 42:Add, Progress, -Theme x0 y0 w4 h%overlayH% Disabled Vertical Background%panel% c%accent%, 100
    Gui, 42:Font, s8 Bold c%textColor%, Segoe UI
    Gui, 42:Add, Text, x14 y6 w286 h20 0x200 vAutoTargetConfirmationPrompt BackgroundTrans, %prompt%
    Gui, 42:Font, Norm s8 c%muted%, Segoe UI
    Gui, 42:Add, Text, x14 y29 w286 h17 vContextAssistantStatus BackgroundTrans, %statusText%
    Capture_BeforeShow("42")
    Gui, 42:Show, x%overlayX% y%overlayY% w%overlayW% h%overlayH% NoActivate, AHK FOR GOS BY SBEZRUK Notification
    ContextAssistant_MakeWindowPassive(hContextAssistantWnd)
    ApplyRoundedCorners(hContextAssistantWnd, (UIRoundness > 12) ? 12 : UIRoundness)
    return hContextAssistantWnd ? true : false
}

ContextAssistant_GetConfirmationPrompt(actionName, value, variant := "", targetName := "") {
    isMaskValue := RegExMatch(value . "", "^__MASK__:([0-9]{5,20})$", maskMatch)
    if (isMaskValue)
        targetText := "Маска " . maskMatch1
    else
        targetText := "ID " . value

    targetName := Trim(targetName)
    if (!isMaskValue && targetName != "" && targetName != "Маска")
        targetText .= " (" . targetName . ")"

    if (actionName = "HouseAlarm")
        return "Дом №" . value . " - отметить в GPS?"
    if (actionName = "OOPSearch")
        return targetText . " - отправить /find?"
    if (actionName = "Stun")
        return targetText . " - " . ((variant = "baton") ? "дубинка" : "тазер") . "?"
    if (actionName = "Chase")
        return targetText . " - начать погоню?"
    if (actionName = "DrugsNearby")
        return targetText . " - сохранить целью?"
    if (actionName = "PDPCuff")
        return targetText . " - надеть наручники?"
    return targetText . " - подставить?"
}

ContextAssistant_CloseGameChat(inputEpoch := 0) {
    global MockMode
    inputEpoch := AutomationEpoch
    if (MockMode = "On")
        return
    if (isInChat() != 1)
        return
    SafeSend("^a{Backspace}", "Input", inputEpoch)
    Sleep, 40
    SafeSend("{F6}", "Input", inputEpoch)
    Sleep, 80
}

ContextAssistant_Request(actionName, presetValue := "", presetVariant := "", targetName := "", inputEpoch := 0) {
    if (IsObject(IDCaptureState) || PhysicalInputBusy || IsObject(GameMenuStarting) || IsObject(GameMenuLease))
        return false
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName
    global ContextAssistantStatus, ContextAssistantMode, hContextAssistantWnd, UserID, MockMode, UIRoundness, TargetIsMask
    global ContextNotificationMode, ContextNotificationTimeoutSec, Bind_ConfirmID, Bind_RejectID
    inputEpoch := AutomationEpoch

    if !ContextAssistant_IsEnabled(actionName)
    {
        SafeWarn("Сценарий отключён в профиле: " . actionName)
        return false
    }

    if !EnsureGameActive()
    {
        ServiceUI_Notify("Игра не активна. Для проверки без GTA включи MockMode в настройках чата.", 2600)
        return false
    }

    title := "", prompt := "", confirmText := "", maxValue := 0
    ContextAssistant_GetMeta(actionName, title, prompt, confirmText, maxValue)
    usedCurrentTarget := false
    if (presetValue = "" && actionName != "HouseAlarm" && actionName != "TrainCrash") {
        presetValue := UserID
        usedCurrentTarget := true
    }
    if (usedCurrentTarget && TargetIsMask && RegExMatch(presetValue . "", "^[0-9]{5,20}$"))
        presetValue := "__MASK__:" . presetValue
    hasPresetValue := (presetValue != "")

    ContextAssistant_Close()
    ContextAssistantAction := actionName
    ContextAssistantInput := presetValue
    ContextAssistantVariant := presetVariant
    ContextAssistantTargetName := targetName

    if (hasPresetValue)
    {
        ContextAssistantMode := "confirm"
        prompt := ContextAssistant_GetConfirmationPrompt(actionName, presetValue, presetVariant, targetName)
        acceptKey := IsBindFieldFilled(Bind_ConfirmID) ? Bind_ConfirmID : "не задан"
        rejectKey := IsBindFieldFilled(Bind_RejectID) ? Bind_RejectID : "не задан"
        ContextAssistantStatus := acceptKey . " - Да    " . rejectKey . " - Нет"
        if (ContextNotificationMode != "Чат")
            ContextNotificationMode := "Плашка"
        NormalizeNumberRange(ContextNotificationTimeoutSec, 8, 2, 30)

        if (ContextNotificationMode = "Чат")
        {
            hContextAssistantWnd := 0
            GameNotify(prompt . "  [" . ContextAssistantStatus . "]", "INFO")
        }
        else if !ContextAssistant_ShowConfirmationOverlay(title, prompt, ContextAssistantStatus)
        {
            ContextAssistant_Close()
            return false
        }

        timeoutMs := -Abs(ContextNotificationTimeoutSec * 1000)
        SetTimer, ContextAssistantTimeoutLabel, %timeoutMs%
        return true
    }

    if GameUi_ShouldShowPassive() {
        value := ""
        try {
            if !ServiceUI_Request(title, prompt, value, 6, 30)
                return false
            if (actionName = "Stun" && presetVariant = "") {
                weapon := ""
                if !ServiceUI_Request("Выбор средства", "1 — тазер, 2 — дубинка. Введите цифру и нажмите Enter.", weapon, 1, 30)
                    return false
                if (weapon != "1" && weapon != "2")
                    return SafeWarn("Выберите 1 (тазер) или 2 (дубинка).")
                presetVariant := weapon = "2" ? "baton" : "taser"
            }
            return ContextAssistant_Execute(actionName, value, presetVariant, targetName)
        } finally {
            ContextAssistant_Close()
        }
    }
    ContextAssistant_CloseGameChat()
    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, textColor, accent)

    Gui, 42:+HwndhContextAssistantWnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox -Resize
    Gui, 42:Color, %bg%, %controlBg%
    Gui, 42:Margin, 18, 14
    Gui, 42:Font, s14 Bold c%textColor%, Segoe UI
    Gui, 42:Add, Text, x18 y14 w524 h28 BackgroundTrans, %title%

    ContextAssistantMode := "input"
    ContextAssistantStatus := "Enter - подтвердить, Esc - отменить."
    Gui, 42:Font, Norm s9 c%muted%, Segoe UI
    Gui, 42:Add, Text, x18 y50 w524 h42 BackgroundTrans, %prompt%
    Gui, 42:Font, Norm s10 c%inputText%, Segoe UI
    Gui, 42:Add, Edit, x18 y104 w524 h32 -Multi -WantReturn -VScroll -HScroll Number Limit6 vContextAssistantInput, %presetValue%
    Gui, 42:Font, Norm s9 c%muted%, Segoe UI
    Gui, 42:Add, Text, x18 y142 w524 h22 vContextAssistantStatus BackgroundTrans, %ContextAssistantStatus%
    Gui, 42:Font, Norm s10 c%textColor%, Segoe UI
    if (actionName = "Stun")
    {
        Gui, 42:Add, Button, x18 y178 w164 h34 Default gContextAssistantTaserLabel, Тазер
        Gui, 42:Add, Button, x190 y178 w164 h34 gContextAssistantBatonLabel, Дубинка
        Gui, 42:Add, Button, x378 y178 w164 h34 gContextAssistantCancelLabel, Отмена
    }
    else
    {
        Gui, 42:Add, Button, x190 y178 w164 h34 Default gContextAssistantConfirmLabel, %confirmText%
        Gui, 42:Add, Button, x378 y178 w164 h34 gContextAssistantCancelLabel, Отмена
    }
    Capture_BeforeShow("42")
    Gui, 42:Show, % "w560 h230" . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), AHK FOR GOS BY SBEZRUK - %title%
    ApplyRoundedCorners(hContextAssistantWnd, UIRoundness)
    if !GameUi_ShouldShowPassive() {
        GuiControl, 42:Focus, ContextAssistantInput
        SafeSend("^a", "Input", inputEpoch)
    }
    SetTimer, ContextAssistantTimeoutLabel, -30000
    return true
}

ContextAssistant_RestoreGame() {
    global MockMode
    if (MockMode = "On")
        return true
    return GameLocator_Activate(0.7)
}

ContextAssistant_ExpandCommand(templateText, idValue) {
    commandText := StrReplace(templateText, "{ID}", idValue)
    commandText := StrReplace(commandText, "%ID%", idValue)
    return Trim(commandText)
}

ContextAssistant_BuildCommand(actionName, idValue, variant := "") {
    global AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    if (actionName = "OOPSearch")
        return ContextAssistant_ExpandCommand(AssistOOPCommand, idValue)
    if (actionName = "Stun")
        return ContextAssistant_ExpandCommand((variant = "baton") ? AssistBatonCommand : AssistTaserCommand, idValue)
    if (actionName = "Chase")
        return "/chase " . idValue
    if (actionName = "PDPCuff")
        return "/cuff " . idValue
    return ""
}

BuildTrainCrashReport(choice) {
    if (choice = 1)
        place := "в пгт. Батырево"
    else if (choice = 2)
        place := "в г. Лыткарино"
    else if (choice = 3)
        place := "на заводе г. Арзамас"
    else
        return ""
    return ApplyTemplate("/r Докладывает: {REPORT_RANK} {SURNAME}. Крушение поезда произошло " . place . ".")
}

SuElapsedNotify(payload := "") {
    global UserID
    targetId := (payload != "") ? payload : UserID
    GameNotify("Прошло 20 секунд после корректировки розыска ID " . targetId . ".", "INFO")
    return true
}

ContextAssistant_Execute(actionName, rawValue, variant := "", targetName := "") {
    global MockMode

    rawValue := Trim(rawValue)
    isMaskValue := RegExMatch(rawValue, "^__MASK__:([0-9]{5,20})$", maskMatch)
    if (isMaskValue) {
        value := maskMatch1
        targetName := ""
    } else {
        maxValue := (actionName = "HouseAlarm") ? 10000 : ((actionName = "TrainCrash") ? 3 : 999999)
        minValue := (actionName = "HouseAlarm" || actionName = "TrainCrash") ? 1 : 0
        if !ContextAssistant_ValidateNumber(rawValue, maxValue, value, minValue)
            return false
    }

    if (actionName = "EnterID" && isMaskValue)
    {
        ShowIDGui(value, "", 1)
        GameNotify("Выбрана цель: маска " . value . ".", "INFO")
        Notify("info")
        return true
    }

    if (actionName = "HouseAlarm")
    {
        if (MockMode = "On")
        {
            MockPreview_Append("[GPS] Отметить дом №" . value . " по сигнализации")
            LogError("ContextAssistant.HouseAlarm", "Mock GPS house: " . value, "INFO")
            return true
        }
        if !ContextAssistant_RestoreGame()
            return SafeWarn("Не удалось вернуть фокус в игру для GPS.")
        return RunGpsDialogAction("Сигнализация дома", 15, value)
    }

    if (actionName = "TrainCrash")
    {
        commandText := BuildTrainCrashReport(value)
        if (commandText = "")
            return false
        if !ContextAssistant_RestoreGame()
            return SafeWarn("Не удалось вернуть фокус в игру.")
        return ChatQueue_Enqueue(commandText, "TrainCrash")
    }

    ShowIDGui(value, targetName, isMaskValue ? 1 : 0)
    if (actionName = "EnterID" || actionName = "DrugsNearby")
    {
        if (actionName = "DrugsNearby")
        {
            LogError("ContextAssistant.DrugsNearby", "Saved nearby drug-use ID: " . value, "INFO")
            if (MockMode = "On")
                MockPreview_Append("[ID] Наркотики рядом — сохранён ID " . value)
            ServiceUI_Notify("Сохранён ID " . value . " (наркотики рядом).", 1800)
        }
        if (actionName = "EnterID")
        {
            selectedText := "ID " . value
            if (targetName != "" && targetName != "Маска")
                selectedText .= " (" . targetName . ")"
            GameNotify("Выбрана цель: " . selectedText . ".", "INFO")
        }
        Notify("info")
        return true
    }

    commandText := ContextAssistant_BuildCommand(actionName, value, variant)
    if (commandText = "")
        return false

    if !ContextAssistant_RestoreGame()
        return SafeWarn("Не удалось вернуть фокус в игру.")

    requireCloseRange := (MockMode != "On" && (actionName = "Stun" || actionName = "PDPCuff"))
    if !CanRunAction(actionName, false, true, false, false, requireCloseRange)
        return false

    queued := ChatQueue_Enqueue(commandText, "ContextAssistant." . actionName)
    if (queued)
    {
        LogError("ContextAssistant", actionName . " prepared for ID " . value, "INFO")
        Notify("info")
    }
    return queued
}

ContextAssistant_Submit(variant := "") {
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName, ContextAssistantMode

    previousCritical := A_IsCritical
    Critical, On
    actionName := ContextAssistantAction
    rawValue := ContextAssistantInput
    targetName := ContextAssistantTargetName
    confirming := ContextAssistantMode = "confirm"
    if (confirming) {
        selectedVariant := (variant != "") ? variant : ContextAssistantVariant
        ContextAssistant_Close()
    }
    Critical, %previousCritical%
    if (confirming)
        return ContextAssistant_Execute(actionName, rawValue, selectedVariant, targetName)

    Gui, 42:Submit, NoHide
    rawValue := ContextAssistantInput
    maxValue := (actionName = "HouseAlarm") ? 10000 : ((actionName = "TrainCrash") ? 3 : 999999)
    minValue := (actionName = "HouseAlarm" || actionName = "TrainCrash") ? 1 : 0
    if !ContextAssistant_ValidateNumber(rawValue, maxValue, normalizedValue, minValue)
    {
        ContextAssistant_ShowStatus("Введите целое число от " . minValue . " до " . maxValue . ".")
        Notify("warn")
        GuiControl, 42:Focus, ContextAssistantInput
        return false
    }

    ContextAssistant_Close()
    return ContextAssistant_Execute(actionName, normalizedValue, variant, targetName)
}

ReadMDSFormationMinutes(inputEpoch := 0) {
    global MDSFormationMaxMinutes
    minutesText := ""
    if !ServiceUI_Request("Построение", "Время построения в минутах (1–" . MDSFormationMaxMinutes . "):", minutesText, 2, 30)
        return 0
    minutesText := Trim(minutesText)
    if !RegExMatch(minutesText, "^\d{1,2}$") {
        SafeWarn("Время построения должно быть целым числом минут.")
        return 0
    }
    minutes := minutesText + 0
    if (minutes < 1 || minutes > MDSFormationMaxMinutes) {
        SafeWarn("Допустимое время построения: от 1 до " . MDSFormationMaxMinutes . " минут.")
        return 0
    }
    return minutes
}

ReadGpsInputNumber(ByRef wasCancelled, ByRef endKey, seed := "", preparedState := "") {
    gpsNumber := ""
    ok := ServiceUI_Request("GPS", "Введите номер метки GPS и подтвердите пробелом или Enter.", gpsNumber, 5, 45, seed, true, false, preparedState)
    wasCancelled := !ok
    endKey := ok ? "gui" : ""
    return ok ? Trim(gpsNumber) : ""
}

RunGpsInputTrigger(triggerText, actionName, downCount, firstDigit) {
    global BindMenuEditMode
    if (BindMenuEditMode) {
        BindMenuWarn()
        return ""
    }
    if !IsGameActive()
        return ""
    epoch := AutomationEpoch
    reservation := GameMenu_Reserve("GPS.Input", epoch)
    if !IsObject(reservation)
        return ""
    prepared := "", wasCancelled := true
    try {
        if !ServiceUI_IsTest() {
            prepared := ServiceUI_NewInputState("GPS", "Введите номер метки GPS и подтвердите пробелом или Enter.", 5, 45
                , firstDigit, true, epoch, DllCall("GetForegroundWindow", "Ptr"), CurrentProfile, TickNow())
            hook := ServiceUI_CreateInputHook(prepared, 45)
            hook.Start()
        }
        ; Consume the remaining digits before any prefix erasure, waits or GUI work.
        if (isInChat() = 1) {
            if !EraseGpsTypedCommand(triggerText, firstDigit, "", epoch)
                return ""
            if (epoch != AutomationEpoch || !IsGameActive() || !SafeSend("{Esc}", "Event", epoch))
                return ""
        }
        gpsNumber := ReadGpsInputNumber(wasCancelled, endKey, firstDigit, prepared)
    } finally {
        ServiceUI_ReleaseInputCapture(prepared)
        GameMenu_Close(reservation)
    }
    if (!wasCancelled && epoch = AutomationEpoch && RegExMatch(gpsNumber, "^[0-9]{1,5}$"))
        RunGpsDialogAction(actionName, downCount, gpsNumber, epoch)
    return ""
}

ChatWizard_Begin(modeName, inputEpoch := 0) {
    global ChatWizardMode, ChatWizardPrompt, ChatWizardOpenedFromChat, BindMenuEditMode
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch)
        return false
    if (ChatWizardMode != "" || ServiceUI_IsInputActive()) {
        GameNotify("Уже включён режим ввода. Нажмите Esc для отмены.", "WARN")
        return false
    }
    if (BindMenuEditMode) {
        BindMenuWarn()
        return false
    }
    if (!IsGameActive() && MockMode != "On" && !AuditTestMode)
        return false
    ChatWizardOpenedFromChat := isInChat() = 1
    ChatWizardMode := modeName
    ChatWizardEpoch := inputEpoch
    ChatWizardProfile := CurrentProfile
    ChatWizardPrompt := "Введите значение и нажмите пробел или Enter."
    return true
}

ChatWizard_ReadToken(ByRef cancelled, maxLength := 40, timeoutSeconds := 90) {
    global ChatWizardMode, ChatWizardPrompt
    typedText := ""
    if (ChatWizardMode = "" || ChatWizardEpoch != AutomationEpoch || ChatWizardProfile != CurrentProfile) {
        cancelled := true
        return ""
    }
    ok := ServiceUI_Request(ChatWizardMode, ChatWizardPrompt, typedText
        , Min(80, Max(1, Round(maxLength))), Min(180, Max(10, Round(timeoutSeconds))), "", true)
    cancelled := !ok
    return ok ? Trim(typedText) : ""
}

ChatWizard_NormalizeToken(rawText) {
    text := Trim(rawText)
    while (SubStr(text, 1, 1) = "!")
        text := Trim(SubStr(text, 2))
    StringLower, text, text
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

ChatWizard_Finish(closeChat := true, inputEpoch := 0) {
    global ChatWizardMode, ChatWizardPrompt, ChatWizardOpenedFromChat
    ServiceUI_CancelInput("wizard-finish")
    if (!inputEpoch)
        inputEpoch := ChatWizardEpoch
    if (closeChat && inputEpoch = AutomationEpoch && ChatWizardOpenedFromChat && isInChat() = 1)
        SafeSend("{Esc}", "Event", inputEpoch)
    ChatWizardMode := ""
    ChatWizardPrompt := ""
    ChatWizardOpenedFromChat := false
    ChatWizardEpoch := 0
    ChatWizardProfile := ""
}

ChatWizard_Cancel(message := "") {
    if (message != "")
        GameNotify(message, "WARN")
    ChatWizard_Finish(false)
    return false
}

VehicleLookup_ResolveCountry(rawText, ByRef countryIndex, ByRef countryName) {
    token := ChatWizard_NormalizeToken(rawText)
    token := StrReplace(token, ".", "")
    token := StrReplace(token, "-", " ")
    token := RegExReplace(token, "\s+", " ")
    countryIndex := 0
    countryName := ""

    if RegExMatch(token, "^\d$", match) {
        number := match + 0
        if (number >= 1 && number <= 8)
            countryIndex := number
    } else if (token = "россия" || token = "рф" || token = "российская федерация") {
        countryIndex := 1
    } else if (token = "беларусь" || token = "республика беларусь" || token = "белоруссия") {
        countryIndex := 2
    } else if (token = "армения" || token = "республика армения") {
        countryIndex := 3
    } else if (token = "казахстан" || token = "республика казахстан") {
        countryIndex := 4
    } else if (token = "украина") {
        countryIndex := 5
    } else if (token = "азербайджан" || token = "азербайджанская республика") {
        countryIndex := 6
    } else if (token = "грузия") {
        countryIndex := 7
    } else if (token = "евросоюз" || token = "ес" || token = "европейский союз") {
        countryIndex := 8
    }

    names := ["Российская Федерация", "Республика Беларусь", "Республика Армения"
        , "Республика Казахстан", "Украина", "Азербайджанская Республика"
        , "Грузия", "Европейский союз"]
    if (countryIndex < 1 || countryIndex > names.Length())
        return false
    countryName := names[countryIndex]
    return true
}

VehicleLookup_ResolveRegion(rawText, ByRef regionIndex, ByRef regionCode) {
    token := ChatWizard_NormalizeToken(rawText)
    token := RegExReplace(token, "i)^(регион|region)\s*")
    token := Trim(token)
    regionIndex := 0
    regionCode := ""
    if !RegExMatch(token, "^(\d{1,2})$", match)
        return false
    regionIndex := match1 + 0
    if (regionIndex < 1 || regionIndex > 99)
        return false
    regionCode := Format("{:02}", regionIndex)
    return true
}

VehicleLookup_NormalizePlate(rawText) {
    plate := ChatWizard_NormalizeToken(rawText)
    plate := StrReplace(plate, " ", "")
    plate := StrReplace(plate, "-", "")
    StringUpper, plate, plate
    cyrillic := ["А", "В", "Е", "К", "М", "Н", "О", "Р", "С", "Т", "У", "Х"]
    latin := ["A", "B", "E", "K", "M", "H", "O", "P", "C", "T", "Y", "X"]
    Loop % cyrillic.Length()
        plate := StrReplace(plate, cyrillic[A_Index], latin[A_Index])
    return plate
}

VehicleLookup_GetRegionListPosition(countryIndex, regionIndex) {
    countryIndex += 0
    regionIndex += 0
    if (countryIndex = 1) {
        if (regionIndex = 20)
            return 0
        if (regionIndex > 20)
            return regionIndex - 1
    }
    return regionIndex
}

VehicleLookup_RunWizard() {
    wizardEpoch := AutomationEpoch
    if !ChatWizard_Begin("поиск ТС", wizardEpoch)
        return false

    GameNotify("Поиск ТС включён. Введите страну, например !россия, и нажмите пробел.", "INFO")
    Loop
    {
        rawCountry := ChatWizard_ReadToken(cancelled, 32, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        if VehicleLookup_ResolveCountry(rawCountry, countryIndex, countryName)
            break
        GameNotify("Страна не распознана. Пример: !россия, !беларусь или !1.", "WARN")
    }
    GameNotify("Выбрана страна: " . countryName . ". Введите код региона, например !05.", "INFO")

    Loop
    {
        rawRegion := ChatWizard_ReadToken(cancelled, 12, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        if (VehicleLookup_ResolveRegion(rawRegion, regionIndex, regionCode)
            && VehicleLookup_GetRegionListPosition(countryIndex, regionIndex) > 0)
            break
        if (countryIndex = 1 && regionIndex = 20) {
            GameNotify("Код региона 20 отсутствует в списке РФ. Укажите действующий код.", "WARN")
            continue
        }
        GameNotify("Регион не распознан. Введите номер позиции, например !05.", "WARN")
    }
    GameNotify("Выбран регион: " . regionCode . ". Введите номер ТС в формате A123AA.", "INFO")

    EnsureEnglishLayout()
    Loop
    {
        rawPlate := ChatWizard_ReadToken(cancelled, 16, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        plate := VehicleLookup_NormalizePlate(rawPlate)
        if RegExMatch(plate, "^[A-Z]\d{3}[A-Z]{2}$")
            break
        GameNotify("Неверный номер. Используйте формат A123AA без кода региона.", "WARN")
    }

    GameNotify("Поиск: " . countryName . ", регион " . regionCode . ", номер " . plate . ".", "INFO")
    ChatWizard_Finish(true, wizardEpoch)
    return VehicleLookup_Execute(countryIndex, regionIndex, plate, wizardEpoch)
}

VehicleLookup_Execute(countryIndex, regionIndex, plate, inputEpoch := 0) {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !CanRunAction("поиск ТС по номеру", false, true))
        return false
    regionListPosition := VehicleLookup_GetRegionListPosition(countryIndex, regionIndex)
    if (regionListPosition < 1)
        return SafeWarn("Выбранный регион отсутствует в игровом списке.")
    steps := [{Kind: "Radial", Value: 1, Delay: 280, Gap: 0}, {Kind: "Radial", Value: 3, Delay: 280, Gap: 0}
        , {Kind: "Radial", Value: 6, Delay: 320, Gap: 0}, {Kind: "Select", Value: countryIndex, Gap: 45, Delay: 250}
        , {Kind: "Select", Value: regionListPosition, Gap: 35, Delay: 280}
        , {Kind: "Paste", Value: plate, Delay: 80}, {Kind: "Key", Value: "Enter", Delay: 80}
        , {Kind: "Layout", Value: 0x4190419}]
    return GameMenu_Run("VehicleLookup", "/frac", steps, 320, inputEpoch)
}

WantedRemoval_GetReason(reasonNumber, ByRef reasonText) {
    reasons := {}
    reasons[1] := "ошибка КПК"
    reasons[2] := "явка с повинной"
    reasons[3] := "самооборона"
    reasons[4] := "менее 5 лет проживания в области"
    reasons[5] := "признание вины, незначительное нарушение"
    reasonNumber += 0
    if !reasons.HasKey(reasonNumber)
        return false
    reasonText := reasons[reasonNumber]
    return true
}

WantedRemoval_GetDepartmentTag() {
    global ProfileMode
    if (ProfileMode = "ГАИ" || ProfileMode = "ДПС")
        return "ГАИ"
    if (ProfileMode = "ФСБ")
        return "УФСБ"
    if (ProfileMode = "ВЧ" || ProfileMode = "Военная полиция")
        return "ВЧ"
    return "УМВД"
}

WantedRemoval_RunWizard() {
    wizardEpoch := AutomationEpoch
    if !ChatWizard_Begin("снятие розыска", wizardEpoch)
        return false

    GameNotify("Снятие розыска включено. Введите жетон игрока, например !321, и нажмите пробел.", "INFO")
    Loop
    {
        rawTarget := ChatWizard_ReadToken(cancelled, 16, 120)
        if (cancelled)
            return ChatWizard_Cancel("Снятие розыска отменено.")
        targetToken := ChatWizard_NormalizeToken(rawTarget)
        targetToken := RegExReplace(targetToken, "i)^id")
        if RegExMatch(targetToken, "^(\d{1,4})$", targetMatch) {
            targetId := targetMatch1 + 0
            break
        }
        GameNotify("Жетон не распознан. Введите, например, !321.", "WARN")
    }

    GameNotify("Основания: !1 ошибка КПК; !2 явка с повинной; !3 самооборона; !4 менее 5 лет; !5 признание вины.", "INFO")
    Loop
    {
        rawReason := ChatWizard_ReadToken(cancelled, 8, 120)
        if (cancelled)
            return ChatWizard_Cancel("Снятие розыска отменено.")
        reasonToken := ChatWizard_NormalizeToken(rawReason)
        if (RegExMatch(reasonToken, "^[1-5]$") && WantedRemoval_GetReason(reasonToken + 0, reasonText)) {
            reasonNumber := reasonToken + 0
            break
        }
        GameNotify("Выберите основание от !1 до !5.", "WARN")
    }

    GameNotify("Выбрано: жетон " . targetId . ", п." . reasonNumber . " — " . reasonText . ".", "INFO")
    ChatWizard_Finish(true, wizardEpoch)
    return WantedRemoval_Execute(targetId, reasonNumber, wizardEpoch)
}

WantedRemoval_Execute(targetId, reasonNumber, inputEpoch := 0) {
    global ReportRank, Surname
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !CanRunAction("снятие розыска", false, true))
        return false
    departmentTag := WantedRemoval_GetDepartmentTag()
    report := "/d [" . departmentTag . "] Говорит " . ReportRank . " полиции " . Surname
        . ",выношу из базы розыска жетон " . targetId
        . ",на основании ФЗоП гл.3 ст.7 ч.1 п." . reasonNumber
    steps := [{Kind: "Command", Text: "/frac", Delay: 320}
        , {Kind: "Radial", Value: 1, Delay: 280, Gap: 0}, {Kind: "Radial", Value: 4, Delay: 280, Gap: 0}
        , {Kind: "Radial", Value: 2, Delay: 320, Gap: 0}, {Kind: "Digits", Value: targetId . "", Delay: 80}
        , {Kind: "Key", Value: "Enter", Delay: 0}]
    return GameMenu_Run("WantedRemoval", report, steps, 700, inputEpoch)
}

Fine_ParseArticle(rawText, ByRef article, ByRef chapterPosition, ByRef itemPosition, ByRef errorText) {
    text := ChatWizard_NormalizeToken(rawText)
    text := StrReplace(text, "коап", "")
    text := RegExReplace(text, "i)^(статья|ст\.?)\s*")
    text := StrReplace(text, " ", "")
    article := ""
    chapterPosition := 0
    itemPosition := 0
    errorText := ""

    if !RegExMatch(text, "^(\d{1,2})\.(\d{1,2})$", match) {
        errorText := "Введите статью КоАП с точкой, например !20.6."
        return false
    }
    chapter := match1 + 0
    item := match2 + 0
    counts := {1:2, 2:3, 3:4, 5:2, 6:1, 7:2, 8:5, 9:4, 10:3, 11:4
        , 12:2, 13:6, 14:5, 15:3, 16:4, 17:5, 18:6, 19:2, 20:7, 21:2}

    if (chapter = 2 && (item = 4 || item = 5)) {
        errorText := "Статьи 2.4 и 2.5 КоАП упразднены."
        return false
    }
    if (chapter = 4) {
        errorText := "Статьи главы 4 КоАП упразднены."
        return false
    }
    if !counts.HasKey(chapter) {
        errorText := "Такая глава не используется для выписывания штрафа."
        return false
    }
    if (item < 1 || item > counts[chapter]) {
        errorText := "Статья " . chapter . "." . item . " отсутствует в выбранной главе КоАП."
        return false
    }

    article := chapter . "." . item
    chapterPosition := chapter
    itemPosition := item
    return true
}

Fine_RunWizard() {
    wizardEpoch := AutomationEpoch
    if !ChatWizard_Begin("выбор статьи КоАП", wizardEpoch)
        return false
    GameNotify("Режим штрафа включён. Введите статью КоАП, например !20.6, и нажмите пробел.", "INFO")
    Loop
    {
        rawArticle := ChatWizard_ReadToken(cancelled, 24, 120)
        if (cancelled)
            return ChatWizard_Cancel("Оформление штрафа отменено.")
        if Fine_ParseArticle(rawArticle, article, chapterPosition, itemPosition, parseError)
            break
        GameNotify(parseError, "WARN")
    }
    GameNotify("КоАП ст. " . article . ": глава " . chapterPosition . ", позиция " . itemPosition . ".", "INFO")
    ChatWizard_Finish(true, wizardEpoch)
    return Fine_ExecuteArticle(article, chapterPosition, itemPosition, wizardEpoch)
}

Fine_ExecuteArticle(article, chapterPosition, itemPosition, inputEpoch := 0) {
    global RP_Fine, UserID
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !CanRunAction("штраф КоАП " . article, true))
        return false
    target := UserID
    Evidence_Arm("FINE", 60000)
    SplitConfigSequenceMiddle(RP_Fine, rpBefore, rpAfter)
    rpBefore := ApplyActionTemplate(rpBefore), rpAfter := ApplyActionTemplate(rpAfter)
    if (rpBefore != "") {
        if (!SendConfigSequence(rpBefore, 700, batch) || !QueueBatch_Wait(batch, 20000))
            return false
        Sleep, 900
    }
    if (inputEpoch != AutomationEpoch || "ID:" . target != "ID:" . UserID)
        return false
    steps := [{Kind: "Radial", Value: 1, Delay: 480, Gap: 110}, {Kind: "Radial", Value: 6, Delay: 480, Gap: 110}
        , {Kind: "Radial", Value: 1, Delay: 550, Gap: 110}, {Kind: "Key", Value: "Enter", Delay: 450}
        , {Kind: "Select", Value: chapterPosition, Gap: 45, Delay: 350}, {Kind: "Select", Value: itemPosition, Gap: 45, Delay: 450}]
    if !GameMenu_Run("Fine.OpenMenu", "/frac " . target, steps, 800, inputEpoch, target)
        return false
    if (inputEpoch != AutomationEpoch)
        return false
    return rpAfter = "" || SendConfigSequence(rpAfter, 700)
}

MatchGpsEnterCommand(lineText, triggerText, ByRef gpsNumber) {
    lineText := Trim(lineText)
    triggerText := Trim(triggerText)
    gpsNumber := ""

    if (triggerText = "" || triggerText = "ERROR")
        return false

    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText

    if (SubStr(lineText, 1, StrLen(triggerText)) != triggerText)
        return false

    tailText := Trim(SubStr(lineText, StrLen(triggerText) + 1))
    if (tailText = "")
        return false

    if !RegExMatch(tailText, "^(\d+)$", m)
        return false

    gpsNumber := m1
    return true
}

TryHandleGpsEnterCommand(inputEpoch := 0) {
    global Trig_GpsD, Trig_GpsOS
    inputEpoch := AutomationEpoch

    if !IsGameActive()
        return false

    if (isInChat() != 1)
        return false

    lineText := GetActiveChatText()
    if (lineText = "")
        return false

    gpsNumber := ""
    actionName := ""
    downCount := 0

    if MatchGpsEnterCommand(lineText, Trig_GpsD, gpsNumber)
    {
        actionName := "GPS Д"
        downCount := 15
    }
    else if MatchGpsEnterCommand(lineText, Trig_GpsOS, gpsNumber)
    {
        actionName := "GPS ОБ"
        downCount := 16
    }
    else
        return false

    SafeSend("^a{Backspace}", "Input", inputEpoch)
    Sleep, 40
    SafeSend("{Enter}", "Input", inputEpoch)
    Sleep, 80
    return RunGpsDialogAction(actionName, downCount, gpsNumber)
}

SendGpsDialogDown(count, delayMs := 35, inputEpoch := 0) {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !RegExMatch(count . "", "^[0-9]+$") || count > 80)
        return false
    Loop %count% {
        if !SafeSend("{Down}", "Event", inputEpoch)
            return false
        Sleep, %delayMs%
    }
    return inputEpoch = AutomationEpoch
}

RunGpsDialogAction(actionName, downCount, gpsNumber, inputEpoch := 0) {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch)
        return false
    gpsNumber := Trim(gpsNumber)
    if (!RegExMatch(gpsNumber, "^[0-9]{1,5}$") || gpsNumber + 0 < 1 || gpsNumber + 0 > 10000
        || !RegExMatch(downCount . "", "^[0-9]+$") || downCount > 80) {
        Notify("warn")
        return false
    }
    if !CanRunAction(actionName, false, false)
        return false
    reservation := GameMenu_Reserve("GPS", inputEpoch)
    if !IsObject(reservation)
        return SafeWarn("GPS: ввод занят другим действием.")
    ok := false, stage := "закрытие чата"
    try {
        if !GameMenu_Prepare(reservation)
            return false
        stage := "открытие /gps"
        ; Amazing GPS is driven by keys; do not inspect SA-MP dialog memory.
        ; Keep a cancellable opening pause before navigation.
        lease := GameMenu_SendCommand(reservation, "/gps", 500, false)
        if !IsObject(lease)
            return false
        ; GPS alone uses shorter key presses; other game menus keep 30/50 ms.
        lease.KeyDelay := 10, lease.KeyDuration := 20
        stage := "выбор пункта"
        if !GameMenu_Tap(lease, "Home")
            return false
        Loop %downCount%
            if !GameMenu_Tap(lease, "Down")
                return false
        stage := "открытие поля номера"
        if (!GameMenu_Tap(lease, "Enter") || !GameMenu_Wait(lease, 200))
            return false
        stage := "ввод номера"
        if (!GameMenu_TypeDigits(lease, gpsNumber) || !GameMenu_Wait(lease, 50))
            return false
        stage := "подтверждение"
        ok := GameMenu_Tap(lease, "Enter")
        return ok
    } finally {
        GameMenu_Close(reservation)
        if (!ok) {
            LogError("GPS", "Остановлено: " . stage . "; поколение " . inputEpoch . ". Повтор /gps не выполнялся.", "WARN")
            if (inputEpoch = AutomationEpoch)
                ServiceUI_Notify("GPS остановлен: " . stage . ". Проверьте активное окно игры.", 3500, "WARN")
        }
    }
}

InputAction_DoEnterID(inputEpoch := 0) {
    global
    if IsObject(IDCaptureState)
        return IDCapture_Complete("confirm")
    if !CanRunAction("ввод ID", false, false)
        return false
    NormalizeIDEntryMode(IDEntryMode)
    if (IDEntryMode = "Перехват цифр")
        return IDCapture_Start()
    idText := ""
    if !ServiceUI_Request("ID игрока", "Введите ID игрока и нажмите Enter.", idText, 20, 45)
        return false
    if !RegExMatch(idText, "^\d{1,20}$")
        return SafeWarn("ID должен содержать только цифры.")
    ShowIDGui(idText)
    return true
}

Action_DoInCar() {
    global RP_InCar, UserID
    if !CanRunAction("incar", true, true, true)
        return false
    return QueueRpAction(RP_InCar, "/incar " . UserID, "DoInCar", [])
}

Action_DoDoc() {
    global RP_Doc, UserID
    if !CanRunAction("документы", true)
        return false
    return QueueRpAction(RP_Doc, "/doc " . UserID, "DoDoc", [])
}

Action_DoSearch() {
    global RP_Search, UserID
    if !CanRunAction("досмотр", true, true, false, false, true)
        return false
    Evidence_Arm("SEARCH_PERSON", 60000)
    return QueueRpAction(RP_Search, "/frac " . UserID, "DoSearch", [1, 5, 1])
}

InputAction_DoSOS(inputEpoch := 0) {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !CanRunAction("SOS", false, true))
        return false
    return GameMenu_Run("SOS", "/sos", [{Kind: "Key", Value: "Down", Delay: 300}
        , {Kind: "Key", Value: "Enter", Delay: 0}], 300, inputEpoch)
}

InputAction_DoWantedList(inputEpoch := 0) {
    global StopTimerActive, StopTimerCounter
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch || !CanRunAction("Розыскиваемые", false, true))
        return false
    steps := []
    Loop, 8
        steps.Push({Kind: "Key", Value: "1", Delay: 50})
    if (!GameMenu_Run("WantedList", "/frac", steps, 300, inputEpoch) || inputEpoch != AutomationEpoch)
        return false
    StopTimerActive := 1
    StopTimerCounter := 60
    ShowStopTimerGUI()
    return true
}

Action_DoArrest() {
    global RP_Arrest, UserID
    if !CanRunAction("арест", true)
        return false
    Evidence_Arm("ARREST", 60000)
    return QueueRpAction(RP_Arrest, "/frac " . UserID, "DoArrest", [1, 5, 8])
}

ReadAutoReportMinutes(mode, inputEpoch := 0) {
    minutesText := ""
    if !ServiceUI_Request("Автодоклад: " . mode, "Продолжительность: от 10 до 600 минут.", minutesText, 3, 30)
        return 0
    minutesText := Trim(minutesText)
    if !AutoReport_IsValidDuration(minutesText) {
        SafeWarn("Допустимое время автодоклада: целое число от 10 до 600 минут.")
        return 0
    }
    return minutesText + 0
}

QueueNamedAction(lines, source, onFirstSent := "") {
    id := ChatQueue_EnqueueBatch(lines, source, 700, "", onFirstSent)
    if (!id)
        SafeWarn("Действие не поставлено в очередь: " . source . ". Очередь заполнена или действие отменено.")
    return id
}

Action_StartStopTimer(batch) {
    global StopTimerActive, StopTimerCounter
    if (batch.Epoch != AutomationEpoch || (batch.State != "queued" && batch.State != "sent"))
        return false
    StopTimerActive := 1
    StopTimerCounter := 15
    ShowStopTimerGUI()
    return true
}

Action_SuReminderAfterSent(target, batch) {
    if (batch.Epoch != AutomationEpoch || (batch.State != "queued" && batch.State != "sent"))
        return false
    return TaskScheduler_Set("SuReminder", 20000, "SuElapsedNotify", "Напоминание /su", target)
}

Action_DoCuff() {
    global LastCuffActionTick, LastCuffActionTarget, LastCuffActionEpoch, CuffFollowupWindowMs, UserID
    epoch := AutomationEpoch, target := UserID, now := TickNow()
    followup := LastCuffActionTick > 0 && now - LastCuffActionTick <= CuffFollowupWindowMs
        && LastCuffActionEpoch = epoch && "ID:" . LastCuffActionTarget = "ID:" . target
    LastCuffActionTick := 0
    if (followup)
        return CanRunCuffFollowup() && DoCuffFollowup(epoch, target)
    if !CanRunAction("cuff", true, true)
        return false
    target := UserID
    if (SendChatForEpoch(epoch, "/cuff " . target) != 1)
        return false
    if (epoch = AutomationEpoch) {
        LastCuffActionTarget := target, LastCuffActionEpoch := epoch
        LastCuffActionTick := TickNow()
    }
    Sleep, 1200
    return true
}

Action_DoDeject() {
    global LastDejectActionTick, LastDejectActionTarget, LastDejectActionEpoch, DejectFollowupWindowMs, UserID
    epoch := AutomationEpoch, target := UserID, now := TickNow()
    followup := LastDejectActionTick > 0 && now - LastDejectActionTick <= DejectFollowupWindowMs
        && LastDejectActionEpoch = epoch && "ID:" . LastDejectActionTarget = "ID:" . target
    LastDejectActionTick := 0
    if (followup)
        return CanRunDejectFollowup() && SendDejectRPAfterCommand(epoch, target)
    if !CanRunAction("deject", true, true, true)
        return false
    target := UserID
    if (SendChatForEpoch(epoch, (target < 1000 ? "/deject " : "/dejectid ") . target) != 1)
        return false
    if (epoch = AutomationEpoch) {
        LastDejectActionTarget := target, LastDejectActionEpoch := epoch
        LastDejectActionTick := TickNow()
    }
    Sleep, 500
    return true
}

Action_DoTowStart() {
    global RP_TowStart
    epoch := AutomationEpoch
    if !CanRunAction("эвакуация старт", false, true, true)
        return false
    Evidence_Arm("EVAC_START", 60000)
    towTemplate := TowStart_EnsureTowLast(RP_TowStart)
    if SplitConfigReportLine(towTemplate, reportLine, towSequence) {
        if (SendChatForEpoch(epoch, ApplyActionTemplate(reportLine), "TowStartReport") != 1)
            return false
        Sleep, 500
    } else
        towSequence := towTemplate
    if (epoch != AutomationEpoch || !SendConfigSequence(TowStart_EnsureTowLast(towSequence), 700, batch) || !QueueBatch_Wait(batch, 25000))
        return false
    return epoch = AutomationEpoch && ActionTimer_StartEvacuation()
}

Action_DoTowEnd() {
    global RP_TowEnd
    epoch := AutomationEpoch
    if !CanRunAction("эвакуация конец", false, true, true)
        return false
    Evidence_Arm("EVAC_END", 90000)
    if (!SendConfigSequence(RP_TowEnd, 700, batch) || !QueueBatch_Wait(batch, 20000))
        return false
    if (epoch != AutomationEpoch)
        return false
    ActionTimer_Stop("Evac")
    Sleep, 650
    return GameMenu_Run("TowEnd", "/frac", [{Kind: "Radial", Value: 1, Gap: 0, Delay: 280}
        , {Kind: "Radial", Value: 4, Gap: 0, Delay: 280}, {Kind: "Radial", Value: 5, Gap: 0, Delay: 320}], 320, epoch)
}

Action_DoCarSearch() {
    global RP_CarSearch
    epoch := AutomationEpoch
    if !CanRunAction("осмотр ТС", false, true)
        return false
    if (!SendConfigSequence(RP_CarSearch, 700, batch) || !QueueBatch_Wait(batch, 20000) || epoch != AutomationEpoch)
        return false
    Evidence_Arm("SEARCH_TRUNK", 45000)
    return GameMenu_Run("CarSearch", "/frac", [{Kind: "Radial", Value: 1, Gap: 0, Delay: 280}
        , {Kind: "Radial", Value: 4, Gap: 0, Delay: 280}, {Kind: "Radial", Value: 1, Gap: 0, Delay: 320}], 320, epoch)
}

Action_DoRights() {
    global RP_Rights
    if !CanRunAction("права", false, true, false, false, true)
        return false
    count := SendConfigSequence(RP_Rights, 1000, batch, "", "Rights")
    if (!count)
        return SafeWarn("Права: текст пуст или очередь заполнена.")
    return count
}
