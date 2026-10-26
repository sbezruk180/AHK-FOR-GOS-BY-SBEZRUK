CommandPalette_RunRegression() {
    global CustomFunctions, Trig_Intro, UserID
    saved := CustomFunctions, savedTrigger := Trig_Intro
    try {
        Trig_Intro := "!предст"
        CustomFunctions := [{Name: "Особый осмотр", Trigger: "!осмотртест", Hotkey: "^!9", Script: "SEND /me осмотрел"}]
        CustomFunctions.Push({Name: "Свой incident", Trigger: "!incident", Hotkey: "", Script: "NOTICE keep"})
        conflict := PrivateText_Resolve("!incident")
        AuditAssert("Palette tool aliases never replace configured custom commands", IsObject(conflict) && conflict.Kind = "custom" && conflict.Index = 2)
        results := CommandPalette_Find("зачитать права")
        AuditAssert("Palette natural-language rights", results.Length() && results[1].Key = "Rights")
        results := CommandPalette_Find("надеть наручники")
        AuditAssert("Palette natural-language cuffs", results.Length() && results[1].Key = "Cuff")
        results := CommandPalette_Find("наручнки")
        AuditAssert("Palette one-character typo", results.Length() && results[1].Key = "Cuff")
        results := CommandPalette_Find("!предст")
        AuditAssert("Palette exact configured command wins", results.Length() && results[1].Key = "Intro" && results[1].Score = 10000)
        results := CommandPalette_Find(TextCommands_LayoutVariant("!предст"))
        AuditAssert("Palette wrong keyboard layout resolves", results.Length() && results[1].Key = "Intro")
        results := CommandPalette_Find("осмотртест")
        AuditAssert("Palette retains legacy custom functions without Enabled field", results.Length() && results[1].Action.Kind = "custom")
        results := CommandPalette_Find("настроить gps")
        AuditAssert("Palette exposes working GPS calibration", results.Length() && results[1].Action.Function = "GPS_OpenCalibration")
        results := CommandPalette_Find("абракадабраэюъщ")
        AuditAssert("Palette does not invent matches", !results.Length())
        results := CommandPalette_Find("", 3)
        AuditAssert("Palette results bounded", results.Length() = 3)
        configProbe := AppHost_DataDir() . "\palette-profile-probe.ini"
        if FileExist(configProbe)
            FileDelete, %configProbe%
        CheckedIniWrite("Empty", configProbe, "Profiles", "Last")
        AuditAssert("Diagnostics missing legacy binding keys are not ERROR conflicts", V1_CheckProfileConflicts(configProbe, conflictDetail))
        CheckedIniWrite("!е", configProbe, "Profile_Empty", "Bind_EnterID")
        CheckedIniWrite("!t", configProbe, "Profile_Empty", "Bind_OpenBindsTab")
        AuditAssert("Diagnostics compares imported Russian and English physical hotkeys", !V1_CheckProfileConflicts(configProbe, conflictDetail))
        if FileExist(configProbe)
            FileDelete, %configProbe%
        AuditAssert("Palette bounded edit distance", CommandPalette_NearWord("наручники", "наручнки") && !CommandPalette_NearWord("дом", "дым") && !CommandPalette_NearWord("права", "правильно"))
        rows := CommandPalette_Catalog(), toolsOK := true
        for _, row in rows {
            if (row.Action.Kind = "tool" && !IsFunc(row.Action.Function))
                toolsOK := false
        }
        AuditAssert("Palette all tool handlers implemented", toolsOK)
        preview := CommandPalette_Describe(results[1])
        AuditAssert("Palette preview identifies actual profile", InStr(preview, CurrentProfile))
    } catch e {
        AuditAssert("Palette exception: " . e.Message . " | " . e.What . " | " . e.Extra . " | " . e.Line, false)
    } finally {
        CustomFunctions := saved, Trig_Intro := savedTrigger
    }
}

CommandPalette_RunDesktopChecks() {
    global CommandPaletteRows, CommandPaletteSelection, CommandPaletteLastQuery, CommandPaletteSession
    Gui, PaletteFixture:New, +HwndfixtureHwnd -Caption +ToolWindow
    Gui, PaletteFixture:Show, x40 y40 w160 h80, Palette owner
    WinActivate, ahk_id %fixtureHwnd%
    state := ServiceUI_NewInputState("Палитра команд", "Поиск действий", 180, 90, "наручники", false
        , AutomationEpoch, fixtureHwnd, CurrentProfile, TickNow())
    state.AllowDesktop := true, state.ForcePrivacy := false
    state.Observer := {Update: Func("CommandPalette_Update"), KeyDown: Func("CommandPalette_KeyDown"), Char: Func("CommandPalette_Char")}
    CommandPaletteRows := [], CommandPaletteLastQuery := Chr(1), CommandPaletteSelection := 1, CommandPaletteSession := {}
    try {
        DesktopSmoke_Assert("palette actual passive window opens", ServiceUI_CreateInputGui(state))
        DesktopSmoke_Assert("palette preserves foreground owner", DllCall("GetForegroundWindow", "Ptr") = fixtureHwnd)
        GuiControlGet, listText, ServiceInput:, CommandPaletteResults
        DesktopSmoke_Assert("palette renders live search matches", InStr(listText, "Cuff"))
        state.Value := "права"
        ServiceUI_InputTick(state)
        ; The observer is also callable before a request timer acquires the state.
        CommandPalette_Update(state)
        DesktopSmoke_Assert("palette updates preview after changed query", CommandPaletteRows.Length() > 0)
    } finally {
        Gui, ServiceInput:Destroy
        Gui, PaletteFixture:Destroy
        CommandPaletteSession := ""
    }
}
