; Bounded, in-process execution journal. A sent step means delivery to the local
; client/keyboard transport, not a server acknowledgement. No game polling here.
global ActionTraceRecords := {}
global ActionTraceOrder := []
global ActionTraceNextId := 0
global ActionTraceLastId := 0
global ActionTraceVisible := 0
global hActionTraceWnd := 0
global ActionTraceSelectedId := 0
global ActionTraceSelectedStep := 0
global ActionTraceRows := []
global ActionTraceRenderedId := 0
global ActionTraceRenderedRows := []
global ActionTraceRetryBusy := 0
global ActionTraceHistoryText := ""

ActionTrace_Begin(source, expectedSteps := 0) {
    global ActionTraceRecords, ActionTraceOrder, ActionTraceNextId, ActionTraceLastId
    if !IsObject(ActionTraceRecords)
        ActionTraceRecords := {}
    if !IsObject(ActionTraceOrder)
        ActionTraceOrder := []
    id := ++ActionTraceNextId
    record := {Id: id, Source: SubStr(source . "", 1, 120), Steps: [], Total: 0
        , Expected: Max(0, Floor(expectedSteps + 0)), Observed: 0, State: "running"
        , Epoch: AutomationEpoch, Profile: CurrentProfile, Target: UserID . ""
        , Mock: MockMode = "On" || AuditTestMode || Training_IsActive(), Started: TickNow(), Finished: 0
        , Stamp: A_Hour . ":" . A_Min . ":" . A_Sec, Detail: ""}
    ActionTraceRecords[id] := record
    ActionTraceOrder.Push(id)
    ActionTraceLastId := id
    ; Prefer completed records so a long scenario keeps its parent journal.
    ; If all 24 records are active, the oldest still yields to the strict cap.
    while (ActionTraceOrder.Length() > 24) {
        removeIndex := 1
        for index, candidate in ActionTraceOrder {
            if (ActionTraceRecords[candidate].State != "running") {
                removeIndex := index
                break
            }
        }
        ActionTraceRecords.Delete(ActionTraceOrder.RemoveAt(removeIndex))
    }
    ActionTrace_Changed()
    return id
}

ActionTrace_Get(id) {
    global ActionTraceRecords
    return IsObject(ActionTraceRecords) && ActionTraceRecords.HasKey(id) ? ActionTraceRecords[id] : ""
}

ActionTrace_Add(id, kind, text, retryable := false) {
    record := ActionTrace_Get(id)
    if !IsObject(record)
        return 0
    record.Total++
    if (record.Steps.Length() >= 120)
        return 0
    original := text . ""
    record.Steps.Push({Kind: SubStr(kind . "", 1, 24), Text: SubStr(original, 1, 1023)
        , Status: "queued", Detail: "", Tries: 0, Replayed: 0
        , Retryable: retryable && StrLen(original) <= 1023 && ActionTrace_IsRetrySafeText(original)})
    ActionTrace_Changed()
    return record.Steps.Length()
}

ActionTrace_Update(id, index, status, detail := "") {
    record := ActionTrace_Get(id)
    if (!IsObject(record) || index < 1 || index > record.Steps.Length())
        return false
    if !ActionTrace_IsStatus(status)
        return false
    step := record.Steps[index]
    ; A later logging/callback exception must not relabel an actual send as an
    ; unsent line. This also prevents replay after cancellation races.
    if (step.Status = "sent" && status != "sent")
        return false
    step.Status := status
    step.Detail := SubStr(detail . "", 1, 1000)
    if (status = "unknown" || status = "cancelled" || status = "skipped")
        step.Retryable := false
    ActionTrace_Changed()
    return true
}

ActionTrace_Rejected(source, reason, notify := false) {
    id := ActionTrace_Begin(source, 1)
    step := ActionTrace_Add(id, "CHECK", "Проверки перед действием", false)
    ActionTrace_Update(id, step, "failed", reason)
    ActionTrace_Finish(id, "failed", reason)
    if (notify)
        SafeWarn(reason)
    return false
}

