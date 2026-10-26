; Searchable command entry. The existing dispatcher remains the only executor.
global CommandPaletteResults := "", CommandPalettePreview := ""
global CommandPaletteRows := []
global CommandPaletteSelection := 1
global CommandPaletteLastQuery := ""
global CommandPaletteSession := ""

CommandPalette_Normalize(text) {
    StringLower, text, text
    text := StrReplace(text, "ё", "е")
    return Trim(RegExReplace(text, "[^a-zа-я0-9]+", " "))
}

CommandPalette_Synonyms(token) {
    static words := {Intro: "представиться представление показать жетон", Cuff: "наручники надеть связать задержать cuff"
        , Search: "обыск обыскать досмотр досмотреть", Rights: "права зачитать миранда"
        , GuideRights: "права памятка окно текст", GpsD: "дом дома домой gps house", GpsOS: "организация офис gps org"
        , PersonalFile: "досье личное дело игрока", VehicleLookup: "номер автомобиль машина владелец"
        , StopChase: "остановить требование остановки транспорт", Chase: "погоня начать преследование"
        , GuideSignals: "сигналы спецоперации вгп поезд расписание", Su: "розыск звезды объявить"
        , LawSearchSubmit: "найти искать закон законодательство статья поиск", EnterID: "ввод ид id игрок"
        , Deject: "высадить вытолкнуть машина", InCar: "посадить машину конвой", Arrest: "арест посадить тюрьма"
        , Fine: "штраф выписать", Protocol: "протокол оформить", Doc: "удостоверение документы показать"
        , SOS: "помощь сос подкрепление", PatrolStart: "патруль начать заступить", PostStart: "пост заступить"
        , OpenSettings: "настройки параметры меню", TextCommandInput: "палитра команды поиск действий"
        , IncidentCard: "карточка происшествие дело задержание заметки", ActionTrace: "результат ошибка шаг журнал действие повтор"
        , BlockBuilder: "конструктор сценарий блоки последовательность редактор", Training: "тренировка обучение песочница тест офлайн"
        , GPSCalibration: "гпс gps настройка калибровка скорость стрелки"}
    return words.HasKey(token) ? words[token] : ""
}

CommandPalette_Catalog() {
    global CustomFunctions
    rows := []
    for _, meta in GetBindCatalog() {
        if (meta.Token = "TextCommandInput")
            continue
        hotkey := meta.HotkeyVar != "" ? GetDynamicGlobalValue(meta.HotkeyVar) : ""
        trigger := meta.TriggerVar != "" ? GetDynamicGlobalValue(meta.TriggerVar) : ""
        action := {Kind: "token", Token: meta.Token}
        if (meta.Token = "GpsD" || meta.Token = "GpsOS")
            action := {Kind: "gps", Name: meta.Token = "GpsD" ? "GPS Д" : "GPS ОС", Down: meta.Token = "GpsD" ? 15 : 16, Number: ""}
        rows.Push({Name: meta.Label, Category: meta.Category, Hint: meta.Hint, Trigger: trigger, Hotkey: hotkey
            , Key: meta.Token, Action: action, Search: CommandPalette_Normalize(meta.Label . " " . meta.Token . " " . trigger . " " . CommandPalette_Synonyms(meta.Token))})
    }
    for index, item in CustomFunctions {
        rows.Push({Name: item.Name, Category: "Мои сценарии", Hint: "Пользовательская последовательность", Trigger: item.Trigger
            , Hotkey: item.Hotkey, Key: "CustomFunction:" . index, Action: {Kind: "custom", Index: index}
            , Search: CommandPalette_Normalize(item.Name . " " . item.Trigger)})
    }
    for _, tool in [{Key: "IncidentCard", Name: "Карточка происшествия", Func: "IncidentCard_Open"}
        , {Key: "ActionTrace", Name: "Результат последнего действия", Func: "ActionTrace_Open"}
        , {Key: "BlockBuilder", Name: "Конструктор действий", Func: "OpenCustomFunctionBuilder"}
        , {Key: "Training", Name: "Учебный режим", Func: "Training_Open"}
        , {Key: "GPSCalibration", Name: "Настроить GPS", Func: "GPS_OpenCalibration"}] {
        rows.Push({Name: tool.Name, Category: "Инструменты", Hint: "Открывает локальное окно AHK", Trigger: "", Hotkey: ""
            , Key: tool.Key, Action: {Kind: "tool", Function: tool.Func}
            , Search: CommandPalette_Normalize(tool.Name . " " . CommandPalette_Synonyms(tool.Key))})
    }
    return rows
}

