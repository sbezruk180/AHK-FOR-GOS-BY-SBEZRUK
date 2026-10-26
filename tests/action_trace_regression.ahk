; Exercise real queue items and transport result contracts without any game.
ActionTrace_RunRegression() {
    global
    longParent := ActionTrace_Begin("Long scenario", 100)
    Loop, 40 {
        childRecord := ActionTrace_Begin("Completed inner send", 1)
        ActionTrace_Finish(childRecord, "done")
    }
    AuditAssert("Trace: long running parent survives completed child history rotation", IsObject(ActionTrace_Get(longParent)) && ActionTraceOrder.Length() <= 24)
    ActionTrace_Finish(longParent, "done")
    parent := ActionTrace_Begin("Parent operation", 1)
    child := ActionTrace_Begin("Inner send", 1)
    ActionTrace_Finish(child, "done")
    ActionTrace_Finish(parent, "failed", "navigation stopped")
    AuditAssert("Trace: terminal parent remains the latest whole operation", ActionTraceLastId = parent)
    names := ["ActionTraceRecords", "ActionTraceOrder", "ActionTraceNextId", "ActionTraceLastId"
        , "ActionTraceVisible", "ActionTraceSelectedId", "ActionTraceSelectedStep"
        , "ChatQueueItems", "QueueBatchStates", "QueueBatchNextId", "ChatQueueBusy"
        , "ChatQueueLastSendTick", "ChatQueueNextSendTick", "ChatQueueMaxRetries", "ChatQueueMinDelay"
        , "QueueFailureGeneration", "AuditTestMode", "AuditTransportResult", "MockMode", "AutomationEpoch"
        , "CurrentProfile", "UserID", "PhysicalInputBusy", "IDCaptureState", "GameMenuStarting", "GameMenuLease"
        , "g_RemoteOperation", "CustomFunctionRunState", "ServiceUIInputState", "ServiceUIConfirmState"
        , "SafeModeEnabled", "SafeDistanceChecks", "SafeBlockWhenChat", "SafeRequireChatForEditable"
        , "ActionCooldownMs", "LastActionTick", "ChatTransportStatus"]
    saved := {}
    for _, name in names
        saved[name] := GetDynamicGlobalValue(name)
    try {
        ActionTraceRecords := {}, ActionTraceOrder := [], ActionTraceNextId := 0, ActionTraceLastId := 0
        ActionTraceVisible := 0, ChatQueueItems := [], QueueBatchStates := {}, QueueBatchNextId := 0
        ChatQueueBusy := 0, ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
        ChatQueueMaxRetries := 0, ChatQueueMinDelay := 250, AuditTestMode := 1, AuditTransportResult := 1
        MockMode := "On", CurrentProfile := "TraceFixture", UserID := "41", PhysicalInputBusy := 0
        IDCaptureState := "", GameMenuStarting := "", GameMenuLease := "", g_RemoteOperation := ""
        CustomFunctionRunState := "", ServiceUIInputState := "", ServiceUIConfirmState := ""
        SafeModeEnabled := "Off", SafeDistanceChecks := "Off", SafeBlockWhenChat := "Off"
        SafeRequireChatForEditable := "Off", ActionCooldownMs := 0, LastActionTick := 0
        id := ActionTrace_Begin("Проверка стадий", 2)
        first := ActionTrace_Add(id, "CHAT", "/r Выполнено", false)
        second := ActionTrace_Add(id, "CHAT", "/r Ещё не запускалось", false)
        ActionTrace_Update(id, first, "sent", "Передано транспорту")
        ActionTrace_Finish(id, "failed", "Следующий шаг не запустился")
        record := ActionTrace_Get(id)
        AuditAssert("Trace: completed stage survives failure and dependent stage is skipped", record.Steps[1].Status = "sent" && record.Steps[2].Status = "skipped")
        AuditAssert("Trace: post-send exception cannot mark an actual send as unsent", !ActionTrace_Update(id, first, "failed", "exception") && record.Steps[1].Status = "sent")
        AuditAssert("Trace: gameplay commands cannot be replayed through generic retry", !ActionTrace_IsRetrySafeText("/cuff 41") && !ActionTrace_IsRetrySafeText("/gps") && ActionTrace_IsRetrySafeText("/r Доклад") && !ActionTrace_IsRetrySafeText("/r a`n/cuff 41"))
        batch := ChatQueue_EnqueueBatch(["/r Строка 1", "/r Строка 2"], "Trace.Success", 0)
        id := QueueBatchStates[batch].TraceId
        ChatQueue_Tick()
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
        ChatQueue_Tick()
        record := ActionTrace_Get(id)
        AuditAssert("Trace: production queue records both actual successful sends", record.State = "done" && record.Steps[1].Status = "sent" && record.Steps[2].Status = "sent" && record.Observed = 2)
        AuditAssert("Trace: mock success is clearly distinguished from actual game delivery", record.Mock && InStr(record.Detail, "Mock"))
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0, AuditTransportResult := -1
        batch := ChatQueue_EnqueueBatch(["/r Повторяемая строка 41", "/cuff 41", "/r Зависимая строка"], "Trace.Failure", 0)
        id := QueueBatchStates[batch].TraceId
        ChatQueue_Tick()
        record := ActionTrace_Get(id)
        AuditAssert("Trace: known-unsent failure cancels dependent lines and retains exact reason", record.State = "failed" && record.Steps[1].Status = "failed" && record.Steps[2].Status = "skipped" && record.Steps[3].Status = "skipped" && ChatQueue_Count() = 0)
        AuditAssert("Trace: only failed known-unsent communication line is eligible for retry", ActionTrace_CanRetry(id, 1, reason) && !ActionTrace_CanRetry(id, 2, reason))
        UserID := "42"
        AuditAssert("Trace: replay rejects changed target", !ActionTrace_CanRetry(id, 1, reason) && InStr(reason, "контекста"))
        UserID := "41", CurrentProfile := "AnotherProfile"
        AuditAssert("Trace: replay rejects changed profile", !ActionTrace_CanRetry(id, 1, reason))
        CurrentProfile := "TraceFixture"
        ChatQueueItems.Push({Text: "/r Чужая операция", Source: "Other", Batch: 0, Epoch: AutomationEpoch})
        AuditAssert("Trace: retry refuses a busy or unrelated queue", !ActionTrace_CanRetry(id, 1, reason))
        ChatQueueItems := [], AuditTransportResult := 1
        retryOk := ActionTrace_RetryStep(id, 1, false)
        AuditAssert("Trace: safe retry queues exactly one immutable selected line", retryOk && ChatQueue_Count() = 1 && ChatQueueItems[1].Text = "/r Повторяемая строка 41" && record.Steps[1].Replayed)
        AuditAssert("Trace: the same failed stage cannot be replayed twice", !ActionTrace_CanRetry(id, 1, reason))
        ChatQueue_Clear(0)
        AuditAssert("Trace: old cancellation epoch invalidates replay", !ActionTrace_CanRetry(id, 1, reason))
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0, AuditTransportResult := -1
        batch := ChatQueue_EnqueueBatch(["/cuff 41"], "Trace.Command", 0)
        id := QueueBatchStates[batch].TraceId
        ChatQueue_Tick()
        AuditAssert("Trace: failed mechanical command stays non-replayable", !ActionTrace_CanRetry(id, 1, reason) && !ActionTrace_Get(id).Steps[1].Retryable)
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0, AuditTransportResult := -2
        batch := ChatQueue_EnqueueBatch(["/r Неопределённый вызов", "/r После него"], "Trace.Unknown", 0)
        id := QueueBatchStates[batch].TraceId
        ChatQueue_Tick()
        record := ActionTrace_Get(id)
        AuditAssert("Trace: unknown launched call prohibits replay and stops dependent steps", record.State = "unknown" && record.Steps[1].Status = "unknown" && record.Steps[2].Status = "skipped" && !ActionTrace_CanRetry(id, 1, reason))
        batch := ChatQueue_EnqueueBatch(["/r Завершённый транспорт"], "Trace.AfterSendException", 0)
        id := QueueBatchStates[batch].TraceId
        item := ChatQueueItems.RemoveAt(1)
        ActionTrace_QueueAttempt(item)
        ActionTrace_QueueTransportResult(item, 1)
        item.TraceKnownUnsent := false, item.TraceReason := "Исключение после отправки"
        ChatQueue_CompleteItem(item, "unknown")
        record := ActionTrace_Get(id)
        AuditAssert("Trace: exception after a real side effect retains sent stage and disables replay", record.State = "unknown" && record.Steps[1].Status = "sent" && !ActionTrace_CanRetry(id, 1, reason))
        batch := ChatQueue_EnqueueBatch(["/r Отмена 1", "/r Отмена 2"], "Trace.Cancel", 0)
        id := QueueBatchStates[batch].TraceId
        ChatQueue_CancelBatch(batch)
        AuditAssert("Trace: cancelling a batch records a terminal reason", ActionTrace_Get(id).State = "cancelled" && !ActionTrace_CanRetry(id, 1, reason))
        ChatQueueItems := [], ChatQueueBusy := 0, ChatTransportStatus := "Старый успешный статус"
        IDCaptureState := {Fixture: true}
        result := ChatTransport_Send("/r До отправки", "Trace.InputBusy")
        record := ActionTrace_Get(ActionTraceLastId)
        AuditAssert("Trace: pre-send input rejection replaces stale transport status", result = -1 && record.State = "failed" && InStr(record.Detail, "ввод ID") && !InStr(record.Detail, "Старый"))
        IDCaptureState := ""
        ActionTrace_Rejected("Trace.Safety", "Цель слишком далеко")
        record := ActionTrace_Get(ActionTraceLastId)
        AuditAssert("Trace: pre-action safety rejection is visible and non-replayable", record.State = "failed" && record.Steps[1].Kind = "CHECK" && record.Detail = "Цель слишком далеко" && !record.Steps[1].Retryable)
        id := ActionTrace_Begin("Большая операция", 130)
        Loop, 130
            ActionTrace_Add(id, "CHAT", "/r " . A_Index . " " . StrReplace(Format("{:1100}", "x"), " ", "a"), true)
        record := ActionTrace_Get(id)
        AuditAssert("Trace: step count and retained text have strict memory bounds", record.Total = 130 && record.Steps.Length() = 120 && StrLen(record.Steps[1].Text) = 1023 && !record.Steps[1].Retryable)
        firstId := id
        Loop, 30
            ActionTrace_Begin("Ограниченная история " . A_Index)
        AuditAssert("Trace: old operation history is bounded and stale ids are safe", ActionTraceOrder.Length() = 24 && ActionTraceRecords.Count() = 24 && !IsObject(ActionTrace_Get(firstId)) && !ActionTrace_Update(firstId, 1, "failed", "stale"))
    } finally {
        for _, name in names
            SetDynamicGlobalValue(name, saved[name])
    }
}