ActionTrace_QueueTransportResult(item, result) {
    if (!IsObject(item) || result != 1)
        return
    record := ActionTrace_Get(item.TraceId)
    if IsObject(record)
        ActionTrace_Update(item.TraceId, item.TraceIndex, "sent", record.Mock || item.ForceMock ? "Учебный / Mock: показано без отправки в игру." : "Транспорт выполнил отправку; ответ сервера не проверялся.")
}

ActionTrace_IsStatus(status) {
    return status = "queued" || status = "running" || status = "sent" || status = "done"
        || status = "failed" || status = "unknown" || status = "cancelled" || status = "skipped"
}

ActionTrace_Finish(id, status, detail := "") {
    global ActionTraceLastId
    record := ActionTrace_Get(id)
    if (!IsObject(record) || !ActionTrace_IsStatus(status) || status = "queued" || status = "running")
        return false
    if (record.State != "running")
        return false
    record.State := status
    ActionTraceLastId := id
    record.Finished := TickNow()
    record.Detail := SubStr(detail . "", 1, 1000)
    for index, step in record.Steps {
        if (step.Status = "queued")
            ActionTrace_Update(id, index, status = "cancelled" ? "cancelled" : "skipped", "Продолжение операции не выполнялось.")
        else if (step.Status = "running")
            ActionTrace_Update(id, index, status = "cancelled" ? "cancelled" : "unknown", "Выполнение прервано; повтор запрещён.")
    }
    ActionTrace_Changed()
    return true
}

ActionTrace_IsRetrySafeText(text) {
    ; Mechanical gameplay commands depend on preconditions specific to their
    ; original action. Generic replay cannot safely re-create those conditions.
    if (text = "" || StrLen(text) > 1023 || InStr(text, "`n") || InStr(text, "`r"))
        return false
    return SubStr(LTrim(text), 1, 1) != "/"
        || RegExMatch(LTrim(text), "i)^/(?:me|do|todo|r|d|f|b|s|w|rb|fb|gov)\s+\S")
}

ActionTrace_RegisterBatch(batchId, prepared) {
    if (!IsObject(prepared) || !prepared.Length() || !QueueBatchStates.HasKey(batchId))
        return 0
    first := prepared[1]
    id := ActionTrace_Begin(first.Source, prepared.Length())
    QueueBatchStates[batchId].TraceId := id
    for _, item in prepared {
        kind := item.HasKey("Kind") ? item.Kind : (item.Role = "RP" ? "RP" : "CHAT")
        text := kind = "Menu" ? JoinStrings(item.Steps, " > ") : item.Text
        item.TraceId := id
        item.TraceIndex := ActionTrace_Add(id, kind, text, false)
        item.TraceKnownUnsent := false
        item.TraceReason := ""
    }
    return id
}

ActionTrace_RegisterItem(item) {
    if !IsObject(item)
        return 0
    item.TraceId := ActionTrace_Begin(item.Source, 1)
    if (item.ForceMock)
        ActionTraceRecords[item.TraceId].Mock := true
    item.TraceIndex := ActionTrace_Add(item.TraceId, "CHAT", item.Text, false)
    item.TraceKnownUnsent := false
    item.TraceReason := ""
    return item.TraceId
}

ActionTrace_QueueAttempt(item) {
    if (!IsObject(item) || !item.TraceId)
        return
    record := ActionTrace_Get(item.TraceId)
    if (!IsObject(record) || record.State != "running")
        return
    item.TraceKnownUnsent := false
    item.TraceReason := ""
    if (item.TraceIndex > 0 && item.TraceIndex <= record.Steps.Length())
        record.Steps[item.TraceIndex].Tries++
    ActionTrace_Update(item.TraceId, item.TraceIndex, "running", "Попытка " . (item.Tries + 1) . ".")
}

ActionTrace_QueueRetryPending(item) {
    if IsObject(item)
        ActionTrace_Update(item.TraceId, item.TraceIndex, "queued", "Вызов не запускался. Ожидание автоматического повтора: " . item.TraceReason)
}

