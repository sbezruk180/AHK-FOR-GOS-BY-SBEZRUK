; diagnostics subsystem. Definitions only; initialization is in bootstrap.

RunContextAssistantMockTest() {
    global MockMode, ChatQueueEnabled, ChatQueueMinDelay, ChatQueueItems, ChatQueueBusy
    global ChatQueueLastSendTick, ChatQueueNextSendTick
    global ChatQueuePreviewText, ChatTransportStatus, ActionCooldownMs, LastActionTick
    global SafeModeEnabled, SafeBlockWhenChat, SafeDistanceChecks, SafeTooltipWarnings
    global NotifySoundEnabled, ThemeMode, AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    global UserID, ActiveID, ModernLogFile, ErrorLogFile, LogDir, MaxLogBytes

    MockMode := "On"
    ChatQueueEnabled := "Off"
    ChatQueueMinDelay := 250
    ChatQueueItems := []
    ChatQueueBusy := 0
    ChatQueuePreviewText := ""
    ChatTransportStatus := "Ожидание"
    ActionCooldownMs := 0
    LastActionTick := 0
    SafeModeEnabled := "Off"
    SafeBlockWhenChat := "Off"
    SafeDistanceChecks := "Off"
    SafeTooltipWarnings := "Off"
    NotifySoundEnabled := "Off"
    ThemeMode := "Graphite"
    AssistOOPCommand := "/find {ID}"
    AssistTaserCommand := "/tazer {ID}"
    AssistBatonCommand := "/baton {ID}"
    UserID := ""
    ActiveID := 0
    LogDir := AppHost_DataDir() . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    ErrorLogFile := AppHost_DataDir() . "\error_log.txt"
    MaxLogBytes := 262144

    ok := true
    ok := ContextAssistant_Execute("OOPSearch", "41") && ok
    ok := ContextAssistant_Execute("Stun", "42", "taser") && ok
    ok := ContextAssistant_Execute("Stun", "43", "baton") && ok
    ok := ContextAssistant_Execute("Chase", "44") && ok
    ok := ContextAssistant_Execute("Chase", "1002") && ok
    ok := ContextAssistant_Execute("HouseAlarm", "155") && ok
    ok := ContextAssistant_Execute("DrugsNearby", "46") && ok
    ok := ContextAssistant_Execute("PDPCuff", "47") && ok

    parserIdOk := (ChatLogReader_ExtractID("Вы оглушили Test_Player[77] с помощью электрошокера") = 77)
    parserChaseTargetOk := (ChatLogReader_ExtractChaseTargetID("Officer_Name[15] начал преследование Player_Name[77]") = 77)
    parserChaseSingleOk := (ChatLogReader_ExtractChaseTargetID("Вы начали преследование Player_Name[88]") = 88)
    parserNameOk := (ChatLogReader_ExtractNickname("Вы оглушили Test_Player с помощью электрошокера") = "Test_Player")
    ChatQueue_Clear(0)
    ChatQueueLastSendTick := 0
    ChatQueueNextSendTick := 0
    lookupQueueOk := ChatLogReader_BeginLookup("OOPSearch", "Test_Player")
    ChatQueue_Tick()
    lookupQueueOk := lookupQueueOk && InStr(ChatQueuePreviewText, "/id Test_Player")
    ChatLogReader_ClearLookup()
    ok := parserIdOk && parserChaseTargetOk && parserChaseSingleOk && parserNameOk && lookupQueueOk && ok

    expectedLines := ["/find 41", "/tazer 42", "/baton 43", "/chase 44", "/chase 1002", "[GPS] Отметить дом №155 по сигнализации", "[ID] Наркотики рядом — сохранён ID 46", "/cuff 47", "/id Test_Player"]
    report := "AHK FOR GOS BY SBEZRUK context assistant MockMode test`r`n"
    report .= "Time: " . A_YYYY . "-" . A_MM . "-" . A_DD . " " . A_Hour . ":" . A_Min . ":" . A_Sec . "`r`n`r`n"
    Loop % expectedLines.Length()
    {
        expectedLine := expectedLines[A_Index]
        found := InStr(ChatQueuePreviewText, expectedLine) > 0
        if (!found)
            ok := false
        report .= (found ? "[PASS] " : "[FAIL] ") . expectedLine . "`r`n"
    }
    report .= (parserIdOk ? "[PASS] " : "[FAIL] ") . "ChatLog ID parser`r`n"
    report .= (parserChaseTargetOk ? "[PASS] " : "[FAIL] ") . "Chase parser selects second ID`r`n"
    report .= (parserChaseSingleOk ? "[PASS] " : "[FAIL] ") . "Chase parser keeps single ID`r`n"
    report .= (parserNameOk ? "[PASS] " : "[FAIL] ") . "ChatLog nickname parser`r`n"
    report .= (lookupQueueOk ? "[PASS] " : "[FAIL] ") . "ChatLog /id through ChatQueue`r`n"
    report .= "`r`nStatus: " . (ok ? "PASS" : "FAIL") . "`r`n"
    report .= "Final ID: " . UserID . "`r`n"
    report .= "`r`nPreview:`r`n" . ChatQueuePreviewText . "`r`n"

    reportPath := AppHost_DataDir() . "\context_assistant_test.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    Gui, 41:Destroy
    return ok
}

V1_FileName(path) {
    SplitPath, path, name
    return name
}

V1_GetBetween(text, startMarker, endMarker) {
    startPos := InStr(text, "`n" . startMarker)
    if !startPos
        startPos := InStr(text, startMarker)
    if !startPos
        return ""
    ; Function definitions are no longer necessarily adjacent after modularization.
    ; Inspect the actual function body instead of unrelated following modules.
    if RegExMatch(startMarker, "^[A-Za-z_][A-Za-z0-9_]*\(") {
        body := "", sawBrace := false
        fragment := SubStr(text, startPos)
        Loop, Parse, fragment, `n, `r
        {
            body .= A_LoopField . "`r`n"
            if InStr(A_LoopField, "{")
                sawBrace := true
            if (sawBrace && V1_BraceBalance(body) = 0)
                return body
        }
    }
    endPos := InStr(text, "`n" . endMarker, false, startPos + StrLen(startMarker))
    if !endPos
        endPos := StrLen(text) + 1
    return SubStr(text, startPos, endPos - startPos)
}

V1_HasOnlyCrlf(path) {
    if (A_IsCompiled && (path = A_ScriptFullPath || RegExMatch(path, "i)\.ahk$|[\\/]laws[\\/]"))) {
        text := AppHost_SourceFile(path)
        return InStr(text, "`r`n") && !InStr(StrReplace(text, "`r`n"), "`n")
    }
    file := FileOpen(path, "r")
    if !IsObject(file)
        return false
    size := file.Length
    VarSetCapacity(data, size, 0)
    read := file.RawRead(data, size)
    file.Close()
    previous := -1, hasLf := false
    Loop % read
    {
        value := NumGet(data, A_Index - 1, "UChar")
        if (value = 10) {
            hasLf := true
            if (previous != 13)
                return false
        }
        previous := value
    }
    return hasLf
}

V1_BraceBalance(text) {
    balance := 0
    Loop, Parse, text, `n, `r
    {
        line := A_LoopField
        inString := false
        index := 1
        while (index <= StrLen(line))
        {
            char := SubStr(line, index, 1)
            if (char = """") {
                if (inString && SubStr(line, index + 1, 1) = """") {
                    index += 2
                    continue
                }
                inString := !inString
            } else if (!inString && char = ";")
                break
            else if (!inString && char = "{")
                balance++
            else if (!inString && char = "}")
                balance--
            index++
        }
    }
    return balance
}

V1_Join(items) {
    out := ""
    count := IsObject(items) ? items.Length() : 0
    Loop % count
        out .= (out = "" ? "" : ", ") . items[A_Index]
    return out
}

V1_HasDuplicateFunctions(text, ByRef details) {
    seen := {}, duplicates := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "^([A-Za-z_][A-Za-z0-9_]*)\([^)]*\)\s*\{", match)
            continue
        key := match1
        StringLower, key, key
        if seen.HasKey(key)
            duplicates.Push(match1)
        else
            seen[key] := 1
    }
    details := V1_Join(duplicates)
    return duplicates.Length() > 0
}

V1_HasDuplicateLabels(text, ByRef details) {
    seen := {}, duplicates := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "^([A-Za-z_][A-Za-z0-9_]*):\s*$", match)
            continue
        key := match1
        StringLower, key, key
        if seen.HasKey(key)
            duplicates.Push(match1)
        else
            seen[key] := 1
    }
    details := V1_Join(duplicates)
    return duplicates.Length() > 0
}

V1_AllGosubTargetsExist(text, ByRef details) {
    checked := {}, missing := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "i)^\s*Gosub,\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", match)
            continue
        key := match1
        StringLower, key, key
        if checked.HasKey(key)
            continue
        checked[key] := 1
        if !RegExMatch(text, "im)^" . match1 . ":\s*$")
            missing.Push(match1)
    }
    details := V1_Join(missing)
    return missing.Length() = 0
}

