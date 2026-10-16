; ui documents subsystem. Definitions only; initialization is in bootstrap.

TerritoryMapMode_Normalize(ByRef mode, fallback := "Local") {
    mode := Trim(mode)
    if (mode != "Local" && mode != "Forum")
        mode := fallback
    return mode
}

TerritoryMapMode_ToUiLabel(mode) {
    TerritoryMapMode_Normalize(mode)
    return (mode = "Forum") ? "Официальные ссылки" : "Локальные копии"
}

TerritoryMapMode_FromUiLabel(label) {
    label := Trim(label)
    mode := (label = "Forum" || label = "Официальные ссылки") ? "Forum" : "Local"
    TerritoryMapMode_Normalize(mode)
    return mode
}

CloseAllDocs() {
    global
    TerritoryMap_CloseAll()
    Gui, 1:Destroy
    ServiceCodesGuiVisible := 0
    LawDoc_ResetAllFlags()
}

LawDoc_PageCount(prefix) {
    if IsFunc("LawCorpus_PageCount")
    {
        fn := Func("LawCorpus_PageCount")
        corpusCount := fn.Call(prefix)
        if (corpusCount > 0)
            return corpusCount
    }
    if (prefix = "vu")
        return 3
    else if (prefix = "fp")
        return 4
    else if (prefix = "kon")
        return 4
    else if (prefix = "fzop")
        return 12
    else if (prefix = "ter")
        return 7
    else if (prefix = "tk")
        return 6
    else if (prefix = "arg")
        return 4
    else if (prefix = "uk")
        return 9
    else if (prefix = "vv")
        return 5
    else if (prefix = "koap")
        return 8
    else if (prefix = "pdd")
        return 10
    else if (prefix = "oruzh")
        return 3
    else if (prefix = "upk")
        return 41
    else if (prefix = "kas")
        return 4
    else if (prefix = "fsb")
        return 3
    else if (prefix = "fsin")
        return 2
    else if (prefix = "vs")
        return 2
    else if (prefix = "sud")
        return 2
    else if (prefix = "ord")
        return 2
    else if (prefix = "gt")
        return 2
    return 0
}

LawDoc_ResetAllFlags() {
    global
    LawDocCurrentPages := {}
    docPrefixes := ["vu", "fp", "kon", "fzop", "ter", "tk", "arg", "uk", "vv", "koap", "pdd", "oruzh", "upk", "kas", "fsb", "fsin", "vs", "sud", "ord", "gt"]
    Loop % docPrefixes.Length()
    {
        docPrefix := docPrefixes[A_Index]
        ; Navigation uses LawDocCurrentPages; only the legacy first-page flag exists.
        ; Resetting a window must not load and paginate every corpus document.
        flagName := "fl" . docPrefix . "1"
        %flagName% := False
    }
}

LawDoc_Navigate(prefix, direction) {
    global LawDocCurrentPages
    count := LawDoc_PageCount(prefix)
    if (count < 1)
        return

    currentIdx := IsFunc("LawDoc_GetCurrentPage") ? LawDoc_GetCurrentPage(prefix) : 1

    if (direction = "prev")
        nextIdx := currentIdx - 1
    else
        nextIdx := currentIdx + 1

    if (nextIdx < 1)
        nextIdx := count
    if (nextIdx > count)
        nextIdx := 1

    if IsFunc("LawDoc_ShowPage")
    {
        if !LawDoc_ShowPage(prefix, nextIdx)
            return false
        ApplyPersistentAlwaysOnTop()
        return true
    }
    return false
}

NavigateVU(direction) {
    LawDoc_Navigate("vu", direction)
}

NavigateFP(direction) {
    LawDoc_Navigate("fp", direction)
}

NavigateKON(direction) {
    LawDoc_Navigate("kon", direction)
}

NavigateFZOP(direction) {
    LawDoc_Navigate("fzop", direction)
}

NavigateTER(direction) {
    LawDoc_Navigate("ter", direction)
}

NavigateTK(direction) {
    LawDoc_Navigate("tk", direction)
}

NavigateARG(direction) {
    LawDoc_Navigate("arg", direction)
}

NavigateUK(direction) {
    LawDoc_Navigate("uk", direction)
}

NavigateVV(direction) {
    LawDoc_Navigate("vv", direction)
}

NavigateKOAP(direction) {
    LawDoc_Navigate("koap", direction)
}

NavigatePDD(direction) {
    LawDoc_Navigate("pdd", direction)
}