ActionTrace_QueueComplete(item, result) {
    if (!IsObject(item) || !item.TraceId)
        return
    record := ActionTrace_Get(item.TraceId)
    if (!IsObject(record) || record.State != "running")
        return
    detail := item.TraceReason
    if (result = "sent")
        detail := record.Mock ? "Учебный / Mock: показано без отправки в игру." : "Транспорт выполнил отправку. Ответ сервера этим не подтверждается."
    else if (detail = "")
        detail := result = "cancelled" ? "Операция или её контекст отменены." : "Причина не предоставлена транспортом; повтор запрещён."
    if (item.TraceIndex > 0 && item.TraceIndex <= record.Steps.Length()) {
        step := record.Steps[item.TraceIndex]
        step.Retryable := result = "failed" && item.TraceKnownUnsent && !item.HasKey("Kind") && ActionTrace_IsRetrySafeText(step.Text)
    }
    ActionTrace_Update(item.TraceId, item.TraceIndex, result, detail)
    record.Observed++
    if (result != "sent")
        ActionTrace_Finish(item.TraceId, result, detail)
    else if (record.Observed >= record.Expected)
        ActionTrace_Finish(item.TraceId, "done", record.Mock ? "Все шаги показаны в Mock без отправки." : "Все шаги переданы клиенту. Подтверждение сервера не проверялось.")
}

ActionTrace_CancelBatch(batchId, reason := "Последовательность отменена.") {
    if (QueueBatchStates.HasKey(batchId) && QueueBatchStates[batchId].TraceId)
        ActionTrace_Finish(QueueBatchStates[batchId].TraceId, "cancelled", reason)
}

ActionTrace_RecordTransport(id, index, result, status := "") {
    record := ActionTrace_Get(id)
    if !IsObject(record)
        return
    label := result = 1 ? "sent" : (result = -2 ? "unknown" : "failed")
    if (result = 1)
        status := record.Mock ? "Учебный / Mock: показано без отправки в игру." : "Отправка выполнена транспортом; это не ответ сервера."
    else if (status = "")
        status := result = -2 ? "Вызов мог начаться. Повтор запрещён." : "Отправка не выполнена."
    if (index > 0 && index <= record.Steps.Length())
        record.Steps[index].Retryable := result = -1 && ActionTrace_IsRetrySafeText(record.Steps[index].Text)
    ActionTrace_Update(id, index, label, status)
    if (record.Epoch != AutomationEpoch || record.Profile != CurrentProfile || "ID:" . record.Target != "ID:" . UserID)
        ActionTrace_Finish(id, "cancelled", "Контекст изменился во время вызова; зависимые шаги отменены.")
    else
        ActionTrace_Finish(id, result = 1 ? "done" : label, status)
}

ActionTrace_CanRetry(id, index, ByRef reason, requireIdle := true) {
    reason := ""
    record := ActionTrace_Get(id)
    if (!IsObject(record) || index < 1 || index > record.Steps.Length())
        reason := "Выберите шаг в сохранённой операции."
    else if (record.State = "running")
        reason := "Операция ещё выполняется."
    else {
        step := record.Steps[index]
        if (step.Status != "failed" || !step.Retryable || step.Replayed)
            reason := "Повтор доступен только для точно неотправленного сообщения. Команды игры, меню и неопределённые вызовы запрещены."
        else if (record.Epoch != AutomationEpoch || record.Profile != CurrentProfile || "ID:" . record.Target != "ID:" . UserID
            || !!record.Mock != !!(MockMode = "On" || AuditTestMode || Training_IsActive()))
            reason := "Профиль, цель или режим изменились; повтор из старого контекста запрещён."
        else if (requireIdle && (ChatQueue_Count() || ChatQueueBusy || PhysicalInputBusy || IsObject(IDCaptureState)
            || ServiceUI_IsInputActive() || IsObject(GameMenuStarting) || IsObject(GameMenuLease)
            || IsObject(g_RemoteOperation) || IsObject(CustomFunctionRunState)))
            reason := "Завершите текущий ввод и другие автоматизации перед повтором."
    }
    return reason = ""
}

