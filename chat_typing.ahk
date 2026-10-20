; Fast literal typing. Included before configuration loading; AutoHotkey 1.1 ANSI.
global ChatTypingDelayMs := 5
global ChatTypingSpeedMode := "Fixed"
global ChatTypingMinCPS := 20
global ChatTypingMaxCPS := 40
global ChatFactionCommands := ChatTyping_DefaultCommands()
global ChatTypingLastError := ""

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

ChatTyping_EffectiveDelay(configured, override := "") {
    ChatTyping_NormalizeDelay(configured)
    override := Trim(override)
    if (override = "" || !RegExMatch(override, "^[+-]?\d+(?:\.\d+)?$"))
        return configured
    ; Explicit zero is reserved for RP narration around an action; it does not alter the user's typing setting.
    return Max(0, Min(100, Round(override + 0)))
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
    return mode = "FastTyping" || ((mode = "FactionTyping" || mode = "FactionTypingMemory") && ChatTyping_IsFactionCommand(text, commands))
}

ChatTyping_ModeLabel(mode) {
    static labels := {Auto: "Авто", Memory: "Память", Keyboard: "Вставка", FastTyping: "Печать всего", FactionTyping: "Фракция: остальное вставка", FactionTypingMemory: "Фракция: остальное память"}
    return labels.HasKey(mode) ? labels[mode] : labels.Auto
}

ChatTyping_ModeFromLabel(label) {
    static modes := {"Авто": "Auto", "Память": "Memory", "Вставка": "Keyboard", "Печать всего": "FastTyping", "Печать фракции": "FactionTyping", "Фракция: остальное вставка": "FactionTyping", "Фракция: остальное память": "FactionTypingMemory"}
    label := Trim(label)
    if modes.HasKey(label)
        return modes[label]
    if (label = "Auto" || label = "Memory" || label = "Keyboard" || label = "FastTyping" || label = "FactionTyping" || label = "FactionTypingMemory")
        return label
    return "Auto"
}

ChatTyping_NormalizeSpeedConfig(ByRef mode, ByRef minimum, ByRef maximum) {
    mode := mode = "RandomCPS" || mode = "Случайный темп (симв/с)" ? "RandomCPS" : "Fixed"
    if !RegExMatch(Trim(minimum), "^\d+$")
        minimum := 20
    if !RegExMatch(Trim(maximum), "^\d+$")
        maximum := 40
    minimum := Max(1, Min(1000, minimum + 0)), maximum := Max(1, Min(1000, maximum + 0))
    if (minimum > maximum) {
        swap := minimum, minimum := maximum, maximum := swap
    }
}

ChatTyping_SpeedLabel(mode) {
    return mode = "RandomCPS" ? "Случайный темп (симв/с)" : "Постоянный интервал"
}

ChatTyping_UsesVariableSpeed(mode, override := "") {
    return mode = "RandomCPS" && !RegExMatch(Trim(override), "^[+-]?\d+(?:\.\d+)?$")
}

ChatTyping_NextCharWait(minimum, maximum, elapsedMs := 0) {
    ; Called with validated integer CPS bounds. Time already spent pressing a
    ; physical key counts towards its start-to-start interval.
    Random, rate, %minimum%, %maximum%
    return Max(0, Round(1000.0 / rate) - Max(0, elapsedMs))
}

ChatTyping_WaitInterval(delayMs, epoch, hwnd, contextGuard := "") {
    started := TickNow()
    Loop {
        Sleep, -1
        if (!ChatTyping_IsReady(epoch, hwnd, contextGuard) || isInChat() != 1)
            return false
        remaining := delayMs - ((TickNow() - started) & 0xFFFFFFFF)
        if (remaining <= 0)
            return true
        DllCall("Sleep", "UInt", Min(10, remaining))
    }
}

ChatTyping_IsSingleLine(text) {
    ; Line breaks and tabs would become physical chat actions. Only one line is allowed.
    return text != "" && !RegExMatch(text, "[\x01-\x1F\x7F]")
}

