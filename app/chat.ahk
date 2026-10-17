; chat subsystem. Definitions only; initialization is in bootstrap.

SendChat(text, source := "Direct") {
    result := ChatTransport_Send(text, source)
    if (result = 1)
        Evidence_MaybeCaptureReportText(text)
    return result
}

ChatTransport_SetStatus(status, source := "ChatTransport", level := "INFO") {
    global ChatTransportStatus
    if (status = ChatTransportStatus)
        return
    ChatTransportStatus := status
    LogError(source, "Chat transport: " . status, level)
}

ChatTransport_GetDisplayStatus() {
    global MockMode, TextSendMode, ChatTransportStatus
    if (MockMode = "On")
        return "Mock (без игры)"
    if (ChatTransportStatus != "" && ChatTransportStatus != "Ожидание")
        return ChatTransportStatus
    return TextSendMode
}

ChatTransport_GetConnectionSummary(runMemoryCheck := 0) {
    global MockMode, TextSendMode, GameWindowTitle, GameProcessName, GAME_MP_ModuleName
    global GAME_DETECTION_SOURCE
    NormalizeTextSendMode(TextSendMode)
    ApplyGameProcessSelector()
    if (MockMode = "On")
        return "Тест без игры включён | Реальная отправка отключена"

    gamePID := 0, gameSelector := "", locatorSource := ""
    if !GameLocator_Find(gamePID, gameSelector, locatorSource)
        return "PROCESS_LOOKUP: не найдено окно """ . GameWindowTitle . """ и EXE " . GameProcessName . " | Режим: " . TextSendMode

    sourceText := (locatorSource = "title") ? "заголовок" : "EXE (резерв)"
    activeText := WinActive(gameSelector) ? "окно активно" : "окно не активно"
    if (!runMemoryCheck)
        return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | Режим: " . TextSendMode

    memoryReady := checkHandles()
    if (memoryReady)
        return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | Memory готов | " . GetAzmpCompatibilitySummary()

    reason := MemoryGetShortError()
    if (TextSendMode = "Auto" && WinActive(gameSelector))
        reason .= " | Keyboard готов"
    else if (TextSendMode = "Auto")
        reason .= " | активируй окно для Keyboard"
    return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | " . reason
}

ChatTransport_Send(text, source := "ChatTransport", role := "") {
    if (IsObject(IDCaptureState) || ServiceUI_IsInputActive() || (IsObject(GameMenuStarting) && source != "GPS") || IsObject(GameMenuLease))
        return -1
    global MockMode, TextSendMode, g_RemoteOperation
    global ChatTransportLastMemoryFailureTick, ChatTransportMemoryRetryMs
    text := "" . text
    if (text = "")
        return -1
    if (MockMode = "On")
    {
        MockPreview_Append(text)
        ChatTransport_SetStatus("Mock (без игры)", source)
        return true
    }

    ApplyGameProcessSelector()
    NormalizeTextSendMode(TextSendMode)
    if (TextSendMode = "FastTyping" || TextSendMode = "FactionTyping") {
        if ChatTyping_ShouldType(TextSendMode, text, ChatFactionCommands) {
            result := SendChatTyped(text, true, true, "", ChatTransport_TypingDelayOverride(source, role, text))
            status := result = 1 ? ChatTyping_ModeLabel(TextSendMode) : (result = -2 ? "Печать прервана; повтор отключён" : "Печать: " . (ChatTypingLastError != "" ? ChatTypingLastError : "отправка недоступна"))
            ChatTransport_SetStatus(status, source, result = 1 ? "INFO" : "WARN")
            return result
        }
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Вставка (остальной текст)" : "Вставка: " . ChatKeyboardLastError, source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }
    if (TextSendMode = "Keyboard")
    {
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Вставка" : "Вставка: " . ChatKeyboardLastError, source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }

    if (TextSendMode = "Memory")
    {
        if IsObject(g_RemoteOperation)
            return -2
        ; Only fall back before a memory operation is attempted, never after an uncertain call.
        if !checkHandles() {
            memoryError := MemoryGetShortError()
            if IsObject(g_RemoteOperation)
                return -2
            ok := SendChatKeyboard(text)
            ChatTransport_SetStatus(ok ? "Вставка: память недоступна (" . memoryError . ")" : "Отправка: " . ChatKeyboardLastError, source, ok ? "INFO" : "WARN")
            return ok ? 1 : -1
        }
        result := SendChatMemory(text)
        if (result = 1)
            ChatTransport_SetStatus("Memory", source)
        else {
            memoryStatus := MemoryGetStatusText()
            memoryError := MemoryGetShortError()
            ChatTransport_SetStatus("Memory: " . memoryError, source, "ERROR")
            LogError(source, "Memory send failed | " . memoryStatus, "ERROR")
        }
        return IsObject(g_RemoteOperation) ? -2 : result
    }

    if IsObject(g_RemoteOperation)
        return -2
    memoryError := ""
    nowTick := TickNow()
    canRetryMemory := (ChatTransportLastMemoryFailureTick <= 0 || nowTick - ChatTransportLastMemoryFailureTick >= ChatTransportMemoryRetryMs)
    if (canRetryMemory)
    {
        result := SendChatMemory(text)
        if (result = 1)
        {
            ChatTransportLastMemoryFailureTick := 0
            ChatTransport_SetStatus("Memory (Auto)", source)
            return 1
        }
        if (result = -2 || IsObject(g_RemoteOperation)) {
            ChatTransport_SetStatus("Память: вызов запускался; повтор отключён", source, "WARN")
            return -2
        }
        memoryStatus := MemoryGetStatusText()
        memoryError := MemoryGetShortError()
        LogError(source, "Auto Memory failed | " . memoryStatus, "WARN")
        ChatTransportLastMemoryFailureTick := nowTick
    }

    if GameLocator_IsActive()
    {
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Вставка (Авто)" : "Авто: " . ChatKeyboardLastError, source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }

    if (memoryError = "")
        memoryError := MemoryGetShortError()
    ChatTransport_SetStatus("Auto: " . memoryError . "; активируй игру для Keyboard", source, "WARN")
    return -1
}

SendChatKeyboard(text) {
    global MockMode, ChatKeyboardLastError
    ChatKeyboardLastError := ""
    if IsObject(IDCaptureState) {
        ChatKeyboardLastError := "Активен ввод ID."
        return false
    }
    if (text = "")
        return false
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append(text)
        return true
    }
    previous := A_IsCritical
    Critical, On
    if (PhysicalInputBusy || IsObject(IDCaptureState) || !GameLocator_IsActive()) {
        ChatKeyboardLastError := "Окно игры не активно или ввод занят."
        Critical, %previous%
        return false
    }
    PhysicalInputBusy := 1
    epoch := AutomationEpoch, ownerHwnd := WinExist("A")
    Critical, Off
    try {
        chatState := isInChat()
        if (chatState < 0 || !ChatTyping_IsReady(epoch, ownerHwnd)) {
            ChatKeyboardLastError := "Состояние чата недоступно: " . MemoryGetShortError()
            return false
        }
        if (chatState = 0) {
            if !SafeSend("{F6}", "Event", epoch)
                return false
        }
        if !ChatTyping_WaitForChatOpen(epoch, ownerHwnd) {
            ChatKeyboardLastError := ChatTypingLastError
            return false
        }
        if !SafeSend("^a{Backspace}", "Input", epoch)
            return false
        Sleep, 50
        ; Clipboard insertion works independently of the keyboard layout.
        if !PasteOnly(text, 1, "", ownerHwnd) {
            ChatKeyboardLastError := "Вставка отменена: окно, контекст или буфер изменились."
            return false
        }
        Sleep, 70
        if (!ChatTyping_IsReady(epoch, ownerHwnd) || isInChat() != 1) {
            ChatKeyboardLastError := "Ввод отменён или чат закрыт до отправки."
            return false
        }
        return SafeSend("{Enter}", "Event", epoch)
    } finally {
        Critical, On
        PhysicalInputBusy := 0
        Critical, %previous%
    }
}

SendChatAuto(text) {
    trimmed := Trim(text)
    if (trimmed = "")
        return
    ChatQueue_Enqueue(trimmed, "SendChatAuto")
}

WaitForChatQueueIdle(timeoutMs := 20000) {
    global ChatQueueBusy
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 1000)
        timeoutMs := 1000
    epoch := AutomationEpoch
    failures := QueueFailureGeneration
    started := TickNow()
    Loop
    {
        if (epoch != AutomationEpoch || QueueFailureGeneration != failures)
            return false
        if (ChatQueue_Count() <= 0 && !ChatQueueBusy)
            return true
        if (TickNow() - started >= timeoutMs)
            return false
        Sleep, 50
    }
}

SendRadialNumberTwice(number, delayMs := 300, pressGapMs := 0, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !RegExMatch(number . "", "^\d$")
        return false
    key := "{" . number . "}"
    if !SafeSend(key, "Event", inputEpoch)
        return false
    pressGapMs := Round(pressGapMs)
    if (pressGapMs > 0)
        Sleep, %pressGapMs%
    if !SafeSend(key, "Event", inputEpoch)
        return false
    Sleep, %delayMs%
    return true
}

SendListSelection(position, stepDelayMs := 35, afterDelayMs := 220, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    position := Round(position)
    if (position < 1)
        return false
    downCount := position - 1
    if (downCount > 0)
    {
        Loop, %downCount%
        {
            if !SafeSend("{Down}", "Event", inputEpoch)
                return false
            Sleep, %stepDelayMs%
        }
    }
    if !SafeSend("{Enter}", "Event", inputEpoch)
        return false
    Sleep, %afterDelayMs%
    return true
}

EnsureEnglishLayout() {
    return SafeLayout(0x4090409)
}

ClearBindMenuChatLine(force := false, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !IsGameActive()
        return
    if (!force && isInChat() != 1)
        return

    SafeSend("{Alt up}", "Input", inputEpoch)
    Sleep, 20
    SafeSend("^a", "Input", inputEpoch)
    Sleep, 30
    SafeSend("{Backspace}", "Input", inputEpoch)
    Sleep, 30
}

ForceCloseBindMenuEditMode(reason := "") {
    global BindMenuVisible, BindMenuEditMode, hBindMenuWnd
    Gui, 19:Destroy
    hBindMenuWnd := 0
    BindMenuVisible := false
    BindMenuEditMode := false
    ResumeGameTextTriggersAfterBindMenu()
    ApplyAllBinds()
    if (reason != "")
    {
        Notify("info")
        ServiceUI_Notify(reason, 1200)
    }
}

ApplyTemplate(str) {
    global IntroRole, ReportRole, Rank, ReportRank, Surname, PersonalBadge
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount
    str := StrReplace(str, "{INTRO_ROLE}", IntroRole)
    str := StrReplace(str, "{REPORT_ROLE}", ReportRole)
    str := StrReplace(str, "{RANK}", Rank)
    str := StrReplace(str, "{REPORT_RANK}", ReportRank)
    str := StrReplace(str, "{SURNAME}", Surname)
    str := StrReplace(str, "{BADGE}", PersonalBadge)
    str := StrReplace(str, "{PERSONAL_BADGE}", PersonalBadge)
    str := StrReplace(str, "{TOKEN}", PersonalBadge)
    str := StrReplace(str, "{PATROL_ROUTE}", PatrolRoute)
    str := StrReplace(str, "{POST_ROUTE}", PostRoute)
    str := StrReplace(str, "{CONVOY_ROUTE}", ConvoyRoute)
    str := StrReplace(str, "{PATROL_UNIT}", PatrolUnit)
    str := StrReplace(str, "{PATROL_CREW_COUNT}", PatrolCrewCount)
    str := StrReplace(str, "{POST_UNIT}", PostUnit)
    str := StrReplace(str, "{POST_CREW_COUNT}", PostCrewCount)
    return str
}

ApplyActionTemplate(str) {
    global UserID, CurrentProfile, TargetNickname, TargetIsMask
    str := ApplyTemplate(str)
    str := StrReplace(str, "{USER_ID}", UserID)
    str := StrReplace(str, "{ID}", TargetIsMask ? "" : UserID)
    str := StrReplace(str, "{MASK}", TargetIsMask ? UserID : "")
    str := StrReplace(str, "{TARGET}", UserID)
    str := StrReplace(str, "{TARGET_NICK}", TargetNickname)
    str := StrReplace(str, "{NICK}", TargetNickname)
    str := StrReplace(str, "{TARGET_FULL}", GetTargetFullLabel())
    str := StrReplace(str, "{PROFILE}", CurrentProfile)
    FormatTime, psNowTime,, HH:mm:ss
    FormatTime, psNowDate,, dd.MM.yyyy
    str := StrReplace(str, "{TIME}", psNowTime)
    str := StrReplace(str, "{DATE}", psNowDate)
    return str
}

SendConfigSequence(sequenceText, delayMs := "") {
    global SequenceLineDelay
    NormalizeNumberRange(SequenceLineDelay, 700, 250, 3000)
    if (delayMs = "" || delayMs < SequenceLineDelay)
        delayMs := SequenceLineDelay
    return ChatQueue_EnqueueSequence(sequenceText, "RPSequence", delayMs)
}

SplitConfigSequenceMiddle(sequenceText, ByRef firstPart, ByRef secondPart) {
    lines := []
    firstPart := ""
    secondPart := ""

    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")

    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        lines.Push(line)
    }

    total := lines.Length()
    if (total <= 0)
        return

    splitIndex := Floor(total / 2)
    Loop % total
    {
        line := lines[A_Index]
        if (A_Index <= splitIndex)
        {
            if (firstPart != "")
                firstPart .= "`n"
            firstPart .= line
        }
        else
        {
            if (secondPart != "")
                secondPart .= "`n"
            secondPart .= line
        }
    }
}

SplitConfigReportLine(sequenceText, ByRef reportLine, ByRef remainingText) {
    reportLine := ""
    remainingText := ""
    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        normalized := Evidence_NormalizeChatLine(line)
        if (reportLine = "" && RegExMatch(normalized, "^/r\s+докладывает(?:\s|$)")) {
            reportLine := line
            continue
        }
        if (remainingText != "")
            remainingText .= "`n"
        remainingText .= line
    }
    return (reportLine != "")
}

TowStart_EnsureTowLast(sequenceText) {
    cleaned := ""
    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        lineLower := line
        StringLower, lineLower, lineLower
        if (lineLower = "/tow")
            continue
        if (cleaned != "")
            cleaned .= "`n"
        cleaned .= line
    }
    if (cleaned != "")
        cleaned .= "`n"
    cleaned .= "/tow"
    return cleaned
}

EnsureRussianLayout() {
    return SafeLayout(0x4190419)
}

PasteOnly(text, alreadyOwned := 0, contextGuard := "", expectedHwnd := 0, menuLease := "") {
    if IsObject(IDCaptureState)
        return false
    global MockMode
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[TYPE] " . text)
        return true
    }
    if (!GameLocator_IsActive() || (!alreadyOwned && PhysicalInputBusy))
        return false
    if (!alreadyOwned)
        PhysicalInputBusy := 1
    epoch := AutomationEpoch
    ownerHwnd := expectedHwnd ? expectedHwnd : WinExist("A")
    if !ChatTyping_IsReady(epoch, ownerHwnd, contextGuard) {
        if (!alreadyOwned)
            PhysicalInputBusy := 0
        return false
    }
    saved := ClipboardAll
    sequence := -1
    try {
        Clipboard := text
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        ClipWait, 0.5
        if (ErrorLevel || !ChatTyping_IsReady(epoch, ownerHwnd, contextGuard)
            || sequence != DllCall("GetClipboardSequenceNumber", "UInt"))
            return false
        if !SafeSend("^v", "Input", epoch, menuLease)
            return false
        Sleep, 50
        return ChatTyping_IsReady(epoch, ownerHwnd, contextGuard)
    } finally {
        if (sequence >= 0 && sequence = DllCall("GetClipboardSequenceNumber", "UInt"))
            Clipboard := saved
        VarSetCapacity(saved, 0)
        if (!alreadyOwned)
            PhysicalInputBusy := 0
    }
}

SendTemplateChat(template) {
    text := ApplyTemplate(template)
    SendChatAuto(text)
}

SendTemplateOpen(template, leftCount := 0, inputEpoch := 0) {
    global PhysicalInputBusy
    inputEpoch := AutomationEpoch
    text := ApplyTemplate(template)
    previous := A_IsCritical
    Critical, On
    try {
        ownerHwnd := WinExist("A")
        if (PhysicalInputBusy || IsObject(IDCaptureState))
            return false
        if !TypeChatForEpoch(inputEpoch, text)
            return false
        if (leftCount <= 0)
            return true
        ; Typed input restores this critical thread before returning. Claim its
        ; caret tail before allowing another sender or hotkey to interrupt.
        if (PhysicalInputBusy || inputEpoch != AutomationEpoch || WinExist("A") != ownerHwnd)
            return false
        PhysicalInputBusy := 1
        Critical, Off
        try {
            Sleep, 50
            if (inputEpoch != AutomationEpoch || WinExist("A") != ownerHwnd)
                return false
            return SafeSend("{Left " . leftCount . "}", "Input", inputEpoch)
        } finally {
            Critical, On
            PhysicalInputBusy := 0
        }
    } finally {
        Critical, %previous%
    }
}

GetActiveChatText(inputEpoch := 0) {
    result := CaptureChatClipboard(false)
    return result.Ok ? result.Query : ""
}

CaptureChatClipboard(cancelChat := false) {
    global MockMode
    result := {Ok: 0, Query: "", Reason: "Не удалось прочитать игровой чат."}
    if (MockMode = "On" || AuditTestMode || PhysicalInputBusy || !GameLocator_IsActive() || isInChat() != 1)
        return result
    PhysicalInputBusy := 1
    epoch := AutomationEpoch
    saved := ClipboardAll
    sequence := -1
    try {
        Clipboard := ""
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        if !SafeSend("^a^c", "Input", epoch)
            return result
        ClipWait, 0.4
        if (ErrorLevel || epoch != AutomationEpoch || !GameLocator_IsActive() || isInChat() != 1)
            return result
        ; Only restore a clipboard update belonging to this foreground process.
        foreground := DllCall("GetForegroundWindow", "Ptr")
        owner := DllCall("GetClipboardOwner", "Ptr")
        DllCall("GetWindowThreadProcessId", "Ptr", foreground, "UInt*", foregroundPID)
        DllCall("GetWindowThreadProcessId", "Ptr", owner, "UInt*", ownerPID)
        if (!ownerPID || ownerPID != foregroundPID) {
            sequence := -1
            result.Reason := "Буфер обмена изменён другим приложением."
            return result
        }
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        result.Query := Trim(Clipboard)
        if (sequence != DllCall("GetClipboardSequenceNumber", "UInt")) {
            sequence := -1
            return result
        }
        if (!cancelChat) {
            result.Ok := SafeSend("{End}", "Input", epoch)
            return result
        }
        if !SafeSend("^a{Backspace}", "Input", epoch)
            return result
        started := TickNow()
        while (isInChat() = 1 && TickNow() - started < 900) {
            if !SafeSend("{Esc}", "Input", epoch)
                return result
            Sleep, 70
        }
        result.Ok := epoch = AutomationEpoch && GameLocator_IsActive() && isInChat() = 0
        return result
    } finally {
        if (sequence >= 0 && sequence = DllCall("GetClipboardSequenceNumber", "UInt"))
            Clipboard := saved
        VarSetCapacity(saved, 0)
        PhysicalInputBusy := 0
    }
}
