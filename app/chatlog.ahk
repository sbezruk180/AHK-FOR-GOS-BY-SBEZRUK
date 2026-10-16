; chatlog subsystem. Definitions only; initialization is in bootstrap.

Evidence_IsAllowedEvent(eventCode) {
    static allowed := {"FINE":1, "ARREST":1, "SEARCH_PERSON":1, "SEARCH_TRUNK":1
        , "DOC_LICENSE":1, "DOC_TECHPASSPORT":1, "EVAC_START":1, "EVAC_END":1
        , "REPORT":1
        , "SOS_START":1, "SOS_ARRIVE":1, "CIVIL_START":1, "CIVIL_ARRIVE":1
        , "CALL_START":1, "CALL_ARRIVE":1, "CALL_WORK_START":1, "CALL_WORK_END":1
        , "PATROL_START":1, "PATROL_CONTINUE":1
        , "PATROL_END":1, "POST_START":1, "POST_CONTINUE":1, "POST_END":1}
    return allowed.HasKey(eventCode)
}

Evidence_EventLabel(eventCode) {
    static labels := {"FINE":"Штраф", "ARREST":"Арест", "SEARCH_PERSON":"Личный досмотр"
        , "SEARCH_TRUNK":"Досмотр багажника", "DOC_LICENSE":"Получена лицензия"
        , "DOC_TECHPASSPORT":"Получен техпаспорт", "EVAC_START":"Начало эвакуации"
        , "EVAC_END":"Завершение эвакуации", "REPORT":"Доклад", "SOS_START":"Доклад SOS: выехал"
        , "SOS_ARRIVE":"Доклад SOS: прибыл", "CIVIL_START":"Гражданский вызов: принят"
        , "CIVIL_ARRIVE":"Гражданский вызов: прибыл", "CALL_START":"ДТП: вызов принят"
        , "CALL_ARRIVE":"ДТП: экипаж прибыл", "CALL_WORK_START":"ДТП: оформление начато"
        , "CALL_WORK_END":"ДТП: оформление завершено", "PATROL_START":"Доклад патруля: начало"
        , "PATROL_CONTINUE":"Доклад патруля: продолжение", "PATROL_END":"Доклад патруля: конец"
        , "POST_START":"Доклад поста: начало", "POST_CONTINUE":"Доклад поста: продолжение"
        , "POST_END":"Доклад поста: конец"}
    return labels.HasKey(eventCode) ? labels[eventCode] : eventCode
}

Evidence_Arm(eventCode, timeoutMs := 45000) {
    global EvidenceScreenshotMode, EvidencePendingEvents
    if (EvidenceScreenshotMode != "On" || !Evidence_IsAllowedEvent(eventCode))
        return false
    if !IsObject(EvidencePendingEvents)
        EvidencePendingEvents := {}
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 3000)
        timeoutMs := 3000
    else if (timeoutMs > 180000)
        timeoutMs := 180000
    EvidencePendingEvents[eventCode] := TickNow() + timeoutMs
    LogError("Evidence", "Ожидание подтверждения в чате: " . Evidence_EventLabel(eventCode), "INFO")
    return true
}

Evidence_PurgeExpiredPending() {
    global EvidencePendingEvents
    if !IsObject(EvidencePendingEvents)
        EvidencePendingEvents := {}
    expired := []
    for eventCode, expiresAt in EvidencePendingEvents
        if (expiresAt <= TickNow())
            expired.Push(eventCode)
    Loop % expired.Length()
        EvidencePendingEvents.Delete(expired[A_Index])
}

Evidence_IsPending(eventCode) {
    global EvidencePendingEvents
    Evidence_PurgeExpiredPending()
    return IsObject(EvidencePendingEvents) && EvidencePendingEvents.HasKey(eventCode)
}

Evidence_ConsumePending(eventCode) {
    global EvidencePendingEvents
    Evidence_PurgeExpiredPending()
    if (!IsObject(EvidencePendingEvents) || !EvidencePendingEvents.HasKey(eventCode))
        return false
    EvidencePendingEvents.Delete(eventCode)
    return true
}

Evidence_ClearDocumentContext(clearPending := false) {
    global EvidenceDocumentContext, EvidencePendingEvents
    EvidenceDocumentContext := {}
    if (clearPending && IsObject(EvidencePendingEvents)) {
        EvidencePendingEvents.Delete("DOC_LICENSE")
        EvidencePendingEvents.Delete("DOC_TECHPASSPORT")
    }
}

Evidence_ArmDocumentsForPlayer(playerId, timeoutMs := 90000) {
    global EvidenceScreenshotMode, EvidenceDocumentContext
    if (EvidenceScreenshotMode != "On")
        return false
    if !RegExMatch(playerId . "", "^\d{1,4}$")
        return false

    playerId += 0
    playerName := getPlayerNameById(playerId)
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 3000)
        timeoutMs := 3000
    else if (timeoutMs > 180000)
        timeoutMs := 180000

    Evidence_ClearDocumentContext(true)
    EvidenceDocumentContext := {ID: playerId, Name: playerName, Expires: TickNow() + timeoutMs}
    Evidence_Arm("DOC_LICENSE", timeoutMs)
    Evidence_Arm("DOC_TECHPASSPORT", timeoutMs)
    LogError("Evidence", "Ожидаются документы после досмотра ID " . playerId
        . ((playerName != "") ? " (" . playerName . ")" : ""), "INFO")
    return true
}

Evidence_GetDistanceToPlayerID(playerId, ByRef distance) {
    distance := -1
    if !RegExMatch(playerId . "", "^\d{1,4}$")
        return false
    selfCoords := getPlayerCoordinates()
    if !IsObject(selfCoords)
        return false
    pedPtr := getPlayerPedById(playerId + 0)
    if !IsLikelyPointer(pedPtr)
        return false
    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(targetCoords)
        return false
    dx := targetCoords[1] - selfCoords[1]
    dy := targetCoords[2] - selfCoords[2]
    dz := targetCoords[3] - selfCoords[3]
    distance := Sqrt(dx * dx + dy * dy + dz * dz)
    return true
}

Evidence_FindPlayerIDByName(playerName) {
    targetName := Evidence_NormalizeNickname(playerName)
    if (targetName = "")
        return -1
    Loop, 1004
    {
        playerId := A_Index - 1
        currentName := getPlayerNameById(playerId)
        if (currentName = "")
            continue
        if (Evidence_NormalizeNickname(currentName) = targetName)
            return playerId
    }
    return -1
}

