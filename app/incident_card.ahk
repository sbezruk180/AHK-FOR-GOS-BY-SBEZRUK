; Incident journal: bounded local records, no automatic commands and no timer.
; The storage is separate from profile INI files; text fields use the existing
; lossless CP1251 hex codec so ANSI x86 and Unicode test hosts read identical data.
global IC_Title := "", IC_Info := "", IC_List := "", IC_Notes := "", IC_Laws := "", IC_Chat := "", IC_Next := "", IC_Status := ""
global IncidentCardEnabled := 0
global IncidentCardCurrent := ""
global IncidentCardEntries := []
global IncidentCardChatTail := []
global IncidentCardHwnd := 0
global IncidentCardListHwnd := 0
global IncidentCardNotesHwnd := 0
global IncidentCardBusy := 0
global IncidentCardStatus := ""
global IncidentCardPassive := 0
global IncidentCardRecordSerial := 0
global IncidentCardWriteBusy := 0

IncidentCard_DataDir(root := "") {
    return root != "" ? RTrim(root, "\/") : AppHost_DataDir() . "\incidents"
}

IncidentCard_ValidRecordID(id) {
    return RegExMatch(id . "", "^[0-9]{14}-[0-9]{1,15}-[0-9]{1,6}$") > 0
}

IncidentCard_CleanLine(value, maxLen := 128) {
    return SubStr(Trim(RegExReplace(value . "", "[\x00-\x1F\x7F]", " ")), 1, maxLen)
}

IncidentCard_NormalizeTarget(id, nickname := "", isMask := false, profile := "") {
    id := Trim(id . "")
    if (isMask) {
        if !RegExMatch(id, "^[0-9]{5,20}$")
            return ""
    } else {
        if !RegExMatch(id, "^[0-9]{1,6}$")
            return ""
        id := "" . (id + 0)
    }
    return {ID: id, Nickname: isMask ? "" : IncidentCard_CleanLine(nickname, 64)
        , Mask: isMask ? 1 : 0, Profile: IncidentCard_CleanLine(profile, 100)}
}

IncidentCard_CurrentTarget() {
    global UserID, ActiveID, TargetNickname, TargetIsMask, CurrentProfile
    if (!ActiveID)
        return ""
    return IncidentCard_NormalizeTarget(UserID, TargetNickname, TargetIsMask, CurrentProfile)
}

IncidentCard_TargetMatches(card, target) {
    if (!IsObject(card) || !IsObject(target) || card.Profile != target.Profile
        || card.Mask != target.Mask || "ID:" . card.ID != "ID:" . target.ID)
        return false
    ; A nickname learned later enriches an unnamed target. A known different
    ; nickname means ID reuse and must never merge two people's records.
    return card.Nickname = "" || target.Nickname = "" || card.Nickname = target.Nickname
}

IncidentCard_CreateRecord(target, now := "") {
    global IncidentCardRecordSerial
    if !IsObject(target)
        return ""
    target := IncidentCard_NormalizeTarget(target.ID, target.Nickname, target.Mask, target.Profile)
    if !IsObject(target)
        return ""
    if (now = "")
        now := A_NowUTC
    if !RegExMatch(now, "^[0-9]{14}$")
        return ""
    IncidentCardRecordSerial := Mod(IncidentCardRecordSerial, 999999) + 1
    id := now . "-" . TickNow() . "-" . IncidentCardRecordSerial
    return {RecordID: id, Created: now, Updated: now, Profile: target.Profile
        , ID: target.ID, Nickname: target.Nickname, Mask: target.Mask, Notes: "", Laws: [], Chat: []}
}

