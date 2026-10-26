; ui overlays subsystem. Definitions only; initialization is in bootstrap.

PromoteOverlayWindow(hwnd, keepShown := 1, noActivate := 1) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return
    flags := 0x0001 | 0x0002
    flags |= 0x0010
    if (keepShown && DllCall("IsWindowVisible", "Ptr", hwnd))
        flags |= 0x0040
    WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
}

RebuildFloatingGUI() {
    global HUDVisible, BindListVisible
    UpdateLawGuiColors()
    CreateHUD()
    UpdateHUD()
    if (!HUDVisible)
        Gui, 12:Hide
    if (BindListVisible)
    {
        CreateBindList()
        UpdateBindList()
    }
    ActionTimer_Rebuild()
}

ShowTriggerValue(val) {
    if (val = "" or val = "ERROR")
        return "—"
    return val
}

ShowHotkeyValue(val) {
    if (val = "" or val = "ERROR")
        return "—"
    return val
}

MockPreview_Append(text) {
    global ChatQueuePreviewText, ChatQueuePreviewLineCount, ChatQueuePreviewKnownLength
    if Training_IsActive()
        Training_RecordOutput(text)
    MockPreview_LineCount()
    FormatTime, stamp,, HH:mm:ss
    if (ChatQueuePreviewText != "")
        ChatQueuePreviewText .= "`r`n"
    ChatQueuePreviewText .= "[" . stamp . "] " . text
    StrReplace(text, "`n", "", addedBreaks)
    ChatQueuePreviewLineCount += addedBreaks + 1
    ; Trim a large append in one pass instead of allocating one array per line.
    if (ChatQueuePreviewLineCount > 500) {
        boundary := InStr(ChatQueuePreviewText, "`n", false, 0, 500)
        ChatQueuePreviewText := SubStr(ChatQueuePreviewText, boundary + 1)
        ChatQueuePreviewLineCount := 500
    }
    length := StrLen(ChatQueuePreviewText)
    if (length > 131072) {
        start := length - 131072 + 1
        boundary := InStr(ChatQueuePreviewText, "`n", false, start)
        ChatQueuePreviewText := SubStr(ChatQueuePreviewText, boundary ? boundary + 1 : start)
        ChatQueuePreviewLineCount := MockPreview_CountLines(ChatQueuePreviewText)
    }
    ChatQueuePreviewKnownLength := StrLen(ChatQueuePreviewText)
    if (!AuditTestMode && !Training_IsActive())
        MockPreview_Show()
}

MockPreview_CountLines(text) {
    if (text = "")
        return 0
    StrReplace(text, "`n", "", breaks)
    return breaks + 1
}

MockPreview_LineCount() {
    global ChatQueuePreviewText, ChatQueuePreviewLineCount, ChatQueuePreviewKnownLength
    length := StrLen(ChatQueuePreviewText)
    if (length != ChatQueuePreviewKnownLength) {
        ChatQueuePreviewLineCount := MockPreview_CountLines(ChatQueuePreviewText)
        ChatQueuePreviewKnownLength := length
    }
    return ChatQueuePreviewLineCount
}

MockPreview_Show() {
    global hMockPreviewWnd, MockPreviewEdit, MockPreviewCountText, ChatQueuePreviewText, ThemeMode
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, text, accent)
    count := MockPreview_LineCount()
    if (!hMockPreviewWnd)
    {
        Gui, 41:Destroy
        Gui, 41:+HwndhMockPreviewWnd +AlwaysOnTop +ToolWindow -Resize
        Gui, 41:Color, %bg%, %controlBg%
        Gui, 41:Font, s13 Bold c%text%, Segoe UI
        Gui, 41:Add, Text, x20 y16 w400 h28 BackgroundTrans, Тестовый чат
        Gui, 41:Font, Norm s9 c%muted%, Segoe UI
        Gui, 41:Add, Text, x430 y22 w190 h20 Right vMockPreviewCountText BackgroundTrans, % "Строк: " . count
        Gui, 41:Font, Norm s10 c%inputText%, Consolas
        Gui, 41:Add, Edit, x20 y60 w600 h290 ReadOnly -Wrap vMockPreviewEdit, %ChatQueuePreviewText%
        Gui, 41:Font, Norm s10 c%text%, Segoe UI
        Gui, 41:Add, Button, x20 y370 w130 h34 gClearMockPreviewLabel, Очистить
        Gui, 41:Add, Button, x490 y370 w130 h34 gCloseMockPreviewLabel, Закрыть
        Capture_BeforeShow("41")
        Gui, 41:Show, w640 h420 NoActivate, AMZ MockMode - тест без игры
        WinSet, Transparent, 255, ahk_id %hMockPreviewWnd%
    }
    GuiControl, 41:, MockPreviewEdit, %ChatQueuePreviewText%
    GuiControl, 41:, MockPreviewCountText, % "Строк: " . count
}

BindMenuWarn(msg := "") {
    if (msg = "")
        msg := "Меню биндов открыто. Используй !меню для закрытия."
    Notify("warn")
    ServiceUI_Notify(msg, 1600)
    return false
}

BindMenuHotkeyBlockedWarn() {
    static lastWarnTick := 0
    nowTick := TickNow()
    if (lastWarnTick > 0 && nowTick - lastWarnTick < 1200)
        return
    lastWarnTick := nowTick
    Notify("warn")
    ServiceUI_Notify("Меню биндов открыто. Закрой !меню перед действием.", 1400)
}

BuildBindMenuAliasList(meta) {
    aliases := []
    aliases.Push("!" . meta.Token)
    aliases.Push("!" . meta.Label)
    if (meta.Token = "WantedList")
        aliases.Push("!розыскиваемые")
    else if (meta.Token = "Cuff")
        aliases.Push("!cuff")
    else if (meta.Token = "Deject")
        aliases.Push("!deject")
    else if (meta.Token = "SOS")
        aliases.Push("!sos")
    return aliases
}

HandleBindMenuEnter() {
    global BindMenuEditMode
    if (!BindMenuEditMode)
        return false

    lineText := GetActiveChatText()
    if (lineText = "")
    {
        ClearBindMenuChatLine()
        return true
    }

    if !TryHandleBindMenuLine(lineText)
    {
        ClearBindMenuChatLine()
        BindMenuWarn()
    }
    return true
}

HandleBindMenuApplyHotkey(inputEpoch := 0) {
    global BindMenuEditMode
    inputEpoch := AutomationEpoch
    if (!BindMenuEditMode)
        return false

    SafeSend("{Alt up}", "Input", inputEpoch)
    Sleep, 20

    lineText := GetActiveChatText()
    if (lineText = "")
    {
        ClearBindMenuChatLine(true)
        return true
    }

    normalized := Trim(lineText)
    lowered := normalized
    StringLower, lowered, lowered
    if (lowered = "!меню" || lowered = "!menu")
    {
        ClearBindMenuChatLine(true)
        ForceCloseBindMenuEditMode("Меню биндов закрыто.")
        return true
    }

    if TryHandleBindMenuLine(normalized)
    {
        ClearBindMenuChatLine(true)
        return true
    }

    ClearBindMenuChatLine(true)
    BindMenuWarn()
    return true
}

BuildChatBindMenuRows() {
    rows := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        row := BuildBindListRow(meta)
        row.Command := GetBindMenuDisplayCommand(meta)
        rows.Push(row)
    }
    return rows
}

