; automation subsystem. Definitions only; initialization is in bootstrap.

TaskScheduler_Set(name, totalMs, callback, statusText := "", payload := "") {
    global TaskSchedulerItems, TaskSchedulerNextDueTick, TaskSchedulerGeneration
    if !IsObject(TaskSchedulerItems)
        TaskSchedulerItems := {}
    totalMs := Round(totalMs)
    if (name = "" || totalMs < 1)
        return false
    if (totalMs > 2147480000)
        totalMs := 2147480000

    TaskSchedulerGeneration++
    endTick := TickNow() + totalMs
    TaskSchedulerItems[name] := {Name: name, EndTick: endTick, Callback: callback, Status: statusText, Payload: payload, Generation: TaskSchedulerGeneration}
    if (TaskSchedulerNextDueTick = 0 || TaskScheduler_RemainingMs(endTick) < TaskScheduler_RemainingMs(TaskSchedulerNextDueTick))
        TaskSchedulerNextDueTick := endTick
    return true
}

TaskScheduler_Cancel(name) {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return false
    if !TaskSchedulerItems.HasKey(name)
        return false
    TaskSchedulerItems.Delete(name)
    TaskScheduler_RecalculateNextDue()
    return true
}

TaskScheduler_CancelAll() {
    global TaskSchedulerItems, TaskSchedulerNextDueTick
    count := TaskScheduler_Count()
    TaskSchedulerItems := {}
    TaskSchedulerNextDueTick := 0
    return count
}

TaskScheduler_Count() {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return 0
    count := 0
    for name, task in TaskSchedulerItems
        count++
    return count
}

TaskScheduler_StatusText() {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return "нет"
    out := ""
    nowTick := TickNow()
    for name, task in TaskSchedulerItems
    {
        leftSec := Ceil(TaskScheduler_RemainingMs(task.EndTick, nowTick) / 1000.0)
        if (leftSec < 0)
            leftSec := 0
        minutes := Floor(leftSec / 60)
        seconds := Mod(leftSec, 60)
        timeText := Format("{:02}:{:02}", minutes, seconds)
        label := task.Status != "" ? task.Status : name
        if (out != "")
            out .= "; "
        out .= label . " " . timeText
    }
    return out != "" ? out : "нет"
}

TaskScheduler_RemainingMs(endTick, nowTick := "") {
    return endTick - (nowTick = "" ? TickNow() : nowTick)
}

TaskScheduler_RecalculateNextDue(nowTick := "") {
    global TaskSchedulerItems, TaskSchedulerNextDueTick
    if (nowTick = "")
        nowTick := TickNow()
    TaskSchedulerNextDueTick := 0
    bestRemaining := ""
    if !IsObject(TaskSchedulerItems)
        return 0
    for name, task in TaskSchedulerItems
    {
        remaining := TaskScheduler_RemainingMs(task.EndTick, nowTick)
        if (bestRemaining = "" || remaining < bestRemaining)
        {
            bestRemaining := remaining
            TaskSchedulerNextDueTick := task.EndTick
        }
    }
    return TaskSchedulerNextDueTick
}

TaskScheduler_Tick() {
    global TaskSchedulerItems, TaskSchedulerBusy, TaskSchedulerNextDueTick
    global TaskSchedulerLastStatusTick, TaskSchedulerMaxCallbacksPerTick, MDSFormationActive

    if (TaskSchedulerBusy)
        return false
    TaskSchedulerBusy := 1
    nowTick := TickNow()
    changed := 0
    ok := true

    try
    {
        if (MDSFormationActive)
            HandleMDSFormationTimerTick(0)

        shouldScan := IsObject(TaskSchedulerItems) && TaskSchedulerNextDueTick != 0
            && TaskScheduler_RemainingMs(TaskSchedulerNextDueTick, nowTick) <= 0
        if (shouldScan)
        {
            due := []
            for name, task in TaskSchedulerItems
            {
                if (TaskScheduler_RemainingMs(task.EndTick, nowTick) <= 0)
                    due.Push({Name: name, Generation: task.Generation})
            }

            processed := 0
            Loop % due.Length()
            {
                if (processed >= TaskSchedulerMaxCallbacksPerTick)
                    break
                dueItem := due[A_Index]
                name := dueItem.Name
                if !TaskSchedulerItems.HasKey(name)
                    continue
                task := TaskSchedulerItems[name]
                if (task.Generation != dueItem.Generation || TaskScheduler_RemainingMs(task.EndTick, nowTick) > 0)
                    continue

                TaskSchedulerItems.Delete(name)
                changed := 1
                processed++
                TaskScheduler_Invoke(task)
                Sleep, -1
                nowTick := TickNow()
            }
            TaskScheduler_RecalculateNextDue(nowTick)
        }

        if (changed || TaskSchedulerLastStatusTick = 0 || nowTick - TaskSchedulerLastStatusTick >= 1000)
        {
            TaskSchedulerLastStatusTick := nowTick
            UpdateAutomationSettingsStatus()
        }
    }
    catch e
    {
        ok := false
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("TaskScheduler", "Tick error: " . errorText, "ERROR")
        TaskScheduler_RecalculateNextDue()
    }

    TaskSchedulerBusy := 0
    return ok
}

