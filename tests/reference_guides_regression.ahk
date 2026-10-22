; Checks use production text/layout/profile/viewer code, never a game client.
Guide_RunRegression() {
    global
    catalog := Guide_GetCatalog()
    AuditAssert("Guides: signals and rights without removed scenarios", catalog.Length() = 2 && IsObject(Guide_GetMeta(24)) && !IsObject(Guide_GetMeta(22)) && !IsObject(Guide_GetMeta(23)))
    timetable := Guide_SignalsText()
    timesOK := true
    for _, time in ["03:30", "07:30", "15:30", "19:30", "10:00", "19:00", "03:00–03:10", "07:00–07:10", "15:00–15:10", "19:00–19:10", "09:30–09:40", "18:30–18:40"]
        timesOK := timesOK && InStr(timetable, time)
    AuditAssert("Guides: server timetable and 20-30 minute gathering windows", timesOK && InStr(timetable, "только спецподразделения") && !InStr(timetable, "ВУЛКАН"))
    AuditAssert("Guides: exactly two supplied department reports", InStr(timetable, "/d [ГАИ/УФСБ] Говорит лейтенант полиции Лукашенко, занял предварительную точку крушения ВГП - Лыткарино.") && InStr(timetable, "/d [ГАИ/УФСБ] Говорит лейтенант полиции Лукашенко, точка крушения ВГП - Лыткарино.") && !InStr(timetable, "/r ") && !InStr(timetable, "2-1"))
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
            combined .= StrReplace(page, "`r`n`r`nPgUp / PgDn — листать | Esc — закрыть")
        AuditAssert("Guides: pagination preserves all scenario text " . meta.Id, pages.Length() >= (meta.Id = 21 ? 4 : 1) && RegExReplace(original, "\s+") = RegExReplace(combined, "\s+"))
    }
    savedRights := RP_Rights
    RP_Rights := "Право на адвоката.`nПраво на звонок."
    firstRights := Guide_GetPages(24)
    RP_Rights := "Обновлённый текст прав профиля."
    updatedRights := Guide_GetPages(24)
    AuditAssert("Guides: rights viewer follows profile text without stale cache", InStr(firstRights[1], "Право на звонок.") && InStr(updatedRights[1], RP_Rights) && !InStr(updatedRights[1], "Право на звонок."))
    RP_Rights := ""
    emptyRights := Guide_GetPages(24)
    AuditAssert("Guides: empty rights show configuration hint", InStr(emptyRights[1], "Текст прав не задан"))
    RP_Rights := savedRights
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
    SearchResults := LawSearch_Find("ALL", "ФЗОП статья 22", 3).Results
    SearchDoc := "ALL", SearchCurrentIndex := 1, SearchCurrentPart := 1
    Search_ShowCurrentResult()
    Gui, 16:+HwndguideSearchWindow
    DesktopSmoke_Assert("law search result fixture opens", SearchGuiVisible && DllCall("IsWindow", "Ptr", guideSearchWindow))
    Guide_Toggle(21)
    DesktopSmoke_Assert("guide takes page navigation from an open law search", current_doc = 21 && !SearchGuiVisible && !SearchModeActive && !DllCall("IsWindow", "Ptr", guideSearchWindow))
    ToggleLawDoc(5, "flter1", "ter1")
    DesktopSmoke_Assert("guide can switch to law", current_doc = 5)
    Guide_Toggle(21)
    DesktopSmoke_Assert("law can switch to guide", current_doc = 21)
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