ShowChatBindMenu() {
    global BindMenuVisible, BindMenuEditMode, hBindMenuWnd, BindMenuW, BindMenuH
    global BindListTransparency, CustomBindListColor, CustomTextColor, UIRoundness, InnerRoundness

    BindMenuEditMode := true
    SuspendGameTextTriggersForBindMenu()

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    if (CustomBindListColor != "")
    {
        panel := CustomBindListColor
        if (CustomTextColor = "")
        {
            if (ColorBrightness(panel) >= 140)
                text := "1D232B", muted := "66727F"
            else
                text := "F4F6F8", muted := "A9B1BA"
        }
    }

    controlBg := ""
    inputText := ""
    cardBg := ""
    cardEdge := ""
    GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, text, accent)

    overlayW := Floor(A_ScreenWidth * 0.52)
    NormalizeNumberRange(overlayW, 900, 620, 1080)
    if (overlayW > A_ScreenWidth - 40)
        overlayW := A_ScreenWidth - 40
    overlayH := Floor(A_ScreenHeight * 0.88)
    NormalizeNumberRange(overlayH, 880, 520, 1020)
    if (overlayH > A_ScreenHeight - 60)
        overlayH := A_ScreenHeight - 60
    if (overlayW < 560)
        overlayW := 560
    if (overlayH < 500)
        overlayH := 500

    overlayX := A_ScreenWidth - overlayW - 24
    if (overlayX < 10)
        overlayX := 10
    overlayY := Floor((A_ScreenHeight - overlayH) / 2)
    if (overlayY < 10)
        overlayY := 10

    BindMenuW := overlayW
    BindMenuH := overlayH
    overlayAlpha := BindListTransparency
    NormalizeNumberRange(overlayAlpha, 220, 120, 255)

    rows := BuildChatBindMenuRows()
    contentX := 24
    contentW := overlayW - 48
    gutter := 20
    colW := Floor((contentW - gutter) / 2)
    headerY := 22
    helpY := 52
    formatY := 70
    examplesY := 88
    tableHeaderY := 116
    listStartY := 140
    bottomY := overlayH - 42
    rowH := 18
    rowGap := 2
    categoryH := 18
    gap := 3

    Gui, 19:Destroy
    Gui, 19:+HwndhBindMenuWnd +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 +E0x08000000
    Gui, 19:Color, %panel%
    Gui, 19:Margin, 0, 0

    AddOutlinedPanel(19, 0, 0, overlayW, overlayH, panel, cardEdge, 1)

    Gui, 19:Font, s14 Bold c%text%, Segoe UI
    Gui, 19:Add, Text, % "x" contentX " y" headerY " w" contentW " h26 BackgroundTrans +0x200 +0x4000", Меню биндов
    Gui, 19:Font, Norm s8 c%muted%, Segoe UI
    Gui, 19:Add, Text, % "x" contentX " y" helpY " w" contentW " h16 BackgroundTrans +0x200 +0x4000", Закрыть: напиши !меню и нажми Alt+F
    Gui, 19:Add, Text, % "x" contentX " y" formatY " w" contentW " h16 BackgroundTrans +0x200 +0x4000", Формат: !имя клавиша или !имя !триггер
    Gui, 19:Add, Text, % "x" contentX " y" examplesY " w" contentW " h16 BackgroundTrans +0x200 +0x4000", Примеры: !wanted alt+r · !dep !департамент · !cuff ctrl+f8
    Gui, 19:Add, Progress, % "-Theme " . "x" contentX " y108 w" contentW " h1 Disabled Background" panel " c" cardEdge, 100

    Loop, 2
    {
        colIndex := A_Index - 1
        colX := contentX + colIndex * (colW + gutter)
        nameW := Floor(colW * 0.34)
        cmdW := Floor(colW * 0.22)
        hkW := Floor(colW * 0.20)
        trigW := colW - nameW - cmdW - hkW - 12
        cmdX := colX + nameW + 4
        hkX := cmdX + cmdW + 4
        trigX := hkX + hkW + 4
        Gui, 19:Font, s8 Bold c%accent%, Segoe UI
        Gui, 19:Add, Text, % "x" colX " y" tableHeaderY " w" nameW " h16 +0x200 +0x4000 BackgroundTrans hwndnameHeadHwnd", Функция
        Gui, 19:Add, Text, % "x" cmdX " y" tableHeaderY " w" cmdW " h16 +0x200 +0x4000 BackgroundTrans hwndcmdHeadHwnd", Имя
        Gui, 19:Add, Text, % "x" hkX " y" tableHeaderY " w" hkW " h16 +0x200 +0x4000 BackgroundTrans hwndhkHeadHwnd", HK
        Gui, 19:Add, Text, % "x" trigX " y" tableHeaderY " w" trigW " h16 +0x200 +0x4000 BackgroundTrans hwndtrigHeadHwnd", TXT
        for _, headerHwnd in [nameHeadHwnd, cmdHeadHwnd, hkHeadHwnd, trigHeadHwnd]
            UIStyle_SetTextRole(headerHwnd, "accent")
    }

    totalRows := rows.Length()
    shown := 0
    col := 0
    y1 := listStartY
    y2 := listStartY
    lastCategory1 := ""
    lastCategory2 := ""

    Loop % totalRows
    {
        row := rows[A_Index]
        useCol := col
        y := useCol ? y2 : y1
        lastCategory := useCol ? lastCategory2 : lastCategory1
        needH := rowH + rowGap
        if (row.Category != lastCategory)
            needH += categoryH + gap

        if (y + needH > bottomY && useCol = 0)
        {
            col := 1
            useCol := 1
            y := y2
            lastCategory := lastCategory2
            needH := rowH + rowGap
            if (row.Category != lastCategory)
                needH += categoryH + gap
        }
        if (y + needH > bottomY)
            break

        x := contentX + useCol * (colW + gutter)
        nameW := Floor(colW * 0.34)
        cmdW := Floor(colW * 0.22)
        hkW := Floor(colW * 0.20)
        trigW := colW - nameW - cmdW - hkW - 12
        cmdX := x + nameW + 4
        hkX := cmdX + cmdW + 4
        trigX := hkX + hkW + 4

        if (row.Category != lastCategory)
        {
            Gui, 19:Font, s8 Bold c%accent%, Segoe UI
            Gui, 19:Add, Text, % "x" x " y" y " w" colW " h" categoryH " +0x200 +0x4000 BackgroundTrans hwndcategoryHwnd", % row.Category
            UIStyle_SetTextRole(categoryHwnd, "accent")
            y += categoryH + gap
            if (useCol = 0)
                lastCategory1 := row.Category
            else
                lastCategory2 := row.Category
        }

        hkText := row.Hotkey
        if (hkText = "")
            hkText := "-"
        trigText := row.Trigger
        if (trigText = "")
            trigText := "-"
        cmdText := row.Command
        if (cmdText = "")
            cmdText := "-"

        Gui, 19:Font, Norm s8 c%text%, Segoe UI
        Gui, 19:Add, Text, % "x" x " y" y " w" nameW " h" rowH " +0x200 +0x4000 BackgroundTrans", % row.Label
        Gui, 19:Font, Norm s8 c%muted%, Segoe UI
        Gui, 19:Add, Text, % "x" cmdX " y" y " w" cmdW " h" rowH " +0x200 +0x4000 BackgroundTrans", % cmdText
        Gui, 19:Add, Text, % "x" hkX " y" y " w" hkW " h" rowH " +0x200 +0x4000 BackgroundTrans", % hkText
        Gui, 19:Add, Text, % "x" trigX " y" y " w" trigW " h" rowH " +0x200 +0x4000 BackgroundTrans", % trigText

        y += rowH + rowGap
        if (useCol = 0)
            y1 := y
        else
            y2 := y
        shown += 1
    }

    if (shown < totalRows)
    {
        footerY := overlayH - 32
        Gui, 19:Font, Norm s8 c%muted%, Segoe UI
        Gui, 19:Add, Text, % "x" contentX " y" footerY " w" contentW " h18 Center BackgroundTrans +0x200 +0x4000", % "+ еще " . (totalRows - shown) . " строк. Открой F11 для полного списка."
    }

    Capture_BeforeShow("19")

    Gui, 19:Show, % "x" overlayX " y" overlayY " w" overlayW " h" overlayH " NoActivate", ChatBindMenu
    PromoteOverlayWindow(hBindMenuWnd, 1, 1)
    WinSet, Transparent, %overlayAlpha%, ahk_id %hBindMenuWnd%
    ApplyRoundedCorners(hBindMenuWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hBindMenuWnd, InnerRoundness)
    BindMenuVisible := true
}

OpenBindMenuEditMode() {
    ShowChatBindMenu()
    Notify("info")
    ServiceUI_Notify("Меню биндов открыто. Используй !меню для закрытия.", 1600)
}

CloseBindMenuEditMode(closeGui := 1) {
    ForceCloseBindMenuEditMode("Меню биндов закрыто.")
}

ToggleBindMenuEditMode() {
    global BindMenuVisible
    if (BindMenuVisible)
        ForceCloseBindMenuEditMode("Меню биндов закрыто.")
    else
        OpenBindMenuEditMode()
}

