; Behavioural tests. Invoke the main script with --audit-selftest; no game or physical input.
RunAuditSelfTest() {
    global
    AuditTestMode := 1
    MockMode := "On"
    AuditChecks := 0, AuditFailures := 0, AuditSkipped := 0
    AuditReport := "AHK audit behavioural regression`r`n"
    AuditReport .= "Runtime=" . A_AhkVersion . " | Unicode=" . A_IsUnicode . " | PtrSize=" . A_PtrSize . "`r`n"
    AuditReport .= "No game, physical input, capture verification, or game ABI test.`r`n"
    scratch := A_Temp . "\ahk_audit_" . DllCall("GetCurrentProcessId") . "_" . TickNow()
    FileCreateDir, %scratch%
    LogDir := scratch . "\logs"
    ModernLogFile := LogDir . "\audit.log"
    ChatLogPlayerNickname := "Own_Player"
    AuditAssert("F01 bracket chase selects second ID", ChatLogReader_ExtractChaseTargetID("Own_Player[15] Other_Player[77]") = 77)
    AuditAssert("F01 ID fallback advances", ChatLogReader_ExtractChaseTargetID("ID:15 target ID#88") = 88)
    AuditAssert("F01 single ID", ChatLogReader_ExtractChaseTargetID("Officer [123]") = 123)
    AuditAssert("F01 absent ID", ChatLogReader_ExtractChaseTargetID("no identifiers") = -1)
    AuditAssert("F01 nickname skips own name", ChatLogReader_ExtractNickname("Own_Player Other_Player") = "Other_Player")
    AuditAssert("F01 own nickname only terminates", ChatLogReader_ExtractNickname("Own_Player") = "")

    ChatQueueItems := [], ChatQueueMaxItems := 10, ChatQueueBusy := 0
    ChatQueueEnabled := "On", ChatQueueMaxRetries := 1, ChatQueueMinDelay := 250
    ChatQueueNextSendTick := 0, ChatQueueLastSendTick := 0, AuditTransportResult := -1
    AutoReportSentCount := 0, AutoReportSkippedCount := 0
    ChatQueue_Enqueue("failure", "AutoReport", 0, 0, 1)
    ChatQueue_Tick()
    AuditAssert("F02 -1 is retried, not counted as sent", ChatQueueItems.Length() = 1 && ChatQueueItems[1].Tries = 1 && AutoReportSentCount = 0)
    ChatQueueNextSendTick := 0
    ChatQueue_Tick()
    AuditAssert("F02 exhausted refusal is failure", ChatQueueItems.Length() = 0 && AutoReportSkippedCount = 1 && AutoReportSentCount = 0)
    AuditTransportResult := 1, ChatQueueNextSendTick := 0
    ChatQueue_Enqueue("success", "AutoReport", 0, 0, 1)
    ChatQueue_Tick()
    AuditAssert("F29 sent increments at transport completion", ChatQueueItems.Length() = 0 && AutoReportSentCount = 1)
    ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
    ChatQueueItems := []
    Loop, 9
        ChatQueue_Enqueue("pending " . A_Index, "test", 0, 0, 1)
    AuditAssert("F14 batch rejects without accepting prefix", !ChatQueue_EnqueueBatch(["one", "two"], "test") && ChatQueueItems.Length() = 9)
    ChatQueueItems := []
    SequenceLineDelay := 700
    UserID := 42
    AuditAssert("F14 RP action accepted", QueueRpAction("before`nafter", "/doc 42", "test", [1, 5, 1]))
    AuditAssert("F14 order includes command, menu, and RP after", ChatQueueItems.Length() = 4 && ChatQueueItems[1].Text = "before" && ChatQueueItems[2].Text = "/doc 42" && ChatQueueItems[3].Kind = "Menu" && ChatQueueItems[4].Text = "after")
    batch := ChatQueueItems[1].Batch
    AuditTransportResult := -1, ChatQueueMaxRetries := 0
    ChatQueue_Tick()
    AuditAssert("F14 failed batch cancels menu and RP after", ChatQueueItems.Length() = 0 && QueueBatchStates[batch].State = "failed")
    epoch := AutomationEpoch
    ChatQueueBusy := 1
    ChatQueue_Clear(0)
    AuditAssert("F13 cancellation preserves active sender ownership", ChatQueueBusy = 1 && AutomationEpoch = epoch + 1)
    ChatQueueBusy := 0
    CustomFunctionRunState := {Name: "cancelled", Steps: [], Index: 1}
    EvidenceScreenshotQueue := [1], EvidencePendingEvents := {test: 1}, ChatLogRescuePending := {StartedTick: 1}
    CancelAllAutomation(0)
    AuditAssert("F13 StopAll cancels custom runner and evidence", !IsObject(CustomFunctionRunState) && EvidenceScreenshotQueue.Length() = 0 && EvidencePendingEvents.Count() = 0 && !IsObject(ChatLogRescuePending))
    savedClipboard := ClipboardAll
    oldSequence := DllCall("GetClipboardSequenceNumber", "UInt")
    AuditAssert("F16 mock keyboard sender", SendChatKeyboard("mock"))
    AuditAssert("F16 mock input and screenshot are simulations", SafeSend("{F6}") && Evidence_SendKeyPress("F1", "LAlt"))
    AuditAssert("F16 mock does not touch clipboard", DllCall("GetClipboardSequenceNumber", "UInt") = oldSequence)
    AuditAssert("F13 cancelled command refuses transport", SendChatForEpoch(epoch - 1, "cancelled") = -1)
    AuditAssert("F13 cancelled paste refuses clipboard", !PasteOnlyForEpoch(epoch - 1, "cancelled"))
    AuditAssert("F13 cancelled epoch blocks input", !SafeSend("{Enter}", "Input", AutomationEpoch - 1))

    file := scratch . "\profiles.ini"
    seed := "[Unknown]`r`nPreserved=keep-me`r`n[Meta]`r`nConfigVersion=14`r`n"
    FileAppend, %seed%, %file%, CP1251
    originalHash := FileSHA256(file)
    ConfigReadOnly := 0, ConfigTransactionBusy := 0
    stage := ConfigStage(file)
    CheckedIniWrite("changed", stage, "Unknown", "Preserved")
    ConfigWriteFailed := 1
    AuditAssert("F18 injected write refusal rolls back", !ConfigCommit(stage, file) && FileSHA256(file) = originalHash)
    AuditAssert("F18 transaction lock released on failure", !ConfigTransactionBusy)
    stage := ConfigStage(file)
    values := ["", "  leading and trailing  ", """quoted""", "{NL}", "{RAW_NL}", "{RAW2_NL}", "H1:2:AA", "a`r`nb`nc`rd", "Применение оружия", "100% literal"]
    for index, value in values
        IniWriteText(value, stage, "Profile_Test", "Text" . index)
    AuditAssert("F18 successful atomic commit", ConfigCommit(stage, file))
    IniRead, preserved, %file%, Unknown, Preserved,
    AuditAssert("F18 unknown keys preserved", preserved = "keep-me")
    for index, value in values
        AuditAssert("F20 exact codec roundtrip " . index, IniReadText(file, "Profile_Test", "Text" . index, "MISSING") == value)
    AuditAssert("F20 missing key uses default", IniReadText(file, "Profile_Test", "missing", "fallback") = "fallback")
    CheckedIniWrite("{NL}", file, "Legacy", "Literal")
    AuditAssert("F20 legacy decoder retained", IniReadText(file, "Legacy", "Literal") = "`r`n")
    CheckedIniWrite("15", file, "Meta", "ConfigVersion")
    AuditAssert("F18 newer schema opens read-only", ConfigStage(file) = "" && ConfigReadOnly)
    ConfigReadOnly := 0
    abc := scratch . "\abc.txt"
    FileAppend, abc, %abc%, CP1251
    ; Exercise append/partial-line/rotation against a private producer-owned fixture.
    ChatLogPath := scratch . "\chatlog.txt"
    ChatLogReaderEnabled := "On", MockMode := "Off", AuditReaderLines := []
    FileAppend, initial`n, %ChatLogPath%, CP1251
    ChatLogReader_ResetGeneration()
    ChatLogReader_Tick()
    checkpoint := ChatLogLastPos
    FileAppend, partial, %ChatLogPath%, CP1251
    ChatLogReader_Tick()
    AuditAssert("F11 partial line retains checkpoint", ChatLogLastPos = checkpoint && AuditReaderLines.Length() = 0)
    FileAppend, complete`n, %ChatLogPath%, CP1251
    ChatLogReader_Tick()
    AuditAssert("F11 completed fragment dispatched exactly once", AuditReaderLines.Length() = 1 && AuditReaderLines[1] = "partialcomplete")
    ChatLogReader_Tick()
    AuditAssert("F11 no duplicate line dispatch", AuditReaderLines.Length() = 1)
    previousIdentity := ChatLogReaderIdentity
    FileMove, %ChatLogPath%, % ChatLogPath . ".old", 1
    FileAppend, new generation`n, %ChatLogPath%, CP1251
    ChatLogReader_Tick()
    AuditAssert("F30 replaced file establishes a new generation", ChatLogReaderIdentity != previousIdentity && ChatLogLastPos > 0 && AuditReaderLines.Length() = 1)
    ChatLogRescuePending := {ID: 7}
    cursorBeforeRewrite := ChatLogLastPos
    fixture := FileOpen(ChatLogPath, "w", "CP1251")
    fixture.Write("NEW GENERATION`r`n")
    fixture.Close()
    ChatLogReader_Tick()
    AuditAssert("F30 in-place rewrite resets cursor and pending state", !IsObject(ChatLogRescuePending) && ChatLogLastPos = cursorBeforeRewrite && AuditReaderLines.Length() = 1)
    AuditReaderLines := "", MockMode := "On"
    AuditAssert("F25 CNG SHA-256 known vector", FileSHA256(abc) = "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")
    AuditAssert("F25 missing path never runs a shell", FileSHA256(scratch . "\missing%PATH%.txt") = "")
    memory := DllCall("VirtualAlloc", "Ptr", 0x50000000, "UPtr", 4096, "UInt", 0x3000, "UInt", 4, "Ptr")
    if (memory) {
        NumPut(0, memory + 0, 0, "UInt")
        AuditAssert("F09 legitimate zero float", TryReadFloat(-1, memory, value) && value = 0)
        NumPut(0x7F800000, memory + 0, 0, "UInt")
        AuditAssert("F09 infinity rejected", !TryReadFloat(-1, memory, value))
        NumPut(0x7FC00000, memory + 0, 0, "UInt")
        AuditAssert("F09 NaN rejected", !TryReadFloat(-1, memory, value))
        DllCall("VirtualFree", "Ptr", memory, "UPtr", 0, "UInt", 0x8000)
    } else
        AuditSkip("F09 controlled float memory allocation unavailable")
    AuditAssert("F09 unreadable address rejected", !TryReadFloat(-1, 0, value))
    AuditAssert("F23 deadlines support uptime above 49.7 days", TaskScheduler_RemainingMs(0x100000000 + 700, 0x100000000 + 750) = -50)
    AuditAssert("F23 monotonic 64-bit clock", TickNow() >= 0)
    CFG_ThemePresetName := "", ThemeMode := "Graphite"
    CustomMenuColor := "FFFFFF", CustomTextColor := "F4F6F8", CustomBorderColor := "", CustomTabColor := "", CustomBindListColor := ""
    GetThemeColors(bg, panel, text, accent, muted)
    AuditAssert("F24 light override has readable text", ColorContrast(text, panel) >= 4.5 && ColorContrast(muted, panel) >= 4.5)
    CustomMenuColor := "101114", CustomTextColor := "111418"
    GetThemeColors(bg, panel, text, accent, muted)
    AuditAssert("F24 dark override has readable text", ColorContrast(text, panel) >= 4.5 && ColorContrast(muted, panel) >= 4.5)
    T_HijackStart := "preserve-start", T_HijackArrive := "preserve-arrive", AssistOOPEnabled := "Off"
    CFG_T_HijackStart := "", CFG_AssistOOPEnabled := 1
    SyncConfigOnlyProfileFieldsToCfg()
    AuditAssert("F19 hidden templates and flags preserved", CFG_T_HijackStart = "preserve-start" && CFG_T_HijackArrive = "preserve-arrive" && CFG_AssistOOPEnabled = 0)
    HistoricalHotstrings := {}, HistoricalHotstringCount := 0
    Loop, 512
        Hotstring_AdmitPattern(":*:audit" . A_Index)
    AuditAssert("F28 repeated pattern allowed, new pattern capped", Hotstring_AdmitPattern(":*:audit1") && !Hotstring_AdmitPattern(":*:audit513"))
    ChatQueuePreviewText := ""
    Loop, 650
        MockPreview_Append("preview " . A_Index)
    AuditAssert("F12 preview bounded", StrSplit(ChatQueuePreviewText, "`n").Length() <= 500 && StrLen(ChatQueuePreviewText) <= 131072)
    AuditAssert("F07 no reference build blocks memory writes", !MemoryBuildCompatible())
    sha := ""
    Loop, 64
        sha .= "A"
    AuditAssert("Auto ID: read-only accepts no hash with x86 module", MemoryReadBuildPolicy("", true))
    AuditAssert("Auto ID: read-only rejects x64 module", !MemoryReadBuildPolicy("", false))
    AuditAssert("Auto ID: explicit hash mismatch stays blocked", !MemoryReadBuildPolicy(sha, true, false))
    AuditAssert("Auto ID: explicit verified hash permits read", MemoryReadBuildPolicy(sha, true, true))
    AuditAssert("Auto ID: malformed explicit hash cannot bypass", !MemoryReadBuildPolicy("BAD", true, true))
    AuditAssert("Auto ID: explicit hash cannot permit x64 layout", !MemoryReadBuildPolicy(sha, false, true))
    VarSetCapacity(header, 4096, 0)
    NumPut(0x5A4D, header, 0, "UShort")
    NumPut(128, header, 0x3C, "UInt")
    NumPut(0x4550, header, 128, "UInt")
    NumPut(0x14C, header, 132, "UShort")
    NumPut(224, header, 148, "UShort")
    NumPut(0x2000, header, 150, "UShort")
    NumPut(0x10B, header, 152, "UShort")
    NumPut(0x300000, header, 208, "UInt")
    NumPut(512, header, 212, "UInt")
    AuditAssert("Auto ID: valid bounded PE32 DLL accepted", MemoryReadPe32Header(header, 4096))
    NumPut(0x8664, header, 132, "UShort")
    AuditAssert("Auto ID: PE64 module refused", !MemoryReadPe32Header(header, 4096))
    NumPut(0x14C, header, 132, "UShort")
    NumPut(0x400, header, 208, "UInt")
    AuditAssert("Auto ID: module too small for read offsets refused", !MemoryReadPe32Header(header, 4096))
    NumPut(0x300000, header, 208, "UInt")
    NumPut(0xFFFF0000, header, 0x3C, "UInt")
    AuditAssert("Auto ID: out-of-range PE header refused", !MemoryReadPe32Header(header, 4096))
    AuditAssert("Auto ID: first exact ID qualifies immediately", AutoTargetID_ObserveCandidate(42, "Test_Player", 0x200000, 1) >= AutoTargetID_RequiredReads(1, false))
    AuditAssert("Auto ID: mask retains repeated observations", AutoTargetID_RequiredReads(3, false) = 3 && AutoTargetID_RequiredReads(4, true) = 3)
    AuditAssert("Auto ID: same target accumulates", AutoTargetID_ObserveCandidate(42, "Test_Player", 0x200000, 1) = 2)
    AuditAssert("Auto ID: same ID different PED resets", AutoTargetID_ObserveCandidate(42, "Test_Player", 0x300000, 1) = 1 && AutoTargetCandidatePed = 0x300000)
    AutoTargetID_ResetCandidate()
    AuditAssert("Auto ID: lost target resets candidate", AutoTargetCandidateReads = 0 && AutoTargetCandidatePed = 0 && AutoTargetCandidateID = -1)
    AuditAssert("OBS exclusion requires 0x11", Capture_AffinityMatches(1, 1, 0x11))
    AuditAssert("OBS disabled confirmed at zero", Capture_AffinityMatches(0, 1, 0))
    AuditAssert("OBS failed read rejects cached success", !Capture_AffinityMatches(1, 0, 0x11))
    AuditAssert("OBS WDA_MONITOR is not exclusion", !Capture_AffinityMatches(1, 1, 1))
    AuditAssert("OBS missing state retries", Capture_ShouldRetry("", 1, 100))
    retryState := {Enabled: 1, NextRetry: 2000}
    AuditAssert("OBS errors throttled before deadline", !Capture_ShouldRetry(retryState, 1, 1999))
    AuditAssert("OBS error retry reaches deadline", Capture_ShouldRetry(retryState, 1, 2000))
    AuditAssert("OBS changed option retries immediately", Capture_ShouldRetry(retryState, 0, 0))
    AuditAssert("F10 reader never truncates chatlog", !ChatLogReader_MaybeCleanup(file) && FileExist(file))

    LawSearchCorpusSignature := "", SearchInitialized := 0
    LawSearch_Init()
    AuditAssert("F21 official LAW corpus loaded", LawSearchMissingDocuments.Length() = 0 && SearchIndex.Length() > 20)
    AuditAssert("search exact reference TER", LawSearch_CheckExpected("ФЗТЕР гл. 3 ст. 9.2 ч. 2", "ALL", "TER", "9.2", "2", 3))
    AuditAssert("search compact KOAP reference", LawSearch_CheckExpected("коап ст17.5", "ALL", "KOAP", "17.5", "", 3))
    AuditAssert("search natural phrase", LawSearch_CheckExpected("как правильно применять оружие", "ALL", "FZOP", "16", "1", 5))
    AuditAssert("search typo", LawSearch_CheckExpected("приминение оружия", "ALL", "FZOP", "16", "1", 5))
    AuditAssert("search nonsense does not invent results", LawSearch_CheckNoResults("абракадабра фывапролдж", "ALL"))
    parsed := LawSearch_ParseQuery("""применение оружия"" -служебного")
    AuditAssert("search quote and exclusion syntax", parsed.RequiredPhrases.Length() = 1 && parsed.ExcludedTokens[1] = "служебного")
    package := LawSearch_Find("ALL", """применение оружия"" -служебного", 30)
    exactFilters := package.Results.Length() > 0
    for _, result in package.Results {
        item := result.Item
        if (!LawSearch_HasPhrase(item.NormTitle . " " . item.NormBody, "применение оружия") || LawSearch_HasExactWord(item.NormTitle . " " . item.NormBody, "служебного"))
            exactFilters := false
    }
    AuditAssert("search quotes required and exclusions enforced", exactFilters)
    Audit_CorpusReload()
    AuditAssert("F24 settings fits work area", Audit_ViewportCheck())
    if (A_PtrSize != 4 || A_IsUnicode)
        AuditSkip("ANSI x86 game ABI, module enumeration and HANDLE lifecycle need Windows A32 integration")
    AuditSkip("Real Windows GUI/DPI, OBS capture, game offsets, remote-thread stress and screenshot files require target integration")
    AuditReport .= "`r`nChecks: " . AuditChecks . " | Failed: " . AuditFailures . " | Skipped integration groups: " . AuditSkipped . "`r`n"
    reportPath := A_ScriptDir . "\audit_selftest_report.txt"
    FileDelete, %reportPath%
    FileAppend, %AuditReport%, %reportPath%, CP1251
    reportFailed := ErrorLevel
    FileRemoveDir, %scratch%, 1
    return !reportFailed && AuditFailures = 0
}

AuditAssert(name, ok) {
    global AuditReport, AuditChecks, AuditFailures
    AuditChecks++
    if (!ok)
        AuditFailures++
    line := (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
    AuditReport .= line
    FileAppend, %line%, *, UTF-8
    return ok
}

AuditSkip(name) {
    global AuditReport, AuditSkipped
    AuditSkipped++
    AuditReport .= "SKIP | " . name . "`r`n"
}

Audit_CorpusReload() {
    global LawSearchDocCatalog, LawCorpusCache, LawCorpusPages, SearchInitialized
    fileName := "_audit_" . DllCall("GetCurrentProcessId") . ".txt"
    path := A_ScriptDir . "\laws\" . fileName
    if FileExist(path) {
        AuditSkip("owned temporary LAW filename collision")
        return
    }
    original := LawSearchDocCatalog.Clone()
    meta := {Code: "AUDIT", Name: "Audit", Short: "Audit", Prefix: "audit", FileName: fileName, Aliases: "audit", Order: 999}
    LawSearchDocCatalog.Push(meta)
    try {
        AuditAssert("F21 missing text is not cached", LawCorpus_GetText("audit") = "" && !LawCorpusCache.HasKey("audit"))
        AuditAssert("F21 missing pages are not cached", LawCorpus_BuildPages("audit").Length() = 0 && !LawCorpusPages.HasKey("audit"))
        body := "Статья 1. Проверка`r`n1. восстановленный документ.`r`n"
        FileAppend, %body%, %path%, CP1251
        AuditAssert("F21 newly supplied document loads", InStr(LawCorpus_GetText("audit"), "восстановленный документ"))
        previousSignature := LawSearchCorpusSignature
        LawSearch_Init()
        AuditAssert("F21 query index follows corpus generation", LawSearchCorpusSignature != previousSignature && SearchIndexCounts.HasKey("AUDIT"))
    } finally {
        FileDelete, %path%
        LawSearchDocCatalog := original
        SearchInitialized := 0
        LawSearch_Init()
    }
}

Audit_ViewportCheck() {
    global SettingsX, SettingsY, SettingsW, SettingsH
    SettingsX := 0, SettingsY := 0
    Settings_NormalizeViewport()
    SysGet, primary, MonitorPrimary
    SysGet, area, MonitorWorkArea, %primary%
    return SettingsW <= areaRight - areaLeft && SettingsH <= areaBottom - areaTop
}