ChatTyping_IsReady(epoch, gameHwnd, contextGuard := "") {
    global AutomationEpoch, IDCaptureState
    if (epoch != AutomationEpoch || IsObject(IDCaptureState))
        return false
    if IsObject(contextGuard) {
        try {
            if !contextGuard.Call()
                return false
        } catch e {
            return false
        }
    }
    return epoch = AutomationEpoch && !IsObject(IDCaptureState)
        && GameLocator_IsActive() && WinExist("A") = gameHwnd
}

ChatTyping_CodepointFromByte(byte) {
    if (byte < 0 || byte > 255 || byte = 0x98 || byte != Floor(byte))
        return -1
    if (byte < 128)
        return byte
    VarSetCapacity(encoded, 1, 0), VarSetCapacity(wide, 2, 0)
    NumPut(byte, encoded, 0, "UChar")
    ; ANSI runtime strings are CP1251 bytes. VkKeyScanExW needs the Unicode character.
    if (DllCall("MultiByteToWideChar", "UInt", 1251, "UInt", 8, "Ptr", &encoded, "Int", 1, "Ptr", &wide, "Int", 1, "Int") != 1)
        return -1
    return NumGet(wide, 0, "UShort")
}

ChatTyping_Codepoint(character) {
    ordinal := Asc(character)
    return A_IsUnicode ? ordinal : ChatTyping_CodepointFromByte(ordinal)
}

ChatTyping_GetLayouts() {
    us := DllCall("LoadKeyboardLayoutW", "WStr", "00000409", "UInt", 0, "Ptr")
    ru := DllCall("LoadKeyboardLayoutW", "WStr", "00000419", "UInt", 0, "Ptr")
    return (us & 0xFFFF) = 0x409 && (ru & 0xFFFF) = 0x419 ? {US: us, RU: ru} : ""
}

ChatTyping_MapCodepoint(codepoint, layouts) {
    if (!IsObject(layouts) || codepoint < 32 || codepoint > 0xFFFF)
        return ""
    russian := (codepoint >= 0x400 && codepoint <= 0x52F) || codepoint = 0x2116
    preferred := russian ? [layouts.RU, layouts.US] : [layouts.US, layouts.RU]
    for index, layout in preferred {
        packed := DllCall("VkKeyScanExW", "UShort", codepoint, "Ptr", layout, "Short")
        if (packed = -1)
            continue
        vk := packed & 0xFF, modifiers := (packed >> 8) & 0xFF
        ; Never use Unicode packets, AltGr, Ctrl or Alt combinations as chat characters.
        if (vk = 0xE7 || vk = 0 || (modifiers & 0xFE))
            continue
        scan := DllCall("MapVirtualKeyExW", "UInt", vk, "UInt", 4, "Ptr", layout, "UInt")
        if (!scan)
            continue
        scan := (scan & 0xFF) | ((scan & 0xFF00) ? 0x100 : 0)
        letter := (codepoint >= 65 && codepoint <= 90) || (codepoint >= 97 && codepoint <= 122)
            || (codepoint >= 0x410 && codepoint <= 0x44F) || codepoint = 0x401 || codepoint = 0x451
        return {VK: vk, SC: scan, Layout: layout, Shift: modifiers & 1, Letter: letter, Codepoint: codepoint}
    }
    return ""
}

ChatTyping_BuildKeyPlan(text, ByRef plan, ByRef reason, layouts := "") {
    plan := [], reason := "", mapped := {}
    if !ChatTyping_IsSingleLine(text) {
        reason := "Для печати нужна одна строка без табуляции."
        return false
    }
    if !IsObject(layouts)
        layouts := ChatTyping_GetLayouts()
    if !IsObject(layouts) {
        reason := "Не удалось загрузить раскладки RU/US."
        return false
    }
    Loop, % StrLen(text) {
        codepoint := ChatTyping_Codepoint(SubStr(text, A_Index, 1))
        ; Repeated characters share one immutable mapping instead of allocating a key object per byte.
        if mapped.HasKey(codepoint)
            key := mapped[codepoint]
        else {
            key := ChatTyping_MapCodepoint(codepoint, layouts)
            mapped[codepoint] := key
        }
        if !IsObject(key) {
            plan := []
            reason := "Символ U+" . Format("{:04X}", codepoint) . " не вводится клавишами RU/US."
            return false
        }
        plan.Push(key)
        if (Mod(A_Index, 64) = 0)
            Sleep, -1
    }
    return true
}