ClampWindowToVirtualDesktop(ByRef x, ByRef y, windowW, windowH, margin := 8) {
    SysGet, virtualX, 76
    SysGet, virtualY, 77
    SysGet, virtualW, 78
    SysGet, virtualH, 79

    if (virtualW <= 0 || virtualH <= 0)
        return false

    minX := virtualX + margin
    minY := virtualY + margin
    maxX := virtualX + virtualW - windowW - margin
    maxY := virtualY + virtualH - windowH - margin
    if (maxX < minX)
        minX := maxX := virtualX
    if (maxY < minY)
        minY := maxY := virtualY

    if (x < minX)
        x := minX
    else if (x > maxX)
        x := maxX
    if (y < minY)
        y := minY
    else if (y > maxY)
        y := maxY
    return true
}

NormalizeWindowStates() {
    global HudX, HudY, HUDVisible, BindListX, BindListY, BindListW, BindListH, BindListVisible
    global SettingsX, SettingsY, SettingsW, SettingsH, SettingsVisible, SettingsTargetTab, SettingsPage

    NormalizeNumberRange(HudX, 10, -4000, 8000)
    NormalizeNumberRange(HudY, 10, -4000, 8000)
    NormalizeNumberRange(BindListX, 300, -4000, 8000)
    NormalizeNumberRange(BindListY, 70, -4000, 8000)
    NormalizeNumberRange(BindListW, 520, 420, 760)
    NormalizeNumberRange(BindListH, 390, 320, 740)
    NormalizeNumberRange(SettingsX, 120, -4000, 8000)
    NormalizeNumberRange(SettingsY, 60, -4000, 8000)
    Settings_NormalizeViewport()
    ClampWindowToVirtualDesktop(SettingsX, SettingsY, SettingsW, SettingsH)
    ClampWindowToVirtualDesktop(BindListX, BindListY, BindListW, BindListH)
    ClampWindowToVirtualDesktop(HudX, HudY, 380, 180)
    NormalizeSettingsPage(SettingsPage)
    SettingsTargetTab := SettingsPageIndex(SettingsPage)

    HUDVisible := HUDVisible ? 1 : 0
    BindListVisible := BindListVisible ? 1 : 0
    SettingsVisible := SettingsVisible ? 1 : 0
}

NormalizeVisibleStateValue(ByRef visible) {
    visible := visible ? 1 : 0
}

SetPendingGuiStateValues(targetHUD, targetBindList, targetSettings) {
    global PendingHUDVisible, PendingBindListVisible, PendingSettingsVisible
    PendingHUDVisible := targetHUD ? 1 : 0
    PendingBindListVisible := targetBindList ? 1 : 0
    PendingSettingsVisible := targetSettings ? 1 : 0
}

ApplyPendingGuiState(settingsTab := 1) {
    global HUDVisible, BindListVisible, SettingsVisible
    global PendingHUDVisible, PendingBindListVisible, PendingSettingsVisible

    if (PendingHUDVisible != -1 && HUDVisible != PendingHUDVisible)
        SetHUDWindowState(PendingHUDVisible)
    if (PendingBindListVisible != -1 && BindListVisible != PendingBindListVisible)
        SetBindListWindowState(PendingBindListVisible)
    if (PendingSettingsVisible != -1 && SettingsVisible != PendingSettingsVisible)
        SetSettingsWindowState(PendingSettingsVisible, settingsTab)
}

ClearPendingGuiStateValues() {
    global PendingHUDVisible, PendingBindListVisible, PendingSettingsVisible
    PendingHUDVisible := -1
    PendingBindListVisible := -1
    PendingSettingsVisible := -1
}

SetHUDWindowState(visible, persist := 1) {
    global HUDVisible
    NormalizeVisibleStateValue(visible)
    if (visible)
    {
        CreateHUD()
        UpdateHUD()
        HUDVisible := 1
    }
    else
    {
        Gui, 12:Hide
        HUDVisible := 0
    }
    if (persist)
        SaveHUDWindowState()
}

SetBindListWindowState(visible, persist := 1) {
    global BindListVisible
    NormalizeVisibleStateValue(visible)
    if (visible)
    {
        CreateBindList()
        UpdateBindList()
        BindListVisible := 1
    }
    else
    {
        Gui, 13:Hide
        BindListVisible := 0
    }
    if (persist)
        SaveBindListWindowState()
}

RequestIndependentGuiState(targetHUD, targetBindList, targetSettings, settingsTab := 1) {
    SetPendingGuiStateValues(targetHUD, targetBindList, targetSettings)
    ApplyPendingGuiState(settingsTab)
    SetTimer, EnforceIndependentGuiState, -80
}

ResolveBackgroundImage() {
    global BackgroundImageURL, BackgroundImageFile
    path := Trim(BackgroundImageURL, " " . Chr(34))
    if (RegExMatch(path, "i)^https?://"))
        return false
    if (path = "" || path = "ERROR") {
        BackgroundImageFile := ""
        return true
    }
    if (!FileExist(path))
        path := AppHost_DataDir() . "\" . path
    if (!FileExist(path) || !RegExMatch(path, "i)\.(png|jpe?g|bmp)$"))
        return false
    FileGetSize, bytes, %path%
    if (bytes > 5242880 || !ImageDimensionsBounded(path, w, h) || w > 4096 || h > 4096)
        return false
    BackgroundImageFile := path
    return true
}

SafePicture(guiId, x, y, w, h, varName, imageFile := "") {
    opts := "x" . x . " y" . y . " w" . w . " h" . h . " v" . varName . " BackgroundTrans"
    if (imageFile != "" && FileExist(imageFile))
    {
        Gui, %guiId%:Add, Picture, %opts%, %imageFile%
        return
    }
    Gui, %guiId%:Add, Text, %opts%,
}

CreateHUD() {
    global hHUDWnd, HudX, HudY, BackgroundImageFile, HUDTransparency, UIRoundness, HUDMode, InnerRoundness
    global ThemeMode, TabGuiHeaderText
    global HUDTimeText, HUDProfileText, HUDIDText, HUDMenuText, HUDBindListText
    global HUDBG, HUDBorderTop, HUDBorderBottom, HUDBorderLeft, HUDBorderRight, HUDDragZone

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    GetControlSurfaceColors(controlBg, inputFg, cardBg, cardEdge, panel, text, accent)
    hudAlpha := HUDTransparency
    NormalizeNumberRange(hudAlpha, 245, 180, 255)

    if (HUDMode = "Компактный")
        hudW := 280, hudH := 138
    else if (HUDMode = "Профиль + ID")
        hudW := 280, hudH := 112
    else
        hudW := 304, hudH := 186

    hudRight := hudW - 1
    hudBottom := hudH - 1
    valueX := 88
    valueW := hudW - valueX - 12
    labelW := 64
    lineW := hudW - 40

    Gui, 12:Destroy
    Gui, 12:+HwndhHUDWnd +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x08000000
    Gui, 12:Color, %panel%
    Gui, 12:Margin, 0, 0
    SafePicture(12, 0, 0, hudW, hudH, "HUDBG", BackgroundImageFile)
    Gui, 12:Add, Progress, -Theme x0 y0 w%hudW% h1 Disabled Background%panel% c%cardEdge% vHUDBorderTop, 100
    Gui, 12:Add, Progress, -Theme x0 y%hudBottom% w%hudW% h1 Disabled Background%panel% c%cardEdge% vHUDBorderBottom, 100
    Gui, 12:Add, Progress, -Theme x0 y0 w1 h%hudH% Disabled Vertical Background%panel% c%cardEdge% vHUDBorderLeft, 100
    Gui, 12:Add, Progress, -Theme x%hudRight% y0 w1 h%hudH% Disabled Vertical Background%panel% c%cardEdge% vHUDBorderRight, 100
    Gui, 12:Add, Text, x0 y0 w%hudW% h34 vHUDDragZone gStartHUDDrag BackgroundTrans,

    Gui, 12:Font, s10 Bold c%text%, Segoe UI
    Gui, 12:Add, Text, x18 y10 gStartHUDDrag w%lineW% h22 +0x4000 BackgroundTrans, %TabGuiHeaderText%
    Gui, 12:Font, Norm s8 c%muted%, Segoe UI
    Gui, 12:Add, Text, x18 y36 w%lineW% h16 BackgroundTrans, Статус персонажа

    rowY := 60
    Gui, 12:Font, Norm s8 c%muted%, Segoe UI
    if (HUDMode != "Профиль + ID")
    {
        Gui, 12:Add, Text, x18 y%rowY% w%labelW% h18 BackgroundTrans, Время
        rowY += 24
    }
    Gui, 12:Add, Text, x18 y%rowY% w%labelW% h18 BackgroundTrans, Профиль
    rowY += 24
    Gui, 12:Add, Text, x18 y%rowY% w%labelW% h18 BackgroundTrans, Цель
    if (HUDMode = "Полный")
    {
        rowY += 24
        Gui, 12:Add, Text, x18 y%rowY% w%labelW% h18 BackgroundTrans, Меню
        rowY += 24
        Gui, 12:Add, Text, x18 y%rowY% w%labelW% h18 BackgroundTrans, Бинды
    }

    rowY := 60
    Gui, 12:Font, s9 Bold c%text%, Segoe UI
    if (HUDMode != "Профиль + ID")
    {
        Gui, 12:Add, Text, x%valueX% y%rowY% vHUDTimeText w%valueW% h20 Right +0x4000 BackgroundTrans, --
        rowY += 24
    }
    Gui, 12:Add, Text, x%valueX% y%rowY% vHUDProfileText w%valueW% h20 Right +0x4000 BackgroundTrans, --
    rowY += 24
    Gui, 12:Add, Text, x%valueX% y%rowY% vHUDIDText w%valueW% h20 Right +0x4000 BackgroundTrans, --
    if (HUDMode = "Полный")
    {
        rowY += 24
        Gui, 12:Add, Text, x%valueX% y%rowY% vHUDMenuText w%valueW% h20 Right +0x4000 BackgroundTrans, --
        rowY += 24
        Gui, 12:Add, Text, x%valueX% y%rowY% vHUDBindListText w%valueW% h20 Right +0x4000 BackgroundTrans, --
    }

    Capture_BeforeShow("12")

    Gui, 12:Show, x%HudX% y%HudY% NoActivate w%hudW% h%hudH%, AMZHUD
    PromoteOverlayWindow(hHUDWnd, 1, 1)
    WinSet, Transparent, %hudAlpha%, ahk_id %hHUDWnd%
    ApplyRoundedCorners(hHUDWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hHUDWnd, InnerRoundness)
    ApplyPersistentAlwaysOnTop()
}