IncidentCard_EncodeRecord(card) {
    if (!IsObject(card) || !IncidentCard_ValidRecordID(card.RecordID)
        || !RegExMatch(card.Created . "", "^[0-9]{14}$") || !RegExMatch(card.Updated . "", "^[0-9]{14}$")
        || !RegExMatch(card.Mask . "", "^[01]$")
        || !IsObject(IncidentCard_NormalizeTarget(card.ID, card.Nickname, card.Mask, card.Profile))
        || card.Profile != IncidentCard_CleanLine(card.Profile, 100)
        || card.Nickname != IncidentCard_CleanLine(card.Nickname, 64) || (card.Mask && card.Nickname != "")
        || StrLen(card.Notes) > 16000 || !IsObject(card.Laws) || card.Laws.Length() > 16
        || !IsObject(card.Chat) || card.Chat.Length() > 24)
        return ""
    out := "AHK_FOR_GOS_INCIDENT_V1`r`n"
    for _, key in ["RecordID", "Created", "Updated", "Profile", "ID", "Nickname", "Mask", "Notes"]
        out .= key . "=" . EncodeIniText(card[key]) . "`r`n"
    out .= "LawCount=" . card.Laws.Length() . "`r`nChatCount=" . card.Chat.Length() . "`r`n"
    for index, law in card.Laws {
        if (!IsObject(law) || StrLen(law.Key) > 256 || StrLen(law.Title) > 240 || StrLen(law.Text) > 2000)
            return ""
        for _, field in ["Key", "Title", "Text"]
            out .= "Law" . index . field . "=" . EncodeIniText(law[field]) . "`r`n"
    }
    for index, line in card.Chat {
        if (StrLen(line) > 512)
            return ""
        out .= "Chat" . index . "=" . EncodeIniText(line) . "`r`n"
    }
    return StrLen(out) <= 131072 ? out : ""
}

IncidentCard_DecodeRecord(text, expectedID := "") {
    if (StrLen(text) > 131072 || SubStr(text, 1, 25) != "AHK_FOR_GOS_INCIDENT_V1`r`n")
        return ""
    values := {}, lineNo := 0
    Loop, Parse, text, `n, `r
    {
        lineNo++
        if (lineNo = 1 || A_LoopField = "")
            continue
        equal := InStr(A_LoopField, "=")
        if (!equal)
            return ""
        key := SubStr(A_LoopField, 1, equal - 1), value := SubStr(A_LoopField, equal + 1)
        if (!RegExMatch(key, "^[A-Za-z][A-Za-z0-9]*$") || values.HasKey(key))
            return ""
        values[key] := value
    }
    card := {Laws: [], Chat: []}
    for _, key in ["RecordID", "Created", "Updated", "Profile", "ID", "Nickname", "Mask", "Notes"] {
        if (!values.HasKey(key) || !IncidentCard_IsEncodedText(values[key]))
            return ""
        card[key] := DecodeIniText(values[key], "hex1")
    }
    if (!IncidentCard_ValidRecordID(card.RecordID) || (expectedID != "" && card.RecordID != expectedID)
        || !RegExMatch(card.Mask . "", "^[01]$") || StrLen(card.Profile) > 100 || StrLen(card.Nickname) > 64
        || !values.HasKey("LawCount") || !RegExMatch(values.LawCount, "^(?:[0-9]|1[0-6])$")
        || !values.HasKey("ChatCount") || !RegExMatch(values.ChatCount, "^(?:[0-9]|1[0-9]|2[0-4])$"))
        return ""
    Loop % values.LawCount {
        index := A_Index, law := {}
        for _, field in ["Key", "Title", "Text"] {
            key := "Law" . index . field
            if (!values.HasKey(key) || !IncidentCard_IsEncodedText(values[key]))
                return ""
            law[field] := DecodeIniText(values[key], "hex1")
        }
        card.Laws.Push(law)
    }
    Loop % values.ChatCount {
        key := "Chat" . A_Index
        if (!values.HasKey(key) || !IncidentCard_IsEncodedText(values[key]))
            return ""
        card.Chat.Push(DecodeIniText(values[key], "hex1"))
    }
    return IncidentCard_EncodeRecord(card) != "" ? card : ""
}

IncidentCard_IsEncodedText(text) {
    if !RegExMatch(text, "^H1:([0-9]{1,6}):([A-F0-9]*)$", match)
        return false
    ; A NUL cannot round-trip through AHK's string representation.
    return StrLen(match2) = match1 * 2 && !RegExMatch(match2, "^(?:[A-F0-9]{2})*00")
}

