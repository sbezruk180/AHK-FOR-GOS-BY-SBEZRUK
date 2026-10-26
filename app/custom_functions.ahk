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
            steps.Push({Type: "WAIT", Value: waitMs, SourceLine: lineNo})
        }
        else if RegExMatch(line, "i)^TIMER\s+(\d+)(?:\|(.*))?$", m)
        {
            seconds := m1 + 0
            NormalizeNumberRange(seconds, 15, 1, 3600)
            label := Trim(m2)
            steps.Push({Type: "TIMER", Value: seconds, Label: label, SourceLine: lineNo})
        }
        else if RegExMatch(line, "i)^NOTICE\s+(.+)$", m)
            steps.Push({Type: "NOTICE", Value: m1, SourceLine: lineNo})
        else if RegExMatch(line, "i)^(?:TYPE|OPEN)\s+(.+)$", m)
            steps.Push({Type: "TYPE", Value: m1, SourceLine: lineNo})
        else if RegExMatch(line, "i)^(?:SEND|CHAT)\s+(.+)$", m)
            steps.Push({Type: "SEND", Value: m1, SourceLine: lineNo})
        else if RegExMatch(line, "i)^STOP$", m)
            steps.Push({Type: "STOP", Value: "", SourceLine: lineNo})
        else if RegExMatch(line, "i)^[A-Z_]+(?:\s|$)")
        {
            errorText := "Строка " . lineNo . ": неизвестная команда."
            return []
        }
        else
            steps.Push({Type: "SEND", Value: line, SourceLine: lineNo})
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
    return CustomFunction_StartSteps(fn.Name, steps)
}

CustomFunction_StartSteps(name, steps, previewOnly := false) {
    global CustomFunctionRunState, AutomationEpoch, CurrentProfile, UserID, QueueFailureGeneration
    if (IsObject(CustomFunctionRunState) || !IsObject(steps) || !steps.Length())
        return false
    traceId := !previewOnly && IsFunc("ActionTrace_Begin") ? ActionTrace_Begin("Конструктор: " . name, steps.Length()) : 0
    CustomFunctionRunState := {Name: name, Steps: steps, Index: 1, NextTick: TickNow(), WaitingForQueue: 0, PendingBatch: 0
        , Epoch: AutomationEpoch, Profile: CurrentProfile, Target: UserID, Failures: QueueFailureGeneration, PreviewOnly: !!previewOnly
        , TraceId: traceId, TraceStep: 0, TraceTerminal: 0}
    SetTimer, CustomFunctionRunnerTick, 60
    if (previewOnly)
        MockPreview_Append("[BLOCK TEST] " . name . " — только выбранные блоки, без игры и таймеров.")
    else
        GameNotify("Запущена функция: " . name)
    return true
}

CustomFunction_TraceComplete(state, status, detail := "") {
    if (!IsObject(state) || !state.TraceId || state.TraceTerminal)
        return
    if (IsFunc("ActionTrace_Update")) {
        if (state.TraceStep)
            ActionTrace_Update(state.TraceId, state.TraceStep, status, detail)
        if (state.PendingTraceStep)
            ActionTrace_Update(state.TraceId, state.PendingTraceStep, status, detail)
    }
    if IsFunc("ActionTrace_Finish")
        ActionTrace_Finish(state.TraceId, status, detail)
    state.TraceTerminal := 1
}

StopCustomFunctionRun(showNotice := 1) {
    global CustomFunctionRunState
    SetTimer, CustomFunctionRunnerTick, Off
    wasActive := IsObject(CustomFunctionRunState)
    if (wasActive && CustomFunctionRunState.PendingBatch)
        ChatQueue_CancelBatch(CustomFunctionRunState.PendingBatch)
    if (wasActive)
        CustomFunction_TraceComplete(CustomFunctionRunState, "cancelled", "Выполнение остановлено; завершённые шаги не повторяются.")
    CustomFunctionRunState := ""
    if (showNotice && wasActive)
        GameNotify("Пользовательская функция остановлена.", "WARN")
}