V1_RunMigrationTest(ByRef details) {
    global AppVersion
    AppVersion := "1.1"
    dir := A_Temp . "\AMZ_GOS_V13_" . DllCall("GetCurrentProcessId") . "_" . TickNow()
    FileCreateDir, %dir%
    fileName := dir . "\profiles.ini"
    seed := "[Profiles]`r`nNames=Основной|Резервный`r`nLast=Основной`r`n[Profile_Основной]`r`n"
    seed .= "ReportRole=Моя должность`r`nT_CivilCallStart=Мой доклад`r`n"
    seed .= "Bind_ToggleHUD=F9`r`nTerritoryMapMode=Forum`r`nUnknownLegacyKey=keep-me`r`n"
    seed .= "MDS_EvacReminder=remove-me`r`nBind_MDSEvacReminder=F8`r`nTrig_MDSEvacReminder=!эвдок`r`n"
    seed .= "[Profile_Резервный]`r`nSurname=Тестов`r`n"
    seed .= "[Meta]`r`nConfigVersion=10`r`n"
    FileAppend, %seed%, %fileName%
    firstOk := MigrateV11Configuration(fileName) && MigrateV12Configuration(fileName) && MigrateV13Configuration(fileName)
    firstText := SelfTest_ReadFile(fileName)
    secondOk := MigrateV11Configuration(fileName) && MigrateV12Configuration(fileName) && MigrateV13Configuration(fileName)
    secondText := SelfTest_ReadFile(fileName)
    IniRead, role, %fileName%, Profile_Основной, ReportRole, ERROR
    civil := IniReadText(fileName, "Profile_Основной", "T_CivilCallStart", "ERROR")
    IniRead, hud, %fileName%, Profile_Основной, Bind_ToggleHUD, ERROR
    IniRead, legacy, %fileName%, Profile_Основной, UnknownLegacyKey, ERROR
    IniRead, chase, %fileName%, Profile_Основной, Bind_ChaseNoID, ERROR
    IniRead, lawKey, %fileName%, Profile_Основной, Bind_LawSearchSubmit, ERROR
    IniRead, autoMode, %fileName%, Profile_Основной, AutoReportMode, ERROR
    IniRead, mapMode, %fileName%, Profile_Основной, TerritoryMapMode, ERROR
    IniRead, reserveMapMode, %fileName%, Profile_Резервный, TerritoryMapMode, ERROR
    IniRead, autoPatrolTrigger, %fileName%, Profile_Основной, Trig_AutoPatrol, ERROR
    IniRead, autoPostTrigger, %fileName%, Profile_Основной, Trig_AutoPost, ERROR
    IniRead, removedMds, %fileName%, Profile_Основной, MDS_EvacReminder, __REMOVED__
    ok := firstOk && secondOk && firstText = secondText
        && role = "Моя должность" && civil = "Мой доклад" && hud = "F9"
        && legacy = "keep-me" && chase = "Insert" && lawKey = "^+f" && autoMode = "Патруль"
        && mapMode = "Forum" && reserveMapMode = "Local"
        && autoPatrolTrigger = "!апатруль" && autoPostTrigger = "!апост" && removedMds = "__REMOVED__"
    details := ok ? "repeat is byte-stable; new commands added; obsolete MDS keys removed" : "migration assertion failed"
    FileDelete, %fileName%
    FileRemoveDir, %dir%
    return ok
}

V1_CheckV12Pipeline(mainText, ByRef details) {
    migration := V1_GetBetween(mainText, "MigrateV11Configuration(", "MigrateConfigIfNeeded(")
        . V1_GetBetween(mainText, "MigrateV12Configuration(", "MigrateConfigIfNeeded(")
    loader := V1_GetBetween(mainText, "LoadProfileV9FieldsFromIni(", "WriteProfileV9FieldsToIni(")
    writer := V1_GetBetween(mainText, "WriteProfileV9FieldsToIni(", "NormalizeProfileMode(")
    fields := ["ReportRole", "T_CivilCallStart", "T_CivilCallArrive"
        , "Bind_CivilCallStart", "Bind_CivilCallArrive", "Trig_CivilCallStart", "Trig_CivilCallArrive"
        , "Bind_VehicleLookup", "Trig_VehicleLookup", "Bind_WantedRemoval", "Trig_WantedRemoval"
        , "Bind_ChaseNoID", "Trig_ChaseNoID", "Bind_LawSearchSubmit"
        , "AutoReportMode", "AutoReportDurationMin", "TerritoryMapMode"]
    missing := []
    Loop % fields.Length()
    {
        field := fields[A_Index]
        if (!InStr(migration, field) || !InStr(loader, field) || !InStr(writer, field)
            || !InStr(mainText, "global CFG_" . field . " :="))
            missing.Push(field)
    }
    backupPos := InStr(mainText, "backupFile := CreateConfigBackup(""migrate_v""")
    migratePos := InStr(mainText, "storedVersion < 12 && !MigrateV12Configuration(", false, backupPos)
    backupOk := backupPos > 0 && migratePos > backupPos
    details := missing.Length() ? V1_Join(missing) : (backupOk ? "17 fields and pre-migration backup" : "backup hook missing")
    return missing.Length() = 0 && backupOk
}

