; Checks use production text/layout/profile/viewer code, never a game client.
Guide_RunRegression() {
    global
    catalog := Guide_GetCatalog()
    AuditAssert("Guides: three separate reference documents", catalog.Length() = 3)
    timetable := Guide_SignalsText()
    timesOK := true
    for _, time in ["03:30", "07:30", "15:30", "19:30", "10:00", "19:00", "03:00Ц03:10", "07:00Ц07:10", "15:00Ц15:10", "19:00Ц19:10", "09:30Ц09:40", "18:30Ц18:40"]
        timesOK := timesOK && InStr(timetable, time)
    AuditAssert("Guides: server timetable and 20-30 minute gathering windows", timesOK && InStr(timetable, "только спецподразделени€") && !InStr(timetable, "¬”Ћ јЌ"))
    savedTriggers := {}, savedBinds := {}
    for _, meta in catalog {
        savedTriggers[meta.Token] := GetDynamicGlobalValue("Trig_" . meta.Token)
        savedBinds[meta.Token] := GetDynamicGlobalValue("Bind_" . meta.Token)
        SetDynamicGlobalValue("Trig_" . meta.Token, meta.Trigger)
        action := PrivateText_Resolve(meta.Trigger)
        AuditAssert("Guides: private TXT dispatch " . meta.Token, IsObject(action) && action.Kind = "token" && action.Token = meta.Token && IsLabel(GetBoundLabelByToken(meta.Token)))
        original := "", combined := ""
        for _, chapter in Guide_GetChapters(meta.Id)
            original .= chapter.Title . chapter.Text
        pages := Guide_GetPages(meta.Id)
        for _, page in pages
            combined .= StrReplace(page, "`r`n`r`nPgUp / PgDn Ч листать | Esc Ч закрыть")
        AuditAssert("Guides: pagination preserves all scenario text " . meta.Id, pages.Length() >= 4 && RegExReplace(original, "\s+") = RegExReplace(combined, "\s+"))
    }
    AuditAssert("Guides: invalid ID has no pages", Guide_GetPages(0).Length() = 0 && !Guide_Toggle(999))
    for token, value in savedTriggers
        SetDynamicGlobalValue("Trig_" . token, value)
}

Guide_RunDesktopChecks() {
    global
    queuedBeforeGuides := ChatQueue_Count()
    Gui, GuideFocusProbe:New, +HwndguideFocusHwnd -Caption +ToolWindow
    Gui, GuideFocusProbe:Show, x680 y460 w200 h40, Guide focus fixture
    WinActivate, ahk_id %guideFocusHwnd%
    for _, meta in Guide_GetCatalog() {
        opened := Guide_Toggle(meta.Id)
        Gui, 1:+HwndguideWindow
        DesktopSmoke_Assert("reference guide opens " . meta.Token, opened && current_doc = meta.Id && DllCall("IsWindow", "Ptr", guideWindow))
        DesktopSmoke_Assert("guide keeps foreground and capture registration " . meta.Token, DllCall("GetForegroundWindow", "Ptr") = guideFocusHwnd && CaptureWindowStates.HasKey(guideWindow))
        pages := Guide_GetPages(meta.Id), allShown := true
        Loop % pages.Length() {
            pageNumber := A_Index
            WinGetText, shownText, ahk_id %guideWindow%
            allShown := allShown && InStr(shownText, pages[pageNumber])
            Guide_Navigate("next")
            Gui, 1:+HwndguideWindow
        }
        DesktopSmoke_Assert("every guide page renders and next wraps " . meta.Token, allShown && GuideCurrentPages[meta.Id] = 1)
        Guide_Navigate("prev")
        DesktopSmoke_Assert("guide previous wraps " . meta.Token, GuideCurrentPages[meta.Id] = pages.Length())
        Guide_Toggle(meta.Id)
        DesktopSmoke_Assert("same guide command closes viewer " . meta.Token, !current_doc && !DllCall("IsWindow", "Ptr", guideWindow))
    }
    Guide_Toggle(22)
    ToggleLawDoc(5, "flter1", "ter1")
    DesktopSmoke_Assert("guide can switch to law", current_doc = 5)
    Guide_Toggle(23)
    DesktopSmoke_Assert("law can switch to guide", current_doc = 23)
    ServiceCodes_Show()
    DesktopSmoke_Assert("guide can switch to service codes", ServiceCodesGuiVisible && !current_doc)
    Guide_Toggle(21)
    Gosub, DoHideLawGui
    DesktopSmoke_Assert("hide-law key closes reference guide", !current_doc)
    Gosub, DoToggleLastLawDoc
    DesktopSmoke_Assert("last-document key reopens reference guide", current_doc = 21)
    CloseAllDocs()
    current_doc := 0
    Gui, GuideFocusProbe:Destroy
    DesktopSmoke_Assert("guides never enqueue chat messages", ChatQueue_Count() = queuedBeforeGuides)
    for _, meta in Guide_GetCatalog() {
        SetDynamicGlobalValue("Trig_" . meta.Token, meta.Trigger . "test")
        SetDynamicGlobalValue("Bind_" . meta.Token, "^!F" . (meta.Id - 14))
    }
    DesktopSmoke_Assert("guide configuration saves atomically", SaveProfile(CurrentProfile))
    for _, meta in Guide_GetCatalog() {
        SetDynamicGlobalValue("Trig_" . meta.Token, "")
        SetDynamicGlobalValue("Bind_" . meta.Token, "")
    }
    LoadProfile(CurrentProfile)
    profileOK := true
    for _, meta in Guide_GetCatalog()
        profileOK := profileOK && GetDynamicGlobalValue("Trig_" . meta.Token) = meta.Trigger . "test" && GetDynamicGlobalValue("Bind_" . meta.Token) = "^!F" . (meta.Id - 14)
    DesktopSmoke_Assert("guide TXT and hotkeys survive profile reload", profileOK)
}
