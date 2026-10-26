; ui settings subsystem. Definitions only; initialization is in bootstrap.

GetThemeColors(ByRef bg, ByRef panel, ByRef text, ByRef accent, ByRef muted) {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    NormalizeThemeMode(ThemeMode)
    NormalizeColorNumber(CustomMenuColor)
    NormalizeColorNumber(CustomTextColor)
    NormalizeColorNumber(CustomBorderColor)
    NormalizeColorNumber(CustomTabColor)
    NormalizeColorNumber(CustomBindListColor)

    if (ThemeMode = "Graphite")
    {
        bg := "0E101A"
        panel := "161A29"
        text := "ECECFA"
        accent := "8060F8"
        muted := "9DA5BD"
    }
    else if (ThemeMode = "Light")
    {
        bg := "F5F7FA"
        panel := "FFFFFF"
        text := "1D232B"
        accent := "5B6B7B"
        muted := "66727F"
    }
    else if (ThemeMode = "Black")
    {
        bg := "050608"
        panel := "101114"
        text := "F4F6F8"
        accent := "6E7F90"
        muted := "A9B1BA"
    }
    else if (ThemeMode = "Midnight")
    {
        bg := "0B1020"
        panel := "121A2B"
        text := "EAF0FF"
        accent := "5B7CFA"
        muted := "A9B7D4"
    }
    else if (ThemeMode = "Emerald")
    {
        bg := "091512"
        panel := "10211B"
        text := "EAFBF3"
        accent := "2DAF7B"
        muted := "99C9B4"
    }
    else if (ThemeMode = "Amber")
    {
        bg := "17120A"
        panel := "261C10"
        text := "FFF3DE"
        accent := "C9872C"
        muted := "CFB38A"
    }
    else if (ThemeMode = "Rose")
    {
        bg := "1B1018"
        panel := "2A1822"
        text := "FDEAF2"
        accent := "C65F86"
        muted := "D3A2B5"
    }
    else
    {
        bg := "202020"
        panel := "2B2B2B"
        text := "F2F2F2"
        accent := "6A6A6A"
        muted := "A6A6A6"
    }

    if (CustomMenuColor != "")
    {
        panel := CustomMenuColor
        if (ColorBrightness(CustomMenuColor) >= 140)
            bg := ShiftHexColor(CustomMenuColor, 18)
        else
            bg := ShiftHexColor(CustomMenuColor, -18)
    }

    if (CustomTextColor != "")
        text := CustomTextColor
    else if (text = "" || CustomMenuColor != "")
    {
        if (ColorBrightness(panel) >= 140)
            text := "1D232B"
        else
            text := "F4F6F8"
    }

    if (CustomBorderColor != "")
        accent := CustomBorderColor
    else if (accent = "")
    {
        if (ColorBrightness(panel) >= 140)
            accent := ShiftHexColor(panel, -70)
        else
            accent := ShiftHexColor(panel, 70)
    }

    if (CustomTextColor != "")
    {
        if (ColorBrightness(text) >= 140)
            muted := ShiftHexColor(text, -70)
        else
            muted := ShiftHexColor(text, 70)
    }
    else if (ColorBrightness(panel) >= 140)
        muted := "66727F"
    else if (muted = "")
        muted := "A9B1BA"
    surfaces := [bg, panel]
    if (CustomTabColor != "")
        surfaces.Push(CustomTabColor)
    text := EnsureTextContrast(text, surfaces, 4.5)
    muted := EnsureTextContrast(muted, surfaces, 4.5)
}

GetControlSurfaceColors(ByRef controlBg, ByRef controlText, ByRef cardBg, ByRef cardEdge, panel, text, accent) {
    if (ColorBrightness(panel) >= 140) {
        controlBg := "FFFFFF"
        cardBg := ShiftHexColor(panel, -3)
        cardEdge := ShiftHexColor(panel, -24)
        controlText := "192332"
    } else {
        controlBg := ShiftHexColor(panel, 8)
        cardBg := ShiftHexColor(panel, -3)
        cardEdge := ShiftHexColor(panel, 20)
        controlText := "EBF0F7"
    }
    controlText := EnsureTextContrast(controlText, [controlBg], 4.5)
}

ApplyListViewColors(hwnd, bgHex, textHex) {
    if (!hwnd)
        return

    bgBgr := HexToBGR(bgHex)
    textBgr := HexToBGR(textHex)
    SendMessage, 0x1001, 0, %bgBgr%,, ahk_id %hwnd%
    SendMessage, 0x1026, 0, %bgBgr%,, ahk_id %hwnd%
    SendMessage, 0x1024, 0, %textBgr%,, ahk_id %hwnd%
}

AddOutlinedPanel(guiNum, x, y, w, h, fillColor, borderColor, borderSize := 1) {
    if (w <= 0 || h <= 0)
        return
    if (borderSize < 1)
        borderSize := 1
    if (borderSize * 2 > w)
        borderSize := 1
    if (borderSize * 2 > h)
        borderSize := 1
    rightX := x + w - borderSize
    bottomY := y + h - borderSize
    Gui, %guiNum%:Add, Progress, -Theme x%x% y%y% w%w% h%h% Disabled Background%fillColor% c%fillColor% hwndpanelFill, 100
    Gui, %guiNum%:Add, Progress, -Theme x%x% y%y% w%w% h%borderSize% Disabled Background%fillColor% c%borderColor% hwndpanelTop, 100
    Gui, %guiNum%:Add, Progress, -Theme x%x% y%y% w%borderSize% h%h% Disabled Vertical Background%fillColor% c%borderColor% hwndpanelLeft, 100
    Gui, %guiNum%:Add, Progress, -Theme x%x% y%bottomY% w%w% h%borderSize% Disabled Background%fillColor% c%borderColor% hwndpanelBottom, 100
    Gui, %guiNum%:Add, Progress, -Theme x%rightX% y%y% w%borderSize% h%h% Disabled Vertical Background%fillColor% c%borderColor% hwndpanelRight, 100
    return {Fill: panelFill, Top: panelTop, Left: panelLeft, Bottom: panelBottom, Right: panelRight, X: x, Y: y, W: w, Border: borderSize}
}

GetThemePresetList() {
    global ThemesFile
    if !FileExist(ThemesFile)
        return ""
    IniRead, sections, %ThemesFile%
    if (sections = "ERROR")
        return ""
    out := ""
    Loop, Parse, sections, `n, `r
    {
        sectionName := Trim(A_LoopField)
        if (SubStr(sectionName, 1, 6) != "Theme_")
            continue
        presetName := SubStr(sectionName, 7)
        if (presetName = "")
            continue
        if (out != "")
            out .= "|"
        out .= presetName
    }
    return out
}

IsBuiltInThemeName(themeName) {
    themeName := Trim(themeName)
    return (themeName = "Graphite" || themeName = "Light" || themeName = "Black" || themeName = "Midnight" || themeName = "Emerald" || themeName = "Amber" || themeName = "Rose")
}

GetThemeModeList() {
    out := "Graphite|Light|Black|Midnight|Emerald|Amber|Rose"
    presets := GetThemePresetList()
    if (presets = "")
        return out
    Loop, Parse, presets, |
    {
        item := Trim(A_LoopField)
        if (item = "" || IsBuiltInThemeName(item))
            continue
        out .= "|" . item
    }
    return out
}

ThemePresetExists(themeName) {
    global ThemesFile
    NormalizeProfileNameValue(themeName)
    if (themeName = "" || !FileExist(ThemesFile))
        return 0
    section := "Theme_" . themeName
    IniRead, chk, %ThemesFile%, %section%, ThemeMode, __MISSING__
    return (chk != "__MISSING__")
}

ShowSettingsWindow() {
    global SettingsX, SettingsY, SettingsW, SettingsH, hSettingsWnd
    global MenuTransparency, UIRoundness, InnerRoundness
    Settings_NormalizeViewport()
    Gui, 2:-DPIScale
    Capture_BeforeShow("2")
    Gui, 2:Show, % "x" . SettingsX . " y" . SettingsY . " w" . SettingsW . " h" . SettingsH . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), Настройки профиля
    Gui, 2:+DPIScale
    Settings_UpdateScrollbars()
    if !GameUi_ShouldShowPassive()
        WinActivate, ahk_id %hSettingsWnd%
    PromoteOverlayWindow(hSettingsWnd)
    ; The settings canvas is opaque: avoid an unnecessary layered window.
    if (DllCall("GetWindowLong", "Ptr", hSettingsWnd, "Int", -20, "UInt") & 0x80000)
        WinSet, Transparent, Off, ahk_id %hSettingsWnd%
    ApplyRoundedCorners(hSettingsWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hSettingsWnd, InnerRoundness)
}

ApplyRoundedCorners(hwnd, radius := 18) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return false
    if (radius <= 0)
        return DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    WinGetPos,,, w, h, ahk_id %hwnd%
    region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Int", radius, "Int", radius, "Ptr")
    if (!region)
        return false
    ok := DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", 1)
    if (!ok)
        DllCall("DeleteObject", "Ptr", region)
    return ok
}

ApplyRoundedPanelsForGui(guiHwnd, radius := "") {
    global InnerRoundness
    if (radius = "")
        radius := InnerRoundness
    if (!guiHwnd)
        return
    WinGet, ctrlList, ControlListHwnd, ahk_id %guiHwnd%
    Loop, Parse, ctrlList, `n, `r
    {
        ctrlHwnd := A_LoopField + 0
        if (!ctrlHwnd)
            continue
        VarSetCapacity(className, 64, 0)
        DllCall("GetClassName", "Ptr", ctrlHwnd, "Str", className, "Int", 64)
        if (className != "msctls_progress32")
            continue
        WinGetPos,,, cw, ch, ahk_id %ctrlHwnd%
        if (cw = "" or ch = "")
            continue
        if (cw < 100 || ch < 32)
            continue
        ApplyRoundedCorners(ctrlHwnd, radius)
    }
}

SetSettingsBindsStatus(statusText) {
    global CFG_BindsStatusText, SettingsVisible
    CFG_BindsStatusText := statusText
    if (SettingsVisible)
        GuiControl, 2:, CFG_BindsStatusText, %statusText%
}