CommandPalette_ActionKey(action) {
    if !IsObject(action)
        return ""
    if (action.Kind = "token")
        return action.Token
    if (action.Kind = "custom")
        return "CustomFunction:" . action.Index
    if (action.Kind = "gps")
        return action.Down = 15 ? "GpsD" : "GpsOS"
    return action.Kind . ":" . action.Label . action.Mode
}

CommandPalette_NearWord(a, b) {
    ; A one-edit comparison is bounded and sufficient for a small action catalog.
    if (a = b)
        return true
    la := StrLen(a), lb := StrLen(b)
    if (la < 4 || lb < 4 || Abs(la - lb) > 1)
        return false
    i := 1, j := 1, edits := 0
    while (i <= la && j <= lb) {
        if (SubStr(a, i, 1) = SubStr(b, j, 1)) {
            i++, j++
            continue
        }
        if (++edits > 1)
            return false
        if (la >= lb)
            i++
        if (lb >= la)
            j++
    }
    return edits + (i <= la || j <= lb ? 1 : 0) <= 1
}

CommandPalette_Score(query, haystack) {
    if (query = "")
        return 1
    if (query = haystack)
        return 900
    score := 0, matched := 0
    for _, word in StrSplit(query, " ") {
        if (word = "как" || word = "мне" || word = "хочу" || word = "нужно" || word = "игрока")
            continue
        found := 0
        for _, candidate in StrSplit(haystack, " ") {
            points := word = candidate ? 80 : (InStr(candidate, word) = 1 ? 40 : (CommandPalette_NearWord(word, candidate) ? 20 : 0))
            found := Max(found, points)
        }
        if (!found)
            return 0
        score += found, matched++
    }
    return matched ? score : 0
}

CommandPalette_Find(query, limit := 6) {
    exact := PrivateText_Resolve(query), exactKey := CommandPalette_ActionKey(exact)
    normalized := CommandPalette_Normalize(query)
    layout := CommandPalette_Normalize(TextCommands_LayoutVariant(query))
    matches := []
    for _, row in CommandPalette_Catalog() {
        row.Score := Max(CommandPalette_Score(normalized, row.Search), CommandPalette_Score(layout, row.Search))
        if (exactKey != "" && row.Key = exactKey) {
            row.Score := 10000
            row.Action := exact
        }
        if (!row.Score)
            continue
        position := matches.Length() + 1
        for index, existing in matches {
            if (row.Score > existing.Score) {
                position := index
                break
            }
        }
        matches.InsertAt(position, row)
        if (matches.Length() > limit)
            matches.Pop()
    }
    ; Search/document aliases need not be individual catalog entries.
    if (IsObject(exact) && exact.Kind != "opener" && exactKey != "" && (!matches.Length() || matches[1].Score < 10000))
        matches.InsertAt(1, {Name: query, Category: "TXT-команда", Key: exactKey, Action: exact, Score: 10000})
    if (matches.Length() > limit)
        matches.Pop()
    return matches
}

CommandPalette_Describe(row) {
    global UserID, CurrentProfile
    if !IsObject(row)
        return "Совпадений нет. Попробуйте: зачитать права, надеть наручники, дом, карточка."
    text := row.Category . " · " . row.Hint . "`n"
    text .= "Бинд: " . (row.Hotkey != "" ? row.Hotkey : "не назначен") . "   TXT: " . row.Trigger . "`n"
    text .= "Профиль: " . CurrentProfile . "   Цель: " . (HasCurrentID() ? UserID : "не выбрана")
    static templates := {Intro: "T_Intro", Rights: "RP_Rights", Cuff: "RP_Cuff", Doc: "RP_Doc", Search: "RP_Search"
        , Arrest: "RP_Arrest", Fine: "RP_Fine", Protocol: "RP_Protocol", PatrolStart: "T_PatrolStart", PostStart: "T_PostStart"}
    if templates.HasKey(row.Key) {
        sample := ApplyActionTemplate(GetDynamicGlobalValue(templates[row.Key]))
        text .= "`nПример: " . SubStr(StrReplace(StrReplace(sample, "`r", ""), "`n", " / "), 1, 130)
    }
    return text
}

CommandPalette_Update(state) {
    global CommandPaletteRows, CommandPaletteSelection, CommandPaletteLastQuery, CommandPaletteSession
    if (CommandPaletteLastQuery != state.Value || !IsObject(CommandPaletteRows)) {
        CommandPaletteRows := CommandPalette_Find(state.Value)
        CommandPaletteSelection := 1
        CommandPaletteLastQuery := state.Value
    }
    lines := ""
    for index, row in CommandPaletteRows
        lines .= (index = CommandPaletteSelection ? ">  " : "    ") . row.Name . "  ·  " . row.Category . "`n"
    GuiControl, ServiceInput:, CommandPaletteResults, % lines = "" ? "Ничего не найдено" : RTrim(lines, "`n")
    GuiControl, ServiceInput:, CommandPalettePreview, % CommandPalette_Describe(CommandPaletteRows[CommandPaletteSelection])
    if IsObject(CommandPaletteSession)
        CommandPaletteSession.Selected := CommandPaletteRows[CommandPaletteSelection]
}