Evidence_DocumentContextValid() {
    global EvidenceDocumentContext
    if !IsObject(EvidenceDocumentContext) || !EvidenceDocumentContext.HasKey("ID")
        return false
    if (!EvidenceDocumentContext.HasKey("Expires") || EvidenceDocumentContext.Expires <= TickNow()) {
        Evidence_ClearDocumentContext(true)
        return false
    }
    return true
}

Evidence_DocumentSenderMatches(line) {
    global EvidenceDocumentContext
    if !Evidence_DocumentContextValid()
        return false

    targetId := EvidenceDocumentContext.ID + 0
    targetName := EvidenceDocumentContext.HasKey("Name") ? EvidenceDocumentContext.Name : ""
    liveName := getPlayerNameById(targetId)
    if (liveName != "")
        targetName := liveName

    parsedId := ChatLogReader_ExtractID(line, targetName)
    if (parsedId >= 0)
        return (parsedId + 0 = targetId)

    senderName := ChatLogReader_ExtractNickname(line)
    if (senderName = "")
        return false

    senderLower := senderName
    targetLower := targetName
    StringLower, senderLower, senderLower
    StringLower, targetLower, targetLower
    if (targetLower != "" && senderLower = targetLower)
        return true

    resolvedId := Evidence_FindPlayerIDByName(senderName)
    return (resolvedId >= 0 && resolvedId = targetId)
}

Evidence_DocumentSenderIsNear() {
    global EvidenceDocumentContext, EvidenceDocumentDistanceLimit
    if !Evidence_DocumentContextValid()
        return false

    limit := EvidenceDocumentDistanceLimit
    NormalizeNumberRange(limit, 20, 2, 100)
    distance := -1
    if !Evidence_GetDistanceToPlayerID(EvidenceDocumentContext.ID, distance) {
        LogError("Evidence", "Документ отклонён: расстояние до владельца документов не определено.", "WARN")
        return false
    }
    if (distance > limit) {
        LogError("Evidence", "Документ отклонён: ID " . EvidenceDocumentContext.ID . " находится в "
            . Round(distance, 1) . " м, лимит " . limit . " м.", "WARN")
        return false
    }
    LogError("Evidence", "Документ от ID " . EvidenceDocumentContext.ID . ": расстояние "
        . Round(distance, 2) . " м.", "INFO")
    return true
}

Evidence_MaybeClearDocumentContext() {
    if (!Evidence_IsPending("DOC_LICENSE") && !Evidence_IsPending("DOC_TECHPASSPORT"))
        Evidence_ClearDocumentContext(false)
}

Evidence_NormalizeChatLine(line) {
    text := Trim(line, " `t`r`n")
    text := RegExReplace(text, "i)(?:\{|\[)[0-9A-F]{6,8}(?:\}|\])")
    text := RegExReplace(text, "^\s*\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*")
    text := StrReplace(text, "ё", "е")
    text := StrReplace(text, "Ё", "Е")
    text := RegExReplace(text, "\s+", " ")
    StringLower, text, text
    return Trim(text)
}