UpdateHUD() {
    global hHUDWnd
    if (!hHUDWnd || !DllCall("IsWindow", "Ptr", hHUDWnd, "Int")) {
        UpdateAutomationSettingsStatus()
        return
    }
    global CurrentProfile, UserID, ActiveID, Bind_OpenSettings, Bind_ToggleBindList, HUDMode
    global TargetNickname, TargetIsMask
    FormatTime, timeNow,, HH:mm:ss

    if (!ActiveID || UserID = "")
        currentTarget := "не задана"
    else if (TargetIsMask)
        currentTarget := "Маска " . UserID
    else
        currentTarget := "ID " . UserID . ((TargetNickname != "") ? " · " . TargetNickname : "")

    if (StrLen(currentTarget) > 27)
        currentTarget := SubStr(currentTarget, 1, 26) . "..."

    if (HUDMode != "Профиль + ID")
        UIStyle_SetTextIfChanged("12", "HUDTimeText", timeNow)
    UIStyle_SetTextIfChanged("12", "HUDProfileText", CurrentProfile)
    UIStyle_SetTextIfChanged("12", "HUDIDText", currentTarget)

    if (HUDMode = "Полный")
    {
        UIStyle_SetTextIfChanged("12", "HUDMenuText", Bind_OpenSettings)
        UIStyle_SetTextIfChanged("12", "HUDBindListText", Bind_ToggleBindList)
    }
    UpdateAutomationSettingsStatus()
}

BuildBindListRow(meta) {
    hotkeyValue := ShowHotkeyValue(GetDynamicGlobalValue(meta.HotkeyVar))
    triggerValue := ShowTriggerValue(GetDynamicGlobalValue(meta.TriggerVar))

    hasHotkey := IsBindFieldFilled(hotkeyValue)
    hasTrigger := IsBindFieldFilled(triggerValue)

    status := "[--] Пусто"
    bindValue := "—"
    if (hasHotkey && hasTrigger)
    {
        status := "[MIX] Hotkey + !"
        bindValue := hotkeyValue . " | ! " . triggerValue
    }
    else if (hasHotkey)
    {
        status := "[HK] Hotkey"
        bindValue := hotkeyValue
    }
    else if (hasTrigger)
    {
        status := "[TXT] ! Триггер"
        bindValue := "! " . triggerValue
    }

    return {Token: meta.Token, Label: meta.Label, Category: meta.Category, Hotkey: hotkeyValue, Trigger: triggerValue, BindValue: bindValue, Status: status}
}

BuildBindListRows() {
    global BindListItems
    NormalizeBindListItemsValue(BindListItems)

    rows := []
    seen := {}
    tokenMap := GetBindCatalogMap()

    Loop, Parse, BindListItems, `n, `r
    {
        token := NormalizeBindListToken(A_LoopField)
        if (token = "" or seen.HasKey(token))
            continue

        seen[token] := 1
        if (tokenMap.HasKey(token))
        {
            meta := tokenMap[token]
            if !BindCatalog_IsUserVisible(meta)
                continue
            row := BuildBindListRow(meta)
            if (row.Status != "[--] Пусто")
                rows.Push(row)
        }
        else
        {
            rows.Push({Token: token, Label: token, Category: "Пользовательское", Hotkey: "—", Trigger: "—", BindValue: "—", Status: "Неизвестный токен"})
        }
    }

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (seen.HasKey(meta.Token))
            continue

        row := BuildBindListRow(meta)
        if (row.Status != "[--] Пусто")
            rows.Push(row)
    }
    AppendCustomFunctionBindRows(rows)
    return rows
}

BuildBindListSummary(rows) {
    total := rows.Length()
    hotkeys := 0
    triggers := 0
    both := 0
    unknown := 0

    Loop % total
    {
        row := rows[A_Index]
        hasHotkey := IsBindFieldFilled(row.Hotkey)
        hasTrigger := IsBindFieldFilled(row.Trigger)

        if (hasHotkey)
            hotkeys += 1
        if (hasTrigger)
            triggers += 1
        if (hasHotkey && hasTrigger)
            both += 1
        if (row.Status = "Неизвестный токен")
            unknown += 1
    }

    summaryText := "Строк: " . total . " | Hotkey: " . hotkeys . " | ! триггер: " . triggers . " | Оба: " . both
    if (unknown > 0)
        summaryText .= " | Неизвестных токенов: " . unknown
    return summaryText
}

UpdateBindListColumnLayout(listWidth := "") {
    global BindListW
    Gui, 13:Default
    if (listWidth = "")
        listWidth := BindListW - 20
    commandW := Floor(listWidth * 0.50)
    hotkeyW := Floor(listWidth * 0.22)
    triggerW := listWidth - commandW - hotkeyW - 18
    if (commandW < 120)
        commandW := 120
    if (hotkeyW < 72)
        hotkeyW := 72
    if (triggerW < 70)
        triggerW := 70
    LV_ModifyCol(1, commandW)
    LV_ModifyCol(2, hotkeyW)
    LV_ModifyCol(3, triggerW)
    LV_ModifyCol(4, 0)
}

BindList_GetLayout(width, height) {
    contentW := width - 32
    searchW := Max(150, contentW - 220)
    return {ContentW: contentW, TitleW: width - 160, CountX: width - 122, CloseX: width - 48
        , SearchW: searchW, CategoryX: 28 + searchW, CategoryW: contentW - searchW - 12
        , ListY: 110, ListH: Max(136, height - 152), FooterY: height - 28
        , FooterW: width - 64, GripX: width - 38}
}

