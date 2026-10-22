; bindings subsystem. Definitions only; initialization is in bootstrap.

NormalizeTextTrigger(ByRef val) {
    val := Trim(val)
    if (val = "ERROR")
        val := ""
    if (val != "" && SubStr(val, 1, 1) != "!")
        val := "!" . val
}

GetDefaultBindListItems() {
    return "OpenBindsTab`nAutoPatrol`nAutoPost`nConfirmID`nRejectID`nIntro`nSOS`nEnterID`nResetID`nChase`nChaseNoID`nDeject`nCuff`nInCar`nStopChase`nDoc`nSearch`nPersonalFile`nSu`nVehicleLookup`nWantedRemoval`nCivilCallStart`nCivilCallArrive`nMaskCall`nRecordCheck`nTrainCrash`nGpsD`nGpsOS`nVU`nFP`nKON`nFZOP`nTER`nTK`nARG`nUK`nVV`nKOAP`nPDD`nORUZH`nUPK`nKAS`nFSB`nFSIN`nVS`nSUD`nORD`nGT"
}

NormalizeBindListToken(item) {
    item := Trim(item)
    if (item = "")
        return ""

    compact := RegExReplace(item, "[\s_\-]+")
    StringLower, compact, compact

    if (compact = "opensettings" or compact = "settings" or compact = "menu")
        return "OpenSettings"
    if (compact = "togglebindlist" or compact = "bindlist" or compact = "showbindlist")
        return "ToggleBindList"
    if (compact = "togglelastlawdoc" or compact = "lastlawdoc" or compact = "lastdoc" or compact = "lawlast")
        return "ToggleLastLawDoc"
    if (compact = "togglehud" or compact = "hud")
        return "ToggleHUD"
    if (compact = "intro")
        return "Intro"
    if (compact = "sos")
        return "SOS"
    if (compact = "enterid")
        return "EnterID"
    if (compact = "resetid")
        return "ResetID"
    if (compact = "confirmid" or compact = "acceptid")
        return "ConfirmID"
    if (compact = "rejectid" or compact = "declineid")
        return "RejectID"
    if (compact = "capturetargetid" or compact = "targetid")
        return ""
    if (compact = "openbindstab" or compact = "bindsettings")
        return "OpenBindsTab"
    if (compact = "chase")
        return "Chase"
    if (compact = "deject")
        return "Deject"
    if (compact = "cuff")
        return "Cuff"
    if (compact = "incar")
        return "InCar"
    if (compact = "stopchase")
        return "StopChase"
    if (compact = "doc")
        return "Doc"
    if (compact = "search")
        return "Search"
    if (compact = "maskcall")
        return "MaskCall"
    if (compact = "recordcheck")
        return "RecordCheck"
    if (compact = "traincrash")
        return "TrainCrash"
    if (compact = "personalfile")
        return "PersonalFile"
    if (compact = "su")
        return "Su"
    if (compact = "gpsd" or compact = "д")
        return "GpsD"
    if (compact = "gpsos" or compact = "ос")
        return "GpsOS"
    if (compact = "dep")
        return "Dep"
    if (compact = "sosstart")
        return "SOSStart"
    if (compact = "sosarrive")
        return "SOSArrive"
    if (compact = "hijackstart")
        return "HijackStart"
    if (compact = "hijackarrive")
        return "HijackArrive"
    if (compact = "callstart")
        return "CallStart"
    if (compact = "callarrive")
        return "CallArrive"
    if (compact = "patrolstart")
        return "PatrolStart"
    if (compact = "patrolcont" or compact = "patrolcontinue")
        return "PatrolCont"
    if (compact = "patrolend")
        return "PatrolEnd"
    if (compact = "poststart")
        return "PostStart"
    if (compact = "postcont" or compact = "postcontinue")
        return "PostCont"
    if (compact = "postend")
        return "PostEnd"
    if (compact = "convoystart")
        return "ConvoyStart"
    if (compact = "convoyend")
        return "ConvoyEnd"
    if (compact = "towstart")
        return "TowStart"
    if (compact = "towend")
        return "TowEnd"
    if (compact = "carsearch")
        return "CarSearch"
    if (compact = "arrest")
        return "Arrest"
    if (compact = "fine")
        return "Fine"
    if (compact = "protocol")
        return "Protocol"
    if (compact = "guiderights" or compact = "rightsgui")
        return "GuideRights"
    if (compact = "rights")
        return "Rights"
    if (compact = "cardds")
        return "CardDS"
    if (compact = "cardvk")
        return "CardVK"
    if (compact = "vu" or compact = "ву")
        return "VU"
    if (compact = "fp" or compact = "фп")
        return "FP"
    if (compact = "kon" or compact = "кон")
        return "KON"
    if (compact = "fzop" or compact = "фзоп")
        return "FZOP"
    if (compact = "ter" or compact = "тер")
        return "TER"
    if (compact = "tk" or compact = "тк")
        return "TK"
    if (compact = "arg" or compact = "арг")
        return "ARG"
    if (compact = "uk" or compact = "ук")
        return "UK"
    if (compact = "vv" or compact = "вв")
        return "VV"
    if (compact = "koap" or compact = "коап")
        return "KOAP"
    if (compact = "pdd" or compact = "пдд")
        return "PDD"
    if (compact = "oruzh" or compact = "оруж")
        return "ORUZH"
    if (compact = "upk" or compact = "упк")
        return "UPK"
    if (compact = "kas" or compact = "кас")
        return "KAS"
    if (compact = "fsb" or compact = "фсб")
        return "FSB"
    if (compact = "fsin" or compact = "фсин")
        return "FSIN"
    if (compact = "vs" or compact = "фзовс" or compact = "военнаяслужба")
        return "VS"
    if (compact = "sud" or compact = "суд")
        return "SUD"
    if (compact = "ord" or compact = "орд")
        return "ORD"
    if (compact = "gt" or compact = "гт" or compact = "гостайна")
        return "GT"
    return item
}

NormalizeBindListItemsValue(ByRef val) {
    val := StrReplace(val, "|", "`n")
    val := StrReplace(val, ",", "`n")
    val := RegExReplace(val, "(`r`n|`r)", "`n")
    val := RegExReplace(val, "`n{2,}", "`n")

    clean := ""
    Loop, Parse, val, `n, `r
    {
        item := NormalizeBindListToken(A_LoopField)
        if (item = "")
            continue
        if (clean != "")
            clean .= "`n"
        clean .= item
    }

    if (clean = "")
        clean := GetDefaultBindListItems()

    val := clean
}

NormalizeHotkeyValue(ByRef val) {
    val := Trim(val)
    if (val = "ERROR")
        val := ""
}

GetCfgHotkeyOrder() {
    static order := ""
    if IsObject(order)
        return order

    order := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            order.Push("CFG_" . meta.HotkeyVar)
    }
    return order
}

GetCfgHotkeyMetaMap() {
    static metaMap := ""
    if IsObject(metaMap)
        return metaMap

    metaMap := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            metaMap["CFG_" . meta.HotkeyVar] := {Label: meta.Label, Token: meta.Token, BindVar: meta.HotkeyVar}
    }
    return metaMap
}

BuildHotkeyConflictStatus(changes) {
    msg := "Конфликты hotkey: "
    Loop % changes.Length()
    {
        item := changes[A_Index]
        if (A_Index > 1)
            msg .= " | "
        msg .= item.Hotkey . ": " . item.LoserLabel . " -> снят, оставлен " . item.WinnerLabel
    }
    return msg
}