Evidence_NormalizeNickname(nickname) {
    nickname := Evidence_NormalizeChatLine(nickname)
    nickname := StrReplace(nickname, "\", "")
    nickname := RegExReplace(nickname, "[^a-zа-я0-9]")
    return nickname
}

Evidence_LineContainsNickname(line, nickname) {
    wanted := Evidence_NormalizeNickname(nickname)
    if (wanted = "")
        return false
    return InStr(Evidence_NormalizeNickname(line), wanted) > 0
}

Evidence_ExtractOtherNickname(line, ownNickname) {
    ownNormalized := Evidence_NormalizeNickname(ownNickname)
    searchPos := 1
    pattern := "i)([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})"
    while (searchPos := RegExMatch(line, pattern, match, searchPos))
    {
        candidate := match1
        if (Evidence_NormalizeNickname(candidate) != ownNormalized)
            return candidate
        searchPos += StrLen(match)
    }
    return ""
}

Evidence_BeginDocumentWindow() {
    global EvidenceScreenshotMode, EvidenceDocumentActivationMode, EvidenceDocumentWaitSec
    global EvidenceDocumentWindowExpires, EvidenceDocumentDistanceLimit, ChatLogPlayerNickname
    if (EvidenceScreenshotMode != "On" || EvidenceDocumentActivationMode != "После представления")
        return false
    if (Evidence_NormalizeNickname(ChatLogPlayerNickname) = "") {
        GameNotify("Автоскрин документов не включён: укажите свой Nick_Name в настройках «Автоскриншоты».", "WARN")
        return false
    }
    NormalizeNumberRange(EvidenceDocumentWaitSec, 90, 5, 300)
    Evidence_ClearDocumentContext(true)
    EvidenceDocumentWindowExpires := TickNow() + EvidenceDocumentWaitSec * 1000
    GameNotify("Ожидание документов: " . EvidenceDocumentWaitSec . " сек., радиус "
        . EvidenceDocumentDistanceLimit . " ед.", "INFO")
    return true
}

Evidence_DocumentActivationAllowed() {
    global EvidenceScreenshotMode, EvidenceDocumentActivationMode, EvidenceDocumentWindowExpires
    global ChatLogPlayerNickname
    if (EvidenceScreenshotMode != "On" || Evidence_NormalizeNickname(ChatLogPlayerNickname) = "")
        return false
    if (EvidenceDocumentActivationMode = "Только радиус")
        return true
    if (EvidenceDocumentActivationMode != "После представления")
        return false
    return (EvidenceDocumentWindowExpires > TickNow())
}

Evidence_IsOwnReportLine(text) {
    global Surname, PatrolUnit, PostUnit, ChatLogPlayerNickname
    normalized := Evidence_NormalizeChatLine(text)
    if (normalized = "")
        return false

    ownNickname := Evidence_NormalizeNickname(ChatLogPlayerNickname)
    if (ownNickname != "" && Evidence_LineContainsNickname(normalized, ownNickname))
        return true

    surnameText := Evidence_NormalizeChatLine(Surname)
    patrolText := Evidence_NormalizeChatLine(PatrolUnit)
    postText := Evidence_NormalizeChatLine(PostUnit)
    if (surnameText != "" && InStr(normalized, surnameText))
        return true
    if (patrolText != "" && InStr(normalized, patrolText))
        return true
    if (postText != "" && InStr(normalized, postText))
        return true
    return InStr(normalized, "вы ") || InStr(normalized, "вам ")
}

Evidence_IsOwnActionLine(text) {
    global ChatLogPlayerNickname
    ownName := Evidence_NormalizeNickname(ChatLogPlayerNickname)
    if (ownName = "")
        return false
    normalized := Evidence_NormalizeChatLine(text)
    if (Evidence_LineContainsNickname(normalized, ownName) || InStr(normalized, "вы ") || InStr(normalized, "вам "))
        return true
    return false
}

Evidence_DetectChatEvent(line) {
    text := Evidence_NormalizeChatLine(line)
    if (text = "")
        return ""

    documentEvent := Evidence_DetectReceivedDocument(line)
    if (documentEvent != "")
        return documentEvent

    ; Pending state already ties these confirmations to an action started by this script.
    ; Do not require the server line to contain our nickname: many server messages are impersonal.
    if (Evidence_IsPending("FINE")
        && RegExMatch(text, "i)(выписал[аи]?|выписан[ао]?|оштрафовал[аи]?|оштрафован[ао]?|назначил[аи]?\s+штраф|штраф\s+(?:успешно\s+)?(?:выписан|назначен|выдан|оформлен))"))
        return "FINE"

    if (Evidence_IsPending("ARREST")
        && RegExMatch(text, "i)(арестовал[аи]?|арестован[аоы]?|поместил[аи]?.*(?:кпз|камер|тюрьм)|посадил[аи]?.*(?:кпз|камер|тюрьм)|отправил[аи]?.*(?:кпз|тюрьм)|заключил[аи]?.*под\s+страж|доставлен[ао]?.*(?:кпз|камер)|заключен[ао]?\s+под\s+страж)"))
        return "ARREST"

    if (Evidence_IsPending("SEARCH_TRUNK")
        && (RegExMatch(text, "i)(обыскал[аи]?|обыскива|досмотрел[аи]?|досматрива|пров(?:е|ё)л[аи]?|проверил[аи]?|проверя|произв(?:е|ё)л[аи]?|осмотрел[аи]?|осматрива).*(багажник|автомобил|транспортн\w*\s+средств|тс)")
        || RegExMatch(text, "i)(багажник|автомобил|транспортн\w*\s+средств|тс).*(досмотрен|обыскан|осмотрен|проверен)")))
        return "SEARCH_TRUNK"

    if (Evidence_IsPending("SEARCH_PERSON")
        && (RegExMatch(text, "i)(обыскал[аи]?|обыскива|досмотрел[аи]?|досматрива|пров(?:е|ё)л[аи]?|проверил[аи]?|произв(?:е|ё)л[аи]?|выполнил[аи]?).*(обыск|личн\w*\s+досмотр|граждан|игрок)")
        || RegExMatch(text, "i)(личн\w*\s+досмотр|обыск).*(проведен|проведён|выполнен|завершен|завершён|начат)")))
        return "SEARCH_PERSON"

    reportEvent := Evidence_ClassifyReportText(text)
    if (reportEvent != "" && Evidence_IsPending(reportEvent) && Evidence_IsOwnReportLine(line))
        return reportEvent

    return ""
}

Evidence_RequestScreenshot(eventCode, delayMs := 700) {
    global EvidenceScreenshotMode, EvidenceScreenshotQueue, EvidenceScreenshotMethod
    if (EvidenceScreenshotMode != "On" || !Evidence_IsAllowedEvent(eventCode))
        return false
    if !IsObject(EvidenceScreenshotQueue)
        EvidenceScreenshotQueue := []
    delayMs := Round(delayMs)
    if (delayMs < 100)
        delayMs := 100
    else if (delayMs > 10000)
        delayMs := 10000

    dueTick := TickNow() + delayMs
    expiresTick := dueTick + 20000
    ; The same chat line can be observed by both the direct-send and chatlog paths.
    ; Merge only near-identical requests, without suppressing later real events.
    for index, queuedItem in EvidenceScreenshotQueue
    {
        if (queuedItem.Code = eventCode && Abs(queuedItem.Due - dueTick) <= 800) {
            if (dueTick < queuedItem.Due)
                queuedItem.Due := dueTick
            if (!queuedItem.HasKey("Expires") || queuedItem.Expires < expiresTick)
                queuedItem.Expires := expiresTick
            SetTimer, EvidenceScreenshotTimer, 100
            return true
        }
    }

    EvidenceScreenshotQueue.Push({Code:eventCode, Due:dueTick, Expires:expiresTick
        , Attempts:0, InactiveLogged:0})
    SetTimer, EvidenceScreenshotTimer, 100
    LogError("Evidence", "Запланирован снимок (" . EvidenceScreenshotMethod . "): "
        . Evidence_EventLabel(eventCode), "INFO")
    return true
}

Evidence_ClassifyReportText(text) {
    global Surname, PatrolUnit, PostUnit
    normalized := Evidence_NormalizeChatLine(ApplyActionTemplate(text))
    hasRadioPrefix := RegExMatch(normalized, "^/(?:r|radio)\s+")
    if (hasRadioPrefix)
        normalized := RegExReplace(normalized, "^/(?:r|radio)\s+")

    if RegExMatch(normalized, "^докладывает\s+[^:]{1,100}:\s*(.+)$", report)
        action := report1
    else {
        ; Organization presets often omit the word "докладывает".
        if !hasRadioPrefix
            return ""
        surnameText := Evidence_NormalizeChatLine(Surname)
        patrolText := Evidence_NormalizeChatLine(PatrolUnit)
        postText := Evidence_NormalizeChatLine(PostUnit)
        presetPrefix := InStr(normalized, "экипаж ") = 1
            || InStr(normalized, "оперативная группа ") = 1
            || InStr(normalized, "специальная группа ") = 1
            || InStr(normalized, "военный патруль ") = 1
            || InStr(normalized, "караул ") = 1
        ownIdentity := (surnameText != "" && InStr(normalized, surnameText))
            || (patrolText != "" && InStr(normalized, patrolText))
            || (postText != "" && InStr(normalized, postText))
        if (!presetPrefix && !ownIdentity)
            return ""
        action := normalized
    }

    isSos := InStr(action, "sos") || (InStr(action, "срочн") && InStr(action, "помощ"))
        || (InStr(action, "сигнал") && InStr(action, "помощ"))
    if (isSos) {
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "SOS_ARRIVE"
        if RegExMatch(action, "(реагир|принял|приняла|приняли|выехал|выехала|выехали|выдвиг|выдвин|направил|направила|направили)")
            return "SOS_START"
    }

    if (InStr(action, "вызов") && InStr(action, "гражданск")) {
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "CIVIL_ARRIVE"
        if RegExMatch(action, "(принял|приняла|приняли|реагир|выехал|выехала|выехали|выдвиг|выдвин|направил|направила|направили)")
            return "CIVIL_START"
    }

    ; Some built-in organization presets describe work without repeating ДТП/происшествие.
    if (RegExMatch(action, "(приступил|приступила|приступили|начал|начала|начали).*(оперативн[а-яё]*\s+мероприят|выполнен[а-яё]*\s+задач|обеспечен[а-яё]*\s+поряд)"))
        return "CALL_WORK_START"
    if (RegExMatch(action, "(оперативн[а-яё]*\s+мероприят|выполнен[а-яё]*\s+задач).*(завершил|завершила|завершили|завершен|завершена)")
        || RegExMatch(action, "задач[а-яё]*.*(выполнил|выполнила|выполнили)"))
        return "CALL_WORK_END"

    if (InStr(action, "дтп") || InStr(action, "происшеств") || InStr(action, "авари")) {
        if RegExMatch(action, "(завершил|завершила|завершили|закончил|закончила|закончили|выполнил|выполнила|выполнили).*(оформлен|работ|мероприят|задач|поряд)")
            || RegExMatch(action, "(оформлен|работ|мероприят|задач).*(завершен|завершена|завершили|выполнен|выполнена)")
            return "CALL_WORK_END"
        if RegExMatch(action, "(приступил|приступила|приступили|начал|начала|начали).*(оформлен|работ|мероприят|задач|поряд)")
            return "CALL_WORK_START"
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "CALL_ARRIVE"
        if RegExMatch(action, "(принял|приняла|приняли|реагир|сообщен|сообщён)")
            return "CALL_START"
    }

    if (RegExMatch(action, "(начал|начала|начали|приступил|приступила|приступили).*(эваку|погруз)")
        || RegExMatch(action, "(эвакуац|погруз).*(начат|началась|начата)"))
        return "EVAC_START"
    if (RegExMatch(action, "(эвакуировал|эвакуировала|эвакуировали|завершил|завершила|завершили|доставил|доставила|доставили).*(тс|автомобил|транспорт|эвакуац|штраф|стоянк)")
        || RegExMatch(action, "(тс|автомобил|транспорт|эвакуац).*(эвакуирован|завершен|завершена|доставлен|перемещен)"))
        return "EVAC_END"

    isPatrol := InStr(action, "патрул") || (InStr(action, "маршрут") && InStr(action, "служб"))
    if (isPatrol) {
        if RegExMatch(action, "(завершил|завершила|завершили|окончил|окончила|окончили|закончил|закончила|закончили|покида)")
            return "PATROL_END"
        if RegExMatch(action, "(патрулиру|продолжа|обстановка|без происшеств|несение службы)")
            return "PATROL_CONTINUE"
        if RegExMatch(action, "(заступил|заступила|заступили|начал|начала|начали|приступил|приступила|приступили|выехал|выехала|выехали)")
            return "PATROL_START"
    }

    isPost := InStr(action, "пост") || InStr(action, "караул")
        || (InStr(action, "объект") && RegExMatch(action, "(заступ|приступ|продолжа|работ|служб|заверш)"))
    if (isPost) {
        if RegExMatch(action, "(покинул|покинула|покинули|покида|завершил|завершила|завершили|снялся|снялась|снялись|закончил|закончила|закончили)")
            return "POST_END"
        if RegExMatch(action, "(продолжа|стоим|стоять|обстановка|без происшеств|несение службы|работа на объекте|работу на объекте)")
            return "POST_CONTINUE"
        if RegExMatch(action, "(заступил|заступила|заступили|начал|начала|начали|прибыл|прибыла|прибыли|приступил|приступила|приступили)")
            return "POST_START"
    }
    return ""
}

Evidence_IsReportText(text) {
    normalized := Evidence_NormalizeChatLine(ApplyActionTemplate(text))
    return RegExMatch(normalized, "^/(?:r|radio)\s+\S") > 0
        || InStr(normalized, "докладывает") > 0
}

Evidence_MaybeCaptureReportText(text) {
    if !Evidence_IsReportText(text)
        return false
    eventCode := Evidence_ClassifyReportText(text)
    if (eventCode != "") {
        Evidence_Arm(eventCode, 120000)
        ; Direct fallback removes dependence on chatlog timing/path. A chatlog request
        ; for the same event is merged by Evidence_RequestScreenshot.
        return Evidence_RequestScreenshot(eventCode, 650)
    }
    ; Unknown user-defined radio reports cannot be confirmed by phrase classification.
    ; Capture them directly after the line has had time to appear in chat.
    return Evidence_RequestScreenshot("REPORT", 500)
}

Evidence_RunRecognitionMatrix() {
    cases := []
    cases.Push({Text:"/r докладывает Лукашенко: реагирую на вызов срочной помощи.", Event:"SOS_START"})
    cases.Push({Text:"{33CCFF}[12:04:07] /R ДОКЛАДЫВАЕТ Лукашенко: прибыл на вызов срочной помощи!!!", Event:"SOS_ARRIVE"})
    cases.Push({Text:"/r докладывает Лукашенко: принял вызов гражданскго.", Event:"CIVIL_START"})
    cases.Push({Text:"/r  докладывает  Лукашенко:  прибыл на вызов гражданского.", Event:"CIVIL_ARRIVE"})
    cases.Push({Text:"/r докладывает экипаж Р101: принял вызов о ДТП.", Event:"CALL_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: прибыли на вызов о ДТП.", Event:"CALL_ARRIVE"})
    cases.Push({Text:"/r докладывает экипаж Р101: приступили к оформлению ДТП.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: завершили оформление ДТП.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r докладывает Лукашенко: начал эвакуировать ТС на штрафстоянку.", Event:"EVAC_START"})
    cases.Push({Text:"/r докладывает Лукашенко: эвакуировал ТС на штрафстоянку.", Event:"EVAC_END"})
    cases.Push({Text:"/r докладывает экипаж Р101: заступили на патрулирование.", Event:"PATROL_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: патрулируем по маршруту.", Event:"PATROL_CONTINUE"})
    cases.Push({Text:"/r докладывает экипаж Р101: завершили патруль.", Event:"PATROL_END"})
    cases.Push({Text:"/r докладывает экипаж Р101: заступили на пост.", Event:"POST_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: продолжаем стоять на посту.", Event:"POST_CONTINUE"})
    cases.Push({Text:"/r докладывает экипаж Р101: покинули пост.", Event:"POST_END"})
    cases.Push({Text:"/r Экипаж Р101, выдвигаемся на вызов SOS.", Event:"SOS_START"})
    cases.Push({Text:"/r Экипаж Р101, прибыли на вызов SOS.", Event:"SOS_ARRIVE"})
    cases.Push({Text:"/r Оперативная группа Р101, приняла сообщение о происшествии.", Event:"CALL_START"})
    cases.Push({Text:"/r Оперативная группа Р101, прибыла на место происшествия.", Event:"CALL_ARRIVE"})
    cases.Push({Text:"/r Специальная группа Р101, приступила к выполнению задачи на месте происшествия.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r Специальная группа Р101, выполнение задачи на месте происшествия завершила.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r Военный патруль Р101, продолжает несение службы по маршруту А-1.", Event:"PATROL_CONTINUE"})
    cases.Push({Text:"/r Оперативная группа Р202, работу на объекте КПП завершила.", Event:"POST_END"})
    cases.Push({Text:"/r Оперативная группа Р101, выдвинулась на вызов SOS.", Event:"SOS_START"})
    cases.Push({Text:"/r Оперативная группа Р101, приступила к оперативным мероприятиям.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r Оперативная группа Р101, оперативные мероприятия завершила.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r Военный патруль Р101, задачу выполнил.", Event:"CALL_WORK_END"})
    cases.Push({Text:"В чате обсуждают патруль и пост.", Event:""})
    cases.Push({Text:"/r докладывает Лукашенко: гражданский находится рядом.", Event:""})
    cases.Push({Text:"/r докладывает экипаж Р101: ДТП.", Event:""})
    cases.Push({Text:"/r сотрудник начал эвакуировать ТС.", Event:""})

    failures := []
    Loop % cases.Length()
    {
        item := cases[A_Index]
        actual := Evidence_ClassifyReportText(item.Text)
        if (actual != item.Event)
            failures.Push(A_Index . ": ожидалось " . item.Event . ", получено " . actual)
    }
    return {Ok: failures.Length() = 0, Total: cases.Length()
        , Passed: cases.Length() - failures.Length(), Failures: failures}
}

Evidence_SendKeyPress(keyName, modifier := "") {
    global MockMode
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[SCREENSHOT requested] " . modifier . "+" . keyName)
        return true
    }
    if (PhysicalInputBusy || !GameLocator_IsActive())
        return false
    PhysicalInputBusy := 1
    epoch := AutomationEpoch
    modifierDown := false, keyDown := false
    try {
        if (modifier != "") {
            modifierDown := SafeSend("{" . modifier . " down}", "Input", epoch)
            if (!modifierDown)
                return false
            Sleep, 30
        }
        keyDown := SafeSend("{" . keyName . " down}", "Input", epoch)
        if (!keyDown)
            return false
        Sleep, 60
        return epoch = AutomationEpoch && GameLocator_IsActive()
    } finally {
        ; Releases never depend on focus: a held modifier must not remain stuck after Alt-Tab.
        if (keyDown)
            SendInput, {%keyName% up}
        if (modifierDown)
            SendInput, {%modifier% up}
        PhysicalInputBusy := 0
    }
}