ResizeBindListGui(width, height) {
    global BindListW, BindListH, hBindListWnd, UIRoundness, InnerRoundness
    if (!hBindListWnd || !DllCall("IsWindow", "Ptr", hBindListWnd, "Int"))
        return
    BindListW := width, BindListH := height
    layout := BindList_GetLayout(width, height)
    GuiControl, 13:Move, BindListDragZone, % "x0 y0 w" . width . " h58"
    GuiControl, 13:Move, BindListTitleText, % "x16 y14 w" . layout.TitleW . " h22"
    GuiControl, 13:Move, BindListProfileText, % "x16 y40 w" . (width - 88) . " h18"
    GuiControl, 13:Move, BindListCountText, % "x" . layout.CountX . " y18 w60 h18"
    GuiControl, 13:Move, BindListCloseText, % "x" . layout.CloseX . " y12 w32 h30"
    GuiControl, 13:Move, BindListSearchEdit, % "x16 y68 w" . layout.SearchW . " h30"
    GuiControl, 13:Move, BindListCategoryDDL, % "x" . layout.CategoryX . " y68 w" . layout.CategoryW . " h30"
    GuiControl, 13:Move, BindListLV, % "x16 y" . layout.ListY . " w" . layout.ContentW . " h" . layout.ListH
    GuiControl, 13:Move, BindListInfoText, % "x16 y" . layout.FooterY . " w" . layout.FooterW . " h18"
    GuiControl, 13:Move, BindListResizeGripText, % "x" . layout.GripX . " y" . layout.FooterY . " w22 h18"
    GuiControl, 13:Move, BindListBG, % "x0 y0 w" . width . " h" . height
    GuiControl, 13:Move, BindListBorderTop, % "x0 y0 w" . width . " h1"
    GuiControl, 13:Move, BindListBorderBottom, % "x0 y" . (height - 1) . " w" . width . " h1"
    GuiControl, 13:Move, BindListBorderLeft, % "x0 y0 w1 h" . height
    GuiControl, 13:Move, BindListBorderRight, % "x" . (width - 1) . " y0 w1 h" . height
    UpdateBindListColumnLayout(layout.ContentW)
    ApplyRoundedCorners(hBindListWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hBindListWnd, InnerRoundness)
}

CreateBindList() {
    global hBindListWnd, hBindListLV, BindListX, BindListY, BindListW, BindListH, UIRoundness, InnerRoundness, BackgroundImageFile
    global BindListBG, BindListBorderTop, BindListBorderBottom, BindListBorderLeft, BindListBorderRight, BindListDragZone
    global CurrentProfile, CustomBindListColor, CustomTextColor, TabGuiHeaderText, BindListTransparency
    global BindListLV, BindListInfoText, BindListTitleText, BindListProfileText, BindListResizeGripText, BindListRefreshText, BindListCloseText
    global BindListSearch, BindListCategory, BindListSearchEdit, BindListCategoryDDL, hBindListCategoryDDL, BindListCountText

    NormalizeNumberRange(BindListW, 520, 420, 760)
    NormalizeNumberRange(BindListH, 390, 320, 740)

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    if (CustomBindListColor != "")
    {
        panel := CustomBindListColor
        if (CustomTextColor = "")
        {
            if (ColorBrightness(panel) >= 140)
                text := "1D232B", muted := "66727F"
            else
                text := "ECECFA", muted := "9DA5BD"
        }
    }
    GetControlSurfaceColors(controlBg, bindInputText, cardBg, cardEdge, panel, text, accent)
    layout := BindList_GetLayout(BindListW, BindListH)
    listW := layout.ContentW, listH := layout.ListH, infoY := layout.FooterY, infoW := layout.FooterW
    searchW := layout.SearchW, catX := layout.CategoryX, catW := layout.CategoryW
    titleW := layout.TitleW, countX := layout.CountX, closeX := layout.CloseX, gripX := layout.GripX
    bindRight := BindListW - 1, bindBottom := BindListH - 1

    Gui, 13:Destroy
    Gui, 13:+HwndhBindListWnd +AlwaysOnTop -Caption +ToolWindow +LastFound +Resize +MinSize420x320 +MaxSize760x740
    Gui, 13:Color, %panel%, %controlBg%
    Gui, 13:Margin, 0, 0
    SafePicture(13, 0, 0, BindListW, BindListH, "BindListBG", BackgroundImageFile)
    Gui, 13:Add, Progress, -Theme x0 y0 w%BindListW% h1 Disabled Background%panel% c%cardEdge% vBindListBorderTop, 100
    Gui, 13:Add, Progress, -Theme x0 y%bindBottom% w%BindListW% h1 Disabled Background%panel% c%cardEdge% vBindListBorderBottom, 100
    Gui, 13:Add, Progress, -Theme x0 y0 w1 h%BindListH% Disabled Vertical Background%panel% c%cardEdge% vBindListBorderLeft, 100
    Gui, 13:Add, Progress, -Theme x%bindRight% y0 w1 h%BindListH% Disabled Vertical Background%panel% c%cardEdge% vBindListBorderRight, 100
    Gui, 13:Add, Text, x0 y0 w%BindListW% h58 vBindListDragZone gStartBindListDrag BackgroundTrans,

    Gui, 13:Font, s11 Bold c%text%, Segoe UI
    Gui, 13:Add, Text, x16 y14 w%titleW% h22 vBindListTitleText gStartBindListDrag +0x4000 BackgroundTrans, Бинды
    Gui, 13:Font, Norm s9 c%muted%, Segoe UI
    profileW := BindListW - 88
    Gui, 13:Add, Text, x16 y40 w%profileW% h18 vBindListProfileText gStartBindListDrag +0x4000 BackgroundTrans, %CurrentProfile%
    Gui, 13:Font, s8 Bold c%accent%, Segoe UI
    Gui, 13:Add, Text, x%countX% y18 w60 h18 Right vBindListCountText hwndcountHwnd BackgroundTrans, 0 шт.
    Gui, 13:Font, s9 Norm c%text%, Segoe UI
    Gui, 13:Add, Button, x%closeX% y12 w32 h30 vBindListCloseText g13GuiClose, X
    Gui, 13:Add, Text, x0 y0 w0 h0 vBindListRefreshText Hidden,

    Gui, 13:Font, Norm s9 c%bindInputText%, Segoe UI
    Gui, 13:Add, Edit, x16 y68 w%searchW% h30 -Multi -WantReturn -VScroll -HScroll vBindListSearchEdit hwndsearchHwnd gBindListFilterChanged, %BindListSearch%
    DllCall("SendMessageW", "Ptr", searchHwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "Поиск по биндам")
    Gui, 13:Add, DropDownList, x%catX% y68 w%catW% r10 vBindListCategoryDDL hwndhBindListCategoryDDL gBindListFilterChanged, Все|Системные|Задержание и RP|Доклады|Транспорт / прочее|Документы|Пользовательское
    GuiControl, 13:ChooseString, BindListCategoryDDL, %BindListCategory%
    Gui, 13:Font, Norm s9 c%bindInputText%, Segoe UI
    Gui, 13:Add, ListView, x16 y110 w%listW% h%listH% vBindListLV hwndhBindListLV gBindListViewEvent AltSubmit -Multi Background%controlBg%, Команда|Клавиша|TXT|Token
    Gui, 13:Font, Norm s8 c%muted%, Segoe UI
    Gui, 13:Add, Text, x16 y%infoY% w%infoW% h18 vBindListInfoText +0x4000 BackgroundTrans, Бинды загружены.
    Gui, 13:Font, s9 Norm c%muted%, Segoe UI
    Gui, 13:Add, Text, x%gripX% y%infoY% w22 h18 Right vBindListResizeGripText BackgroundTrans, //

    UIStyle_SetTextRole(countHwnd, "accent")
    Capture_BeforeShow("13")
    Gui, 13:Show, % "x" BindListX " y" BindListY " w" BindListW " h" BindListH . (GameUi_ShouldShowPassive() ? " NoActivate" : ""), BindList
    PromoteOverlayWindow(hBindListWnd, 1, 0)
    bindListAlpha := BindListTransparency
    NormalizeNumberRange(bindListAlpha, 225, 150, 255)
    WinSet, Transparent, %bindListAlpha%, ahk_id %hBindListWnd%
    ResizeBindListGui(BindListW, BindListH)
    ApplyListViewColors(hBindListLV, controlBg, bindInputText)
    ApplyPersistentAlwaysOnTop()
}

GetBindListHintText(summaryText := "") {
    if (summaryText = "")
        return "Перетащи строку для изменения порядка."
    return summaryText
}