V1_CheckTemplates(ByRef details) {
    global IntroRole, ReportRole, Rank, ReportRank, Surname
    global PatrolUnit, PatrolRoute, PatrolCrewCount, PostUnit, PostRoute, PostCrewCount, ConvoyRoute
    saved := {IntroRole:IntroRole, ReportRole:ReportRole, Rank:Rank, ReportRank:ReportRank, Surname:Surname
        , PatrolUnit:PatrolUnit, PatrolRoute:PatrolRoute, PatrolCrewCount:PatrolCrewCount
        , PostUnit:PostUnit, PostRoute:PostRoute, PostCrewCount:PostCrewCount, ConvoyRoute:ConvoyRoute}
    IntroRole := "начальником МДС ГАИ", ReportRole := "Начальник МДС ГАИ"
    Rank := "лейтенант", ReportRank := "лейтенант", Surname := "Лукашенко"
    PatrolUnit := "Р101", PatrolRoute := "А-1", PatrolCrewCount := "2"
    PostUnit := "Р202", PostRoute := "АП ГАИ", PostCrewCount := "3", ConvoyRoute := "А-Б"
    pairs := []
    pairs.Push(["Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}.", "Здравия желаю, являюсь начальником МДС ГАИ, лейтенант полиции Лукашенко."])
    pairs.Push(["/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь.", "/d [ГАИ/] говорит Начальник МДС ГАИ, лейтенант полиции Лукашенко, на связь."])
    pairs.Push(["/r докладывает {SURNAME}: реагирую на вызов срочной помощи.", "/r докладывает Лукашенко: реагирую на вызов срочной помощи."])
    pairs.Push(["/r докладывает {SURNAME}: прибыл на вызов срочной помощи.", "/r докладывает Лукашенко: прибыл на вызов срочной помощи."])
    pairs.Push(["/r докладывает {SURNAME}: принял вызов гражданского.", "/r докладывает Лукашенко: принял вызов гражданского."])
    pairs.Push(["/r докладывает {SURNAME}: прибыл на вызов гражданского.", "/r докладывает Лукашенко: прибыл на вызов гражданского."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП.", "/r докладывает экипаж Р101: принял вызов о ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП.", "/r докладывает экипаж Р101: прибыли на вызов о ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП.", "/r докладывает экипаж Р101: приступили к оформлению ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП.", "/r докладывает экипаж Р101: завершили оформление ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек.", "/r докладывает экипаж Р101: патрулируем по маршруту А-1 в составе 2 человек."])
    pairs.Push(["/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек.", "/r докладывает экипаж Р202: продолжаем стоять на посту АП ГАИ в составе 3 человек."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}.", "/r докладывает экипаж Р101: продолжаем сопровождение военной колонны по маршруту А-Б."])
    ok := true
    Loop % pairs.Length()
    {
        actual := ApplyTemplate(pairs[A_Index][1])
        if (actual != pairs[A_Index][2] || RegExMatch(actual, "\{[A-Z0-9_]+\}"))
            ok := false
    }
    IntroRole := saved.IntroRole, ReportRole := saved.ReportRole, Rank := saved.Rank
    ReportRank := saved.ReportRank, Surname := saved.Surname, PatrolUnit := saved.PatrolUnit
    PatrolRoute := saved.PatrolRoute, PatrolCrewCount := saved.PatrolCrewCount
    PostUnit := saved.PostUnit, PostRoute := saved.PostRoute, PostCrewCount := saved.PostCrewCount
    ConvoyRoute := saved.ConvoyRoute
    details := ok ? pairs.Length() . " exact expansions" : "template mismatch or unresolved placeholder"
    return ok
}

V1_CheckCatalog(ByRef details) {
    catalog := GetBindCatalog(), seen := {}, issues := []
    required := {"CivilCallStart":0, "CivilCallArrive":0, "VehicleLookup":0
        , "WantedRemoval":0, "ChaseNoID":0, "LawSearchSubmit":0
        , "AutoPatrol":0, "AutoPost":0}
    assist := {"AssistOOP":0, "AssistStun":0, "AssistChase":0
        , "AssistHouse":0, "AssistDrugs":0, "AssistPDPCuff":0}
    special := {"OpenSettings":1, "ToggleBindList":1, "ToggleHUD":1, "GpsD":1, "GpsOS":1}
    hijackCount := 0
    Loop % catalog.Length()
    {
        meta := catalog[A_Index], key := meta.Token
        StringLower, key, key
        if seen.HasKey(key)
            issues.Push("duplicate " . meta.Token)
        seen[key] := 1
        if required.HasKey(meta.Token)
            required[meta.Token] := BindCatalog_IsRegistrable(meta) && BindCatalog_IsUserVisible(meta)
        if assist.HasKey(meta.Token)
            assist[meta.Token] := meta.InternalOnly && !meta.Enabled && !meta.ExposeInSettings
                && !BindCatalog_IsRegistrable(meta)
        if (meta.Token = "HijackStart" || meta.Token = "HijackArrive") {
            if (meta.LegacyOnly && !meta.Enabled && !meta.ExposeInSettings && !BindCatalog_IsRegistrable(meta))
                hijackCount++
        }
        if BindCatalog_IsRegistrable(meta) && !special.HasKey(meta.Token) {
            handler := GetBoundLabelByToken(meta.Token)
            if (handler = "" || !IsLabel(handler))
                issues.Push("handler " . meta.Token)
        }
    }
    for token, present in required
        if !present
            issues.Push("required " . token)
    for token, hidden in assist
        if !hidden
            issues.Push("Assist " . token)
    if (hijackCount != 2)
        issues.Push("Hijack legacy flags")
    details := issues.Length() ? V1_Join(issues) : catalog.Length() . " unique items; 8 required; 6 Assist internal; 2 Hijack legacy"
    return issues.Length() = 0
}

V1_CheckProfileConflicts(fileName, ByRef details) {
    IniRead, profile, %fileName%, Profiles, Last, Основной
    section := "Profile_" . profile
    hotkeys := {}, triggers := {}, conflicts := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.HotkeyVar != "") {
            iniKey := meta.HotkeyVar
            IniRead, value, %fileName%, %section%, %iniKey%,
            NormalizeHotkeyValue(value)
            value := NormalizeHotkeyId(value)
            if (value != "" && hotkeys.HasKey(value))
                conflicts.Push(value . ": " . hotkeys[value] . "/" . meta.Token)
            else if (value != "")
                hotkeys[value] := meta.Token
        }
        if (meta.TriggerVar != "") {
            iniKey := meta.TriggerVar
            IniRead, value, %fileName%, %section%, %iniKey%,
            NormalizeTextTrigger(value)
            StringLower, value, value
            if (value != "" && triggers.HasKey(value))
                conflicts.Push(value . ": " . triggers[value] . "/" . meta.Token)
            else if (value != "")
                triggers[value] := meta.Token
        }
    }
    details := conflicts.Length() ? V1_Join(conflicts) : "no conflicts"
    return conflicts.Length() = 0
}

RunSelfTestV1() {
    global SelfTestCriticalFailed, SelfTestHighFailed, SelfTestMediumWarnings, SelfTestLowNotes, SelfTestTotal
    global AppVersion, ConfigVersion
    global LawSearchDocCatalog

    AppVersion := "1.1", ConfigVersion := 14
    SelfTestCriticalFailed := 0, SelfTestHighFailed := 0
    SelfTestMediumWarnings := 0, SelfTestLowNotes := 0, SelfTestTotal := 0

    root := AppHost_DataDir()
    mainPath := A_ScriptFullPath
    profilePath := FileExist(root . "\profiles_updated.ini") ? root . "\profiles_updated.ini" : root . "\profiles.ini"
    paths := [mainPath, A_ScriptDir . "\helper.ahk", A_ScriptDir . "\UDF.ahk", A_ScriptDir . "\common.ahk"]
    mainText := SelfTest_ReadFile(mainPath)
    helperText := ""
    udfText := SelfTest_ReadFile(A_ScriptDir . "\UDF.ahk")
    commonText := SelfTest_ReadFile(A_ScriptDir . "\common.ahk")

    report := "AHK FOR GOS BY SBEZRUK v1.1 regression self-test`r`n"
    report .= "Runtime: AutoHotkey " . A_AhkVersion . " | ANSI=" . (!A_IsUnicode) . " | PtrSize=" . A_PtrSize . "`r`n"
    report .= "Project: " . A_ScriptDir . "`r`nData: " . root . "`r`nLIVE GAME: NOT RUN`r`n`r`n"

    Loop % paths.Length()
    {
        path := paths[A_Index]
        SelfTest_Add(report, "Critical", "file exists: " . V1_FileName(path), SelfTest_FileExistsNonEmpty(path))
        SelfTest_Add(report, "High", "CP1251 artifact has no BOM: " . V1_FileName(path), SelfTest_HasNoBom(path))
        SelfTest_Add(report, "High", "CRLF only: " . V1_FileName(path), V1_HasOnlyCrlf(path))
    }
    LawSearch_InitCatalog()
    Loop % LawSearchDocCatalog.Length()
    {
        lawMeta := LawSearchDocCatalog[A_Index]
        lawPath := root . "\laws\" . lawMeta.FileName
        SelfTest_Add(report, "Critical", "official law exists: " . lawMeta.Code, SelfTest_FileExistsNonEmpty(lawPath))
        SelfTest_Add(report, "High", "official law has no BOM: " . lawMeta.Code, SelfTest_HasNoBom(lawPath))
        SelfTest_Add(report, "High", "official law CRLF only: " . lawMeta.Code, V1_HasOnlyCrlf(lawPath))
    }
    SelfTest_Add(report, "Critical", "AHK v1.1 ANSI 32-bit runtime"
        , !A_IsUnicode && A_PtrSize = 4 && SubStr(A_AhkVersion, 1, 4) = "1.1.")
    SelfTest_Add(report, "Critical", "release v1.1 and schema v14"
        , InStr(mainText, "AppVersion := ""1.1""") && InStr(mainText, "ConfigVersion := 14"))
    IniRead, iniSchema, %profilePath%, Meta, ConfigVersion, 0
    IniRead, iniRelease, %profilePath%, Meta, AppVersion, 0
    SelfTest_Add(report, "Critical", "active INI uses compatible release and schema v14", iniSchema = 14 && (iniRelease = "1.0" || iniRelease = "1.1"))
    SelfTest_Add(report, "Critical", "single helper and modular include contract"
        , IsFunc("AppHost_Init") && IsFunc("LawCorpus_GetText") && IsFunc("AutoTargetID_Poll")
        && V1_HasDuplicateFunctions(mainText, duplicates) = false, duplicates)
    removedMethodFile := "method_" . "helper.ahk"
    methodRemovedOk := !FileExist(root . "\" . removedMethodFile)
        && !InStr(mainText, removedMethodFile)
        && !InStr(mainText, "RegisterTextTrigger(""Meth" . "od_")
        && !InStr(mainText, "DoMeth" . "od")
        && !InStr(mainText, "Meth" . "odDoc")
        && !InStr(mainText, "Meth" . "odSearch")
    SelfTest_Add(report, "Critical", "method helper is fully removed", methodRemovedOk)
    SelfTest_Add(report, "Critical", "pointer validation supports x86 LargeAddressAware"
        , IsLikelyPointer(0x80000000) && IsLikelyPointer(0xFFFEFFFF)
            && !IsLikelyPointer(0xFFFF0000))
    SelfTest_Add(report, "Critical", "Auto ID keeps a validated cache across stable reads"
        , InStr(udfText, "AZMP_TARGET_CACHE_TTL := 1000")
            && InStr(udfText, "AZMP_GetPlayerInfo(AZMP_TARGET_CACHE_ID, playerPool, 1)"))
    SelfTest_Add(report, "High", "NOT_IN_POOL uses soft pool refresh"
        , InStr(udfText, "AZMP_TargetDiagMaybeRefreshNotInPool(targetPed, playerPool, detail)")
            && InStr(mainText, "AutoTargetID_IsHardRecoveryCode(code)"))
    serviceCodesSection := V1_GetBetween(mainText, "ServiceCodes_" . "Show() {", "DoBindMenuToggle:")
    serviceCodesLabelSection := V1_GetBetween(mainText, "DoServiceCodes" . "Gui:", "DoVehicleLookup:")
    SelfTest_Add(report, "High", "!коды reuses legislation GUI"
        , InStr(serviceCodesSection, "LawGui_" . "Show(1, ""Служебные коды""")
            && InStr(serviceCodesLabelSection, "Helper_CloseChatAfterGui()")
            && InStr(mainText, "#If (Service" . "CodesGuiVisible || current_doc >= 21)"))

    allCode := mainText
    SelfTest_Add(report, "Critical", "balanced code braces", V1_BraceBalance(allCode) = 0
        , "delta=" . V1_BraceBalance(allCode))
    SelfTest_Add(report, "Critical", "no duplicate functions", !V1_HasDuplicateFunctions(allCode, duplicateFunctions), duplicateFunctions)
    SelfTest_Add(report, "Critical", "no duplicate labels", !V1_HasDuplicateLabels(mainText, duplicateLabels), duplicateLabels)
    SelfTest_Add(report, "Critical", "literal Gosub targets exist", V1_AllGosubTargetsExist(mainText, missingGosub), missingGosub)

    SelfTest_Add(report, "Critical", "v13 migration is idempotent and legacy-safe"
        , V1_RunMigrationTest(migrationDetails), migrationDetails)
    SelfTest_Add(report, "Critical", "all v12 fields are in read/write pipeline"
        , V1_CheckV12Pipeline(mainText, pipelineDetails), pipelineDetails)

    SelfTest_Add(report, "Critical", "two role forms and exact templates"
        , V1_CheckTemplates(templateDetails), templateDetails)
    towStartSection := V1_GetBetween(mainText, "Action_DoTow" . "Start() {", "Action_DoTowEnd() {")
    formationFinishOk := InStr(mainText, "Время на сбор — окончено") > 0
    towStartTextOk := InStr(mainText, "начал эвакуировать ТС на штрафстоянку.") > 0
    towEnsureOk := InStr(mainText, "TowStart_EnsureTowLast") > 0
    towLastOk := InStr(mainText, "Крюк эвакуатора закреплен на автомобиле.``n/tow") > 0
    towTimerOk := InStr(towStartSection, "ActionTimer_StartEvacuation()") > 0
        && InStr(V1_GetBetween(mainText, "DoTow" . "Start:", "DoTowEnd:"), "Action_DoTowStart()")
    removedMdsOk := !InStr(mainText, "Token: ""MDSEvacReminder""")
    towEndTextOk := InStr(mainText, "эвакуировал ТС на штрафстоянку.") > 0
    formationTowOk := formationFinishOk && towStartTextOk && towEnsureOk && towLastOk && towTimerOk && removedMdsOk && towEndTextOk
    formationTowDetails := "formation=" . formationFinishOk . ", start=" . towStartTextOk . ", ensure=" . towEnsureOk
        . ", tow-last=" . towLastOk . ", timer=" . towTimerOk . ", removed-mds=" . removedMdsOk . ", end=" . towEndTextOk
    SelfTest_Add(report, "High", "formation and tow workflow wording"
        , formationTowOk, formationTowDetails)
    SelfTest_Add(report, "Critical", "configurable !апатруль and !апост"
        , InStr(mainText, "Trig_AutoPatrol := ""!апатруль""")
        && InStr(mainText, "Trig_AutoPost := ""!апост""")
        && InStr(mainText, "IniRead, Trig_AutoPatrol")
        && InStr(mainText, "IniRead, Trig_AutoPost")
        && InStr(mainText, "AutoReport_IsValidDuration(minutesText)"))
    patrolHooks := V1_GetBetween(mainText, "DoPatrol" . "Start:", "DoPost" . "Start:")
    postHooks := V1_GetBetween(mainText, "DoPost" . "Start:", "DoConvoy" . "Start:")
    towHooks := towStartSection . V1_GetBetween(mainText, "Action_DoTow" . "End() {", "Action_DoCarSearch() {")
    SelfTest_Add(report, "Critical", "action timers are wired to patrol, post and evacuation"
        , InStr(patrolHooks, "ActionTimer_StartManualService(""Патруль"")")
        && InStr(patrolHooks, "ActionTimer_Stop(""Patrol"")")
        && InStr(postHooks, "ActionTimer_StartManualService(""Пост"")")
        && InStr(postHooks, "ActionTimer_Stop(""Post"")")
        && InStr(towHooks, "ActionTimer_StartEvacuation()")
        && InStr(towHooks, "ActionTimer_Stop(""Evac"")")
        && InStr(V1_GetBetween(mainText, "DoTow" . "End:", "DoCarSearch:"), "Action_DoTowEnd()"))
    SelfTest_Add(report, "High", "action timer lifecycle and position persistence"
        , InStr(mainText, "ActionTimer" . "Tick:")
        && InStr(mainText, "StartActionTimer" . "Drag:")
        && InStr(V1_GetBetween(mainText, "RebuildFloatingGUI()", "GetNotifySoundPath("), "ActionTimer_Rebuild()")
        && InStr(V1_GetBetween(mainText, "CancelAllAutomation(showStatus := 1)", "SendChatKeyboard("), "ActionTimer_Clear()")
        && InStr(V1_GetBetween(mainText, "WM_EXIT" . "SIZEMOVE(", "CloseAll" . "Docs("), "ActionTimerX := x")
        && InStr(V1_GetBetween(mainText, "ExitScript" . "Label:", "StartSettings" . "Drag:"), "SetTimer, ActionTimerTick, Off"))

    pages := GetSettingsPageCatalog()
    pageSeen := {}, pagesOk := pages.Length() = 13
    Loop % pages.Length()
    {
        pageId := pages[A_Index].Id
        if (pageId = "" || pageSeen.HasKey(pageId))
            pagesOk := false
        pageSeen[pageId] := 1
    }
    SelfTest_Add(report, "Critical", "13 unique settings pages", pagesOk)
    SelfTest_Add(report, "High", "profile UI exposes both role forms"
        , InStr(mainText, "profileItems.Push([""Должность"", ""CFG_IntroRole""")
        && InStr(mainText, "profileItems.Push([""Должность для /d"", ""CFG_ReportRole"""))
    SelfTest_Add(report, "High", "civil reports visible; Hijack rows hidden"
        , InStr(mainText, "reportItems.Push([""Гражданский вызов принят"", ""CFG_T_CivilCallStart""")
        && InStr(mainText, "reportItems.Push([""Гражданский вызов: прибыл"", ""CFG_T_CivilCallArrive""")
        && !InStr(mainText, "reportItems.Push([""Угон выехал"""))

    SelfTest_Add(report, "Critical", "catalog tokens, visibility and handlers"
        , V1_CheckCatalog(catalogDetails), catalogDetails)
    SelfTest_Add(report, "High", "active profile has no bind conflicts"
        , V1_CheckProfileConflicts(profilePath, conflictDetails), conflictDetails)
    textTriggerPredicate := V1_GetBetween(mainText, "GameText" . "TriggerAllowed(hotkeyName := """") {", "RegisterTextTrigger(")
    SelfTest_Add(report, "High", "text hotstrings use a game-scoped hook without memory discovery (static)"
        , InStr(mainText, "Hotkey, If, % GameTextHotkeyContext")
        && InStr(textTriggerPredicate, "WinActive(") && InStr(textTriggerPredicate, "GAME_PROCESS_NAME")
        && !InStr(textTriggerPredicate, "isInChat(") && !InStr(textTriggerPredicate, "IsGameActive("))

    SelfTest_Add(report, "Critical", "default F12/F5/Pause and independent Chase binds"
        , InStr(mainText, "Bind_ToggleHUD := ""F12""")
        && InStr(mainText, "Bind_IDOverlay := ""F5""")
        && InStr(mainText, "Bind_HideLawGui := ""Pause""")
        && InStr(mainText, "Bind_Chase := ""!3""")
        && InStr(mainText, "Bind_ChaseNoID := ""Insert"""))
    chaseNoIdText := V1_GetBetween(mainText, "DoChaseNoID:", "DoDeject:")
    SelfTest_Add(report, "Critical", "Chase ID and no-ID commands"
        , ContextAssistant_BuildCommand("Chase", 4321) = "/chase 4321"
        && InStr(chaseNoIdText, "ChatQueue_Enqueue(""/chase""")
        && !InStr(mainText, "ChatQueue_Enqueue(""/chaseid"))

    captureText := V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand(")
    SelfTest_Add(report, "Critical", "law query is captured locally and cancelled with Escape"
        , InStr(captureText, "{Esc}") && InStr(captureText, "^a^c")
        && !InStr(captureText, "{Enter}") && !InStr(captureText, "{F6}")
        && !InStr(captureText, "SendChat(") && !InStr(captureText, "ChatQueue"))
    SelfTest_Add(report, "High", "law-search submit key is configurable Ctrl+Shift+F"
        , InStr(mainText, "Bind_LawSearchSubmit := ""^+f""")
        && InStr(mainText, "Token: ""LawSearchSubmit""")
        && !RegExMatch(mainText, "m)^\^!f::"))

    evidence := Evidence_RunRecognitionMatrix()
    SelfTest_Add(report, "Critical", "evidence recognition matrix", evidence.Ok
        , evidence.Passed . "/" . evidence.Total)
    SelfTest_Add(report, "High", "evidence retains report identity, pending, focus-retry and cooldown guards"
        , InStr(mainText, "Evidence_IsOwnReportLine(line)")
        && InStr(mainText, "Evidence_IsPending(reportEvent)")
        && InStr(mainText, "Снимок ожидает возврата фокуса в игру")
        && InStr(mainText, "ChatLogReader_CanTrigger(""Evidence:"" . evidenceEvent, 3000)"))

    lawAudit := LawSearch_AuditIndex()
    SelfTest_Add(report, "Critical", "law index covers 20 documents and every article heading"
        , lawAudit.Ok && lawAudit.Documents = 20
        , "docs=" . lawAudit.Documents . ", pages=" . lawAudit.Pages
            . ", headings=" . lawAudit.Headings . ", failures=" . lawAudit.Failures.Length())
    corpusAudit := LawCorpus_Audit()
    SelfTest_Add(report, "Critical", "official offline corpus: 20 readable documents"
        , corpusAudit.Ok && corpusAudit.Documents = 20
        , "docs=" . corpusAudit.Documents . ", chars=" . corpusAudit.Characters
            . ", failures=" . corpusAudit.Issues.Length())
    mapAudit := TerritoryMap_AuditCatalog()
    SelfTest_Add(report, "Critical", "territory map groups and official URLs are valid", SelfTest_MapCatalogValid())
    SelfTest_Add(report, "Medium", "optional local map images for 11 groups"
        , mapAudit.Ok && mapAudit.Groups = 11
        , "groups=" . mapAudit.Groups . ", failures=" . mapAudit.Issues.Length())
    SelfTest_Add(report, "High", "territory map profile mode and two UI choices"
        , (TerritoryMapMode_ToUiLabel("Local") = "Локальные копии")
        && (TerritoryMapMode_ToUiLabel("Forum") = "Официальные ссылки")
        && (TerritoryMapMode_FromUiLabel("Официальные ссылки") = "Forum")
        && InStr(mainText, "CFG_TerritoryMapMode")
        && InStr(mainText, "MigrateV12Configuration("))
    SelfTest_Add(report, "Critical", "current KOAP article 17.4 is present"
        , InStr(LawCorpus_GetText("koap"), "Статья 17.4. Распитие спиртных напитков в общественных местах"))
    SelfTest_Add(report, "Critical", "current VU point 3.20 is present"
        , InStr(LawCorpus_GetText("vu"), "3.20 Сотрудники специализированных подразделений"))
    SelfTest_Add(report, "Critical", "current TER service-territory definitions are present"
        , InStr(LawCorpus_GetText("ter"), "Статья 15. Понятие служебной территории")
        && InStr(LawCorpus_GetText("ter"), "Статья 18. Перечень служебных территорий"))
    SelfTest_Add(report, "Critical", "current TER colony access rule is present"
        , InStr(LawCorpus_GetText("ter"), "На территории желтой зоны вправе находиться лица, недавно освободившиеся")
        && InStr(LawCorpus_GetText("ter"), "Статья 13. Права сотрудников органов внутренних дел"))
    SelfTest_Add(report, "Critical", "deleted FZOP article 8 point 10 is absent"
        , LawSearch_CheckNoResults("ФЗОП статья 8 пункт 10", "ALL"))
    SelfTest_Add(report, "High", "dynamic corpus pagination replaces fixed summaries"
        , SelfTest_CorpusPagesComplete() && IsFunc("LawDoc_ShowPage") && IsFunc("LawDoc_GetCurrentPage"))
    SelfTest_Add(report, "High", "law exact and compact references"
        , LawSearch_CheckExpected("ФЗОТОД гл. 3 ст. 12 ч. 2", "ALL", "TER", "12", "2", 3)
        && LawSearch_CheckExpected("ФЗОТОД гл3 ст12 ч2", "ALL", "TER", "12", "2", 3))
    SelfTest_Add(report, "High", "law natural query, word forms and permutation"
        , LawSearch_CheckExpected("кто считается сотрудником полиции", "ALL", "FZOP", "22", "1", 5)
        && LawSearch_CheckExpected("сотрудника полиции", "ALL", "FZOP", "22", "1", 5)
        && LawSearch_CheckExpected("полиции сотрудник", "ALL", "FZOP", "22", "1", 5))
    SelfTest_Add(report, "High", "law bounded typo and negative example"
        , LawSearch_CheckExpected("сотрудник полицеи", "ALL", "FZOP", "22", "1", 5)
        && LawSearch_CheckNoResults("квазиплазменный телепортатор", "ALL"))
    searchPackage := LawSearch_Find("ALL", "сотрудник", 99)
    SelfTest_Add(report, "High", "law results cap at 30 and retain total count"
        , searchPackage.Results.Length() <= 30 && searchPackage.Passed >= searchPackage.Results.Length())
    SelfTest_Add(report, "High", "no article-specific search bonuses"
        , !InStr(helperText, "terZoneIntent") && !InStr(helperText, "repeatIntent"))

    SelfTest_Add(report, "Critical", "AutoReport scheduler mock", RunAutoReportMockTest())
    SelfTest_Add(report, "High", "AutoReport UI and cancellation hooks"
        , InStr(mainText, "vCFG_AutoReportMode") && InStr(mainText, "gAutoReportStartLabel")
        && InStr(V1_GetBetween(mainText, "LoadProfile(profileName)", "FinalizeLoadedProfileState("), "AutoReport_Stop")
        && InStr(V1_GetBetween(mainText, "CancelAllAutomation(showStatus := 1)", "SendChatKeyboard("), "AutoReport_Stop")
        && InStr(V1_GetBetween(mainText, "ExitScriptLabel:", "HandleAppExit:"), "AutoReport_Stop"))

    status := (SelfTestCriticalFailed || SelfTestHighFailed) ? "FAIL"
        : ((SelfTestMediumWarnings || SelfTestLowNotes) ? "WARN" : "PASS")
    report .= "`r`nSummary: " . status . "`r`n"
    report .= "Total checks: " . SelfTestTotal . "`r`n"
    report .= "Critical failed: " . SelfTestCriticalFailed . "`r`n"
    report .= "High failed: " . SelfTestHighFailed . "`r`n"
    report .= "Medium warnings: " . SelfTestMediumWarnings . "`r`n"
    report .= "Low notes: " . SelfTestLowNotes . "`r`nLIVE GAME: NOT RUN`r`n"
    SelfTest_WriteReport(report)
    return status != "FAIL"
}

RunSelfTest() {
    ; Compatibility entry point for the shared regression self-test.
    return RunSelfTestV1()
}

SelfTest_Add(ByRef report, severity, name, ok, details := "") {
    global SelfTestCriticalFailed, SelfTestHighFailed, SelfTestMediumWarnings, SelfTestLowNotes, SelfTestTotal

    SelfTestTotal += 1
    if (ok)
        status := "PASS"
    else if (severity = "Medium")
        status := "WARN"
    else if (severity = "Low")
        status := "NOTE"
    else
        status := "FAIL"

    if (!ok)
    {
        if (severity = "Critical")
            SelfTestCriticalFailed += 1
        else if (severity = "High")
            SelfTestHighFailed += 1
        else if (severity = "Medium")
            SelfTestMediumWarnings += 1
        else
            SelfTestLowNotes += 1
    }

    report .= "[" . status . "] " . severity . " | " . name
    if (details != "")
        report .= " | " . details
    report .= "`r`n"
}

SelfTest_ReadFile(path) {
    return AppHost_SourceFile(path)
}

SelfTest_FileExistsNonEmpty(path) {
    if (A_IsCompiled && (path = A_ScriptFullPath || RegExMatch(path, "i)\.ahk$|[\\/]laws[\\/]")))
        return StrLen(AppHost_SourceFile(path)) > 0
    if (!FileExist(path))
        return false
    FileGetSize, fileSize, %path%
    return (fileSize > 0)
}

SelfTest_HasNoBom(path) {
    if (A_IsCompiled && (path = A_ScriptFullPath || RegExMatch(path, "i)\.ahk$|[\\/]laws[\\/]"))) {
        text := AppHost_SourceFile(path)
        return StrLen(text) > 0 && SubStr(text, 1, 1) != Chr(0xFEFF)
    }
    if (!FileExist(path))
        return false
    file := FileOpen(path, "r")
    if !IsObject(file)
        return false
    VarSetCapacity(buf, 3, 0)
    bytesRead := file.RawRead(buf, 3)
    file.Close()
    if (bytesRead >= 3)
    {
        b1 := NumGet(buf, 0, "UChar")
        b2 := NumGet(buf, 1, "UChar")
        b3 := NumGet(buf, 2, "UChar")
        if (b1 = 0xEF && b2 = 0xBB && b3 = 0xBF)
            return false
    }
    if (bytesRead >= 2)
    {
        b1 := NumGet(buf, 0, "UChar")
        b2 := NumGet(buf, 1, "UChar")
        if ((b1 = 0xFF && b2 = 0xFE) || (b1 = 0xFE && b2 = 0xFF))
            return false
    }
    return true
}

SelfTest_TextContains(text, needle) {
    return (InStr(text, needle) > 0)
}

SelfTest_SectionContains(text, marker, needle, limit := 1200) {
    pos := InStr(text, "`n" . marker)
    if (pos)
        pos += 1
    else if (SubStr(text, 1, StrLen(marker)) = marker)
        pos := 1
    if (!pos)
        return false
    section := SubStr(text, pos, limit)
    return (InStr(section, needle) > 0)
}

SelfTest_BraceBalance(text) {
    balance := 0
    Loop, Parse, text
    {
        if (A_LoopField = "{")
            balance += 1
        else if (A_LoopField = "}")
            balance -= 1
    }
    return balance
}

SelfTest_ContinuationBalance(text) {
    openCount := 0
    closeCount := 0
    Loop, Parse, text, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "(")
            openCount += 1
        else if (line = ")")
            closeCount += 1
    }
    return openCount - closeCount
}