Evidence_SendScreenshot() {
    global EvidenceScreenshotMethod
    method := EvidenceScreenshotMethod
    if (method = "PrintScreen")
        Evidence_SendKeyPress("PrintScreen")
    else if (method = "Win+PrintScreen")
        Evidence_SendKeyPress("PrintScreen", "LWin")
    else if (method = "Alt+PrintScreen")
        Evidence_SendKeyPress("PrintScreen", "LAlt")
    else if (method = "F8")
        Evidence_SendKeyPress("F8")
    else if (method = "F12")
        Evidence_SendKeyPress("F12")
    else {
        method := "Alt+F1"
        Evidence_SendKeyPress("F1", "LAlt")
    }
    return method
}

Evidence_ProcessScreenshotQueue() {
    global EvidenceScreenshotMode, EvidenceScreenshotQueue, EvidencePendingEvents, EvidenceLastCaptureTick
    if (EvidenceScreenshotMode != "On") {
        EvidenceScreenshotQueue := []
        EvidencePendingEvents := {}
        SetTimer, EvidenceScreenshotTimer, Off
        return false
    }
    if !IsObject(EvidenceScreenshotQueue) || EvidenceScreenshotQueue.Length() = 0 {
        SetTimer, EvidenceScreenshotTimer, Off
        return false
    }

    item := EvidenceScreenshotQueue[1]
    if (TickNow() < item.Due)
        return false
    if (EvidenceLastCaptureTick > 0 && TickNow() - EvidenceLastCaptureTick < 1200) {
        EvidenceScreenshotQueue[1].Due := EvidenceLastCaptureTick + 1200
        return false
    }

    if !item.HasKey("Expires")
        item.Expires := item.Due + 20000
    if !item.HasKey("Attempts")
        item.Attempts := 0
    if !item.HasKey("InactiveLogged")
        item.InactiveLogged := 0

    if !IsGameActive() {
        item.Attempts += 1
        if (TickNow() < item.Expires) {
            item.Due := TickNow() + 250
            if (!item.InactiveLogged) {
                item.InactiveLogged := 1
                LogError("Evidence", "Снимок ожидает возврата фокуса в игру: "
                    . Evidence_EventLabel(item.Code), "INFO")
            }
            return false
        }
        EvidenceScreenshotQueue.RemoveAt(1)
        LogError("Evidence", "Снимок отменён: игра не стала активной за 20 сек.: "
            . Evidence_EventLabel(item.Code), "WARN")
        if (EvidenceScreenshotQueue.Length() = 0)
            SetTimer, EvidenceScreenshotTimer, Off
        return false
    }

    EvidenceScreenshotQueue.RemoveAt(1)
    try {
        usedMethod := Evidence_SendScreenshot()
        EvidenceLastCaptureTick := TickNow()
        LogError("Evidence", "Нажат " . usedMethod . ": " . Evidence_EventLabel(item.Code), "INFO")
    } catch e {
        if (TickNow() < item.Expires) {
            item.Due := TickNow() + 400
            item.Attempts += 1
            EvidenceScreenshotQueue.InsertAt(1, item)
            LogError("Evidence", "Повтор снимка после ошибки отправки клавиши: " . e.Message, "WARN")
        } else {
            LogError("Evidence", "Снимок не выполнен: " . e.Message, "ERROR")
        }
    }

    if (EvidenceScreenshotQueue.Length() = 0)
        SetTimer, EvidenceScreenshotTimer, Off
    return true
}