CustomFunction_InputIsCurrent(state) {
    global CustomFunctionRunState, AutomationEpoch, CurrentProfile, UserID, QueueFailureGeneration
    return IsObject(state) && IsObject(CustomFunctionRunState) && CustomFunctionRunState == state
        && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile && "ID:" . state.Target = "ID:" . UserID

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
    if (state.Epoch != AutomationEpoch || state.Profile != CurrentProfile || "ID:" . state.Target != "ID:" . UserID) {
        StopCustomFunctionRun(0)
        return
    }
    if (PhysicalInputBusy || IsObject(IDCaptureState))
        return
    if (state.NextTick > TickNow())
        return
    if (state.WaitingForQueue)
    {
        if (!state.PendingBatch || !QueueBatchStates.HasKey(state.PendingBatch)
            || QueueBatchStates[state.PendingBatch].State != "sent") {
            if (state.PendingBatch && QueueBatchStates.HasKey(state.PendingBatch) && QueueBatchStates[state.PendingBatch].State = "queued")
                return
            CustomFunction_TraceComplete(state, "failed", "Отправка шага не подтверждена; зависимые шаги отменены.")
            CustomFunction_StopIfCurrent(state)
            return
        }
        if (state.TraceStep && IsFunc("ActionTrace_Update"))
            ActionTrace_Update(state.TraceId, state.TraceStep, "done", "Отправка подтверждена очередью.")
        state.TraceStep := 0
        state.WaitingForQueue := 0
        state.PendingBatch := 0
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
            CustomFunction_TraceComplete(state, "done", "Все выбранные шаги выполнены.")
            StopCustomFunctionRun(0)
            if (state.PreviewOnly)
                MockPreview_Append("[BLOCK TEST] Завершено: " . completedName)
            else
                GameNotify("Функция завершена: " . completedName)
            return
        }
        step := state.Steps[state.Index]
        ; Mark an elapsed WAIT or immediate prior block before starting the next.
        if (state.TraceStep && IsFunc("ActionTrace_Update"))
            ActionTrace_Update(state.TraceId, state.TraceStep, "done")
        state.TraceStep := 0
        if (state.TraceId && IsFunc("ActionTrace_Add")) {
            state.TraceStep := state.PendingTraceStep ? state.PendingTraceStep : ActionTrace_Add(state.TraceId, step.Type, step.Value)
            state.PendingTraceStep := 0
            ActionTrace_Update(state.TraceId, state.TraceStep, "running")
        }
        state.Index += 1
        if (state.PreviewOnly) {
            value := step.Type = "TIMER" ? step.Value . " сек. | " . ApplyActionTemplate(step.Label) : ApplyActionTemplate(step.Value)
            MockPreview_Append("[BLOCK TEST] " . step.Type . (value != "" ? " " . value : ""))
            if (step.Type = "WAIT") {
                state.NextTick := TickNow() + step.Value
                return
            }
            if (step.Type = "STOP") {
                StopCustomFunctionRun(0)
                return
            }
            continue
        }
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
                if (state.TraceStep && IsFunc("ActionTrace_Update"))
                    ActionTrace_Update(state.TraceId, state.TraceStep, "queued", "Ожидание свободной очереди.")
                state.PendingTraceStep := state.TraceStep
                state.TraceStep := 0
                return
            }
            text := ApplyActionTemplate(step.Value)
            batchId := ChatQueue_EnqueueBatch([text], "CustomFunction." . state.Name, 0)
            if (batchId) {
                state.PendingBatch := batchId
                state.WaitingForQueue := 1
            } else {
                state.Index -= 1
                state.NextTick := TickNow() + 1000
                state.PendingTraceStep := state.TraceStep, state.TraceStep := 0
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
            if (MockMode = "On" || AuditTestMode || Training_IsActive()) {
                MockPreview_Append("[TYPE] " . ApplyActionTemplate(step.Value))
                continue
            }
            if !EnsureGameActive()
            {
                state.Index -= 1
                state.PendingTraceStep := state.TraceStep, state.TraceStep := 0
                return
            }
            if !CustomFunction_InputIsCurrent(state) {
                CustomFunction_StopIfCurrent(state)
                return
            }
            if (PhysicalInputBusy || IsObject(IDCaptureState)) {
                state.Index -= 1
                state.PendingTraceStep := state.TraceStep, state.TraceStep := 0
                return
            }
            if !TypeChatForEpoch(inputEpoch, ApplyActionTemplate(step.Value), Func("CustomFunction_InputIsCurrent").Bind(state)) {
                CustomFunction_TraceComplete(state, "failed", "Ввод текста не завершён; зависимые шаги отменены.")
                CustomFunction_StopIfCurrent(state)
                LogError("CustomFunction", "Ввод текста не завершён; зависимые шаги отменены.", "WARN")
                return
            }
            continue
        }
        if (step.Type = "STOP")
        {
            CustomFunction_TraceComplete(state, "done", "Сценарий завершён командой STOP.")
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
    if (errorText = "Функция не содержит выполняемых шагов." && CustomBlocks_HasDisabledSteps(CFB_Script))
        errorText := ""
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
    global hCFBScript
    if !DllCall("IsWindow", "Ptr", hCFBScript)
        return false
    ControlGetText, script,, ahk_id %hCFBScript%
    first := 0, last := 0
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xB0, "UInt*", first, "UInt*", last)
    before := SubStr(script, 1, first), after := SubStr(script, last + 1)
    insert := (before != "" && SubStr(before, 0) != "`n" ? "`r`n" : "") . text
    if (after != "" && SubStr(after, 1, 1) != "`r" && SubStr(after, 1, 1) != "`n")
        insert .= "`r`n"
    ; EM_REPLACESEL preserves the Edit control's native Ctrl+Z undo history.
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xC2, "Ptr", 1, "Str", insert)
    GuiControl, 40:Focus, CFB_Script
    return true
}