ActionTrace_RetryStep(id, index, askConfirmation := true) {
    global ActionTraceRetryBusy
    if (ActionTraceRetryBusy)
        return false
    ActionTraceRetryBusy := 1
    try {
        if !ActionTrace_CanRetry(id, index, reason) {
            ServiceUI_Notify(reason, 4000, "WARN")
            return false
        }
        record := ActionTrace_Get(id), step := record.Steps[index]
        if (askConfirmation && !ServiceUI_Confirm("Повтор одного сообщения", "Отправить только выбранную строку?`nВыполненные и зависимые шаги не повторяются.`n`n" . step.Text))
            return false
        if !ActionTrace_CanRetry(id, index, reason)
            return false
        if (!record.Mock) {
            if !GameLocator_Find(gamePID, gameSelector, locatorSource)
                return false
            ActionTrace_Close()
            WinActivate, %gameSelector%
            WinWaitActive, %gameSelector%,, 0.5
            if (!GameLocator_IsActive() || !ActionTrace_CanRetry(id, index, reason))
                return false
        }
        if !CanRunAction("Повтор сообщения", record.Target != "", true)
            return false
        ; The batch has one immutable, already-rendered line. Never resume the
        ; rest of a failed RP chain or interpolate with a new target/profile.
        previous := A_IsCritical
        Critical, On
        try {
            if !ActionTrace_CanRetry(id, index, reason)
                return false
            batchId := ChatQueue_EnqueueBatch([step.Text], "Повтор: " . record.Source, 0)
            if (!batchId)
                return false
            step.Replayed := 1
            step.Detail .= "`nНа повтор поставлена только эта строка; зависимые шаги не возобновлялись."
        } finally {
            Critical, %previous%
        }
        ActionTrace_Changed()
        return true
    } finally {
        ActionTraceRetryBusy := 0
    }
}

ActionTrace_StatusLabel(status) {
    static labels := {queued: "Ожидает", running: "Выполняется", sent: "Передано клиенту", done: "Завершено"
        , failed: "Не выполнено", unknown: "Результат неизвестен", cancelled: "Отменено", skipped: "Пропущено"}
    return labels.HasKey(status) ? labels[status] : status
}

ActionTrace_Changed() {
    global ActionTraceVisible
    if (ActionTraceVisible)
        SetTimer, ActionTrace_Refresh, -40
}

ActionTrace_Open(params*) {
    global ActionTraceVisible, hActionTraceWnd, ActionTraceSelectedId, ActionTraceSelectedStep
    global ActionTraceLastId, ActionTraceRenderedId, ActionTraceRenderedRows, ActionTraceHistoryText
    global AT_History, AT_Steps, AT_Detail, AT_Summary, AT_Retry
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(controlBg, controlText, cardBg, cardEdge, panel, fg, accent)
    Gui, ActionTrace:Destroy
    Gui, ActionTrace:New, +HwndhActionTraceWnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
    Gui, ActionTrace:Color, %bg%, %controlBg%
    Gui, ActionTrace:Margin, 20, 16
    Gui, ActionTrace:Font, s16 Bold c%fg%, Segoe UI
    Gui, ActionTrace:Add, Text, x20 y16 w890 h30 BackgroundTrans, Результат действий
    Gui, ActionTrace:Font, s9 Norm c%muted%, Segoe UI
    Gui, ActionTrace:Add, Text, x20 y52 w890 h40 +Wrap BackgroundTrans, Последние 24 операции. Передано клиенту не означает подтверждение сервера. Повтор разрешён только для безопасных сообщений, которые точно не были отправлены.
    Gui, ActionTrace:Font, s9 Norm c%controlText%, Segoe UI
    Gui, ActionTrace:Add, ListBox, x20 y102 w255 h318 vAT_History gActionTrace_HistoryChanged AltSubmit
    Gui, ActionTrace:Add, ListView, x289 y102 w621 h318 vAT_Steps gActionTrace_StepChanged AltSubmit -Multi -LV0x10, №|Шаг|Результат|Содержание
    Gui, ActionTrace:Font, s9 Norm c%fg%, Segoe UI
    Gui, ActionTrace:Add, Text, x20 y434 w890 h42 vAT_Summary +Wrap BackgroundTrans
    Gui, ActionTrace:Font, s10 Norm c%controlText%, Consolas
    Gui, ActionTrace:Add, Edit, x20 y486 w890 h140 vAT_Detail ReadOnly -Wrap
    Gui, ActionTrace:Font, s9 Norm c%fg%, Segoe UI
    Gui, ActionTrace:Add, Button, x20 y642 w160 h36 gActionTrace_SelectLatest, Последняя операция
    Gui, ActionTrace:Add, Button, x194 y642 w195 h36 vAT_Retry gActionTrace_RetrySelected, Повторить выбранный шаг
    Gui, ActionTrace:Add, Button, x760 y642 w150 h36 gActionTrace_Close, Закрыть
    ActionTraceSelectedId := ActionTraceLastId, ActionTraceSelectedStep := 0
    ActionTraceRenderedId := 0, ActionTraceRenderedRows := [], ActionTraceHistoryText := ""
    ActionTraceVisible := 1
    Capture_BeforeShow("ActionTrace")
    ActionTrace_Refresh()
    Gui, ActionTrace:Show, % "w930 h696" . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), AHK FOR GOS - Результат действий
    return true
}