SelfTest_CheckSyntaxText(ByRef report, name, text) {
    braceDelta := SelfTest_BraceBalance(text)
    contDelta := SelfTest_ContinuationBalance(text)
    SelfTest_Add(report, "High", name . " has no AHK v2 arrow syntax", !SelfTest_TextContains(text, "=" . ">"))
    SelfTest_Add(report, "High", name . " static brace heuristic (not interpreter validation)", (braceDelta = 0), "delta=" . braceDelta)
    SelfTest_Add(report, "Medium", name . " static continuation heuristic", (contDelta = 0), "delta=" . contDelta)
}

SelfTest_WriteReport(report) {
    reportPath := AppHost_DataDir() . "\selftest_report.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    return !ErrorLevel
}

RunDiagnosticsExport() {
    global DiagnosticsFailCount, DiagnosticsWarnCount, DiagnosticsNoteCount, DiagnosticsTotal

    DiagnosticsFailCount := 0
    DiagnosticsWarnCount := 0
    DiagnosticsNoteCount := 0
    DiagnosticsTotal := 0

    projectDir := AppHost_DataDir()
    mainPath := A_ScriptFullPath
    helperPath := projectDir . "\helper.ahk"
    commonPath := projectDir . "\common.ahk"
    udfPath := projectDir . "\UDF.ahk"
    profilesPath := Diagnostics_GetActiveConfigPath(projectDir)
    themesPath := projectDir . "\themes.ini"
    selftestPath := projectDir . "\selftest_report.txt"
    errorLogPath := projectDir . "\error_log.txt"
    modernLogPath := projectDir . "\logs\amz_gos.log"
    activeLogPath := FileExist(modernLogPath) ? modernLogPath : errorLogPath

    mainText := SelfTest_ReadFile(mainPath)
    commonText := SelfTest_ReadFile(commonPath)
    udfText := SelfTest_ReadFile(udfPath)

    report := "AHK FOR GOS BY SBEZRUK diagnostics report`r`n"
    report .= "Time: " . A_YYYY . "-" . A_MM . "-" . A_DD . " " . A_Hour . ":" . A_Min . ":" . A_Sec . "`r`n"
    report .= "Project: " . projectDir . "`r`n"
    report .= "Script: " . mainPath . "`r`n"
    report .= "Mode: CLI read-only diagnostics`r`n`r`n"

    Diagnostics_AddSection(report, "Runtime safety")
    Diagnostics_AddLine(report, "No GUI, hotkeys, timers, clipboard, GTA memory, profiles/themes writes, or game actions are intentionally used in this mode.")
    Diagnostics_AddCheck(report, "High", "diagnostics guard before normal startup (static)", SelfTest_TextContains(mainText, "if HasCommandLineArg(" . Chr(34) . "--diagnostics" . Chr(34) . ")"), "guard is in auto-execute before InitProfiles/ApplyAllBinds/CreateHUD")

    Diagnostics_AddSection(report, "Capture")
    Diagnostics_AddLine(report, Capture_GetDiagnosticsText())

    Diagnostics_AddSection(report, "Files")
    Diagnostics_CollectFileInfo(report, mainPath, "main")
    Diagnostics_CollectFileInfo(report, helperPath, "helper")
    Diagnostics_CollectFileInfo(report, commonPath, "common")
    Diagnostics_CollectFileInfo(report, udfPath, "UDF")
    Diagnostics_CollectFileInfo(report, profilesPath, "active profiles config")
    if FileExist(themesPath)
        Diagnostics_CollectFileInfo(report, themesPath, "themes")
    else
        Diagnostics_AddLine(report, "themes.ini: optional file is not present; built-in themes remain available")

    Diagnostics_AddSection(report, "Self-test summary")
    Diagnostics_ReadSelfTestSummary(report, selftestPath)

    Diagnostics_AddSection(report, "Error log tail")
    if FileExist(activeLogPath)
    {
        Diagnostics_AddLine(report, "Source: " . activeLogPath)
        Diagnostics_AddLine(report, Diagnostics_ReadTail(activeLogPath, 40))
    }
    else
        Diagnostics_AddLine(report, "No log file found")

    Diagnostics_AddSection(report, "Profile and theme summary")
    currentProfile := Diagnostics_ReadIniValue(profilesPath, "Profiles", "Last", "")
    if (currentProfile = "" || currentProfile = "ERROR")
        currentProfile := "Основной"
    profileSection := "Profile_" . currentProfile
    Diagnostics_AddLine(report, "Active config: " . profilesPath)
    Diagnostics_AddLine(report, "Active profile: " . currentProfile)
    themeMode := Diagnostics_ReadIniValue(profilesPath, "UI", "ThemeMode", "")
    if (themeMode = "" || themeMode = "ERROR")
        themeMode := "<missing>"
    Diagnostics_AddLine(report, "ThemeMode: " . themeMode)
    Diagnostics_AddLine(report, "themes.ini: " . (FileExist(themesPath) ? "present" : "missing"))

    Diagnostics_AddSection(report, "Safe settings")
    Diagnostics_AddLine(report, "SafeModeEnabled=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeModeEnabled", "<missing>"))
    Diagnostics_AddLine(report, "SafeBlockWhenChat=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeBlockWhenChat", "<missing>"))
    Diagnostics_AddLine(report, "SafeVehicleChecks=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeVehicleChecks", "<missing>"))
    Diagnostics_AddLine(report, "SafeRequireChatForEditable=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeRequireChatForEditable", "<missing>"))
    Diagnostics_AddLine(report, "SafeTooltipWarnings=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeTooltipWarnings", "<missing>"))
    Diagnostics_AddLine(report, "SafeDistanceChecks=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeDistanceChecks", "<missing>"))
    Diagnostics_AddLine(report, "SafeDistanceLimit=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeDistanceLimit", "<missing>"))

    Diagnostics_AddSection(report, "Chat transport")
    Diagnostics_AddLine(report, "TextSendMode=" . Diagnostics_ReadIniValue(profilesPath, "UI", "TextSendMode", "Auto"))
    Diagnostics_AddLine(report, "GameWindowTitle=" . Diagnostics_ReadIniValue(profilesPath, "UI", "GameWindowTitle", "AMAZING ONLINE"))
    Diagnostics_AddLine(report, "GameProcessName=" . Diagnostics_ReadIniValue(profilesPath, "UI", "GameProcessName", "gta_sa.exe"))
    Diagnostics_AddLine(report, "AzmpExpectedSHA256=" . Diagnostics_ReadIniValue(profilesPath, "UI", "AzmpExpectedSHA256", "<not set>"))
    Diagnostics_AddLine(report, "MockMode=" . Diagnostics_ReadIniValue(profilesPath, "UI", "MockMode", "Off"))
    Diagnostics_AddCheck(report, "Critical", "unified chat transport wrapper", SelfTest_TextContains(mainText, "ChatTransport_Send(text") && SelfTest_TextContains(mainText, "SendChatMemory(text)"))
    Diagnostics_AddCheck(report, "High", "Auto send mode is available", SelfTest_TextContains(mainText, "Auto|Memory|Keyboard"))
    Diagnostics_AddCheck(report, "High", "window-title locator and EXE fallback are present", SelfTest_TextContains(commonText, "GameLocator_Find(ByRef pid") && SelfTest_TextContains(commonText, "source := ""title""") && SelfTest_TextContains(commonText, "source := ""exe"""))

    Diagnostics_AddSection(report, "ChatLog and target ID")
    Diagnostics_AddLine(report, "ChatLog.Enabled=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "Enabled", "On"))
    Diagnostics_AddLine(report, "ChatLog.Path=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "Path", "<missing>"))
    Diagnostics_AddLine(report, "ChatLog.PlayerNickname=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "PlayerNickname", "<not set>"))
    Diagnostics_AddLine(report, "ChatLog.AutoCleanup=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "AutoCleanup", "On"))
    Diagnostics_AddLine(report, "ChatLog.MaxSizeKB=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "MaxSizeKB", "512"))
    Diagnostics_AddLine(report, "ChatLog.KeepTailKB=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "KeepTailKB", "32"))
    Diagnostics_AddLine(report, "AutoTargetIDEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AutoTargetIDEnabled", "On"))
    Diagnostics_AddCheck(report, "High", "ChatLogReader routes lookups through queue", SelfTest_SectionContains(mainText, "ChatLogReader_BeginLookup(actionName", "ChatQueue_Enqueue(""/id ", 2600))
    Diagnostics_AddCheck(report, "High", "RMB target resolver is present", SelfTest_TextContains(mainText, "AutoTargetID_Poll()") && SelfTest_TextContains(udfText, "getPlayerIdByPed(targetPed)"))

    Diagnostics_AddSection(report, "Context assistant (legacy/internal)")
    Diagnostics_AddLine(report, "AssistOOPEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistOOPEnabled", "On"))
    Diagnostics_AddLine(report, "AssistStunEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistStunEnabled", "On"))
    Diagnostics_AddLine(report, "AssistChaseEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistChaseEnabled", "On"))
    Diagnostics_AddLine(report, "AssistHouseEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistHouseEnabled", "On"))
    Diagnostics_AddLine(report, "AssistDrugsEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistDrugsEnabled", "On"))
    Diagnostics_AddLine(report, "AssistPDPCuffEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistPDPCuffEnabled", "On"))
    Diagnostics_AddLine(report, "Registration: disabled; profile values are retained only for backward compatibility")
    Diagnostics_AddCheck(report, "High", "six context actions remain internal and unregistered"
        , V1_CheckCatalog(contextCatalogDetails), contextCatalogDetails)
    Diagnostics_AddCheck(report, "Critical", "context actions use queue", SelfTest_SectionContains(mainText, "ContextAssistant_Execute(actionName", "ChatQueue_Enqueue(commandText", 7000))

    Diagnostics_AddSection(report, "Official legislation corpus")
    corpusAudit := LawCorpus_Audit()
    lawAudit := LawSearch_AuditIndex()
    mapAudit := TerritoryMap_AuditCatalog()
    Diagnostics_AddLine(report, "Source: https://forum.amazing-online.com/forums/zakonodatelstvo.732/")
    Diagnostics_AddLine(report, "TerritoryMapMode=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "TerritoryMapMode", "Local"))
    Diagnostics_AddCheck(report, "Critical", "20 official documents are readable"
        , corpusAudit.Ok && corpusAudit.Documents = 20
        , "docs=" . corpusAudit.Documents . ", chars=" . corpusAudit.Characters)
    Diagnostics_AddCheck(report, "Critical", "every detected article heading is indexed"
        , lawAudit.Ok && lawAudit.Documents = 20
        , "pages=" . lawAudit.Pages . ", headings=" . lawAudit.Headings . ", failures=" . lawAudit.Failures.Length())
    Diagnostics_AddCheck(report, "Medium", "optional local assets for 11 territory map groups"
        , mapAudit.Ok && mapAudit.Groups = 11
        , "groups=" . mapAudit.Groups . ", failures=" . mapAudit.Issues.Length())
    Diagnostics_AddCheck(report, "Critical", "law-query capture never submits chat"
        , InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "{Esc}")
        && !InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "{Enter}")
        && !InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "SendChat("))

    Diagnostics_AddSection(report, "Bind-list summary")
    catalog := GetBindCatalog()
    hotkeyVarCount := 0
    triggerVarCount := 0
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            hotkeyVarCount += 1
        if (meta.TriggerVar != "")
            triggerVarCount += 1
    }
    Diagnostics_AddLine(report, "Catalog items: " . catalog.Length())
    Diagnostics_AddLine(report, "Hotkey fields: " . hotkeyVarCount)
    Diagnostics_AddLine(report, "Trigger fields: " . triggerVarCount)

    Diagnostics_AddSection(report, "Bind conflict scan")
    Diagnostics_CheckBindConflicts(report, mainText, profilesPath, profileSection)

    status := "PASS"
    if (DiagnosticsFailCount > 0)
        status := "FAIL"
    else if (DiagnosticsWarnCount > 0 || DiagnosticsNoteCount > 0)
        status := "WARN"

    Diagnostics_AddSection(report, "Summary")
    Diagnostics_AddLine(report, "Status: " . status)
    Diagnostics_AddLine(report, "Total checks: " . DiagnosticsTotal)
    Diagnostics_AddLine(report, "Failures: " . DiagnosticsFailCount)
    Diagnostics_AddLine(report, "Warnings: " . DiagnosticsWarnCount)
    Diagnostics_AddLine(report, "Notes: " . DiagnosticsNoteCount)

    wroteReport := Diagnostics_WriteReport(report)
    return wroteReport && DiagnosticsFailCount = 0
}