TaskScheduler_Invoke(task) {
    if !IsObject(task)
        return false
    callback := task.Callback
    try
    {
        if (callback = "MDSFormation") {
            HandleMDSFormationTimerTick(1)
            return true
        }
        if (callback != "" && IsFunc(callback)) {
            fn := Func(callback)
            fn.Call(task.Payload)
            return true
        }
        LogError("TaskScheduler", "Unknown callback: " . callback, "WARN")
        return false
    }
    catch e
    {
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("TaskScheduler", "Callback " . callback . " failed: " . errorText, "ERROR")
        return false
    }
}

AutoReport_NormalizeMode(ByRef mode, fallback := "Патруль") {
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        mode := fallback
    return mode
}

AutoReport_IsValidDuration(durationMin) {
    raw := Trim(durationMin . "")
    if !RegExMatch(raw, "^\d+$")
        return false
    value := raw + 0
    return value >= 10 && value <= 600
}

AutoReport_GetTemplate() {
    global AutoReportMode, T_PatrolContinue, T_PostContinue
    templateText := (AutoReportMode = "Пост") ? T_PostContinue : T_PatrolContinue
    return ApplyTemplate(templateText)
}

AutoReport_GetStatusText(nowTick := "") {
    global AutoReportActive, AutoReportMode, AutoReportEndTick, AutoReportNextTick
    global AutoReportSentCount, AutoReportSkippedCount
    if (!AutoReportActive)
        return "Автодоклад: выключен"
    if (nowTick = "")
        nowTick := TickNow()
    leftSec := Ceil(TaskScheduler_RemainingMs(AutoReportEndTick, nowTick) / 1000.0)
    if (leftSec < 0)
        leftSec := 0
    leftText := Format("{:02}:{:02}", Floor(leftSec / 60), Mod(leftSec, 60))
    if (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= TaskScheduler_RemainingMs(AutoReportEndTick, nowTick))
    {
        nextSec := Ceil(TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) / 1000.0)
        if (nextSec < 0)
            nextSec := 0
        nextText := Format("{:02}:{:02}", Floor(nextSec / 60), Mod(nextSec, 60))
    }
    else
        nextText := "—"
    return "Автодоклад: " . AutoReportMode . " | осталось " . leftText . " | следующий " . nextText . " | в очереди принято " . AutoReportAcceptedCount . " | транспорт выполнен " . AutoReportSentCount . " | пропущено " . AutoReportSkippedCount
}

AutoReport_UpdateStatus() {
    global CFG_AutoReportStatus
    CFG_AutoReportStatus := AutoReport_GetStatusText()
    if SettingsGui_CanUpdate()
    {
        try
            GuiControl, 2:, CFG_AutoReportStatus, %CFG_AutoReportStatus%
    }
}

AutoReport_ScheduleNext() {
    global AutoReportActive, AutoReportEndTick, AutoReportNextTick
    if (!AutoReportActive)
        return false
    nextRemaining := TaskScheduler_RemainingMs(AutoReportNextTick)
    endRemaining := TaskScheduler_RemainingMs(AutoReportEndTick)
    dueTick := (nextRemaining <= endRemaining) ? AutoReportNextTick : AutoReportEndTick
    delayMs := TaskScheduler_RemainingMs(dueTick)
    if (delayMs < 1)
        delayMs := 1
    return TaskScheduler_Set("AutoReport", delayMs, "AutoReport_OnTask", "Автодоклад")
}

