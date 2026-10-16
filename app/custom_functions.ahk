; custom functions subsystem. Definitions only; initialization is in bootstrap.

NormalizeCustomFunctionTrigger(value) {
    value := Trim(value)
    if (value = "" || value = "ERROR")
        return ""
    if (SubStr(value, 1, 1) != "!")
        value := "!" . value
    StringLower, value, value
    return value
}

NormalizeCustomFunctionName(value, fallback := "Новая функция") {
    value := Trim(value)
    value := StrReplace(value, "|", "/")
    value := RegExReplace(value, "[\r\n\t]+", " ")
    if (value = "")
        value := fallback
    if (StrLen(value) > 60)
        value := SubStr(value, 1, 60)
    return value
}

CreateDefaultCustomFunction() {
    return {Name: "Пример: RP с паузой", Hotkey: "", Trigger: "", Script: "SEND /me начал выполнять действие.`nWAIT 1000`nSEND /do Действие продолжается.`nTIMER 15|Контроль времени`nNOTICE Пользовательская функция запущена."}
}

LoadCustomFunctions() {
    global CustomFunctionsFile, CustomFunctions, CustomFunctionMaxCount
    CustomFunctions := []
    IniRead, count, %CustomFunctionsFile%, General, Count, 0
    NormalizeNumberRange(count, 0, 0, CustomFunctionMaxCount)
    Loop % count
    {
        section := "Function" . A_Index
        name := IniReadText(CustomFunctionsFile, section, "Name", "Функция " . A_Index)
        IniRead, hotkeyValue, %CustomFunctionsFile%, %section%, Hotkey,
        triggerValue := IniReadText(CustomFunctionsFile, section, "Trigger", "")
        scriptValue := IniReadText(CustomFunctionsFile, section, "Script", "")
        name := NormalizeCustomFunctionName(name, "Функция " . A_Index)
        triggerValue := NormalizeCustomFunctionTrigger(triggerValue)
        CustomFunctions.Push({Name: name, Hotkey: Trim(hotkeyValue), Trigger: triggerValue, Script: scriptValue})
    }
    if (CustomFunctions.Length() = 0)
        CustomFunctions.Push(CreateDefaultCustomFunction())
}

SaveCustomFunctions() {
    global CustomFunctionsFile, CustomFunctions
    stage := ConfigStage(CustomFunctionsFile)
    if (stage = "")
        return false
    count := IsObject(CustomFunctions) ? CustomFunctions.Length() : 0
    CheckedIniWrite(count, stage, "General", "Count")
    Loop % count {
        item := CustomFunctions[A_Index]
        section := "Function" . A_Index
        IniWriteText(item.Name, stage, section, "Name")
        CheckedIniWrite(item.Hotkey, stage, section, "Hotkey")
        IniWriteText(item.Trigger, stage, section, "Trigger")
        IniWriteText(item.Script, stage, section, "Script")
    }
    return ConfigCommit(stage, CustomFunctionsFile)
}

CustomFunction_HotkeyAllowed() {
    global GameProcessName, CustomFunctionGuiVisible, BindMenuEditMode
    if (CustomFunctionGuiVisible || BindMenuEditMode)
        return false
    if !WinActive("ahk_exe " . GameProcessName)
        return false
    return (isInChat() != 1)
}

ClearCustomFunctionHotkeys() {
    global CustomFunctionRegisteredHotkeys, CustomFunctionHotkeyMap, CustomFunctionHotkeyContext
    if IsObject(CustomFunctionRegisteredHotkeys)
    {
        Hotkey, If, % CustomFunctionHotkeyContext
        Loop % CustomFunctionRegisteredHotkeys.Length()
        {
            hk := CustomFunctionRegisteredHotkeys[A_Index]
            if (hk != "")
                Hotkey, %hk%, DispatchCustomFunctionHotkey, Off UseErrorLevel
        }
        Hotkey, If
    }
    CustomFunctionRegisteredHotkeys := []
    CustomFunctionHotkeyMap := {}
}