Diagnostics_AddSection(ByRef report, title) {
    report .= "`r`n== " . title . " ==`r`n"
}

Diagnostics_AddLine(ByRef report, line) {
    report .= line . "`r`n"
}

Diagnostics_AddCheck(ByRef report, severity, name, ok, details := "") {
    global DiagnosticsFailCount, DiagnosticsWarnCount, DiagnosticsNoteCount, DiagnosticsTotal

    DiagnosticsTotal += 1
    if (ok)
        status := "PASS"
    else if (severity = "Low")
        status := "NOTE"
    else if (severity = "Medium")
        status := "WARN"
    else
        status := "FAIL"

    if (!ok)
    {
        if (severity = "Critical" || severity = "High")
            DiagnosticsFailCount += 1
        else if (severity = "Medium")
            DiagnosticsWarnCount += 1
        else
            DiagnosticsNoteCount += 1
    }

    report .= "[" . status . "] " . severity . " | " . name
    if (details != "")
        report .= " | " . details
    report .= "`r`n"
}

Diagnostics_WriteReport(report) {
    reportPath := AppHost_DataDir() . "\diagnostics_report.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    return !ErrorLevel
}

Diagnostics_CollectFileInfo(ByRef report, path, label) {
    exists := FileExist(path)
    if (!exists && A_IsCompiled && RegExMatch(path, "i)\.ahk$")) {
        text := AppHost_SourceFile(path)
        Diagnostics_AddCheck(report, "High", label . " embedded source present", StrLen(text) > 0, path)
        return
    }
    Diagnostics_AddCheck(report, "High", label . " exists", exists, path)
    if (!exists)
        return

    FileGetSize, fileSize, %path%
    Diagnostics_AddCheck(report, "High", label . " non-empty", (fileSize > 0), "size=" . fileSize)
    Diagnostics_AddCheck(report, "High", label . " has no BOM", SelfTest_HasNoBom(path), path)
}

