; Game-only reference guides. The existing law window owns rendering/capture/focus.
; No chat queue entries, game memory access, hooks or recurring timers here.
global GuideCurrentPages := {}

Guide_GetCatalog() {
    static catalog := ""
    if !IsObject(catalog)
        catalog := [{Id: 21, Name: "СО: ВГП и RP-капты", Token: "GuideSignals", Trigger: "!сигналы"}]
    return catalog
}

Guide_GetMeta(id) {
    for _, meta in Guide_GetCatalog()
        if (meta.Id = id)
            return meta
    return ""
}

Guide_GetChapters(id) {
    if (id = 21)
        source := Guide_SignalsText()
    else
        return []
    chapters := []
    Loop, Parse, source, `n, `r
    {
        line := A_LoopField
        if (SubStr(line, 1, 4) = "=== ")
            chapters.Push({Title: SubStr(line, 5), Text: ""})
        else if (chapters.Length())
            chapters[chapters.Length()].Text .= line . "`r`n"
    }
    return chapters
}

Guide_GetPages(id) {
    static cache := {}, layoutKey := ""
    meta := Guide_GetMeta(id)
    if !IsObject(meta)
        return []
    layout := LawGui_GetLayout()
    key := layout.ContentW . "|" . layout.BodyH . "|" . layout.FontSize . "|" . A_ScreenDPI
    if (key != layoutKey)
        cache := {}, layoutKey := key
    if cache.HasKey(id)
        return cache[id]
    pages := []
    for _, chapter in Guide_GetChapters(id) {
        body := chapter.Title . "`r`n`r`n" . Trim(chapter.Text, "`r`n")
        parts := LawGui_MeasuredPages(body, layout.ContentW, Max(60, layout.BodyH - 52), layout.FontSize)
        for _, part in parts
            pages.Push(part . "`r`n`r`nPgUp / PgDn — листать | Esc — закрыть")
    }
    cache[id] := pages
    return pages
}

Guide_ShowPage(id, page := 1) {
    global GuideCurrentPages
    meta := Guide_GetMeta(id), pages := Guide_GetPages(id)
    if (!IsObject(meta) || !pages.Length())
        return false
    if !IsObject(GuideCurrentPages)
        GuideCurrentPages := {}
    page := Max(1, Min(pages.Length(), Round(page)))
    GuideCurrentPages[id] := page
    LawGui_Show(1, meta.Name . " (" . page . "/" . pages.Length() . ")", pages[page], 1)
    ApplyPersistentAlwaysOnTop()
    return true
}

Guide_Toggle(id, fromChat := false) {
    global current_doc, last_doc, SearchGuiVisible, SearchModeActive
    if !IsObject(Guide_GetMeta(id))
        return false
    if (current_doc = id) {
        CloseAllDocs()
        current_doc := 0
        return true
    }
    ; Search owns PgUp/PgDn while open. End it before handing navigation
    ; to the guide; otherwise the visible guide cannot be paged.
    if (SearchGuiVisible || SearchModeActive)
        Search_Close(0)
    CloseAllDocs()
    if !Guide_ShowPage(id)
        return false
    current_doc := id, last_doc := id
    if (fromChat)
        Helper_CloseChatAfterGui()
    return true
}

Guide_Navigate(direction) {
    global current_doc, GuideCurrentPages
    pages := Guide_GetPages(current_doc)
    if (!pages.Length())
        return false
    page := IsObject(GuideCurrentPages) && GuideCurrentPages.HasKey(current_doc) ? GuideCurrentPages[current_doc] : 1
    page += direction = "prev" ? -1 : 1
    if (page < 1)
        page := pages.Length()
    if (page > pages.Length())
        page := 1
    return Guide_ShowPage(current_doc, page)
}

Guide_LoadProfile(fileName, section) {
    for _, meta in Guide_GetCatalog() {
        hotkeyKey := "Bind_" . meta.Token, triggerKey := "Trig_" . meta.Token
        IniRead, hotkeyValue, %fileName%, %section%, %hotkeyKey%, %A_Space%
        IniRead, triggerValue, %fileName%, %section%, %triggerKey%, % meta.Trigger
        SetDynamicGlobalValue(hotkeyKey, Trim(hotkeyValue))
        SetDynamicGlobalValue(triggerKey, triggerValue)
    }
}

Guide_SignalsText() {
    text =
    (LTrim
    === Расписание спецподразделений
    ВГП — военно-грузовой поезд:
    03:30, 07:30, 15:30 и 19:30.

    RP-капты:
    10:00 и 19:00.

    На эти мероприятия собираются только спецподразделения.
    Сбор — за 20–30 минут до начала. Интервалы на следующих страницах рассчитаны от времени начала мероприятия.
    Точную точку сбора и задачу сообщает руководитель.

    === ВГП: начало и сбор
    Начало 03:30 — сбор 03:00–03:10.
    Начало 07:30 — сбор 07:00–07:10.
    Начало 15:30 — сбор 15:00–15:10.
    Начало 19:30 — сбор 19:00–19:10.

    Участники: только спецподразделения.
    Прибывайте на сбор по указаниям руководителя, заранее уточнив состав группы, точку и задачу.

    === RP-капты: начало и сбор
    Начало 10:00 — сбор 09:30–09:40.
    Начало 19:00 — сбор 18:30–18:40.

    Участники: только спецподразделения.
    Это время сбора до начала мероприятия, а не его длительность.
    Дополнительные условия участия уточняйте у руководителя.

    === Два доклада ВГП
    Предварительная точка:
    /d [ГАИ/УФСБ] Говорит лейтенант полиции Лукашенко, занял предварительную точку крушения ВГП - Лыткарино.

    Подтверждённая точка:
    /d [ГАИ/УФСБ] Говорит лейтенант полиции Лукашенко, точка крушения ВГП - Лыткарино.

    Окно показывает расписание и подсказки. Сообщения автоматически не отправляются.
    )
    return text
}