CustomFunctionBuilder_Check(params*) {
    GuiControlGet, script, 40:, CFB_Script
    errorText := "", steps := CustomFunction_Parse(script, errorText)
    if (errorText != "") {
        GuiControl, 40:, CFB_Status, % "Ошибка: " . errorText
        return false
    }
    waitMs := 0
    for _, step in steps
        if (step.Type = "WAIT")
            waitMs += step.Value
    GuiControl, 40:, CFB_Status, % "Проверено: " . steps.Length() . " шагов. Сумма пауз: " . waitMs . " мс. Таймеры не задерживают сценарий."
    return true
}

CustomFunctionBuilder_PreviewText(script, ByRef errorText) {
    steps := CustomFunction_Parse(script, errorText)
    if (errorText != "")
        return ""
    result := "Предпросмотр: сообщения не отправляются, таймеры не запускаются.`r`nПоля профиля и ID подставлены на момент просмотра.`r`n`r`n"
    for index, step in steps {
        value := step.Type = "WAIT" ? step.Value . " мс" : (step.Type = "TIMER" ? step.Value . " сек. | " . ApplyActionTemplate(step.Label) : ApplyActionTemplate(step.Value))
        result .= index . ". " . step.Type . (value != "" ? "  " . value : "") . "`r`n"
        if (step.Type = "STOP") {
            if (index < steps.Length())
                result .= "После STOP оставшиеся шаги не выполняются.`r`n"
            break
        }
    }
    return result
}

CustomFunctionBuilder_Preview(params*) {
    GuiControlGet, script, 40:, CFB_Script
    errorText := "", preview := CustomFunctionBuilder_PreviewText(script, errorText)
    if (errorText != "") {
        GuiControl, 40:, CFB_Status, % "Ошибка: " . errorText
        return false
    }
    return ServiceUI_ShowDetails("Предпросмотр сценария", preview, true)
}

CustomFunctionBuilder_Duplicate(params*) {
    global CustomFunctions, CustomFunctionMaxCount, CFB_Name, CFB_Script
    if (CustomFunctions.Length() >= CustomFunctionMaxCount) {
        GuiControl, 40:, CFB_Status, Достигнут предел пользовательских функций.
        return false
    }
    Gui, 40:Submit, NoHide
    errorText := ""
    CustomFunction_Parse(CFB_Script, errorText)
    if (errorText = "Функция не содержит выполняемых шагов." && CustomBlocks_HasDisabledSteps(CFB_Script))
        errorText := ""
    if (errorText != "") {
        GuiControl, 40:, CFB_Status, % "Ошибка: " . errorText
        return false
    }
    name := NormalizeCustomFunctionName(CFB_Name), number := 1
    Loop {
        candidate := SubStr(name, 1, 44) . " (копия " . number . ")", exists := false
        for _, item in CustomFunctions
            if (item.Name = candidate)
                exists := true
        if (!exists)
            break
        number++
    }
    ; The copy includes unsaved editor text, but never copies conflicting binds.
    CustomFunctions.Push({Name: candidate, Hotkey: "", Trigger: "", Script: CFB_Script})
    if !SaveCustomFunctions() {
        CustomFunctions.Pop()
        GuiControl, 40:, CFB_Status, Не удалось сохранить копию.
        return false
    }
    CustomFunctionBuilder_RefreshList(CustomFunctions.Length())
    ApplyAllBinds()
    GuiControl, 40:, CFB_Status, Копия сохранена без горячей клавиши и TXT. Назначьте их отдельно.
    return true
}