IncidentCard_SaveRecord(card, root := "") {
    global IncidentCardWriteBusy
    previousCritical := A_IsCritical
    Critical, On
    if (IncidentCardWriteBusy || !IsObject(card)) {
        Critical, %previousCritical%
        return false
    }
    IncidentCardWriteBusy := 1
    Critical, %previousCritical%
    previousUpdated := card.Updated
    card.Updated := A_NowUTC
    text := IncidentCard_EncodeRecord(card)
    if (text = "") {
        card.Updated := previousUpdated
        IncidentCardWriteBusy := 0
        return false
    }
    folder := IncidentCard_DataDir(root), target := folder . "\" . card.RecordID . ".case"
    stage := target . ".tmp-" . DllCall("GetCurrentProcessId")
    ok := false
    try {
        FileCreateDir, %folder%
        file := FileOpen(stage, "w", "UTF-8-RAW")
        if !IsObject(file)
            return false
        try {
            written := file.Write(text)
            flushed := DllCall("FlushFileBuffers", "Ptr", file.__Handle, "Int")
        } finally {
            file.Close()
        }
        if (!written || !flushed)
            return false
        ok := DllCall("MoveFileExW", "WStr", stage, "WStr", target, "UInt", 0x9, "Int")
        if (ok && root = "")
            IncidentCard_UpdateEntry(card)
        return !!ok
    } catch e {
        return false
    } finally {
        if (!ok)
            card.Updated := previousUpdated
        IncidentCardWriteBusy := 0
        if FileExist(stage) {
            try {
                FileDelete, %stage%
            } catch cleanupError {
                LogError("IncidentCard", "Временный файл недоступен для удаления: " . stage, "WARN")
            }
        }
    }
}

IncidentCard_RecordEntry(card) {
    return {RecordID: card.RecordID, Profile: card.Profile, ID: card.ID
        , Nickname: card.Nickname, Mask: card.Mask, Created: card.Created, Updated: card.Updated}
}

IncidentCard_UpdateEntry(card) {
    global IncidentCardEntries
    if !IsObject(IncidentCardEntries)
        IncidentCardEntries := []
    for index, entry in IncidentCardEntries
        if (entry.RecordID = card.RecordID) {
            IncidentCardEntries[index] := IncidentCard_RecordEntry(card)
            return true
        }
    IncidentCardEntries.InsertAt(1, IncidentCard_RecordEntry(card))
    while (IncidentCardEntries.Length() > 200)
        IncidentCardEntries.RemoveAt(IncidentCardEntries.Length())
    return true
}