Evidence_DetectReceivedDocument(line) {
    global ChatLogPlayerNickname, EvidenceDocumentContext, EvidenceDocumentWaitSec
    if !Evidence_DocumentActivationAllowed()
        return ""

    lowerLine := Evidence_NormalizeChatLine(line)
    if (lowerLine = "")
        return ""
    ownContext := Evidence_LineContainsNickname(lowerLine, ChatLogPlayerNickname)
        || RegExMatch(lowerLine, "i)(?:^|[\s,:])(вам|вы|вас|ваш|ваши|вашего|вашему)(?:[\s,:.!?]|$)")
    if !ownContext
        return ""

    documentEvent := ""
    if (RegExMatch(lowerLine, "i)тех[\s\.\-]*паспорт")
        || RegExMatch(lowerLine, "i)техническ(?:ий|ого|ому|им|ом)?\s+паспорт")
        || (InStr(lowerLine, "свидетельств") && InStr(lowerLine, "регистрац")))
        documentEvent := "DOC_TECHPASSPORT"
    else if InStr(lowerLine, "лиценз")
        documentEvent := "DOC_LICENSE"
    if (documentEvent = "")
        return ""

    actionMatch := RegExMatch(lowerLine, "i)(посмотр|просматр|провер|изуч|ознаком|предъяв|показ|получ|переда|достае|берет|берёт|открыл|открыла|демонстр|предостав)")
    if (!actionMatch && !(InStr(lowerLine, "документ") && InStr(lowerLine, "лиценз")))
        return ""

    targetName := Evidence_ExtractOtherNickname(line, ChatLogPlayerNickname)
    if (targetName = "") {
        LogError("Evidence", "Документ отклонён: в строке не найден Nick_Name проверяемого игрока.", "WARN")
        return ""
    }
    targetId := Evidence_FindPlayerIDByName(targetName)
    if (targetId < 0) {
        LogError("Evidence", "Документ отклонён: игрок " . targetName . " не найден рядом/в списке.", "WARN")
        return ""
    }

    NormalizeNumberRange(EvidenceDocumentWaitSec, 90, 5, 300)
    EvidenceDocumentContext := {ID: targetId, Name: targetName
        , Expires: TickNow() + EvidenceDocumentWaitSec * 1000}
    if !Evidence_DocumentSenderIsNear()
        return ""
    Evidence_Arm(documentEvent, 5000)
    LogError("Evidence", "Документы " . targetName . " (ID " . targetId . ") распознаны по строке chatlog.", "INFO")
    return documentEvent
}