OpenCustomFunctionBuilder(selectIndex := 1) {
    global hCustomFunctionWnd, CustomFunctionGuiVisible, CustomFunctionSelected
    global UIRoundness, InnerRoundness, GuiTransparency
    GetThemeColors(bg, panel, text, accent, muted)
    GetControlSurfaceColors(controlBg, controlText, cardBg, cardEdge, panel, text, accent)

    Gui, 40:Destroy
    Gui, 40:+HwndhCustomFunctionWnd +AlwaysOnTop -Resize
    Gui, 40:Color, %bg%, %controlBg%
    Gui, 40:Margin, 0, 0
    Gui, 40:Font, s8 Bold c%muted%, Segoe UI
    Gui, 40:Add, Text, x24 y18 w880 h18 BackgroundTrans, АВТОМАТИЗАЦИИ / КОНСТРУКТОР
    Gui, 40:Font, s18 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x24 y39 w880 h32 BackgroundTrans, Конструктор функций
    Gui, 40:Font, Norm s9 c%muted%, Segoe UI
    Gui, 40:Add, Text, x24 y77 w880 h20 BackgroundTrans, Сообщения, паузы, таймеры и уведомления в одном сценарии.

    AddOutlinedPanel(40, 18, 112, 232, 488, cardBg, cardEdge, 1)
    AddOutlinedPanel(40, 266, 112, 656, 488, cardBg, cardEdge, 1)

    Gui, 40:Font, s10 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x34 y128 w200 h22 BackgroundTrans, Мои функции
    Gui, 40:Font, Norm s9 c%controlText%, Segoe UI
    Gui, 40:Add, ListBox, x34 y164 w200 h324 vCFB_List gCustomFunctionListChanged AltSubmit
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x34 y502 w200 h30 gCustomFunctionBuilder_Duplicate, Создать копию
    Gui, 40:Add, Button, x34 y544 w94 h36 gCustomFunctionNewLabel, Новая
    Gui, 40:Add, Button, x140 y544 w94 h36 gCustomFunctionDeleteLabel, Удалить

    Gui, 40:Font, Norm s9 c%muted%, Segoe UI
    Gui, 40:Add, Text, x284 y130 w252 h20 BackgroundTrans, Название
    Gui, 40:Add, Text, x552 y130 w140 h20 BackgroundTrans, Горячая клавиша
    Gui, 40:Add, Text, x708 y130 w196 h20 BackgroundTrans, Текстовый триггер
    Gui, 40:Font, Norm s10 c%controlText%, Segoe UI
    Gui, 40:Add, Edit, x284 y156 w252 h34 -Multi -WantReturn -VScroll -HScroll vCFB_Name
    Gui, 40:Add, Hotkey, x552 y156 w140 h34 vCFB_Hotkey
    Gui, 40:Add, Edit, x708 y156 w196 h34 -Multi -WantReturn -VScroll -HScroll vCFB_Trigger

    Gui, 40:Font, s9 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x284 y208 w184 h20 BackgroundTrans, Сценарий
    Gui, 40:Add, Button, x478 y202 w130 h28 gCustomBlocks_Open, Блоки
    Gui, 40:Add, Button, x620 y202 w130 h28 gCustomFunctionBuilder_Check, Проверить
    Gui, 40:Add, Button, x764 y202 w140 h28 gCustomFunctionBuilder_Preview, Предпросмотр
    Gui, 40:Font, Norm s10 c%controlText%, Consolas
    Gui, 40:Add, Edit, x284 y236 w620 h240 vCFB_Script hwndhCFBScript WantTab -Wrap Background%controlBg%

    Gui, 40:Font, Norm s8 c%text%, Segoe UI
    Gui, 40:Add, Button, x284 y490 w90 h32 gCustomFunctionAddSendLabel, + SEND
    Gui, 40:Add, Button, x380 y490 w90 h32 gCustomFunctionAddWaitLabel, + Пауза
    Gui, 40:Add, Button, x476 y490 w90 h32 gCustomFunctionAddTimerLabel, + Таймер
    Gui, 40:Add, Button, x572 y490 w106 h32 gCustomFunctionAddNoticeLabel, + Уведомл.
    Gui, 40:Add, Button, x684 y490 w90 h32 gCustomFunctionAddTypeLabel, + TYPE
    Gui, 40:Add, Button, x780 y490 w124 h32 gCustomFunctionAddIDLabel, + ID

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x284 y540 w620 h42 +Wrap vCFB_Status BackgroundTrans,
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x284 y620 w142 h36 gCustomFunctionSaveLabel Default, Сохранить
    Gui, 40:Add, Button, x438 y620 w142 h36 gCustomFunctionRunLabel, Запустить
    Gui, 40:Add, Button, x592 y620 w142 h36 gCustomFunctionStopLabel, Остановить
    Gui, 40:Add, Button, x762 y620 w142 h36 gCustomFunctionCloseLabel, Закрыть

    Capture_BeforeShow("40")

    Gui, 40:Show, % "w940 h680" . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), AHK FOR GOS BY SBEZRUK - Конструктор функций
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
    CustomBlocks_Close(false)
    Gui, 40:Destroy
    CustomFunctionGuiVisible := 0
    hCustomFunctionWnd := 0
}


; The block model keeps each physical source line, including comments and blanks.
; Disabled blocks remain ordinary AHK-script comments, so old versions ignore them safely.
CustomBlocks_Parse(script) {
    model := {Rows: [], Original: script . "", Dirty: false}
    normalized := StrReplace(StrReplace(script, "`r`n", "`n"), "`r", "`n")
    for _, raw in StrSplit(normalized, "`n") {
        disabled := RegExMatch(raw, "^\s*;@AHK_DISABLED(?:\s|$)(.*)$", marker)
        body := disabled ? marker1 : raw
        active := Trim(body) != "" && SubStr(Trim(body), 1, 1) != ";" && SubStr(Trim(body), 1, 1) != "#"
        model.Rows.Push({Raw: body, Enabled: !disabled, Executable: active})
    }
    return model
}