RenderBindListRows(rows, selectRow := 0) {
    Gui, 13:Default
    LV_Delete()

    if (rows.Length() = 0)
    {
        LV_Add("", "Бинды не заданы", "—", "—", "")
        GuiControl, 13:, BindListInfoText, % GetBindListHintText("Нет заданных hotkey и текстовых триггеров.")
    }
    else
    {
        Loop % rows.Length()
        {
            row := rows[A_Index]
            displayLabel := (row.HasKey("Conflict") && row.Conflict) ? "[!] " . row.Label : row.Label
            LV_Add("", displayLabel, row.Hotkey, row.Trigger, row.Token)
        }
        if (selectRow > 0 && selectRow <= rows.Length())
            LV_Modify(selectRow, "Select Focus Vis")
        GuiControl, 13:, BindListInfoText, % GetBindListHintText(BuildBindListSummary(rows))
    }
    GuiControl, 13:, BindListCountText, % rows.Length() . " шт."

    UpdateBindListColumnLayout()
}

GetBindListRowsFromListView() {
    rows := []
    Gui, 13:Default
    rowCount := LV_GetCount()
    Loop % rowCount
    {
        idx := A_Index
        LV_GetText(actionText, idx, 1)
        LV_GetText(hotkeyText, idx, 2)
        LV_GetText(triggerText, idx, 3)
        LV_GetText(tokenText, idx, 4)
        bindText := ""
        if (hotkeyText != "" && hotkeyText != "—")
            bindText := hotkeyText
        if (triggerText != "" && triggerText != "—")
        {
            if (bindText != "")
                bindText .= " | "
            bindText .= "! " . triggerText
        }
        if (bindText = "")
            bindText := "—"
        rows.Push({Label: actionText, Category: "", Hotkey: hotkeyText, Trigger: triggerText, BindValue: bindText, Token: tokenText})
    }
    return rows
}

PersistBindListOrderFromRows(rows) {
    global BindListItems, CFG_BindListItems, ConfigFile, CurrentProfile, SettingsVisible

    newOrder := ""
    Loop % rows.Length()
    {
        token := NormalizeBindListToken(rows[A_Index].Token)
        if (token = "")
            continue
        if (newOrder != "")
            newOrder .= "`n"
        newOrder .= token
    }

    if (newOrder = "")
        newOrder := GetDefaultBindListItems()

    BindListItems := newOrder
    NormalizeBindListItemsValue(BindListItems)
    CFG_BindListItems := BindListItems

    if (SettingsVisible)
        GuiControl, 2:, CFG_BindListItems, %BindListItems%

    IniWriteText(BindListItems, ConfigFile, "Profile_" . CurrentProfile, "BindListItems")
}

MoveBindListRow(fromRow, toRow) {
    if (fromRow <= 0 || toRow <= 0 || fromRow = toRow)
        return

    rows := GetBindListRowsFromListView()
    if (fromRow > rows.Length() || toRow > rows.Length())
        return

    moving := rows.RemoveAt(fromRow)
    rows.InsertAt(toRow, moving)
    PersistBindListOrderFromRows(rows)
    RenderBindListRows(rows, toRow)
}

GetBindListRowFromScreenPos(screenX, screenY) {
    global hBindListLV
    if (!hBindListLV)
        return 0

    VarSetCapacity(pt, 8, 0)
    NumPut(screenX, pt, 0, "Int")
    NumPut(screenY, pt, 4, "Int")
    DllCall("ScreenToClient", "Ptr", hBindListLV, "Ptr", &pt)

    VarSetCapacity(ht, 20, 0)
    NumPut(NumGet(pt, 0, "Int"), ht, 0, "Int")
    NumPut(NumGet(pt, 4, "Int"), ht, 4, "Int")
    SendMessage, 0x1039, 0, % &ht,, ahk_id %hBindListLV%
    hitRow := ErrorLevel
    if (hitRow < 0)
        return 0
    return hitRow + 1
}

BindList_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global BindListVisible, hBindListWnd, hBindListLV
    global BindListDragFromRow, BindListDragHoverRow, BindListDragActive
    global BindListSearch, BindListCategory

    if (!BindListVisible || !hBindListWnd || !WinActive("ahk_id " . hBindListWnd))
        return
    if (Trim(BindListSearch) != "" || (BindListCategory != "" && BindListCategory != "Все"))
        return

    MouseGetPos, mouseX, mouseY, winId, ctrlHwnd, 2
    if (ctrlHwnd != hBindListLV)
        return

    dragRow := GetBindListRowFromScreenPos(mouseX, mouseY)
    if (dragRow <= 0)
        return

    BindListDragFromRow := dragRow
    BindListDragHoverRow := dragRow
    BindListDragActive := 0
}

BindList_OnMouseMove(wParam, lParam, msg, hwnd) {
    global BindListVisible, hBindListWnd, hBindListLV
    global BindListDragFromRow, BindListDragHoverRow, BindListDragActive

    if (!BindListVisible || BindListDragFromRow <= 0)
        return
    if !GetKeyState("LButton", "P")
        return
    if (!hBindListWnd || !WinActive("ahk_id " . hBindListWnd))
        return

    MouseGetPos, mouseX, mouseY, winId, ctrlHwnd, 2
    if (ctrlHwnd != hBindListLV)
        return

    hoverRow := GetBindListRowFromScreenPos(mouseX, mouseY)
    if (hoverRow <= 0)
        return

    BindListDragActive := 1
    if (hoverRow != BindListDragHoverRow)
    {
        BindListDragHoverRow := hoverRow
        Gui, 13:Default
        LV_Modify(hoverRow, "Focus Vis")
        ServiceUI_Notify("Перемещение: " . BindListDragFromRow . " -> " . hoverRow, 4000)
    }
}

BindList_OnLButtonUp(wParam, lParam, msg, hwnd) {
    global BindListDragFromRow, BindListDragHoverRow, BindListDragActive
    global BindListVisible, hBindListWnd, hBindListLV

    if (BindListDragFromRow <= 0)
        return

    fromRow := BindListDragFromRow
    toRow := 0

    if (BindListVisible && hBindListWnd && WinActive("ahk_id " . hBindListWnd))
    {
        MouseGetPos, mouseX, mouseY, winId, ctrlHwnd, 2
        if (ctrlHwnd = hBindListLV)
            toRow := GetBindListRowFromScreenPos(mouseX, mouseY)
    }

    if (BindListDragActive && toRow > 0 && toRow != fromRow)
        MoveBindListRow(fromRow, toRow)

    BindListDragFromRow := 0
    BindListDragHoverRow := 0
    BindListDragActive := 0
    ServiceUI_ClearNotice()
}

BindList_OnCommand(wParam, lParam, msg, hwnd) {
    global BindListVisible, hBindListCategoryDDL
    if (!BindListVisible || !hBindListCategoryDDL || lParam != hBindListCategoryDDL)
        return

    notifyCode := (wParam >> 16) & 0xFFFF
    if (notifyCode != 7)
        return

    VarSetCapacity(cbi, 52, 0)
    NumPut(52, cbi, 0, "UInt")
    if !DllCall("GetComboBoxInfo", "Ptr", hBindListCategoryDDL, "Ptr", &cbi)
        return
    hwndList := NumGet(cbi, 48, "Ptr")
    if (hwndList)
        DllCall("SetWindowPos", "Ptr", hwndList, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0053)
}

UpdateBindList() {
    global BindListSearch, BindListCategory, BindListSearchEdit, BindListCategoryDDL, hBindListWnd
    if (!hBindListWnd || !DllCall("IsWindow", "Ptr", hBindListWnd))
        return
    if WinExist("ahk_id " . hBindListWnd)
    {
        GuiControlGet, BindListSearch, 13:, BindListSearchEdit
        GuiControlGet, BindListCategory, 13:, BindListCategoryDDL
    }
    BindListSearch := Trim(BindListSearch)
    if (BindListCategory = "" || BindListCategory = "ERROR")
        BindListCategory := "Все"
    rows := BuildBindListRows()
    rows := MarkBindListConflicts(rows)
    filtered := []
    searchNeedle := BindListSearch
    StringLower, searchNeedle, searchNeedle
    Loop % rows.Length()
    {
        row := rows[A_Index]
        if (BindListCategory != "Все" && row.Category != BindListCategory)
            continue
        hay := row.Label . " " . row.Token . " " . row.Hotkey . " " . row.Trigger
        StringLower, hay, hay
        if (searchNeedle != "" && !InStr(hay, searchNeedle))
            continue
        filtered.Push(row)
    }
    RenderBindListRows(filtered)
}