Diagnostics_ReadSelfTestSummary(ByRef report, selftestPath) {
    if (!FileExist(selftestPath))
    {
        Diagnostics_AddCheck(report, "Medium", "selftest_report.txt exists", false, selftestPath)
        return
    }

    tail := Diagnostics_ReadTail(selftestPath, 8)
    Diagnostics_AddLine(report, tail)
}

Diagnostics_ReadTail(path, maxLines := 40) {
    if (!FileExist(path))
        return "not found: " . path

    FileRead, content, %path%
    if (ErrorLevel)
        return "read failed: " . path

    lines := []
    Loop, Parse, content, `n, `r
        lines.Push(A_LoopField)

    total := lines.Length()
    if (total <= 0)
        return "<empty>"

    startIndex := total - maxLines + 1
    if (startIndex < 1)
        startIndex := 1

    out := ""
    Loop % total - startIndex + 1
    {
        idx := startIndex + A_Index - 1
        if (out != "")
            out .= "`r`n"
        out .= lines[idx]
    }
    return out
}

Diagnostics_GetActiveConfigPath(projectDir) {
    updatedPath := projectDir . "\profiles_updated.ini"
    if FileExist(updatedPath)
        return updatedPath
    return projectDir . "\profiles.ini"
}

Diagnostics_ReadIniValue(filePath, sectionName, keyName, defaultValue := "") {
    if (!FileExist(filePath) || sectionName = "" || keyName = "")
        return defaultValue
    IniRead, value, %filePath%, %sectionName%, %keyName%, %defaultValue%
    return value
}

Diagnostics_GetGlobalDefault(text, varName) {
    marker := "global " . varName . " :="
    pos := InStr(text, marker)
    if (!pos)
        return ""

    lineEnd := InStr(text, "`n", false, pos)
    if (!lineEnd)
        lineEnd := StrLen(text) + 1
    line := SubStr(text, pos, lineEnd - pos)
    assignPos := InStr(line, ":=")
    if (!assignPos)
        return ""

    value := Trim(SubStr(line, assignPos + 2))
    if (SubStr(value, 1, 1) = """")
    {
        value := SubStr(value, 2)
        quotePos := InStr(value, """")
        if (quotePos)
            value := SubStr(value, 1, quotePos - 1)
    }
    return value
}

Diagnostics_NormalizeHotkeyForCompare(value) {
    value := Trim(value)
    if (value = "ERROR")
        return ""
    StringLower, value, value
    return value
}

Diagnostics_NormalizeTriggerForCompare(value) {
    value := Trim(value)
    if (value = "ERROR")
        return ""
    if (value != "" && SubStr(value, 1, 1) != "!")
        value := "!" . value
    StringLower, value, value
    return value
}

Diagnostics_AppendList(ByRef text, item) {
    if (text != "")
        text .= "; "
    text .= item
}

Diagnostics_TextHasLabel(text, labelName) {
    if (labelName = "")
        return false
    return (InStr(text, labelName . ":") > 0)
}

