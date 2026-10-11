; Additional behavioural tests, invoked from RunAuditSelfTest().
RunChatTypingRegression() {
    global ChatTypingDelayMs, ChatFactionCommands, IDCaptureState, MockMode, AuditTestMode
    oldDelay := ChatTypingDelayMs, oldCommands := ChatFactionCommands, oldCapture := IDCaptureState
    oldMock := MockMode, oldAudit := AuditTestMode
    delayCases := [["", 5], ["ERROR", 5], ["bad", 5], [0, 1], [-3, 1], [1, 1], [5, 5], [5.6, 6], [100, 100], [9999, 100]]
    for index, item in delayCases {
        value := item[1]
        ChatTyping_NormalizeDelay(value)
        AuditAssert("Typing speed range " . index, value = item[2])
    }
    AuditAssert("Typing override uses zero for RP without changing configured delay", ChatTyping_EffectiveDelay(50, 0) = 0)
    AuditAssert("Typing no override keeps user delay", ChatTyping_EffectiveDelay(50) = 50)
    AuditAssert("Typing override clamps below zero", ChatTyping_EffectiveDelay(50, -10) = 0)
    AuditAssert("Typing override clamps above maximum", ChatTyping_EffectiveDelay(50, 1000) = 100)
    AuditAssert("Typing malformed override keeps user delay", ChatTyping_EffectiveDelay(50, "invalid") = 50)
    AuditAssert("Typing invalid user delay keeps default without override", ChatTyping_EffectiveDelay("invalid") = 5)
    commands := "R, /d; /R | /rb  /fb /gov invalid!"
    ChatTyping_NormalizeCommands(commands)
    AuditAssert("Faction list canonicalizes separators and removes duplicates", commands = "/r /d /rb /fb /gov")
    commands := ""
    ChatTyping_NormalizeCommands(commands)
    for index, command in ["/frac", "/cuff", "/deject", "/mdc", "/chase"]
        AuditAssert("Default faction typing includes operational command " . command, ChatTyping_IsFactionCommand(command . " 123", commands))
    AuditAssert("Faction typing does not confuse cuff with cuffing", !ChatTyping_IsFactionCommand("/cuffing 123", commands))
    AuditAssert("Faction command ignores case and leading spaces", ChatTyping_IsFactionCommand("  /R сообщение", commands))
    AuditAssert("Faction command with no message", ChatTyping_IsFactionCommand("/gov", commands))
    AuditAssert("Faction command needs token boundary", !ChatTyping_IsFactionCommand("/radio текст", commands))
    AuditAssert("Faction command needs slash at start", !ChatTyping_IsFactionCommand("/me сказал /r текст", commands))
    AuditAssert("Faction command punctuation is not delimiter", !ChatTyping_IsFactionCommand("/r! text", commands))
    AuditAssert("FastTyping types ordinary text", ChatTyping_ShouldType("FastTyping", "обычный текст", commands))
    AuditAssert("FactionTyping types faction text", ChatTyping_ShouldType("FactionTyping", "/d доклад", commands))
    AuditAssert("FactionTyping leaves other commands to paste", !ChatTyping_ShouldType("FactionTyping", "/me проверил", commands))
    AuditAssert("Keyboard never selects typing", !ChatTyping_ShouldType("Keyboard", "/r доклад", commands))
    AuditAssert("Typed sender accepts literal keyboard punctuation", ChatTyping_IsSingleLine("!+^#%{Enter} сообщение"))
    AuditAssert("Typed sender rejects newline with accidental Enter", !ChatTyping_IsSingleLine("первая`nвторая"))
    AuditAssert("Typed sender rejects tab", !ChatTyping_IsSingleLine("/r`tdoc"))
    for index, mode in ["Auto", "Memory", "Keyboard", "FastTyping", "FactionTyping"]
        AuditAssert("Chat send mode label roundtrip " . mode, ChatTyping_ModeFromLabel(ChatTyping_ModeLabel(mode)) = mode)
    AuditAssert("Unknown send label selects Auto", ChatTyping_ModeFromLabel("invalid") = "Auto")
    RunChatTypingPhysicalRegression()
    try {
        MockMode := "On", AuditTestMode := 1, IDCaptureState := ""
        before := DllCall("GetClipboardSequenceNumber", "UInt")
        AuditAssert("Typing mock does not touch clipboard", SendChatTyped("/r макет !+{}%") = 1 && before = DllCall("GetClipboardSequenceNumber", "UInt"))
        IDCaptureState := {Digits: "15"}
        AuditAssert("Typed sender refuses during numeric ID capture", SendChatTyped("/r blocked") = -1)
        IDCaptureState := ""
        AuditAssert("Typed sender rejects multiline before transport", SendChatTyped("first`nsecond") = -1)
    } finally {
        ChatTypingDelayMs := oldDelay, ChatFactionCommands := oldCommands, IDCaptureState := oldCapture
        MockMode := oldMock, AuditTestMode := oldAudit
    }
}

