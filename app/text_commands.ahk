; Shared aliases for chat hotstrings and passive TXT input. Configured commands
; win over optional aliases; disabled commands do not acquire English aliases.
TextCommands_LayoutVariant(text) {
    static ru := "¸éöóêåíãøùçõúôûâàïðîëäæýÿ÷ñìèòüáþ."
    static en := Chr(96) . "qwertyuiop[]asdfghjkl;'zxcvbnm,./"
    StringLower, text, text
    russian := RegExMatch(text, "[à-ÿ¸]")
    from := russian ? ru : en, to := russian ? en : ru
    result := ""
    Loop, Parse, text
    {
        char := A_LoopField
        position := InStr(from, char, true)
        result .= position ? SubStr(to, position, 1) : char
    }
    return result
}

TextCommands_OpenerTriggers() {
    return ["!áèíä", "!bind", TextCommands_LayoutVariant("!áèíä"), TextCommands_LayoutVariant("!bind")]
}

TextCommands_IsOpener(text) {
    for _, trigger in TextCommands_OpenerTriggers()
        if (text = trigger)
            return true
    return false
}

TextCommands_EnglishTrigger(token) {
    static names := {GuideSignals: "!signals", BindMenu: "!menu", Codes: "!codes", Search: "!frisk", Search_RUN: "!search", GpsD: "!house", GpsOS: "!org"}
    if names.HasKey(token)
        return names[token]
    StringLower, token, token
    return "!" . token
}

TextCommands_GetAliasRoutes() {
    global CustomFunctions
    sources := [{Trigger: "!ìåíþ", English: "!menu", Action: {Kind: "label", Label: "DoBindMenuToggle"}}
        , {Trigger: "!menu", English: "!menu", Action: {Kind: "label", Label: "DoBindMenuToggle"}}
        , {Trigger: "!êîäû", English: "!codes", Action: {Kind: "label", Label: "DoServiceCodesGui"}}
        , {Trigger: "!ïíàéòè", English: "!search", Action: {Kind: "label", Label: "DoLawSearchClipboard"}}]
    for _, meta in GetBindCatalog() {
        if (!BindCatalog_IsRegistrable(meta) || meta.TriggerVar = "")
            continue
        trigger := GetDynamicGlobalValue(meta.TriggerVar)
        NormalizeTextTrigger(trigger)
        if (trigger = "")
            continue
        action := {Kind: "token", Token: meta.Token}
        if (meta.Token = "GpsD" || meta.Token = "GpsOS")
            action := {Kind: "gps", Name: meta.Token = "GpsD" ? "GPS Ä" : "GPS ÎÑ", Down: meta.Token = "GpsD" ? 15 : 16, Number: ""}
        sources.Push({Trigger: trigger, English: TextCommands_EnglishTrigger(meta.Token), Action: action})
    }
    for index, item in CustomFunctions {
        trigger := item.Trigger
        NormalizeTextTrigger(trigger)
        if (trigger != "")
            sources.Push({Trigger: trigger, English: "", Action: {Kind: "custom", Index: index}})
    }
    for trigger, mode in PrivateText_SearchModes()
        sources.Push({Trigger: trigger, English: "!search" . mode, Action: {Kind: "search", Mode: mode}})
    ; Claim every explicit command first, including user commands and reserved
    ; opener variants, before considering any automatically generated name.
    claimed := {}
    for _, trigger in TextCommands_OpenerTriggers()
        claimed[trigger] := true
    for _, source in sources
        claimed[source.Trigger] := true
    routes := []
    for _, source in sources {
        candidates := [TextCommands_LayoutVariant(source.Trigger)]
        if (source.English != "") {
            candidates.Push(source.English)
            candidates.Push(TextCommands_LayoutVariant(source.English))
        }
        for _, trigger in candidates {
            if (trigger = "" || claimed.HasKey(trigger))
                continue
            claimed[trigger] := true
            routes.Push({Trigger: trigger, Canonical: source.Trigger, Action: source.Action})
        }
    }
    return routes
}

TextCommands_ResolveAlias(text) {
    for _, route in TextCommands_GetAliasRoutes() {
        if (route.Trigger = text)
            return PrivateText_ResolveExact(route.Canonical)
        if (route.Action.Kind = "gps" && MatchGpsEnterCommand(text, route.Trigger, number)) {
            action := route.Action.Clone()
            action.Number := number
            return action
        }
    }
    return ""
}

TextCommands_RegisterAliases(ByRef ok, ByRef errText, ByRef usedTriggers) {
    for _, route in TextCommands_GetAliasRoutes() {
        if usedTriggers.HasKey(route.Trigger)
            continue
        action := route.Action, previous := ""
        if (action.Kind = "gps") {
            if !RegisterGpsInputTextTrigger("Alias " . route.Trigger, previous, route.Trigger, action.Name, action.Down, errText, usedTriggers)
                ok := 0
        } else if (action.Kind = "search") {
            if !RegisterSearchModeTrigger("Alias " . route.Trigger, previous, route.Trigger, action.Mode, LawSearch_GetDocName(action.Mode), errText, usedTriggers)
                ok := 0
        } else if (action.Kind = "custom") {
            try {
                pattern := ":?:" . route.Trigger
                Hotstring(pattern, Func("RunCustomFunctionTrigger").Bind(action.Index), "On")
                TrackRegisteredGameTextHotstring(pattern)
                usedTriggers[route.Trigger] := "Alias " . route.Canonical
            } catch error {
                ok := 0
                errText .= route.Trigger . " -> " . error.Message . "`n"
            }
        } else {
            label := action.Kind = "token" ? GetBoundLabelByToken(action.Token) : action.Label
            if (label != "" && !RegisterTextTrigger("Alias " . route.Trigger, previous, route.Trigger, label, errText, usedTriggers))
                ok := 0
        }
    }
}