ChatTyping_KeyToken(key, capsLockOn := false) {
    if (!IsObject(key) || key.VK = 0xE7 || key.SC < 1)
        return ""
    shift := key.Shift ? 1 : 0
    if (key.Letter && capsLockOn)
        shift := !shift
    token := "{vk" . Format("{:02X}", key.VK) . "sc" . Format("{:03X}", key.SC) . "}"
    ; Blind prevents AutoHotkey from restoring held Alt/Ctrl or changing CapsLock.
    return "{Blind}" . (shift ? "{LShift down}" : "") . token . (shift ? "{LShift up}" : "")
}

ChatTyping_KeyMatchesLayout(key, layout) {
    if (!IsObject(key) || !layout || !key.HasKey("Codepoint") || key.VK = 0xE7 || key.SC < 1)
        return false
    packed := DllCall("VkKeyScanExW", "UShort", key.Codepoint, "Ptr", layout, "Short")
    if (packed = -1 || (packed & 0xFF) != key.VK || ((packed >> 8) & 0xFF) != key.Shift)
        return false
    scan := DllCall("MapVirtualKeyExW", "UInt", key.VK, "UInt", 4, "Ptr", layout, "UInt")
    scan := (scan & 0xFF) | ((scan & 0xFF00) ? 0x100 : 0)
    ; A matching language ID alone is insufficient: alternate keyboard variants may place keys differently.
    return scan = key.SC
}

ChatTyping_ActivateLayout(layout, epoch, gameHwnd, gameThread, contextGuard := "", key := "") {
    if !ChatTyping_IsReady(epoch, gameHwnd, contextGuard)
        return false
    current := DllCall("GetKeyboardLayout", "UInt", gameThread, "Ptr")
    if (current = layout || ChatTyping_KeyMatchesLayout(key, current))
        return ChatTyping_IsReady(epoch, gameHwnd, contextGuard)
    SafeLayout(layout, gameHwnd, epoch)
    if !ChatTyping_IsReady(epoch, gameHwnd, contextGuard)
        return false
    current := DllCall("GetKeyboardLayout", "UInt", gameThread, "Ptr")
    matches := current = layout || ChatTyping_KeyMatchesLayout(key, current)
    return matches && ChatTyping_IsReady(epoch, gameHwnd, contextGuard)
}

ChatTyping_WaitForChatOpen(epoch, gameHwnd, contextGuard := "", timeoutMs := 700) {
    global ChatTypingLastError
    started := A_TickCount
    timeoutMs := Max(1, Min(2000, Round(timeoutMs + 0)))
    Loop {
        if !ChatTyping_IsReady(epoch, gameHwnd, contextGuard) {
            ChatTypingLastError := "Ввод прерван: изменилось активное окно или действие."
            return false
        }
        state := isInChat()
        if !ChatTyping_IsReady(epoch, gameHwnd, contextGuard) {
            ChatTypingLastError := "Ввод прерван: изменилось активное окно или действие."
            return false
        }
        if (state = 1)
            return true
        if (state < 0) {
            ChatTypingLastError := "Не удалось прочитать состояние игрового чата."
            return false
        }
        if (((A_TickCount - started) & 0xFFFFFFFF) >= timeoutMs) {
            ChatTypingLastError := "Чат не открылся после F6."
            return false
        }
        Sleep, 10
    }
}