CustomBlocks_Serialize(model) {
    if !IsObject(model)
        return ""
    if (!model.Dirty)
        return model.Original
    result := ""
    for index, row in model.Rows {
        raw := !row.Enabled && row.Executable ? ";@AHK_DISABLED " . row.Raw : row.Raw
        result .= (index = 1 ? "" : "`r`n") . raw
    }
    return result
}

CustomBlocks_RowInfo(row) {
    if (!row.Executable)
        return {Type: "Заметка", Value: row.Raw, Error: ""}
    steps := CustomFunction_Parse(row.Raw, errorText)
    if (errorText != "")
        return {Type: "Ошибка", Value: row.Raw, Error: errorText}
    step := steps[1]
    return {Type: step.Type, Value: step.Type = "TIMER" ? step.Value . "|" . step.Label : step.Value, Error: ""}
}

CustomBlocks_Move(model, from, to) {
    if (!IsObject(model) || from < 1 || from > model.Rows.Length() || to < 1 || to > model.Rows.Length() || from = to)
        return false
    row := model.Rows.RemoveAt(from)
    model.Rows.InsertAt(to, row)
    model.Dirty := true
    return true
}

CustomBlocks_Toggle(model, index) {
    if (!IsObject(model) || index < 1 || index > model.Rows.Length() || !model.Rows[index].Executable)
        return false
    model.Rows[index].Enabled := !model.Rows[index].Enabled
    model.Dirty := true
    return true
}

CustomBlocks_SelectedScript(model, indices, ByRef errorText) {
    errorText := "", script := ""
    if (!IsObject(model) || !IsObject(indices)) {
        errorText := "Выберите выполняемые блоки."
        return ""
    }
    for _, index in indices {
        if (index < 1 || index > model.Rows.Length())
            continue
        row := model.Rows[index]
        if (row.Executable && row.Enabled)
            script .= (script = "" ? "" : "`r`n") . row.Raw
    }
    if (script = "") {
        errorText := "Выберите хотя бы один включённый блок."
        return ""
    }
    CustomFunction_Parse(script, errorText)
    return errorText = "" ? script : ""
}

