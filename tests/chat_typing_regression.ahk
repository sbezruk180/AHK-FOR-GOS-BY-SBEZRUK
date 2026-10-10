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