AutoReport_Start(mode, durationMin, showStatus := 1) {
    global AutoReportMode, AutoReportDurationMin, AutoReportActive
    global AutoReportStartTick, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSentCount, AutoReportSkippedCount

    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
    {
        if (showStatus)
            GameNotify("Выберите режим автодоклада: Патруль или Пост.", "WARN")
        return false
    }
    if !AutoReport_IsValidDuration(durationMin)
    {
        if (showStatus)
            GameNotify("Продолжительность автодоклада: целое число от 10 до 600 минут.", "WARN")
        return false
    }

    AutoReport_Stop(0, "replace")
    AutoReportMode := mode
    AutoReportDurationMin := durationMin + 0
    AutoReportActive := 1
    AutoReportStartTick := TickNow()
    AutoReportEndTick := AutoReportStartTick + AutoReportDurationMin * 60000
    AutoReportNextTick := AutoReportStartTick + 600000
    AutoReportLastDispatchTick := 0
    AutoReportSentCount := 0
    AutoReportAcceptedCount := 0
    AutoReportSkippedCount := 0
    if !AutoReport_ScheduleNext()
    {
        AutoReportActive := 0
        if (showStatus)
            GameNotify("Не удалось поставить автодоклад в планировщик.", "ERROR")
        return false
    }
    AutoReportLastDispatchTick := AutoReportStartTick
    if !AutoReport_DispatchScheduled(AutoReportStartTick)
    {
        AutoReport_Stop(0, "initial-dispatch-failed")
        if (showStatus)
            GameNotify("Автодоклад не запущен: первый доклад не удалось поставить в очередь.", "ERROR")
        return false
    }
    LogError("AutoReport", "Started: mode=" . AutoReportMode . ", duration=" . AutoReportDurationMin . " min", "INFO")
    ActionTimer_StartAutoReport(AutoReportMode)
    AutoReport_UpdateStatus()
    UpdateAutomationSettingsStatus()
    if (showStatus)
        GameNotify("Автодоклад «" . AutoReportMode . "» запущен на " . FormatRussianMinutes(AutoReportDurationMin) . ". Первый доклад поставлен в очередь сразу. Следующий — через 10 минут.", "INFO")
    return true
}

AutoReport_Stop(showStatus := 1, reason := "manual") {
    global AutoReportActive, AutoReportMode, AutoReportStartTick, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSentCount, AutoReportSkippedCount
    wasActive := AutoReportActive
    stoppedMode := AutoReportMode
    TaskScheduler_Cancel("AutoReport")
    if (wasActive)
        LogError("AutoReport", "Stopped: reason=" . reason . ", sent=" . AutoReportSentCount . ", skipped=" . AutoReportSkippedCount, "INFO")
    if (reason != "completed")
        ChatQueue_RemoveBySource("AutoReport")
    AutoReportActive := 0
    AutoReportStartTick := 0
    AutoReportEndTick := 0
    AutoReportNextTick := 0
    AutoReportLastDispatchTick := 0
    AutoReportSentCount := 0
    AutoReportAcceptedCount := 0
    AutoReportSkippedCount := 0
    stoppedToken := (stoppedMode = "Пост") ? "Post" : "Patrol"
    ActionTimer_Stop(stoppedToken, 1, "AutoReport")
    AutoReport_UpdateStatus()
    UpdateAutomationSettingsStatus()
    if (wasActive && reason = "completed")
    {
        GameNotify("Автодоклад «" . stoppedMode . "» завершён.", "INFO")
        if ActionTimer_IsEnabled(stoppedMode)
            PlayStopTimerSound()
    }
    if (showStatus && wasActive)
        GameNotify("Автодоклад «" . stoppedMode . "» остановлен.", "INFO")
    return wasActive
}

AutoReport_DispatchScheduled(scheduledTick) {
    global MockMode, AutoReportAcceptedCount, AutoReportSkippedCount
    reportText := AutoReport_GetTemplate()
    if (Trim(reportText) = "")
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "Report template is empty; tick skipped.", "WARN")
        return false
    }
    if (MockMode = "On")
        queued := ChatQueue_Enqueue(reportText, "AutoReport", 1, 700, 1)
    else if !GameLocator_IsActive()
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "Game is unavailable; scheduled report skipped.", "WARN")
        return false
    }
    else
        queued := ChatQueue_Enqueue(reportText, "AutoReport", 0, 700, 1)

    if (queued)
        AutoReportAcceptedCount += 1
    else
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "ChatQueue rejected scheduled report.", "WARN")
    }
    return queued
}

AutoReport_HandleTick(nowTick := "") {
    global AutoReportActive, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSkippedCount
    if (!AutoReportActive)
        return false
    if (nowTick = "")
        nowTick := TickNow()

    endRemaining := TaskScheduler_RemainingMs(AutoReportEndTick, nowTick)
    nextRemaining := TaskScheduler_RemainingMs(AutoReportNextTick, nowTick)
    if (nextRemaining <= endRemaining && nextRemaining <= 0)
    {
        scheduledTick := AutoReportNextTick
        missed := 0
        while (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= 0)
        {
            AutoReportNextTick := AutoReportNextTick + 600000
            missed += 1
        }
        lateness := -TaskScheduler_RemainingMs(scheduledTick, nowTick)
        if (missed > 1 || lateness > 60000)
        {
            AutoReportSkippedCount += missed
            LogError("AutoReport", "Missed " . missed . " interval(s); catch-up suppressed.", "WARN")
        }
        else if (AutoReportLastDispatchTick != scheduledTick)
        {
            AutoReportLastDispatchTick := scheduledTick
            AutoReport_DispatchScheduled(scheduledTick)
        }
    }

    if (TaskScheduler_RemainingMs(AutoReportEndTick, nowTick) <= 0)
    {
        AutoReport_Stop(0, "completed")
        return true
    }
    AutoReport_ScheduleNext()
    AutoReport_UpdateStatus()
    return true
}

