TextCommands_RunRegression() {
    global
    saved := {}, names := ["Trig_GuidePDP", "Trig_GuideSVU", "Trig_GuideSignals", "Trig_Intro", "Trig_GpsD", "Trig_GpsOS", "CustomFunctions"]
    for _, name in names
        saved[name] := GetDynamicGlobalValue(name)
    try {
        Trig_GuidePDP := "!пдп", Trig_GuideSVU := "!сву", Trig_GuideSignals := "!сигналы", Trig_Intro := "!предст"
        Trig_GpsD := "!д", Trig_GpsOS := "!ос", CustomFunctions := [{Trigger: "!миг"}]
        for _, pair in [["!пдп", "!glg"], ["!сву", "!cde"], ["!сигналы", "!cbuyfks"], ["!предст", "!ghtlcn"], ["!bind", "!иштв"]]
            AuditAssert("TXT keyboard mapping " . pair[1], TextCommands_LayoutVariant(pair[1]) = pair[2])
        for _, text in ["!pdp", "!glg", "!ПДП"] {
            action := PrivateText_Resolve(text)
            AuditAssert("TXT aliases share PDP action " . text, IsObject(action) && action.Kind = "token" && action.Token = "GuidePDP")
        }
        for _, text in ["!svu", "!cde", "!signals", "!cbuyfks", "!intro", "!ghtlcn"] {
            action := PrivateText_Resolve(text)
            expected := InStr("|!svu|!cde|", "|" . text . "|") ? "GuideSVU" : (InStr("|!signals|!cbuyfks|", "|" . text . "|") ? "GuideSignals" : "Intro")
            AuditAssert("TXT English/layout route " . text, IsObject(action) && action.Token = expected)
        }
        action := PrivateText_Resolve("!house155")
        AuditAssert("TXT English GPS preserves the number", IsObject(action) && action.Kind = "gps" && action.Down = 15 && action.Number = 155)
        action := PrivateText_Resolve("!l10000")
        AuditAssert("TXT keyboard-layout GPS preserves the number", IsObject(action) && action.Kind = "gps" && action.Number = 10000)
        action := PrivateText_Resolve("!searchuk")
        AuditAssert("TXT English law search preserves mode", IsObject(action) && action.Kind = "search" && action.Mode = "UK")
        action := PrivateText_Resolve("!vbu")
        AuditAssert("TXT user command supports the other layout", IsObject(action) && action.Kind = "custom" && action.Index = 1)
        for _, text in TextCommands_OpenerTriggers()
            AuditAssert("TXT opener remains reserved " . text, GetReservedTextTriggerSet().HasKey(text) && PrivateText_Resolve(text).Kind = "opener")
        Trig_GuideSVU := "!pdp"
        action := PrivateText_Resolve("!pdp")
        AuditAssert("TXT configured trigger wins over English alias", IsObject(action) && action.Token = "GuideSVU")
        Trig_GuidePDP := ""
        AuditAssert("TXT disabled trigger has no layout alias", !IsObject(PrivateText_Resolve("!glg")))
        mode := "Только окно AHK"
        PrivateText_NormalizeMode(mode)
        AuditAssert("TXT UI mode labels preserve private-only config", mode = "Окно AHK" && PrivateText_ModeToUiLabel(mode) = "Только окно AHK")
        mode := "Чат + окно AHK"
        PrivateText_NormalizeMode(mode)
        AuditAssert("TXT UI mode labels preserve combined config", mode = "Игровой чат" && PrivateText_ModeToUiLabel(mode) = "Чат + окно AHK")
    } finally {
        for name, value in saved
            SetDynamicGlobalValue(name, value)
    }
}