CustomBlocks_Open(params*) {
    global CustomBlocksState, hCustomFunctionWnd, hCFBScript, CustomFunctionSelected
    if (IsObject(CustomBlocksState) && DllCall("IsWindow", "Ptr", CustomBlocksState.Hwnd)) {
        WinActivate, % "ahk_id " . CustomBlocksState.Hwnd
        return true
    }
    if !DllCall("IsWindow", "Ptr", hCFBScript)
        return false
    ControlGetText, script,, ahk_id %hCFBScript%
    state := {Model: CustomBlocks_Parse(script), Index: CustomFunctionSelected, EditorHwnd: hCFBScript, DragRow: 0, DragTarget: 0}
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    Gui, CFBBlocks:New, +HwndblocksHwnd +Owner%hCustomFunctionWnd% +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
    Gui, CFBBlocks:Color, %bg%, %surface%
    Gui, CFBBlocks:Font, s14 Bold c%fg%, Segoe UI
    Gui, CFBBlocks:Add, Text, x22 y18 w832 h30 BackgroundTrans, Блочный конструктор
    Gui, CFBBlocks:Font, s9 Norm c%muted%, Segoe UI
    Gui, CFBBlocks:Add, Text, x22 y56 w832 h38 +Wrap BackgroundTrans, Перетащите строку или используйте стрелки. Ctrl / Shift — несколько блоков. Текст, комментарии и пустые строки сохраняются.
    Gui, CFBBlocks:Font, s9 Norm c%inputFg%, Segoe UI
    Gui, CFBBlocks:Add, ListView, x22 y104 w832 h242 hwndlistHwnd AltSubmit -ReadOnly, №|Состояние|Блок|Текст / значение
    state.Hwnd := blocksHwnd, state.ListHwnd := listHwnd
    GuiControl, CFBBlocks:+g, %listHwnd%, % Func("CustomBlocks_ListEvent")
    Gui, CFBBlocks:Font, s9 Norm c%fg%, Segoe UI
    Gui, CFBBlocks:Add, Button, x22 y358 w90 h32 hwndupHwnd, Вверх
    Gui, CFBBlocks:Add, Button, x122 y358 w90 h32 hwnddownHwnd, Вниз
    Gui, CFBBlocks:Add, Button, x222 y358 w164 h32 hwndtoggleHwnd, Включить / выкл.
    Gui, CFBBlocks:Add, Button, x396 y358 w118 h32 hwnddeleteHwnd, Удалить блок
    Gui, CFBBlocks:Add, Button, x524 y358 w156 h32 hwndpreviewHwnd, Просмотр выбранных
    Gui, CFBBlocks:Add, Button, x690 y358 w164 h32 hwndtestHwnd, Тест выбранных
    Gui, CFBBlocks:Font, s8 Norm c%muted%, Segoe UI
    Gui, CFBBlocks:Add, Text, x22 y404 w160 h18 BackgroundTrans, Тип блока
    Gui, CFBBlocks:Add, Text, x192 y404 w662 h18 BackgroundTrans, Значение (TIMER: секунды|название). STOP не требует значения.
    Gui, CFBBlocks:Font, s10 Norm c%inputFg%, Segoe UI
    Gui, CFBBlocks:Add, DropDownList, x22 y430 w160 hwndtypeHwnd, SEND||WAIT|TIMER|NOTICE|TYPE|STOP|Заметка
    Gui, CFBBlocks:Add, Edit, x192 y430 w662 h32 hwndvalueHwnd -Multi -WantReturn
    Gui, CFBBlocks:Font, s9 Norm c%fg%, Segoe UI
    Gui, CFBBlocks:Add, Button, x22 y474 w160 h32 hwndinsertHwnd, Добавить после
    Gui, CFBBlocks:Add, Button, x192 y474 w182 h32 hwndupdateHwnd, Изменить выбранный
    Gui, CFBBlocks:Font, s8 Norm c%muted%, Segoe UI
    Gui, CFBBlocks:Add, Text, x22 y520 w832 h38 +Wrap hwndstatusHwnd BackgroundTrans, Тест выполняет только выбранные блоки в песочнице: без игры, отправки сообщений и запуска игровых таймеров.
    Gui, CFBBlocks:Font, s10 Norm c%fg%, Segoe UI
    Gui, CFBBlocks:Add, Button, x536 y570 w176 h36 hwndapplyHwnd, Применить в сценарий
    Gui, CFBBlocks:Add, Button, x724 y570 w130 h36 hwndcloseHwnd, Закрыть
    state.TypeHwnd := typeHwnd, state.ValueHwnd := valueHwnd, state.StatusHwnd := statusHwnd
    for hwnd, callback in { (upHwnd): "CustomBlocks_Up", (downHwnd): "CustomBlocks_Down", (toggleHwnd): "CustomBlocks_ToggleSelected"
        , (deleteHwnd): "CustomBlocks_Delete", (previewHwnd): "CustomBlocks_Preview", (testHwnd): "CustomBlocks_Test"
        , (insertHwnd): "CustomBlocks_Insert", (updateHwnd): "CustomBlocks_Update", (applyHwnd): "CustomBlocks_Apply", (closeHwnd): "CustomBlocks_CloseButton" }
        GuiControl, CFBBlocks:+g, %hwnd%, % Func(callback)
    UIStyle_SetButtonRole(applyHwnd, "primary")
    CustomBlocksState := state
    CustomBlocks_Refresh(1)
    Capture_BeforeShow("CFBBlocks")
    Gui, CFBBlocks:Show, % "w876 h628" . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), AHK FOR GOS - Блочный конструктор
    return true
}

CustomBlocks_SelectList() {
    global CustomBlocksState
    if (!IsObject(CustomBlocksState) || !DllCall("IsWindow", "Ptr", CustomBlocksState.ListHwnd))
        return false
    Gui, CFBBlocks:Default
    Gui, CFBBlocks:ListView, % CustomBlocksState.ListHwnd
    return true
}

CustomBlocks_Selection() {
    indices := []
    if !CustomBlocks_SelectList()
        return indices
    row := 0
    while (row := LV_GetNext(row))
        indices.Push(row)
    return indices
}

CustomBlocks_Refresh(selectIndex := 1) {
    global CustomBlocksState
    if !CustomBlocks_SelectList()
        return false
    LV_Delete()
    for index, row in CustomBlocksState.Model.Rows {
        info := CustomBlocks_RowInfo(row)
        LV_Add("", index, row.Executable ? (row.Enabled ? "Вкл." : "Выкл.") : "—", info.Type, info.Value)
    }
    LV_ModifyCol(1, 38), LV_ModifyCol(2, 74), LV_ModifyCol(3, 96), LV_ModifyCol(4, 596)
    if (selectIndex > 0 && selectIndex <= CustomBlocksState.Model.Rows.Length()) {
        LV_Modify(selectIndex, "Select Focus Vis")
        CustomBlocks_LoadRow(selectIndex)
    }
    return true
}

CustomBlocks_LoadRow(index) {
    global CustomBlocksState
    if (!IsObject(CustomBlocksState) || index < 1 || index > CustomBlocksState.Model.Rows.Length())
        return false
    info := CustomBlocks_RowInfo(CustomBlocksState.Model.Rows[index])
    if (info.Type = "Ошибка")
        info.Type := "SEND", info.Value := CustomBlocksState.Model.Rows[index].Raw
    GuiControl, CFBBlocks:ChooseString, % CustomBlocksState.TypeHwnd, % info.Type
    GuiControl, CFBBlocks:, % CustomBlocksState.ValueHwnd, % info.Value
    return true
}