Diagnostics_CheckBindConflicts(ByRef report, mainText, profilesPath, profileSection) {
    catalog := GetBindCatalog()
    tokens := {}
    hotkeys := {}
    triggers := {}
    duplicateTokens := ""
    duplicateHotkeys := ""
    duplicateTriggers := ""
    missingLabels := ""
    wantedTrigger := ""
    searchTriggerConflict := false

    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        token := meta.Token
        if (tokens.HasKey(token))
            Diagnostics_AppendList(duplicateTokens, token)
        else
            tokens[token] := 1

        if (meta.HotkeyVar != "")
        {
            defaultHotkey := Diagnostics_GetGlobalDefault(mainText, meta.HotkeyVar)
            hotkeyValue := Diagnostics_ReadIniValue(profilesPath, profileSection, meta.HotkeyVar, defaultHotkey)
            hotkeyKey := Diagnostics_NormalizeHotkeyForCompare(hotkeyValue)
            if (hotkeyKey != "")
            {
                if (hotkeys.HasKey(hotkeyKey))
                    Diagnostics_AppendList(duplicateHotkeys, hotkeyValue . " -> " . hotkeys[hotkeyKey] . " / " . meta.HotkeyVar)
                else
                    hotkeys[hotkeyKey] := meta.HotkeyVar
            }

            if (token != "OpenSettings" && token != "ToggleBindList" && token != "ToggleHUD")
            {
                labelName := GetBoundLabelByToken(token)
                if (labelName = "" || !Diagnostics_TextHasLabel(mainText, labelName))
                    Diagnostics_AppendList(missingLabels, token . " -> " . labelName)
            }
        }

        if (meta.TriggerVar != "")
        {
            defaultTrigger := Diagnostics_GetGlobalDefault(mainText, meta.TriggerVar)
            triggerValue := Diagnostics_ReadIniValue(profilesPath, profileSection, meta.TriggerVar, defaultTrigger)
            triggerKey := Diagnostics_NormalizeTriggerForCompare(triggerValue)
            if (meta.TriggerVar = "Trig_WantedList")
                wantedTrigger := triggerValue
            if (triggerKey != "")
            {
                if (triggers.HasKey(triggerKey))
                    Diagnostics_AppendList(duplicateTriggers, triggerValue . " -> " . triggers[triggerKey] . " / " . meta.TriggerVar)
                else
                    triggers[triggerKey] := meta.TriggerVar
            }
        }
    }

    searchKey := "!пнайти"
    StringLower, searchKey, searchKey
    if (triggers.HasKey(searchKey))
        searchTriggerConflict := true

    Diagnostics_AddCheck(report, "High", "duplicate catalog tokens", (duplicateTokens = ""), duplicateTokens)
    Diagnostics_AddCheck(report, "Medium", "duplicate non-empty hotkeys", (duplicateHotkeys = ""), duplicateHotkeys)
    Diagnostics_AddCheck(report, "Medium", "duplicate non-empty triggers", (duplicateTriggers = ""), duplicateTriggers)
    Diagnostics_AddCheck(report, "High", "missing labels for hotkey catalog actions", (missingLabels = ""), missingLabels)
    Diagnostics_AddCheck(report, "Medium", "WantedList trigger is present", (Trim(wantedTrigger) != ""), "Trig_WantedList=" . wantedTrigger)
    Diagnostics_AddCheck(report, "Medium", "fixed search trigger conflict", !searchTriggerConflict, "!пнайти")
}

MemoryLiveTest_WriteReport(state, finalStatus := "") {
    global MemoryLiveTestResult, GameWindowTitle, GameProcessName
    reportPath := AppHost_DataDir() . "\memory_live_test_report.txt"
    if !IsObject(MemoryLiveTestResult)
        MemoryLiveTestResult := {}
    FormatTime, completedAt,, yyyy-MM-dd HH:mm:ss
    report := "AHK FOR GOS BY SBEZRUK Memory live-test`r`n"
    report .= "Completed: " . completedAt . "`r`n"
    report .= "WindowTitle: " . GameWindowTitle . "`r`n"
    report .= "FallbackEXE: " . GameProcessName . "`r`n"
    report .= "azmp.dll: " . (MemoryLiveTestResult.HasKey("Azmp") ? MemoryLiveTestResult.Azmp : GetAzmpCompatibilitySummary(1)) . "`r`n"
    report .= "/time: " . (MemoryLiveTestResult.HasKey("Time") ? MemoryLiveTestResult.Time : "не выполнялся") . "`r`n"
    report .= "Russian message: " . (MemoryLiveTestResult.HasKey("Russian") ? MemoryLiveTestResult.Russian : "не выполнялось") . "`r`n"
    report .= "Result: " . finalStatus . "`r`n"
    report .= "Last memory state: " . MemoryGetStatusText() . "`r`n"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    MemoryLiveTestResult.ReportPath := reportPath
    MemoryLiveTestResult.State := state
    return reportPath
}

MemoryLiveTest_Finish(success, statusText) {
    global MemoryLiveTestMode, MemoryLiveTestResult
    reportPath := MemoryLiveTest_WriteReport(success ? "PASS" : "FAIL", statusText)
    LogError("MemoryLiveTest", statusText . " | report=" . reportPath, success ? "INFO" : "ERROR")
    GameNotify(statusText, success ? "INFO" : "ERROR")
    if (MemoryLiveTestMode)
        SetTimer, MemoryLiveTestExitLabel, -350
    return success
}

MemoryLiveTest_SendRussian(payload := "") {
    global MemoryLiveTestResult
    testMessage := (payload != "") ? payload : "Проверка Memory AHK FOR GOS BY SBEZRUK: русское сообщение."
    result := SendChatMemory(testMessage)
    memoryStatus := MemoryGetStatusText()
    if !IsObject(MemoryLiveTestResult)
        MemoryLiveTestResult := {}
    MemoryLiveTestResult.Russian := (result = 1) ? "PASS | " . memoryStatus : "FAIL | " . memoryStatus
    if (result != 1)
        return MemoryLiveTest_Finish(false, "Русское сообщение не отправлено: " . MemoryGetShortError())
    return MemoryLiveTest_Finish(true, "Memory live-тест пройден: /time и русское сообщение отправлены.")
}

RunMemoryLiveTest(showPrompt := 1) {
    global MockMode, MemoryLiveTestMode, MemoryLiveTestResult
    MemoryLiveTestResult := {}
    if (MemoryLiveTestMode)
        MockMode := "Off"
    if (MockMode = "On") {
        MemoryLiveTestResult.Time := "FAIL | MockMode включён"
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "Отключи MockMode для live-теста Memory.")
    }

    ApplyGameProcessSelector()
    if !checkHandles() {
        MemoryLiveTestResult.Time := "FAIL | " . MemoryGetStatusText()
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "Memory не подключён: " . MemoryGetShortError())
    }

    MemoryLiveTestResult.Azmp := GetAzmpCompatibilitySummary(1)
    result := SendChatMemory("/time")
    memoryStatus := MemoryGetStatusText()
    MemoryLiveTestResult.Time := (result = 1) ? "PASS | " . memoryStatus : "FAIL | " . memoryStatus
    if (result != 1) {
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "/time не отправлен: " . MemoryGetShortError())
    }

    TaskScheduler_Set("MemoryLiveTest", 1200, "MemoryLiveTest_SendRussian", "Memory live-test", "Проверка Memory AHK FOR GOS BY SBEZRUK: русское сообщение.")
    if (showPrompt)
        GameNotify("/time отправлен. Через 1.2 сек. будет отправлена русская тестовая строка.", "INFO")
    return true
}