SettingsGui_CanUpdate() {
    global SettingsVisible, SettingsGuiReady, hSettingsWnd
    return SettingsVisible && SettingsGuiReady && hSettingsWnd && DllCall("IsWindow", "Ptr", hSettingsWnd)
}

SetSettingsWindowState(visible, tabIndex := 1, persist := 1) {
    global SettingsVisible
    NormalizeVisibleStateValue(visible)
    if (visible)
    {
        OpenSettings(tabIndex)
        SettingsVisible := 1
    }
    else
    {
        if (SettingsVisible)
            CloseSettings()
        else
            Gui, 2:Hide
        SettingsVisible := 0
    }
    if (persist)
        SaveSettingsWindowState()
}

ResetStyleDefaults() {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global UIRoundness, InnerRoundness, GuiTransparency, MenuTransparency, HUDTransparency, BindListTransparency
    global HUDMode, BackgroundImageURL, BackgroundImageFile, FullscreenSafeGui

    SaveGuiToGlobals(1)

    ThemeMode := "Graphite"
    HUDMode := "Полный"
    CustomMenuColor := ""
    CustomTextColor := ""
    CustomBorderColor := ""
    CustomTabColor := ""
    CustomBindListColor := ""
    BackgroundImageURL := ""
    BackgroundImageFile := ""
    TabGuiHeaderText := "AMZ Helper | sbezruk180"
    UIRoundness := 18
    InnerRoundness := 14
    GuiTransparency := 225
    MenuTransparency := 225
    HUDTransparency := 225
    BindListTransparency := 225
    FullscreenSafeGui := "Auto"
}

OpenSettings(tabIndex := 1) {
    global SettingsVisible, SettingsTargetTab, SettingsPage, UIRoundness, InnerRoundness, hSettingsWnd
    if RegExMatch(tabIndex . "", "^\d+$")
    {
        pages := GetSettingsPageCatalog()
        SettingsPage := (tabIndex >= 1 && tabIndex <= pages.Length()) ? pages[tabIndex].Id : "profile"
    }
    else
        SettingsPage := tabIndex
    NormalizeSettingsPage(SettingsPage)
    SettingsTargetTab := SettingsPageIndex(SettingsPage)
    BuildSettingsGui()
    ShowSettingsWindow()
    RefreshSettingsTabs()
    SettingsVisible := 1
    SaveSettingsWindowState()
    ResolveCfgHotkeyConflicts("", 0)
    ApplyPersistentAlwaysOnTop()
}

ApplyPersistentAlwaysOnTop() {
    global hHUDWnd, hBindListWnd, hSettingsWnd, hTerritoryMapWnd, hTerritoryMapViewWnd, hActionTimerWnd
    if (hHUDWnd && DllCall("IsWindowVisible", "Ptr", hHUDWnd))
        PromoteOverlayWindow(hHUDWnd, 1, 1)
    if (hBindListWnd && DllCall("IsWindowVisible", "Ptr", hBindListWnd))
        PromoteOverlayWindow(hBindListWnd)
    if (hSettingsWnd && DllCall("IsWindowVisible", "Ptr", hSettingsWnd))
        PromoteOverlayWindow(hSettingsWnd)
    if (hTerritoryMapWnd && DllCall("IsWindowVisible", "Ptr", hTerritoryMapWnd))
        PromoteOverlayWindow(hTerritoryMapWnd)
    if (hTerritoryMapViewWnd && DllCall("IsWindowVisible", "Ptr", hTerritoryMapViewWnd))
        PromoteOverlayWindow(hTerritoryMapViewWnd)
    if (hActionTimerWnd && DllCall("IsWindowVisible", "Ptr", hActionTimerWnd))
        PromoteOverlayWindow(hActionTimerWnd, 1, 1)
}

ApplyGuiSettingsAuto(saveProfileToo := 0, refreshSettingsToo := 0) {
    global CurrentProfile, BindListVisible, SettingsVisible
    if (!SettingsVisible)
        return
    SaveGuiToGlobals(1)
    SaveUISettings()
    if (saveProfileToo)
        if !SaveProfile(CurrentProfile)
            return
    if (refreshSettingsToo)
    {
        RebuildFloatingGUI()
        BuildSettingsGui()
        ShowSettingsWindow()
        RefreshSettingsTabs()
    }
    else
    {
        UpdateHUD()
        if (BindListVisible)
        {
            CreateBindList()
            UpdateBindList()
        }
    }
    ApplyPersistentAlwaysOnTop()
}

CloseSettings() {
    global SettingsVisible, SettingsGuiReady, CurrentProfile, BindMenuEditMode, UiPreviewMode, hSettingsWnd
    global SettingsPageExtents, SettingsPageFrames, SettingsScrollX, SettingsScrollY
    if (BindMenuEditMode)
        CloseBindMenuEditMode(0)
    if (SettingsVisible && !UiPreviewMode)
    {
        SaveGuiToGlobals(1)
        if !SaveProfile(CurrentProfile)
            return
        SaveUISettings()
    }
    SettingsVisible := 0
    SettingsGuiReady := 0
    if (!UiPreviewMode)
        SaveSettingsWindowState()
    ; Opening settings always rebuilds the GUI, so hidden controls serve no reuse.
    Gui, 2:Destroy
    hSettingsWnd := 0
    SettingsPageExtents := {}, SettingsPageFrames := {}
    SettingsScrollX := 0, SettingsScrollY := 0
}

SetSettingsStatus(message) {
    global hSettingsWnd
    if (message = "" || !hSettingsWnd || !WinExist("ahk_id " . hSettingsWnd))
        return
    GuiControl, 2:, SettingsStatusText, %message%
}

SettingsActionAllowed(actionName, delayMs := 700) {
    global SettingsLastAction, SettingsLastActionTick
    elapsed := TickNow() - SettingsLastActionTick
    if (SettingsLastAction = actionName && elapsed >= 0 && elapsed < delayMs)
    {
        SetSettingsStatus("Команда уже выполняется. Подождите немного.")
        return false
    }
    SettingsLastAction := actionName
    SettingsLastActionTick := TickNow()
    return true
}

ToggleSettings() {
    global SettingsVisible
    if (SettingsVisible)
        CloseSettings()
    else
        OpenSettings(1)
}

RefreshSettingsTabs() {
    global SettingsPage
    NormalizeSettingsPage(SettingsPage)
    Settings_SwitchPage(SettingsPageIndex(SettingsPage))
}

Settings_SwitchPage(pageIndex, syncNavigation := 1) {
    global SettingsTargetTab, SettingsPage, SettingsNavigationBusy, SettingsNavigationButtons
    pages := GetSettingsPageCatalog()
    if (pageIndex < 1 || pageIndex > pages.Length() || SettingsNavigationBusy)
        return false

    SettingsNavigationBusy := 1
    Settings_ResetScroll()
    SettingsTargetTab := pageIndex
    SettingsPage := pages[pageIndex].Id
    GuiControl, 2:Choose, SettingsTabs, %SettingsTargetTab%
    if (syncNavigation)
    {
        Gui, 2:Default
        Gui, 2:ListView, SettingsNavLV
        LV_Modify(0, "-Select -Focus")
        LV_Modify(SettingsTargetTab, "Select Focus Vis")
    }
    for navIndex, navHwnd in SettingsNavigationButtons {
        if DllCall("IsWindow", "Ptr", navHwnd)
            UIStyle_SetButtonRole(navHwnd, navIndex = pageIndex ? "nav-active" : "nav")
    }
    Settings_ActivateLayout(pageIndex)
    UpdateAutomationSettingsStatus()
    SettingsNavigationBusy := 0
    return true
}

Settings_NavClick(controlHwnd, guiEvent := "", eventInfo := "", eventError := "") {
    global SettingsNavigationButtons
    for index, hwnd in SettingsNavigationButtons
        if (hwnd = controlHwnd)
            return Settings_SwitchPage(index)
    return false
}

GetSettingsPageCatalog() {
    pages := []
    pages.Push({Id: "profile", Label: "Профиль"})
    pages.Push({Id: "safety", Label: "Чат и безопасность"})
    pages.Push({Id: "appearance", Label: "Интерфейс"})
    pages.Push({Id: "reports", Label: "Шаблоны докладов"})
    pages.Push({Id: "operations", Label: "Патруль, пост и строй"})
    pages.Push({Id: "hotkeys_main", Label: "Бинды: основные"})
    pages.Push({Id: "hotkeys_transport", Label: "Бинды: транспорт"})
    pages.Push({Id: "text_triggers", Label: "TXT-команды"})
    pages.Push({Id: "documents", Label: "Документы"})
    pages.Push({Id: "rp_person", Label: "RP - персонаж"})
    pages.Push({Id: "rp_vehicle", Label: "RP - транспорт"})
    pages.Push({Id: "automation", Label: "Автоматизация"})
    pages.Push({Id: "screenshots", Label: "Автоскриншоты"})
    return pages
}

SettingsPageIndex(pageId) {
    pages := GetSettingsPageCatalog()
    Loop % pages.Length()
        if (pages[A_Index].Id = pageId)
            return A_Index
    return 1
}

SettingsPageIdFromLegacyTab(tabIndex) {
    legacy := {1: "profile", 2: "safety", 3: "appearance", 4: "reports", 5: "operations", 6: "hotkeys_main", 7: "text_triggers", 8: "documents", 9: "rp_person"}
    tabIndex += 0
    if legacy.HasKey(tabIndex)
        return legacy[tabIndex]
    pages := GetSettingsPageCatalog()
    if (tabIndex >= 1 && tabIndex <= pages.Length())
        return pages[tabIndex].Id
    return "profile"
}

Settings_AddControl(label, varName, value, x, y, w, controlType, options, textColor, inputColor) {
    Gui, 2:Font, s9 Norm c%textColor%, Segoe UI
    Gui, 2:Add, Text, % "x" x " y" y " w" w " h26 +Wrap BackgroundTrans", %label%
    Gui, 2:Font, s10 Norm c%inputColor%, Segoe UI
    opts := "x" x " y" (y + 28) " w" w " v" . varName
    if (controlType = "DropDown" || controlType = "Combo") {
        opts .= " r8"
        if (controlType = "DropDown")
            Gui, 2:Add, DropDownList, %opts%, %options%
        else
            Gui, 2:Add, ComboBox, %opts%, %options%
        GuiControl, 2:ChooseString, %varName%, %value%
    } else {
        opts .= " h32 -Multi -WantReturn -VScroll -HScroll"
        Gui, 2:Add, Edit, %opts%, %value%
    }
    Settings_RecordExtent(y + 66)
}