MarkBindListConflicts(rows) {
    hotkeys := {}, triggers := {}
    Loop % rows.Length()
    {
        idx := A_Index
        row := rows[idx]
        hk := IsBindFieldFilled(row.Hotkey) ? Diagnostics_NormalizeHotkeyForCompare(row.Hotkey) : ""
        tr := IsBindFieldFilled(row.Trigger) ? Diagnostics_NormalizeTriggerForCompare(row.Trigger) : ""
        if (hk != "")
        {
            if hotkeys.HasKey(hk)
                rows[idx].Conflict := 1, rows[hotkeys[hk]].Conflict := 1
            else
                hotkeys[hk] := idx
        }
        if (tr != "")
        {
            if triggers.HasKey(tr)
                rows[idx].Conflict := 1, rows[triggers[tr]].Conflict := 1
            else
                triggers[tr] := idx
        }
    }
    return rows
}

ToggleBindOverlay() {
    global BindOverlayVisible
    if (BindOverlayVisible)
        HideBindOverlay()
    else
        ShowBindOverlay()
}

HideBindOverlay() {
    global BindOverlayVisible, hBindOverlayWnd
    Gui, 18:Destroy
    BindOverlayVisible := 0
    hBindOverlayWnd := 0
}

BuildBindOverlayRows() {
    rows := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        row := BuildBindListRow(meta)
        if (row.Status != "[--] Пусто")
            rows.Push(row)
    }
    AppendCustomFunctionBindRows(rows)
    return rows
}

ShowBindOverlay() {
    global BindOverlayVisible, hBindOverlayWnd, BindOverlayW, BindOverlayH
    global BindListTransparency, CustomBindListColor, CustomTextColor, UIRoundness, InnerRoundness

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    if (CustomBindListColor != "")
    {
        panel := CustomBindListColor
        if (CustomTextColor = "")
        {
            if (ColorBrightness(panel) >= 140)
                text := "1D232B", muted := "66727F"
            else
                text := "F4F6F8", muted := "A9B1BA"
        }
    }

    controlBg := ""
    inputText := ""
    cardBg := ""
    cardEdge := ""
    GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, text, accent)

    overlayW := Floor(A_ScreenWidth * 0.26)
    NormalizeNumberRange(overlayW, 400, 340, 500)
    if (overlayW > A_ScreenWidth - 40)
        overlayW := A_ScreenWidth - 40
    overlayH := Floor(A_ScreenHeight * 0.58)
    NormalizeNumberRange(overlayH, 500, 320, 650)
    if (overlayH > A_ScreenHeight - 60)
        overlayH := A_ScreenHeight - 60
    if (overlayW < 320)
        overlayW := 320
    if (overlayH < 300)
        overlayH := 300

    overlayX := A_ScreenWidth - overlayW - 24
    if (overlayX < 10)
        overlayX := 10
    overlayY := Floor((A_ScreenHeight - overlayH) / 2)
    if (overlayY < 10)
        overlayY := 10

    BindOverlayW := overlayW
    BindOverlayH := overlayH
    overlayAlpha := BindListTransparency
    NormalizeNumberRange(overlayAlpha, 220, 150, 255)

    contentX := 16
    contentW := overlayW - 32
    nameX := contentX
    hkX := contentX + Floor(contentW * 0.54)
    trigX := contentX + Floor(contentW * 0.76)
    nameW := hkX - nameX - 8
    hkW := trigX - hkX - 8
    trigW := overlayW - trigX - 16
    rowH := 16
    rowY := 68
    maxY := overlayH - 34

    rows := BuildBindOverlayRows()

    Gui, 18:Destroy
    Gui, 18:+HwndhBindOverlayWnd +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 +E0x08000000
    Gui, 18:Color, %panel%
    Gui, 18:Margin, 0, 0

    AddOutlinedPanel(18, 0, 0, overlayW, overlayH, panel, cardEdge, 1)

    Gui, 18:Font, s10 Bold c%text%, Segoe UI
    Gui, 18:Add, Text, % "x" contentX " y16 w" contentW " h20 BackgroundTrans", Бинды
    Gui, 18:Font, Norm s7 c%muted%, Segoe UI
    Gui, 18:Add, Text, % "x" contentX " y38 w" contentW " h16 BackgroundTrans", Alt+X — скрыть · F11 — полный список
    Gui, 18:Add, Progress, % "-Theme " . "x" contentX " y58 w" contentW " h1 Disabled Background" panel " c" cardEdge, 100

    if (!IsObject(rows) || rows.Length() = 0)
    {
        Gui, 18:Font, Norm s9 c%muted%, Segoe UI
        Gui, 18:Add, Text, % "x" contentX " y" rowY " w" contentW " h24 Center BackgroundTrans", Назначенных биндов нет.
    }
    else
    {
        skippedRows := 0
        lastCategory := ""
        Loop % rows.Length()
        {
            row := rows[A_Index]
            if (row.Category != lastCategory)
            {
                if (rowY + 20 > maxY)
                {
                    skippedRows := rows.Length() - A_Index + 1
                    break
                }
                Gui, 18:Font, s8 Bold c%accent%, Segoe UI
                Gui, 18:Add, Text, % "x" contentX " y" rowY " w" contentW " h18 +0x200 BackgroundTrans hwndcategoryHwnd", % row.Category
                UIStyle_SetTextRole(categoryHwnd, "accent")
                rowY += 18
                lastCategory := row.Category
            }

            if (rowY + rowH > maxY)
            {
                skippedRows := rows.Length() - A_Index + 1
                break
            }

            actionText := row.Label
            hotkeyText := "HK: " . row.Hotkey
            triggerText := "!: " . row.Trigger

            Gui, 18:Font, Norm s7 c%text%, Segoe UI
            Gui, 18:Add, Text, % "x" nameX " y" rowY " w" nameW " h" rowH " +0x200 BackgroundTrans", % actionText
            Gui, 18:Font, Norm s7 c%muted%, Segoe UI
            Gui, 18:Add, Text, % "x" hkX " y" rowY " w" hkW " h" rowH " +0x200 BackgroundTrans", % hotkeyText
            Gui, 18:Add, Text, % "x" trigX " y" rowY " w" trigW " h" rowH " +0x200 BackgroundTrans", % triggerText
            rowY += rowH
        }

        if (skippedRows > 0)
        {
            footerY := overlayH - 26
            Gui, 18:Font, Norm s7 c%muted%, Segoe UI
            Gui, 18:Add, Text, % "x" contentX " y" footerY " w" contentW " h18 Center BackgroundTrans", % "+ еще " . skippedRows . " строк. Открой F11 для полного списка."
        }
    }

    Capture_BeforeShow("18")

    Gui, 18:Show, % "x" overlayX " y" overlayY " w" overlayW " h" overlayH " NoActivate", BindOverlay
    PromoteOverlayWindow(hBindOverlayWnd, 1, 1)
    WinSet, Transparent, %overlayAlpha%, ahk_id %hBindOverlayWnd%
    ApplyRoundedCorners(hBindOverlayWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hBindOverlayWnd, InnerRoundness)
    BindOverlayVisible := 1
}

ShowStopTimerGUI() {
    global hStopTimerWnd, StopTimerActive, StopTimerCounter, StopTimerWidth, StopTimerHeight
    global StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor
    global StopTimerX, StopTimerY, UIRoundness

    if (!StopTimerActive)
        return

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)

    GetControlSurfaceColors(surface, inputFg, card, edge, panel, text, accent)
    borderColor := (StopTimerBorderColor != "" ? StopTimerBorderColor : edge)
    timerTextColor := (StopTimerTextColor != "" ? StopTimerTextColor : text)
    timerBgColor := (StopTimerBgColor != "" ? StopTimerBgColor : panel)
    timerW := StopTimerWidth
    timerH := StopTimerHeight
    alpha := StopTimerTransparency
    if (timerW = "" || timerW < 80)
        timerW := 150
    if (timerH = "" || timerH < 40)
        timerH := 72
    if (StopTimerX = "")
        StopTimerX := 100
    if (StopTimerY = "")
        StopTimerY := 90
    if (alpha = "" || alpha < 120)
        alpha := 235

    Gui, 15:Destroy
    Gui, 15:+HwndhStopTimerWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +LastFound
    Gui, 15:Color, %timerBgColor%
    Gui, 15:Margin, 0, 0
    Gui, 15:Add, Progress, -Theme x0 y0 w%timerW% h1 Disabled Background%timerBgColor% c%borderColor%, 100
    bottomY := timerH - 1
    Gui, 15:Add, Progress, -Theme x0 y%bottomY% w%timerW% h1 Disabled Background%timerBgColor% c%borderColor%, 100
    Gui, 15:Add, Progress, -Theme x0 y0 w1 h%timerH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
    rightX := timerW - 1
    Gui, 15:Add, Progress, -Theme x%rightX% y0 w1 h%timerH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
    Gui, 15:Add, Text, x0 y0 w%timerW% h%timerH% Center 0x200 gStartStopTimerDrag vStopTimerCount hwndhStopTimerCountText BackgroundTrans, %StopTimerCounter%
    Gui, 15:Font, s26 Bold c%timerTextColor%, Segoe UI
    GuiControl, 15:Font, StopTimerCount
    UIStyle_SetTextRole(hStopTimerCountText, "text")
    showOpts := "x" . StopTimerX . " y" . StopTimerY . " w" . timerW . " h" . timerH . " NoActivate"
    Capture_BeforeShow("15")
    Gui, 15:Show, %showOpts%, StopTimer
    WinSet, Transparent, %alpha%, ahk_id %hStopTimerWnd%
    WinSet, AlwaysOnTop, On, ahk_id %hStopTimerWnd%
    ApplyRoundedCorners(hStopTimerWnd, UIRoundness)
    SetTimer, StopTimerTick, 1000
}