AutoReport_OnTask(payload := "") {
    return AutoReport_HandleTick(TickNow())
}

ChatQueue_Count() {
    global ChatQueueItems
    return IsObject(ChatQueueItems) ? ChatQueueItems.Length() : 0
}

ChatQueue_RemoveBySource(source) {
    global ChatQueueItems
    if !IsObject(ChatQueueItems)
        return 0
    kept := []
    removed := 0
    Loop % ChatQueueItems.Length()
    {
        item := ChatQueueItems[A_Index]
        if (IsObject(item) && item.HasKey("Source") && item.Source = source)
            removed += 1
        else
            kept.Push(item)
    }
    if (removed > 0)
    {
        ChatQueueItems := kept
        UpdateHUD()
    }
    return removed
}

ChatQueue_StatusText() {
    global ChatQueueBusy
    count := ChatQueue_Count()
    if (count <= 0)
        return ChatQueueBusy ? "отправка" : "пусто"
    return count . " в очереди"
}

ChatQueue_Enqueue(text, source := "ChatQueue", forceMock := 0, delayAfter := "", forceQueue := 0) {
    global ChatQueueItems, ChatQueueEnabled, ChatQueueMaxItems
    text := Trim(text)
    if (text = "")
        return false
    if (!forceMock && !forceQueue && ChatQueueEnabled != "On")
        return ChatQueue_SendNow(text, source)
    if !IsObject(ChatQueueItems)
        ChatQueueItems := []
    NormalizeNumberRange(ChatQueueMaxItems, 200, 10, 1000)
    if (ChatQueueItems.Length() >= ChatQueueMaxItems) {
        LogError(source, "Очередь переполнена, строка отклонена: " . text, "ERROR")
        Notify("warn")
        return false
    }
    if (delayAfter != "")
        NormalizeNumberRange(delayAfter, 700, 0, 30000)
    ChatQueueItems.Push({Text: text, Source: source, Tries: 0, ForceMock: forceMock ? 1 : 0, DelayAfter: delayAfter, Epoch: AutomationEpoch, Batch: 0})
    LogError(source, "Queued chat line: " . text, "INFO")
    UpdateHUD()
    return true
}

ChatQueue_SendNow(text, source := "ChatQueue") {
    return ChatQueue_TrySend(text, source)
}

ChatQueue_Tick() {
    global ChatQueueItems, ChatQueueBusy, ChatQueueLastSendTick, ChatQueueNextSendTick
    global ChatQueueMinDelay, ChatQueueMaxRetries, AutoReportSentCount, AutoReportSkippedCount
    global QueueFailureGeneration, AuditTransportResult, AuditTestMode, QueueBatchStates
    if (ChatQueueBusy || PhysicalInputBusy || IsObject(IDCaptureState) || !IsObject(ChatQueueItems) || !ChatQueueItems.Length())
        return
    if (ChatQueueNextSendTick > TickNow())
        return
    NormalizeNumberRange(ChatQueueMinDelay, 700, 250, 5000)
    NormalizeNumberRange(ChatQueueMaxRetries, 2, 0, 5)
    if (ChatQueueLastSendTick && TickNow() - ChatQueueLastSendTick < ChatQueueMinDelay)
        return
    ChatQueueBusy := 1
    item := ChatQueueItems.RemoveAt(1)
    try {
        epoch := item.HasKey("Epoch") ? item.Epoch : AutomationEpoch
        if (epoch != AutomationEpoch) {
            ChatQueue_CompleteItem(item, "cancelled")
            return
        }
        if (item.HasKey("Kind") && item.Kind = "Menu") {
            result := QueueMenu_Run(item) ? 1 : -1
        } else if (item.HasKey("ForceMock") && item.ForceMock) {
            MockPreview_Append(item.Text)
            result := 1
        } else
            result := AuditTestMode ? AuditTransportResult : ChatTransport_Send(item.Text, item.Source, item.HasKey("Role") ? item.Role : "")
        if (epoch != AutomationEpoch) {
            ChatQueue_CompleteItem(item, "cancelled")
            return
        }
        if (result = 1) {
            if (item.Source = "AutoReport")
                AutoReportSentCount++
            if (!AuditTestMode && !item.HasKey("Kind"))
                Evidence_MaybeCaptureReportText(item.Text)
            ChatQueueLastSendTick := TickNow()
            ChatQueueNextSendTick := TickNow() + (item.DelayAfter = "" ? ChatQueueMinDelay : item.DelayAfter)
            ChatQueue_CompleteItem(item, "sent")
        } else if (result != -2 && !item.HasKey("Kind") && !IsObject(g_RemoteOperation) && item.Tries < ChatQueueMaxRetries) {
            item.Tries++
            ChatQueueItems.InsertAt(1, item)
            ChatQueueNextSendTick := TickNow() + 1000
        } else {
            QueueFailureGeneration++
            if (item.Source = "AutoReport")
                AutoReportSkippedCount++
            ChatQueue_CompleteItem(item, result = -2 || IsObject(g_RemoteOperation) ? "unknown" : "failed")
            LogError(item.Source, "Отправка не подтверждена; остаток операции отменён: " . item.Text, "ERROR")
            ChatQueueNextSendTick := TickNow() + ChatQueueMinDelay
        }
    } catch e {
        QueueFailureGeneration++
        ChatQueue_CompleteItem(item, "failed")
        LogError("ChatQueue", e.Message, "ERROR")
    } finally {
        ChatQueueBusy := 0
        if (!AuditTestMode)
            UpdateHUD()
    }
}