ActionTrace_Close(params*) {
    global ActionTraceVisible, hActionTraceWnd
    SetTimer, ActionTrace_Refresh, Off
    ActionTraceVisible := 0
    hActionTraceWnd := 0
    Gui, ActionTrace:Destroy
}

ActionTrace_SelectLatest(params*) {
    global ActionTraceSelectedId, ActionTraceSelectedStep, ActionTraceLastId
    ActionTraceSelectedId := ActionTraceLastId, ActionTraceSelectedStep := 0
    ActionTrace_Refresh()
}

ActionTrace_HistoryChanged(params*) {
    global ActionTraceRows, ActionTraceSelectedId, ActionTraceSelectedStep
    GuiControlGet, row, ActionTrace:, AT_History
    if (row > 0 && row <= ActionTraceRows.Length()) {
        ActionTraceSelectedId := ActionTraceRows[row]
        ActionTraceSelectedStep := 0
        ActionTrace_Refresh()
    }
}

ActionTrace_StepChanged(controlHwnd := 0, guiEvent := "", eventInfo := 0, eventError := "") {
    global ActionTraceSelectedStep
    if (guiEvent = "Normal" || guiEvent = "I" || guiEvent = "DoubleClick") {
        if (eventInfo > 0)
            ActionTraceSelectedStep := eventInfo
        ActionTrace_RenderDetail()
    }
}

ActionTrace_RetrySelected(params*) {
    global ActionTraceSelectedId, ActionTraceSelectedStep
    return ActionTrace_RetryStep(ActionTraceSelectedId, ActionTraceSelectedStep)
}