HideStopTimerGUI() {
    global hStopTimerWnd, StopTimerActive, StopTimerCounter, StopTimerX, StopTimerY
    SetTimer, StopTimerTick, Off
    if (hStopTimerWnd)
    {
        WinGetPos, x, y,,, ahk_id %hStopTimerWnd%
        if (x != "")
        {
            StopTimerX := x
            StopTimerY := y
            SaveUISettings()
        }
    }
    Gui, 15:Destroy
    hStopTimerWnd := 0
    StopTimerActive := 0
    StopTimerCounter := 0
}

ToggleBindList() {
    global BindListVisible
    SetBindListWindowState(!BindListVisible)
}

ToggleHUD() {
    global HUDVisible
    SetHUDWindowState(!HUDVisible)
}

GetCurrentDisplayID() {
    global UserID, ActiveID
    displayID := Trim(UserID)
    if (!ActiveID || displayID = "" || displayID = "ERROR")
        return "—"
    return displayID
}

ShowIDOverlay() {
    global IDOverlayVisible, hIDOverlayWnd, IDOverlayText, IDOverlayX, IDOverlayY, IDOverlayW, IDOverlayH, UIRoundness

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, text, accent)

    overlayW := IDOverlayW
    overlayH := IDOverlayH
    NormalizeNumberRange(overlayW, 120, 90, 240)
    NormalizeNumberRange(overlayH, 34, 28, 80)
    if (IDOverlayX = "")
        IDOverlayX := 20
    if (IDOverlayY = "")
        IDOverlayY := 420

    borderRight := overlayW - 1
    borderBottom := overlayH - 1
    textW := overlayW - 16

    Gui, IDOverlay:Destroy
    Gui, IDOverlay:New, +HwndhIDOverlayWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +LastFound
    Gui, IDOverlay:Color, %panel%
    Gui, IDOverlay:Margin, 0, 0
    Gui, IDOverlay:Add, Progress, -Theme x0 y0 w%overlayW% h1 Disabled Background%panel% c%edge%, 100
    Gui, IDOverlay:Add, Progress, -Theme x0 y%borderBottom% w%overlayW% h1 Disabled Background%panel% c%edge%, 100
    Gui, IDOverlay:Add, Progress, -Theme x0 y0 w1 h%overlayH% Disabled Vertical Background%panel% c%edge%, 100
    Gui, IDOverlay:Add, Progress, -Theme x%borderRight% y0 w1 h%overlayH% Disabled Vertical Background%panel% c%edge%, 100
    Gui, IDOverlay:Font, s10 Bold c%text%, Segoe UI
    Gui, IDOverlay:Add, Text, x8 y0 w%textW% h%overlayH% Center 0x200 vIDOverlayText BackgroundTrans, % "ID: " . GetCurrentDisplayID()
    Capture_BeforeShow("IDOverlay")
    Gui, IDOverlay:Show, % "x" . IDOverlayX . " y" . IDOverlayY . " w" . overlayW . " h" . overlayH . " NoActivate", IDOverlay
    WinSet, AlwaysOnTop, On, ahk_id %hIDOverlayWnd%
    ApplyRoundedCorners(hIDOverlayWnd, UIRoundness)
    IDOverlayVisible := 1
}

HideIDOverlay() {
    global IDOverlayVisible, hIDOverlayWnd
    Gui, IDOverlay:Destroy
    IDOverlayVisible := 0
    hIDOverlayWnd := 0
}

ToggleIDOverlay() {
    global IDOverlayVisible
    if (IDOverlayVisible)
        HideIDOverlay()
    else
        ShowIDOverlay()
}

UpdateIDOverlay() {
    global IDOverlayVisible, hIDOverlayWnd, IDOverlayText
    if (!IDOverlayVisible || !hIDOverlayWnd)
        return
    if !DllCall("IsWindow", "Ptr", hIDOverlayWnd)
        return
    GuiControl, IDOverlay:, IDOverlayText, % "ID: " . GetCurrentDisplayID()
}

ShowIDGui(idValue, nickname := "", isMask := 0) {
    global UserID, ActiveID, TargetNickname, TargetIsMask
    UserID := idValue
    TargetNickname := isMask ? "" : Trim(nickname)
    TargetIsMask := isMask ? 1 : 0
    ActiveID := 1
    UpdateHUD()
    UpdateIDOverlay()
    IncidentCard_OnTargetChanged()
}

ResetCurrentID() {
    IDCapture_Complete("cancel")
    global UserID, ActiveID, TargetNickname, TargetIsMask
    UserID := ""
    TargetNickname := ""
    TargetIsMask := 0
    ActiveID := 0
    UpdateHUD()
    UpdateIDOverlay()
    Notify("info")
    IncidentCard_OnTargetChanged()
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global hHUDWnd, hBindListWnd, hSettingsWnd, hStopTimerWnd, hActionTimerWnd
    global HudX, HudY, BindListX, BindListY, BindListW, BindListH, SettingsX, SettingsY, SettingsW, SettingsH, StopTimerX, StopTimerY, ActionTimerX, ActionTimerY

    if (hwnd = hHUDWnd)
    {
        WinGetPos, x, y,,, ahk_id %hHUDWnd%
        HudX := x
        HudY := y
        SaveHUDWindowState()
    }
    else if (hwnd = hBindListWnd)
    {
        WinGetPos, x, y, w, h, ahk_id %hBindListWnd%
        BindListX := x
        BindListY := y
        BindListW := w
        BindListH := h
        SaveBindListWindowState()
    }
    else if (hwnd = hSettingsWnd)
    {
        WinGetPos, x, y, w, h, ahk_id %hSettingsWnd%
        SettingsX := x
        SettingsY := y
        SettingsW := w
        SettingsH := h
        SaveSettingsWindowState()
    }
    else if (hwnd = hStopTimerWnd)
    {
        WinGetPos, x, y,,, ahk_id %hStopTimerWnd%
        StopTimerX := x
        StopTimerY := y
        SaveUISettings()
    }
    else if (hwnd = hActionTimerWnd)
    {
        WinGetPos, x, y,,, ahk_id %hActionTimerWnd%
        ActionTimerX := x
        ActionTimerY := y
        SaveUISettings()
    }
}

WM_NCHITTEST(wParam, lParam, msg, hwnd) {
    global hBindListWnd
    if (hwnd != hBindListWnd)
        return

    CoordMode, Mouse, Screen
    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
    if (ww = "" || wh = "")
        return

    mx := lParam & 0xFFFF
    my := (lParam >> 16) & 0xFFFF
    if (mx > 32767)
        mx -= 65536
    if (my > 32767)
        my -= 65536

    border := 8
    left := (mx >= wx && mx < wx + border)
    right := (mx <= wx + ww && mx > wx + ww - border)
    top := (my >= wy && my < wy + border)
    bottom := (my <= wy + wh && my > wy + wh - border)

    if (top && left)
        return 13
    if (top && right)
        return 14
    if (bottom && left)
        return 16
    if (bottom && right)
        return 17
    if (left)
        return 10
    if (right)
        return 11
    if (top)
        return 12
    if (bottom)
        return 15
}