ActionTrace_RunDesktopChecks() {
    global
    previous := ActionTraceVisible
    id := ActionTrace_Begin("Проверка окна результата", 2)
    step := ActionTrace_Add(id, "CHAT", "/r Пример завершённого сообщения", false)
    ActionTrace_Update(id, step, "sent", "Транспорт завершил вызов")
    ActionTrace_Add(id, "MENU", "Down > Enter", false)
    ActionTrace_Finish(id, "failed", "Меню не завершено")
    ActionTrace_Open()
    DesktopSmoke_Assert("trace opens actual native window", ActionTraceVisible && DllCall("IsWindow", "Ptr", hActionTraceWnd))
    ActionTraceSelectedId := id, ActionTraceSelectedStep := 1
    ActionTrace_Refresh()
    GuiControlGet, detail, ActionTrace:, AT_Detail
    DesktopSmoke_Assert("trace native details show exact selected step and no server-ack claim", InStr(detail, "/r Пример завершённого сообщения") && InStr(detail, "Передано клиенту"))
    GuiControlGet, enabled, ActionTrace:Enabled, AT_Retry
    DesktopSmoke_Assert("trace retry button is disabled for a completed message", !enabled)
    ActionTrace_Close()
    DesktopSmoke_Assert("trace closes without retaining a GUI refresh timer or handle", !ActionTraceVisible && !hActionTraceWnd)
}