RunV1MockRegression() {
    global MockMode, ChatQueueEnabled, ChatQueueMaxItems, ChatQueueItems, ChatQueueBusy
    global TaskSchedulerItems, SettingsVisible, LogDir, ModernLogFile, MaxLogBytes
    global IntroRole, ReportRole, Rank, ReportRank, Surname
    global PatrolUnit, PatrolRoute, PatrolCrewCount, PostUnit, PostRoute, PostCrewCount, ConvoyRoute
    global AutoReportActive
    MockMode := "On"
    ChatQueueEnabled := "On"
    ChatQueueMaxItems := 200
    ChatQueueItems := []
    ChatQueueBusy := 0
    TaskSchedulerItems := {}
    SettingsVisible := 0
    LogDir := AppHost_DataDir() . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    MaxLogBytes := 262144
    IntroRole := "начальником МДС ГАИ", ReportRole := "Начальник МДС ГАИ"
    Rank := "лейтенант", ReportRank := "лейтенант", Surname := "Лукашенко"
    PatrolUnit := "Р101", PatrolRoute := "А-1", PatrolCrewCount := "2"
    PostUnit := "Р202", PostRoute := "АП ГАИ", PostCrewCount := "3"
    ConvoyRoute := "Арзамас — Батырево"

    cases := []
    cases.Push(["представление", ApplyTemplate("Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}."), "начальником МДС ГАИ"])
    cases.Push(["/d", ApplyTemplate("/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь."), "/d [ГАИ/]"])
    cases.Push(["SOS принят", ApplyTemplate("/r докладывает {SURNAME}: реагирую на вызов срочной помощи."), "срочной помощи"])
    cases.Push(["SOS прибыл", ApplyTemplate("/r докладывает {SURNAME}: прибыл на вызов срочной помощи."), "прибыл"])
    cases.Push(["гражданский принят", ApplyTemplate("/r докладывает {SURNAME}: принял вызов гражданского."), "принял вызов гражданского"])
    cases.Push(["гражданский прибыл", ApplyTemplate("/r докладывает {SURNAME}: прибыл на вызов гражданского."), "прибыл на вызов гражданского"])
    cases.Push(["ДТП принят", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП."), "принял вызов о ДТП"])
    cases.Push(["ДТП прибыл", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП."), "прибыли"])
    cases.Push(["ДТП оформление", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП."), "приступили"])
    cases.Push(["ДТП завершено", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП."), "завершили"])
    cases.Push(["патруль", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."), "Р101"])
    cases.Push(["пост", ApplyTemplate("/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек."), "АП ГАИ"])
    cases.Push(["колонна", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}."), "военной колонны"])
    cases.Push(["эвакуация начало", ApplyTemplate("/r докладывает {SURNAME}: начал эвакуировать ТС на штрафстоянку."), "начал эвакуировать"])
    cases.Push(["эвакуация конец", ApplyTemplate("/r докладывает {SURNAME}: эвакуировал ТС на штрафстоянку."), "эвакуировал ТС"])
    cases.Push(["Chase с ID", ContextAssistant_BuildCommand("Chase", 4321), "/chase 4321"])
    cases.Push(["Chase без ID", "/chase", "/chase"])

    checks := []
    ok := true
    Loop % cases.Length()
    {
        item := cases[A_Index]
        queued := ChatQueue_Enqueue(item[2], "Mock." . item[1], 1)
        passed := queued && InStr(item[2], item[3]) && !RegExMatch(item[2], "\{[A-Z0-9_]+\}")
        checks.Push([item[1], passed])
        ok := passed && ok
    }

    serviceOk := VehicleLookup_ResolveCountry("!Россия", countryIndex, countryName)
        && countryIndex = 1 && VehicleLookup_ResolveRegion("!05", regionIndex, regionCode)
        && regionCode = "05" && VehicleLookup_NormalizePlate("а123аа") = "A123AA"
        && WantedRemoval_GetReason(3, removalReason) && removalReason = "самооборона"
        && Fine_ParseArticle("!20.6", fineArticle, fineChapter, fineItem, fineError)
        && fineArticle = "20.6" && fineChapter = 20 && fineItem = 6
        && GetBoundLabelByToken("VehicleLookup") = "DoVehicleLookup"
        && GetBoundLabelByToken("WantedRemoval") = "DoWantedRemoval"
    checks.Push(["сервисные мастера и штраф", serviceOk])
    ok := serviceOk && ok

    autoOk := RunAutoReportMockTest()
    checks.Push(["автоматический доклад", autoOk])
    ok := autoOk && ok

    ChatQueueItems := []
    TaskSchedulerItems := {}
    AutoReport_Start("Патруль", 20, 0)
    ChatQueue_Enqueue("/r mock pending", "Mock.Cancel", 1)
    CancelAllAutomation(0)
    cancelOk := !AutoReportActive && ChatQueue_Count() = 0 && TaskScheduler_Count() = 0
    checks.Push(["отмена всей автоматизации", cancelOk])
    ok := cancelOk && ok

    report := "AHK FOR GOS BY SBEZRUK v1.1 MockMode regression`r`n"
    Loop % checks.Length()
        report .= (checks[A_Index][2] ? "PASS" : "FAIL") . " | " . checks[A_Index][1] . "`r`n"
    report .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    path := AppHost_DataDir() . "\v1_mocktest_report.txt"
    FileDelete, %path%
    FileAppend, %report%, %path%
    return ok
}

RunLawSearchRegression() {
    audit := LawSearch_AuditIndex()
    corpusAudit := LawCorpus_Audit()
    mapAudit := TerritoryMap_AuditCatalog()
    checks := []
    checks.Push(["all documents/pages/headings indexed", audit.Ok])
    checks.Push(["official corpus 20/20", corpusAudit.Ok && corpusAudit.Documents = 20])
    checks.Push(["territory map catalog and official URLs", SelfTest_MapCatalogValid()])
    checks.Push(["exact reference", LawSearch_CheckExpected("ФЗОТОД гл. 3 ст. 12 ч. 2", "ALL", "TER", "12", "2", 3)])
    checks.Push(["compact reference", LawSearch_CheckExpected("ФЗОТОД гл3 ст12 ч2", "ALL", "TER", "12", "2", 3)])
    checks.Push(["natural query", LawSearch_CheckExpected("кто считается сотрудником полиции", "ALL", "FZOP", "22", "1", 5)])
    checks.Push(["word permutation", LawSearch_CheckExpected("полиции сотрудник", "ALL", "FZOP", "22", "1", 5)])
    checks.Push(["word form", LawSearch_CheckExpected("сотрудника полиции", "ALL", "FZOP", "22", "1", 5)])
    checks.Push(["bounded typo", LawSearch_CheckExpected("сотрудник полицеи", "ALL", "FZOP", "22", "1", 5)])
    checks.Push(["negative query", LawSearch_CheckNoResults("квазиплазменный телепортатор", "ALL")])
    checks.Push(["KAS article reference", LawSearch_CheckExpected("КАС статья 1", "ALL", "KAS", "1", "", 5)])
    checks.Push(["current KOAP 17.4", LawSearch_CheckExpected("КоАП статья 17.4", "ALL", "KOAP", "17.4", "", 3)])
    checks.Push(["current KAS 135", LawSearch_CheckExpected("КАС статья 135", "ALL", "KAS", "135", "", 3)])
    checks.Push(["deleted FZOP 8.10 absent", LawSearch_CheckNoResults("ФЗОП статья 8 пункт 10", "ALL")])
    checks.Push(["dynamic full-document pages preserve every character", SelfTest_CorpusPagesComplete()])
    package := LawSearch_Find("ALL", "сотрудник", 99)
    checks.Push(["30-result cap and total", package.Results.Length() <= 30 && package.Passed >= package.Results.Length()])
    report := "AHK FOR GOS BY SBEZRUK v1.1 law-search regression`r`n"
    report .= "Documents=" . audit.Documents . " Pages=" . audit.Pages
        . " ArticleHeadings=" . audit.Headings . " AuditFailures=" . audit.Failures.Length() . "`r`n"
    report .= "OfficialCorpusDocs=" . corpusAudit.Documents . " CorpusChars=" . corpusAudit.Characters
        . " MapGroups=" . mapAudit.Groups . "`r`n"
    ok := true
    Loop % checks.Length()
    {
        item := checks[A_Index]
        report .= (item[2] ? "PASS" : "FAIL") . " | " . item[1] . "`r`n"
        if !item[2]
            ok := false
    }
    if (audit.Failures.Length() > 0) {
        report .= "`r`nIndex failures (first 30):`r`n"
        Loop % audit.Failures.Length() {
            if (A_Index > 30)
                break
            report .= "- " . audit.Failures[A_Index] . "`r`n"
        }
    }
    if (!mapAudit.Ok)
        report .= "WARN | missing optional local map images: " . mapAudit.Issues.Length() . "`r`n"
    report .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    path := AppHost_DataDir() . "\law_search_test_report.txt"
    FileDelete, %path%
    FileAppend, %report%, %path%
    return ok
}

RunAutoReportMockTest() {
    global
    SettingsVisible := 0
    MockMode := "On"
    ChatQueueEnabled := "On"
    ChatQueueMaxItems := 200
    ChatQueueItems := []
    ChatQueueBusy := 0
    ChatQueueNextSendTick := 0
    ChatQueueLastSendTick := 0
    TaskSchedulerItems := {}
    MDSFormationActive := 0
    ChatWizardMode := ""
    LogDir := AppHost_DataDir() . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    MaxLogBytes := 262144
    T_PatrolContinue := "/r экипаж {PATROL_UNIT}: патрулируем {PATROL_ROUTE}, состав {PATROL_CREW_COUNT}."
    T_PostContinue := "/r экипаж {POST_UNIT}: пост {POST_ROUTE}, состав {POST_CREW_COUNT}."
    PatrolUnit := "Р101"
    PatrolRoute := "А-1"
    PatrolCrewCount := "2"
    PostUnit := "Р202"
    PostRoute := "КПП"
    PostCrewCount := "3"

    checks := []
    ok := true

    durationOk := AutoReport_IsValidDuration("10") && AutoReport_IsValidDuration("600")
        && !AutoReport_IsValidDuration("9") && !AutoReport_IsValidDuration("601")
        && !AutoReport_IsValidDuration("10a") && !AutoReport_IsValidDuration("10.5")
    checks.Push({Name: "strict duration 10-600", Ok: durationOk})
    ok := durationOk && ok

    startOk := AutoReport_Start("Патруль", 20, 0)
        && AutoReportActive
        && TaskSchedulerItems.HasKey("AutoReport")
        && (TaskScheduler_RemainingMs(AutoReportNextTick, AutoReportStartTick) = 600000)
        && AutoReportLastDispatchTick = AutoReportStartTick
        && ChatQueue_Count() = 1
        && AutoReportAcceptedCount = 1
    checks.Push({Name: "start and immediate first report", Ok: startOk})
    ok := startOk && ok

    firstTick := AutoReportNextTick
    AutoReport_HandleTick(firstTick)
    firstOk := (ChatQueue_Count() = 2 && AutoReportAcceptedCount = 2 && TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "ten-minute tick and reschedule", Ok: firstOk})
    ok := firstOk && ok

    AutoReport_HandleTick(firstTick)
    noDoubleOk := (ChatQueue_Count() = 2 && AutoReportAcceptedCount = 2)
    checks.Push({Name: "no double send", Ok: noDoubleOk})
    ok := noDoubleOk && ok

    replaceOk := AutoReport_Start("Пост", 15, 0)
        && AutoReportActive
        && AutoReportMode = "Пост"
        && AutoReportDurationMin = 15
        && ChatQueue_Count() = 1
        && AutoReportAcceptedCount = 1
        && TaskScheduler_Count() = 1
        && TaskSchedulerItems.HasKey("AutoReport")
    checks.Push({Name: "safe replacement", Ok: replaceOk})
    ok := replaceOk && ok

    AutoReport_Stop(0, "mock-stop")
    stopOk := (!AutoReportActive && ChatQueue_Count() = 0 && !TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "manual stop", Ok: stopOk})
    ok := stopOk && ok

    ChatQueueItems := []
    AutoReport_Start("Пост", 10, 0)
    completionTick := AutoReportEndTick
    AutoReport_HandleTick(completionTick)
    completionOk := (!AutoReportActive && ChatQueue_Count() = 2 && !TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "completion at duration", Ok: completionOk})
    ok := completionOk && ok

    ChatQueueItems := []
    AutoReport_Start("Патруль", 20, 0)
    CancelAllAutomation(0)
    cancelAllOk := (!AutoReportActive && ChatQueue_Count() = 0 && TaskScheduler_Count() = 0)
    checks.Push({Name: "CancelAllAutomation", Ok: cancelAllOk})
    ok := cancelAllOk && ok

    sourceText := AppHost_SourceText()
    loadPos := RegExMatch(sourceText, "m)^LoadProfile\(profileName\) \{")
    finalizePos := InStr(sourceText, "FinalizeLoadedProfileState(profileName)", false, loadPos)
    loadSection := (loadPos > 0 && finalizePos > loadPos) ? SubStr(sourceText, loadPos, finalizePos - loadPos) : ""
    profileSwitchOk := InStr(loadSection, "AutoReport_Stop(0, ""profile-switch"")") > 0
    checks.Push({Name: "profile switch cancellation", Ok: profileSwitchOk})
    ok := profileSwitchOk && ok

    reportText := "AHK FOR GOS BY SBEZRUK v1 AutoReport mock test`r`n"
    Loop % checks.Length()
    {
        item := checks[A_Index]
        reportText .= (item.Ok ? "PASS" : "FAIL") . " | " . item.Name . "`r`n"
    }
    reportText .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    reportPath := AppHost_DataDir() . "\autoreport_mocktest_report.txt"
    FileDelete, %reportPath%
    FileAppend, %reportText%, %reportPath%
    return ok
}


SelfTest_CorpusPagesComplete() {
    global LawSearchDocCatalog
    ; Counts depend on DPI/fonts; verify preservation of every non-whitespace character.
    for _, doc in LawSearchDocCatalog {
        pages := LawCorpus_BuildPages(doc.Prefix)
        if (!IsObject(pages) || pages.Length() < 1)
            return false
        combined := ""
        for _, page in pages
            combined .= page
        if (RegExReplace(combined, "\s+") != RegExReplace(LawCorpus_GetText(doc.Prefix), "\s+"))
            return false
    }
    return true
}

SelfTest_MapCatalogValid() {
    seen := {}, catalog := TerritoryMap_GetCatalog()
    if (catalog.Length() != 11)
        return false
    for _, map in catalog {
        if (seen.HasKey(map.Id) || !TerritoryMap_IsOfficialUrl(map.ForumUrl))
            return false
        seen[map.Id] := true
    }
    return true
}