CommandPalette_KeyDown(state, hook, vk) {
    global CommandPaletteRows, CommandPaletteSelection
    if (vk != 0x26 && vk != 0x28 && vk != 9)
        return false
    count := CommandPaletteRows.Length()
    if (!count)
        return true
    if (vk = 9) {
        row := CommandPaletteRows[CommandPaletteSelection]
        state.Value := row.Trigger != "" ? row.Trigger : row.Name
        CommandPalette_Update(state)
        return true
    }
    CommandPaletteSelection := Mod(CommandPaletteSelection - 1 + (vk = 0x26 ? count - 1 : 1), count) + 1
    CommandPalette_Update(state)
    return true
}

CommandPalette_Char(state, hook, chars) {
    if (chars != " " || SubStr(state.Value, 1, 1) != "!")
        return
    exact := PrivateText_Resolve(Trim(state.Value))
    if IsObject(exact) {
        state.Value := Trim(state.Value)
        state.ObserverConfirmed := 1
        hook.Stop()
    }
}

CommandPalette_AllowDesktop() {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", pid)
    return hwnd && pid = DllCall("GetCurrentProcessId", "UInt")
}

CommandPalette_Open(params*) {
    global PrivateTextInputBusy, CommandPaletteRows, CommandPaletteSelection, CommandPaletteLastQuery, CommandPaletteSession
    if (PrivateTextInputBusy || PhysicalInputBusy || IsObject(IDCaptureState) || ServiceUI_IsInputActive())
        return PrivateText_ReportBlocked("Ввод занят. Завершите действие или отмените его.")
    desktop := !GameLocator_IsActive() && CommandPalette_AllowDesktop()
    if (!desktop && !Training_IsActive() && !GameLocator_IsActive() && !ServiceUI_IsTest())
        return PrivateText_ReportBlocked("Откройте палитру из меню AHK или активной игры.")
    PrivateTextInputBusy := 1
    CommandPaletteRows := [], CommandPaletteSelection := 1, CommandPaletteLastQuery := Chr(1)
    session := {Selected: ""}, CommandPaletteSession := session
    observer := {Update: Func("CommandPalette_Update"), KeyDown: Func("CommandPalette_KeyDown"), Char: Func("CommandPalette_Char"), AllowDesktop: desktop}
    epoch := AutomationEpoch, profile := CurrentProfile, seed := ""
    try {
        Loop {
            value := ""
            prepare := desktop || Training_IsActive() ? "" : Func("PrivateText_PrepareChat").Bind(epoch)
            if !ServiceUI_Request("Палитра команд", "Ищите по смыслу, названию или TXT: «зачитать права», «наручники», !предст.", value, 180, 90, seed, false, true, "", prepare, observer)
            {
                if (ServiceUILastInputError != "")
                    PrivateText_ReportBlocked(ServiceUILastInputError)
                return false
            }
            if (epoch != AutomationEpoch || profile != CurrentProfile)
                return false
            if (Trim(value) = "") {
                if ServiceUI_IsTest()
                    return false
                seed := ""
                continue
            }
            if (BindMenuEditMode && TryHandleBindMenuLine(value))
                return true
            action := PrivateText_Resolve(value)
            if !IsObject(action) {
                if (CommandPaletteLastQuery != value || !IsObject(session.Selected)) {
                    finalRows := CommandPalette_Find(value)
                    session.Selected := finalRows[1]
                }
                if IsObject(session.Selected)
                    action := session.Selected.Action
            }
            if (!IsObject(action)) {
                if ServiceUI_IsTest()
                    return false
                seed := value
                continue
            }
            if (action.Kind = "opener") {
                seed := ""
                continue
            }
            ; Release the input hook before any dispatcher can acquire input.
            PrivateTextInputBusy := 0
            if (action.Kind = "tool")
                return Func(action.Function).Call()
            return PrivateText_Dispatch(action, epoch)
        }
    } finally {
        PrivateTextInputBusy := 0
        CommandPaletteSession := ""
    }
}

Tools_OpenPalette(params*) {
    return CommandPalette_Open()
}

Tools_OpenIncident(params*) {
    return IncidentCard_Open()
}

Tools_OpenTrace(params*) {
    return ActionTrace_Open()
}

Tools_OpenBuilder(params*) {
    OpenCustomFunctionBuilder()
}

Tools_OpenTraining(params*) {
    return Training_Open()
}

Tools_OpenGPS(params*) {
    return GPS_OpenCalibration()
}