ChatQueue_EnqueueSequence(sequenceText, source := "Sequence", delayAfter := 700) {
    lines := []
    sequenceText := StrReplace(StrReplace(sequenceText, "`r`n", "`n"), "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        if (Trim(A_LoopField) != "")
            lines.Push(ApplyActionTemplate(Trim(A_LoopField)))
    }
    return ChatQueue_EnqueueBatch(lines, source, delayAfter) ? lines.Length() : 0
}

ChatQueue_TrySend(text, source := "ChatQueue") {
    epoch := AutomationEpoch
    result := ChatTransport_Send(text, source)
    if (result = 1 && epoch = AutomationEpoch)
        Evidence_MaybeCaptureReportText(text)
    return result = 1
}

ChatQueue_EnqueueMockDemo() {
    ChatQueue_Enqueue("/me проверил работу очереди сообщений.", "MockDemo", 1)
    ChatQueue_Enqueue("/do Первая строка доставлена без запуска GTA/SAMP.", "MockDemo", 1)
    ChatQueue_Enqueue("/r Тест очереди AHK FOR GOS BY SBEZRUK завершён.", "MockDemo", 1)
    MockPreview_Show()
    UpdateAutomationSettingsStatus()
    return 3
}

CancelAllAutomation(showStatus := 1) {
    ServiceUI_CancelInput("cancel-all")
    IDCapture_Complete("cancel")
    global ChatWizardMode, EvidenceScreenshotQueue, EvidencePendingEvents, EvidenceDocumentContext, EvidenceDocumentWindowExpires
    StopCustomFunctionRun(0)
    HideStopTimerGUI()
    EvidenceScreenshotQueue := []
    EvidencePendingEvents := {}
    EvidenceDocumentContext := {}
    EvidenceDocumentWindowExpires := 0
    ChatLogReader_ResetGeneration()
    SetTimer, EvidenceScreenshotTimer, Off
    ; Input with no active legacy reader returns 1; inside a caller's try it throws.
    ; Cancellation must stay idempotent without swallowing other input errors.
    try {
        Input
    } catch inputError {
        if (inputError.What != "Input" || inputError.Message != "1")
            throw inputError
    }
    ChatWizardMode := ""
    StopMDSFormationCountdown(0)
    AutoReport_Stop(0, "cancel-all")
    TaskScheduler_CancelAll()
    ChatQueue_Clear(0)
    ActionTimer_Clear()
    ContextAssistant_Close()
    UpdateHUD()
    UpdateAutomationSettingsStatus()
    if (showStatus)
    {
        ServiceUI_Notify("Активные автоматизации остановлены.", 1600)
    }
}

StopMDSFormationCountdown(showStatus := 1) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    TaskScheduler_Cancel("MDSFormation")
    MDSFormationActive := 0
    MDSFormationEndTick := 0
    MDSFormationLastMinute := -1

    if (showStatus)
    {
        Notify("info")
        ServiceUI_Notify("Строй остановлен.", 1600)
    }
    UpdateHUD()
}

StartMDSFormationCountdown(minutes) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    StopMDSFormationCountdown(0)
    MDSFormationActive := 1
    MDSFormationEndTick := TickNow() + minutes * 60000
    MDSFormationLastMinute := minutes

    ChatQueue_Enqueue(MDSFormationInitialText(minutes), "MDSFormation")
    TaskScheduler_Set("MDSFormation", minutes * 60000, "MDSFormation", "Строй")
    Notify("info")
    ServiceUI_Notify("Строй запущен на " . FormatRussianMinutes(minutes) . ". Повторный вызов остановит отсчёт.", 2200)
    UpdateHUD()
}