ResolveCfgHotkeyConflicts(changedVar := "", showTip := 1) {
    global

    order := GetCfgHotkeyOrder()
    metaMap := GetCfgHotkeyMetaMap()
    used := {}
    changes := []

    if (changedVar != "")
    {
        currentValue := GetDynamicGlobalValue(changedVar)
        NormalizeHotkeyValue(currentValue)
        SetDynamicGlobalValue(changedVar, currentValue)
        if (currentValue != "")
        {
            keyId := currentValue
            StringLower, keyId, keyId
            used[keyId] := changedVar
        }
    }

    Loop % order.Length()
    {
        varName := order[A_Index]
        curValue := GetDynamicGlobalValue(varName)
        NormalizeHotkeyValue(curValue)
        SetDynamicGlobalValue(varName, curValue)

        if (varName = changedVar && changedVar != "")
            continue
        if (curValue = "")
            continue

        keyId := curValue
        StringLower, keyId, keyId

        if (used.HasKey(keyId))
        {
            winnerVar := used[keyId]
            winnerLabel := metaMap.HasKey(winnerVar) ? metaMap[winnerVar].Label : winnerVar
            loserLabel := metaMap.HasKey(varName) ? metaMap[varName].Label : varName
            blank := ""
            SetDynamicGlobalValue(varName, "")
            GuiControl, 2:, %varName%, %blank%
            changes.Push({Hotkey: curValue, WinnerLabel: winnerLabel, LoserLabel: loserLabel})
            continue
        }

        used[keyId] := varName
    }

    if (changes.Length() > 0)
    {
        statusText := BuildHotkeyConflictStatus(changes)
        SetSettingsBindsStatus(statusText)
        if (showTip)
        {
            ServiceUI_Notify(statusText, 1800)
        }
    }
    else
    {
        SetSettingsBindsStatus("Конфликтов hotkey нет. Последний выбранный hotkey имеет приоритет.")
    }
}

ResetRegisteredGameTextHotstrings() {
    global RegisteredGameTextHotstrings, GameTextHotkeyContext
    Hotkey, If, % GameTextHotkeyContext
    if IsObject(RegisteredGameTextHotstrings)
    {
        Loop % RegisteredGameTextHotstrings.Length()
        {
            pattern := RegisteredGameTextHotstrings[A_Index]
            if (pattern != "")
            {
                try
                    Hotstring(pattern, "", "Off")
            }
        }
    }
    RegisteredGameTextHotstrings := []
    Hotkey, If
}

TrackRegisteredGameTextHotstring(pattern) {
    global RegisteredGameTextHotstrings
    if (pattern = "")
        return
    if !IsObject(RegisteredGameTextHotstrings)
        RegisteredGameTextHotstrings := []
    RegisteredGameTextHotstrings.Push(pattern)
}

SuspendGameTextTriggersForBindMenu() {
    global RegisteredGameTextHotstrings, BindMenuTextTriggersSuspended, GameTextHotkeyContext
    if !IsObject(RegisteredGameTextHotstrings)
        return

    Hotkey, If, % GameTextHotkeyContext
    Loop % RegisteredGameTextHotstrings.Length()
    {
        pattern := RegisteredGameTextHotstrings[A_Index]
        ; Keep the two reserved close-menu commands available while editing.
        if (pattern = ":?:!меню" || pattern = ":?:!menu")
            continue
        if (pattern != "")
        {
            try
                Hotstring(pattern, "", "Off")
        }
    }
    Hotkey, If
    BindMenuTextTriggersSuspended := true
}

ResumeGameTextTriggersAfterBindMenu() {
    global BindMenuTextTriggersSuspended
    if (!BindMenuTextTriggersSuspended)
        return

    BindMenuTextTriggersSuspended := false
    ok := 1
    errText := ""
    ApplyTextTriggers(ok, errText)
}

GameTextTriggerAllowed(hotkeyName := "") {
    global GAME_PROCESS_NAME, PhysicalInputBusy, IDCaptureState, TextTriggerInputMode
    if (TextTriggerInputMode = "Окно AHK")
        return false
    ; Explicit TXT commands are recognized on Space in the foreground game.
    ; Never discover modules/read memory in this synchronous keyboard-hook predicate:
    ; an unavailable or slow chat read otherwise prevents Hotstring recognition.
    ; The invoked action and its transport retain their own chat/focus checks.
    if (GAME_PROCESS_NAME = "" || PhysicalInputBusy || IsObject(IDCaptureState))
        return false
    return WinActive("ahk_exe " . GAME_PROCESS_NAME) ? true : false
}