ApplyCustomFunctionHotkeys(ByRef ok, ByRef errText, ByRef usedKeys) {
    global CustomFunctions, CustomFunctionRegisteredHotkeys, CustomFunctionHotkeyMap, CustomFunctionHotkeyContext
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        hk := Trim(fn.Hotkey)
        if (hk = "" || hk = "ERROR")
            continue
        keyId := NormalizeHotkeyId(hk)
        if (keyId = "")
            continue
        owner := "Пользовательская функция «" . fn.Name . "»"
        if (usedKeys.HasKey(keyId))
        {
            errText .= owner . " = " . hk . "  -> дубликат с """ . usedKeys[keyId] . """`n"
            ok := 0
            continue
        }
        Hotkey, If, % CustomFunctionHotkeyContext
        Hotkey, %hk%, DispatchCustomFunctionHotkey, On UseErrorLevel
        registerError := ErrorLevel
        Hotkey, If
        if (registerError)
        {
            errText .= owner . " = " . hk . "  -> неверный hotkey`n"
            ok := 0
            continue
        }
        usedKeys[keyId] := owner
        CustomFunctionHotkeyMap[keyId] := A_Index
        CustomFunctionRegisteredHotkeys.Push(hk)
    }
}

ApplyCustomFunctionTextTriggers(ByRef ok, ByRef errText, ByRef usedTriggers) {
    global CustomFunctions
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        trig := NormalizeCustomFunctionTrigger(fn.Trigger)
        if (trig = "")
            continue
        keyId := trig
        StringLower, keyId, keyId
        owner := "Пользовательская функция «" . fn.Name . "»"
        if (usedTriggers.HasKey(keyId))
        {
            errText .= owner . " = " . trig . "  -> дубликат с """ . usedTriggers[keyId] . """`n"
            ok := 0
            continue
        }
        try
        {
            cb := Func("RunCustomFunctionTrigger").Bind(A_Index)
            Hotstring(":?:" . trig, cb, "On")
            TrackRegisteredGameTextHotstring(":?:" . trig)
            usedTriggers[keyId] := owner
        }
        catch e
        {
            errText .= owner . " = " . trig . "  -> неверный TXT-триггер`n"
            ok := 0
        }
    }
}

RunCustomFunctionTrigger(index) {
    RunCustomFunction(index)
    return ""
}

CustomFunction_Parse(scriptText, ByRef errorText) {
    steps := []
    errorText := ""
    scriptText := StrReplace(scriptText, "`r`n", "`n")
    scriptText := StrReplace(scriptText, "`r", "`n")
    lineNo := 0
    Loop, Parse, scriptText, `n
    {
        lineNo += 1
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "i)^WAIT\s+(\d+)$", m)
        {
            waitMs := m1 + 0
            NormalizeNumberRange(waitMs, 1000, 0, 300000)
            steps.Push({Type: "WAIT", Value: waitMs})
        }
        else if RegExMatch(line, "i)^TIMER\s+(\d+)(?:\|(.*))?$", m)
        {
            seconds := m1 + 0
            NormalizeNumberRange(seconds, 15, 1, 3600)
            label := Trim(m2)
            steps.Push({Type: "TIMER", Value: seconds, Label: label})
        }
        else if RegExMatch(line, "i)^NOTICE\s+(.+)$", m)
            steps.Push({Type: "NOTICE", Value: m1})
        else if RegExMatch(line, "i)^(?:TYPE|OPEN)\s+(.+)$", m)
            steps.Push({Type: "TYPE", Value: m1})
        else if RegExMatch(line, "i)^(?:SEND|CHAT)\s+(.+)$", m)
            steps.Push({Type: "SEND", Value: m1})
        else if RegExMatch(line, "i)^STOP$", m)
            steps.Push({Type: "STOP", Value: ""})
        else if RegExMatch(line, "i)^[A-Z_]+(?:\s|$)")
        {
            errorText := "Строка " . lineNo . ": неизвестная команда."
            return []
        }
        else
            steps.Push({Type: "SEND", Value: line})
        if (steps.Length() > 120)
        {
            errorText := "Слишком много шагов. Максимум: 120."
            return []
        }
    }
    if (steps.Length() = 0)
        errorText := "Функция не содержит выполняемых шагов."
    return steps
}

RunCustomFunction(index) {
    global CustomFunctions, CustomFunctionRunState
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return false
    if IsObject(CustomFunctionRunState)
    {
        GameNotify("Уже выполняется функция «" . CustomFunctionRunState.Name . "». Останови её в конструкторе.", "WARN")
        return false
    }
    fn := CustomFunctions[index]
    errorText := ""
    steps := CustomFunction_Parse(fn.Script, errorText)
    if (errorText != "")
    {
        GameNotify("Ошибка функции «" . fn.Name . "»: " . errorText, "ERROR")
        return false
    }
    CustomFunctionRunState := {Name: fn.Name, Steps: steps, Index: 1, NextTick: TickNow(), WaitingForQueue: 0, Epoch: AutomationEpoch, Profile: CurrentProfile, Target: UserID, Failures: QueueFailureGeneration}
    SetTimer, CustomFunctionRunnerTick, 60
    GameNotify("Запущена функция: " . fn.Name)
    return true
}

StopCustomFunctionRun(showNotice := 1) {
    global CustomFunctionRunState
    SetTimer, CustomFunctionRunnerTick, Off
    wasActive := IsObject(CustomFunctionRunState)
    CustomFunctionRunState := ""
    if (showNotice && wasActive)
        GameNotify("Пользовательская функция остановлена.", "WARN")
}

CustomFunction_InputIsCurrent(state) {
    global CustomFunctionRunState, AutomationEpoch, CurrentProfile, UserID, QueueFailureGeneration
    return IsObject(state) && IsObject(CustomFunctionRunState) && CustomFunctionRunState == state
        && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile && state.Target = UserID
        && state.Failures = QueueFailureGeneration
}

CustomFunction_StopIfCurrent(state) {
    global CustomFunctionRunState
    if (IsObject(CustomFunctionRunState) && CustomFunctionRunState == state)
        StopCustomFunctionRun(0)
}

CustomFunctionRunner_Process(inputEpoch := 0) {
    global CustomFunctionRunState, ChatQueueBusy, StopTimerActive, StopTimerCounter, StopTimerLabel
    inputEpoch := AutomationEpoch
    if !IsObject(CustomFunctionRunState)
    {
        SetTimer, CustomFunctionRunnerTick, Off
        return
    }
    state := CustomFunctionRunState
    if (state.Epoch != AutomationEpoch || state.Failures != QueueFailureGeneration || state.Profile != CurrentProfile || state.Target != UserID) {
        StopCustomFunctionRun(0)
        return
    }
    if (PhysicalInputBusy || IsObject(IDCaptureState))
        return
    if (state.NextTick > TickNow())
        return
    if (state.WaitingForQueue)
    {
        if (ChatQueue_Count() > 0 || ChatQueueBusy)
            return
        state.WaitingForQueue := 0
    }
    Loop, 20
    {
        if !CustomFunction_InputIsCurrent(state) {
            CustomFunction_StopIfCurrent(state)
            return
        }
        if (state.Index > state.Steps.Length())
        {
            completedName := state.Name
            StopCustomFunctionRun(0)
            GameNotify("Функция завершена: " . completedName)
            return
        }
        step := state.Steps[state.Index]
        state.Index += 1
        if (step.Type = "WAIT")
        {
            state.NextTick := TickNow() + step.Value
            return
        }
        if (step.Type = "SEND")
        {
            if (ChatQueue_Count() > 0 || ChatQueueBusy)
            {
                state.Index -= 1
                return
            }
            text := ApplyActionTemplate(step.Value)
            if (ChatQueue_Enqueue(text, "CustomFunction." . state.Name, 0, 0, 1)) {
                state.WaitingForQueue := 1
            } else {
                state.Index -= 1
                state.NextTick := TickNow() + 1000
                LogError("CustomFunction", "Очередь отклонила строку функции «" . state.Name . "».", "WARN")
            }
            return
        }
        if (step.Type = "NOTICE")
        {
            GameNotify(ApplyActionTemplate(step.Value))
            continue
        }
        if (step.Type = "TIMER")
        {
            StopTimerActive := 1
            StopTimerCounter := step.Value
            StopTimerLabel := ApplyActionTemplate(step.Label)
            ShowStopTimerGUI()
            if (StopTimerLabel != "")
                GameNotify(StopTimerLabel . ": " . step.Value . " сек.")
            continue
        }
        if (step.Type = "TYPE")
        {
            if (MockMode = "On" || AuditTestMode) {
                MockPreview_Append("[TYPE] " . ApplyActionTemplate(step.Value))
                continue
            }
            if !EnsureGameActive()
            {
                state.Index -= 1
                return
            }
            if !CustomFunction_InputIsCurrent(state) {
                CustomFunction_StopIfCurrent(state)
                return
            }
            if (PhysicalInputBusy || IsObject(IDCaptureState)) {
                state.Index -= 1
                return
            }
            if !TypeChatForEpoch(inputEpoch, ApplyActionTemplate(step.Value), Func("CustomFunction_InputIsCurrent").Bind(state)) {
                CustomFunction_StopIfCurrent(state)
                LogError("CustomFunction", "Ввод текста не завершён; зависимые шаги отменены.", "WARN")
                return
            }
            continue
        }
        if (step.Type = "STOP")
        {
            StopCustomFunctionRun(0)
            return
        }
    }
}

AppendCustomFunctionBindRows(ByRef rows) {
    global CustomFunctions
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        hk := ShowHotkeyValue(fn.Hotkey)
        trig := ShowTriggerValue(fn.Trigger)
        hasHotkey := IsBindFieldFilled(hk)
        hasTrigger := IsBindFieldFilled(trig)
        if (!hasHotkey && !hasTrigger)
            continue
        bindValue := hasHotkey ? hk : ""
        if (hasTrigger)
            bindValue .= (bindValue != "" ? " | " : "") . "! " . trig
        status := (hasHotkey && hasTrigger) ? "[MIX] Hotkey + !" : (hasHotkey ? "[HK] Hotkey" : "[TXT] ! Триггер")
        rows.Push({Token: "CustomFunction:" . A_Index, Label: fn.Name, Category: "Свои функции", Hotkey: hk, Trigger: trig, BindValue: bindValue, Status: status})
    }
}

CustomFunctionBuilder_ListText() {
    global CustomFunctions
    listText := ""
    if !IsObject(CustomFunctions)
        return listText
    Loop % CustomFunctions.Length()
    {
        name := NormalizeCustomFunctionName(CustomFunctions[A_Index].Name, "Функция " . A_Index)
        listText .= (listText = "" ? "" : "|") . name
    }
    return listText
}

CustomFunctionBuilder_RefreshList(selectIndex := 1) {
    global CustomFunctions, CustomFunctionSelected
    count := IsObject(CustomFunctions) ? CustomFunctions.Length() : 0
    if (count <= 0)
    {
        CustomFunctions := [CreateDefaultCustomFunction()]
        count := 1
    }
    if (selectIndex < 1 || selectIndex > count)
        selectIndex := 1
    listText := CustomFunctionBuilder_ListText()
    GuiControl, 40:, CFB_List, % "|" . listText
    GuiControl, 40:Choose, CFB_List, %selectIndex%
    CustomFunctionSelected := selectIndex
    CustomFunctionBuilder_LoadSelection(selectIndex)
}

CustomFunctionBuilder_LoadSelection(index) {
    global CustomFunctions, CustomFunctionSelected
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return
    fn := CustomFunctions[index]
    CustomFunctionSelected := index
    GuiControl, 40:, CFB_Name, % fn.Name
    GuiControl, 40:, CFB_Hotkey, % fn.Hotkey
    GuiControl, 40:, CFB_Trigger, % fn.Trigger
    GuiControl, 40:, CFB_Script, % fn.Script
    GuiControl, 40:, CFB_Status, % "Шагов можно до 120. Строка без команды считается SEND."
}

CustomFunctionBuilder_StoreFields(index) {
    global CustomFunctions, CFB_Name, CFB_Hotkey, CFB_Trigger, CFB_Script
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return false
    CustomFunctions[index] := {Name: NormalizeCustomFunctionName(CFB_Name, "Функция " . index), Hotkey: Trim(CFB_Hotkey), Trigger: NormalizeCustomFunctionTrigger(CFB_Trigger), Script: CFB_Script}
    return true
}

CustomFunctionBuilder_SaveCurrent(applyBinds := 1) {
    global CustomFunctions, CustomFunctionSelected, CFB_Name, CFB_Hotkey, CFB_Trigger, CFB_Script
    Gui, 40:Submit, NoHide
    index := CustomFunctionSelected
    if (index < 1 || index > CustomFunctions.Length())
        return false
    name := NormalizeCustomFunctionName(CFB_Name, "Функция " . index)
    triggerValue := NormalizeCustomFunctionTrigger(CFB_Trigger)
    errorText := ""
    CustomFunction_Parse(CFB_Script, errorText)
    if (errorText != "")
    {
        GuiControl, 40:, CFB_Status, % "Ошибка: " . errorText
        Notify("warn")
        return false
    }
    previous := CustomFunctions[index]
    CustomFunctions[index] := {Name: name, Hotkey: Trim(CFB_Hotkey), Trigger: triggerValue, Script: CFB_Script}
    if !SaveCustomFunctions() {
        CustomFunctions[index] := previous
        GuiControl, 40:, CFB_Status, Ошибка записи. Изменения не сохранены.
        return false
    }
    CustomFunctionBuilder_RefreshList(index)
    if (applyBinds)
        ApplyAllBinds()
    GuiControl, 40:, CFB_Status, Сохранено. Hotkey работает только в игре и при закрытом чате.
    return true
}

CustomFunctionBuilder_AppendStep(text) {
    global CFB_Script, hCFBScript
    GuiControlGet, CFB_Script, 40:, CFB_Script
    if (CFB_Script != "" && SubStr(CFB_Script, 0) != "`n")
        CFB_Script .= "`r`n"
    CFB_Script .= text
    GuiControl, 40:, CFB_Script, %CFB_Script%
    if (hCFBScript)
        SendMessage, 0xB1, -1, -1,, ahk_id %hCFBScript%
}

OpenCustomFunctionBuilder(selectIndex := 1) {
    global hCustomFunctionWnd, CustomFunctionGuiVisible, CustomFunctionSelected
    global UIRoundness, InnerRoundness, GuiTransparency, CustomMenuColor, CustomTextColor
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    if (CustomMenuColor != "")
        panel := CustomMenuColor
    if (CustomTextColor != "")
        text := CustomTextColor
    controlBg := "", controlText := "", cardBg := "", cardEdge := ""
    GetControlSurfaceColors(controlBg, controlText, cardBg, cardEdge, panel, text, accent)

    Gui, 40:Destroy
    Gui, 40:+HwndhCustomFunctionWnd +AlwaysOnTop -Resize
    Gui, 40:Color, %bg%, %controlBg%
    Gui, 40:Margin, 0, 0
    Gui, 40:Add, Progress, -Theme x0 y0 w940 h4 Disabled Background%bg% c%accent%, 100
    Gui, 40:Font, s15 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x20 y14 w560 h30 BackgroundTrans, Конструктор функций
    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x20 y44 w880 h18 BackgroundTrans, Собирай последовательности из сообщений, пауз, таймеров и уведомлений. Hotkey действует только в игре при закрытом чате.
    Gui, 40:Add, Progress, -Theme x18 y70 w904 h1 Disabled Background%bg% c%cardEdge%, 100

    AddOutlinedPanel(40, 18, 84, 238, 500, cardBg, cardEdge, 1)
    AddOutlinedPanel(40, 270, 84, 652, 500, cardBg, cardEdge, 1)

    Gui, 40:Font, s9 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x32 y98 w210 h20 BackgroundTrans, МОИ ФУНКЦИИ
    Gui, 40:Font, Norm s9 c%controlText%, Segoe UI
    Gui, 40:Add, ListBox, x32 y126 w210 h402 vCFB_List gCustomFunctionListChanged AltSubmit
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x32 y540 w98 h30 gCustomFunctionNewLabel, Новая
    Gui, 40:Add, Button, x144 y540 w98 h30 gCustomFunctionDeleteLabel, Удалить

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y100 w250 h18 BackgroundTrans, Название
    Gui, 40:Add, Text, x552 y100 w150 h18 BackgroundTrans, Hotkey
    Gui, 40:Add, Text, x718 y100 w184 h18 BackgroundTrans, TXT-триггер
    Gui, 40:Font, Norm s9 c%controlText%, Segoe UI
    Gui, 40:Add, Edit, x286 y120 w250 h28 vCFB_Name
    Gui, 40:Add, Hotkey, x552 y120 w150 h28 vCFB_Hotkey
    Gui, 40:Add, Edit, x718 y120 w184 h28 vCFB_Trigger

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y164 w616 h18 BackgroundTrans, Сценарий
    Gui, 40:Font, Norm s9 c%controlText%, Consolas
    Gui, 40:Add, Edit, x286 y184 w616 h302 vCFB_Script hwndhCFBScript WantTab -Wrap Background%controlBg%

    Gui, 40:Font, Norm s8 c%text%, Segoe UI
    Gui, 40:Add, Button, x286 y500 w88 h28 gCustomFunctionAddSendLabel, + SEND
    Gui, 40:Add, Button, x380 y500 w88 h28 gCustomFunctionAddWaitLabel, + Пауза
    Gui, 40:Add, Button, x474 y500 w88 h28 gCustomFunctionAddTimerLabel, + Таймер
    Gui, 40:Add, Button, x568 y500 w104 h28 gCustomFunctionAddNoticeLabel, + Уведомл.
    Gui, 40:Add, Button, x678 y500 w88 h28 gCustomFunctionAddTypeLabel, + TYPE
    Gui, 40:Add, Button, x772 y500 w130 h28 gCustomFunctionAddIDLabel, + Переменная ID

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y542 w616 h20 vCFB_Status BackgroundTrans,
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x286 y594 w132 h32 gCustomFunctionSaveLabel Default, Сохранить
    Gui, 40:Add, Button, x430 y594 w132 h32 gCustomFunctionRunLabel, Запустить
    Gui, 40:Add, Button, x574 y594 w132 h32 gCustomFunctionStopLabel, Остановить
    Gui, 40:Add, Button, x770 y594 w132 h32 gCustomFunctionCloseLabel, Закрыть

    Capture_BeforeShow("40")

    Gui, 40:Show, w940 h644, AHK FOR GOS BY SBEZRUK - Конструктор функций
    CustomFunctionGuiVisible := 1
    if (selectIndex < 1)
        selectIndex := CustomFunctionSelected > 0 ? CustomFunctionSelected : 1
    CustomFunctionBuilder_RefreshList(selectIndex)
    alpha := GuiTransparency
    NormalizeNumberRange(alpha, 245, 180, 255)
    WinSet, Transparent, %alpha%, ahk_id %hCustomFunctionWnd%
    ApplyRoundedCorners(hCustomFunctionWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hCustomFunctionWnd, InnerRoundness)
}

CloseCustomFunctionBuilder(saveCurrent := 0) {
    global CustomFunctionGuiVisible, hCustomFunctionWnd
    if (saveCurrent)
        CustomFunctionBuilder_SaveCurrent(1)
    Gui, 40:Destroy
    CustomFunctionGuiVisible := 0
    hCustomFunctionWnd := 0
}