HandleMDSFormationTimerTick(finishOnly := 0) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    if (!MDSFormationActive)
        return

    millisecondsLeft := TaskScheduler_RemainingMs(MDSFormationEndTick)
    if (finishOnly || millisecondsLeft <= 0)
    {
        ChatQueue_Enqueue(MDSFormationFinishText(), "MDSFormation")
        StopMDSFormationCountdown(0)
        Notify("info")
        ServiceUI_Notify("Время сбора в строй истекло.", 1800)
        return
    }

    minutesLeft := Ceil(millisecondsLeft / 60000.0)
    if (minutesLeft >= MDSFormationLastMinute)
        return

    MDSFormationLastMinute := minutesLeft
    ChatQueue_Enqueue(MDSFormationCountdownText(minutesLeft), "MDSFormation")
}

ToggleMDSFormationCountdown() {
    global MDSFormationActive

    if (MDSFormationActive)
    {
        StopMDSFormationCountdown(1)
        return
    }

    minutes := ReadMDSFormationMinutes()
    if (minutes > 0)
        StartMDSFormationCountdown(minutes)
}

ChatQueue_Clear(showStatus := 1) {
    global ChatQueueItems, ChatQueueBusy, ChatQueueNextSendTick, ChatQueueLastSendTick
    ChatQueueItems := []
    AutomationEpoch++
    ChatQueue_CancelBatches()
    ChatQueueNextSendTick := 0
    ChatQueueLastSendTick := 0
    if (showStatus)
    {
        ServiceUI_Notify("Очередь сообщений очищена.", 1400)
    }
    UpdateHUD()
    UpdateAutomationSettingsStatus()
}

ActionTimer_EnterCritical(ByRef previousState) {
    previousState := A_IsCritical
    if (!previousState)
        Critical, On
}

ActionTimer_LeaveCritical(previousState) {
    if (!previousState)
        Critical, Off
}

ActionTimer_IsEnabled(kind) {
    global EvacuationTimerEnabled, PatrolTimerEnabled, PostTimerEnabled
    if (kind = "Evac" || kind = "Эвакуация")
        return EvacuationTimerEnabled = "On"
    if (kind = "Patrol" || kind = "Патруль")
        return PatrolTimerEnabled = "On"
    if (kind = "Post" || kind = "Пост")
        return PostTimerEnabled = "On"
    return false
}

ActionTimer_Count() {
    global ActionTimerItems
    count := 0
    if IsObject(ActionTimerItems)
        for token, item in ActionTimerItems
            count += 1
    return count
}

ActionTimer_FormatSeconds(seconds) {
    seconds := Ceil(seconds + 0)
    if (seconds < 0)
        seconds := 0
    hours := Floor(seconds / 3600)
    minutes := Floor(Mod(seconds, 3600) / 60)
    secs := Mod(seconds, 60)
    if (hours > 0)
        return Format("{:02}:{:02}:{:02}", hours, minutes, secs)
    return Format("{:02}:{:02}", minutes, secs)
}

ActionTimer_Start(token, label, durationSec, timerMode := "Manual", exactEndTick := "") {
    global ActionTimerItems, MockMode
    token := Trim(token)
    durationSec := Floor(durationSec + 0)
    ActionTimer_EnterCritical(previousCritical)
    if (token = "" || durationSec < 1 || !ActionTimer_IsEnabled(token) || MockMode = "On")
    {
        ActionTimer_LeaveCritical(previousCritical)
        return false
    }
    if !IsObject(ActionTimerItems)
        ActionTimerItems := {}
    endTick := (exactEndTick = "") ? TickNow() + durationSec * 1000 : exactEndTick + 0
    ActionTimerItems[token] := {Label: label, EndTick: endTick, Mode: timerMode}
    SetTimer, ActionTimerTick, 1000
    ActionTimer_Render()
    if (ActionTimer_Count() < 1)
        SetTimer, ActionTimerTick, Off
    ActionTimer_LeaveCritical(previousCritical)
    return true
}

ActionTimer_StartEvacuation() {
    return ActionTimer_Start("Evac", "ЭВАКУАЦИЯ · ОЖИДАНИЕ", 180)
}

ActionTimer_StartManualService(mode) {
    global AutoReportActive, AutoReportMode, AutoReportEndTick
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        return false
    ActionTimer_EnterCritical(previousCritical)
    token := (mode = "Пост") ? "Post" : "Patrol"
    if (AutoReportActive && AutoReportMode = mode && TaskScheduler_RemainingMs(AutoReportEndTick) > 0)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return true
    }
    label := (mode = "Пост") ? "ПОСТ · ДО ДОКЛАДА" : "ПАТРУЛЬ · ДО ДОКЛАДА"
    started := ActionTimer_Start(token, label, 600)
    ActionTimer_LeaveCritical(previousCritical)
    return started
}