Settings_AddGrid(items, startX, startY, cols, colWidth, rowHeight, controlType, textColor, inputColor) {
    rowHeight := Max(rowHeight, controlType = "Multi" ? 88 : 76)
    for index, item in items {
        col := Mod(index - 1, cols)
        row := Floor((index - 1) / cols)
        x := startX + col * colWidth
        y := startY + row * rowHeight
        w := colWidth - 18
        controlValue := item[3]
        Gui, 2:Font, s9 Norm c%textColor%, Segoe UI
        Gui, 2:Add, Text, % "x" x " y" y " w" w " h28 +Wrap BackgroundTrans", % item[1]
        Gui, 2:Font, s10 Norm c%inputColor%, Segoe UI
        h := controlType = "Multi" ? rowHeight - 42 : 32
        opts := "x" x " y" (y + 28) " w" w " h" h " v" . item[2]
        if (controlType = "Hotkey") {
            opts .= " gCfgHotkeyChanged"
            Gui, 2:Add, Hotkey, %opts%, %controlValue%
        } else {
            if (controlType = "Multi")
                opts .= " Multi WantTab +VScroll"
            if (controlType != "Multi")
                opts .= " -Multi -WantReturn -VScroll -HScroll"
            Gui, 2:Add, Edit, %opts%, %controlValue%
        }
        Settings_RecordExtent(y + 28 + h + 12)
    }
}

Settings_GetCatalogItems(fieldType, groupName) {
    items := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (fieldType = "Hotkey")
        {
            if (meta.HotkeyVar = "")
                continue
            isTransport := (meta.Category = "Транспорт / прочее")
            isAssistant := (meta.Category = "Контекстный помощник")
            if (isAssistant)
                continue
            if ((groupName = "transport" && !isTransport) || (groupName = "main" && isTransport))
                continue
            varName := "CFG_" . meta.HotkeyVar
            items.Push([meta.Label, varName, GetDynamicGlobalValue(meta.HotkeyVar)])
        }
        else
        {
            if (meta.TriggerVar = "")
                continue
            isDocument := (meta.Category = "Документы")
            isAssistant := (meta.Category = "Контекстный помощник")
            if (isAssistant)
                continue
            if ((groupName = "documents" && !isDocument) || (groupName = "commands" && isDocument))
                continue
            varName := "CFG_" . meta.TriggerVar
            items.Push([meta.Label, varName, GetDynamicGlobalValue(meta.TriggerVar)])
        }
    }
    return items
}

Settings_AddAssistantCard(label, enabledCfgVar, enabledValue, hotkeyCfgVar, hotkeyValue, triggerCfgVar, triggerValue, x, y, textColor, mutedColor, inputTextColor) {
    checkOpts := "x" . x . " y" . y . " w280 h22 v" . enabledCfgVar
    if (enabledValue = "On")
        checkOpts .= " Checked"
    Gui, 2:Font, s10 Bold c%textColor%, Segoe UI
    Gui, 2:Add, Checkbox, %checkOpts%, %label%

    labelY := y + 27
    inputY := y + 45
    triggerX := x + 126
    Gui, 2:Font, Norm s8 c%mutedColor%, Segoe UI
    Gui, 2:Add, Text, % "x" . x . " y" . labelY . " w116 h16 BackgroundTrans", Клавиша
    Gui, 2:Add, Text, % "x" . triggerX . " y" . labelY . " w154 h16 BackgroundTrans", TXT-триггер

    hotkeyOpts := "x" . x . " y" . inputY . " w116 h28 v" . hotkeyCfgVar . " gCfgHotkeyChanged"
    triggerOpts := "x" . triggerX . " y" . inputY . " w154 h28 v" . triggerCfgVar
    Gui, 2:Font, Norm s9 c%inputTextColor%, Segoe UI
    Gui, 2:Add, Hotkey, %hotkeyOpts%, %hotkeyValue%
    Gui, 2:Add, Edit, %triggerOpts%, %triggerValue%
}

Settings_AddPageFrame(title, subtitle, cardBg, cardEdge, textColor, mutedColor) {
    SettingsPageFrames[SettingsBuildingPage] := AddOutlinedPanel(2, 230, 82, 934, 674, cardBg, cardEdge, 1)
    Settings_RecordExtent(740)
    Gui, 2:Font, s18 Bold c%textColor%, Segoe UI
    Gui, 2:Add, Text, x254 y96 w870 h32 BackgroundTrans, %title%
    Gui, 2:Font, Norm s9 c%mutedColor%, Segoe UI
    Gui, 2:Add, Text, x256 y134 w870 h22 BackgroundTrans, %subtitle%
}