SendChatTyped(text, submit := true, clearExisting := true, contextGuard := "", delayOverride := "") {
    global MockMode, AuditTestMode, PhysicalInputBusy, AutomationEpoch, IDCaptureState, ChatTypingDelayMs, ChatTypingLastError
    global ChatTypingSpeedMode, ChatTypingMinCPS, ChatTypingMaxCPS
    text := "" . text, ChatTypingLastError := ""
    if (!ChatTyping_IsSingleLine(text) || IsObject(IDCaptureState)) {
        ChatTypingLastError := IsObject(IDCaptureState) ? "Активен ввод ID." : "Для печати нужна одна строка."
        return -1
    }
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append(text)
        return 1
    }

    previous := A_IsCritical
    Critical, On
    if (PhysicalInputBusy || IsObject(IDCaptureState) || !GameLocator_IsActive()) {
        ChatTypingLastError := "Игра не активна или ввод занят."
        Critical, %previous%
        return -1
    }
    PhysicalInputBusy := 1
    epoch := AutomationEpoch, gameHwnd := WinExist("A")
    ; Printing remains interruptible even when a caller entered a critical thread.
    Critical, Off

    previousDelay := A_KeyDelay, previousDuration := A_KeyDuration
    timerPeriodSet := false, oldLayout := 0
    try {
        delay := ChatTyping_EffectiveDelay(ChatTypingDelayMs, delayOverride)
        speedMode := ChatTypingSpeedMode, minCPS := ChatTypingMinCPS, maxCPS := ChatTypingMaxCPS
        ChatTyping_NormalizeSpeedConfig(speedMode, minCPS, maxCPS)
        variable := ChatTyping_UsesVariableSpeed(speedMode, delayOverride)
        gameThread := DllCall("GetWindowThreadProcessId", "Ptr", gameHwnd, "Ptr", 0, "UInt")
        oldLayout := DllCall("GetKeyboardLayout", "UInt", gameThread, "Ptr")
        if !ChatTyping_BuildKeyPlan(text, plan, ChatTypingLastError)
            return -1
        ; A short key-down interval is needed by games that sample the physical keyboard per frame.
        ; The configured typing interval still controls the gap between characters.
        SetKeyDelay, -1, 10
        timerPeriodSet := DllCall("winmm\timeBeginPeriod", "UInt", 1, "UInt") = 0
        chatState := isInChat()
        if (chatState < 0 || !ChatTyping_IsReady(epoch, gameHwnd, contextGuard))
            return -1
        ; A hotkey such as Alt+1 must not turn text keys into menu shortcuts.
        if !SafeSend("{Blind}{LControl up}{RControl up}{LAlt up}{RAlt up}{LShift up}{RShift up}{LWin up}{RWin up}", "Event", epoch)
            return -2
        if (chatState = 0) {
            if !SafeSend("{Blind}{F6}", "Event", epoch)
                return -2
            if !ChatTyping_WaitForChatOpen(epoch, gameHwnd, contextGuard)
                return -2
        }
        if (!ChatTyping_IsReady(epoch, gameHwnd, contextGuard) || isInChat() != 1)
            return -2
        if (clearExisting) {
            if !SafeSend("{Blind}{LControl down}{vk41sc01E}{LControl up}{Backspace}", "Event", epoch)
                return -2
            Sleep, 50
        }

        for index, key in plan {
            charStarted := TickNow()
            if (!ChatTyping_IsReady(epoch, gameHwnd, contextGuard) || isInChat() != 1)
                return -2
            if !ChatTyping_ActivateLayout(key.Layout, epoch, gameHwnd, gameThread, contextGuard, key) {
                ChatTypingLastError := "Игра не приняла раскладку клавиатуры."
                return -2
            }
            token := ChatTyping_KeyToken(key, GetKeyState("CapsLock", "T"))
            if (token = "" || !SafeSend(token, "Text", epoch))
                return -2
            if (index < plan.Length()) {
                pause := variable ? ChatTyping_NextCharWait(minCPS, maxCPS, TickNow() - charStarted) : delay
                if !ChatTyping_WaitInterval(pause, epoch, gameHwnd, contextGuard)
                    return -2
            }
        }
        if (!ChatTyping_IsReady(epoch, gameHwnd, contextGuard) || isInChat() != 1)
            return -2
        if (submit && !SafeSend("{Blind}{Enter}", "Event", epoch))
            return -2
        return ChatTyping_IsReady(epoch, gameHwnd, contextGuard) ? 1 : -2
    } finally {
        SetKeyDelay, %previousDelay%, %previousDuration%
        if (timerPeriodSet)
            DllCall("winmm\timeEndPeriod", "UInt", 1, "UInt")
        if (oldLayout && ChatTyping_IsReady(epoch, gameHwnd))
            SafeLayout(oldLayout)
        Critical, On
        PhysicalInputBusy := 0
        Critical, %previous%
    }
}