CustomBlocks_ListEvent(controlHwnd := 0, guiEvent := "", eventInfo := 0, eventError := "") {
    global CustomBlocksState
    if !IsObject(CustomBlocksState)
        return
    if (guiEvent = "D" && eventInfo > 0) {
        CustomBlocksState.DragRow := eventInfo, CustomBlocksState.DragTarget := eventInfo
        SetTimer, CustomBlocks_DragTick, 30
    } else if ((guiEvent = "Normal" || guiEvent = "DoubleClick") && eventInfo > 0)
        CustomBlocks_LoadRow(eventInfo)
}

CustomBlocks_DragTick() {
    global CustomBlocksState
    if (!IsObject(CustomBlocksState) || !CustomBlocksState.DragRow || !DllCall("IsWindow", "Ptr", CustomBlocksState.ListHwnd)) {
        SetTimer, CustomBlocks_DragTick, Off
        return
    }
    VarSetCapacity(point, 8, 0)
    DllCall("GetCursorPos", "Ptr", &point)
    DllCall("ScreenToClient", "Ptr", CustomBlocksState.ListHwnd, "Ptr", &point)
    VarSetCapacity(hit, 24, 0)
    NumPut(NumGet(point, 0, "Int"), hit, 0, "Int"), NumPut(NumGet(point, 4, "Int"), hit, 4, "Int")
    target := DllCall("SendMessage", "Ptr", CustomBlocksState.ListHwnd, "UInt", 0x1039, "Ptr", 0, "Ptr", &hit, "Ptr") + 1
    if (target > 0 && target <= CustomBlocksState.Model.Rows.Length())
        CustomBlocksState.DragTarget := target
    if GetKeyState("LButton", "P")
        return
    SetTimer, CustomBlocks_DragTick, Off
    from := CustomBlocksState.DragRow, to := target > 0 ? CustomBlocksState.DragTarget : from
    CustomBlocksState.DragRow := 0
    if CustomBlocks_Move(CustomBlocksState.Model, from, to)
        CustomBlocks_Refresh(to)
}

CustomBlocks_Up(params*) {
    return CustomBlocks_MoveSelected(-1)
}

CustomBlocks_Down(params*) {
    return CustomBlocks_MoveSelected(1)
}

CustomBlocks_MoveSelected(direction) {
    global CustomBlocksState
    rows := CustomBlocks_Selection()
    if (rows.Length() != 1)
        return CustomBlocks_Status("Для перемещения выберите один блок.", false)
    from := rows[1], to := from + direction
    if !CustomBlocks_Move(CustomBlocksState.Model, from, to)
        return false
    CustomBlocks_Refresh(to)
    return true
}

CustomBlocks_ToggleSelected(params*) {
    global CustomBlocksState
    rows := CustomBlocks_Selection(), changed := false
    for _, index in rows
        if CustomBlocks_Toggle(CustomBlocksState.Model, index)
            changed := true
    if (changed)
        CustomBlocks_Refresh(rows[1])
    return changed
}

CustomBlocks_Delete(params*) {
    global CustomBlocksState
    rows := CustomBlocks_Selection()
    if !rows.Length()
        return false
    count := rows.Length()
    Loop % count
        CustomBlocksState.Model.Rows.RemoveAt(rows[count - A_Index + 1])
    CustomBlocksState.Model.Dirty := true
    CustomBlocks_Refresh(Min(rows[1], CustomBlocksState.Model.Rows.Length()))
    return true
}

CustomBlocks_ReadFields(ByRef raw, ByRef errorText) {
    global CustomBlocksState
    raw := "", errorText := ""
    if !IsObject(CustomBlocksState)
        return false
    GuiControlGet, type, CFBBlocks:, % CustomBlocksState.TypeHwnd
    GuiControlGet, value, CFBBlocks:, % CustomBlocksState.ValueHwnd
    if (InStr(value, "`n") || InStr(value, "`r")) {
        errorText := "Один блок должен занимать одну строку."
        return false
    }
    if (type = "Заметка") {
        raw := "; " . value
        return true
    }
    raw := type . (type = "STOP" ? "" : " " . value)
    CustomFunction_Parse(raw, errorText)
    return errorText = ""
}

CustomBlocks_Insert(params*) {
    global CustomBlocksState
    if !CustomBlocks_ReadFields(raw, errorText)
        return CustomBlocks_Status(errorText, false)
    rows := CustomBlocks_Selection(), index := rows.Length() ? rows[rows.Length()] + 1 : CustomBlocksState.Model.Rows.Length() + 1
    CustomBlocksState.Model.Rows.InsertAt(index, {Raw: raw, Enabled: true, Executable: SubStr(raw, 1, 1) != ";"})
    CustomBlocksState.Model.Dirty := true
    CustomBlocks_Refresh(index)
    return true
}