NavigateUPK(direction) {
    LawDoc_Navigate("upk", direction)
}

NavigateORUZH(direction) {
    LawDoc_Navigate("oruzh", direction)
}

NavigateKAS(direction) {
    LawDoc_Navigate("kas", direction)
}

NavigateFSB(direction) {
    LawDoc_Navigate("fsb", direction)
}

NavigateFSIN(direction) {
    LawDoc_Navigate("fsin", direction)
}

NavigateVS(direction) {
    LawDoc_Navigate("vs", direction)
}

NavigateSUD(direction) {
    LawDoc_Navigate("sud", direction)
}

NavigateORD(direction) {
    LawDoc_Navigate("ord", direction)
}

NavigateGT(direction) {
    LawDoc_Navigate("gt", direction)
}

LawSearch_CaptureAndCancelChat(inputEpoch := 0) {
    return CaptureChatClipboard(true)
}

ServiceCodes_GetText() {
    codesText =
    (LTrim
    1-1 Построение на парковке.
    1-2 Сбор на парковке управления ФСБ.
    1-3 На связь!
    1-4 Так точно/принял!
    1-5 Отмена/отбой! 
    1-6 Построение на плацу ВЧ.

    2-1 Начал участвовать в СО/МП.
    2-2 Продолжаю участвовать в СО/МП.
    2-3 Закончил участвовать в СО/МП.

    3-1 Выехали на вызов о срочной помощи "SOS".
    3-2 Прибыли на вызов срочной помощи "SOS".

    4-1 Выехали на вызов об ограблении дома/особняка.
    4-2 Прибыли на вызов об ограблении дома/особняка.
    4-3 Отработали вызов об ограблении дома/особняка.

    5-1 Выехали на вызов от гражданского.
    5-2 Прибыли на вызов от гражданского.
    5-3 Отработали вызов от гражданского.

    6-1 Начал патрулировать.
    6-2 Продолжаю патрулировать.
    6-3 Закончил патрулировать.

    7-1 Начал стоять на посту.
    7-2 Продолжаю стоять на посту.
    7-3 Закончил стоять на посту.
     
    8-1 Начал сопровождение ВК
    8-2 Закончил сопровождение ВК

    9-1 Начал выполнять служебную деятельность 
    9-2 Продолжаю выполнять служебную деятельность 
    9-3 Закончил выполнять служебную деятельность.
    )
    return codesText
}

ServiceCodes_Show() {
    global ServiceCodesGuiVisible, current_doc, last_doc
    if (ServiceCodesGuiVisible) {
        LawGui_Close()
        return false
    }

    if (current_doc) {
        last_doc := current_doc
        current_doc := 0
    }
    CloseAllDocs()
    LawGui_Show(1, "Служебные коды", ServiceCodes_GetText(), 1)
    ApplyPersistentAlwaysOnTop()
    ServiceCodesGuiVisible := 1
    return true
}

ToggleLawDoc(docId, firstFlagVar, showFuncName) {
    global current_doc, last_doc
    prefix := LawDoc_PrefixById(docId)
    if (prefix = "")
    {
        LogError("ToggleLawDoc", "Неизвестный документ: " . docId)
        return false
    }
    if (current_doc != docId)
    {
        CloseAllDocs()
        current_doc := docId
        last_doc := docId
        if !IsFunc("LawDoc_ShowPage") || !LawDoc_ShowPage(prefix, 1)
        {
            LogError("ToggleLawDoc", "Не удалось открыть официальный corpus: " . prefix)
            current_doc := 0
            return false
        }
        ApplyPersistentAlwaysOnTop()
    }
    else
    {
        last_doc := docId
        CloseAllDocs()
        current_doc := 0
    }
    return true
}

LawDoc_PrefixById(docId) {
    static prefixes := ["vu", "fp", "kon", "fzop", "ter", "tk", "arg", "uk", "vv", "koap"
        , "pdd", "oruzh", "upk", "kas", "fsb", "fsin", "vs", "sud", "ord", "gt"]
    docId += 0
    if (docId < 1 || docId > prefixes.Length())
        return ""
    return prefixes[docId]
}

ToggleLawDocFromChat(docId, firstFlagVar, showFuncName) {
    global current_doc
    wasCurrentDoc := current_doc
    ToggleLawDoc(docId, firstFlagVar, showFuncName)
    if (wasCurrentDoc != docId && current_doc = docId)
        Helper_CloseChatAfterGui()
}