IncidentCard_LoadRecord(id, root := "") {
    if !IncidentCard_ValidRecordID(id)
        return ""
    file := FileOpen(IncidentCard_DataDir(root) . "\" . id . ".case", "r", "UTF-8")
    if !IsObject(file)
        return ""
    try {
        if (file.Length > 131072)
            return ""
        return IncidentCard_DecodeRecord(file.Read(), id)
    } finally {
        file.Close()
    }
}

IncidentCard_LoadEntries(root := "") {
    folder := IncidentCard_DataDir(root), names := "", entries := []
    Loop, Files, % folder . "\*.case", F
    {
        SplitPath, A_LoopFileName,,,, id
        if IncidentCard_ValidRecordID(id)
            names .= id . "`n"
    }
    Sort, names, R
    count := 0
    Loop, Parse, names, `n, `r
    {
        if (A_LoopField = "")
            continue
        if (++count > 200)
            break
        card := IncidentCard_LoadRecord(A_LoopField, root)
        if IsObject(card)
            entries.Push(IncidentCard_RecordEntry(card))
    }
    return entries
}

IncidentCard_RecordingAllowed(allowTest := false) {
    global AuditTestMode
    training := IsFunc("Training_IsActive") ? Func("Training_IsActive").Call() : false
    return !training && (allowTest || !AuditTestMode)
}

IncidentCard_OnChatLine(line, allowTest := false) {
    global IncidentCardChatTail
    if !IncidentCard_RecordingAllowed(allowTest)
        return false
    if !IsObject(IncidentCardChatTail)
        IncidentCardChatTail := []
    line := IncidentCard_CleanLine(line, 512)
    if (line = "")
        return false
    IncidentCardChatTail.Push(line)
    while (IncidentCardChatTail.Length() > 80)
        IncidentCardChatTail.RemoveAt(1)
    return true
}

IncidentCard_LineMatches(line, card) {
    if (!IsObject(card) || card.Mask)
        return false
    ; An ID only matches bracketed player-ID syntax, never time, prices,
    ; house numbers or a substring of another ID.
    if (RegExMatch(card.ID . "", "^[0-9]{1,6}$")
        && RegExMatch(line, "i)(?:\[\s*" . card.ID . "\s*\]|\bID\s*[:#№]?\s*" . card.ID . "(?![0-9]))"))
        return true
    name := card.Nickname
    if (name = "")
        return false
    escaped := RegExReplace(name, "([\\.*+?\[\](){}^$|])", "\$1")
    return RegExMatch(line, "i)(?<![A-Za-zА-Яа-яЁё0-9_])" . escaped . "(?![A-Za-zА-Яа-яЁё0-9_])") > 0
}

IncidentCard_CollectChat(card, lines := "") {
    global IncidentCardChatTail
    if (!IsObject(card) || !IsObject(card.Chat))
        return 0
    if !IsObject(lines)
        lines := IncidentCardChatTail
    added := 0
    for _, line in lines {
        line := IncidentCard_CleanLine(line, 512)
        if (!IncidentCard_LineMatches(line, card))
            continue
        duplicate := false
        for _, saved in card.Chat
            if (saved = line) {
                duplicate := true
                break
            }
        if (duplicate)
            continue
        card.Chat.Push(line), added++
        while (card.Chat.Length() > 24)
            card.Chat.RemoveAt(1)
    }
    return added
}

IncidentCard_AddLaw(card, item) {
    if (!IsObject(card) || !IsObject(item) || item.DocCode = "" || item.ItemId = ""
        || !RegExMatch(item.DocCode, "^[A-Z]{2,8}$"))
        return false
    key := item.DocCode . "|" . item.ItemId
    if (StrLen(key) > 256)
        return false
    for _, law in card.Laws
        if (law.Key = key)
            return false
    if (card.Laws.Length() >= 16)
        return false
    title := IncidentCard_CleanLine(item.DocName . " / " . LawSearch_GetItemTitle(item), 240)
    text := SubStr(LawSearch_GetItemBodyText(item), 1, 2000)
    if (StrLen(LawSearch_GetItemBodyText(item)) > 2000)
        text := SubStr(text, 1, 1960) . "`r`n[Сохранён фрагмент статьи]"
    card.Laws.Push({Key: key, Title: title, Text: text})
    return true
}

IncidentCard_FormatTime(stamp) {
    FormatTime, formatted, %stamp%, yyyy-MM-dd HH:mm:ss
    return formatted . " UTC"
}

IncidentCard_Label(card) {
    return (card.Mask ? "Маска " : "ID ") . card.ID . (card.Nickname != "" ? " / " . card.Nickname : "")
}

IncidentCard_Report(card) {
    if !IsObject(card)
        return ""
    out := "AHK FOR GOS — карточка происшествия`r`n"
        . "Номер: " . card.RecordID . "`r`nЦель: " . IncidentCard_Label(card)
        . "`r`nПрофиль: " . card.Profile . "`r`nСоздана: " . IncidentCard_FormatTime(card.Created)
        . "`r`nИзменена: " . IncidentCard_FormatTime(card.Updated)
        . "`r`n`r`nЗАМЕТКИ`r`n" . card.Notes . "`r`n`r`nВЫБРАННЫЕ НОРМЫ`r`n"
    for _, law in card.Laws
        out .= law.Title . "`r`n" . law.Text . "`r`n`r`n"
    out .= "ФРАГМЕНТЫ CHATLOG (совпадение по нику / ID не доказывает событие)`r`n"
    for _, line in card.Chat
        out .= line . "`r`n"
    return out
}

IncidentCard_Export(card, root := "") {
    static serial := 0
    if (!IsObject(card) || IncidentCard_EncodeRecord(card) = "")
        return ""
    folder := IncidentCard_DataDir(root) . "\exports"
    try {
        FileCreateDir, %folder%
        target := folder . "\" . card.RecordID . "-" . A_NowUTC . "-" . DllCall("GetCurrentProcessId") . "-" . (++serial) . ".txt"
        file := FileOpen(target, "w", "UTF-8")
        if !IsObject(file)
            return ""
        try {
            ok := file.Write(IncidentCard_Report(card)) > 0
        } finally {
            file.Close()
        }
        return ok ? target : ""
    } catch exportError {
        return ""
    }
}

IncidentCard_SaveFromGui() {
    global IncidentCardCurrent, IncidentCardHwnd, IncidentCardNotesHwnd, IncidentCardPassive
    if !IsObject(IncidentCardCurrent)
        return true
    if (IncidentCardHwnd && IncidentCardNotesHwnd && !IncidentCardPassive) {
        ControlGetText, notes,, ahk_id %IncidentCardNotesHwnd%
        IncidentCardCurrent.Notes := SubStr(notes, 1, 16000)
    }
    return IncidentCard_SaveRecord(IncidentCardCurrent)
}

IncidentCard_SelectTarget(forceNew := false, allowTest := false) {
    global IncidentCardCurrent, IncidentCardEntries
    if !IncidentCard_RecordingAllowed(allowTest)
        return false
    target := IncidentCard_CurrentTarget()
    if !IsObject(target)
        return false
    if (!forceNew && IncidentCard_TargetMatches(IncidentCardCurrent, target)) {
        if (IncidentCardCurrent.Nickname = "" && target.Nickname != "")
            IncidentCardCurrent.Nickname := target.Nickname
        return IncidentCard_SaveFromGui()
    }
    if !IncidentCard_SaveFromGui()
        return false
    if (!forceNew) {
        record := IncidentCard_FindRecord(target, IncidentCardEntries)
        if IsObject(record) {
            IncidentCardCurrent := record
            if (record.Nickname = "" && target.Nickname != "")
                record.Nickname := target.Nickname
            return IncidentCard_SaveRecord(record)
        }
    }
    card := IncidentCard_CreateRecord(target)
    if (!IsObject(card) || !IncidentCard_SaveRecord(card))
        return false
    IncidentCardCurrent := card
    IncidentCard_UpdateEntry(card)
    return true
}

IncidentCard_FindRecord(target, entries, root := "") {
    if (!IsObject(target) || !IsObject(entries))
        return ""
    for _, entry in entries {
        if !IncidentCard_TargetMatches(entry, target)
            continue
        record := IncidentCard_LoadRecord(entry.RecordID, root)
        if (IsObject(record) && IncidentCard_TargetMatches(record, target))
            return record
    }
    return ""
}

IncidentCard_OnTargetChanged(allowTest := false) {
    global IncidentCardEnabled, IncidentCardBusy, IncidentCardHwnd
    if (!IncidentCard_RecordingAllowed(allowTest) || !IncidentCardEnabled || IncidentCardBusy)
        return false
    IncidentCardBusy := 1
    try {
        result := IncidentCard_SelectTarget(false, allowTest)
        if (IncidentCardHwnd)
            IncidentCard_RefreshGui()
        return result
    } finally {
        IncidentCardBusy := 0
    }
}

IncidentCard_SetStatus(text) {
    global IncidentCardStatus, IncidentCardHwnd
    IncidentCardStatus := text
    if (IncidentCardHwnd)
        GuiControl, IncidentJournal:, IC_Status, %text%
}

IncidentCard_RefreshGui() {
    global IncidentCardCurrent, IncidentCardEntries, IncidentCardHwnd
    if (!IncidentCardHwnd)
        return
    options := "", selected := 0
    for index, entry in IncidentCardEntries {
        options .= (options = "" ? "" : "|") . StrReplace(IncidentCard_Label(entry), "|", " ") . " / " . SubStr(entry.Created, 9, 4)
        if (IsObject(IncidentCardCurrent) && entry.RecordID = IncidentCardCurrent.RecordID)
            selected := index
    }
    GuiControl, IncidentJournal:, IC_List, % "|" . options
    if (selected)
        GuiControl, IncidentJournal:Choose, IC_List, %selected%
    card := IncidentCardCurrent
    if !IsObject(card) {
        GuiControl, IncidentJournal:, IC_Title, Выберите цель через Auto ID или ручной ввод
        GuiControl, IncidentJournal:, IC_Info, Карточка создаётся после выбора ID. Старые записи доступны слева.
        GuiControl, IncidentJournal:, IC_Notes,
        GuiControl, IncidentJournal:, IC_Laws,
        GuiControl, IncidentJournal:, IC_Chat,
        return
    }
    GuiControl, IncidentJournal:, IC_Title, % IncidentCard_Label(card)
    GuiControl, IncidentJournal:, IC_Info, % "Профиль: " . card.Profile . " | " . IncidentCard_FormatTime(card.Created)
    GuiControl, IncidentJournal:, IC_Notes, % card.Notes
    laws := ""
    for index, law in card.Laws
        laws .= index . ". " . law.Title . "`r`n"
    GuiControl, IncidentJournal:, IC_Laws, %laws%
    chat := ""
    for _, line in card.Chat
        chat .= line . "`r`n"
    GuiControl, IncidentJournal:, IC_Chat, %chat%
    GuiControl, IncidentJournal:, IC_Next, % IncidentCard_NextHint(card)
}

IncidentCard_NextHint(card) {
    if !IsObject(card)
        return "Далее: выберите цель и создайте карточку."
    if (Trim(card.Notes) = "")
        return "Далее: запишите основания и обстоятельства происшествия."
    if (!card.Laws.Length())
        return "Далее: найдите нужную норму и добавьте её снимок из поиска."
    if (!card.Chat.Length())
        return "Далее: проверьте chatlog и сохраните относящиеся к цели строки."
    return "Далее: сверьте цель, ознакомьте с правами и экспортируйте запись."
}

IncidentCard_Open(params*) {
    global IncidentCardEnabled, IncidentCardEntries, IncidentCardHwnd, IncidentCardListHwnd
    global IncidentCardNotesHwnd, IncidentCardPassive, IncidentCardCurrent
    if (IncidentCardHwnd && DllCall("IsWindow", "Ptr", IncidentCardHwnd)) {
        IncidentCard_OnTargetChanged()
        Gui, IncidentJournal:Show, NoActivate
        return true
    }
    IncidentCardEnabled := 1
    IncidentCardEntries := IncidentCard_LoadEntries()
    IncidentCard_SelectTarget()
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    IncidentCardPassive := GameUi_ShouldShowPassive()
    Gui, IncidentJournal:New, +HwndIncidentCardHwnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
    if (IncidentCardPassive)
        Gui, IncidentJournal:+E0x08000000
    Gui, IncidentJournal:Color, %panel%, %surface%
    Gui, IncidentJournal:Font, s8 Bold c%accent%, Segoe UI
    Gui, IncidentJournal:Add, Text, x20 y16 w820 h18 BackgroundTrans, AHK FOR GOS / ЖУРНАЛ ПРОИСШЕСТВИЙ
    Gui, IncidentJournal:Font, s14 Bold c%fg%, Segoe UI
    Gui, IncidentJournal:Add, Text, x252 y48 w588 h30 vIC_Title BackgroundTrans
    Gui, IncidentJournal:Font, s8 Norm c%muted%, Segoe UI
    Gui, IncidentJournal:Add, Text, x252 y82 w588 h28 vIC_Info BackgroundTrans
    Gui, IncidentJournal:Add, Text, x20 y50 w208 h22 BackgroundTrans, Последние 200 карточек
    Gui, IncidentJournal:Font, s9 c%inputFg%, Segoe UI
    Gui, IncidentJournal:Add, ListBox, x20 y80 w212 h390 vIC_List AltSubmit HwndIncidentCardListHwnd
    selectCallback := Func("IncidentCard_SelectEntry")
    GuiControl, IncidentJournal:+g, %IncidentCardListHwnd%, %selectCallback%
    Gui, IncidentJournal:Font, s9 Bold c%fg%, Segoe UI
    Gui, IncidentJournal:Add, Text, x252 y116 w588 h20 BackgroundTrans, Заметки
    Gui, IncidentJournal:Font, s9 Norm c%inputFg%, Segoe UI
    noteOptions := IncidentCardPassive ? "ReadOnly" : ""
    Gui, IncidentJournal:Add, Edit, x252 y142 w588 h134 vIC_Notes HwndIncidentCardNotesHwnd Limit16000 +VScroll %noteOptions%
    Gui, IncidentJournal:Font, s9 Bold c%fg%, Segoe UI
    Gui, IncidentJournal:Add, Text, x252 y288 w588 h20 BackgroundTrans, Выбранные нормы (снимок текста)
    Gui, IncidentJournal:Font, s9 Norm c%inputFg%, Segoe UI
    Gui, IncidentJournal:Add, Edit, x252 y312 w588 h72 vIC_Laws ReadOnly +VScroll
    Gui, IncidentJournal:Font, s9 Bold c%fg%, Segoe UI
    Gui, IncidentJournal:Add, Text, x252 y396 w588 h20 BackgroundTrans, Фрагменты chatlog по нику / ID
    Gui, IncidentJournal:Font, s9 Norm c%inputFg%, Segoe UI
    Gui, IncidentJournal:Add, Edit, x252 y420 w588 h92 vIC_Chat ReadOnly +VScroll
    Gui, IncidentJournal:Font, s9 c%fg%, Segoe UI
    buttons := [{X: 20, Y: 482, W: 212, Text: "Палитра действий", Call: "IncidentCard_PaletteButton"}
        , {X: 20, Y: 524, W: 212, Text: "Текущая цель", Call: "IncidentCard_CurrentButton"}
        , {X: 20, Y: 566, W: 212, Text: "Новая карточка цели", Call: "IncidentCard_NewButton"}
        , {X: 252, Y: 524, W: 180, Text: "Добавить заметку", Call: "IncidentCard_AddNoteButton"}
        , {X: 444, Y: 524, W: 192, Text: "Статья из поиска", Call: "IncidentCard_AddLawButton"}
        , {X: 648, Y: 524, W: 192, Text: "Обновить chatlog", Call: "IncidentCard_ChatButton"}
        , {X: 252, Y: 566, W: 180, Text: "Права (памятка)", Call: "IncidentCard_RightsButton"}
        , {X: 444, Y: 566, W: 192, Text: "Экспорт TXT", Call: "IncidentCard_ExportButton"}
        , {X: 648, Y: 566, W: 192, Text: "Сохранить", Call: "IncidentCard_SaveButton"}]
    for _, button in buttons {
        Gui, IncidentJournal:Add, Button, % "x" . button.X . " y" . button.Y . " w" . button.W . " h32 HwndbuttonHwnd", % button.Text
        callback := Func(button.Call)
        GuiControl, IncidentJournal:+g, %buttonHwnd%, %callback%
    }
    Gui, IncidentJournal:Font, s8 c%muted%, Segoe UI
    Gui, IncidentJournal:Add, Text, x20 y610 w820 h18 vIC_Next BackgroundTrans
    Gui, IncidentJournal:Add, Text, x20 y634 w820 h38 vIC_Status +Wrap BackgroundTrans
    IncidentCard_SetStatus("Данные сохраняются локально. Статья: откройте результат поиска и нажмите «Статья из поиска».")
    IncidentCard_RefreshGui()
    Capture_BeforeShow("IncidentJournal")
    showMode := IncidentCardPassive ? "NoActivate" : ""
    Gui, IncidentJournal:Show, w860 h682 %showMode%, AHK FOR GOS — карточка происшествия
    return !!IncidentCardHwnd
}

IncidentCard_SelectEntry(controlHwnd := 0, event := "", eventInfo := "", params*) {
    global IncidentCardEntries, IncidentCardCurrent
    GuiControlGet, index, IncidentJournal:, IC_List
    if (!IncidentCardEntries.HasKey(index) || (IsObject(IncidentCardCurrent) && IncidentCardEntries[index].RecordID = IncidentCardCurrent.RecordID))
        return false
    if !IncidentCard_SaveFromGui() {
        IncidentCard_SetStatus("Не удалось сохранить заметки; переход отменён.")
        return false
    }
    loaded := IncidentCard_LoadRecord(IncidentCardEntries[index].RecordID)
    if !IsObject(loaded) {
        IncidentCard_SetStatus("Карточка повреждена или недоступна. Исходный файл сохранён.")
        return false
    }
    IncidentCardCurrent := loaded
    IncidentCard_RefreshGui()
    return true
}

IncidentCard_CurrentButton(params*) {
    result := IncidentCard_SelectTarget()
    IncidentCard_RefreshGui()
    IncidentCard_SetStatus(result ? "Открыта карточка текущей цели." : "Выберите ID цели; если запись не сохранилась, проверьте доступ к папке данных.")
    return result
}

IncidentCard_NewButton(params*) {
    result := IncidentCard_SelectTarget(true)
    IncidentCard_RefreshGui()
    IncidentCard_SetStatus(result ? "Создана отдельная карточка. Предыдущая сохранена." : "Не удалось создать карточку: нет ID или папка недоступна для записи.")
    return result
}

IncidentCard_AddNoteButton(params*) {
    global IncidentCardCurrent, IncidentCardNotesHwnd, IncidentCardPassive
    if !IsObject(IncidentCardCurrent)
        return false
    if (!IncidentCardPassive) {
        GuiControl, IncidentJournal:Focus, IC_Notes
        return true
    }
    note := "", record := IncidentCardCurrent
    if !ServiceUI_Request("Заметка происшествия", "Введите заметку (до 512 символов), Enter — сохранить.", note, 512, 180, "", false, true)
        return false
    if (IncidentCardCurrent != record)
        return false
    if (StrLen(record.Notes) + StrLen(note) + 2 > 16000) {
        IncidentCard_SetStatus("Достигнут предел заметок (16 000 символов).")
        return false
    }
    record.Notes .= (record.Notes = "" ? "" : "`r`n") . note
    ok := IncidentCard_SaveRecord(record)
    IncidentCard_RefreshGui()
    IncidentCard_SetStatus(ok ? "Заметка сохранена." : "Ошибка записи заметки; текст остаётся в памяти до сохранения.")
    return ok
}

IncidentCard_AddLawButton(params*) {
    global IncidentCardCurrent, SearchResults, SearchCurrentIndex
    if (!IsObject(IncidentCardCurrent) || !IsObject(SearchResults) || !SearchResults.HasKey(SearchCurrentIndex)) {
        IncidentCard_SetStatus("Сначала откройте результат поиска по законам, затем добавьте его сюда.")
        return false
    }
    if !IncidentCard_SaveFromGui()
        return false
    added := IncidentCard_AddLaw(IncidentCardCurrent, SearchResults[SearchCurrentIndex].Item)
    ok := added && IncidentCard_SaveRecord(IncidentCardCurrent)
    IncidentCard_RefreshGui()
    IncidentCard_SetStatus(ok ? "Снимок статьи сохранён в карточке." : "Статья уже добавлена, достигнут предел 16 норм или запись недоступна.")
    return ok
}

IncidentCard_ChatButton(params*) {
    global IncidentCardCurrent
    if (!IsObject(IncidentCardCurrent) || !IncidentCard_SaveFromGui())
        return false
    count := IncidentCard_CollectChat(IncidentCardCurrent)
    ok := IncidentCard_SaveRecord(IncidentCardCurrent)
    IncidentCard_RefreshGui()
    IncidentCard_SetStatus(ok ? "Добавлено фрагментов: " . count . ". Источник — последние 80 прочитанных строк chatlog." : "Ошибка сохранения chatlog; фрагменты остаются в памяти.")
    return ok
}

IncidentCard_RightsButton(params*) {
    return Guide_Toggle(24)
}

IncidentCard_PaletteButton(params*) {
    global IncidentCardCurrent
    if (!IncidentCard_TargetMatches(IncidentCardCurrent, IncidentCard_CurrentTarget())) {
        IncidentCard_SetStatus("Цель карточки отличается от текущей. Выберите её ID или откройте карточку текущей цели.")
        return false
    }
    if (!IncidentCard_SaveFromGui() || !IsFunc("CommandPalette_Open"))
        return false
    return Func("CommandPalette_Open").Call()
}

IncidentCard_ExportButton(params*) {
    global IncidentCardCurrent
    if !IncidentCard_SaveFromGui()
        return false
    path := IncidentCard_Export(IncidentCardCurrent)
    IncidentCard_SetStatus(path != "" ? "Экспорт: " . path : "Не удалось создать экспорт TXT.")
    return path != ""
}

IncidentCard_SaveButton(params*) {
    result := IncidentCard_SaveFromGui()
    IncidentCard_SetStatus(result ? "Карточка сохранена." : "Ошибка сохранения; проверьте доступ к папке данных.")
    return result
}

IncidentCard_Close(params*) {
    global IncidentCardHwnd, IncidentCardListHwnd, IncidentCardNotesHwnd
    if !IncidentCard_SaveFromGui() {
        IncidentCard_SetStatus("Не удалось сохранить карточку. Окно оставлено открытым.")
        return false
    }
    Gui, IncidentJournal:Destroy
    IncidentCardHwnd := 0, IncidentCardListHwnd := 0, IncidentCardNotesHwnd := 0
    return true
}

IncidentCard_Shutdown() {
    return IncidentCard_Close()
}

IncidentJournalGuiClose() {
    IncidentCard_Close()
}

IncidentJournalGuiEscape() {
    IncidentCard_Close()
}