ResolveChatLogPath() {
    global ChatLogPath
    configured := Trim(ChatLogPath)
    if (SubStr(configured, 1, 1) = """" && SubStr(configured, 0) = """")
        configured := SubStr(configured, 2, StrLen(configured) - 2)
    if (configured != "")
        return configured

    candidates := []
    candidates.Push("C:\Amazing Games\Amazing Online\PC\amazing\chatlog.txt")
    candidates.Push(A_MyDocuments . "\GTA San Andreas User Files\SAMP\chatlog.txt")
    Loop % candidates.Length()
    {
        candidate := candidates[A_Index]
        if FileExist(candidate)
            return candidate
    }
    return configured
}

ChatLogReader_MaybeCleanup(path, fileSize := -1) {
    global ChatLogAutoCleanupEnabled
    ChatLogAutoCleanupEnabled := "Off"
    return false
}

InitChatLogReader() {
    global ChatLogLastPos, ChatLogFileSeen, ChatLogPendingIdResultLine
    global ChatLogLookupAction, ChatLogLookupVariant, ChatLogLookupName, ChatLogLookupStartedTick
    ChatLogReaderIdentity := ""
    ChatLogLastPos := 0
    ChatLogFileSeen := false
    ChatLogPendingIdResultLine := 0
    ChatLogLookupAction := ""
    ChatLogLookupVariant := ""
    ChatLogLookupName := ""
    ChatLogLookupStartedTick := 0

    path := ResolveChatLogPath()
    if (path = "" || !FileExist(path))
        return false
    file := FileOpen(path, "r", "CP1251")
    if !IsObject(file)
        return false
    file.Seek(0, 2)
    ChatLogLastPos := file.Pos
    file.Close()
    ChatLogFileSeen := true
    LogError("ChatLogReader", "Watching " . path . " from byte " . ChatLogLastPos, "INFO")
    return true
}

ChatLogReader_CanTrigger(actionKey, cooldownMs := 5000) {
    global ChatLogActionCooldowns
    if !IsObject(ChatLogActionCooldowns)
        ChatLogActionCooldowns := {}
    lastTick := ChatLogActionCooldowns.HasKey(actionKey) ? ChatLogActionCooldowns[actionKey] : 0
    if (lastTick > 0 && TickNow() - lastTick < cooldownMs)
        return false
    ChatLogActionCooldowns[actionKey] := TickNow()
    return true
}

ChatLogReader_ExtractID(line, lookupName := "") {
    if (lookupName != "") {
        if RegExMatch(line, "i)\Q" . lookupName . "\E\s*(?:\[|\(\s*ID\s*[:#]?\s*)(\d{1,6})", match)
            return match1 + 0
        if RegExMatch(line, "i)(?:\[|\bID\s*[:#]?\s*)(\d{1,6})\]?\s*[-:|]*\s*\Q" . lookupName . "\E", match)
            return match1 + 0
        spacedName := StrReplace(lookupName, "_", " ")
        if (spacedName != lookupName) {
            if RegExMatch(line, "i)\Q" . spacedName . "\E\s*(?:\[|\(\s*ID\s*[:#]?\s*)(\d{1,6})", match)
                return match1 + 0
            if RegExMatch(line, "i)(?:\[|\bID\s*[:#]?\s*)(\d{1,6})\]?\s*[-:|]*\s*\Q" . spacedName . "\E", match)
                return match1 + 0
        }
    }
    if RegExMatch(line, "i)\[(\d{1,6})\]", match)
        return match1 + 0
    if RegExMatch(line, "i)\bID\s*[:#]?\s*(\d{1,6})", match)
        return match1 + 0
    if (lookupName != "" && ChatLogReader_LineContainsName(line, lookupName)
        && RegExMatch(line, "i)(?:^|\s)(\d{1,6})(?:\s|$)", match))
        return match1 + 0
    return -1
}

ChatLogReader_ExtractChaseTargetID(line) {
    ids := []
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)\[(\d{1,6})\]", match)
        if (!found)
            break
        ids.Push(match1 + 0)
        offset += found + StrLen(match) - 1
    }

    ; В сообщении о начале преследования первый ID принадлежит инициатору,
    ; второй — игроку, которого начали преследовать.
    if (ids.Length() >= 2)
        return ids[2]
    if (ids.Length() = 1)
        return ids[1]

    ; Резерв для серверных форматов без квадратных скобок.
    ids := []
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)\bID\s*[:#]?\s*(\d{1,6})", match)
        if (!found)
            break
        ids.Push(match1 + 0)
        offset += found + StrLen(match) - 1
    }
    if (ids.Length() >= 2)
        return ids[2]
    if (ids.Length() = 1)
        return ids[1]
    return -1
}

