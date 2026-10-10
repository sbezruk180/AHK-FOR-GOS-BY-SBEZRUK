; Fast literal typing. Included before configuration loading; AutoHotkey 1.1 ANSI.
global ChatTypingDelayMs := 5
global ChatFactionCommands := ChatTyping_DefaultCommands()

ChatTyping_DefaultCommands() {
    return "/frac /fracid /cuff /uncuff /deject /dejectid /mdc /chase /chaseid /incar /search /su /wanted /doc /find /lookup /sos /tazer /baton /tow /mask /r /d /dep /m /h /f /rb /fb /gov"
}

ChatTyping_NormalizeDelay(ByRef value) {
    value := Trim(value)
    if !RegExMatch(value, "^[+-]?\d+(?:\.\d+)?$")
        value := 5
    value := Max(1, Min(100, Round(value + 0)))
    return value
}

ChatTyping_NormalizeCommands(ByRef value) {
    value := Trim(RegExReplace(value, "[,;|\s]+", " "))
    StringLower, value, value
    commands := {}, normalized := "", count := 0
    for index, command in StrSplit(value, " ") {
        if (SubStr(command, 1, 1) != "/")
            command := "/" . command
        if (!RegExMatch(command, "^/[a-z][a-z0-9_]{0,31}$") || commands.HasKey(command))
            continue
        commands[command] := 1
        normalized .= (normalized = "" ? "" : " ") . command
        count++
        if (count >= 32)
            break
    }
    value := normalized = "" ? ChatTyping_DefaultCommands() : normalized
    return value
}

ChatTyping_IsFactionCommand(text, commandList) {
    text := Trim(text)
    if !RegExMatch(text, "i)^(/[a-z][a-z0-9_]{0,31})(?:\s|$)", match)
        return false
    command := match1
    StringLower, command, command
    ChatTyping_NormalizeCommands(commandList)
    for index, candidate in StrSplit(commandList, " ")
        if (candidate = command)
            return true
    return false
}

ChatTyping_ShouldType(mode, text, commands) {
    return mode = "FastTyping" || (mode = "FactionTyping" && ChatTyping_IsFactionCommand(text, commands))
}

ChatTyping_ModeLabel(mode) {
    static labels := {Auto: "Авто", Memory: "Память", Keyboard: "Вставка", FastTyping: "Печать всего", FactionTyping: "Печать фракции"}
    return labels.HasKey(mode) ? labels[mode] : labels.Auto
}

ChatTyping_ModeFromLabel(label) {
    static modes := {"Авто": "Auto", "Память": "Memory", "Вставка": "Keyboard", "Печать всего": "FastTyping", "Печать фракции": "FactionTyping"}
    label := Trim(label)
    if modes.HasKey(label)
        return modes[label]
    if (label = "Auto" || label = "Memory" || label = "Keyboard" || label = "FastTyping" || label = "FactionTyping")
        return label
    return "Auto"
}

ChatTyping_IsSingleLine(text) {
    ; Text mode would turn CR/LF/tab into physical Enter/tab. Only one chat line is allowed.
    return text != "" && !RegExMatch(text, "[\x01-\x1F\x7F]")
}

ChatTyping_IsReady(epoch, gameHwnd) {
    global AutomationEpoch, IDCaptureState
    return epoch = AutomationEpoch && !IsObject(IDCaptureState)
        && GameLocator_IsActive() && WinExist("A") = gameHwnd
}

SendChatTyped(text) {
    global MockMode, AuditTestMode, PhysicalInputBusy, AutomationEpoch, IDCaptureState, ChatTypingDelayMs
    text := "" . text
    if (!ChatTyping_IsSingleLine(text) || IsObject(IDCaptureState))
        return -1
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append(text)
        return 1
    }

    previous := A_IsCritical
    Critical, On
    if (PhysicalInputBusy || IsObject(IDCaptureState) || !GameLocator_IsActive()) {
        Critical, %previous%
        return -1
    }
    PhysicalInputBusy := 1
    epoch := AutomationEpoch, gameHwnd := WinExist("A")
    ; Printing remains interruptible even when a caller entered a critical thread.
    Critical, Off

    previousDelay := A_KeyDelay, previousDuration := A_KeyDuration
    inputStarted := false, timerPeriodSet := false, oldLayout := 0
    try {
        ChatTyping_NormalizeDelay(ChatTypingDelayMs)
        delay := ChatTypingDelayMs
        gameThread := DllCall("GetWindowThreadProcessId", "Ptr", gameHwnd, "Ptr", 0, "UInt")
        oldLayout := DllCall("GetKeyboardLayout", "UInt", gameThread, "Ptr")
        SetKeyDelay, -1, -1
        ; Sleep below 10 ms needs a temporary timer resolution on Windows.
        timerPeriodSet := DllCall("winmm\timeBeginPeriod", "UInt", 1, "UInt") = 0
        chatState := isInChat()
        if (chatState < 0 || !ChatTyping_IsReady(epoch, gameHwnd))
            return -1
        if (chatState = 0) {
            inputStarted := true
            if !SafeSend("{F6}", "Input", epoch)
                return -2
            Sleep, 120
            if (!ChatTyping_IsReady(epoch, gameHwnd) || isInChat() != 1)
                return -2
        }
        if (!ChatTyping_IsReady(epoch, gameHwnd) || isInChat() != 1)
            return inputStarted ? -2 : -1
        inputStarted := true
        if !SafeSend("^a{Backspace}", "Input", epoch)
            return -2
        Sleep, 50
        if (!ChatTyping_IsReady(epoch, gameHwnd) || isInChat() != 1 || !SafeLayout(0x4190419))
            return -2

        length := StrLen(text)
        Loop, %length% {
            if (!ChatTyping_IsReady(epoch, gameHwnd) || isInChat() != 1)
                return -2
            ; Text mode sends each character literally, including ! + ^ # % and braces.
            if !SafeSend("{Text}" . SubStr(text, A_Index, 1), "Event", epoch)
                return -2
            if (A_Index < length) {
                DllCall("Sleep", "UInt", delay)
                ; Unlike native Sleep, this pumps hotkeys, cancellation and focus timers.
                Sleep, -1
            }
        }
        if (!ChatTyping_IsReady(epoch, gameHwnd) || isInChat() != 1)
            return -2
        if !SafeSend("{Enter}", "Input", epoch)
            return -2
        return ChatTyping_IsReady(epoch, gameHwnd) ? 1 : -2
    } finally {
        SetKeyDelay, %previousDelay%, %previousDuration%
        if (timerPeriodSet)
            DllCall("winmm\timeEndPeriod", "UInt", 1, "UInt")
        if (oldLayout && ChatTyping_IsReady(epoch, gameHwnd))
            SafeLayout(oldLayout)
        PhysicalInputBusy := 0
        Critical, %previous%
    }
}