BuildSettingsGui() {
    global
    SettingsGuiReady := 0
    SettingsPageExtents := {}
    SettingsPageFrames := {}
    SettingsCanvasHeight := 800
    SettingsScale := A_ScreenDPI / 96.0
    SettingsBuildingPage := 0
    SettingsScrollX := 0
    SettingsScrollY := 0
    SyncConfigOnlyProfileFieldsToCfg()
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    controlBg := "F7F8FA", inputText := "111418", cardBg := "2A3037", cardEdge := "3A434D"
    GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, text, accent)
    if (CustomTabColor != "") {
        cardBg := CustomTabColor
        if (ColorContrast(text, cardBg) < 4.5)
            cardBg := panel
    }
    if (CustomBorderColor != "")
        cardEdge := CustomBorderColor

    profiles := GetProfilesString()
    pages := GetSettingsPageCatalog()
    pageLabels := ""
    Loop % pages.Length()
        pageLabels .= (pageLabels = "" ? "" : "|") . pages[A_Index].Label

    Gui, 2:Destroy
    Gui, 2:+HwndhSettingsWnd +AlwaysOnTop -Caption +ToolWindow +Resize +0x300000 +DPIScale
    Gui, 2:Color, %bg%, %controlBg%
    Gui, 2:Font, Norm s10 c%text%, Segoe UI
    buildW := 1180, buildH := 800
    ; The sidebar and header are independent of the form pages.
    ; Native buttons keep keyboard navigation and the existing page dispatch.
    Gui, 2:Add, Progress, -Theme x0 y0 w220 h800 Disabled Background%panel% c%panel%, 100
    Gui, 2:Add, Progress, -Theme x220 y0 w1 h800 Disabled Background%bg% c%cardEdge%, 100
    Gui, 2:Add, Progress, -Theme x0 y0 w1180 h1 Disabled Background%bg% c%cardEdge% vSettingsBorderTop, 100
    Gui, 2:Add, Progress, -Theme x0 y799 w1180 h1 Disabled Background%bg% c%cardEdge% vSettingsBorderBottom, 100
    Gui, 2:Add, Text, x0 y0 w220 h100 vSettingsDragZone gStartSettingsDrag BackgroundTrans,
    Gui, 2:Font, s18 Bold c%accent%, Segoe UI
    Gui, 2:Add, Text, x22 y22 w38 h34 BackgroundTrans hwndhSettingsBrand, G
    UIStyle_SetTextRole(hSettingsBrand, "accent")
    Gui, 2:Font, s11 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x62 y25 w150 h24 BackgroundTrans, AHK FOR GOS
    Gui, 2:Font, Norm s8 c%muted%, Segoe UI
    Gui, 2:Add, Text, x63 y51 w146 h18 BackgroundTrans, AMAZING ONLINE
    Gui, 2:Add, Text, x24 y106 w170 h20 BackgroundTrans, РАБОЧЕЕ ПРОСТРАНСТВО

    Gui, 2:Font, Norm s8 c%muted%, Segoe UI
    Gui, 2:Add, Text, x244 y14 w210 h18 BackgroundTrans, АКТИВНЫЙ ПРОФИЛЬ
    Gui, 2:Font, Norm s10 c%inputText%, Segoe UI
    Gui, 2:Add, ComboBox, x244 y36 w208 r10 vCFG_ProfileName, %profiles%
    GuiControl, 2:ChooseString, CFG_ProfileName, %CurrentProfile%
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Button, x466 y34 w88 h34 vSettingsBtnLoad gCfgLoadProfile, Загрузить
    Gui, 2:Add, Button, x562 y34 w96 h34 vSettingsBtnSave hwndhSettingsSave gCfgSaveProfile, Сохранить
    UIStyle_SetButtonRole(hSettingsSave, "primary")
    Gui, 2:Add, Button, x674 y34 w82 h34 vSettingsBtnCreate gCfgCreateProfile, Создать
    Gui, 2:Add, Button, x764 y34 w82 h34 vSettingsBtnDelete hwndhSettingsDelete gCfgDeleteProfile, Удалить
    UIStyle_SetButtonRole(hSettingsDelete, "danger")
    Gui, 2:Add, Button, x862 y34 w76 h34 vSettingsBtnImport gImportProfilesLabel, Импорт
    Gui, 2:Add, Button, x946 y34 w76 h34 vSettingsBtnExport gExportProfilesLabel, Экспорт
    Gui, 2:Add, Button, x1066 y34 w38 h34 vSettingsBtnHide gMinimizeSettingsLabel, -
    Gui, 2:Add, Button, x1112 y34 w42 h34 vSettingsBtnExit gExitScriptButtonLabel, X

    ; Keep the existing selection model for all profile/page callers.
    Gui, 2:Font, Norm s10 c%text%, Segoe UI
    Gui, 2:Add, ListView, x24 y138 w180 h520 Hidden -Hdr -Multi AltSubmit vSettingsNavLV hwndhSettingsNavLV gSettingsNavChanged Background%panel% NoSortHdr, Раздел
    Gui, 2:Default
    Gui, 2:ListView, SettingsNavLV
    Loop % pages.Length()
        LV_Add("", pages[A_Index].Label)
    LV_ModifyCol(1, 176)
    ApplyListViewColors(hSettingsNavLV, panel, text)
    SettingsNavigationButtons := []
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    for navIndex, navPage in pages {
        navY := 140 + (navIndex - 1) * 40
        navOptions := "x12 y" . navY . " w196 h36 vSettingsNavItem" . navIndex . " hwndhNavButton gSettings_NavClick"
        Gui, 2:Add, Button, %navOptions%, % navPage.Label
        UIStyle_SetButtonRole(hNavButton, "nav")
        SettingsNavigationButtons.Push(hNavButton)
    }
    Gui, 2:Font, s9 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x24 y706 w176 h22 BackgroundTrans, SBEZRUK180
    Gui, 2:Font, s8 Norm c%muted%, Segoe UI
    Gui, 2:Add, Text, x24 y732 w176 h18 BackgroundTrans, Помощник гос. структур

    Gui, 2:Add, Tab2, x-1000 y-1000 w10 h10 AltSubmit vSettingsTabs, %pageLabels%

    SettingsBuildingPage := 1
    Gui, 2:Tab, 1
    Settings_AddPageFrame("Профиль", "Данные персонажа и экипажей. Изменения сохраняются кнопкой «Сохранить».", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 240, 166, 904, 72, panel, cardEdge, 1)
    Settings_AddControl("Организация", "CFG_ProfileMode", ProfileMode, 256, 172, 210, "DropDown", "ППС|ГАИ|ФСБ|Спец МВД|ВЧ", text, inputText)
    Gui, 2:Add, Button, x482 y204 w158 h28 gApplyPresetLabel, Применить режим
    Gui, 2:Font, s12 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x668 y176 w452 h24 vProfileSummaryText +0x200 +0x4000 BackgroundTrans, %CurrentProfile%
    Gui, 2:Font, s9 Norm c%muted%, Segoe UI
    Gui, 2:Add, Text, x668 y206 w452 h18 +0x4000 BackgroundTrans, % ProfileMode . "  |  " . Surname . "  |  " . Rank

    AddOutlinedPanel(2, 240, 250, 904, 206, panel, cardEdge, 1)
    Gui, 2:Font, s10 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x256 y264 w860 h20 BackgroundTrans, Персонаж и служба
    profileItems := []
    profileItems.Push(["Должность", "CFG_IntroRole", IntroRole])
    profileItems.Push(["Должность для /d", "CFG_ReportRole", ReportRole])
    profileItems.Push(["Фамилия / позывной", "CFG_Surname", Surname])
    profileItems.Push(["Личный жетон", "CFG_PersonalBadge", PersonalBadge])
    profileItems.Push(["Звание", "CFG_Rank", Rank])
    profileItems.Push(["Звание для докладов", "CFG_ReportRank", ReportRank])
    Settings_AddGrid(profileItems, 256, 294, 3, 294, 76, "Edit", text, inputText)

    AddOutlinedPanel(2, 240, 472, 444, 180, panel, cardEdge, 1)
    AddOutlinedPanel(2, 700, 472, 444, 180, panel, cardEdge, 1)
    Gui, 2:Font, s10 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x256 y486 w412 h20 BackgroundTrans, Патруль
    Gui, 2:Add, Text, x716 y486 w412 h20 BackgroundTrans, Пост
    patrolItems := [["Экипаж", "CFG_PatrolUnit", PatrolUnit], ["Состав", "CFG_PatrolCrewCount", PatrolCrewCount]]
    postItems := [["Экипаж", "CFG_PostUnit", PostUnit], ["Состав", "CFG_PostCrewCount", PostCrewCount]]
    Settings_AddGrid(patrolItems, 256, 514, 2, 210, 68, "Edit", text, inputText)
    Settings_AddGrid(postItems, 716, 514, 2, 210, 68, "Edit", text, inputText)
    Settings_AddControl("Маршрут", "CFG_PatrolRoute", PatrolRoute, 256, 584, 408, "Edit", "", text, inputText)
    Settings_AddControl("Название поста", "CFG_PostRoute", PostRoute, 716, 584, 408, "Edit", "", text, inputText)
    AddOutlinedPanel(2, 240, 666, 904, 78, panel, cardEdge, 1)
    Settings_AddControl("Маршрут колонны", "CFG_ConvoyRoute", ConvoyRoute, 256, 672, 868, "Edit", "", text, inputText)

    SettingsBuildingPage := 2
    Gui, 2:Tab, 2
    Settings_AddPageFrame("Чат и безопасность", "Отправка сообщений, проверки, уведомления и задержки.", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 240, 166, 904, 72, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 240, 904, 72, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 314, 904, 74, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 390, 904, 212, panel, cardEdge, 1)
    idChoice := IDCheckEnabled ? "On" : "Off"
    textModeLabel := ChatTyping_ModeLabel(TextSendMode)
    Settings_AddControl("Режим отправки", "CFG_TextSendMode", textModeLabel, 256, 170, 300, "DropDown", "Авто|Память|Вставка|Печать всего|Фракция: остальное вставка|Фракция: остальное память", text, inputText)
    Settings_AddControl("Тест без игры (Mock)", "CFG_MockMode", MockMode, 572, 170, 120, "DropDown", "Off|On", text, inputText)
    Settings_AddControl("Очередь чата", "CFG_ChatQueueEnabled", ChatQueueEnabled, 708, 170, 120, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Проверка ID", "CFG_IDCheckEnabled", idChoice, 844, 170, 120, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("SafeMode", "CFG_SafeModeEnabled", SafeModeEnabled, 980, 170, 144, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Блок при открытом чате", "CFG_SafeBlockWhenChat", SafeBlockWhenChat, 240, 244, 200, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Требовать чат", "CFG_SafeRequireChatForEditable", SafeRequireChatForEditable, 456, 244, 190, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Проверка транспорта", "CFG_SafeVehicleChecks", SafeVehicleChecks, 662, 244, 190, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Проверка дистанции", "CFG_SafeDistanceChecks", SafeDistanceChecks, 868, 244, 190, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Радиус, м", "CFG_SafeDistanceLimit", SafeDistanceLimit, 1074, 244, 70, "Edit", "", text, inputText)
    Settings_AddControl("Подсказки", "CFG_SafeTooltipWarnings", SafeTooltipWarnings, 240, 318, 130, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Звук", "CFG_NotifySoundEnabled", NotifySoundEnabled, 386, 318, 110, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Громкость", "CFG_NotifyVolume", NotifyVolume, 512, 318, 90, "Edit", "", text, inputText)
    Gui, 2:Add, Button, x618 y350 w120 h28 gPreviewNotifySoundLabel, Звук
    Settings_AddControl("ID-уведомление", "CFG_ContextNotificationMode", ContextNotificationMode, 754, 318, 168, "DropDown", "Плашка|Чат", text, inputText)
    Settings_AddControl("Скрыть через, сек", "CFG_ContextNotificationTimeoutSec", ContextNotificationTimeoutSec, 938, 318, 166, "Edit", "", text, inputText)
    Settings_AddControl("Задержка действия", "CFG_ActionCooldownMs", ActionCooldownMs, 240, 396, 150, "Edit", "", text, inputText)
    Settings_AddControl("Задержка строк", "CFG_SequenceLineDelay", SequenceLineDelay, 406, 396, 150, "Edit", "", text, inputText)
    Settings_AddControl("Пауза очереди", "CFG_ChatQueueMinDelay", ChatQueueMinDelay, 572, 396, 150, "Edit", "", text, inputText)
    Settings_AddControl("GUI fullscreen", "CFG_FullscreenSafeGui", FullscreenSafeGui, 738, 396, 140, "DropDown", "Auto|On|Off", text, inputText)
    Settings_AddControl("Бэкапы", "CFG_ProfileSaveBackups", ProfileSaveBackups, 894, 396, 120, "DropDown", "On|Off", text, inputText)
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Text, x240 y476 w880 h18 BackgroundTrans, Приоритет bind-list
    Gui, 2:Font, Norm s9 c%inputText%, Consolas
    Gui, 2:Add, Edit, x240 y498 w884 h90 vCFG_BindListItems WantTab, %BindListItems%
    Settings_AddControl("Заголовок окна", "CFG_GameWindowTitle", GameWindowTitle, 240, 602, 200, "Edit", "", text, inputText)
    Settings_AddControl("Процесс (резерв)", "CFG_GameProcessName", GameProcessName, 456, 602, 170, "Edit", "", text, inputText)
    Settings_AddControl("Ожидаемый SHA-256 azmp.dll", "CFG_AzmpExpectedSHA256", AzmpExpectedSHA256, 642, 602, 320, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Button, x978 y634 w146 h30 gTestChatConnectionLabel, Проверить
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x240 y668 w884 h46 vCFG_ChatConnectionStatus BackgroundTrans +Wrap, % ChatTransport_GetConnectionSummary(0)

    AddOutlinedPanel(2, 240, 730, 904, 336, panel, cardEdge, 1)
    Gui, 2:Font, s11 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x256 y742 w868 h24 BackgroundTrans, Печать и ручной ввод ID
    Settings_AddControl("Интервал печати, мс (1–100)", "CFG_ChatTypingDelayMs", ChatTypingDelayMs, 256, 778, 214, "Edit", "", text, inputText)
    Settings_AddControl("Ручной ввод ID", "CFG_IDEntryMode", IDEntryMode, 490, 778, 258, "DropDown", "Перехват цифр|Окно ввода", text, inputText)
    Settings_AddControl("Время ввода ID, сек", "CFG_IDCaptureTimeoutSec", IDCaptureTimeoutSec, 768, 778, 164, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x950 y782 w174 h58 +Wrap BackgroundTrans, По бинду «Ввести ID вручную». Повтор бинда применяет ID.
    Settings_AddControl("Темп набора", "CFG_ChatTypingSpeedMode", ChatTyping_SpeedLabel(ChatTypingSpeedMode), 256, 852, 300, "DropDown", "Постоянный интервал|Случайный темп (симв/с)", text, inputText)
    Settings_AddControl("От, симв/с (1–1000)", "CFG_ChatTypingMinCPS", ChatTypingMinCPS, 576, 852, 180, "Edit", "", text, inputText)
    Settings_AddControl("До, симв/с (1–1000)", "CFG_ChatTypingMaxCPS", ChatTypingMaxCPS, 776, 852, 180, "Edit", "", text, inputText)
    Settings_AddControl("Команды для режима «Печать фракции»", "CFG_ChatFactionCommands", ChatFactionCommands, 256, 926, 868, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x256 y998 w868 h54 +Wrap BackgroundTrans, Темп задаётся в символах/сек.; фактическая скорость ограничена игрой и удержанием клавиши 10 мс. Интервал и случайный темп не меняют паузы действий/RP. Фракционные команды: через пробел или `;.
    Settings_RecordExtent(1078)

    SettingsBuildingPage := 3
    Gui, 2:Tab, 3
    Settings_AddPageFrame("Интерфейс", "Тема, HUD, цвета и параметры таймера.", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 240, 166, 904, 72, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 240, 904, 148, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 398, 904, 78, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 490, 904, 124, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 630, 904, 150, panel, cardEdge, 1)
    AddOutlinedPanel(2, 240, 796, 904, 122, panel, cardEdge, 1)
    themeControlValue := (CFG_ThemePresetName != "" && ThemePresetExists(CFG_ThemePresetName)) ? CFG_ThemePresetName : ThemeMode
    Settings_AddControl("Тема", "CFG_ThemeMode", themeControlValue, 240, 170, 200, "Combo", GetThemeModeList(), text, inputText)
    Settings_AddControl("Режим HUD", "CFG_HUDMode", HUDMode, 456, 170, 200, "DropDown", "Полный|Компактный|Профиль + ID", text, inputText)
    Settings_AddControl("Скругление", "CFG_UIRoundness", UIRoundness, 672, 170, 110, "Edit", "", text, inputText)
    Settings_AddControl("Скругление внутри", "CFG_InnerRoundness", InnerRoundness, 798, 170, 150, "Edit", "", text, inputText)
    Settings_AddControl("Текст HUD", "CFG_TabGuiHeaderText", TabGuiHeaderText, 964, 170, 180, "Edit", "", text, inputText)
    Settings_AddControl("Меню", "CFG_MenuTransparency", MenuTransparency, 240, 246, 110, "Edit", "", text, inputText)
    Settings_AddControl("HUD", "CFG_HUDTransparency", HUDTransparency, 366, 246, 110, "Edit", "", text, inputText)
    Settings_AddControl("Bind-list", "CFG_BindListTransparency", BindListTransparency, 492, 246, 110, "Edit", "", text, inputText)
    Settings_AddControl("Фон меню", "CFG_CustomMenuColor", CustomMenuColor, 618, 246, 120, "Edit", "", text, inputText)
    Settings_AddControl("Цвет текста", "CFG_CustomTextColor", CustomTextColor, 754, 246, 120, "Edit", "", text, inputText)
    Settings_AddControl("Акцент", "CFG_CustomBorderColor", CustomBorderColor, 890, 246, 120, "Edit", "", text, inputText)
    Settings_AddControl("Карточки", "CFG_CustomTabColor", CustomTabColor, 1026, 246, 118, "Edit", "", text, inputText)
    Settings_AddControl("Фон bind-list", "CFG_CustomBindListColor", CustomBindListColor, 240, 322, 150, "Edit", "", text, inputText)
    Settings_AddControl("Общая прозрачность", "CFG_GuiTransparency", GuiTransparency, 406, 322, 160, "Edit", "", text, inputText)
    Gui, 2:Add, Button, x582 y354 w130 h28 gResetStyleLabel, Сбросить стиль
    Gui, 2:Add, Button, x720 y354 w130 h28 gSaveThemePresetLabel, Сохранить тему
    Gui, 2:Add, Button, x858 y354 w130 h28 gLoadThemePresetLabel, Применить тему
    Settings_AddControl("Локальный фон (PNG / JPG / BMP, до 5 МиБ)", "CFG_BackgroundImageURL", BackgroundImageURL, 240, 404, 660, "Edit", "", text, inputText)
    Settings_AddControl("Скрывать окна из захвата", "CFG_OBSHideWindows", OBSHideWindows, 256, 500, 270, "DropDown", "Off|On", text, inputText)
    GuiControl, 2:+gCapture_ModeChanged, CFG_OBSHideWindows
    Gui, 2:Font, s9 Norm c%text%, Segoe UI
    Gui, 2:Add, Text, x548 y502 w574 h56 vCaptureStatusText BackgroundTrans +Wrap, %CaptureStatus%
    Gui, 2:Font, s8 Norm c%muted%, Segoe UI
    Gui, 2:Add, Text, x548 y566 w574 h40 BackgroundTrans +Wrap, % "OBS: «Захват окна» — метод Windows 10 (1903+). Флаг Windows не подтверждает результат записи; проверьте источник OBS."
    Settings_AddControl("Ширина таймера", "CFG_StopTimerWidth", StopTimerWidth, 240, 642, 140, "Edit", "", text, inputText)
    Settings_AddControl("Высота таймера", "CFG_StopTimerHeight", StopTimerHeight, 396, 642, 140, "Edit", "", text, inputText)
    Settings_AddControl("Прозрачность", "CFG_StopTimerTransparency", StopTimerTransparency, 552, 642, 140, "Edit", "", text, inputText)
    Settings_AddControl("Цвет рамки", "CFG_StopTimerBorderColor", StopTimerBorderColor, 708, 642, 140, "Edit", "", text, inputText)
    Settings_AddControl("Цвет цифр", "CFG_StopTimerTextColor", StopTimerTextColor, 864, 642, 140, "Edit", "", text, inputText)
    Settings_AddControl("Цвет фона", "CFG_StopTimerBgColor", StopTimerBgColor, 1020, 642, 124, "Edit", "", text, inputText)
    Settings_AddControl("Громкость таймера", "CFG_StopTimerVolume", StopTimerVolume, 240, 710, 160, "Edit", "", text, inputText)
    Gui, 2:Add, Button, x416 y742 w160 h30 gPreviewStopTimerSoundLabel, Проверить таймер
    Gui, 2:Font, s10 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x258 y806 w850 h22 BackgroundTrans, Таймеры действий
    Settings_AddControl("Эвакуация · 3 минуты", "CFG_EvacuationTimerEnabled", EvacuationTimerEnabled, 258, 840, 250, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Патруль · до доклада", "CFG_PatrolTimerEnabled", PatrolTimerEnabled, 524, 840, 250, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Пост · до доклада", "CFG_PostTimerEnabled", PostTimerEnabled, 790, 840, 250, "DropDown", "On|Off", text, inputText)

    SettingsBuildingPage := 4
    Gui, 2:Tab, 4
    Settings_AddPageFrame("Шаблоны докладов", "Одна строка поля отправляется как одно сообщение.", cardBg, cardEdge, text, muted)
    reportItems := []
    reportItems.Push(["Представление с должностью", "CFG_T_Intro", T_Intro])
    reportItems.Push(["/dep", "CFG_T_Dep", T_Dep])
    reportItems.Push(["SOS выехал", "CFG_T_SOSStart", T_SOSStart])
    reportItems.Push(["SOS прибыл", "CFG_T_SOSArrive", T_SOSArrive])
    reportItems.Push(["Гражданский вызов принят", "CFG_T_CivilCallStart", T_CivilCallStart])
    reportItems.Push(["Гражданский вызов: прибыл", "CFG_T_CivilCallArrive", T_CivilCallArrive])
    reportItems.Push(["ДТП: вызов принят", "CFG_T_CallStart", T_CallStart])
    reportItems.Push(["ДТП: прибыли", "CFG_T_CallArrive", T_CallArrive])
    reportItems.Push(["ДТП: оформление", "CFG_T_CallWorkStart", T_CallWorkStart])
    reportItems.Push(["ДТП: завершено", "CFG_T_CallWorkEnd", T_CallWorkEnd])
    Settings_AddGrid(reportItems, 240, 170, 2, 452, 112, "Multi", text, inputText)

    SettingsBuildingPage := 5
    Gui, 2:Tab, 5
    Settings_AddPageFrame("Патруль, пост и строй", "Операционные доклады и редактируемые сообщения строя.", cardBg, cardEdge, text, muted)
    operationItems := []
    operationItems.Push(["Патруль начал", "CFG_T_PatrolStart", T_PatrolStart])
    operationItems.Push(["Патруль продолжаю", "CFG_T_PatrolContinue", T_PatrolContinue])
    operationItems.Push(["Патруль завершил", "CFG_T_PatrolEnd", T_PatrolEnd])
    operationItems.Push(["Пост начал", "CFG_T_PostStart", T_PostStart])
    operationItems.Push(["Пост продолжаю", "CFG_T_PostContinue", T_PostContinue])
    operationItems.Push(["Пост завершил", "CFG_T_PostEnd", T_PostEnd])
    operationItems.Push(["Колонна начала", "CFG_T_ConvoyStart", T_ConvoyStart])
    operationItems.Push(["Колонна продолжает", "CFG_T_ConvoyCont", T_ConvoyCont])
    operationItems.Push(["Колонна завершила", "CFG_T_ConvoyEnd", T_ConvoyEnd])
    operationItems.Push(["Строй: начало", "CFG_MDS_FormationInitial", MDS_FormationInitial])
    operationItems.Push(["Строй: отсчёт", "CFG_MDS_FormationCountdown", MDS_FormationCountdown])
    operationItems.Push(["Строй: завершение", "CFG_MDS_FormationFinish", MDS_FormationFinish])
    Settings_AddGrid(operationItems, 240, 166, 2, 452, 82, "Multi", text, inputText)

    SettingsBuildingPage := 6
    Gui, 2:Tab, 6
    Settings_AddPageFrame("Основные клавиши", "Системные команды, задержание, доклады и строй.", cardBg, cardEdge, text, muted)
    Settings_AddGrid(Settings_GetCatalogItems("Hotkey", "main"), 240, 166, 4, 224, 56, "Hotkey", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    bindsStatusY := SettingsPageExtents[6] + 12
    Settings_RecordExtent(bindsStatusY + 32)
    Gui, 2:Add, Text, x240 y%bindsStatusY% w880 h28 vCFG_BindsStatusText BackgroundTrans +Wrap, Конфликтов hotkey нет.

    SettingsBuildingPage := 7
    Gui, 2:Tab, 7
    Settings_AddPageFrame("Транспортные клавиши", "Патруль, пост, колонна, эвакуация и служебные действия.", cardBg, cardEdge, text, muted)
    Settings_AddGrid(Settings_GetCatalogItems("Hotkey", "transport"), 240, 170, 3, 300, 76, "Hotkey", text, inputText)

    SettingsBuildingPage := 8
    Gui, 2:Tab, 8
    Settings_AddPageFrame("TXT-команды", "Триггеры вводятся в чат с префиксом ! и сохраняются в профиль.", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 240, 166, 904, 96, panel, cardEdge, 1)
    Settings_AddControl("Ввод текстовых команд", "CFG_TextTriggerInputMode", PrivateText_ModeToUiLabel(TextTriggerInputMode), 256, 176, 340, "DropDown", "Чат + окно AHK|Только окно AHK", text, inputText)
    Gui, 2:Font, s9 Norm c%muted%, Segoe UI
    Gui, 2:Add, Text, x622 y176 w494 h48 +Wrap BackgroundTrans, Alt+T по умолчанию / !бинд / !bind открывают личное окно в обоих режимах. «Только окно AHK» отключает команды в чате.
    Gui, 2:Add, Button, x622 y232 w160 h24 gPrivateText_RestoreDefaultKey, Восстановить Alt+T
    Gui, 2:Add, Text, x798 y234 w316 h22 BackgroundTrans, Затем нажмите «Сохранить».
    Settings_AddGrid(Settings_GetCatalogItems("Trigger", "commands"), 240, 280, 5, 180, 52, "Edit", text, inputText)

    SettingsBuildingPage := 9
    Gui, 2:Tab, 9
    Settings_AddPageFrame("Документы", "Кодексы открываются по TXT-командам и листаются PgUp / PgDn.", cardBg, cardEdge, text, muted)
    documentItems := Settings_GetCatalogItems("Trigger", "documents")
    Settings_AddGrid(documentItems, 240, 174, 3, 300, 76, "Edit", text, inputText)
    documentOptionsY := Max(618, 174 + Ceil(documentItems.Length() / 3) * 76 + 16)
    AddOutlinedPanel(2, 242, documentOptionsY, 884, 120, panel, cardEdge, 1)
    Settings_AddControl("Режим карт территорий", "CFG_TerritoryMapMode", CFG_TerritoryMapMode, 258, documentOptionsY + 12, 270, "DropDown", "Локальные копии|Официальные ссылки", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, % "x548 y" . (documentOptionsY + 10) . " w560 h38 BackgroundTrans +Wrap", Локальные копии — открываются внутри AHK FOR GOS BY SBEZRUK без интернета; режим по умолчанию.
    Gui, 2:Add, Text, % "x548 y" . (documentOptionsY + 62) . " w560 h42 BackgroundTrans +Wrap", Официальные ссылки — соответствующий пост открывается через системный браузер; нужный спойлер необходимо развернуть вручную.
    Settings_RecordExtent(documentOptionsY + 132)

    SettingsBuildingPage := 10
    Gui, 2:Tab, 10
    Settings_AddPageFrame("RP: персонаж", "Последовательности /me и /do для взаимодействия с персонажем.", cardBg, cardEdge, text, muted)
    rpPerson := []
    rpPerson.Push(["Остановка / мегафон", "CFG_RP_StopChase", RP_StopChase])
    rpPerson.Push(["Изъятие из авто", "CFG_RP_Deject", RP_Deject])
    rpPerson.Push(["Посадка в авто", "CFG_RP_InCar", RP_InCar])
    rpPerson.Push(["Служебное удостоверение", "CFG_RP_Doc", RP_Doc])
    rpPerson.Push(["Личный досмотр", "CFG_RP_Search", RP_Search])
    rpPerson.Push(["Арест", "CFG_RP_Arrest", RP_Arrest])
    rpPerson.Push(["Штраф", "CFG_RP_Fine", RP_Fine])
    rpPerson.Push(["Протокол", "CFG_RP_Protocol", RP_Protocol])
    rpPerson.Push(["Права", "CFG_RP_Rights", RP_Rights])
    Settings_AddGrid(rpPerson, 240, 170, 3, 300, 184, "Multi", text, inputText)

    SettingsBuildingPage := 11
    Gui, 2:Tab, 11
    Settings_AddPageFrame("RP: транспорт", "Эвакуация, осмотр транспорта и служебные визитки.", cardBg, cardEdge, text, muted)
    rpVehicle := []
    rpVehicle.Push(["Эвакуация: старт", "CFG_RP_TowStart", RP_TowStart])
    rpVehicle.Push(["Эвакуация: конец", "CFG_RP_TowEnd", RP_TowEnd])
    rpVehicle.Push(["Осмотр ТС", "CFG_RP_CarSearch", RP_CarSearch])
    rpVehicle.Push(["Визитка DS", "CFG_RP_CardDS", RP_CardDS])
    rpVehicle.Push(["Визитка VK", "CFG_RP_CardVK", RP_CardVK])
    Settings_AddGrid(rpVehicle, 240, 180, 2, 452, 176, "Multi", text, inputText)

    SettingsBuildingPage := 12
    Gui, 2:Tab, 12
    Settings_AddPageFrame("Автоматизация", "Очередь, задачи, автодоклады и диагностические инструменты.", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 242, 174, 884, 120, panel, cardEdge, 1)
    AddOutlinedPanel(2, 242, 312, 884, 112, panel, cardEdge, 1)
    AddOutlinedPanel(2, 242, 430, 884, 52, panel, cardEdge, 1)
    Gui, 2:Font, s11 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x250 y184 w860 h28 vCFG_AutomationQueueStatus BackgroundTrans, Очередь: --
    Gui, 2:Add, Text, x250 y224 w860 h28 vCFG_AutomationTaskStatus BackgroundTrans, Задачи: --
    Gui, 2:Add, Text, x250 y264 w860 h28 vCFG_AutomationSafeStatus BackgroundTrans, SafeMode / MockMode: --
    Gui, 2:Font, Norm s10 c%text%, Segoe UI
    Gui, 2:Add, Button, x250 y324 w190 h34 gCancelAllAutomationLabel, Остановить всё
    Gui, 2:Add, Button, x454 y324 w190 h34 gClearChatQueueLabel, Очистить очередь
    Gui, 2:Add, Button, x658 y324 w190 h34 gOpenMockPreviewLabel, Тестовый чат
    Gui, 2:Add, Button, x862 y324 w190 h34 gRunDiagnosticsFromGuiLabel, Диагностика
    Gui, 2:Add, Button, x250 y378 w190 h34 gRunSelfTestFromGuiLabel, Запустить self-test
    Gui, 2:Add, Button, x454 y378 w190 h34 gRunMockQueueDemoLabel, Тест очереди
    Gui, 2:Add, Button, x658 y378 w190 h34 gRunMemoryLiveTestLabel, Memory live-тест
    Gui, 2:Add, Button, x862 y378 w190 h34 gCheckAzmpLabel, Проверить azmp.dll
    Gui, 2:Add, Button, x250 y732 w250 h28 gOpenCustomFunctionBuilderLabel, Конструктор своих функций
    Gui, 2:Font, Norm s8 c%muted%, Segoe UI
    Gui, 2:Add, Text, x514 y736 w596 h20 BackgroundTrans, Свои последовательности, паузы, таймеры, уведомления и TXT/hotkey-запуск.
    chatLogChecked := (ChatLogReaderEnabled = "On") ? " Checked" : ""
    autoTargetChecked := (AutoTargetIDEnabled = "On") ? " Checked" : ""
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Checkbox, x250 y438 w170 h24 vCFG_ChatLogReaderEnabled%chatLogChecked%, Читать chatlog.txt
    Gui, 2:Add, Checkbox, x430 y438 w170 h24 vCFG_AutoTargetIDEnabled%autoTargetChecked%, ID по ПКМ
    Settings_AddControl("Путь chatlog.txt", "CFG_ChatLogPath", ChatLogPath, 610, 418, 500, "Edit", "", text, inputText)
    AddOutlinedPanel(2, 242, 494, 884, 210, panel, cardEdge, 1)
    Gui, 2:Font, s11 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x258 y510 w850 h24 BackgroundTrans, Автоматический доклад каждые 10 минут
    Settings_AddControl("Режим", "CFG_AutoReportMode", AutoReportMode, 258, 542, 220, "DropDown", "Патруль|Пост", text, inputText)
    Settings_AddControl("Продолжительность, минут (10–600)", "CFG_AutoReportDurationMin", AutoReportDurationMin, 496, 542, 250, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s10 c%text%, Segoe UI
    Gui, 2:Add, Button, x770 y574 w150 h32 gAutoReportStartLabel, Запустить
    Gui, 2:Add, Button, x936 y574 w150 h32 gAutoReportStopLabel, Остановить
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x258 y620 w828 h48 vCFG_AutoReportStatus BackgroundTrans +Wrap, % AutoReport_GetStatusText()
    SettingsBuildingPage := 13
    Gui, 2:Tab, 13
    Settings_AddPageFrame("Автоскриншоты", "Распознавание действий в chatlog.txt. Chatlog читается без изменения файла игры.", cardBg, cardEdge, text, muted)
    AddOutlinedPanel(2, 242, 174, 884, 236, panel, cardEdge, 1)
    Settings_AddControl("Автоскриншоты", "CFG_EvidenceScreenshotMode", EvidenceScreenshotMode, 258, 190, 150, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Свой Nick_Name", "CFG_ChatLogPlayerNickname", ChatLogPlayerNickname, 426, 190, 236, "Edit", "", text, inputText)
    Settings_AddControl("Режим документов", "CFG_EvidenceDocumentActivationMode", EvidenceDocumentActivationMode, 680, 190, 210, "DropDown", "Только радиус|После представления", text, inputText)
    Settings_AddControl("Способ снимка", "CFG_EvidenceScreenshotMethod", EvidenceScreenshotMethod, 908, 190, 198, "DropDown", "Alt+F1|PrintScreen|Win+PrintScreen|Alt+PrintScreen|F8|F12", text, inputText)
    Settings_AddControl("Ожидание после представления, сек", "CFG_EvidenceDocumentWaitSec", EvidenceDocumentWaitSec, 258, 274, 250, "Edit", "", text, inputText)
    Settings_AddControl("Радиус документов, ед.", "CFG_EvidenceDocumentDistanceLimit", EvidenceDocumentDistanceLimit, 526, 274, 210, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x258 y354 w830 h44 BackgroundTrans +Wrap, Укажите Nick_Name сотрудника точно как в chatlog.txt (сейчас: Semen_Lukashenko). Режим «Только радиус» работает постоянно; «После представления» включает ожидание после команды «Представление».

    SettingsBuildingPage := 0
    Gui, 2:Tab
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x242 y772 w660 h18 vSettingsStatusText BackgroundTrans, Изменения сохраняются кнопкой «Сохранить» или при закрытии окна.
    Gui, 2:Add, Text, x920 y772 w240 h18 Right +0x4000 vSettingsOwnerText BackgroundTrans, AHK FOR GOS BY SBEZRUK · SBezruk180
    SettingsCanvasHeight := Max(800, SettingsPageExtents[1] + 60)
    SettingsGuiReady := 1
    Settings_UpdateScrollbars()
    Capture_ApplyWindow(hSettingsWnd)
    RefreshSettingsTabs()
}

SyncConfigOnlyProfileFieldsToCfg() {
    global
    CFG_ReportRole := ReportRole
    CFG_T_CivilCallStart := T_CivilCallStart
    CFG_T_CivilCallArrive := T_CivilCallArrive
    CFG_Bind_CivilCallStart := Bind_CivilCallStart
    CFG_Bind_CivilCallArrive := Bind_CivilCallArrive
    CFG_Trig_CivilCallStart := Trig_CivilCallStart
    CFG_Trig_CivilCallArrive := Trig_CivilCallArrive
    CFG_Bind_VehicleLookup := Bind_VehicleLookup
    CFG_Trig_VehicleLookup := Trig_VehicleLookup
    CFG_Bind_WantedRemoval := Bind_WantedRemoval
    CFG_Trig_WantedRemoval := Trig_WantedRemoval
    CFG_Bind_ChaseNoID := Bind_ChaseNoID
    CFG_Trig_ChaseNoID := Trig_ChaseNoID
    CFG_Bind_LawSearchSubmit := Bind_LawSearchSubmit
    CFG_AutoReportMode := AutoReportMode
    CFG_AutoReportDurationMin := AutoReportDurationMin
    CFG_TerritoryMapMode := TerritoryMapMode_ToUiLabel(TerritoryMapMode)
    CFG_T_HijackStart := T_HijackStart
    CFG_T_HijackArrive := T_HijackArrive
    catalog := GetBindCatalog()
    for _, meta in catalog {
        if (!IsBindCatalogEntryEditable(meta)) {
            if (meta.HotkeyVar != "")
                SetDynamicGlobalValue("CFG_" . meta.HotkeyVar, GetDynamicGlobalValue(meta.HotkeyVar))
            if (meta.TriggerVar != "")
                SetDynamicGlobalValue("CFG_" . meta.TriggerVar, GetDynamicGlobalValue(meta.TriggerVar))
        }
    }
    for _, name in ["AssistOOPEnabled", "AssistStunEnabled", "AssistChaseEnabled", "AssistHouseEnabled", "AssistDrugsEnabled", "AssistPDPCuffEnabled"]
        SetDynamicGlobalValue("CFG_" . name, GetDynamicGlobalValue(name) = "On" ? 1 : 0)
}

ApplyCfgConfigOnlyProfileFieldsToGlobals() {
    global
    ReportRole := CFG_ReportRole
    T_CivilCallStart := CFG_T_CivilCallStart
    T_CivilCallArrive := CFG_T_CivilCallArrive
    Bind_CivilCallStart := CFG_Bind_CivilCallStart
    Bind_CivilCallArrive := CFG_Bind_CivilCallArrive
    Trig_CivilCallStart := CFG_Trig_CivilCallStart
    Trig_CivilCallArrive := CFG_Trig_CivilCallArrive
    Bind_VehicleLookup := CFG_Bind_VehicleLookup
    Trig_VehicleLookup := CFG_Trig_VehicleLookup
    Bind_WantedRemoval := CFG_Bind_WantedRemoval
    Trig_WantedRemoval := CFG_Trig_WantedRemoval
    Bind_ChaseNoID := CFG_Bind_ChaseNoID
    Trig_ChaseNoID := CFG_Trig_ChaseNoID
    Bind_LawSearchSubmit := CFG_Bind_LawSearchSubmit
    AutoReportMode := CFG_AutoReportMode
    AutoReportDurationMin := CFG_AutoReportDurationMin
    TerritoryMapMode := TerritoryMapMode_FromUiLabel(CFG_TerritoryMapMode)
    CFG_TerritoryMapMode := TerritoryMapMode_ToUiLabel(TerritoryMapMode)
    AutoReport_NormalizeMode(AutoReportMode)
    if !AutoReport_IsValidDuration(AutoReportDurationMin)
        AutoReportDurationMin := 15
}

ApplyCfgCatalogValuesToGlobals() {
    global
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (meta.HotkeyVar != "")
        {
            cfgVar := "CFG_" . meta.HotkeyVar
            SetDynamicGlobalValue(meta.HotkeyVar, GetDynamicGlobalValue(cfgVar))
        }
        if (meta.TriggerVar != "")
        {
            cfgVar := "CFG_" . meta.TriggerVar
            SetDynamicGlobalValue(meta.TriggerVar, GetDynamicGlobalValue(cfgVar))
        }
    }
}

ApplyCfgUiValuesToGlobals() {
    global
    TextTriggerInputMode := CFG_TextTriggerInputMode
    PrivateText_NormalizeMode(TextTriggerInputMode)
    OBSHideWindows := CFG_OBSHideWindows
    NormalizeOnOff(OBSHideWindows, "Off")
    Capture_RefreshWindows()
    BackgroundImageURL := CFG_BackgroundImageURL
    if (CFG_FullscreenSafeGui != "")
        FullscreenSafeGui := CFG_FullscreenSafeGui
    ProfileMode := CFG_ProfileMode
    HUDMode := CFG_HUDMode
    MenuTransparency := CFG_MenuTransparency
    HUDTransparency := CFG_HUDTransparency
    BindListTransparency := CFG_BindListTransparency
    if (CFG_SafeModeEnabled != "")
        SafeModeEnabled := CFG_SafeModeEnabled
    if (CFG_SafeBlockWhenChat != "")
        SafeBlockWhenChat := CFG_SafeBlockWhenChat
    if (CFG_SafeVehicleChecks != "")
        SafeVehicleChecks := CFG_SafeVehicleChecks
    if (CFG_SafeRequireChatForEditable != "")
        SafeRequireChatForEditable := CFG_SafeRequireChatForEditable
    if (CFG_SafeTooltipWarnings != "")
        SafeTooltipWarnings := CFG_SafeTooltipWarnings
    if (CFG_SafeDistanceChecks != "")
        SafeDistanceChecks := CFG_SafeDistanceChecks
    if (CFG_SafeDistanceLimit != "")
        SafeDistanceLimit := CFG_SafeDistanceLimit
    if (CFG_IDCheckEnabled = "On")
        IDCheckEnabled := 1
    else if (CFG_IDCheckEnabled = "Off")
        IDCheckEnabled := 0
    StopTimerWidth := CFG_StopTimerWidth
    StopTimerHeight := CFG_StopTimerHeight
    StopTimerTransparency := CFG_StopTimerTransparency
    StopTimerBorderColor := CFG_StopTimerBorderColor
    StopTimerTextColor := CFG_StopTimerTextColor
    StopTimerBgColor := CFG_StopTimerBgColor
    StopTimerVolume := CFG_StopTimerVolume
    EvacuationTimerEnabled := CFG_EvacuationTimerEnabled
    PatrolTimerEnabled := CFG_PatrolTimerEnabled
    PostTimerEnabled := CFG_PostTimerEnabled
    TextSendMode := ChatTyping_ModeFromLabel(CFG_TextSendMode)
    ChatTypingDelayMs := CFG_ChatTypingDelayMs
    ChatTypingSpeedMode := CFG_ChatTypingSpeedMode
    ChatTypingMinCPS := CFG_ChatTypingMinCPS
    ChatTypingMaxCPS := CFG_ChatTypingMaxCPS
    ChatFactionCommands := CFG_ChatFactionCommands
    IDEntryMode := CFG_IDEntryMode
    IDCaptureTimeoutSec := CFG_IDCaptureTimeoutSec
    ChatTyping_NormalizeDelay(ChatTypingDelayMs)
    ChatTyping_NormalizeSpeedConfig(ChatTypingSpeedMode, ChatTypingMinCPS, ChatTypingMaxCPS)
    ChatTyping_NormalizeCommands(ChatFactionCommands)
    NormalizeIDEntryMode(IDEntryMode)
    IDCaptureTimeoutSec := IDCapture_NormalizeTimeout(IDCaptureTimeoutSec)
    GameWindowTitle := CFG_GameWindowTitle
    GameProcessName := CFG_GameProcessName
    AzmpExpectedSHA256 := CFG_AzmpExpectedSHA256
    MockMode := CFG_MockMode
    ChatQueueEnabled := CFG_ChatQueueEnabled
    ChatQueueMinDelay := CFG_ChatQueueMinDelay
    ChatLogReaderEnabled := CFG_ChatLogReaderEnabled ? "On" : "Off"
    ChatLogPath := CFG_ChatLogPath
    ChatLogPlayerNickname := CFG_ChatLogPlayerNickname
    AutoTargetIDEnabled := CFG_AutoTargetIDEnabled ? "On" : "Off"
    ContextNotificationMode := CFG_ContextNotificationMode
    ContextNotificationTimeoutSec := CFG_ContextNotificationTimeoutSec
    AssistOOPEnabled := CFG_AssistOOPEnabled ? "On" : "Off"
    AssistStunEnabled := CFG_AssistStunEnabled ? "On" : "Off"
    AssistChaseEnabled := CFG_AssistChaseEnabled ? "On" : "Off"
    AssistHouseEnabled := CFG_AssistHouseEnabled ? "On" : "Off"
    AssistDrugsEnabled := CFG_AssistDrugsEnabled ? "On" : "Off"
    AssistPDPCuffEnabled := CFG_AssistPDPCuffEnabled ? "On" : "Off"
    NotifySoundEnabled := CFG_NotifySoundEnabled
    NotifyVolume := CFG_NotifyVolume
    ActionCooldownMs := CFG_ActionCooldownMs
    SequenceLineDelay := CFG_SequenceLineDelay
    ProfileSaveBackups := CFG_ProfileSaveBackups
    EvidenceScreenshotMode := CFG_EvidenceScreenshotMode
    EvidenceScreenshotMethod := CFG_EvidenceScreenshotMethod
    EvidenceDocumentActivationMode := CFG_EvidenceDocumentActivationMode
    EvidenceDocumentWaitSec := CFG_EvidenceDocumentWaitSec
    EvidenceDocumentDistanceLimit := CFG_EvidenceDocumentDistanceLimit
    CustomMenuColor := CFG_CustomMenuColor
    CustomTextColor := CFG_CustomTextColor
    CustomBorderColor := CFG_CustomBorderColor
    CustomTabColor := CFG_CustomTabColor
    CustomBindListColor := CFG_CustomBindListColor
    UIRoundness := CFG_UIRoundness
    InnerRoundness := CFG_InnerRoundness
    GuiTransparency := CFG_GuiTransparency
    NormalizeColorNumber(CustomMenuColor)
    NormalizeColorNumber(CustomTextColor)
    NormalizeColorNumber(CustomBorderColor)
    NormalizeColorNumber(CustomTabColor)
    NormalizeColorNumber(CustomBindListColor)
    NormalizeNumberRange(UIRoundness, 18, 0, 45)
    NormalizeNumberRange(GuiTransparency, 225, 120, 255)
    NormalizeOnOff(SafeModeEnabled, "Off")
    NormalizeOnOff(SafeBlockWhenChat, "Off")
    NormalizeOnOff(SafeVehicleChecks, "Off")
    NormalizeOnOff(SafeRequireChatForEditable, "Off")
    NormalizeOnOff(SafeTooltipWarnings, "Off")
    NormalizeOnOff(SafeDistanceChecks, "Off")
    NormalizeNumberRange(SafeDistanceLimit, 12, 2, 50)
    IDCheckEnabled := IDCheckEnabled ? 1 : 0
    NormalizeNumberRange(StopTimerWidth, 170, 170, 500)
    NormalizeNumberRange(StopTimerHeight, 76, 76, 250)
    NormalizeNumberRange(StopTimerTransparency, 255, 120, 255)
    NormalizeColorNumber(StopTimerBorderColor)
    NormalizeColorNumber(StopTimerTextColor)
    NormalizeColorNumber(StopTimerBgColor)
    NormalizeNumberRange(StopTimerVolume, 65, 0, 100)
    NormalizeNumberRange(StopTimerX, 100, -4000, 8000)
    NormalizeNumberRange(StopTimerY, 90, -4000, 8000)
    NormalizeOnOff(EvacuationTimerEnabled, "On")
    NormalizeOnOff(PatrolTimerEnabled, "On")
    NormalizeOnOff(PostTimerEnabled, "On")
    NormalizeNumberRange(ActionTimerX, 100, -4000, 8000)
    NormalizeNumberRange(ActionTimerY, 180, -4000, 8000)
    NormalizeTextSendMode(TextSendMode)
    NormalizeGameWindowTitle(GameWindowTitle)
    NormalizeGameProcessName(GameProcessName)
    NormalizeSHA256(AzmpExpectedSHA256)
    ApplyGameProcessSelector()
    NormalizeOnOff(MockMode, "Off")
    NormalizeOnOff(ChatQueueEnabled, "On")
    NormalizeOnOff(ChatLogReaderEnabled, "On")
    NormalizeOnOff(ChatLogAutoCleanupEnabled, "Off")
    NormalizeNumberRange(ChatLogMaxSizeKB, 512, 256, 65536)
    NormalizeNumberRange(ChatLogKeepTailKB, 32, 0, 1024)
    if (ChatLogKeepTailKB > ChatLogMaxSizeKB // 2)
        ChatLogKeepTailKB := ChatLogMaxSizeKB // 2
    NormalizeOnOff(AutoTargetIDEnabled, "On")
    ChatLogPath := Trim(ChatLogPath)
    ChatLogPlayerNickname := Trim(ChatLogPlayerNickname)
    NormalizeOnOff(AssistOOPEnabled, "On")
    NormalizeOnOff(AssistStunEnabled, "On")
    NormalizeOnOff(AssistChaseEnabled, "On")
    NormalizeOnOff(AssistHouseEnabled, "On")
    NormalizeOnOff(AssistDrugsEnabled, "On")
    NormalizeOnOff(AssistPDPCuffEnabled, "On")
    NormalizeNumberRange(ChatQueueMinDelay, 700, 250, 5000)
    NormalizeOnOff(NotifySoundEnabled, "On")
    NormalizeNumberRange(NotifyVolume, 65, 0, 100)
    NormalizeNumberRange(ActionCooldownMs, 250, 0, 5000)
    NormalizeNumberRange(SequenceLineDelay, 700, 250, 3000)
    if (ContextNotificationMode != "Чат")
        ContextNotificationMode := "Плашка"
    NormalizeNumberRange(ContextNotificationTimeoutSec, 8, 2, 30)
    NormalizeOnOff(EvidenceScreenshotMode, "Off")
    if (EvidenceScreenshotMethod != "PrintScreen" && EvidenceScreenshotMethod != "Win+PrintScreen"
        && EvidenceScreenshotMethod != "Alt+PrintScreen" && EvidenceScreenshotMethod != "F8"
        && EvidenceScreenshotMethod != "F12")
        EvidenceScreenshotMethod := "Alt+F1"
    if (EvidenceDocumentActivationMode != "После представления")
        EvidenceDocumentActivationMode := "Только радиус"
    NormalizeNumberRange(EvidenceDocumentWaitSec, 90, 5, 300)
    NormalizeNumberRange(EvidenceDocumentDistanceLimit, 20, 2, 100)
    NormalizeOnOff(ProfileSaveBackups, "On")
    NormalizeFullscreenSafeGui(FullscreenSafeGui)
    ResolveBackgroundImage()
    BindListItems := CFG_BindListItems
    NormalizeBindListItemsValue(BindListItems)
    TabGuiHeaderText := CFG_TabGuiHeaderText
    NormalizeSingleLineValue(TabGuiHeaderText, "AMZ Helper | sbezruk180")
    ActionTimer_ReconcileSettings()
    InitChatLogReader()
}

ApplyCfgProfileIdentityValuesToGlobals() {
    global
    IntroRole := CFG_IntroRole
    Rank := CFG_Rank
    ReportRank := CFG_ReportRank
    Surname := CFG_Surname
    PersonalBadge := Trim(CFG_PersonalBadge)
    PatrolRoute := CFG_PatrolRoute
    PostRoute := CFG_PostRoute
    ConvoyRoute := CFG_ConvoyRoute
    PatrolUnit := CFG_PatrolUnit
    PatrolCrewCount := CFG_PatrolCrewCount
    PostUnit := CFG_PostUnit
    PostCrewCount := CFG_PostCrewCount
}

ApplyCfgTemplateAndRpTextsToGlobals() {
    global
    T_Intro := CFG_T_Intro
    T_Dep := CFG_T_Dep
    T_SOSStart := CFG_T_SOSStart
    T_SOSArrive := CFG_T_SOSArrive
    T_HijackStart := CFG_T_HijackStart
    T_HijackArrive := CFG_T_HijackArrive
    T_CallStart := CFG_T_CallStart
    T_CallArrive := CFG_T_CallArrive
    T_CallWorkStart := CFG_T_CallWorkStart
    T_CallWorkEnd := CFG_T_CallWorkEnd
    T_PatrolStart := CFG_T_PatrolStart
    T_PatrolContinue := CFG_T_PatrolContinue
    T_PatrolEnd := CFG_T_PatrolEnd
    RP_StopChase := CFG_RP_StopChase
    RP_Deject := CFG_RP_Deject
    RP_InCar := CFG_RP_InCar
    RP_Doc := CFG_RP_Doc
    RP_Search := CFG_RP_Search
    RP_TowStart := CFG_RP_TowStart
    RP_TowEnd := CFG_RP_TowEnd
    RP_CarSearch := CFG_RP_CarSearch
    RP_Arrest := CFG_RP_Arrest
    RP_Fine := CFG_RP_Fine
    RP_Protocol := CFG_RP_Protocol
    RP_Rights := CFG_RP_Rights
    RP_CardDS := CFG_RP_CardDS
    RP_CardVK := CFG_RP_CardVK
    MDS_FormationInitial := CFG_MDS_FormationInitial
    MDS_FormationCountdown := CFG_MDS_FormationCountdown
    MDS_FormationFinish := CFG_MDS_FormationFinish
    T_PostStart := CFG_T_PostStart
    T_PostContinue := CFG_T_PostContinue
    T_PostEnd := CFG_T_PostEnd
    T_ConvoyStart := CFG_T_ConvoyStart
    T_ConvoyCont := CFG_T_ConvoyCont
    T_ConvoyEnd := CFG_T_ConvoyEnd
}

PrivateText_RestoreDefaultKey(params*) {
    global CFG_Bind_TextCommandInput
    Gui, 2:Submit, NoHide
    CFG_Bind_TextCommandInput := "!t"
    GuiControl, 2:, CFG_Bind_TextCommandInput, !t
    ResolveCfgHotkeyConflicts("CFG_Bind_TextCommandInput", 1)
    SetSettingsStatus("Клавиша окна TXT восстановлена: Alt+T. Нажмите «Сохранить».")
}