ChatLogReader_ExtractNicknameByID(line, playerId) {
    if (playerId < 0)
        return ""
    namePattern := "([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})"
    if RegExMatch(line, "i)" . namePattern . "\s*\[\s*" . playerId . "\s*\]", match)
        return match1
    if RegExMatch(line, "i)\[\s*" . playerId . "\s*\]\s*" . namePattern, match)
        return match1
    return ""
}

ChatLogReader_ExtractNickname(line) {
    global ChatLogPlayerNickname
    ownName := ChatLogPlayerNickname
    StringLower, ownLower, ownName
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})", match)
        if (!found)
            break
        candidate := match1
        StringLower, candidateLower, candidate
        if (candidateLower != ownLower)
            return candidate
        offset += found + StrLen(match) - 1
    }
    return ""
}

ChatLogReader_ClearLookup() {
    global ChatLogPendingIdResultLine, ChatLogLookupAction, ChatLogLookupVariant
    global ChatLogLookupName, ChatLogLookupStartedTick
    ChatLogPendingIdResultLine := 0
    ChatLogLookupAction := ""
    ChatLogLookupVariant := ""
    ChatLogLookupName := ""
    ChatLogLookupStartedTick := 0
}

ChatLogReader_ApplyDetectedID(playerId, playerName := "", source := "") {
    if (playerId < 0)
        return false
    LogError("ChatLogReader", "Detected ID " . playerId . ((playerName != "") ? (" (" . playerName . ")") : "")
        . ((source != "") ? (" from " . source) : "") . "; command execution suppressed", "INFO")
    ; Чат-триггеры только подставляют ID как текущую цель.
    ; Они никогда не запускают /chase, /cuff, тазер, обыск и другие команды.
    return ContextAssistant_Execute("EnterID", playerId, "", playerName)
}

ChatLogReader_CompleteLookup(playerId) {
    global ChatLogLookupAction, ChatLogLookupName
    actionName := ChatLogLookupAction
    playerName := ChatLogLookupName
    ChatLogReader_ClearLookup()
    if (playerId < 0)
        return false
    return ChatLogReader_ApplyDetectedID(playerId, playerName, actionName . "/lookup")
}

ChatLogReader_BeginLookup(actionName, playerName, variant := "") {
    global ChatLogLookupAction, ChatLogLookupVariant, ChatLogLookupName
    global ChatLogLookupStartedTick, ChatLogPendingIdResultLine
    playerName := Trim(playerName)
    if (playerName = "")
        return false
    if (ChatLogLookupAction != "" && TickNow() - ChatLogLookupStartedTick < 12000) {
        LogError("ChatLogReader", "Lookup skipped while another request is active: " . playerName, "WARN")
        return false
    }
    ChatLogLookupAction := actionName
    ChatLogLookupVariant := variant
    ChatLogLookupName := playerName
    ChatLogLookupStartedTick := TickNow()
    ChatLogPendingIdResultLine := 0
    return ChatQueue_Enqueue("/id " . playerName, "ChatLogReader.Lookup", 0, 900, 1)
}

ChatLogReader_HandleTargetEvent(actionName, line, variant := "") {
    if !ContextAssistant_IsEnabled(actionName)
        return false
    if (actionName = "Chase")
        playerId := ChatLogReader_ExtractChaseTargetID(line)
    else
        playerId := ChatLogReader_ExtractID(line)
    if (playerId >= 0) {
        playerName := ChatLogReader_ExtractNicknameByID(line, playerId)
        return ChatLogReader_ApplyDetectedID(playerId, playerName, actionName)
    }
    playerName := ChatLogReader_ExtractNickname(line)
    if (playerName != "")
        return ChatLogReader_BeginLookup(actionName, playerName, variant)
    LogError("ChatLogReader", "Target not parsed for " . actionName . ": " . line, "WARN")
    return false
}

ChatLogReader_LineContainsName(line, playerName) {
    playerName := Trim(playerName)
    if (playerName = "")
        return false
    StringLower, lineLower, line
    StringLower, nameLower, playerName
    if InStr(lineLower, nameLower)
        return true
    spacedName := StrReplace(nameLower, "_", " ")
    return (spacedName != nameLower && InStr(lineLower, spacedName)) ? true : false
}

ChatLogReader_HandleLookupLine(line) {
    global ChatLogLookupAction, ChatLogLookupName, ChatLogLookupStartedTick, ChatLogPendingIdResultLine
    if (ChatLogLookupAction = "")
        return false
    if (AZMP_TickElapsed(ChatLogLookupStartedTick) > 12000) {
        LogError("ChatLogReader", "Lookup timeout for " . ChatLogLookupName, "WARN")
        ChatLogReader_ClearLookup()
        return false
    }

    if InStr(line, "Игроки онлайн:") {
        ChatLogPendingIdResultLine := 3
        return true
    }

    ; Никогда не принимаем произвольный ID из следующих строк. В загруженном
    ; варианте через две строки брался первый попавшийся [ID], из-за чего
    ; активная цель могла получать данные другого игрока.
    if ChatLogReader_LineContainsName(line, ChatLogLookupName) {
        playerId := ChatLogReader_ExtractID(line, ChatLogLookupName)
        if (playerId >= 0)
            return ChatLogReader_CompleteLookup(playerId)
    }

    if (ChatLogPendingIdResultLine > 0) {
        ChatLogPendingIdResultLine -= 1
        if (ChatLogPendingIdResultLine = 0)
            LogError("ChatLogReader", "Lookup response did not contain requested name: " . ChatLogLookupName, "WARN")
    }
    return false
}

