; Private TXT command entry reuses the passive, capture-protected service input.
global PrivateTextInputBusy := 0
global PrivateTextOpenerContext := Func("PrivateText_OpenerAllowed")

PrivateText_NormalizeMode(ByRef mode) {
    if (mode != "Окно AHK")
        mode := "Игровой чат"
}

PrivateText_OpenerAllowed(hotkeyName := "") {
    global GAME_PROCESS_NAME
    return GAME_PROCESS_NAME != "" && !PhysicalInputBusy && !IsObject(IDCaptureState)
        && !PrivateTextInputBusy && WinActive("ahk_exe " . GAME_PROCESS_NAME)
}

PrivateText_Resolve(text) {
    global Trig_GpsD, Trig_GpsOS, CustomFunctions
    text := Trim(text)
    if (text = "")
        return ""
    if (SubStr(text, 1, 1) != "!")
        text := "!" . text
    if (text = "!бинд")
        return {Kind: "opener"}
    if (text = "!меню")
        return {Kind: "label", Label: "DoBindMenuToggle"}
    if (text = "!коды")
        return {Kind: "label", Label: "DoServiceCodesGui"}
    for _, gps in [{Trigger: Trig_GpsD, Down: 15, Name: "GPS Д"}, {Trigger: Trig_GpsOS, Down: 16, Name: "GPS ОС"}] {
        trigger := gps.Trigger
        NormalizeTextTrigger(trigger)
        if (trigger = "")
            continue
        if (text = trigger)
            return {Kind: "gps", Name: gps.Name, Down: gps.Down, Number: ""}
        if MatchGpsEnterCommand(text, trigger, number)
            return {Kind: "gps", Name: gps.Name, Down: gps.Down, Number: number}
    }
    for _, meta in GetBindCatalog() {
        if (!BindCatalog_IsRegistrable(meta) || meta.TriggerVar = "")
            continue
        trigger := GetDynamicGlobalValue(meta.TriggerVar)
        NormalizeTextTrigger(trigger)
        if (trigger != "" && trigger = text)
            return {Kind: "token", Token: meta.Token}
    }
    for index, item in CustomFunctions {
        trigger := item.Trigger
        NormalizeTextTrigger(trigger)
        if (trigger != "" && trigger = text)
            return {Kind: "custom", Index: index}
    }
    modes := PrivateText_SearchModes()
    if (modes.HasKey(text) || text = "!пнайти")
        return {Kind: "search", Mode: modes.HasKey(text) ? modes[text] : ""}
    return ""
}

PrivateText_Open() {
    global PrivateTextInputBusy, BindMenuEditMode, Trig_GpsD, Trig_GpsOS
    if (PrivateTextInputBusy || PhysicalInputBusy || IsObject(IDCaptureState) || ServiceUI_IsInputActive())
        return false
    if (!ServiceUI_IsTest() && !GameLocator_IsActive())
        return false
    PrivateTextInputBusy := 1
    epoch := AutomationEpoch, profile := CurrentProfile, seed := ""
    prompt := "Введите свой TXT-бинд, например !предст или !д155. Текст не отправляется в чат."
    try {
        if (!ServiceUI_IsTest() && isInChat() = 1) {
            if !SafeSend("{Esc}", "Event", epoch)
                return false
            Sleep, 80
        }
        Loop {
            command := ""
            if !ServiceUI_Request("Текстовая команда", prompt, command, 180, 60, seed, !BindMenuEditMode, true) {
                if (ServiceUILastInputError != "")
                    ServiceUI_Notify(ServiceUILastInputError, 4500, "WARN")
                return false
            }
            if (epoch != AutomationEpoch || profile != CurrentProfile)
                return false
            if (BindMenuEditMode && TryHandleBindMenuLine(command))
                return true
            action := PrivateText_Resolve(command)
            if !IsObject(action) {
                if ServiceUI_IsTest()
                    return false
                prompt := "Команда не найдена. Исправьте TXT-бинд или нажмите Esc для отмены."
                seed := command
                continue
            }
            if (action.Kind = "opener") {
                seed := ""
                continue
            }
            return PrivateText_Dispatch(action, epoch)
        }
    } finally {
        PrivateTextInputBusy := 0
    }
}

PrivateText_Dispatch(action, epoch) {
    if (epoch != AutomationEpoch || !IsObject(action))
        return false
    if (action.Kind = "gps") {
        number := action.Number
        if (number = "" && !ServiceUI_Request("GPS", "Введите номер дома / организации и нажмите Enter.", number, 5, 45, "", false, true))
            return false
        return epoch = AutomationEpoch && RunGpsDialogAction(action.Name, action.Down, number, epoch)
    }
    if (action.Kind = "search") {
        query := ""
        if !ServiceUI_Request("Поиск законодательства", "Введите запрос и нажмите Enter. Пробелы разрешены.", query, 180, 60, "", false, true)
            return false
        if (epoch != AutomationEpoch || Trim(query) = "")
            return false
        if (action.Mode != "")
            LawSearch_SelectMode(action.Mode, action.Mode = "ALL" ? "всем материалам" : LawSearch_GetDocName(action.Mode), false)
        LawSearch_RunActive(query)
        return true
    }
    if (action.Kind = "custom") {
        RunCustomFunction(action.Index)
        return true
    }
    if (action.Kind = "token") {
        ExecuteBindToken(action.Token)
        return true
    }
    if (action.Kind = "label" && IsLabel(action.Label)) {
        label := action.Label
        SetTimer, %label%, -1
        return true
    }
    return false
}

PrivateText_RegisterOpener() {
    global PrivateTextOpenerContext, GameTextHotkeyContext
    Hotkey, If, % PrivateTextOpenerContext
    Hotstring(":?:!бинд", Func("PrivateText_Opener"), "On")
    Hotkey, If, % GameTextHotkeyContext
}

PrivateText_Opener(params*) {
    SetTimer, DoPrivateTextInput, -1
}

PrivateText_SearchModes() {
    static modes := {"!пвсе": "ALL", "!пук": "UK", "!пкоап": "KOAP", "!пупк": "UPK", "!пкас": "KAS", "!пфсб": "FSB", "!пфсин": "FSIN", "!пвс": "VS", "!псуд": "SUD", "!порд": "ORD", "!пгт": "GT", "!ппдд": "PDD", "!пфзоп": "FZOP", "!птк": "TK", "!птер": "TER", "!парг": "ARG", "!пву": "VU", "!пвв": "VV", "!поружие": "ORUZH", "!пкон": "KON"}
    return modes
}

GetReservedTextTriggerSet() {
    fixed := {"!меню": "BindMenu", "!menu": "BindMenu", "!бинд": "PrivateText", "!коды": "Codes", "!пнайти": "Search_RUN"}
    for trigger, mode in PrivateText_SearchModes()
        fixed[trigger] := "Search_" . mode
    return fixed
}