ActionTimer_StartAutoReport(mode) {
    global AutoReportEndTick
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        return false
    ActionTimer_EnterCritical(previousCritical)
    token := (mode = "Пост") ? "Post" : "Patrol"
    label := (mode = "Пост") ? "АВТОПОСТ" : "АВТОПАТРУЛЬ"
    durationSec := Ceil(TaskScheduler_RemainingMs(AutoReportEndTick) / 1000.0)
    if (durationSec < 1)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return false
    }
    started := ActionTimer_Start(token, label, durationSec, "AutoReport", AutoReportEndTick)
    ActionTimer_LeaveCritical(previousCritical)
    return started
}

ActionTimer_Stop(token, redraw := 1, expectedMode := "") {
    global ActionTimerItems
    ActionTimer_EnterCritical(previousCritical)
    removed := false
    if IsObject(ActionTimerItems) && ActionTimerItems.HasKey(token)
    {
        item := ActionTimerItems[token]
        if (expectedMode = "" || item.Mode = expectedMode)
        {
            ActionTimerItems.Delete(token)
            removed := true
        }
    }
    if (redraw)
        ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
    return removed
}

ActionTimer_Clear() {
    global ActionTimerItems
    ActionTimer_EnterCritical(previousCritical)
    ActionTimerItems := {}
    ActionTimer_Hide()
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_ReconcileSettings() {
    global ActionTimerItems, AutoReportActive, AutoReportMode
    ActionTimer_EnterCritical(previousCritical)
    if !IsObject(ActionTimerItems)
        ActionTimerItems := {}
    if !ActionTimer_IsEnabled("Evac")
        ActionTimerItems.Delete("Evac")
    if !ActionTimer_IsEnabled("Patrol")
        ActionTimerItems.Delete("Patrol")
    if !ActionTimer_IsEnabled("Post")
        ActionTimerItems.Delete("Post")
    if (AutoReportActive && ActionTimer_IsEnabled(AutoReportMode))
        ActionTimer_StartAutoReport(AutoReportMode)
    ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_PruneExpired(notifyUser := 1) {
    global ActionTimerItems
    if !IsObject(ActionTimerItems)
        return 0
    nowTick := TickNow()
    expired := []
    for token, item in ActionTimerItems
        if (TaskScheduler_RemainingMs(item.EndTick, nowTick) <= 0)
            expired.Push({Token: token, Item: item})
    shouldSound := false
    Loop % expired.Length()
    {
        expiredEntry := expired[A_Index]
        token := expiredEntry.Token
        item := expiredEntry.Item
        ActionTimerItems.Delete(token)
        if (!notifyUser || item.Mode = "AutoReport")
            continue
        if (token = "Evac")
            message := "3 минуты ожидания эвакуации истекли."
        else if (token = "Post")
            message := "10 минут на посту истекли — пора отправить доклад."
        else
            message := "10 минут патруля истекли — пора отправить доклад."
        GameNotify(message, "INFO")
        shouldSound := true
    }
    if (shouldSound)
        PlayStopTimerSound()
    return expired.Length()
}

ActionTimer_BuildBody(nowTick, ByRef lineCount) {
    global ActionTimerItems, AutoReportActive, AutoReportMode, AutoReportNextTick, AutoReportEndTick
    body := ""
    lineCount := 0
    order := ["Evac", "Patrol", "Post"]
    Loop % order.Length()
    {
        token := order[A_Index]
        if !IsObject(ActionTimerItems) || !ActionTimerItems.HasKey(token)
            continue
        item := ActionTimerItems[token]
        remainingSec := Ceil(TaskScheduler_RemainingMs(item.EndTick, nowTick) / 1000.0)
        if (remainingSec < 0)
            remainingSec := 0
        if (body != "")
            body .= "`n"
        body .= item.Label . "   " . ActionTimer_FormatSeconds(remainingSec)
        lineCount += 1
        expectedMode := (token = "Post") ? "Пост" : "Патруль"
        if (item.Mode = "AutoReport" && AutoReportActive && AutoReportMode = expectedMode)
        {
            nextText := "завершение"
            if (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= TaskScheduler_RemainingMs(AutoReportEndTick, nowTick))
            {
                nextSec := Ceil(TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) / 1000.0)
                if (nextSec < 0)
                    nextSec := 0
                nextText := ActionTimer_FormatSeconds(nextSec)
            }
            body .= "`nСЛЕДУЮЩИЙ ДОКЛАД   " . nextText
            lineCount += 1
        }
    }
    return body
}

ActionTimer_Hide(keepTick := 0) {
    global hActionTimerWnd, ActionTimerLastHeight, ActionTimerX, ActionTimerY
    ActionTimer_EnterCritical(previousCritical)
    if (!keepTick)
        SetTimer, ActionTimerTick, Off
    if (hActionTimerWnd && DllCall("IsWindow", "Ptr", hActionTimerWnd))
    {
        WinGetPos, currentX, currentY,,, ahk_id %hActionTimerWnd%
        if (currentX != "")
            ActionTimerX := currentX, ActionTimerY := currentY
    }
    Gui, ActionTimers:Destroy
    hActionTimerWnd := 0
    ActionTimerLastHeight := 0
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_Render() {
    global ActionTimerRenderBusy
    wasCritical := A_IsCritical
    if (!wasCritical)
        Critical, On
    if (ActionTimerRenderBusy)
    {
        if (!wasCritical)
            Critical, Off
        return
    }
    ActionTimerRenderBusy := 1
    try
        ActionTimer_RenderCore()
    catch e
    {
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("ActionTimer", "Render failed: " . errorText, "ERROR")
    }
    finally
    {
        ActionTimerRenderBusy := 0
        if (!wasCritical)
            Critical, Off
    }
}

ActionTimer_RenderCore() {
    global hActionTimerWnd, ActionTimerBody, ActionTimerLastHeight, ActionTimerX, ActionTimerY
    global StopTimerWidth, StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor, UIRoundness
    ActionTimer_PruneExpired(1)
    if (ActionTimer_Count() < 1)
    {
        ActionTimer_Hide()
        return
    }

    nowTick := TickNow()
    body := ActionTimer_BuildBody(nowTick, lineCount)
    if (body = "")
    {
        ActionTimer_Hide()
        return
    }
    ActionTimerBody := body
    overlayW := StopTimerWidth + 150
    NormalizeNumberRange(overlayW, 320, 300, 520)
    overlayH := 42 + lineCount * 24
    NormalizeNumberRange(overlayH, 90, 66, 170)
    NormalizeNumberRange(ActionTimerX, 100, -4000, 8000)
    NormalizeNumberRange(ActionTimerY, 180, -4000, 8000)

    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    borderColor := (StopTimerBorderColor != "") ? StopTimerBorderColor : accent
    timerTextColor := (StopTimerTextColor != "") ? StopTimerTextColor : textColor
    timerBgColor := (StopTimerBgColor != "") ? StopTimerBgColor : panel
    alpha := StopTimerTransparency
    NormalizeNumberRange(alpha, 255, 120, 255)

    needsCreate := !hActionTimerWnd || !DllCall("IsWindow", "Ptr", hActionTimerWnd) || ActionTimerLastHeight != overlayH
    if (needsCreate)
    {
        if (hActionTimerWnd)
            ActionTimer_Hide(1)
        bottomY := overlayH - 2
        rightX := overlayW - 2
        bodyH := overlayH - 34
        headerW := overlayW - 20
        bodyW := overlayW - 24
        Gui, ActionTimers:New, +HwndhActionTimerWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +Border +LastFound
        Gui, ActionTimers:Color, %timerBgColor%
        Gui, ActionTimers:Margin, 0, 0
        Gui, ActionTimers:Add, Progress, -Theme x0 y0 w%overlayW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x0 y%bottomY% w%overlayW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x0 y0 w2 h%overlayH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x%rightX% y0 w2 h%overlayH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Font, s8 Bold c%borderColor%, Segoe UI
        Gui, ActionTimers:Add, Text, x10 y5 w%headerW% h22 Center 0x200 gStartActionTimerDrag BackgroundTrans, ТАЙМЕРЫ ДЕЙСТВИЙ
        Gui, ActionTimers:Font, s11 Bold c%timerTextColor%, Segoe UI
        Gui, ActionTimers:Add, Text, x12 y30 w%bodyW% h%bodyH% Center 0x200 gStartActionTimerDrag vActionTimerBody BackgroundTrans, %body%
        ActionTimerLastHeight := overlayH
        showOpts := "x" . ActionTimerX . " y" . ActionTimerY . " w" . overlayW . " h" . overlayH . " NoActivate"
        Capture_BeforeShow("ActionTimers")
        Gui, ActionTimers:Show, %showOpts%, ActionTimers
        WinSet, Transparent, %alpha%, ahk_id %hActionTimerWnd%
        WinSet, AlwaysOnTop, On, ahk_id %hActionTimerWnd%
        ApplyRoundedCorners(hActionTimerWnd, UIRoundness)
    }
    else
        GuiControl, ActionTimers:, ActionTimerBody, %body%
}

ActionTimer_Rebuild() {
    ActionTimer_EnterCritical(previousCritical)
    if (ActionTimer_Count() < 1)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return
    }
    ActionTimer_Hide(1)
    ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
}