RegisterTextTrigger(triggerName, ByRef prevTrig, currentTrig, callbackName, ByRef errText, ByRef usedTriggers) {
    currentTrig := Trim(currentTrig)

    if (currentTrig = "ERROR")
        currentTrig := ""

    if (currentTrig != "" && SubStr(currentTrig, 1, 1) != "!")
        currentTrig := "!" . currentTrig

    if (prevTrig != "")
    {
        try
            Hotstring(":?:" . prevTrig, "", "Off")
    }

    if (currentTrig = "")
    {
        prevTrig := ""
        return true
    }

    keyId := currentTrig
    StringLower, keyId, keyId

    if (usedTriggers.HasKey(keyId))
    {
        errText .= triggerName . " = " . currentTrig . "  -> дубликат с """ . usedTriggers[keyId] . """`n"
        prevTrig := ""
        return false
    }

    try
    {
        cb := Func("RunTriggerLabel").Bind(callbackName)
        Hotstring(":?:" . currentTrig, cb, "On")
        TrackRegisteredGameTextHotstring(":?:" . currentTrig)
    }
    catch e
    {
        errText .= triggerName . " = " . currentTrig . "  -> неверный или неподдерживаемый текстовый бинд`n"
        prevTrig := ""
        return false
    }

    usedTriggers[keyId] := triggerName
    prevTrig := currentTrig
    return true
}

RegisterSearchModeTrigger(triggerName, ByRef prevTrig, triggerText, docCode, docName, ByRef errText, ByRef usedTriggers) {
    triggerText := Trim(triggerText)
    if (triggerText = "")
        return true
    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText

    if (prevTrig != "")
    {
        try
            Hotstring(":?:" . prevTrig, "", "Off")
    }

    keyId := triggerText
    StringLower, keyId, keyId
    if (usedTriggers.HasKey(keyId))
    {
        errText .= triggerName . " = " . triggerText . "  -> дубликат с " . usedTriggers[keyId] . "`n"
        prevTrig := ""
        return false
    }

    try
    {
        cb := Func("RunSearchModeTrigger").Bind(docCode, docName)
        Hotstring(":?:" . triggerText, cb, "On")
        TrackRegisteredGameTextHotstring(":?:" . triggerText)
    }
    catch e
    {
        errText .= triggerName . " = " . triggerText . "  -> неверная команда поиска`n"
        prevTrig := ""
        return false
    }

    usedTriggers[keyId] := triggerName
    prevTrig := triggerText
    return true
}

RegisterGpsInputTextTrigger(triggerName, ByRef prevTrig, currentTrig, actionName, downCount, ByRef errText, ByRef usedTriggers) {
    currentTrig := Trim(currentTrig)
    if (currentTrig = "ERROR")
        currentTrig := ""
    if (currentTrig != "" && SubStr(currentTrig, 1, 1) != "!")
        currentTrig := "!" . currentTrig
    patterns := [], needed := 0
    if (currentTrig != "") {
        Loop, 10 {
            fullTrig := currentTrig . (A_Index - 1)
            keyId := fullTrig
            StringLower, keyId, keyId
            if (usedTriggers.HasKey(keyId)) {
                errText .= triggerName . " = " . fullTrig . " -> duplicate trigger`n"
                return false
            }
            pattern := ":?*B0:" . fullTrig
            patterns.Push(pattern)
            if !HistoricalHotstrings.HasKey(pattern)
                needed++
        }
        if (HistoricalHotstringCount + needed > 512) {
            errText .= "Достигнут предел GPS-триггеров за сеанс (512). Перезапустите приложение для новых префиксов.`n"
            return false
        }
    }
    registered := [], previous := A_IsCritical
    Critical, On
    try {
        for index, pattern in patterns {
            digit := index - 1
            cb := Func("RunGpsInputTrigger").Bind(currentTrig, actionName, downCount, "" . digit)
            Hotstring(pattern, cb, "On")
            Hotstring_AdmitPattern(pattern)
            registered.Push(pattern)
        }
        if (prevTrig != "" && prevTrig != currentTrig) {
            Loop, 10 {
                try
                    Hotstring(":?*B0:" . prevTrig . (A_Index - 1), "", "Off")
            }
        }
        for index, pattern in registered {
            fullTrig := currentTrig . (index - 1)
            StringLower, fullTrig, fullTrig
            usedTriggers[fullTrig] := triggerName
            TrackRegisteredGameTextHotstring(pattern)
        }
        prevTrig := currentTrig
        return true
    } catch registerError {
        for _, pattern in registered {
            try
                Hotstring(pattern, "", "Off")
        }
        errText .= triggerName . " = " . currentTrig . " -> cannot register GPS trigger: " . registerError.Message . "`n"
        return false
    } finally {
        Critical, %previous%
    }
}

NormalizeBindMenuHotkeyText(rawText) {
    rawText := Trim(rawText)
    if (rawText = "")
        return ""

    lowered := rawText
    StringLower, lowered, lowered
    lowered := RegExReplace(lowered, "\s+")

    if (lowered = "off" || lowered = "none" || lowered = "clear" || lowered = "пусто" || lowered = "нет" || lowered = "-")
        return ""

    if RegExMatch(rawText, "^[!^+#].+")
        return rawText

    parts := StrSplit(lowered, "+")
    mods := ""
    key := ""
    Loop % parts.Length()
    {
        part := parts[A_Index]
        if (part = "alt")
            mods .= "!"
        else if (part = "ctrl" || part = "control")
            mods .= "^"
        else if (part = "shift")
            mods .= "+"
        else if (part = "win" || part = "windows")
            mods .= "#"
        else
            key := part
    }

    if (key = "")
        return rawText

    if RegExMatch(key, "^f\d+$")
        StringUpper, key, key
    return mods . key
}

NormalizeBindMenuAliasText(aliasText) {
    aliasText := Trim(aliasText)
    if (aliasText = "")
        return ""
    StringLower, aliasText, aliasText
    aliasText := RegExReplace(aliasText, "\s+")
    if (SubStr(aliasText, 1, 1) != "!")
        aliasText := "!" . aliasText
    return aliasText
}

NormalizeBindMenuFixedName(name) {
    name := Trim(name)
    if (SubStr(name, 1, 1) = "!")
        name := SubStr(name, 2)
    StringLower, name, name
    name := RegExReplace(name, "\s+")
    return name
}

GetBindMenuFixedName(meta) {
    static fixedNameMap := ""
    if !IsObject(meta)
        return ""

    if !IsObject(fixedNameMap)
    {
        fixedNameMap := {}
        fixedNameMap["OpenSettings"] := "settings"
        fixedNameMap["ToggleBindList"] := "bindlist"
        fixedNameMap["ToggleLastLawDoc"] := "lastdoc"
        fixedNameMap["HideLawGui"] := "hidelaw"
        fixedNameMap["ToggleHUD"] := "hud"
        fixedNameMap["IDOverlay"] := "idoverlay"
        fixedNameMap["EnterID"] := "id"
        fixedNameMap["ResetID"] := "resetid"
        fixedNameMap["Intro"] := "intro"
        fixedNameMap["SOS"] := "sos"
        fixedNameMap["Chase"] := "chase"
        fixedNameMap["Deject"] := "deject"
        fixedNameMap["Cuff"] := "cuff"
        fixedNameMap["InCar"] := "incar"
        fixedNameMap["StopChase"] := "stop"
        fixedNameMap["Doc"] := "doc"
        fixedNameMap["Search"] := "search"
        fixedNameMap["Dep"] := "dep"
        fixedNameMap["WantedList"] := "wanted"
        fixedNameMap["SOSStart"] := "sosstart"
        fixedNameMap["SOSArrive"] := "sosarrive"
        fixedNameMap["HijackStart"] := "hijackstart"
        fixedNameMap["HijackArrive"] := "hijackarrive"
        fixedNameMap["CallStart"] := "callstart"
        fixedNameMap["CallArrive"] := "callarrive"
        fixedNameMap["CallWorkStart"] := "callworkstart"
        fixedNameMap["CallWorkEnd"] := "callworkend"
        fixedNameMap["PatrolStart"] := "patrolstart"
        fixedNameMap["PatrolCont"] := "patrolcont"
        fixedNameMap["PatrolEnd"] := "patrolend"
        fixedNameMap["PostStart"] := "poststart"
        fixedNameMap["PostCont"] := "postcont"
        fixedNameMap["PostEnd"] := "postend"
        fixedNameMap["AutoPatrol"] := "апатруль"
        fixedNameMap["AutoPost"] := "апост"
        fixedNameMap["ConvoyStart"] := "convoystart"
        fixedNameMap["ConvoyCont"] := "convoycont"
        fixedNameMap["ConvoyEnd"] := "convoyend"
        fixedNameMap["TowStart"] := "towstart"
        fixedNameMap["TowEnd"] := "towend"
        fixedNameMap["CarSearch"] := "carsearch"
        fixedNameMap["Arrest"] := "arrest"
        fixedNameMap["Fine"] := "fine"
        fixedNameMap["Protocol"] := "protocol"
        fixedNameMap["Rights"] := "rights"
        fixedNameMap["CardDS"] := "cardds"
        fixedNameMap["CardVK"] := "cardvk"
    }

    if (fixedNameMap.HasKey(meta.Token))
        return fixedNameMap[meta.Token]

    name := meta.Token
    StringLower, name, name
    return RegExReplace(name, "[^a-z0-9_]")
}

GetBindMenuMetaByFixedName(fixedName) {
    fixedName := NormalizeBindMenuFixedName(fixedName)
    if (fixedName = "")
        return ""

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar = "" && meta.TriggerVar = "")
            continue
        if (NormalizeBindMenuFixedName(GetBindMenuFixedName(meta)) = fixedName)
            return meta

        aliases := BuildBindMenuAliasList(meta)
        Loop % aliases.Length()
        {
            aliasName := NormalizeBindMenuFixedName(aliases[A_Index])
            if (aliasName != "" && aliasName = fixedName)
                return meta
        }
    }
    return ""
}

GetActiveTextTriggerSet() {
    used := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.TriggerVar = "")
            continue
        triggerValue := NormalizeBindMenuAliasText(GetDynamicGlobalValue(meta.TriggerVar))
        if (triggerValue != "")
            used[triggerValue] := meta.TriggerVar
    }
    for fixedTrigger, owner in GetReservedTextTriggerSet()
        used[fixedTrigger] := owner
    global CustomFunctions
    if IsObject(CustomFunctions)
    {
        Loop % CustomFunctions.Length()
        {
            fn := CustomFunctions[A_Index]
            trig := NormalizeCustomFunctionTrigger(fn.Trigger)
            if (trig != "")
                used[trig] := "Пользовательская функция: " . fn.Name
        }
    }
    return used
}

GetBindMenuTriggerOwnerLabel(owner) {
    if (owner = "")
        return ""

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        other := catalog[A_Index]
        if (other.TriggerVar = owner)
        {
            if (other.Label != "")
                return other.Label
            return other.Token
        }
    }

    static ownerLabels := ""
    if !IsObject(ownerLabels)
    {
        ownerLabels := {}
        ownerLabels["BindMenu"] := "Меню биндов"
        ownerLabels["VehicleLookup"] := "Поиск ТС по номеру"
        ownerLabels["WantedRemoval"] := "Снятие розыска"
        ownerLabels["Search_ALL"] := "Поиск: все материалы"
        ownerLabels["Search_KOAP"] := "Поиск: КоАП"
        ownerLabels["Search_UK"] := "Поиск: УК"
        ownerLabels["Search_UPK"] := "Поиск: УПК"
        ownerLabels["Search_PDD"] := "Поиск: ПДД"
        ownerLabels["Search_FZOP"] := "Поиск: ФЗОП"
        ownerLabels["Search_TK"] := "Поиск: ТК"
        ownerLabels["Search_TER"] := "Поиск: Территории"
        ownerLabels["Search_ARG"] := "Поиск: АРГ"
        ownerLabels["Search_VU"] := "Поиск: ВУ"
        ownerLabels["Search_VV"] := "Поиск: Вертикаль власти"
        ownerLabels["Search_ORUZH"] := "Поиск: Оружие"
        ownerLabels["Search_KON"] := "Поиск: Конституция"
        ownerLabels["Search_RUN"] := "Поиск по законам"
    }

    if (ownerLabels.HasKey(owner))
        return ownerLabels[owner]
    return owner
}

GetBindMenuDisplayCommand(meta) {
    if !IsObject(meta)
        return "-"
    if (meta.HotkeyVar = "" && meta.TriggerVar = "")
        return "-"

    fixedName := GetBindMenuFixedName(meta)
    if (fixedName = "")
        return "-"
    return "!" . fixedName
}

ValidateBindMenuHotkey(meta, hotkeyText, oldHotkey, ByRef errMsg) {
    errMsg := ""
    if (hotkeyText = "")
        return true

    newKeyId := NormalizeHotkeyId(hotkeyText)
    if (newKeyId = "")
    {
        errMsg := "Некорректный hotkey: " . hotkeyText
        return false
    }

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        other := catalog[A_Index]
        if !BindCatalog_IsRegistrable(other)
            continue
        if (other.HotkeyVar = "" || other.HotkeyVar = meta.HotkeyVar)
            continue
        otherValue := GetDynamicGlobalValue(other.HotkeyVar)
        NormalizeBindValue(otherValue)
        otherKeyId := NormalizeHotkeyId(otherValue)
        if (otherKeyId != "" && otherKeyId = newKeyId)
        {
            ownerLabel := other.Label
            if (ownerLabel = "")
                ownerLabel := other.Token
            errMsg := "Hotkey уже занят: " . hotkeyText . " -> " . ownerLabel
            return false
        }
    }
    return true
}

NormalizeBindMenuTriggerText(rawText) {
    triggerText := Trim(rawText)
    if (triggerText = "")
        return ""
    triggerText := RegExReplace(triggerText, "\s+")
    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText
    return triggerText
}

ValidateBindMenuTrigger(meta, triggerText, ByRef errMsg) {
    errMsg := ""
    if (triggerText = "")
    {
        errMsg := "Некорректный TXT-trigger: " . triggerText
        return false
    }

    checkText := triggerText
    StringLower, checkText, checkText
    if (checkText = "!меню" || checkText = "!menu")
    {
        errMsg := "TXT-trigger зарезервирован: " . triggerText
        return false
    }

    used := GetActiveTextTriggerSet()
    if (used.HasKey(checkText) && used[checkText] != meta.TriggerVar)
    {
        owner := used[checkText]
        ownerLabel := GetBindMenuTriggerOwnerLabel(owner)
        if (ownerLabel = "")
            ownerLabel := owner
        errMsg := "Триггер уже занят: " . triggerText . " -> " . ownerLabel
        return false
    }
    return true
}

ApplyBindMenuTrigger(meta, triggerText) {
    global CurrentProfile, SettingsVisible, BindListVisible, BindOverlayVisible, BindMenuVisible
    if (meta.TriggerVar = "")
        return BindMenuWarn("Для этой команды нет TXT-триггера.")

    triggerText := NormalizeBindMenuTriggerText(triggerText)
    errMsg := ""
    if !ValidateBindMenuTrigger(meta, triggerText, errMsg)
    {
        if (errMsg = "")
            errMsg := "Некорректный TXT-trigger: " . triggerText
        return BindMenuWarn(errMsg)
    }

    SetDynamicGlobalValue(meta.TriggerVar, triggerText)
    cfgVar := "CFG_" . meta.TriggerVar
    SetDynamicGlobalValue(cfgVar, triggerText)
    if (SettingsVisible)
        GuiControl, 2:, %cfgVar%, %triggerText%

    ApplyAllBinds()
    if !SaveProfile(CurrentProfile)
        return
    SaveUISettings()
    if (BindListVisible)
        UpdateBindList()
    if (BindOverlayVisible)
        ShowBindOverlay()
    if (BindMenuVisible)
        ShowChatBindMenu()

    Notify("info")
    ServiceUI_Notify("TXT updated: " . meta.Label . " = " . triggerText, 1600)
    return true
}

GetBindMenuCommandMode(ByRef argText) {
    rawText := Trim(argText)
    lowered := rawText
    StringLower, lowered, lowered

    if RegExMatch(lowered, "^(hk|hotkey|bind)\s+(.+)$", m)
    {
        argText := Trim(m2)
        return "HK"
    }
    if RegExMatch(lowered, "^(txt|text|trig|trigger)\s+(.+)$", m)
    {
        argText := Trim(m2)
        return "TRIG"
    }

    argText := rawText
    if (SubStr(rawText, 1, 1) = "!")
        return "TRIG"
    return "HK"
}

ApplyBindMenuHotkey(meta, hotkeyText) {
    global CurrentProfile, SettingsVisible, BindListVisible, BindOverlayVisible, BindMenuVisible
    oldHotkey := GetDynamicGlobalValue(meta.HotkeyVar)
    errMsg := ""
    if !ValidateBindMenuHotkey(meta, hotkeyText, oldHotkey, errMsg)
    {
        if (errMsg = "")
            errMsg := "Некорректный hotkey: " . hotkeyText
        return BindMenuWarn(errMsg)
    }

    SetDynamicGlobalValue(meta.HotkeyVar, hotkeyText)
    cfgVar := "CFG_" . meta.HotkeyVar
    SetDynamicGlobalValue(cfgVar, hotkeyText)
    if (SettingsVisible)
        GuiControl, 2:, %cfgVar%, %hotkeyText%

    ApplyAllBinds()
    if !SaveProfile(CurrentProfile)
        return
    SaveUISettings()
    if (BindListVisible)
        UpdateBindList()
    if (BindOverlayVisible)
        ShowBindOverlay()
    if (BindMenuVisible)
    {
        SuspendGameTextTriggersForBindMenu()
        ShowChatBindMenu()
    }

    Notify("info")
    ServiceUI_Notify("Бинд обновлен: " . meta.Label . " = " . hotkeyText, 1600)
    return true
}

TryHandleBindMenuLine(lineText) {
    global BindMenuEditMode
    if (!BindMenuEditMode)
        return false

    normalized := Trim(lineText)
    if (normalized = "")
        return false
    lineText := normalized

    lowered := normalized
    StringLower, lowered, lowered
    if (lowered = "!меню" || lowered = "!menu")
    {
        ClearBindMenuChatLine()
        ForceCloseBindMenuEditMode("Меню биндов закрыто.")
        return true
    }

    firstChar := SubStr(lineText, 1, 1)
    if (firstChar != "!")
        return false

    splitAt := RegExMatch(lineText, "\s")
    if (splitAt > 0)
    {
        firstWord := SubStr(lineText, 1, splitAt - 1)
        commandArg := Trim(SubStr(lineText, splitAt + 1))
    }
    else
    {
        firstWord := lineText
        commandArg := ""
    }

    fixedName := NormalizeBindMenuFixedName(firstWord)
    meta := GetBindMenuMetaByFixedName(fixedName)
    if !IsObject(meta)
    {
        ClearBindMenuChatLine()
        BindMenuWarn("Command not found. Use a name from !menu.")
        return true
    }

    if (commandArg = "")
    {
        ClearBindMenuChatLine()
        BindMenuWarn("Use bind or TXT: !" . GetBindMenuFixedName(meta) . " alt+r")
        return true
    }

    commandMode := GetBindMenuCommandMode(commandArg)
    ClearBindMenuChatLine()
    if (commandMode = "TRIG")
        ApplyBindMenuTrigger(meta, commandArg)
    else
    {
        hotkeyText := NormalizeBindMenuHotkeyText(commandArg)
        if (meta.HotkeyVar = "")
            BindMenuWarn("No HK bind for this command.")
        else
            ApplyBindMenuHotkey(meta, hotkeyText)
    }
    return true
}

RunSearchModeTrigger(docCode, docName) {
    global BindMenuEditMode
    if (BindMenuEditMode)
    {
        BindMenuWarn()
        return ""
    }
    LawSearch_ModeHotstring(docCode, docName)
    return ""
}

RunTriggerLabel(labelName) {
    global BindMenuEditMode
    if (BindMenuEditMode)
    {
        if (labelName = "DoBindMenuToggle")
        {
            ToggleBindMenuEditMode()
            return ""
        }
        BindMenuWarn()
        return ""
    }
    SetTimer, %labelName%, -1
    return ""
}

ApplyTextTriggers(ByRef ok, ByRef errText) {
    global
    Hotkey, If, % GameTextHotkeyContext
    ResetRegisteredGameTextHotstrings()
    Hotkey, If, % GameTextHotkeyContext
    usedTriggers := {}
    for _, trigger in TextCommands_OpenerTriggers()
        usedTriggers[trigger] := "Открыть окно TXT"
    PrivateText_RegisterOpener()

    if !RegisterTextTrigger("BindMenu", Prev_Trig_BindMenu, "!меню", "DoBindMenuToggle", errText, usedTriggers)
        ok := 0
    previousMenuEnglish := ""
    if !RegisterTextTrigger("BindMenuEN", previousMenuEnglish, "!menu", "DoBindMenuToggle", errText, usedTriggers)
        ok := 0
    if !RegisterTextTrigger("Codes", Prev_Trig_Codes, "!коды", "DoServiceCodesGui", errText, usedTriggers)
        ok := 0
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta) || meta.TriggerVar = ""
            continue
        callbackName := GetBoundLabelByToken(meta.Token)
        if (callbackName = "")
            continue
        previousTrigger := ""
        currentTrigger := GetDynamicGlobalValue(meta.TriggerVar)
        if !RegisterTextTrigger(meta.TriggerVar, previousTrigger, currentTrigger, callbackName, errText, usedTriggers)
            ok := 0
    }
    if !RegisterGpsInputTextTrigger("Trig_GpsD", Prev_Trig_GpsD, Trig_GpsD, "GPS Д", 15, errText, usedTriggers)
        ok := 0
    if !RegisterGpsInputTextTrigger("Trig_GpsOS", Prev_Trig_GpsOS, Trig_GpsOS, "GPS ОС", 16, errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ALL", Prev_SearchTrig_ALL, "!пвсе", "ALL", "всем материалам", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KOAP", Prev_SearchTrig_KOAP, "!пкоап", "KOAP", "КоАП", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_UK", Prev_SearchTrig_UK, "!пук", "UK", "УК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_UPK", Prev_SearchTrig_UPK, "!пупк", "UPK", "УПК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KAS", Prev_SearchTrig_KAS, "!пкас", "KAS", "КАС", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FSB", Prev_SearchTrig_FSB, "!пфсб", "FSB", "ФЗ о ФСБ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FSIN", Prev_SearchTrig_FSIN, "!пфсин", "FSIN", "ФЗ о ФСИН", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VS", Prev_SearchTrig_VS, "!пвс", "VS", "Военная служба", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_SUD", Prev_SearchTrig_SUD, "!псуд", "SUD", "Судебная система", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ORD", Prev_SearchTrig_ORD, "!порд", "ORD", "ОРД", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_GT", Prev_SearchTrig_GT, "!пгт", "GT", "Государственная тайна", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_PDD", Prev_SearchTrig_PDD, "!ппдд", "PDD", "ПДД", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FZOP", Prev_SearchTrig_FZOP, "!пфзоп", "FZOP", "ФЗ О полиции", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_TK", Prev_SearchTrig_TK, "!птк", "TK", "ТК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_TER", Prev_SearchTrig_TER, "!птер", "TER", "Территории", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ARG", Prev_SearchTrig_ARG, "!парг", "ARG", "АРГ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VU", Prev_SearchTrig_VU, "!пву", "VU", "ВУ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VV", Prev_SearchTrig_VV, "!пвв", "VV", "Вертикаль власти", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ORUZH", Prev_SearchTrig_ORUZH, "!поружие", "ORUZH", "Оружие", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KON", Prev_SearchTrig_KON, "!пкон", "KON", "Конституция", errText, usedTriggers)
        ok := 0
    if !RegisterTextTrigger("Search_RUN", Prev_SearchTrig_RUN, "!пнайти", "DoLawSearchClipboard", errText, usedTriggers)
        ok := 0
    ApplyCustomFunctionTextTriggers(ok, errText, usedTriggers)
    TextCommands_RegisterAliases(ok, errText, usedTriggers)
    if (BindMenuEditMode)
        SuspendGameTextTriggersForBindMenu()
    Hotkey, If
}

NormalizeHotkeyId(hotkeyName) {
    hotkeyName := Trim(hotkeyName)
    if (hotkeyName = "" || hotkeyName = "ERROR")
        return ""
    keyId := hotkeyName
    StringLower, keyId, keyId
    return keyId
}

NormalizeBindValue(ByRef val) {
    if (val = "ERROR")
        val := ""
}

ClearRegisteredBindHotkeys() {
    global RegisteredBindHotkeys, HotkeyDispatchMap, IDConfirmHotkeyContext

    if (IsObject(RegisteredBindHotkeys))
    {
        Loop % RegisteredBindHotkeys.Length()
        {
            item := RegisteredBindHotkeys[A_Index]
            if IsObject(item)
            {
                hk := item.Key
                contextual := item.Contextual
            }
            else
            {
                hk := item
                contextual := false
            }

            if (contextual)
                Hotkey, If, % IDConfirmHotkeyContext
            if (hk != "")
                Hotkey, %hk%, DispatchBoundHotkey, Off UseErrorLevel
            if (contextual)
                Hotkey, If
        }
    }

    RegisteredBindHotkeys := []
    HotkeyDispatchMap := {}
}

RegisterBoundHotkey(bindName, currentKey, token, ByRef errText, ByRef usedKeys) {
    global RegisteredBindHotkeys, HotkeyDispatchMap, IDConfirmHotkeyContext

    currentKey := Trim(currentKey)
    if (currentKey = "" || currentKey = "ERROR")
        return true

    keyId := NormalizeHotkeyId(currentKey)
    if (keyId = "")
        return false

    if (usedKeys.HasKey(keyId))
    {
        errText .= bindName . " = " . currentKey . "  -> дубликат с """ . usedKeys[keyId] . """`n"
        return false
    }

    contextual := (token = "ConfirmID" || token = "RejectID")
    if (contextual)
        Hotkey, If, % IDConfirmHotkeyContext
    Hotkey, %currentKey%, DispatchBoundHotkey, On UseErrorLevel
    registerError := ErrorLevel
    if (contextual)
        Hotkey, If

    if (registerError)
    {
        errText .= bindName . " = " . currentKey . "  -> неверный или неподдерживаемый hotkey`n"
        return false
    }

    usedKeys[keyId] := bindName
    HotkeyDispatchMap[keyId] := token
    RegisteredBindHotkeys.Push({Key: currentKey, Contextual: contextual})
    return true
}

GetBoundLabelByToken(token) {
    static labelMap := ""
    if !IsObject(labelMap)
    {
        labelMap := {}
        labelMap["ToggleLastLawDoc"] := "DoToggleLastLawDoc"
        labelMap["HideLawGui"] := "DoHideLawGui"
        labelMap["EnterID"] := "DoEnterID"
        labelMap["TextCommandInput"] := "DoPrivateTextInput"
        labelMap["ResetID"] := "DoResetID"
        labelMap["OpenBindsTab"] := "DoOpenBindsTab"
        labelMap["IDOverlay"] := "DoToggleIDOverlay"
        labelMap["ConfirmID"] := "DoConfirmID"
        labelMap["RejectID"] := "DoRejectID"
        labelMap["Intro"] := "DoIntro"
        labelMap["SOS"] := "DoSOS"
        labelMap["Chase"] := "DoChase"
        labelMap["ChaseNoID"] := "DoChaseNoID"
        labelMap["Deject"] := "DoDeject"
        labelMap["Cuff"] := "DoCuff"
        labelMap["InCar"] := "DoInCar"
        labelMap["StopChase"] := "DoStopChase"
        labelMap["Doc"] := "DoDoc"
        labelMap["Search"] := "DoSearch"
        labelMap["PersonalFile"] := "DoPersonalFile"
        labelMap["Su"] := "DoSu"
        labelMap["MDC"] := "DoMDC"
        labelMap["Dep"] := "DoDep"
        labelMap["WantedList"] := "DoWantedList"
        labelMap["SOSStart"] := "DoSOSStart"
        labelMap["SOSArrive"] := "DoSOSArrive"
        labelMap["HijackStart"] := "DoHijackStart"
        labelMap["HijackArrive"] := "DoHijackArrive"
        labelMap["CallStart"] := "DoCallStart"
        labelMap["CallArrive"] := "DoCallArrive"
        labelMap["CallWorkStart"] := "DoCallWorkStart"
        labelMap["CallWorkEnd"] := "DoCallWorkEnd"
        labelMap["CivilCallStart"] := "DoCivilCallStart"
        labelMap["CivilCallArrive"] := "DoCivilCallArrive"
        labelMap["VehicleLookup"] := "DoVehicleLookup"
        labelMap["WantedRemoval"] := "DoWantedRemoval"
        labelMap["LawSearchSubmit"] := "DoLawSearchClipboard"
        labelMap["MaskCall"] := "DoMaskCall"
        labelMap["RecordCheck"] := "DoRecordCheck"
        labelMap["TrainCrash"] := "DoTrainCrash"
        labelMap["PatrolStart"] := "DoPatrolStart"
        labelMap["PatrolCont"] := "DoPatrolCont"
        labelMap["PatrolEnd"] := "DoPatrolEnd"
        labelMap["PostStart"] := "DoPostStart"
        labelMap["PostCont"] := "DoPostCont"
        labelMap["PostEnd"] := "DoPostEnd"
        labelMap["ConvoyStart"] := "DoConvoyStart"
        labelMap["ConvoyCont"] := "DoConvoyCont"
        labelMap["ConvoyEnd"] := "DoConvoyEnd"
        labelMap["TowStart"] := "DoTowStart"
        labelMap["TowEnd"] := "DoTowEnd"
        labelMap["CarSearch"] := "DoCarSearch"
        labelMap["Arrest"] := "DoArrest"
        labelMap["Fine"] := "DoFine"
        labelMap["Protocol"] := "DoProtocol"
        labelMap["Rights"] := "DoRights"
        labelMap["CardDS"] := "DoCardDS"
        labelMap["CardVK"] := "DoCardVK"
        labelMap["MDSFormation"] := "DoMDSFormation"
        labelMap["AutoPatrol"] := "DoAutoPatrolToggle"
        labelMap["AutoPost"] := "DoAutoPostToggle"
        labelMap["AssistOOP"] := "DoAssistOOP"
        labelMap["AssistStun"] := "DoAssistStun"
        labelMap["AssistChase"] := "DoAssistChase"
        labelMap["AssistHouse"] := "DoAssistHouse"
        labelMap["AssistDrugs"] := "DoAssistDrugs"
        labelMap["AssistPDPCuff"] := "DoAssistPDPCuff"
        labelMap["GuideSignals"] := "DoGuideSignals"
        labelMap["GuideRights"] := "DoGuideRights"
        labelMap["VU"] := "DoToggleVU"
        labelMap["FP"] := "DoToggleFP"
        labelMap["KON"] := "DoToggleKON"
        labelMap["FZOP"] := "DoToggleFZOP"
        labelMap["TER"] := "DoToggleTER"
        labelMap["TK"] := "DoToggleTK"
        labelMap["ARG"] := "DoToggleARG"
        labelMap["UK"] := "DoToggleUK"
        labelMap["VV"] := "DoToggleVV"
        labelMap["KOAP"] := "DoToggleKOAP"
        labelMap["PDD"] := "DoTogglePDD"
        labelMap["ORUZH"] := "DoToggleORUZH"
        labelMap["UPK"] := "DoToggleUPK"
        labelMap["KAS"] := "DoToggleKAS"
        labelMap["FSB"] := "DoToggleFSB"
        labelMap["FSIN"] := "DoToggleFSIN"
        labelMap["VS"] := "DoToggleVS"
        labelMap["SUD"] := "DoToggleSUD"
        labelMap["ORD"] := "DoToggleORD"
        labelMap["GT"] := "DoToggleGT"
    }

    if (labelMap.HasKey(token))
        return labelMap[token]
    return ""
}

ExecuteBindToken(token) {
    global HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab

    if RegExMatch(token, "^CustomFunction:(\d+)$", customMatch)
    {
        RunCustomFunction(customMatch1)
        return
    }

    if (token = "OpenSettings")
    {
        RequestIndependentGuiState(HUDVisible, BindListVisible, !SettingsVisible, SettingsTargetTab)
        return
    }
    if (token = "ToggleBindList")
    {
        RequestIndependentGuiState(HUDVisible, !BindListVisible, SettingsVisible, SettingsTargetTab)
        return
    }
    if (token = "ToggleHUD")
    {
        RequestIndependentGuiState(!HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab)
        return
    }

    labelName := GetBoundLabelByToken(token)
    if (labelName != "")
        SetTimer, %labelName%, -1
}

HandleBoundHotkey(hotkeyName) {
    if ServiceUI_IsInputActive()
        return
    global HotkeyDispatchMap, BindMenuEditMode
    keyId := NormalizeHotkeyId(hotkeyName)
    if (keyId = "" || !IsObject(HotkeyDispatchMap) || !HotkeyDispatchMap.HasKey(keyId))
        return

    token := HotkeyDispatchMap[keyId]
    if (BindMenuEditMode && token != "TextCommandInput" && GetBoundLabelByToken(token) != "")
    {
        BindMenuHotkeyBlockedWarn()
        return
    }
    ExecuteBindToken(token)
}

ApplyAllBinds() {
    global
    ok := 1
    errText := ""
    usedKeys := {}

    ClearRegisteredBindHotkeys()
    ClearCustomFunctionHotkeys()

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.HotkeyVar = "")
            continue

        hotkeyValue := GetDynamicGlobalValue(meta.HotkeyVar)
        NormalizeBindValue(hotkeyValue)
        SetDynamicGlobalValue(meta.HotkeyVar, hotkeyValue)

        if !RegisterBoundHotkey(meta.HotkeyVar, hotkeyValue, meta.Token, errText, usedKeys)
            ok := 0
    }

    ApplyCustomFunctionHotkeys(ok, errText, usedKeys)
    ApplyTextTriggers(ok, errText)

    UpdateHUD()
    UpdateBindList()

    if (!ok)
        ServiceUI_Message("Ошибка биндов", "Не применились следующие бинды:`n`n" . errText . "", "WARN")
}

GetBindCatalog() {
    static catalog := ""
    if IsObject(catalog)
        return catalog

    catalog := []
    catalog.Push({Token: "TextCommandInput", Label: "Окно текстовых команд", Category: "Системные", HotkeyVar: "Bind_TextCommandInput", TriggerVar: "", Hint: "Личный ввод TXT без игрового чата"})
    catalog.Push({Token: "OpenSettings", Label: "Открыть меню", Category: "Системные", HotkeyVar: "Bind_OpenSettings", TriggerVar: ""})
    catalog.Push({Token: "ToggleBindList", Label: "Показать bind-list", Category: "Системные", HotkeyVar: "Bind_ToggleBindList", TriggerVar: ""})
    catalog.Push({Token: "ToggleLastLawDoc", Label: "Последний закон", Category: "Системные", HotkeyVar: "Bind_ToggleLastLawDoc", TriggerVar: ""})
    catalog.Push({Token: "HideLawGui", Label: "Скрыть окно закона", Category: "Системные", HotkeyVar: "Bind_HideLawGui", TriggerVar: ""})
    catalog.Push({Token: "LawSearchSubmit", Label: "Запустить поиск законов", Category: "Системные", HotkeyVar: "Bind_LawSearchSubmit", TriggerVar: ""})
    catalog.Push({Token: "ToggleHUD", Label: "Показать HUD", Category: "Системные", HotkeyVar: "Bind_ToggleHUD", TriggerVar: ""})
    catalog.Push({Token: "IDOverlay", Label: "ID-плашка", Category: "Системные", HotkeyVar: "Bind_IDOverlay", TriggerVar: ""})
    catalog.Push({Token: "ConfirmID", Label: "Принять найденный ID", Category: "Системные", HotkeyVar: "Bind_ConfirmID", TriggerVar: ""})
    catalog.Push({Token: "RejectID", Label: "Отклонить найденный ID", Category: "Системные", HotkeyVar: "Bind_RejectID", TriggerVar: ""})
    catalog.Push({Token: "EnterID", Label: "Ввести ID вручную", Category: "Системные", HotkeyVar: "Bind_EnterID", TriggerVar: "Trig_EnterID"})
    catalog.Push({Token: "ResetID", Label: "Сброс ID", Category: "Системные", HotkeyVar: "Bind_ResetID", TriggerVar: "Trig_ResetID"})
    catalog.Push({Token: "OpenBindsTab", Label: "Настройки биндов", Category: "Системные", HotkeyVar: "Bind_OpenBindsTab", TriggerVar: "Trig_OpenBindsTab", Hint: "Открыть страницу основных клавиш"})

    catalog.Push({Token: "Intro", Label: "Представление", Category: "Задержание и RP", HotkeyVar: "Bind_Intro", TriggerVar: "Trig_Intro"})
    catalog.Push({Token: "SOS", Label: "SOS", Category: "Задержание и RP", HotkeyVar: "Bind_SOS", TriggerVar: "Trig_SOS"})
    catalog.Push({Token: "Chase", Label: "Chase с ID", Category: "Задержание и RP", HotkeyVar: "Bind_Chase", TriggerVar: "Trig_Chase"})
    catalog.Push({Token: "ChaseNoID", Label: "Chase без ID", Category: "Задержание и RP", HotkeyVar: "Bind_ChaseNoID", TriggerVar: "Trig_ChaseNoID"})
    catalog.Push({Token: "Deject", Label: "Deject", Category: "Задержание и RP", HotkeyVar: "Bind_Deject", TriggerVar: "Trig_Deject"})
    catalog.Push({Token: "Cuff", Label: "Cuff", Category: "Задержание и RP", HotkeyVar: "Bind_Cuff", TriggerVar: "Trig_Cuff"})
    catalog.Push({Token: "InCar", Label: "InCar", Category: "Задержание и RP", HotkeyVar: "Bind_InCar", TriggerVar: "Trig_InCar"})
    catalog.Push({Token: "StopChase", Label: "Остановка", Category: "Задержание и RP", HotkeyVar: "Bind_StopChase", TriggerVar: "Trig_StopChase"})
    catalog.Push({Token: "Doc", Label: "Служебное удостоверение", Category: "Задержание и RP", HotkeyVar: "Bind_Doc", TriggerVar: "Trig_Doc"})
    catalog.Push({Token: "Search", Label: "Досмотр", Category: "Задержание и RP", HotkeyVar: "Bind_Search", TriggerVar: "Trig_Search"})
    catalog.Push({Token: "PersonalFile", Label: "Личное дело", Category: "Задержание и RP", HotkeyVar: "Bind_PersonalFile", TriggerVar: "Trig_PersonalFile"})
    catalog.Push({Token: "Su", Label: "Корректировка розыска", Category: "Задержание и RP", HotkeyVar: "Bind_Su", TriggerVar: "Trig_Su", Hint: "Команда /su и RP-последовательность"})

    catalog.Push({Token: "Dep", Label: "Деп", Category: "Доклады", HotkeyVar: "Bind_Dep", TriggerVar: "Trig_Dep"})
    catalog.Push({Token: "WantedList", Label: "Розыскиваемые", Category: "Доклады", HotkeyVar: "Bind_WantedList", TriggerVar: "Trig_WantedList"})
    catalog.Push({Token: "SOSStart", Label: "SOS выехал", Category: "Доклады", HotkeyVar: "Bind_SOSStart", TriggerVar: "Trig_SOSStart"})
    catalog.Push({Token: "SOSArrive", Label: "SOS прибыл", Category: "Доклады", HotkeyVar: "Bind_SOSArrive", TriggerVar: "Trig_SOSArrive"})
    catalog.Push({Token: "HijackStart", Label: "Угон выехал", Category: "Доклады", HotkeyVar: "Bind_HijackStart", TriggerVar: "Trig_HijackStart", Enabled: 0, ExposeInSettings: 0, LegacyOnly: 1})
    catalog.Push({Token: "HijackArrive", Label: "Угон прибыл", Category: "Доклады", HotkeyVar: "Bind_HijackArrive", TriggerVar: "Trig_HijackArrive", Enabled: 0, ExposeInSettings: 0, LegacyOnly: 1})
    catalog.Push({Token: "CallStart", Label: "ДТП вызов принят", Category: "Доклады", HotkeyVar: "Bind_CallStart", TriggerVar: "Trig_CallStart"})
    catalog.Push({Token: "CallArrive", Label: "ДТП прибыли", Category: "Доклады", HotkeyVar: "Bind_CallArrive", TriggerVar: "Trig_CallArrive"})
    catalog.Push({Token: "CallWorkStart", Label: "ДТП оформление старт", Category: "Доклады", HotkeyVar: "Bind_CallWorkStart", TriggerVar: "Trig_CallWorkStart"})
    catalog.Push({Token: "CallWorkEnd", Label: "ДТП оформление конец", Category: "Доклады", HotkeyVar: "Bind_CallWorkEnd", TriggerVar: "Trig_CallWorkEnd"})
    catalog.Push({Token: "CivilCallStart", Label: "Гражданский вызов принят", Category: "Доклады", HotkeyVar: "Bind_CivilCallStart", TriggerVar: "Trig_CivilCallStart"})
    catalog.Push({Token: "CivilCallArrive", Label: "Гражданский вызов: прибыл", Category: "Доклады", HotkeyVar: "Bind_CivilCallArrive", TriggerVar: "Trig_CivilCallArrive"})
    catalog.Push({Token: "MaskCall", Label: "Маска и звонок", Category: "Доклады", HotkeyVar: "Bind_MaskCall", TriggerVar: "Trig_MaskCall"})
    catalog.Push({Token: "RecordCheck", Label: "Проверка записи", Category: "Доклады", HotkeyVar: "Bind_RecordCheck", TriggerVar: "Trig_RecordCheck"})
    catalog.Push({Token: "TrainCrash", Label: "Крушение поезда", Category: "Доклады", HotkeyVar: "Bind_TrainCrash", TriggerVar: "Trig_TrainCrash"})

    catalog.Push({Token: "PatrolStart", Label: "Патруль старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolStart", TriggerVar: "Trig_PatrolStart"})
    catalog.Push({Token: "PatrolCont", Label: "Патруль прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolCont", TriggerVar: "Trig_PatrolCont"})
    catalog.Push({Token: "PatrolEnd", Label: "Патруль конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolEnd", TriggerVar: "Trig_PatrolEnd"})
    catalog.Push({Token: "PostStart", Label: "Пост старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostStart", TriggerVar: "Trig_PostStart"})
    catalog.Push({Token: "PostCont", Label: "Пост прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostCont", TriggerVar: "Trig_PostCont"})
    catalog.Push({Token: "PostEnd", Label: "Пост конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostEnd", TriggerVar: "Trig_PostEnd"})
    catalog.Push({Token: "AutoPatrol", Label: "Автопатруль · 10 мин", Category: "Транспорт / прочее", HotkeyVar: "Bind_AutoPatrol", TriggerVar: "Trig_AutoPatrol", Hint: "Запрашивает длительность и отправляет доклад каждые 10 минут"})
    catalog.Push({Token: "AutoPost", Label: "Автопост · 10 мин", Category: "Транспорт / прочее", HotkeyVar: "Bind_AutoPost", TriggerVar: "Trig_AutoPost", Hint: "Запрашивает длительность и отправляет доклад каждые 10 минут"})
    catalog.Push({Token: "ConvoyStart", Label: "Колонна старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyStart", TriggerVar: "Trig_ConvoyStart"})
    catalog.Push({Token: "ConvoyCont", Label: "Колонна прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyCont", TriggerVar: "Trig_ConvoyCont"})
    catalog.Push({Token: "ConvoyEnd", Label: "Колонна конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyEnd", TriggerVar: "Trig_ConvoyEnd"})
    catalog.Push({Token: "TowStart", Label: "Эвакуация старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_TowStart", TriggerVar: "Trig_TowStart"})
    catalog.Push({Token: "TowEnd", Label: "Эвакуация конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_TowEnd", TriggerVar: "Trig_TowEnd"})
    catalog.Push({Token: "CarSearch", Label: "Осмотр ТС", Category: "Транспорт / прочее", HotkeyVar: "Bind_CarSearch", TriggerVar: "Trig_CarSearch"})
    catalog.Push({Token: "VehicleLookup", Label: "Пробив номера ТС", Category: "Транспорт / прочее", HotkeyVar: "Bind_VehicleLookup", TriggerVar: "Trig_VehicleLookup"})
    catalog.Push({Token: "WantedRemoval", Label: "Снятие розыска", Category: "Задержание и RP", HotkeyVar: "Bind_WantedRemoval", TriggerVar: "Trig_WantedRemoval"})
    catalog.Push({Token: "Arrest", Label: "Арест", Category: "Транспорт / прочее", HotkeyVar: "Bind_Arrest", TriggerVar: "Trig_Arrest"})
    catalog.Push({Token: "Fine", Label: "Штраф", Category: "Транспорт / прочее", HotkeyVar: "Bind_Fine", TriggerVar: "Trig_Fine"})
    catalog.Push({Token: "Protocol", Label: "Протокол", Category: "Транспорт / прочее", HotkeyVar: "Bind_Protocol", TriggerVar: "Trig_Protocol"})
    catalog.Push({Token: "Rights", Label: "Права", Category: "Транспорт / прочее", HotkeyVar: "Bind_Rights", TriggerVar: "Trig_Rights"})
    catalog.Push({Token: "CardDS", Label: "Визитка DS", Category: "Транспорт / прочее", HotkeyVar: "Bind_CardDS", TriggerVar: "Trig_CardDS"})
    catalog.Push({Token: "CardVK", Label: "Визитка VK", Category: "Транспорт / прочее", HotkeyVar: "Bind_CardVK", TriggerVar: "Trig_CardVK"})
    catalog.Push({Token: "MDSFormation", Label: "Строй", Category: "Доклады", HotkeyVar: "Bind_MDSFormation", TriggerVar: "Trig_MDSFormation"})
    catalog.Push({Token: "AssistOOP", Label: "Пробив ООП", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistOOP", TriggerVar: "Trig_AssistOOP", Hint: "Запрос ID и поиск местоположения", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistStun", Label: "Оглушение", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistStun", TriggerVar: "Trig_AssistStun", Hint: "Запрос ID и выбор тазера или дубинки", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistChase", Label: "Преследование", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistChase", TriggerVar: "Trig_AssistChase", Hint: "Запрос ID и автоматический /chase", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistHouse", Label: "Сигнализация дома", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistHouse", TriggerVar: "Trig_AssistHouse", Hint: "Предложение отметить дом в GPS", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistDrugs", Label: "Наркотики рядом", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistDrugs", TriggerVar: "Trig_AssistDrugs", Hint: "Предложение сохранить ID нарушителя", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistPDPCuff", Label: "Наручники после ПДП", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistPDPCuff", TriggerVar: "Trig_AssistPDPCuff", Hint: "Подтверждение наручников после помощи", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "GpsD", Label: "GPS Д", Category: "Транспорт / прочее", HotkeyVar: "", TriggerVar: "Trig_GpsD"})
    catalog.Push({Token: "GpsOS", Label: "GPS ОС", Category: "Транспорт / прочее", HotkeyVar: "", TriggerVar: "Trig_GpsOS"})
    catalog.Push({Token: "GuideRights", Label: "Права — текстовое окно", Category: "Документы", HotkeyVar: "Bind_GuideRights", TriggerVar: "Trig_GuideRights", Hint: "Текст прав текущего профиля; PgUp / PgDn — листать"})
    catalog.Push({Token: "GuideSignals", Label: "Сигналы СО", Category: "Документы", HotkeyVar: "Bind_GuideSignals", TriggerVar: "Trig_GuideSignals", Hint: "Справочное окно; PgUp / PgDn — листать"})
    catalog.Push({Token: "VU", Label: "ВУ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VU"})
    catalog.Push({Token: "FP", Label: "ФП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FP"})
    catalog.Push({Token: "KON", Label: "Конст.", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KON"})
    catalog.Push({Token: "FZOP", Label: "ФЗОП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FZOP"})
    catalog.Push({Token: "TER", Label: "Терр.", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_TER"})
    catalog.Push({Token: "TK", Label: "ТК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_TK"})
    catalog.Push({Token: "ARG", Label: "АРГ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ARG"})
    catalog.Push({Token: "UK", Label: "УК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_UK"})
    catalog.Push({Token: "VV", Label: "Вертикаль", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VV"})
    catalog.Push({Token: "KOAP", Label: "КоАП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KOAP"})
    catalog.Push({Token: "PDD", Label: "ПДД", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_PDD"})
    catalog.Push({Token: "ORUZH", Label: "Оружие", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ORUZH"})
    catalog.Push({Token: "UPK", Label: "УПК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_UPK"})
    catalog.Push({Token: "KAS", Label: "КАС", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KAS"})
    catalog.Push({Token: "FSB", Label: "ФЗ о ФСБ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FSB"})
    catalog.Push({Token: "FSIN", Label: "ФЗ о ФСИН", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FSIN"})
    catalog.Push({Token: "VS", Label: "Военная служба", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VS"})
    catalog.Push({Token: "SUD", Label: "Судебная система", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_SUD"})
    catalog.Push({Token: "ORD", Label: "ОРД", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ORD"})
    catalog.Push({Token: "GT", Label: "Гостайна", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_GT"})

    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !meta.HasKey("Handler")
            meta.Handler := meta.Token
        if !meta.HasKey("Hint")
            meta.Hint := meta.Label
        if !meta.HasKey("Safe")
            meta.Safe := "On"
        if !meta.HasKey("TemplateVar")
            meta.TemplateVar := ""
        if !meta.HasKey("Enabled")
            meta.Enabled := 1
        if !meta.HasKey("ExposeInSettings")
            meta.ExposeInSettings := 1
        if !meta.HasKey("InternalOnly")
            meta.InternalOnly := 0
        if !meta.HasKey("LegacyOnly")
            meta.LegacyOnly := 0
        catalog[A_Index] := meta
    }
    return catalog
}

BindCatalog_IsRegistrable(meta) {
    return IsObject(meta) && meta.Enabled && !meta.InternalOnly && !meta.LegacyOnly
}

BindCatalog_IsUserVisible(meta) {
    return BindCatalog_IsRegistrable(meta) && meta.ExposeInSettings
}

GetBindCatalogMap() {
    static tokenMap := ""
    if IsObject(tokenMap)
        return tokenMap

    tokenMap := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        tokenMap[meta.Token] := meta
    }
    return tokenMap
}