ActionTrace_Refresh(params*) {
    global ActionTraceVisible, hActionTraceWnd, ActionTraceOrder, ActionTraceRows
    global ActionTraceSelectedId, ActionTraceSelectedStep, ActionTraceLastId
    global ActionTraceRenderedId, ActionTraceRenderedRows, ActionTraceHistoryText
    if (!ActionTraceVisible || !DllCall("IsWindow", "Ptr", hActionTraceWnd))
        return
    rows := [], list := "", selectedRow := 0
    Loop % ActionTraceOrder.Length() {
        id := ActionTraceOrder[ActionTraceOrder.Length() - A_Index + 1]
        record := ActionTrace_Get(id)
        if !IsObject(record)
            continue
        rows.Push(id)
        list .= (list = "" ? "" : "|") . record.Stamp . " " . StrReplace(record.Source, "|", "/") . " - " . ActionTrace_StatusLabel(record.State)
        if (id = ActionTraceSelectedId)
            selectedRow := rows.Length()
    }
    ActionTraceRows := rows
    if (ActionTraceHistoryText != list) {
        GuiControl, ActionTrace:, AT_History, % "|" . list
        ActionTraceHistoryText := list
    }
    if (!selectedRow && rows.Length())
        selectedRow := 1, ActionTraceSelectedId := rows[1], ActionTraceSelectedStep := 0
    if (selectedRow)
        GuiControl, ActionTrace:Choose, AT_History, %selectedRow%
    record := ActionTrace_Get(ActionTraceSelectedId)
    previousGui := A_DefaultGui
    Gui, ActionTrace:Default
    Gui, ActionTrace:ListView, AT_Steps
    try {
        if (ActionTraceRenderedId != ActionTraceSelectedId) {
            LV_Delete()
            ActionTraceRenderedRows := []
            ActionTraceRenderedId := ActionTraceSelectedId
        }
        if IsObject(record) {
            for index, step in record.Steps {
                shortText := SubStr(StrReplace(StrReplace(step.Text, "`r", " "), "`n", " "), 1, 160)
                signature := step.Kind . "|" . step.Status . "|" . shortText
                if (index > ActionTraceRenderedRows.Length()) {
                    LV_Add("", index, step.Kind, ActionTrace_StatusLabel(step.Status), shortText)
                    ActionTraceRenderedRows.Push(signature)
                } else if (ActionTraceRenderedRows[index] != signature) {
                    LV_Modify(index, "", index, step.Kind, ActionTrace_StatusLabel(step.Status), shortText)
                    ActionTraceRenderedRows[index] := signature
                }
            }
            if (!ActionTraceSelectedStep && record.Steps.Length())
                ActionTraceSelectedStep := 1
            if (ActionTraceSelectedStep)
                LV_Modify(ActionTraceSelectedStep, "Select Focus")
        }
        LV_ModifyCol(1, 34), LV_ModifyCol(2, 70), LV_ModifyCol(3, 148), LV_ModifyCol(4, 345)
    } finally {
        Gui, %previousGui%:Default
    }
    ActionTrace_RenderDetail()
}

ActionTrace_RenderDetail() {
    global ActionTraceVisible, ActionTraceSelectedId, ActionTraceSelectedStep
    if (!ActionTraceVisible)
        return
    record := ActionTrace_Get(ActionTraceSelectedId)
    summary := "Операций пока нет. Выполните действие или запустите учебный режим."
    detail := "", reason := ""
    canRetry := false
    if IsObject(record) {
        elapsed := (record.Finished ? record.Finished : TickNow()) - record.Started
        summary := record.Source . " | " . ActionTrace_StatusLabel(record.State) . " | " . (record.Mock ? "Учебный / Mock" : "Игра")
            . " | " . elapsed . " мс | Профиль: " . record.Profile . " | ID: " . (record.Target = "" ? "не задан" : record.Target)
        if (record.Total > record.Steps.Length())
            summary .= " | Показаны первые " . record.Steps.Length() . " из " . record.Total . " шагов."
        detail := record.Detail
        if (ActionTraceSelectedStep > 0 && ActionTraceSelectedStep <= record.Steps.Length()) {
            step := record.Steps[ActionTraceSelectedStep]
            detail := "Шаг " . ActionTraceSelectedStep . " / " . record.Total . " - " . step.Kind . " - " . ActionTrace_StatusLabel(step.Status)
                . "`r`n" . step.Text . "`r`n`r`n" . step.Detail
            canRetry := ActionTrace_CanRetry(record.Id, ActionTraceSelectedStep, reason)
            if (!canRetry && step.Status = "failed")
                detail .= "`r`n`r`n" . reason
        }
    }
    UIStyle_SetTextIfChanged("ActionTrace", "AT_Summary", summary)
    UIStyle_SetTextIfChanged("ActionTrace", "AT_Detail", detail)
    GuiControl, % "ActionTrace:" . (canRetry ? "Enable" : "Disable"), AT_Retry
}