CustomBlocks_Update(params*) {
    global CustomBlocksState
    rows := CustomBlocks_Selection()
    if (rows.Length() != 1)
        return CustomBlocks_Status("Для изменения выберите один блок.", false)
    if !CustomBlocks_ReadFields(raw, errorText)
        return CustomBlocks_Status(errorText, false)
    enabled := CustomBlocksState.Model.Rows[rows[1]].Enabled
    CustomBlocksState.Model.Rows[rows[1]] := {Raw: raw, Enabled: enabled, Executable: SubStr(raw, 1, 1) != ";"}
    CustomBlocksState.Model.Dirty := true
    CustomBlocks_Refresh(rows[1])
    return true
}

CustomBlocks_Preview(params*) {
    global CustomBlocksState
    script := CustomBlocks_SelectedScript(CustomBlocksState.Model, CustomBlocks_Selection(), errorText)
    if (errorText != "")
        return CustomBlocks_Status(errorText, false)
    preview := CustomFunctionBuilder_PreviewText(script, errorText)
    return errorText = "" && ServiceUI_ShowDetails("Предпросмотр выбранных блоков", preview, true)
}

CustomBlocks_Test(params*) {
    global CustomBlocksState, CustomFunctionRunState
    script := CustomBlocks_SelectedScript(CustomBlocksState.Model, CustomBlocks_Selection(), errorText)
    if (errorText != "")
        return CustomBlocks_Status(errorText, false)
    steps := CustomFunction_Parse(script, errorText)
    if !CustomFunction_StartSteps("Тест выбранных блоков", steps, true)
        return CustomBlocks_Status("Сначала остановите выполняющийся сценарий. Новый тест не прерывает его.", false)
    MockPreview_Show()
    return CustomBlocks_Status("Идёт тест выбранных блоков без игровых действий. «Остановить» в основном конструкторе отменяет тест.")
}

CustomBlocks_Apply(params*) {
    global CustomBlocksState, CustomFunctionSelected, hCFBScript
    if (!IsObject(CustomBlocksState) || CustomBlocksState.EditorHwnd != hCFBScript || !DllCall("IsWindow", "Ptr", hCFBScript))
        return false
    if (CustomFunctionSelected != CustomBlocksState.Index)
        return CustomBlocks_Status("В основном конструкторе выбрана другая функция. Вернитесь к исходной перед применением.", false)
    ControlGetText, current,, ahk_id %hCFBScript%
    if !(current == CustomBlocksState.Model.Original)
        return CustomBlocks_Status("Исходный текст изменён в основном конструкторе. Закройте блоки и откройте заново, чтобы сохранить оба изменения.", false)
    script := CustomBlocks_Serialize(CustomBlocksState.Model)
    steps := CustomFunction_Parse(script, errorText)
    ; All blocks may intentionally be disabled; it is safe to keep such a draft.
    if (errorText != "" && errorText != "Функция не содержит выполняемых шагов.")
        return CustomBlocks_Status(errorText, false)
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xB1, "Ptr", 0, "Ptr", -1)
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xC2, "Ptr", 1, "Str", script)
    CustomBlocksState.Model.Original := script, CustomBlocksState.Model.Dirty := false
    GuiControl, 40:, CFB_Status, Блоки перенесены в текстовый сценарий. Нажмите «Сохранить» для записи в файл.
    return CustomBlocks_Status("Применено в текстовый редактор. Бинды и настройки не изменены; сценарий нужно сохранить.")
}

CustomBlocks_Status(text, result := true) {
    global CustomBlocksState
    if IsObject(CustomBlocksState)
        GuiControl, CFBBlocks:, % CustomBlocksState.StatusHwnd, %text%
    return result
}

CustomBlocks_Close(ask := true) {
    global CustomBlocksState
    if (!IsObject(CustomBlocksState))
        return true
    if (ask && CustomBlocksState.Model.Dirty && !ServiceUI_Confirm("Закрыть блоки", "Не перенесённые в сценарий изменения будут потеряны. Закрыть?"))
        return false
    SetTimer, CustomBlocks_DragTick, Off
    Gui, CFBBlocks:Destroy
    CustomBlocksState := ""
    return true
}

CustomBlocks_CloseButton(params*) {
    return CustomBlocks_Close(true)
}

CFBBlocksGuiClose() {
    CustomBlocks_Close(true)
}

CFBBlocksGuiEscape() {
    CustomBlocks_Close(true)
}

CustomBlocks_HasDisabledSteps(script) {
    model := CustomBlocks_Parse(script)
    for _, row in model.Rows
        if (row.Executable && !row.Enabled)
            return true
    return false
}