RunChatTypingPhysicalRegression() {
    byteCases := [[0xCF, 0x41F], [0xEF, 0x43F], [0xA8, 0x401], [0xB8, 0x451], [0xB9, 0x2116], [35, 35]]
    for index, item in byteCases
        AuditAssert("Typing CP1251 byte decodes to Unicode " . index, ChatTyping_CodepointFromByte(item[1]) = item[2])
    AuditAssert("Typing rejects undefined CP1251 byte", ChatTyping_CodepointFromByte(0x98) = -1)
    layouts := ChatTyping_GetLayouts()
    wineModule := DllCall("GetModuleHandleW", "WStr", "ntdll.dll", "Ptr")
    isWine := DllCall("GetProcAddress", "Ptr", wineModule, "AStr", "wine_get_version", "Ptr") != 0
    if (isWine) {
        ; Wine 10 X11 VkKeyScanEx ignores HKL and cannot encode Cyrillic to UTF-8 in its one-byte buffer.
        ; Exercise its real ASCII mapper, while leaving RU/US installation and Cyrillic mapping for Windows.
        nativeLayout := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
        layouts := {US: nativeLayout, RU: nativeLayout}
        AuditSkip("Native Windows RU/US layout loading and Cyrillic VkKeyScanEx mappings unavailable in Wine")
    } else {
        AuditAssert("Typing loads physical US and RU layouts", IsObject(layouts))
    }
    cases := [["/", 0xBF, 0x35, 0], ["a", 0x41, 0x1E, 0], ["A", 0x41, 0x1E, 1]
        , ["п", 0x47, 0x22, 0], ["П", 0x47, 0x22, 1], ["ё", 0xC0, 0x29, 0], ["Ё", 0xC0, 0x29, 1]
        , ["№", 0x33, 0x04, 1], ["!", 0x31, 0x02, 1], ["+", 0xBB, 0x0D, 1], ["^", 0x36, 0x07, 1]
        , ["#", 0x33, 0x04, 1], ["%", 0x35, 0x06, 1], ["{", 0xDB, 0x1A, 1], ["}", 0xDD, 0x1B, 1], [" ", 0x20, 0x39, 0]]
    for index, item in cases {
        if (isWine && (index >= 4 && index <= 8))
            continue
        key := ChatTyping_MapCodepoint(ChatTyping_Codepoint(item[1]), layouts)
        AuditAssert("Typing physical VK/scancode/Shift mapping " . index, IsObject(key) && key.VK = item[2] && key.SC = item[3] && key.Shift = item[4])
        token := ChatTyping_KeyToken(key)
        AuditAssert("Typing event has explicit VK/scancode, no Unicode packet " . index, token != "" && !InStr(token, "{Text}") && !InStr(token, "vkE7") && RegExMatch(token, "i)\{vk[0-9a-f]{2}sc[0-9a-f]{3}\}"))
    }
    lower := ChatTyping_MapCodepoint(0x61, layouts), upper := ChatTyping_MapCodepoint(0x41, layouts)
    AuditAssert("Typing accounts for CapsLock on lower case", InStr(ChatTyping_KeyToken(lower, true), "{LShift down}"))
    AuditAssert("Typing accounts for CapsLock on upper case", !InStr(ChatTyping_KeyToken(upper, true), "{LShift down}"))
    AuditAssert("Typing refuses packet key plan", ChatTyping_KeyToken({VK: 0xE7, SC: 0x1E, Shift: 0, Letter: 0}) = "")
    AuditAssert("Typing preflights full physical ASCII command and punctuation", ChatTyping_BuildKeyPlan("/cuff 123 !+^#%{Enter}", plan, reason, layouts) && plan.Length() = StrLen("/cuff 123 !+^#%{Enter}"))
    if (!isWine)
        AuditAssert("Typing preflights full mixed Cyrillic command", ChatTyping_BuildKeyPlan("/cuff 123 Пётр №7 !+^#%{Enter}", plan, reason, layouts) && plan.Length() = StrLen("/cuff 123 Пётр №7 !+^#%{Enter}"))
    AuditAssert("Typing refuses unmappable char before any prefix plan", !ChatTyping_BuildKeyPlan("/r " . Chr(A_IsUnicode ? 0x2026 : 0x85), plan, reason, layouts) && plan.Length() = 0 && reason != "")
    AuditAssert("Typing refuses malformed line before keyboard plan", !ChatTyping_BuildKeyPlan("/r`ntext", plan, reason, layouts) && plan.Length() = 0)
}