ChatLogReader_ProcessLine(line) {
    global ChatLogPlayerNickname, ChatLogRescuePending
    line := Trim(line, " `t`r`n")
    if (line = "")
        return false
    if ChatLogReader_HandleLookupLine(line)
        return true

    StringLower, lowerLine, line
    ownName := ChatLogPlayerNickname
    StringLower, ownLower, ownName
    ownEvent := (ownLower != "" && InStr(lowerLine, ownLower)) || InStr(lowerLine, "вы ")

    evidenceEvent := Evidence_DetectChatEvent(line)
    if (evidenceEvent != "" && ChatLogReader_CanTrigger("Evidence:" . evidenceEvent, 3000)) {
        captureDelay := (evidenceEvent = "DOC_LICENSE" || evidenceEvent = "DOC_TECHPASSPORT"
            || evidenceEvent = "EVAC_START" || evidenceEvent = "EVAC_END"
            || evidenceEvent = "SOS_START" || evidenceEvent = "SOS_ARRIVE"
            || evidenceEvent = "CIVIL_START" || evidenceEvent = "CIVIL_ARRIVE"
            || evidenceEvent = "CALL_START" || evidenceEvent = "CALL_ARRIVE"
            || evidenceEvent = "CALL_WORK_START" || evidenceEvent = "CALL_WORK_END"
            || evidenceEvent = "PATROL_START" || evidenceEvent = "PATROL_CONTINUE"
            || evidenceEvent = "PATROL_END" || evidenceEvent = "POST_START"
            || evidenceEvent = "POST_CONTINUE" || evidenceEvent = "POST_END") ? 150 : 350
        isDocumentEvent := (SubStr(evidenceEvent, 1, 4) = "DOC_")
        if (isDocumentEvent) {
            if Evidence_ConsumePending(evidenceEvent)
                Evidence_RequestScreenshot(evidenceEvent, captureDelay)
            Evidence_MaybeClearDocumentContext()
        } else if Evidence_ConsumePending(evidenceEvent)
            Evidence_RequestScreenshot(evidenceEvent, captureDelay)
    }

    if RegExMatch(line, "i)Сработала сигнализация дома\s*(?:№|#)?\s*(\d{1,6})", houseMatch) {
        if ChatLogReader_CanTrigger("HouseAlarm:" . houseMatch1, 8000)
            return ContextAssistant_Request("HouseAlarm", houseMatch1)
        return false
    }

    if (InStr(lowerLine, "вы спасли") && IsObject(ChatLogRescuePending)) {
        ; Завершение спасения больше не запускает /cuff. ID уже был подставлен
        ; при первом сообщении, либо будет найден по нику ниже.
        rescue := ChatLogRescuePending
        ChatLogRescuePending := 0
        if (rescue.HasKey("ID") && rescue.ID >= 0)
            return ChatLogReader_ApplyDetectedID(rescue.ID, rescue.HasKey("Name") ? rescue.Name : "", "RescueComplete")
        if (rescue.HasKey("Name") && rescue.Name != "")
            return ChatLogReader_BeginLookup("RescueComplete", rescue.Name)
        return false
    }

    if (InStr(lowerLine, "спасать игрока") && InStr(lowerLine, "вы начал")) {
        rescueId := ChatLogReader_ExtractID(line)
        rescueName := ChatLogReader_ExtractNickname(line)
        ChatLogRescuePending := {ID: rescueId, Name: rescueName, StartedTick: TickNow()}
        if (rescueId >= 0)
            return ChatLogReader_ApplyDetectedID(rescueId, rescueName, "RescueStart")
        if (rescueName != "")
            return ChatLogReader_BeginLookup("RescueStart", rescueName)
        return true
    }

    if InStr(lowerLine, "вы оглушили") {
        variant := InStr(lowerLine, "дубин") ? "baton" : "taser"
        if ChatLogReader_CanTrigger("Stun", 5000)
            return ChatLogReader_HandleTargetEvent("Stun", line, variant)
        return false
    }

    if ((InStr(lowerLine, "употребил") || InStr(lowerLine, "употребила")) && (InStr(lowerLine, "мятн") || InStr(lowerLine, "зелен") || InStr(lowerLine, "зелён"))) {
        if ChatLogReader_CanTrigger("DrugsNearby", 7000)
            return ChatLogReader_HandleTargetEvent("DrugsNearby", line)
        return false
    }

    if (ownEvent && InStr(lowerLine, "местополож")) {
        if ChatLogReader_CanTrigger("OOPSearch", 5000)
            return ChatLogReader_HandleTargetEvent("OOPSearch", line)
        return false
    }

    if (ownEvent && InStr(lowerLine, "преследован")) {
        if ChatLogReader_CanTrigger("Chase", 5000)
            return ChatLogReader_HandleTargetEvent("Chase", line)
        return false
    }
    return false
}

ChatLogReader_Tick() {
    global ChatLogReaderEnabled, MockMode, ChatLogLastPos, ChatLogFileSeen, ChatLogReaderIdentity
    if (ChatLogReaderEnabled != "On" || MockMode = "On")
        return false
    path := ResolveChatLogPath()
    file := FileOpen(path, "r", "CP1251")
    if !IsObject(file) {
        ChatLogReader_ResetGeneration()
        return false
    }
    try {
        fileIdentity := ChatLogReader_FileIdentity(file)
        identity := path . "|" . fileIdentity
        if (fileIdentity = "")
            return false
        if (!ChatLogFileSeen || identity != ChatLogReaderIdentity || file.Length < ChatLogLastPos || (ChatLogCursorSignature != "" && ChatLogReader_CursorSignature(file, ChatLogLastPos) != ChatLogCursorSignature)) {
            ChatLogReader_ResetGeneration()
            ChatLogReaderIdentity := identity
            ChatLogFileSeen := true
            ChatLogLastPos := file.Length
            ChatLogCursorSignature := ChatLogReader_CursorSignature(file, ChatLogLastPos)
            return true
        }
        remaining := file.Length - ChatLogLastPos
        if (remaining <= 0)
            return true
        file.Pos := ChatLogLastPos
        readSize := Min(65536, remaining)
        VarSetCapacity(chunk, readSize, 0)
        bytes := file.RawRead(chunk, readSize)
        if (!bytes)
            return true
        lastBreak := 0, processed := 0, lineStart := 0
        Loop % bytes {
            if (NumGet(chunk, A_Index - 1, "UChar") != 10)
                continue
            length := A_Index - 1 - lineStart
            if (ChatLogReaderDroppingLine)
                ChatLogReaderDroppingLine := 0
            else if (length <= 16384)
            {
                completeLine := RTrim(StrGet(&chunk + lineStart, length, "CP1251"), "`r")
                if (AuditTestMode && IsObject(AuditReaderLines))
                    AuditReaderLines.Push(completeLine)
                else
                    ChatLogReader_ProcessLine(completeLine)
            }
            else
                LogError("ChatLogReader", "Пропущена строка длиннее 16 КиБ.", "WARN")
            lastBreak := A_Index
            lineStart := lastBreak
            processed++
            if (processed >= 200)
                break
        }
        ; Keep the byte checkpoint before an incomplete line. No fragment is dispatched.
        if (lastBreak = 0 && bytes >= 65536) {
            ChatLogReaderDroppingLine := 1
            ChatLogLastPos += bytes
        } else {
            ChatLogLastPos += lastBreak
        }
        ChatLogCursorSignature := ChatLogReader_CursorSignature(file, ChatLogLastPos)
        return true
    } finally {
        file.Close()
    }
}
