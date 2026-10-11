#NoEnv
#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2
ListLines, Off
SetBatchLines, -1
SetWinDelay, -1
SetControlDelay, -1
SetMouseDelay, -1
CoordMode, ToolTip, Screen
CoordMode, Mouse, Screen

if (A_PtrSize != 4 || A_IsUnicode)
{
    MsgBox, 16, Ошибка, Этот скрипт нужно запускать только через AutoHotkey 1.1 ANSI 32-bit.
    ExitApp, 2
}

#Include %A_ScriptDir%
#Include %A_ScriptDir%\UDF.ahk
#Include %A_ScriptDir%\runtime_support.ahk
#Include %A_ScriptDir%\chat_typing.ahk
#Include %A_ScriptDir%\id_capture.ahk
#Include %A_ScriptDir%\tests\chat_typing_regression.ahk
#Include %A_ScriptDir%\tests\id_capture_regression.ahk
#Include %A_ScriptDir%\tests\audit_regression.ahk
; ===== BEGIN EMBEDDED helper.ahk: territory map quality/forum patch =====
LawSearchDebug := 0
LawCorpusCache := {}
LawCorpusPages := {}
LawCorpusLastError := ""
LawCorpusPageMaxChars := 3200
LawCorpusPageMaxLines := 34
LawSearchCache := {}
LawSearchCacheOrder := []
LawSearchLevenshteinCache := {}
LawSearchLevenshteinCacheCount := 0
LawSearchFuzzyStartTick := 0
LawSearchFuzzyBudgetMs := 180
LawSearchFuzzyChecksLeft := 0
LawSearchFuzzyBudgetHit := 0
LawSearchAlgorithmVersion := 3
LawSearchDistanceCache := {}
LawSearchDistanceCacheCount := 0
TerritoryMapGuiVisible := 0
TerritoryMapViewVisible := 0
TerritoryMapSelectedIndex := 1
TerritoryMapCurrentGroup := 0
TerritoryMapCurrentAsset := 1
hTerritoryMapWnd := 0
hTerritoryMapViewWnd := 0


LawCorpus_SourceUrl(code)
{
    static urls := ""
    if !IsObject(urls)
    {
        urls := {}
        urls["VU"] := "https://forum.amazing-online.com/threads/vnutrennij-ustav-organov-vnutrennix-del.1027775/"
        urls["FP"] := "https://forum.amazing-online.com/threads/federalnoe-postanovlenie.1027639/"
        urls["KON"] := "https://forum.amazing-online.com/threads/konstitucija-nizhegorodskoj-oblasti.1031535/"
        urls["FZOP"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-policii.1027651/"
        urls["TER"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-territorijax-s-ogranichennym-dostupom.1027655/"
        urls["TK"] := "https://forum.amazing-online.com/threads/trudovoj-kodeks.1027657/"
        urls["ARG"] := "https://forum.amazing-online.com/threads/administrativnyj-reglament-gai.1027781/"
        urls["UK"] := "https://forum.amazing-online.com/threads/ugolovnyj-kodeks.1027637/"
        urls["VV"] := "https://forum.amazing-online.com/threads/federalnyj-konstitucionnyj-zakon-o-vertikali-vlasti.1027656/"
        urls["KOAP"] := "https://forum.amazing-online.com/threads/kodeks-ob-administrativnyx-pravonarushenijax.1027635/"
        urls["PDD"] := "https://forum.amazing-online.com/threads/pravila-dorozhnogo-dvizhenija.1027642/"
        urls["ORUZH"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-ob-oruzhii.1027647/"
        urls["UPK"] := "https://forum.amazing-online.com/threads/ugolovno-processualnyj-kodeks.1033497/"
        urls["KAS"] := "https://forum.amazing-online.com/threads/kodeks-administrativnogo-sudoproizvodstva.1033501/"
        urls["FSB"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-federalnoj-sluzhbe-bezopasnosti.1027654/"
        urls["FSIN"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-federalnoj-sluzhbe-ispolnenija-nakazanij.1027649/"
        urls["VS"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-voennoj-sluzhbe.1052585/"
        urls["SUD"] := "https://forum.amazing-online.com/threads/federalnyj-konstitucionnyj-zakon-o-sudebnoj-sisteme-i-statuse-sudej.1035855/"
        urls["ORD"] := "https://forum.amazing-online.com/threads/federalnyj-zakon-ob-operativno-rozysknoj-dejatelnosti.1033499/"
        urls["GT"] := "https://forum.amazing-online.com/threads/federalnyj-konstitucionnyj-zakon-o-gosudarstvennoj-tajne.1033498/"
    }
    code := Trim(code)
    StringUpper, code, code
    return urls.HasKey(code) ? urls[code] : ""
}

LawCorpus_GetMetaByPrefix(prefix)
{
    global LawSearchDocCatalog
    LawSearch_InitCatalog()
    prefix := Trim(prefix)
    StringLower, prefix, prefix
    Loop % LawSearchDocCatalog.Length()
    {
        meta := LawSearchDocCatalog[A_Index]
        if (meta.Prefix = prefix)
            return meta
    }
    return ""
}

LawCorpus_GetText(prefix, forceReload := 0)
{
    global LawCorpusCache, LawCorpusPages, LawCorpusLastError
    prefix := Trim(prefix)
    StringLower, prefix, prefix
    if (!forceReload && IsObject(LawCorpusCache) && LawCorpusCache.HasKey(prefix))
        return LawCorpusCache[prefix]

    meta := LawCorpus_GetMetaByPrefix(prefix)
    if !IsObject(meta)
    {
        LawCorpusLastError := "Неизвестный документ: " . prefix
        LawCorpus_LogError(LawCorpusLastError)
        return ""
    }

    path := A_ScriptDir . "\laws\" . meta.FileName
    if !FileExist(path)
    {
        LawCorpusLastError := "Отсутствует официальный файл: " . path
        LawCorpus_LogError(LawCorpusLastError)
        return ""
    }

    FileRead, text, %path%
    if (ErrorLevel || Trim(text) = "")
    {
        LawCorpusLastError := "Не удалось прочитать официальный файл: " . path
        LawCorpus_LogError(LawCorpusLastError)
        return ""
    }

    StringReplace, text, text, `r`n, `n, All
    StringReplace, text, text, `r, `n, All
    StringReplace, text, text, `n, `r`n, All
    text := RTrim(text, "`r`n")
    LawCorpusCache[prefix] := text
    if IsObject(LawCorpusPages)
        LawCorpusPages.Delete(prefix)
    LawCorpusLastError := ""
    return text
}

LawCorpus_LogError(message)
{
    if IsFunc("LogError")
    {
        fn := Func("LogError")
        fn.Call("LawCorpus", message, "ERROR")
    }
}

LawCorpus_BuildPages(prefix)
{
    global LawCorpusPages, LawCorpusPageMaxChars, LawCorpusPageMaxLines
    prefix := Trim(prefix)
    StringLower, prefix, prefix
    if (IsObject(LawCorpusPages) && LawCorpusPages.HasKey(prefix))
        return LawCorpusPages[prefix]

    text := LawCorpus_GetText(prefix)
    pages := []
    if (text = "")
    {
        return pages
    }

    current := ""
    lineCount := 0
    Loop, Parse, text, `n, `r
    {
        line := A_LoopField
        candidateLen := StrLen(current) + StrLen(line) + 2
        if (current != "" && (candidateLen > LawCorpusPageMaxChars || lineCount >= LawCorpusPageMaxLines))
        {
            pages.Push(RTrim(current, "`r`n"))
            current := ""
            lineCount := 0
        }

        if (StrLen(line) > LawCorpusPageMaxChars)
        {
            remaining := line
            while (StrLen(remaining) > LawCorpusPageMaxChars)
            {
                splitAt := LawCorpus_FindSplitPosition(remaining, LawCorpusPageMaxChars)
                chunk := SubStr(remaining, 1, splitAt)
                remaining := LTrim(SubStr(remaining, splitAt + 1))
                if (current != "")
                    pages.Push(RTrim(current, "`r`n"))
                pages.Push(chunk)
                current := ""
                lineCount := 0
            }
            line := remaining
        }

        current .= line . "`r`n"
        lineCount++
    }
    if (current != "")
        pages.Push(RTrim(current, "`r`n"))
    if (pages.Length() = 0)
        pages.Push(text)

    LawCorpusPages[prefix] := pages
    return pages
}

LawCorpus_FindSplitPosition(text, limit)
{
    if (StrLen(text) <= limit)
        return StrLen(text)
    pos := limit
    while (pos > Floor(limit * 0.65))
    {
        ch := SubStr(text, pos, 1)
        if (ch = " " || ch = A_Tab)
            return pos
        pos--
    }
    return limit
}

LawCorpus_PageCount(prefix)
{
    pages := LawCorpus_BuildPages(prefix)
    return IsObject(pages) ? pages.Length() : 0
}

LawCorpus_GetPage(prefix, page)
{
    pages := LawCorpus_BuildPages(prefix)
    if !IsObject(pages) || pages.Length() = 0
        return ""
    page := Round(page)
    if (page < 1)
        page := 1
    if (page > pages.Length())
        page := pages.Length()
    return pages[page]
}

LawCorpus_Reset()
{
    global LawCorpusCache, LawCorpusPages, SearchInitialized
    LawCorpusCache := {}
    LawCorpusPages := {}
    SearchInitialized := 0
}

LawCorpus_Audit()
{
    global LawSearchDocCatalog
    LawSearch_InitCatalog()
    issues := []
    totalChars := 0
    if (LawSearchDocCatalog.Length() != 20)
        issues.Push("Ожидалось 20 документов, найдено " . LawSearchDocCatalog.Length())
    seenCodes := {}
    seenFiles := {}
    Loop % LawSearchDocCatalog.Length()
    {
        meta := LawSearchDocCatalog[A_Index]
        if (seenCodes.HasKey(meta.Code))
            issues.Push("Повтор кода: " . meta.Code)
        if (seenFiles.HasKey(meta.FileName))
            issues.Push("Повтор файла: " . meta.FileName)
        seenCodes[meta.Code] := 1
        seenFiles[meta.FileName] := 1
        if (meta.SourceURL = "")
            issues.Push(meta.Code . ": отсутствует официальный URL")
        text := LawCorpus_GetText(meta.Prefix)
        if (text = "")
        {
            issues.Push(meta.Code . ": пустой или отсутствующий файл")
            continue
        }
        totalChars += StrLen(text)
        if InStr(text, "Нажмите, чтобы раскрыть")
            issues.Push(meta.Code . ": в corpus остался интерфейс спойлера")
        if (LawCorpus_PageCount(meta.Prefix) < 1)
            issues.Push(meta.Code . ": пагинация пуста")
    }
    return {Ok: issues.Length() = 0, Documents: LawSearchDocCatalog.Length()
        , Characters: totalChars, Issues: issues}
}

LawDoc_ShowPage(prefix, page := 1)
{
    global LawDocCurrentPages
    meta := LawCorpus_GetMetaByPrefix(prefix)
    if !IsObject(meta)
        return false
    count := LawCorpus_PageCount(prefix)
    if (count < 1)
    {
        MsgBox, 16, Ошибка законодательства, % "Не удалось открыть " . meta.Name . ". Проверьте папку laws."
        return false
    }
    page := Round(page)
    if (page < 1)
        page := 1
    if (page > count)
        page := count
    if !IsObject(LawDocCurrentPages)
        LawDocCurrentPages := {}
    LawDocCurrentPages[prefix] := page
    title := meta.Name . " (" . page . "/" . count . ")"
    LawGui_Show(1, title, LawCorpus_GetPage(prefix, page), 1, prefix)
    return true
}

LawDoc_GetCurrentPage(prefix)
{
    global LawDocCurrentPages
    if (IsObject(LawDocCurrentPages) && LawDocCurrentPages.HasKey(prefix))
        return LawDocCurrentPages[prefix]
    return 1
}

TerritoryMap_GetCatalog()
{
    static catalog := ""
    if IsObject(catalog)
        return catalog

    threadUrl := "https://forum.amazing-online.com/threads/federalnyj-zakon-o-territorijax-s-ogranichennym-dostupom.1027655"
    ; Direct /post-N links are more reliable for ShellExecute than fragment-only URLs.
    p1 := threadUrl . "/post-7449695"
    p2 := threadUrl . "/post-7449696"
    p3 := threadUrl . "/post-8194412"
    catalog := []
    catalog.Push({Id: "military_base", Name: "Красная зона воинской части", Files: "ter_01_military_base.jpg", ForumUrl: p1})
    catalog.Push({Id: "aircraft_carrier", Name: "Военный авианосец", Files: "ter_02_aircraft_carrier.jpg", ForumUrl: p1})
    catalog.Push({Id: "military_port", Name: "Военный порт", Files: "ter_03_military_port.jpg", ForumUrl: p1})
    catalog.Push({Id: "fsin_kresty", Name: "ИК «Кресты»", Files: "ter_04_fsin_kresty.png", ForumUrl: p2})
    catalog.Push({Id: "government", Name: "Правительство", Files: "ter_05_government_1.png|ter_06_government_2.png", ForumUrl: p2})
    catalog.Push({Id: "emergency_service", Name: "ЕСС", Files: "ter_07_emergency_service_1.png|ter_08_emergency_service_2.png", ForumUrl: p2})
    catalog.Push({Id: "draft_office", Name: "Военкомат", Files: "ter_09_draft_office_1.png|ter_10_draft_office_2.png", ForumUrl: p2})
    catalog.Push({Id: "fsb", Name: "УФСБ", Files: "ter_11_fsb.jpg", ForumUrl: p3})
    catalog.Push({Id: "umvd", Name: "УМВД", Files: "ter_12_umvd_1.jpg|ter_13_umvd_2.jpg", ForumUrl: p3})
    catalog.Push({Id: "gai", Name: "ГАИ", Files: "ter_14_gai_1.jpg|ter_15_gai_2.jpg", ForumUrl: p3})
    catalog.Push({Id: "court", Name: "Суд", Files: "ter_16_court_1.jpg|ter_17_court_2.jpg", ForumUrl: p3})
    return catalog
}

TerritoryMap_GetModeDisplay()
{
    global TerritoryMapMode
    return (TerritoryMapMode = "Forum") ? "Официальные ссылки форума" : "Локальные копии"
}

TerritoryMap_ShowCatalog(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapGuiVisible, TerritoryMapSelectedIndex, hTerritoryMapWnd
    catalog := TerritoryMap_GetCatalog()
    items := ""
    Loop % catalog.Length()
        items .= (items = "" ? "" : "|") . A_Index . ". " . catalog[A_Index].Name

    Gui, TerritoryMaps:Destroy
    Gui, TerritoryMaps:New, +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox +HwndhTerritoryMapWnd, Карты территорий
    Gui, TerritoryMaps:Margin, 14, 12
    Gui, TerritoryMaps:Font, s10 Bold, Segoe UI
    Gui, TerritoryMaps:Add, Text, w610, Карты территорий с ограниченным доступом
    Gui, TerritoryMaps:Font, s9 Norm, Segoe UI
    modeText := "Текущий режим: " . TerritoryMap_GetModeDisplay()
    Gui, TerritoryMaps:Add, Text, y+8 w610, %modeText%
    Gui, TerritoryMaps:Add, Text, y+6 w610 h58 +Wrap, Локальные копии показываются без увеличения выше исходного размера, поэтому миниатюры больше не размываются.`nОфициальные ссылки открывают соответствующий пост форума через системный браузер.
    Gui, TerritoryMaps:Add, ListBox, y+8 w610 r11 vTerritoryMapSelectedIndex AltSubmit Choose1, %items%
    Gui, TerritoryMaps:Add, Button, y+10 w190 h30 Default gTerritoryMap_OpenSelected, Открыть
    Gui, TerritoryMaps:Add, Button, x+12 yp w190 h30 gTerritoryMap_CloseCatalog, Закрыть
    Capture_BeforeShow("TerritoryMaps")
    Gui, TerritoryMaps:Show, AutoSize Center
    TerritoryMapSelectedIndex := 1
    TerritoryMapGuiVisible := 1
}

TerritoryMap_OpenSelected(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapMode, TerritoryMapSelectedIndex, TerritoryMapCurrentGroup, TerritoryMapCurrentAsset
    Gui, TerritoryMaps:Submit, NoHide
    catalog := TerritoryMap_GetCatalog()
    idx := TerritoryMapSelectedIndex + 0
    if (idx < 1 || idx > catalog.Length())
        idx := 1

    if (TerritoryMapMode = "Forum")
        return TerritoryMap_OpenOfficial(idx)

    TerritoryMapCurrentGroup := idx
    TerritoryMapCurrentAsset := 1
    return TerritoryMap_ShowLocal(idx, 1)
}

TerritoryMap_OpenOfficial(groupIndex)
{
    catalog := TerritoryMap_GetCatalog()
    if (groupIndex < 1 || groupIndex > catalog.Length())
        return false
    meta := catalog[groupIndex]
    if !TerritoryMap_IsOfficialUrl(meta.ForumUrl)
    {
        MsgBox, 16, Ошибка карт, Заблокирована недопустимая ссылка.
        return false
    }
    if TerritoryMap_ShellOpen(meta.ForumUrl)
        return true

    MsgBox, 48, Карты территорий, Не удалось открыть официальный пост форума.`nПроверьте браузер по умолчанию и ассоциацию протокола HTTPS.
    return false
}

TerritoryMap_ShowLocal(groupIndex, assetIndex := 1)
{
    global TerritoryMapGuiVisible, TerritoryMapViewVisible, TerritoryMapCurrentGroup
    global TerritoryMapCurrentAsset, hTerritoryMapViewWnd
    catalog := TerritoryMap_GetCatalog()
    if (groupIndex < 1 || groupIndex > catalog.Length())
        return false
    meta := catalog[groupIndex]
    files := StrSplit(meta.Files, "|")
    if (assetIndex < 1)
        assetIndex := files.Length()
    if (assetIndex > files.Length())
        assetIndex := 1
    path := A_ScriptDir . "\assets\law_maps\" . files[assetIndex]
    if !FileExist(path)
    {
        MsgBox, 48, Карты территорий, % "Локальная карта отсутствует:`n" . path . "`nИспользуйте кнопку «Оригинал форума» или режим официальных ссылок."
        return false
    }

    TerritoryMapCurrentGroup := groupIndex
    TerritoryMapCurrentAsset := assetIndex

    nativeW := 0
    nativeH := 0
    sizeKnown := TerritoryMap_GetImageSize(path, nativeW, nativeH)
    maxW := A_ScreenWidth - 100
    if (maxW > 1400)
        maxW := 1400
    if (maxW < 480)
        maxW := 480
    maxH := A_ScreenHeight - 220
    if (maxH < 300)
        maxH := 300

    if (sizeKnown)
    {
        displayW := nativeW
        displayH := nativeH
        ; Never enlarge a thumbnail: upscaling was the source of visible blur.
        if (displayW > maxW || displayH > maxH)
        {
            scale := Min(maxW / displayW, maxH / displayH)
            displayW := Floor(displayW * scale)
            displayH := Floor(displayH * scale)
        }
    }
    else
    {
        displayW := 0
        displayH := 0
    }

    canvasW := sizeKnown ? displayW : 960
    if (canvasW < 760)
        canvasW := 760
    if (canvasW > maxW)
        canvasW := maxW
    picX := 12
    if (sizeKnown && canvasW > displayW)
        picX += Floor((canvasW - displayW) / 2)

    Gui, TerritoryMapView:Destroy
    title := meta.Name . " (" . assetIndex . "/" . files.Length() . ")"
    Gui, TerritoryMapView:New, +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox +HwndhTerritoryMapViewWnd, %title%
    Gui, TerritoryMapView:Margin, 12, 10
    Gui, TerritoryMapView:Font, s10 Bold, Segoe UI
    Gui, TerritoryMapView:Add, Text, w%canvasW% Center, %title%

    Gui, TerritoryMapView:Font, s8 Norm c606060, Segoe UI
    if (sizeKnown)
    {
        sizeText := "Исходный размер: " . nativeW . "x" . nativeH . " px"
        if (displayW = nativeW && displayH = nativeH)
            sizeText .= " — показано без увеличения."
        else
            sizeText .= " — уменьшено до " . displayW . "x" . displayH . " px для экрана."
        Gui, TerritoryMapView:Add, Text, y+4 w%canvasW% Center, %sizeText%
    }
    if TerritoryMap_IsThumbnail(files[assetIndex])
    {
        Gui, TerritoryMapView:Font, s8 Norm cA06000, Segoe UI
        Gui, TerritoryMapView:Add, Text, y+3 w%canvasW% Center, Это официальная миниатюра. Полный вариант открывается кнопкой «Оригинал форума».
    }

    picOptions := "x" . picX . " y+8 gTerritoryMap_OpenCurrentLocal"
    if (sizeKnown)
        picOptions .= " w" . displayW . " h" . displayH
    Gui, TerritoryMapView:Add, Picture, %picOptions%, %path%

    Gui, TerritoryMapView:Font, s9 Norm c000000, Segoe UI
    Gui, TerritoryMapView:Add, Button, xm y+10 w130 h30 gTerritoryMap_PreviousAsset, Предыдущая
    Gui, TerritoryMapView:Add, Button, x+8 yp w130 h30 gTerritoryMap_NextAsset, Следующая
    Gui, TerritoryMapView:Add, Button, x+8 yp w145 h30 gTerritoryMap_OpenCurrentLocal, Открыть файл
    Gui, TerritoryMapView:Add, Button, x+8 yp w165 h30 gTerritoryMap_OpenCurrentForum, Оригинал форума
    Gui, TerritoryMapView:Add, Button, x+8 yp w130 h30 gTerritoryMap_CloseView, Закрыть
    Capture_BeforeShow("TerritoryMapView")
    Gui, TerritoryMapView:Show, AutoSize Center
    TerritoryMapViewVisible := 1
    TerritoryMapGuiVisible := 1
    return true
}

TerritoryMap_GetImageSize(path, ByRef width, ByRef height)
{
    width := 0
    height := 0
    imageType := ""
    hImage := LoadPicture(path, "GDI+")
    if (!hImage)
        hImage := LoadPicture(path)
    if (!hImage)
        return false

    VarSetCapacity(bitmapInfo, 24, 0)
    gotInfo := DllCall("GetObject", "Ptr", hImage, "Int", 24, "Ptr", &bitmapInfo)
    if (gotInfo)
    {
        width := NumGet(bitmapInfo, 4, "Int")
        height := Abs(NumGet(bitmapInfo, 8, "Int"))
    }

    DllCall("DeleteObject", "Ptr", hImage)

    return gotInfo && width > 0 && height > 0
}

TerritoryMap_IsThumbnail(fileName)
{
    return RegExMatch(fileName, "i)^ter_(?:0[1-3]|1[2-7])_") > 0
}

TerritoryMap_PreviousAsset(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    TerritoryMap_Navigate("prev")
}

TerritoryMap_NextAsset(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    TerritoryMap_Navigate("next")
}

TerritoryMap_Navigate(direction)
{
    global TerritoryMapCurrentGroup, TerritoryMapCurrentAsset, TerritoryMapViewVisible
    if (!TerritoryMapViewVisible || TerritoryMapCurrentGroup < 1)
        return false
    catalog := TerritoryMap_GetCatalog()
    meta := catalog[TerritoryMapCurrentGroup]
    files := StrSplit(meta.Files, "|")
    next := TerritoryMapCurrentAsset + ((direction = "prev") ? -1 : 1)
    if (next < 1)
        next := files.Length()
    if (next > files.Length())
        next := 1
    return TerritoryMap_ShowLocal(TerritoryMapCurrentGroup, next)
}

TerritoryMap_OpenCurrentForum(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapCurrentGroup, TerritoryMapSelectedIndex
    idx := TerritoryMapCurrentGroup + 0
    if (idx < 1)
        idx := TerritoryMapSelectedIndex + 0
    return TerritoryMap_OpenOfficial(idx)
}

TerritoryMap_OpenCurrentLocal(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapCurrentGroup, TerritoryMapCurrentAsset
    catalog := TerritoryMap_GetCatalog()
    if (TerritoryMapCurrentGroup < 1 || TerritoryMapCurrentGroup > catalog.Length())
        return false
    meta := catalog[TerritoryMapCurrentGroup]
    files := StrSplit(meta.Files, "|")
    idx := TerritoryMapCurrentAsset + 0
    if (idx < 1 || idx > files.Length())
        idx := 1
    path := A_ScriptDir . "\assets\law_maps\" . files[idx]
    if !FileExist(path)
        return false
    if TerritoryMap_ShellOpen(path)
        return true
    MsgBox, 48, Карты территорий, Не удалось открыть файл в системном просмотрщике изображений.
    return false
}

TerritoryMap_ShellOpen(target)
{
    target := Trim(target)
    if (target = "")
        return false
    result := DllCall("Shell32\ShellExecuteA"
        , "Ptr", 0
        , "AStr", "open"
        , "AStr", target
        , "Ptr", 0
        , "AStr", A_ScriptDir
        , "Int", 1
        , "UPtr")
    if (result > 32)
        return true

    ; Fallback for systems where ShellExecute reports a broken file association.
    Run, %target%,, UseErrorLevel
    return !ErrorLevel
}

TerritoryMap_IsOfficialUrl(url)
{
    return RegExMatch(url, "i)^https://forum\.amazing-online\.com/threads/[a-z0-9._-]+(?:/post-\d+|/#post-\d+|/)?$") > 0
}

TerritoryMap_CloseCatalog(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapGuiVisible, TerritoryMapViewVisible, hTerritoryMapWnd
    Gui, TerritoryMaps:Destroy
    hTerritoryMapWnd := 0
    TerritoryMapGuiVisible := TerritoryMapViewVisible ? 1 : 0
}

TerritoryMap_CloseView(CtrlHwnd := "", GuiEvent := "", EventInfo := "", ErrLevel := "")
{
    global TerritoryMapGuiVisible, TerritoryMapViewVisible, hTerritoryMapViewWnd, hTerritoryMapWnd
    Gui, TerritoryMapView:Destroy
    hTerritoryMapViewWnd := 0
    TerritoryMapViewVisible := 0
    TerritoryMapGuiVisible := (hTerritoryMapWnd && WinExist("ahk_id " . hTerritoryMapWnd)) ? 1 : 0
}

TerritoryMap_CloseAll()
{
    global TerritoryMapGuiVisible, TerritoryMapViewVisible, hTerritoryMapWnd, hTerritoryMapViewWnd
    Gui, TerritoryMaps:Destroy
    Gui, TerritoryMapView:Destroy
    hTerritoryMapWnd := 0
    hTerritoryMapViewWnd := 0
    TerritoryMapGuiVisible := 0
    TerritoryMapViewVisible := 0
}

TerritoryMap_AuditCatalog()
{
    catalog := TerritoryMap_GetCatalog()
    issues := []
    seen := {}
    if (catalog.Length() != 11)
        issues.Push("Ожидалось 11 групп карт, найдено " . catalog.Length())
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (seen.HasKey(meta.Id))
            issues.Push("Повтор ID карты: " . meta.Id)
        seen[meta.Id] := 1
        if !TerritoryMap_IsOfficialUrl(meta.ForumUrl)
            issues.Push("Недопустимая ссылка: " . meta.Id)
        files := StrSplit(meta.Files, "|")
        Loop % files.Length()
        {
            path := A_ScriptDir . "\assets\law_maps\" . files[A_Index]
            if !FileExist(path)
                issues.Push("Нет локального файла: " . files[A_Index])
        }
    }
    return {Ok: issues.Length() = 0, Groups: catalog.Length(), Issues: issues}
}


LawGui_Close()
{
    global ServiceCodesGuiVisible, current_doc, last_doc
    Gui, 1:Destroy
    TerritoryMap_CloseAll()
    ServiceCodesGuiVisible := 0
    current_doc := 0
    last_doc := 0
}

Helper_CloseChatAfterGui(inputEpoch := 0)
{
    inputEpoch := AutomationEpoch
    ; The configured local hotkey can still be physically held when it fires.
    ; Wait for release before sending Ctrl+A or Escape to the game.
    KeyWait, F
    KeyWait, LControl
    KeyWait, RControl
    KeyWait, LAlt
    KeyWait, RAlt

    SafeSend("{LControl up}{RControl up}{LAlt up}{RAlt up}", "Input", inputEpoch)
    Sleep, 30

    if IsFunc("isInChat")
    {
        chatFn := Func("isInChat")
        if (chatFn.Call() != 1)
            return true
    }

    if IsFunc("ClearBindMenuChatLine")
    {
        clearFn := Func("ClearBindMenuChatLine")
        clearFn.Call(true)
    }
    else
    {
        SafeSend("^a", "Event", inputEpoch)
        Sleep, 30
        SafeSend("{Backspace}", "Event", inputEpoch)
        Sleep, 30
    }

    started := TickNow()
    Loop
    {
        if IsFunc("isInChat")
        {
            chatFn := Func("isInChat")
            if (chatFn.Call() != 1)
                return true
        }

        ; Escape cancels the empty line. Enter and F6 are never used.
        SafeSend("{Esc}", "Event", inputEpoch)
        Sleep, 90

        if (TickNow() - started >= 900)
            break
    }

    if IsFunc("isInChat")
    {
        chatFn := Func("isInChat")
        return chatFn.Call() != 1
    }
    return true
}


LawGui_FormatBody(body, title := "")
{
    marker := "__LAWGUI_CURRENT_PAGE__"
    prefix := LawGui_GetDocPrefixFromTitle(title, page)
    if (prefix != "" && page > 1)
    {
        before := ""
        prevCount := page - 1
        Loop %prevCount%
        {
            fnName := "LawText_" . prefix . A_Index
            if IsFunc(fnName)
            {
                fn := Func(fnName)
                before .= fn.Call() . "`r`n"
            }
        }

        formatted := LawGui_FormatBodyCore(before . marker . "`r`n" . body)
        markerPos := InStr(formatted, marker)
        if (markerPos > 0)
            return Trim(SubStr(formatted, markerPos + StrLen(marker)), "`r`n")
    }

    return LawGui_FormatBodyCore(body)
}

LawGui_GetDocPrefixFromTitle(title, ByRef page)
{
    page := 1
    if (RegExMatch(title, "\(([0-9]+)/[0-9]+\)", m))
        page := m1 + 0

    if (InStr(title, "Внутренний устав"))
        return "vu"
    if (InStr(title, "Федеральное постановление"))
        return "fp"
    if (InStr(title, "Конституция"))
        return "kon"
    if (InStr(title, "О полиции"))
        return "fzop"
    if (InStr(title, "территориях"))
        return "ter"
    if (InStr(title, "Трудовой"))
        return "tk"
    if (InStr(title, "Административный регламент"))
        return "arg"
    if (InStr(title, "Уголовный кодекс") && !InStr(title, "Уголовно-процессуальный"))
        return "uk"
    if (InStr(title, "вертикали власти"))
        return "vv"
    if (InStr(title, "административных правонарушениях"))
        return "koap"
    if (InStr(title, "Правила дорожного движения"))
        return "pdd"
    if (InStr(title, "Об оружии"))
        return "oruzh"
    if (InStr(title, "Уголовно-процессуальный"))
        return "upk"
    return ""
}

LawGui_FormatBodyCore(body)
{
    formatted := ""
    article := ""
    part := ""
    point := ""
    currentLevel := ""
    currentText := ""
    explainActive := 0
    explainSubSeen := 0
    explainAfterList := 0
    explainArticle := ""
    explainPart := ""
    explainPoint := ""
    subListActive := 0
    subListSubSeen := 0
    subListAfterList := 0
    subListPoint := ""
    subListPart := ""
    subListArticle := ""

    Loop, Parse, body, `n, `r
    {
        raw := A_LoopField
        line := Trim(raw)
        if (line = "")
        {
            formatted .= "`r`n"
            continue
        }
        if (line = "__LAWGUI_CURRENT_PAGE__")
        {
            formatted .= line . "`r`n"
            continue
        }

        if (!explainActive && !subListActive && currentLevel = "point" && LawSearch_TextEndsWithColon(currentText) && RegExMatch(line, "^\s*[0-9]+\)\s+"))
        {
            subListActive := 1
            subListSubSeen := 0
            subListAfterList := 0
            subListPoint := point
            subListPart := part
            subListArticle := article
        }

        indent := LawGui_GetIndent(raw)
        kind := ""
        id := ""
        title := ""
        itemBody := ""
        forceSubPoint := ((explainActive && !explainAfterList) || (subListActive && !subListAfterList))

        if (LawSearch_ParseStructureLine(line, kind, id, title, itemBody, article, 0, part, point, forceSubPoint))
        {
            if (kind = "chapter")
            {
                article := ""
                part := ""
                point := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "article")
            {
                article := id
                part := ""
                point := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "part")
            {
                part := id
                point := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "point")
            {
                point := id
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "subpoint")
            {
                if (explainActive)
                {
                    if (explainArticle != "")
                        article := explainArticle
                    if (explainPart != "")
                        part := explainPart
                    if (explainPoint != "")
                        point := explainPoint
                    explainSubSeen := 1
                }
                if (subListActive)
                {
                    if (subListArticle != "")
                        article := subListArticle
                    if (subListPart != "")
                        part := subListPart
                    if (subListPoint != "")
                        point := subListPoint
                    subListSubSeen := 1
                }
            }

            currentLevel := kind
            currentText := itemBody
            formatted .= indent . LawGui_FormatStructureDisplay(kind, id, title, itemBody) . "`r`n"
            continue
        }

        if (LawSearch_DetectPointExplanation(line, expArticle, expPart, expPoint))
        {
            explainActive := 1
            explainSubSeen := 0
            explainAfterList := 0
            explainArticle := expArticle
            explainPart := expPart
            explainPoint := expPoint
            if (expArticle != "")
                article := expArticle
            if (expPart != "")
                part := expPart
            if (expPoint != "")
                point := expPoint
        }
        else
        {
            if (explainActive && explainSubSeen)
                explainAfterList := 1
            if (subListActive && subListSubSeen)
                subListAfterList := 1
        }

        if (currentLevel != "")
            currentText .= " " . line
        formatted .= raw . "`r`n"
    }

    return RTrim(formatted, "`r`n")
}

LawGui_GetIndent(raw)
{
    if (RegExMatch(raw, "^\s+", m))
        return m
    return ""
}

LawGui_FormatStructureDisplay(kind, id, title, body)
{
    if (kind = "chapter" || kind = "article")
        return title

    if (kind = "part")
        prefix := "Ч. " . id
    else if (kind = "point")
        prefix := "П. " . id
    else if (kind = "subpoint")
        prefix := "ПП. " . id
    else
        prefix := title

    body := Trim(body)
    if (body != "")
        return prefix . ". " . body
    return prefix
}

LawGui_Show(state, title, body, officialExact := 0, docPrefix := "")
{
    global LawGuiTextColor, LawGuiBgColor, LawGuiTransparency

    if (!state)
    {
        LawGui_Close()
        return
    }

    if (!officialExact)
        body := LawGui_FormatBody(body, title)

    Gui, 1:Destroy

    LawGuiX := 5
    LawGuiY := 8
    uiScale := A_ScreenDPI / 96.0
    screenW := Floor(A_ScreenWidth / uiScale)
    screenH := Floor(A_ScreenHeight / uiScale)
    LawGuiW := Floor(screenW / 3)
    if (LawGuiW < 620)
        LawGuiW := 620
    if (LawGuiW > 900)
        LawGuiW := 900
    maxLawW := screenW - 16
    if (LawGuiW > maxLawW)
        LawGuiW := maxLawW

    LawGuiH := screenH - 26
    if (LawGuiH < 600)
        LawGuiH := 600
    maxLawH := screenH - 16
    if (LawGuiH > maxLawH)
        LawGuiH := maxLawH

    LawTextColor := LawGuiTextColor
    if (LawTextColor = "")
        LawTextColor := "FFFFFF"

    LawBgColor := LawGuiBgColor
    if (LawBgColor = "")
        LawBgColor := "000000"

    LawAlpha := LawGuiTransparency
    if (LawAlpha = "")
        LawAlpha := 222
    if (LawAlpha < 200)
        LawAlpha := 200
    if (LawAlpha > 235)
        LawAlpha := 235

    LawBodyFontSize := 9
    if (A_ScreenHeight >= 1300)
        LawBodyFontSize := 10
    LawTitleFontSize := LawBodyFontSize + 1
    LawAccentColor := LawSearch_GetShellAccentColor()

    ContentW := LawGuiW - 28
    if (ContentW < 550)
        ContentW := LawGuiW - 24

    LawHeaderTitle := title
    LawHeaderPage := ""
    if (RegExMatch(title, "^(.*) \(([^()]*)\)$", LawTitleMatch))
    {
        LawHeaderTitle := LawTitleMatch1
        LawHeaderPage := LawTitleMatch2
    }

    HeaderPageW := 78
    HeaderMapW := (docPrefix = "ter") ? 72 : 0
    HeaderTitleW := ContentW - HeaderPageW - HeaderMapW - 16
    if (LawHeaderPage = "")
        HeaderTitleW := ContentW - HeaderMapW - (HeaderMapW ? 8 : 0)
    HeaderH := 30
    BodyH := Max(40, LawGuiH - 62)

    Gui, 1:+LastFound +AlwaysOnTop -Caption +ToolWindow +Border +HwndLawGuiHwnd
    Gui, 1:Color, %LawBgColor%, %LawBgColor%
    Gui, 1:Margin, 10, 6
    LawBorderRight := LawGuiW - 2
    LawBorderBottom := LawGuiH - 2
    Gui, 1:Add, Progress, -Theme x0 y0 w%LawGuiW% h2 Disabled Background%LawBgColor% c%LawAccentColor%, 100
    Gui, 1:Add, Progress, -Theme x0 y%LawBorderBottom% w%LawGuiW% h2 Disabled Background%LawBgColor% c%LawAccentColor%, 100
    Gui, 1:Add, Progress, -Theme x0 y0 w2 h%LawGuiH% Disabled Vertical Background%LawBgColor% c%LawAccentColor%, 100
    Gui, 1:Add, Progress, -Theme x%LawBorderRight% y0 w2 h%LawGuiH% Disabled Vertical Background%LawBgColor% c%LawAccentColor%, 100

    Gui, 1:Font, s%LawTitleFontSize% Bold c%LawTextColor%, Segoe UI
    Gui, 1:Add, Text, xm ym w%HeaderTitleW% h%HeaderH% +0x200 +0x4000 BackgroundTrans, %LawHeaderTitle%
    if (LawHeaderPage != "")
    {
        Gui, 1:Font, s%LawBodyFontSize% Bold c%LawAccentColor%, Segoe UI
        Gui, 1:Add, Text, x+8 yp w%HeaderPageW% h%HeaderH% +0x200 Right BackgroundTrans, %LawHeaderPage%
    }
    if (docPrefix = "ter")
    {
        Gui, 1:Font, s%LawBodyFontSize% Bold c%LawTextColor%, Segoe UI
        Gui, 1:Add, Button, x+8 yp w%HeaderMapW% h22 gTerritoryMap_ShowCatalog, Карты
    }
    Gui, 1:Add, Progress, -Theme xm y+3 w%ContentW% h1 Disabled Background%LawBgColor% c%LawAccentColor%, 100

    Gui, 1:Font, Norm s%LawBodyFontSize% c%LawTextColor%, Segoe UI
    Gui, 1:Add, Edit, xm y+8 w%ContentW% h%BodyH% ReadOnly Multi +VScroll -WantTab, %body%

    Capture_BeforeShow("1")

    Gui, 1:Show, x%LawGuiX% y%LawGuiY% w%LawGuiW% h%LawGuiH% NoActivate, window.
    WinSet, Transparent, %LawAlpha%, ahk_id %LawGuiHwnd%
    LawSearch_ApplyShellRound(LawGuiHwnd)
}

vu1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vu", 1)
}

vu2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vu", 2)
}

vu3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vu", 3)
}

fp1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fp", 1)
}

fp2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fp", 2)
}

fp3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fp", 3)
}

fp4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fp", 4)
}

kon1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kon", 1)
}

kon2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kon", 2)
}

kon3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kon", 3)
}

kon4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kon", 4)
}

fzop1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 1)
}

fzop2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 2)
}

fzop3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 3)
}

fzop4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 4)
}

fzop5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 5)
}

fzop6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 6)
}

fzop7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 7)
}

fzop8(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 8)
}

fzop9(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 9)
}

fzop10(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 10)
}

fzop11(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 11)
}

fzop12(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fzop", 12)
}

ter1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 1)
}

ter2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 2)
}

ter3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 3)
}

ter4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 4)
}

ter5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 5)
}

ter6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 6)
}

ter7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ter", 7)
}

tk1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 1)
}

tk2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 2)
}

tk3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 3)
}

tk4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 4)
}

tk5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 5)
}

tk6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("tk", 6)
}

arg1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("arg", 1)
}

arg2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("arg", 2)
}

arg3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("arg", 3)
}

arg4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("arg", 4)
}

uk1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 1)
}

uk2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 2)
}

uk3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 3)
}

uk4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 4)
}

uk5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 5)
}

uk6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 6)
}

uk7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 7)
}

uk8(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 8)
}

uk9(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("uk", 9)
}

vv1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vv", 1)
}

vv2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vv", 2)
}

vv3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vv", 3)
}

vv4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vv", 4)
}

vv5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vv", 5)
}

koap1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 1)
}

koap2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 2)
}

koap3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 3)
}

koap4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 4)
}

koap5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 5)
}

koap6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 6)
}

koap7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 7)
}

koap8(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("koap", 8)
}

pdd1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 1)
}

pdd2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 2)
}

pdd3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 3)
}

pdd4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 4)
}

pdd5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 5)
}

pdd6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 6)
}

pdd7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 7)
}

pdd8(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 8)
}

pdd9(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 9)
}

pdd10(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("pdd", 10)
}

oruzh1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("oruzh", 1)
}

oruzh2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("oruzh", 2)
}

oruzh3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("oruzh", 3)
}

upk1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 1)
}

upk2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 2)
}

upk3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 3)
}

upk4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 4)
}

upk5(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 5)
}

upk6(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 6)
}

upk7(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 7)
}

upk8(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 8)
}

upk9(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 9)
}

upk10(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 10)
}

upk11(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 11)
}

upk12(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 12)
}

upk13(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 13)
}

upk14(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 14)
}

upk15(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 15)
}

upk16(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 16)
}

upk17(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 17)
}

upk18(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 18)
}

upk19(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 19)
}

upk20(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 20)
}

upk21(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 21)
}

upk22(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 22)
}

upk23(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 23)
}

upk24(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 24)
}

upk25(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 25)
}

upk26(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 26)
}

upk27(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 27)
}

upk28(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 28)
}

upk29(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 29)
}

upk30(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 30)
}

upk31(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 31)
}

upk32(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 32)
}

upk33(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 33)
}

upk34(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 34)
}

upk35(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 35)
}

upk36(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 36)
}

upk37(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 37)
}

upk38(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 38)
}

upk39(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 39)
}

upk40(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 40)
}

upk41(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("upk", 41)
}

LawText_vu1()
{
    return LawCorpus_GetPage("vu", 1)
}

LawText_vu2()
{
    return LawCorpus_GetPage("vu", 2)
}

LawText_vu3()
{
    return LawCorpus_GetPage("vu", 3)
}

LawText_fp1()
{
    return LawCorpus_GetPage("fp", 1)
}

LawText_fp2()
{
    return LawCorpus_GetPage("fp", 2)
}

LawText_fp3()
{
    return LawCorpus_GetPage("fp", 3)
}

LawText_fp4()
{
    return LawCorpus_GetPage("fp", 4)
}

LawText_kon1()
{
    return LawCorpus_GetPage("kon", 1)
}

LawText_kon2()
{
    return LawCorpus_GetPage("kon", 2)
}

LawText_kon3()
{
    return LawCorpus_GetPage("kon", 3)
}

LawText_kon4()
{
    return LawCorpus_GetPage("kon", 4)
}

LawText_fzop1()
{
    return LawCorpus_GetPage("fzop", 1)
}

LawText_fzop2()
{
    return LawCorpus_GetPage("fzop", 2)
}

LawText_fzop3()
{
    return LawCorpus_GetPage("fzop", 3)
}

LawText_fzop4()
{
    return LawCorpus_GetPage("fzop", 4)
}

LawText_fzop5()
{
    return LawCorpus_GetPage("fzop", 5)
}

LawText_fzop6()
{
    return LawCorpus_GetPage("fzop", 6)
}

LawText_fzop7()
{
    return LawCorpus_GetPage("fzop", 7)
}

LawText_fzop8()
{
    return LawCorpus_GetPage("fzop", 8)
}

LawText_fzop9()
{
    return LawCorpus_GetPage("fzop", 9)
}

LawText_fzop10()
{
    return LawCorpus_GetPage("fzop", 10)
}

LawText_fzop11()
{
    return LawCorpus_GetPage("fzop", 11)
}

LawText_fzop12()
{
    return LawCorpus_GetPage("fzop", 12)
}

LawText_ter1()
{
    return LawCorpus_GetPage("ter", 1)
}

LawText_ter2()
{
    return LawCorpus_GetPage("ter", 2)
}

LawText_ter3()
{
    return LawCorpus_GetPage("ter", 3)
}

LawText_ter4()
{
    return LawCorpus_GetPage("ter", 4)
}

LawText_ter5()
{
    return LawCorpus_GetPage("ter", 5)
}

LawText_ter6()
{
    return LawCorpus_GetPage("ter", 6)
}

LawText_ter7()
{
    return LawCorpus_GetPage("ter", 7)
}

LawText_tk1()
{
    return LawCorpus_GetPage("tk", 1)
}

LawText_tk2()
{
    return LawCorpus_GetPage("tk", 2)
}

LawText_tk3()
{
    return LawCorpus_GetPage("tk", 3)
}

LawText_tk4()
{
    return LawCorpus_GetPage("tk", 4)
}

LawText_tk5()
{
    return LawCorpus_GetPage("tk", 5)
}

LawText_tk6()
{
    return LawCorpus_GetPage("tk", 6)
}

LawText_arg1()
{
    return LawCorpus_GetPage("arg", 1)
}

LawText_arg2()
{
    return LawCorpus_GetPage("arg", 2)
}

LawText_arg3()
{
    return LawCorpus_GetPage("arg", 3)
}

LawText_arg4()
{
    return LawCorpus_GetPage("arg", 4)
}

LawText_uk1()
{
    return LawCorpus_GetPage("uk", 1)
}

LawText_uk2()
{
    return LawCorpus_GetPage("uk", 2)
}

LawText_uk3()
{
    return LawCorpus_GetPage("uk", 3)
}

LawText_uk4()
{
    return LawCorpus_GetPage("uk", 4)
}

LawText_uk5()
{
    return LawCorpus_GetPage("uk", 5)
}

LawText_uk6()
{
    return LawCorpus_GetPage("uk", 6)
}

LawText_uk7()
{
    return LawCorpus_GetPage("uk", 7)
}

LawText_uk8()
{
    return LawCorpus_GetPage("uk", 8)
}

LawText_uk9()
{
    return LawCorpus_GetPage("uk", 9)
}

LawText_vv1()
{
    return LawCorpus_GetPage("vv", 1)
}

LawText_vv2()
{
    return LawCorpus_GetPage("vv", 2)
}

LawText_vv3()
{
    return LawCorpus_GetPage("vv", 3)
}

LawText_vv4()
{
    return LawCorpus_GetPage("vv", 4)
}

LawText_vv5()
{
    return LawCorpus_GetPage("vv", 5)
}

LawText_koap1()
{
    return LawCorpus_GetPage("koap", 1)
}

LawText_koap2()
{
    return LawCorpus_GetPage("koap", 2)
}

LawText_koap3()
{
    return LawCorpus_GetPage("koap", 3)
}

LawText_koap4()
{
    return LawCorpus_GetPage("koap", 4)
}

LawText_koap5()
{
    return LawCorpus_GetPage("koap", 5)
}

LawText_koap6()
{
    return LawCorpus_GetPage("koap", 6)
}

LawText_koap7()
{
    return LawCorpus_GetPage("koap", 7)
}

LawText_koap8()
{
    return LawCorpus_GetPage("koap", 8)
}

LawText_pdd1()
{
    return LawCorpus_GetPage("pdd", 1)
}

LawText_pdd2()
{
    return LawCorpus_GetPage("pdd", 2)
}

LawText_pdd3()
{
    return LawCorpus_GetPage("pdd", 3)
}

LawText_pdd4()
{
    return LawCorpus_GetPage("pdd", 4)
}

LawText_pdd5()
{
    return LawCorpus_GetPage("pdd", 5)
}

LawText_pdd6()
{
    return LawCorpus_GetPage("pdd", 6)
}

LawText_pdd7()
{
    return LawCorpus_GetPage("pdd", 7)
}

LawText_pdd8()
{
    return LawCorpus_GetPage("pdd", 8)
}

LawText_pdd9()
{
    return LawCorpus_GetPage("pdd", 9)
}

LawText_pdd10()
{
    return LawCorpus_GetPage("pdd", 10)
}

LawText_oruzh1()
{
    return LawCorpus_GetPage("oruzh", 1)
}

LawText_oruzh2()
{
    return LawCorpus_GetPage("oruzh", 2)
}

LawText_oruzh3()
{
    return LawCorpus_GetPage("oruzh", 3)
}

LawText_upk1()
{
    return LawCorpus_GetPage("upk", 1)
}

LawText_upk2()
{
    return LawCorpus_GetPage("upk", 2)
}

LawText_upk3()
{
    return LawCorpus_GetPage("upk", 3)
}

LawText_upk4()
{
    return LawCorpus_GetPage("upk", 4)
}

LawText_upk5()
{
    return LawCorpus_GetPage("upk", 5)
}

LawText_upk6()
{
    return LawCorpus_GetPage("upk", 6)
}

LawText_upk7()
{
    return LawCorpus_GetPage("upk", 7)
}

LawText_upk8()
{
    return LawCorpus_GetPage("upk", 8)
}

LawText_upk9()
{
    return LawCorpus_GetPage("upk", 9)
}

LawText_upk10()
{
    return LawCorpus_GetPage("upk", 10)
}

LawText_upk11()
{
    return LawCorpus_GetPage("upk", 11)
}

LawText_upk12()
{
    return LawCorpus_GetPage("upk", 12)
}

LawText_upk13()
{
    return LawCorpus_GetPage("upk", 13)
}

LawText_upk14()
{
    return LawCorpus_GetPage("upk", 14)
}

LawText_upk15()
{
    return LawCorpus_GetPage("upk", 15)
}

LawText_upk16()
{
    return LawCorpus_GetPage("upk", 16)
}

LawText_upk17()
{
    return LawCorpus_GetPage("upk", 17)
}

LawText_upk18()
{
    return LawCorpus_GetPage("upk", 18)
}

LawText_upk19()
{
    return LawCorpus_GetPage("upk", 19)
}

LawText_upk20()
{
    return LawCorpus_GetPage("upk", 20)
}

LawText_upk21()
{
    return LawCorpus_GetPage("upk", 21)
}

LawText_upk22()
{
    return LawCorpus_GetPage("upk", 22)
}

LawText_upk23()
{
    return LawCorpus_GetPage("upk", 23)
}

LawText_upk24()
{
    return LawCorpus_GetPage("upk", 24)
}

LawText_upk25()
{
    return LawCorpus_GetPage("upk", 25)
}

LawText_upk26()
{
    return LawCorpus_GetPage("upk", 26)
}

LawText_upk27()
{
    return LawCorpus_GetPage("upk", 27)
}

LawText_upk28()
{
    return LawCorpus_GetPage("upk", 28)
}

LawText_upk29()
{
    return LawCorpus_GetPage("upk", 29)
}

LawText_upk30()
{
    return LawCorpus_GetPage("upk", 30)
}

LawText_upk31()
{
    return LawCorpus_GetPage("upk", 31)
}

LawText_upk32()
{
    return LawCorpus_GetPage("upk", 32)
}

LawText_upk33()
{
    return LawCorpus_GetPage("upk", 33)
}

LawText_upk34()
{
    return LawCorpus_GetPage("upk", 34)
}

LawText_upk35()
{
    return LawCorpus_GetPage("upk", 35)
}

LawText_upk36()
{
    return LawCorpus_GetPage("upk", 36)
}

LawText_upk37()
{
    return LawCorpus_GetPage("upk", 37)
}

LawText_upk38()
{
    return LawCorpus_GetPage("upk", 38)
}

LawText_upk39()
{
    return LawCorpus_GetPage("upk", 39)
}

LawText_upk40()
{
    return LawCorpus_GetPage("upk", 40)
}

LawText_upk41()
{
    return LawCorpus_GetPage("upk", 41)
}



LawSearch_Init()
{
    global SearchInitialized, SearchIndex, SearchIndexCounts, LawSearchDocCatalog, LawCorpusCache, LawCorpusPages
    global LawSearchCache, LawSearchCacheOrder, LawSearchLevenshteinCache, LawSearchLevenshteinCacheCount

    signature := LawSearch_CorpusFingerprint()
    if (SearchInitialized && LawSearchCorpusSignature = signature)
        return true
    if (LawSearchBuildBusy)
        return false
    LawSearchBuildBusy := 1
    previousCritical := A_IsCritical
    Critical, On
    try {
    LawCorpusCache := {}
    LawCorpusPages := {}
    LawSearchMissingDocuments := []

    LawSearchCache := {}
    LawSearchCacheOrder := []
    LawSearchLevenshteinCache := {}
    LawSearchLevenshteinCacheCount := 0

    LawSearch_InitCatalog()
    SearchIndex := []
    SearchIndexCounts := {}

    Loop % LawSearchDocCatalog.Length()
    {
        doc := LawSearchDocCatalog[A_Index]
        if !LawSearch_AddDocFromCorpus(doc.Code, doc.Name, doc.Prefix)
            LawSearchMissingDocuments.Push(doc.Code)
    }

    LawSearchVocabulary_Build()
    LawSearchCorpusSignature := signature
    SearchInitialized := 1
    } finally {
        LawSearchBuildBusy := 0
        Critical, %previousCritical%
    }
    return true
}

LawSearch_PageCount(prefix)
{
    corpusCount := LawCorpus_PageCount(prefix)
    if (corpusCount > 0)
        return corpusCount

    if IsFunc("LawDoc_PageCount")
    {
        pageCountFn := Func("LawDoc_PageCount")
        return pageCountFn.Call(prefix)
    }

    if (prefix = "vu")
        return 3
    else if (prefix = "fp")
        return 4
    else if (prefix = "kon")
        return 4
    else if (prefix = "fzop")
        return 12
    else if (prefix = "ter")
        return 7
    else if (prefix = "tk")
        return 6
    else if (prefix = "arg")
        return 4
    else if (prefix = "uk")
        return 9
    else if (prefix = "vv")
        return 5
    else if (prefix = "koap")
        return 8
    else if (prefix = "pdd")
        return 10
    else if (prefix = "oruzh")
        return 3
    else if (prefix = "upk")
        return 41
    else if (prefix = "kas")
        return 4
    else if (prefix = "fsb")
        return 3
    else if (prefix = "fsin")
        return 2
    else if (prefix = "vs")
        return 2
    else if (prefix = "sud")
        return 2
    else if (prefix = "ord")
        return 2
    else if (prefix = "gt")
        return 2
    return 0
}

LawSearch_AddDocFromCorpus(docCode, docName, prefix)
{
    text := LawCorpus_GetText(prefix)
    if (text = "")
        return false
    LawSearch_ParseAndAdd(docCode, docName, text)
    return true
}

LawSearch_AddDocFromPages(docCode, docName, prefix, pageCount)
{
    text := ""
    Loop %pageCount%
    {
        fnName := "LawText_" . prefix . A_Index
        if IsFunc(fnName)
        {
            fn := Func(fnName)
            text .= fn.Call() . "`r`n"
        }
    }
    LawSearch_ParseAndAdd(docCode, docName, text)
}

LawSearch_AuditIndex()
{
    global LawSearchDocCatalog, SearchIndexCounts

    LawSearch_Init()
    failures := []
    pageCount := 0
    headingCount := 0
    docCount := IsObject(LawSearchDocCatalog) ? LawSearchDocCatalog.Length() : 0
    if (docCount != 20)
        failures.Push("Ожидалось 20 документов, найдено " . docCount)

    Loop % docCount
    {
        doc := LawSearchDocCatalog[A_Index]
        if (!SearchIndexCounts.HasKey(doc.Code) || SearchIndexCounts[doc.Code] < 1)
            failures.Push(doc.Code . ": индекс пуст")
        corpusText := LawCorpus_GetText(doc.Prefix)
        if (corpusText = "")
        {
            failures.Push(doc.Code . ": официальный corpus недоступен")
            continue
        }
        pages := LawCorpus_PageCount(doc.Prefix)
        if (pages < 1)
            failures.Push(doc.Code . ": не объявлены страницы")
        pageCount += pages
        Loop, Parse, corpusText, `n, `r
        {
            line := Trim(A_LoopField)
            if !LawSearch_GetArticleId(line, articleId)
                continue
            headingCount++
            if !LawSearch_IndexHasArticle(doc.Code, articleId)
                failures.Push(doc.Code . ": заголовок статьи " . articleId . " не попал в индекс")
        }
    }
    return {Ok: failures.Length() = 0, Documents: docCount, Pages: pageCount
        , Headings: headingCount, Failures: failures}
}

LawSearch_IndexHasArticle(docCode, articleId)
{
    global SearchIndex
    wanted := LawSearch_NormalizeNumber(articleId)
    Loop % SearchIndex.Length()
    {
        item := SearchIndex[A_Index]
        if (item.DocCode = docCode && LawSearch_NormalizeNumber(item.Article) = wanted)
            return true
    }
    return false
}

LawSearch_ParseAndAdd(docCode, docName, text)
{
    logical := []

    Loop, Parse, text, `n, `r
    {
        raw := RTrim(A_LoopField)
        line := Trim(raw)
        if (line = "")
            continue

        if (SubStr(raw, 1, 4) = "    " && logical.Length() > 0 && !LawSearch_IsStructuralLine(line))
            logical[logical.Length()] := logical[logical.Length()] . " " . line
        else
            logical.Push(line)
    }

    chapter := ""
    chapterTitle := ""
    article := ""
    articleTitle := ""
    part := ""
    partTitle := ""
    point := ""
    pointTitle := ""
    subPoint := ""
    subPointTitle := ""

    currentLevel := ""
    currentId := ""
    currentTitle := ""
    currentText := ""
    explainActive := 0
    explainSubSeen := 0
    explainAfterList := 0
    explainArticle := ""
    explainPart := ""
    explainPoint := ""
    subListActive := 0
    subListSubSeen := 0
    subListAfterList := 0
    subListArticle := ""
    subListPart := ""
    subListPoint := ""

    Loop % logical.Length()
    {
        line := logical[A_Index]
        kind := ""
        id := ""
        title := ""
        body := ""

        if (!explainActive && !subListActive && currentLevel = "point" && LawSearch_TextEndsWithColon(currentText) && RegExMatch(line, "^\s*[0-9]+\)\s+"))
        {
            subListActive := 1
            subListSubSeen := 0
            subListAfterList := 0
            subListArticle := article
            subListPart := part
            subListPoint := point
        }

        forceSubPoint := ((explainActive && !explainAfterList) || (subListActive && !subListAfterList))
        if (LawSearch_ParseStructureLine(line, kind, id, title, body, article, 0, part, point, forceSubPoint))
        {
            LawSearch_FlushStructuredItem(docCode, docName, currentId, currentTitle, currentText, chapter, chapterTitle, article, articleTitle, part, partTitle, point, pointTitle, subPoint, subPointTitle, currentLevel)
            currentLevel := ""
            currentId := ""
            currentTitle := ""
            currentText := ""

            if (kind = "chapter")
            {
                chapter := id
                chapterTitle := title
                article := ""
                articleTitle := ""
                part := ""
                partTitle := ""
                point := ""
                pointTitle := ""
                subPoint := ""
                subPointTitle := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
                continue
            }
            else if (kind = "article")
            {
                article := id
                articleTitle := title
                part := ""
                partTitle := ""
                point := ""
                pointTitle := ""
                subPoint := ""
                subPointTitle := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "part")
            {
                part := id
                partTitle := title
                point := ""
                pointTitle := ""
                subPoint := ""
                subPointTitle := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "point")
            {
                point := id
                pointTitle := title
                subPoint := ""
                subPointTitle := ""
                explainActive := 0
                explainSubSeen := 0
                explainAfterList := 0
                subListActive := 0
                subListSubSeen := 0
                subListAfterList := 0
            }
            else if (kind = "subpoint")
            {
                if (explainActive)
                {
                    if (explainArticle != "")
                        article := explainArticle
                    if (explainPart != "")
                    {
                        part := explainPart
                        if (partTitle = "" || partTitle != "Ч. " . part)
                            partTitle := "Ч. " . part
                    }
                    if (explainPoint != "")
                    {
                        point := explainPoint
                        if (pointTitle = "" || pointTitle != "П. " . point)
                            pointTitle := "П. " . point
                    }
                    explainSubSeen := 1
                }
                if (subListActive)
                {
                    if (subListArticle != "")
                        article := subListArticle
                    if (subListPart != "")
                    {
                        part := subListPart
                        if (partTitle = "" || partTitle != "Ч. " . part)
                            partTitle := "Ч. " . part
                    }
                    if (subListPoint != "")
                    {
                        point := subListPoint
                        if (pointTitle = "" || pointTitle != "П. " . point)
                            pointTitle := "П. " . point
                    }
                    subListSubSeen := 1
                }
                subPoint := id
                subPointTitle := title
            }

            currentLevel := kind
            currentId := id
            currentTitle := title
            currentText := body
            continue
        }

        if (LawSearch_DetectPointExplanation(line, expArticle, expPart, expPoint))
        {
            explainActive := 1
            explainSubSeen := 0
            explainAfterList := 0
            explainArticle := expArticle
            explainPart := expPart
            explainPoint := expPoint
            if (expArticle != "")
                article := expArticle
            if (expPart != "")
            {
                part := expPart
                if (partTitle = "")
                    partTitle := "Ч. " . part
            }
            if (expPoint != "")
            {
                point := expPoint
                if (pointTitle = "")
                    pointTitle := "П. " . point
            }
        }
        else
        {
            if (explainActive && explainSubSeen)
                explainAfterList := 1
            if (subListActive && subListSubSeen)
                subListAfterList := 1
        }

        if (currentTitle = "")
        {
            currentLevel := "text"
            currentTitle := chapterTitle != "" ? chapterTitle : line
            currentId := chapter != "" ? chapter : ""
            currentText := currentTitle = line ? "" : line . "`r`n"
        }
        else
        {
            currentText .= line . "`r`n"
        }
    }

    LawSearch_FlushStructuredItem(docCode, docName, currentId, currentTitle, currentText, chapter, chapterTitle, article, articleTitle, part, partTitle, point, pointTitle, subPoint, subPointTitle, currentLevel)
}

LawSearch_FlushStructuredItem(docCode, docName, itemId, title, text, chapter, chapterTitle, article, articleTitle, part, partTitle, point, pointTitle, subPoint, subPointTitle, level)
{
    title := Trim(title)
    text := Trim(text, " `t`r`n")
    if (title = "" && text = "")
        return
    if (title = "")
        title := SubStr(text, 1, 80)
    LawSearch_Add(docCode, docName, itemId, title, text, chapter, chapterTitle, article, articleTitle, part, partTitle, point, pointTitle, subPoint, subPointTitle, level)
}

LawSearch_IsStructuralLine(line)
{
    kind := ""
    id := ""
    title := ""
    body := ""
    return LawSearch_ParseStructureLine(line, kind, id, title, body, "")
}

LawSearch_ParseStructureLine(line, ByRef kind, ByRef id, ByRef title, ByRef body, currentArticle := "", numericHasChildren := 0, currentPart := "", currentPoint := "", forceParenSubPoint := 0)
{
    line := Trim(line)
    kind := ""
    id := ""
    title := ""
    body := ""

    if (RegExMatch(line, "^\s*(Раздел|раздел|РАЗДЕЛ|Глава|глава|ГЛАВА)\s+([0-9]+(\.[0-9]+)*)?\s*[\.:\-]?\s*(.*)$", m))
    {
        kind := "chapter"
        id := m2
        title := LawSearch_MakeHierarchyTitle("Гл.", id, m4)
        return true
    }

    if (RegExMatch(line, "^\s*(Статья|статья|СТАТЬЯ|Ст\.|ст\.|СТ\.)\s*([0-9]+(\.[0-9]+)*)\.?\s*(.*)$", m))
    {
        kind := "article"
        id := m2
        title := LawSearch_MakeHierarchyTitle("Ст.", id, m4)
        return true
    }

    if (RegExMatch(line, "^\s*(Часть|часть|ЧАСТЬ|ч\.|Ч\.)\s*([0-9]+(\.[0-9]+)*)\.?\s*(.*)$", m))
    {
        kind := "part"
        id := m2
        body := Trim(m4)
        title := LawSearch_MakeHierarchyTitle("Ч.", id, "")
        return true
    }

    if (RegExMatch(line, "i)^\s*(Подпункт|подпункт)\s*([0-9]+(\.[0-9]+)*|[a-zа-яё])\.?\s*(.*)$", m))
    {
        kind := "subpoint"
        id := m2
        body := Trim(m4)
        title := LawSearch_MakeHierarchyTitle("ПП.", id, "")
        return true
    }

    if (RegExMatch(line, "^\s*(Пункт|пункт|ПУНКТ|п\.|П\.)\s*([0-9]+(\.[0-9]+)*)\.?\s*(.*)$", m))
    {
        kind := "point"
        id := m2
        body := Trim(m4)
        title := LawSearch_MakeHierarchyTitle("П.", id, "")
        return true
    }

    if (RegExMatch(line, "^\s*([0-9]+(\.[0-9]+)*)([\.)])?\s+(.+)$", m))
    {
        id := m1
        delim := m3
        body := Trim(m4)
        if (LawSearch_IsNumericAmountLine(id, body))
            return false

        levelCount := LawSearch_NumberLevelCount(id)
        if (delim = ")")
        {
            if (forceParenSubPoint)
                kind := "subpoint"
            else
                kind := "point"
        }
        else if (levelCount = 1 && currentArticle != "")
            kind := "part"
        else if (levelCount >= 3 && currentArticle != "")
            kind := "subpoint"
        else
            kind := "point"

        if (kind = "part")
            title := LawSearch_MakeHierarchyTitle("Ч.", id, "")
        else if (kind = "subpoint")
            title := LawSearch_MakeHierarchyTitle("ПП.", id, "")
        else
            title := LawSearch_MakeHierarchyTitle("П.", id, "")
        return true
    }

    if (RegExMatch(line, "i)^\s*([a-zа-яё])\)\s+(.+)$", m))
    {
        kind := "subpoint"
        id := m1
        body := Trim(m2)
        title := LawSearch_MakeHierarchyTitle("ПП.", id, "")
        return true
    }

    return false
}

LawSearch_MakeHierarchyTitle(prefix, id, caption)
{
    caption := Trim(caption)
    if (id != "")
        out := prefix . " " . id
    else
        out := prefix
    if (caption != "")
        out .= ". " . caption
    return out
}

LawSearch_DetectPointExplanation(line, ByRef outArticle, ByRef outPart, ByRef outPoint)
{
    outArticle := ""
    outPart := ""
    outPoint := ""
    if (RegExMatch(line, "i)Разъяснения\s+по\s+пункту\s+([0-9]+)\s+части\s+([0-9]+)\s+статьи\s+([0-9]+(\.[0-9]+)*)", m))
    {
        outPoint := m1
        outPart := m2
        outArticle := m3
        return true
    }
    return false
}

LawSearch_TextEndsWithColon(text)
{
    text := Trim(text)
    if (text = "")
        return false
    return RegExMatch(text, ":\s*$")
}

LawSearch_NumberLevelCount(id)
{
    if (id = "")
        return 0
    parts := StrSplit(id, ".")
    return parts.Length()
}

LawSearch_NumericLineHasNestedChildren(ByRef logical, lineIndex, line, currentArticle)
{
    if (currentArticle = "")
        return 0
    line := Trim(line)
    if (!RegExMatch(line, "^\s*([0-9]+)\.?\s+", m))
        return 0

    parentId := m1
    parentNum := parentId + 0
    nextSame := parentNum + 1
    childPrefix := parentId . "."
    total := logical.Length()
    idx := lineIndex + 1
    while (idx <= total)
    {
        nextLine := Trim(logical[idx])
        if (nextLine = "")
        {
            idx++
            continue
        }
        if (RegExMatch(nextLine, "i)^\s*(Раздел|Глава|Статья|Ст\.)\s+"))
            break
        if (RegExMatch(nextLine, "i)^\s*(Часть|ч\.|Ч\.)\s+"))
            break
        if (RegExMatch(nextLine, "^\s*" . childPrefix . "[0-9]+(\.[0-9]+)*[\.)]?\s+"))
            return 1
        if (RegExMatch(nextLine, "^\s*([0-9]+)\.?\s+", n))
        {
            nextNum := n1 + 0
            if (nextNum >= nextSame)
                break
        }
        idx++
    }
    return 0
}

LawSearch_IsNumericAmountLine(id, body)
{
    if (RegExMatch(id, "\.[0-9]{3,}"))
        return true
    if (RegExMatch(body, "i)^(руб|рубл)"))
        return true
    return false
}

LawSearch_FlushItem(docCode, docName, itemId, title, text)
{
    title := Trim(title)
    text := Trim(text, " `t`r`n")
    if (title = "" && text = "")
        return
    if (title = "")
        title := SubStr(text, 1, 80)
    LawSearch_Add(docCode, docName, itemId, title, text)
}

LawSearch_IsMajorHeading(line)
{
    return RegExMatch(line, "i)^\s*(Раздел|Глава|Часть)\s+")
}

LawSearch_IsItemStart(line, hasArticles)
{
    return LawSearch_IsStructuralLine(line)
}

LawSearch_GetArticleId(line, ByRef outId)
{
    if (RegExMatch(line, "^\s*(Статья|статья|СТАТЬЯ|Ст\.|ст\.|СТ\.)\s*([0-9]+(\.[0-9]+)*)", m))
    {
        outId := m2
        return true
    }
    return false
}

LawSearch_GetPointId(line, ByRef outId)
{
    if (RegExMatch(line, "i)^\s*(Пункт|пункт|п\.)\s+([0-9]+(\.[0-9]+)*)", m))
    {
        outId := m2
        return true
    }
    if (RegExMatch(line, "^\s*([0-9]+(\.[0-9]+)*)[\.)]", m))
    {
        outId := m1
        return true
    }
    if (RegExMatch(line, "^\s*([a-zа-яё])\)", m))
    {
        outId := m1
        return true
    }
    return false
}

LawSearch_Add(docCode, docName, itemId, title, itemText, chapter := "", chapterTitle := "", article := "", articleTitle := "", part := "", partTitle := "", point := "", pointTitle := "", subPoint := "", subPointTitle := "", level := "")
{
    global SearchIndex, SearchIndexCounts

    docCode := Trim(docCode)
    StringUpper, docCode, docCode

    if (!IsObject(SearchIndex))
        SearchIndex := []
    if (!IsObject(SearchIndexCounts))
        SearchIndexCounts := {}

    meta := LawSearch_GetDocMeta(docCode)
    if (IsObject(meta))
        docName := meta.Name
    title := RegExReplace(Trim(title), "\s+", " ")
    itemText := Trim(itemText, " `t`r`n")
    if (itemId = "")
        itemId := SearchIndex.Length() + 1

    searchTitle := LawSearch_BuildSearchTitle(title, chapterTitle, articleTitle, partTitle, pointTitle, subPointTitle)
    item := {DocCode: docCode, DocName: docName, ItemId: itemId, Title: title, Text: itemText}
    item.DocShort := IsObject(meta) ? meta.Short : docName
    item.DocAliases := IsObject(meta) ? meta.Aliases : ""
    item.DocOrder := IsObject(meta) && meta.HasKey("Order") ? meta.Order : 9999
    item.IndexOrder := SearchIndex.Length() + 1
    item.Level := level
    item.Chapter := chapter
    item.ChapterTitle := chapterTitle
    item.Article := article
    item.ArticleTitle := articleTitle
    item.Part := part
    item.PartTitle := partTitle
    item.Point := point
    item.PointTitle := pointTitle
    item.SubPoint := subPoint
    item.SubPointTitle := subPointTitle
    item.NormId := LawSearch_Normalize(itemId)
    item.NormTitle := LawSearch_Normalize(searchTitle)
    item.NormBody := LawSearch_Normalize(itemText)
    item.TitleTokens := LawSearch_BuildTokenSet(item.NormTitle)
    item.BodyTokens := LawSearch_BuildTokenSet(item.NormBody)
    item.TitleStems := LawSearch_BuildStemSet(item.TitleTokens)
    item.BodyStems := LawSearch_BuildStemSet(item.BodyTokens)
    SearchIndex.Push(item)

    if (!SearchIndexCounts.HasKey(docCode))
        SearchIndexCounts[docCode] := 0
    SearchIndexCounts[docCode] := SearchIndexCounts[docCode] + 1
}

LawSearch_BuildSearchTitle(title, chapterTitle, articleTitle, partTitle, pointTitle, subPointTitle)
{
    out := ""
    LawSearch_AppendUniqueTitle(out, chapterTitle)
    LawSearch_AppendUniqueTitle(out, articleTitle)
    LawSearch_AppendUniqueTitle(out, partTitle)
    LawSearch_AppendUniqueTitle(out, pointTitle)
    LawSearch_AppendUniqueTitle(out, subPointTitle)
    LawSearch_AppendUniqueTitle(out, title)
    return out
}

LawSearch_AppendUniqueTitle(ByRef out, value)
{
    value := RegExReplace(Trim(value), "\s+", " ")
    if (value = "")
        return
    if (InStr("`n" . out . "`n", "`n" . value . "`n"))
        return
    if (out != "")
        out .= "`n"
    out .= value
}

LawSearch_Normalize(text)
{
    out := text
    StringReplace, out, out, Ё, Е, All
    StringReplace, out, out, ё, е, All
    StringLower, out, out
    out := RegExReplace(out, "[^0-9A-Za-zА-Яа-я\.]+", " ")
    out := RegExReplace(out, "(?<!\d)\.|\.(?!\d)", " ")
    out := RegExReplace(out, "\s+", " ")
    return Trim(out)
}

LawSearch_GetItemTitle(item)
{
    if (!IsObject(item))
        return ""
    if (item.HasKey("Title"))
        return item.Title
    return ""
}

LawSearch_GetItemBodyText(item)
{
    if (!IsObject(item))
        return ""

    body := ""
    if (item.HasKey("Text"))
        body .= " " . item.Text
    if (item.HasKey("Body"))
        body .= " " . item.Body
    if (item.HasKey("Content"))
        body .= " " . item.Content
    if (item.HasKey("Raw"))
        body .= " " . item.Raw
    if (Trim(body) = "" && item.HasKey("SearchText"))
        body .= " " . item.SearchText
    return Trim(body, " `t`r`n")
}

LawSearch_GetItemNormTitle(item)
{
    if (!IsObject(item))
        return ""
    if (item.HasKey("NormTitle"))
        return item.NormTitle
    return LawSearch_Normalize(LawSearch_GetItemTitle(item))
}

LawSearch_GetItemNormBody(item)
{
    if (!IsObject(item))
        return ""
    if (item.HasKey("NormBody"))
        return item.NormBody
    if (item.HasKey("NormText"))
        return item.NormText
    return LawSearch_Normalize(LawSearch_GetItemBodyText(item))
}

LawSearch_SelectMode(docCode, docName, showNotice := true)
{
    global SearchModeActive, SearchDoc, SearchDocName, SearchResults, SearchCurrentIndex, SearchCurrentPart, SearchGuiVisible

    if !LawSearch_Init()
        return {Results: [], Checked: 0, Passed: 0, Busy: 1}
    docCode := Trim(docCode)
    StringUpper, docCode, docCode
    SearchModeActive := 1
    SearchDoc := docCode
    SearchDocName := docName
    SearchResults := []
    SearchCurrentIndex := 0
    SearchCurrentPart := 1
    SearchGuiVisible := 0
    Gui, 16:Destroy
    if (showNotice)
        LawSearch_ShowNotice("Поиск по " . docName . " активен. Введите запрос в чат и нажмите назначенную клавишу поиска")
}
LawSearch_ModeHotstring(docCode, docName)
{
    LawSearch_SelectMode(docCode, docName)
}

LawSearch_WaitForQuery()
{
    LawSearch_ShowNotice("Введите запрос в чат и нажмите назначенную клавишу поиска")
}
LawSearch_RunActive(query)
{
    global SearchModeActive, SearchDoc, SearchDocName, SearchResults, SearchGuiVisible

    if (!SearchModeActive || SearchDoc = "")
    {
        LawSearch_ShowNotice("Сначала выберите материал: !пкоап / !пук / !пвсе")
        return
    }

    query := LawSearch_CleanQuery(query)
    if (query = "")
    {
        SearchResults := []
        SearchGuiVisible := 0
        Gui, 16:Destroy
        LawSearch_ShowNotice("Введите запрос")
        return
    }
    if (LawSearch_IsModeCommand(query))
    {
        LawSearch_ShowNotice("Это команда поиска. Введите запрос в чат")
        return
    }

    LawSearch_ShowNotice("Ищу по " . SearchDocName . ": " . query)
    LawSearch_Run(SearchDoc, query)
}

LawSearch_RunActiveFromClipboard()
{
    LawSearch_RunActiveFromChat()
}

LawSearch_RunActiveFromChat()
{
    global SearchModeActive, SearchDoc, SearchResults, SearchGuiVisible

    if (!SearchModeActive || SearchDoc = "")
    {
        LawSearch_ShowNotice("Сначала выберите материал: !пкоап / !пук / !пвсе")
        return
    }

    if (!IsFunc("LawSearch_CaptureAndCancelChat"))
    {
        LawSearch_ShowNotice("Не удалось подключить безопасный захват запроса")
        return
    }

    captureFn := Func("LawSearch_CaptureAndCancelChat")
    capture := captureFn.Call()
    if !IsObject(capture) || !capture.Ok
    {
        reason := IsObject(capture) ? capture.Reason : "Неизвестная ошибка захвата."
        LawSearch_DebugQuery("", "", "", "chat-capture-failed")
        LawSearch_ShowNotice(reason . " Поиск не запущен.")
        return
    }

    rawQuery := capture.Query
    if (rawQuery = "")
    {
        LawSearch_DebugQuery(rawQuery, "", "", "active-chat-empty")
        LawSearch_ShowNotice("Введите запрос в игровой чат и используйте клавишу запуска поиска")
        return
    }

    query := LawSearch_CleanQuery(rawQuery)
    normQuery := LawSearch_Normalize(query)
    LawSearch_DebugQuery(rawQuery, query, normQuery, "active-chat")
    if (query = "")
    {
        SearchResults := []
        SearchGuiVisible := 0
        Gui, 16:Destroy
        LawSearch_ShowNotice("Введите запрос")
        return
    }
    if (LawSearch_IsModeCommand(query))
    {
        LawSearch_ShowNotice("Это команда выбора раздела. Введите поисковый запрос")
        return
    }

    LawSearch_RunActive(query)
}

LawSearch_CleanQuery(query)
{
    query := LawSearch_ExtractQueryText(query)
    query := LawSearch_SanitizeQueryText(query)
    while (SubStr(query, 1, 1) = "!" || SubStr(query, 1, 1) = "/")
        query := Trim(SubStr(query, 2))
    query := LawSearch_SanitizeQueryText(query)
    return query
}

LawSearch_ExtractQueryText(raw)
{
    raw := "" . raw
    StringReplace, raw, raw, `r`n, `n, All
    StringReplace, raw, raw, `r, `n, All

    lines := StrSplit(raw, "`n")
    candidate := ""
    Loop % lines.Length()
    {
        idx := lines.Length() - A_Index + 1
        line := LawSearch_SanitizeQueryText(lines[idx])
        if (line != "")
        {
            candidate := line
            break
        }
    }
    if (candidate = "")
        candidate := raw

    ; Hotstring режима может оставить в поле ! перед самим запросом.
    bangPos := LawSearch_LastCharPos(candidate, "!")
    if (bangPos > 0 && bangPos < StrLen(candidate))
        candidate := SubStr(candidate, bangPos + 1)
    return LawSearch_SanitizeQueryText(candidate)
}

LawSearch_SanitizeQueryText(text)
{
    text := "" . text
    nbsp := Chr(160)
    StringReplace, text, text, %nbsp%, %A_Space%, All
    StringReplace, text, text, `t, %A_Space%, All
    StringReplace, text, text, `r, %A_Space%, All
    StringReplace, text, text, `n, %A_Space%, All
    text := RegExReplace(text, "[\x00-\x1F]+", " ")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

LawSearch_LastCharPos(text, needle)
{
    lastPos := 0
    startPos := 1
    needleLen := StrLen(needle)
    if (needleLen < 1)
        return 0

    Loop
    {
        pos := InStr(text, needle, false, startPos)
        if (!pos)
            break
        lastPos := pos
        startPos := pos + needleLen
    }
    return lastPos
}

LawSearch_DebugQuery(raw, cleaned, normalized, source)
{
    global LawSearchDebug

    if (LawSearchDebug = "")
        LawSearchDebug := 1
    if (!LawSearchDebug)
        return

    FormatTime, stamp,, yyyy-MM-dd HH:mm:ss
    logFile := A_ScriptDir . "\law_search_debug.log"
    entry := "---- " . stamp . " ----`r`n"
    entry .= "source=" . source . "`r`n"
    entry .= "raw_len=" . StrLen(raw) . "`r`n"
    entry .= "raw=[" . LawSearch_DebugEscape(raw) . "]`r`n"
    entry .= "raw_codes=" . LawSearch_DebugCharCodes(raw, 10) . "`r`n"
    entry .= "cleaned_len=" . StrLen(cleaned) . "`r`n"
    entry .= "cleaned=[" . LawSearch_DebugEscape(cleaned) . "]`r`n"
    entry .= "cleaned_codes=" . LawSearch_DebugCharCodes(cleaned, 10) . "`r`n"
    entry .= "normalized=[" . normalized . "]`r`n"
    entry .= "words=[" . LawSearch_DebugWords(normalized) . "]`r`n`r`n"
    RotateOwnedLog(logFile)
    FileAppend, %entry%, %logFile%
}

LawSearch_DebugEscape(text)
{
    out := "" . text
    StringReplace, out, out, `r, \r, All
    StringReplace, out, out, `n, \n, All
    StringReplace, out, out, `t, \t, All
    if (StrLen(out) > 240)
        out := SubStr(out, 1, 240) . "...(trimmed)"
    return out
}

LawSearch_DebugCharCodes(text, maxChars)
{
    out := ""
    len := StrLen(text)
    if (len > maxChars)
        len := maxChars
    Loop % len
    {
        if (out != "")
            out .= ","
        out .= Asc(SubStr(text, A_Index, 1))
    }
    return out
}

LawSearch_DebugWords(normalized)
{
    words := LawSearch_GetMeaningfulWords(normalized)
    out := ""
    if (!IsObject(words))
        return out
    Loop % words.Length()
    {
        if (out != "")
            out .= ","
        out .= words[A_Index]
    }
    return out
}

LawSearch_IsModeCommand(query)
{
    cmd := LawSearch_Normalize(query)
    if (cmd = "")
        return false
    if (cmd = "пвсе" || cmd = "пкоап" || cmd = "пук" || cmd = "пупк" || cmd = "ппдд")
        return true
    if (cmd = "пфзоп" || cmd = "птк" || cmd = "птер" || cmd = "парг" || cmd = "пву")
        return true
    if (cmd = "пвв" || cmd = "поружие" || cmd = "пкон" || cmd = "пнайти")
        return true
    if (cmd = "пкас" || cmd = "пфсб" || cmd = "пфсин" || cmd = "пвс" || cmd = "псуд" || cmd = "порд" || cmd = "пгт")
        return true
    return false
}

LawSearch_Run(docCode, query)
{
    global SearchResults, SearchCurrentIndex, SearchCurrentPart, SearchGuiVisible, SearchLastQuery, SearchModeActive
    global SearchLastChecked, SearchLastPassed, SearchMinScore, SearchLastPossible

    if !LawSearch_Init()
        return {Results: [], Checked: 0, Passed: 0, Busy: 1}
    docCode := Trim(docCode)
    StringUpper, docCode, docCode
    if (docCode = "")
    {
        LawSearch_ShowNotice("Сначала выберите материал: !пкоап / !пук / !пвсе")
        return
    }
    query := LawSearch_CleanQuery(query)
    if (query = "")
    {
        SearchResults := []
        SearchGuiVisible := 0
        Gui, 16:Destroy
        LawSearch_ShowNotice("Введите запрос")
        return
    }

    SearchModeActive := 1
    SearchLastQuery := query
    package := LawSearch_Find(docCode, query, 30)
    if (package.HasKey("Busy") && package.Busy) {
        LawSearch_ShowNotice("Индекс обновляется. Повторите запрос.")
        return
    }
    if (package.HasKey("MissingDocuments") && package.MissingDocuments.Length())
        LawSearch_ShowNotice("Часть LAW-файлов недоступна: " . JoinStrings(package.MissingDocuments, ", "))
    SearchResults := package.Results
    SearchLastChecked := package.Checked
    SearchLastPassed := package.Passed
    SearchMinScore := package.MinScore
    SearchLastPossible := package.Possible
    SearchCurrentIndex := 1
    SearchCurrentPart := 1

    if (!IsObject(SearchResults) || SearchResults.Length() = 0)
    {
        SearchGuiVisible := 0
        Gui, 16:Destroy
        LawSearch_ShowNotice("Подходящие статьи не найдены. Укажите закон, статью или другие ключевые слова.")
        return
    }

    if (SearchLastPossible)
        LawSearch_ShowNotice("Найдены возможные совпадения.")
    Search_ShowCurrentResult()
}

LawSearch_Score(item, query)
{
    q := LawSearch_ParseQuery(query)
    detail := LawSearch_ScoreParsed(item, q)
    return IsObject(detail) ? detail.Score : 0
}

LawSearch_MinScore(query)
{
    return LawSearch_MinScoreParsed(LawSearch_ParseQuery(query))
}

LawSearch_GetMeaningfulWords(q)
{
    parsed := LawSearch_ParseQuery(q)
    out := []
    Loop % parsed.Tokens.Length()
        out.Push(parsed.Tokens[A_Index].Word)
    return out
}

LawSearch_IsStopWord(word)
{
    return InStr("|и|в|во|на|по|с|со|к|ко|от|до|за|из|у|о|об|обо|а|но|или|либо|при|для|без|над|под|не|ни|же|то|это|его|ее|их|ли|бы|кто|что|как|где|когда|какой|какая|какие|можно|разрешено|будет|есть|считается|два|раза|одно|один|одного|одну|одной|тот|самый|настоящий|настоящего|", "|" . word . "|") > 0
}

LawSearch_WordMatchScore(text, word, exactScore, stemScore)
{
    if (text = "" || word = "")
        return 0

    if (LawSearch_HasExactWord(text, word))
        return exactScore

    if (StrLen(word) < 4)
        return 0

    if (LawSearch_HasStemWord(text, word))
        return stemScore

    stems := LawSearch_BuildSafeStems(word)
    Loop % stems.Length()
    {
        stem := stems[A_Index]
        if (LawSearch_HasStemWord(text, stem))
            return stemScore
    }

    return 0
}

LawSearch_HasExactWord(text, word)
{
    return InStr(" " . text . " ", " " . word . " ")
}

LawSearch_HasStemWord(text, stem)
{
    stem := Trim(stem)
    if (StrLen(stem) < 4)
        return false

    parts := StrSplit(text, A_Space)
    stemLen := StrLen(stem)
    Loop % parts.Length()
    {
        token := parts[A_Index]
        if (token = "")
            continue
        if (SubStr(token, 1, stemLen) = stem)
            return true
    }
    return false
}

LawSearch_BuildSafeStems(word)
{
    stems := []
    len := StrLen(word)
    if (len < 5 || RegExMatch(word, "^\d+$"))
        return stems

    if (len > 6)
        LawSearch_AddStem(stems, SubStr(word, 1, len - 2))
    if (len > 7)
        LawSearch_AddStem(stems, SubStr(word, 1, len - 3))

    endings := "ость,ости,остью,ного,ному,ными,лого,ого,его,ому,ему,ыми,ими,ями,ами,ая,ое,ые,ый,ий,ой,ым,им,ых,их,ую,юю,ью,ие,ия,ь"
    endingList := StrSplit(endings, ",")
    Loop % endingList.Length()
    {
        ending := endingList[A_Index]
        endingLen := StrLen(ending)
        if (len > endingLen && SubStr(word, len - endingLen + 1) = ending)
            LawSearch_AddStem(stems, SubStr(word, 1, len - endingLen))
    }

    return stems
}

LawSearch_AddStem(ByRef stems, stem)
{
    stem := Trim(stem)
    if (StrLen(stem) < 4)
        return

    Loop % stems.Length()
    {
        if (stems[A_Index] = stem)
            return
    }
    stems.Push(stem)
}

LawSearch_InsertResult(result)
{
    global SearchResults
    LawSearch_InsertInto(SearchResults, result, 15)
}

Search_ShowNextResult()
{
    global SearchResults, SearchCurrentIndex, SearchCurrentPart

    if (!IsObject(SearchResults) || SearchResults.Length() = 0)
        return

    partCount := LawSearch_GetCurrentPartCount()
    if (SearchCurrentPart < partCount)
        SearchCurrentPart++
    else
    {
        SearchCurrentPart := 1
        SearchCurrentIndex++
        if (SearchCurrentIndex > SearchResults.Length())
            SearchCurrentIndex := 1
    }
    Search_ShowCurrentResult()
}

Search_ShowPrevResult()
{
    global SearchResults, SearchCurrentIndex, SearchCurrentPart

    if (!IsObject(SearchResults) || SearchResults.Length() = 0)
        return

    if (SearchCurrentPart > 1)
        SearchCurrentPart--
    else
    {
        SearchCurrentIndex--
        if (SearchCurrentIndex < 1)
            SearchCurrentIndex := SearchResults.Length()
        SearchCurrentPart := LawSearch_GetCurrentPartCount()
    }
    Search_ShowCurrentResult()
}

LawSearch_GetShellAccentColor()
{
    global CustomBorderColor

    accentColor := CustomBorderColor
    if (accentColor = "")
        accentColor := "BFD7FF"
    return accentColor
}

LawSearch_GetShellAlpha()
{
    global LawGuiTransparency

    alpha := LawGuiTransparency
    if (alpha = "")
        alpha := 228
    if (alpha < 200)
        alpha := 200
    if (alpha > 235)
        alpha := 235
    return alpha
}

LawSearch_ApplyShellRound(hwnd)
{
    global UIRoundness

    if (!hwnd || !IsFunc("ApplyRoundedCorners"))
        return

    radius := UIRoundness
    if (radius = "")
        radius := 18
    if (radius < 0)
        radius := 0
    if (radius > 45)
        radius := 45

    roundFn := Func("ApplyRoundedCorners")
    roundFn.Call(hwnd, radius)
}

Search_Close(showNotice := 1)
{
    global SearchModeActive, SearchGuiVisible, SearchResults, SearchCurrentIndex, SearchCurrentPart

    SearchModeActive := 0
    SearchGuiVisible := 0
    SearchResults := []
    SearchCurrentIndex := 0
    SearchCurrentPart := 1
    Gui, 16:Destroy
    Gui, 17:Destroy
    if (showNotice)
        LawSearch_ShowNotice("Поиск закрыт")
}

Search_ShowCurrentResult()
{
    global SearchResults, SearchCurrentIndex, SearchCurrentPart, SearchGuiVisible, SearchLastQuery, SearchDoc
    global SearchLastChecked, SearchLastPassed, SearchMinScore
    global LawGuiTextColor, LawGuiBgColor

    if (!IsObject(SearchResults) || SearchResults.Length() = 0)
        return

    if (SearchCurrentIndex < 1)
        SearchCurrentIndex := 1
    if (SearchCurrentIndex > SearchResults.Length())
        SearchCurrentIndex := SearchResults.Length()

    result := SearchResults[SearchCurrentIndex]
    item := result.Item
    body := LawSearch_GetResultPartText(item, SearchCurrentPart, partCount)
    headerDoc := item.DocName
    showDocLine := 0
    if (SearchDoc = "ALL")
    {
        headerDoc := "ВСЕ"
        showDocLine := 1
    }

    foundText := SearchResults.Length()
    if (SearchLastPassed > SearchResults.Length())
        foundText := SearchResults.Length() . "/" . SearchLastPassed
    header := "[" . headerDoc . "] Найдено: " . foundText . " | Результат " . SearchCurrentIndex . "/" . SearchResults.Length()
    if (partCount > 1)
        header .= " | Текст " . SearchCurrentPart . "/" . partCount

    meta := "Запрос: " . SearchLastQuery
    if (SearchMinScore != "")
        meta .= " | score>=" . SearchMinScore

    hierarchy := LawSearch_GetResultHierarchy(item, showDocLine)
    if (hierarchy = "")
        hierarchy := item.Title

    textColor := LawGuiTextColor
    if (textColor = "")
        textColor := "FFFFFF"
    bgColor := LawGuiBgColor
    if (bgColor = "")
        bgColor := "000000"
    accentColor := LawSearch_GetShellAccentColor()
    alpha := LawSearch_GetShellAlpha()

    uiScale := A_ScreenDPI / 96.0
    screenW := Floor(A_ScreenWidth / uiScale)
    screenH := Floor(A_ScreenHeight / uiScale)
    SearchGuiW := 720
    if (SearchGuiW > screenW - 20)
        SearchGuiW := screenW - 20
    SearchGuiH := 392
    if (SearchGuiH > screenH - 110)
        SearchGuiH := screenH - 110
    SearchGuiH := Max(200, Min(SearchGuiH, screenH - 40))
    SearchGuiX := 5
    SearchGuiY := A_ScreenHeight - Round(SearchGuiH * uiScale) - 20
    if (SearchGuiY < 80)
        SearchGuiY := 80
    MarginX := 14
    MarginY := 10
    ContentW := SearchGuiW - (MarginX * 2)
    HierarchyH := Min(120, Max(28, UI_MeasureTextHeight(hierarchy, ContentW, 9, 1)))
    BodyY := 76 + HierarchyH
    BodyH := Max(40, SearchGuiH - BodyY - 12)
    borderSize := 2
    rightX := SearchGuiW - borderSize
    bottomY := SearchGuiH - borderSize

    Gui, 16:Destroy
    Gui, 16:+LastFound +AlwaysOnTop -Caption +ToolWindow +Border +HwndSearchGuiHwnd
    Gui, 16:Color, %bgColor%, %bgColor%
    Gui, 16:Margin, %MarginX%, %MarginY%
    Gui, 16:Add, Progress, -Theme x0 y0 w%SearchGuiW% h%borderSize% Disabled Background%bgColor% c%accentColor%, 100
    Gui, 16:Add, Progress, -Theme x0 y%bottomY% w%SearchGuiW% h%borderSize% Disabled Background%bgColor% c%accentColor%, 100
    Gui, 16:Add, Progress, -Theme x0 y0 w%borderSize% h%SearchGuiH% Disabled Vertical Background%bgColor% c%accentColor%, 100
    Gui, 16:Add, Progress, -Theme x%rightX% y0 w%borderSize% h%SearchGuiH% Disabled Vertical Background%bgColor% c%accentColor%, 100
    Gui, 16:Font, s10 Bold c%textColor%, Segoe UI
    Gui, 16:Add, Text, xm ym w%ContentW% h24 +0x200 +0x4000 BackgroundTrans, %header%
    Gui, 16:Font, Norm s8 c%accentColor%, Segoe UI
    Gui, 16:Add, Text, xm y+0 w%ContentW% h20 +0x200 +0x4000 BackgroundTrans, %meta%
    Gui, 16:Add, Progress, -Theme xm y+4 w%ContentW% h1 Disabled Background%bgColor% c%accentColor%, 100
    Gui, 16:Font, s9 Bold c%accentColor%, Segoe UI
    Gui, 16:Add, Text, xm y+7 w%ContentW% h%HierarchyH% +Wrap BackgroundTrans, %hierarchy%
    Gui, 16:Font, s9 Norm c%textColor%, Segoe UI
    Gui, 16:Add, Edit, x14 y%BodyY% w%ContentW% h%BodyH% ReadOnly Multi +VScroll -WantTab, %body%
    Capture_BeforeShow("16")
    Gui, 16:Show, x%SearchGuiX% y%SearchGuiY% w%SearchGuiW% h%SearchGuiH% NoActivate, law search
    WinSet, Transparent, %alpha%, ahk_id %SearchGuiHwnd%
    LawSearch_ApplyShellRound(SearchGuiHwnd)
    SearchGuiVisible := 1
}

LawSearch_GetResultHierarchy(item, showDocLine := 0)
{
    out := ""
    if (!IsObject(item))
        return out
    if (showDocLine && item.HasKey("DocName"))
        LawSearch_AppendHierarchyLine(out, item.DocName)
    if (item.HasKey("ChapterTitle"))
        LawSearch_AppendHierarchyLine(out, item.ChapterTitle)
    if (item.HasKey("ArticleTitle"))
        LawSearch_AppendHierarchyLine(out, item.ArticleTitle)
    if (item.HasKey("PartTitle"))
        LawSearch_AppendHierarchyLine(out, item.PartTitle)
    if (item.HasKey("PointTitle"))
        LawSearch_AppendHierarchyLine(out, item.PointTitle)
    if (item.HasKey("SubPointTitle"))
        LawSearch_AppendHierarchyLine(out, item.SubPointTitle)
    if (out = "" && item.HasKey("Title"))
        LawSearch_AppendHierarchyLine(out, item.Title)
    return out
}

LawSearch_AppendHierarchyLine(ByRef out, value)
{
    value := RegExReplace(Trim(value), "\s+", " ")
    if (value = "")
        return
    if (InStr("`n" . out . "`n", "`n" . value . "`n"))
        return
    if (out != "")
        out .= "`r`n"
    out .= value
}

LawSearch_CountDisplayLines(text)
{
    count := 0
    Loop, Parse, text, `n, `r
    {
        if (Trim(A_LoopField) != "")
            count++
    }
    if (count < 1)
        count := 1
    return count
}


LawSearch_GetCurrentPartCount()
{
    global SearchResults, SearchCurrentIndex, SearchCurrentPart

    if (!IsObject(SearchResults) || SearchResults.Length() = 0)
        return 1
    result := SearchResults[SearchCurrentIndex]
    LawSearch_GetResultPartText(result.Item, SearchCurrentPart, partCount)
    return partCount
}

LawSearch_GetResultPartText(item, part, ByRef partCount)
{
    display := LawSearch_GetItemBodyText(item)
    if (display = "")
        display := LawSearch_GetItemTitle(item)

    lines := LawSearch_WrapDisplayText(display, 74)
    linesPerPart := 18
    partCount := Ceil(lines.Length() / linesPerPart)
    if (partCount < 1)
        partCount := 1
    if (part < 1)
        part := 1
    if (part > partCount)
        part := partCount

    startIdx := (part - 1) * linesPerPart + 1
    endIdx := startIdx + linesPerPart - 1
    out := ""
    Loop % lines.Length()
    {
        if (A_Index < startIdx)
            continue
        if (A_Index > endIdx)
            break
        if (out != "")
            out .= "`r`n"
        out .= lines[A_Index]
    }
    return out
}

LawSearch_WrapDisplayText(text, width)
{
    lines := []
    Loop, Parse, text, `n, `r
    {
        LawSearch_WrapLineToArray(A_LoopField, width, lines)
    }
    if (lines.Length() = 0)
        lines.Push("")
    return lines
}

LawSearch_WrapLineToArray(line, width, ByRef lines)
{
    line := Trim(line)
    if (line = "")
    {
        lines.Push("")
        return
    }
    if (StrLen(line) <= width)
    {
        lines.Push(line)
        return
    }

    current := ""
    words := StrSplit(line, A_Space)
    Loop % words.Length()
    {
        word := words[A_Index]
        if (word = "")
            continue
        candidate := current = "" ? word : current . " " . word
        if (StrLen(candidate) <= width)
            current := candidate
        else
        {
            if (current != "")
                lines.Push(current)
            current := word
        }
    }
    if (current != "")
        lines.Push(current)
}

LawSearch_ShowNotice(text)
{
    global LawGuiTextColor, LawGuiBgColor

    textColor := LawGuiTextColor
    if (textColor = "")
        textColor := "FFFFFF"
    bgColor := LawGuiBgColor
    if (bgColor = "")
        bgColor := "000000"
    accentColor := LawSearch_GetShellAccentColor()
    alpha := LawSearch_GetShellAlpha()

    NoticeW := 590
    if (NoticeW > A_ScreenWidth - 20)
        NoticeW := A_ScreenWidth - 20
    NoticeH := 58
    NoticeX := 5
    NoticeY := 46
    MarginX := 12
    MarginY := 8
    TextW := NoticeW - (MarginX * 2)
    borderSize := 2
    rightX := NoticeW - borderSize
    bottomY := NoticeH - borderSize

    Gui, 17:Destroy
    Gui, 17:+LastFound +AlwaysOnTop -Caption +ToolWindow +Border +HwndSearchNoticeHwnd
    Gui, 17:Color, %bgColor%, %bgColor%
    Gui, 17:Margin, %MarginX%, %MarginY%
    Gui, 17:Add, Progress, -Theme x0 y0 w%NoticeW% h%borderSize% Disabled Background%bgColor% c%accentColor%, 100
    Gui, 17:Add, Progress, -Theme x0 y%bottomY% w%NoticeW% h%borderSize% Disabled Background%bgColor% c%accentColor%, 100
    Gui, 17:Add, Progress, -Theme x0 y0 w%borderSize% h%NoticeH% Disabled Vertical Background%bgColor% c%accentColor%, 100
    Gui, 17:Add, Progress, -Theme x%rightX% y0 w%borderSize% h%NoticeH% Disabled Vertical Background%bgColor% c%accentColor%, 100
    Gui, 17:Font, s9 Bold c%textColor%, Segoe UI
    Gui, 17:Add, Text, xm ym w%TextW% h38 +0x200 BackgroundTrans, %text%
    Capture_BeforeShow("17")
    Gui, 17:Show, x%NoticeX% y%NoticeY% w%NoticeW% h%NoticeH% NoActivate, law search notice
    WinSet, Transparent, %alpha%, ahk_id %SearchNoticeHwnd%
    LawSearch_ApplyShellRound(SearchNoticeHwnd)
    SetTimer, LawSearch_HideNoticeLabel, -2400
}

; ===== Added from current build: missing legislation and compatible search index =====

kas1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kas", 1)
}

kas2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kas", 2)
}

kas3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kas", 3)
}

kas4(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("kas", 4)
}

fsb1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fsb", 1)
}

fsb2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fsb", 2)
}

fsb3(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fsb", 3)
}

fsin1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fsin", 1)
}

fsin2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("fsin", 2)
}

vs1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vs", 1)
}

vs2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("vs", 2)
}

sud1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("sud", 1)
}

sud2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("sud", 2)
}

ord1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ord", 1)
}

ord2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("ord", 2)
}

gt1(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("gt", 1)
}

gt2(State1)
{
    if (!State1)
    {
        LawGui_Close()
        return
    }
    return LawDoc_ShowPage("gt", 2)
}

LawText_kas1()
{
    return LawCorpus_GetPage("kas", 1)
}

LawText_kas2()
{
    return LawCorpus_GetPage("kas", 2)
}

LawText_kas3()
{
    return LawCorpus_GetPage("kas", 3)
}

LawText_kas4()
{
    return LawCorpus_GetPage("kas", 4)
}

LawText_fsb1()
{
    return LawCorpus_GetPage("fsb", 1)
}

LawText_fsb2()
{
    return LawCorpus_GetPage("fsb", 2)
}

LawText_fsb3()
{
    return LawCorpus_GetPage("fsb", 3)
}

LawText_fsin1()
{
    return LawCorpus_GetPage("fsin", 1)
}

LawText_fsin2()
{
    return LawCorpus_GetPage("fsin", 2)
}

LawText_vs1()
{
    return LawCorpus_GetPage("vs", 1)
}

LawText_vs2()
{
    return LawCorpus_GetPage("vs", 2)
}

LawText_sud1()
{
    return LawCorpus_GetPage("sud", 1)
}

LawText_sud2()
{
    return LawCorpus_GetPage("sud", 2)
}

LawText_ord1()
{
    return LawCorpus_GetPage("ord", 1)
}

LawText_ord2()
{
    return LawCorpus_GetPage("ord", 2)
}

LawText_gt1()
{
    return LawCorpus_GetPage("gt", 1)
}

LawText_gt2()
{
    return LawCorpus_GetPage("gt", 2)
}

LawSearch_InitCatalog()
{
    global LawSearchDocCatalog, LawSearchDocByCode

    if (IsObject(LawSearchDocCatalog) && LawSearchDocCatalog.Length() > 0)
        return

    LawSearchDocCatalog := []
    LawSearchDocByCode := {}
    LawSearch_RegisterDoc("VU", "ВУ", "Внутренний устав органов внутренних дел", "vu", "ву|внутренний устав|устав органов внутренних дел|устав овд")
    LawSearch_RegisterDoc("FP", "ФП", "Федеральное постановление", "fp", "фп|федеральное постановление|постановление")
    LawSearch_RegisterDoc("KON", "Конституция", "Конституция Нижегородской области", "kon", "конституция|конституция нижегородской области|конституция но")
    LawSearch_RegisterDoc("FZOP", "ФЗОП", "Федеральный закон «О полиции»", "fzop", "фзоп|фз о полиции|федеральный закон о полиции|закон о полиции|полиция")
    LawSearch_RegisterDoc("TER", "ФЗОТОД", "Федеральный закон «О территориях с ограниченным доступом»", "ter", "фзотод|отод|фз о территориях с ограниченным доступом|территории с ограниченным доступом|ограниченный доступ|территории")
    LawSearch_RegisterDoc("TK", "ТК", "Трудовой кодекс", "tk", "тк|трудовой кодекс|трудовое законодательство")
    LawSearch_RegisterDoc("ARG", "АРГ", "Административный регламент ГАИ", "arg", "арг|административный регламент|административный регламент гаи|регламент гаи")
    LawSearch_RegisterDoc("UK", "УК", "Уголовный кодекс", "uk", "ук|ук но|уголовный кодекс|уголовный кодекс нижегородской области")
    LawSearch_RegisterDoc("VV", "ФКЗОВВ", "Федеральный конституционный закон «О вертикали власти»", "vv", "фкзовв|фкз о вертикали власти|федеральный конституционный закон о вертикали власти|закон о вертикали|вертикаль власти|вертикаль")
    LawSearch_RegisterDoc("KOAP", "КоАП", "Кодекс об административных правонарушениях", "koap", "коап|коап но|кодекс об административных правонарушениях|административный кодекс")
    LawSearch_RegisterDoc("PDD", "ПДД", "Правила дорожного движения", "pdd", "пдд|правила дорожного движения|дорожные правила")
    LawSearch_RegisterDoc("ORUZH", "ФЗОО", "Федеральный закон «Об оружии»", "oruzh", "фзоо|фз об оружии|федеральный закон об оружии|закон об оружии|оружие")
    LawSearch_RegisterDoc("UPK", "УПК", "Уголовно-процессуальный кодекс", "upk", "упк|упк но|уголовно процессуальный кодекс|уголовно-процессуальный кодекс")
    LawSearch_RegisterDoc("KAS", "КАС", "Кодекс административного судопроизводства", "kas", "кас|кас но|кодекс административного судопроизводства|административное судопроизводство")
    LawSearch_RegisterDoc("FSB", "ФЗОФСБ", "Федеральный закон «О Федеральной службе безопасности»", "fsb", "фзофсб|фз о фсб|фз о федеральной службе безопасности|фсб|федеральная служба безопасности")
    LawSearch_RegisterDoc("FSIN", "ФЗОФСИН", "Федеральный закон «О Федеральной службе исполнения наказаний»", "fsin", "фзофсин|фз о фсин|фз о федеральной службе исполнения наказаний|фсин|федеральная служба исполнения наказаний")
    LawSearch_RegisterDoc("VS", "ФЗОВС", "Федеральный закон «О военной службе»", "vs", "фзовс|фз о военной службе|военная служба|военнослужащие")
    LawSearch_RegisterDoc("SUD", "ФКЗОСС", "Федеральный конституционный закон «О судебной системе и статусе судей»", "sud", "фкзосс|судебная система|статус судей|закон о судебной системе")
    LawSearch_RegisterDoc("ORD", "ФЗООРД", "Федеральный закон «Об оперативно-розыскной деятельности»", "ord", "фзоорд|фз об орд|орд|оперативно розыскная деятельность|оперативно-розыскная деятельность")
    LawSearch_RegisterDoc("GT", "ФКЗОГТ", "Федеральный конституционный закон «О государственной тайне»", "gt", "фкзогт|фз о государственной тайне|государственная тайна|гостайна")
}

LawSearch_RegisterDoc(code, shortName, fullName, prefix, aliases)
{
    global LawSearchDocCatalog, LawSearchDocByCode

    meta := {Code: code, Short: shortName, Name: fullName, Prefix: prefix, Aliases: aliases
        , FileName: code . ".txt", SourceURL: LawCorpus_SourceUrl(code), SourceRevision: "2026-07-27"
        , Order: LawSearchDocCatalog.Length() + 1}
    LawSearchDocCatalog.Push(meta)
    LawSearchDocByCode[code] := meta
}

LawSearch_GetDocMeta(code)
{
    global LawSearchDocByCode

    LawSearch_InitCatalog()
    code := Trim(code)
    StringUpper, code, code
    if (IsObject(LawSearchDocByCode) && LawSearchDocByCode.HasKey(code))
        return LawSearchDocByCode[code]
    return ""
}

LawSearch_GetDocName(code, shortName := 0)
{
    meta := LawSearch_GetDocMeta(code)
    if (!IsObject(meta))
        return code
    return shortName ? meta.Short : meta.Name
}

LawSearch_BuildTokenSet(normText)
{
    set := {}
    parts := StrSplit(normText, A_Space)
    Loop % parts.Length()
    {
        token := LawSearch_CanonicalToken(parts[A_Index])
        if (token != "")
            set[token] := 1
    }
    return set
}

LawSearch_BuildStemSet(tokenSet)
{
    stems := {}
    if (!IsObject(tokenSet))
        return stems
    for token, unused in tokenSet
    {
        variants := LawSearch_BuildStemVariants(token)
        Loop % variants.Length()
        {
            stem := variants[A_Index]
            if (StrLen(stem) >= 3)
                stems[stem] := 1
        }
    }
    return stems
}

LawSearch_MergeTokenSets(first, second)
{
    merged := {}
    if (IsObject(first))
        for token, unused in first
            merged[token] := 1
    if (IsObject(second))
        for token, unused in second
            merged[token] := 1
    return merged
}

LawSearch_CanonicalToken(word)
{
    static forms := ""

    word := Trim(word)
    if (word = "")
        return ""
    word := LawSearch_FixMixedCyrillic(word)
    if (!IsObject(forms))
    {
        forms := {}
        LawSearch_AddWordForms(forms, "применение", "применение|применения|применением|применять|применить|применяет|применяют|применяться")
        LawSearch_AddWordForms(forms, "оружие", "оружие|оружия|оружием|оружию|оружии")
        LawSearch_AddWordForms(forms, "сотрудник", "сотрудник|сотрудника|сотруднику|сотрудником|сотрудники|сотрудников|сотрудникам|сотрудниками")
        LawSearch_AddWordForms(forms, "полиция", "полиция|полиции|полицию|полицией|полицейский|полицейского|полицейским|полицейские|полицейских")
        LawSearch_AddWordForms(forms, "территория", "территория|территории|территорию|территорией|территорий|территориях")
        LawSearch_AddWordForms(forms, "задержание", "задержание|задержания|задержать|задержан|задержанный|задержанного|задержанным|задержанному")
        LawSearch_AddWordForms(forms, "осуждение", "осудить|осужден|осуждён|осуждение|осуждения|осужденный|осуждённый|осужденного")
        LawSearch_AddWordForms(forms, "нарушение", "нарушение|нарушения|нарушением|нарушений|нарушитель|нарушителя|нарушители")
        LawSearch_AddWordForms(forms, "правонарушение", "правонарушение|правонарушения|правонарушением|правонарушений")
        LawSearch_AddWordForms(forms, "гражданин", "гражданин|гражданина|гражданину|гражданином|граждане|граждан|гражданами")
        LawSearch_AddWordForms(forms, "лицо", "лицо|лица|лицу|лицом|лиц")
        LawSearch_AddWordForms(forms, "желтый", "желтый|желтая|желтое|желтые|желтой|желтую|желтых|желтом")
        LawSearch_AddWordForms(forms, "зона", "зона|зоны|зону|зоной|зоне|зонах|зон")
        LawSearch_AddWordForms(forms, "закрытый", "закрытый|закрытая|закрытое|закрытые|закрытой|закрытую|закрытых|закрытом")
        LawSearch_AddWordForms(forms, "ограниченный", "ограниченный|ограниченная|ограниченное|ограниченные|ограниченной|ограниченную|ограниченных")
        LawSearch_AddWordForms(forms, "служебный", "служебный|служебная|служебное|служебные|служебной|служебную|служебных")
        LawSearch_AddWordForms(forms, "государственный", "государственный|государственная|государственное|государственные|государственной|государственную|государственных")
        LawSearch_AddWordForms(forms, "исполнительный", "исполнительный|исполнительная|исполнительной|исполнительную|исполнительные|исполнительных")
        LawSearch_AddWordForms(forms, "судебный", "судебный|судебная|судебной|судебную|судебные|судебных")
        LawSearch_AddWordForms(forms, "законодательный", "законодательный|законодательная|законодательной|законодательную|законодательные|законодательных")
    }
    if (forms.HasKey(word))
        return forms[word]
    return word
}

LawSearch_AddWordForms(ByRef forms, canonical, list)
{
    entries := StrSplit(list, "|")
    Loop % entries.Length()
        forms[entries[A_Index]] := canonical
}

LawSearch_StemToken(word)
{
    word := LawSearch_CanonicalToken(word)
    if (word = "" || RegExMatch(word, "^[0-9]+(?:\.[0-9]+)*$"))
        return word

    snowball := LawSearch_RussianStem(word)
    if (snowball != "" && StrLen(snowball) >= 3)
        return snowball
    return LawSearch_LightStem(word)
}

LawSearch_Find(docCode, query, maxResults := 30)
{
    global LawSearchCache, LawSearchCacheOrder, LawSearchAlgorithmVersion

    if !LawSearch_Init()
        return {Results: [], Checked: 0, Passed: 0, MinScore: 0, Possible: 0, Query: "", FuzzyBudgetHit: 1, Busy: 1}
    docCode := Trim(docCode)
    StringUpper, docCode, docCode
    maxResults := Round(maxResults)
    if (maxResults < 1)
        maxResults := 1
    else if (maxResults > 30)
        maxResults := 30

    queryKey := Trim(query)
    StringLower, queryKey, queryKey
    cacheKey := LawSearchAlgorithmVersion . "|" . docCode . "|" . maxResults . "|" . queryKey
    if !IsObject(LawSearchCache)
        LawSearchCache := {}
    if !IsObject(LawSearchCacheOrder)
        LawSearchCacheOrder := []

    if LawSearchCache.HasKey(cacheKey)
        return LawSearch_ClonePackage(LawSearchCache[cacheKey])

    package := LawSearch_Find_Real(docCode, query, maxResults)
    ; Не сохраняем неполный результат, если нечёткий поиск остановлен бюджетом.
    if (!package.FuzzyBudgetHit)
    {
        while (LawSearchCacheOrder.Length() >= 100)
        {
            oldestKey := LawSearchCacheOrder.RemoveAt(1)
            if LawSearchCache.HasKey(oldestKey)
                LawSearchCache.Delete(oldestKey)
        }
        LawSearchCache[cacheKey] := LawSearch_ClonePackage(package)
        LawSearchCacheOrder.Push(cacheKey)
    }
    return package
}

LawSearch_ClonePackage(package)
{
    if !IsObject(package)
        return package
    clone := {}
    for key, value in package
    {
        if (key != "Results")
            clone[key] := value
    }
    clone.Results := []
    if IsObject(package.Results)
    {
        Loop % package.Results.Length()
        {
            sourceResult := package.Results[A_Index]
            resultCopy := {}
            for resultKey, resultValue in sourceResult
                resultCopy[resultKey] := resultValue
            clone.Results.Push(resultCopy)
        }
    }
    return clone
}

LawSearch_Find_Real(docCode, query, maxResults := 30)
{
    global SearchIndex
    global LawSearchFuzzyStartTick, LawSearchFuzzyBudgetMs, LawSearchFuzzyChecksLeft, LawSearchFuzzyBudgetHit

    if !LawSearch_Init()
        return {Results: [], Checked: 0, Passed: 0, Busy: 1}
    docCode := Trim(docCode)
    StringUpper, docCode, docCode
    q := LawSearch_ParseQuery(query)
    maxResults := Round(maxResults)
    if (maxResults < 1)
        maxResults := 1
    else if (maxResults > 30)
        maxResults := 30
    results := []
    checked := 0
    passed := 0
    minScore := LawSearch_MinScoreParsed(q)

    ; Более мягкий поиск требует чуть большего бюджета, но остаётся ограниченным.
    LawSearchFuzzyStartTick := TickNow()
    LawSearchFuzzyChecksLeft := 3500
    LawSearchFuzzyBudgetHit := 0

    seen := {}
    Loop, 2 {
        pass := A_Index
        q.AllowFuzzy := pass = 2 ? 1 : 0
        if (pass = 2 && results.Length() >= maxResults)
            break
        if (pass = 2)
            LawSearchFuzzyStartTick := TickNow()
    Loop % SearchIndex.Length()
    {
        item := SearchIndex[A_Index]
        if (pass = 2 && seen.HasKey(A_Index))
            continue
        indexPosition := A_Index
        if (docCode != "ALL" && item.DocCode != docCode)
            continue
        checked++



        detail := LawSearch_ScoreParsed(item, q)
        if (!IsObject(detail) || detail.Score < minScore)
            continue
        passed++
        seen[indexPosition] := 1
        result := {Score: detail.Score, Coverage: detail.Coverage, ExactRank: detail.ExactRank, Approx: detail.Approx, Item: item}
        result.Key := LawSearch_ResultKey(item, q)
        LawSearch_InsertInto(results, result, maxResults)
    }
    }

    possible := 0
    if (results.Length() > 0)
    {
        top := results[1]
        possible := top.Approx && top.ExactRank < 2
    }
    budgetHit := LawSearchFuzzyBudgetHit ? 1 : 0
    LawSearchFuzzyStartTick := 0
    LawSearchFuzzyChecksLeft := 0
    return {MissingDocuments: LawSearchMissingDocuments.Clone(), Results: results, Checked: checked, Passed: passed, MinScore: minScore, Possible: possible, Query: q, FuzzyBudgetHit: budgetHit}
}

LawSearch_ParseQuery(query)
{
    syntax := LawSearch_QueryFilters(query)
    query := syntax.SearchText
    q := {Raw: query, Norm: LawSearch_Normalize(query), Chapter: "", Article: "", Part: "", Point: ""}
    q.RequiredPhrases := syntax.Phrases
    q.ExcludedTokens := syntax.Excluded
    q.AllowFuzzy := 1
    q.Structured := 0
    q.NumberOnly := 0
    q.DocOnly := 0
    q.HasStrongDoc := 0
    q.DocMatches := LawSearch_MatchDocCodes(q.Norm)

    if RegExMatch(q.Norm, "(^| )(?:глава|гл)\s*([0-9]+(?:\.[0-9]+)*)( |$)", m)
        q.Chapter := m2
    if RegExMatch(q.Norm, "(^| )(?:статья|ст)\s*([0-9]+(?:\.[0-9]+)*)( |$)", m)
        q.Article := m2
    if RegExMatch(q.Norm, "(^| )(?:часть|ч)\s*([0-9]+(?:\.[0-9]+)*)( |$)", m)
        q.Part := m2
    if RegExMatch(q.Norm, "(^| )(?:пункт|п)\s*([0-9]+(?:\.[0-9]+)*)( |$)", m)
        q.Point := m2

    if (q.Article = "")
    {
        if RegExMatch(q.Norm, "(^| )([0-9]+(?:\.[0-9]+){1,2})( |$)", n)
        {
            number := n2
            levels := StrSplit(number, ".")
            if (levels.Length() >= 3)
            {
                q.Article := levels[1] . "." . levels[2]
                if (q.Part = "")
                    q.Part := levels[3]
            }
            else
                q.Article := number
        }
        else if (RegExMatch(q.Norm, "^[0-9]+$", n))
            q.Article := n
        else if (LawSearch_ObjectCount(q.DocMatches) > 0 && RegExMatch(q.Norm, "(^| )([0-9]+)( |$)", n))
            q.Article := n2
    }

    if (q.Chapter != "" || q.Article != "" || q.Part != "" || q.Point != "")
        q.Structured := 1
    for code, strength in q.DocMatches
    {
        if (strength >= 3)
            q.HasStrongDoc := 1
        if (strength = 4 && !q.Structured)
            q.DocOnly := 1
    }

    q.Tokens := []
    q.SyntheticTokens := []
    LawSearch_BuildQueryTokens(q)
    if (q.Article != "" && q.Tokens.Length() = 0 && !q.DocOnly)
        q.NumberOnly := 1
    q.SemanticPhrase := LawSearch_QueryPhrase(q.Tokens)
    return q
}

LawSearch_MatchDocCodes(norm)
{
    global LawSearchDocCatalog

    matches := {}
    LawSearch_InitCatalog()
    Loop % LawSearchDocCatalog.Length()
    {
        meta := LawSearchDocCatalog[A_Index]
        aliases := StrSplit(meta.Aliases, "|")
        Loop % aliases.Length()
        {
            aliasNorm := LawSearch_Normalize(aliases[A_Index])
            if (aliasNorm = "" || !LawSearch_HasPhrase(norm, aliasNorm))
                continue
            if (norm != aliasNorm && InStr("|оружие|полиция|территории|постановление|вертикаль|", "|" . aliasNorm . "|"))
                continue
            if (norm = aliasNorm)
                strength := 4
            else if (!InStr(aliasNorm, " ") && StrLen(aliasNorm) <= 12)
                strength := 3
            else
                strength := 2
            if (!matches.HasKey(meta.Code) || strength > matches[meta.Code])
                matches[meta.Code] := strength
        }
    }
    return matches
}

LawSearch_HasPhrase(text, phrase)
{
    if (text = "" || phrase = "")
        return false
    return InStr(" " . text . " ", " " . phrase . " ") > 0
}

LawSearch_BuildQueryTokens(ByRef q)
{
    seen := {}
    parts := StrSplit(q.Norm, A_Space)
    Loop % parts.Length()
    {
        raw := Trim(parts[A_Index])
        if (raw = "" || RegExMatch(raw, "^[0-9]+(?:\.[0-9]+)*$") || LawSearch_IsReferenceLabel(raw))
            continue
        if (LawSearch_IsStopWord(raw) || LawSearch_IsDocAbbreviation(raw))
            continue

        ; Если слово набрано в английской раскладке, используем русскую раскладку
        ; как основной вариант. Аббревиатуры документов отсеиваются выше.
        layoutWord := LawSearch_KeyboardToRussian(raw)
        if (layoutWord != "")
            raw := layoutWord

        word := LawSearch_CorrectToken(LawSearch_CanonicalToken(raw))
        if (word = "" || seen.HasKey(word))
            continue
        weight := LawSearch_IsCommonWord(word) ? 0.32 : 1.0
        if (StrLen(word) = 3)
            weight *= 0.72
        q.Tokens.Push({Word: word, Weight: weight, Original: 1})
        seen[word] := 1
    }

    ; Связанные термины добавляют баллы, но не заменяют исходные слова.
    Loop % q.Tokens.Length()
    {
        word := q.Tokens[A_Index].Word
        synonyms := LawSearch_GetSynonyms(word)
        Loop % synonyms.Length()
            LawSearch_AddSyntheticToken(q, synonyms[A_Index], 0.42)
    }

    norm := q.Norm
    if (LawSearch_HasPhrase(norm, "два раза") || LawSearch_HasPhrase(norm, "одно и то же") || LawSearch_HasPhrase(norm, "за одно нарушение"))
        LawSearch_AddSyntheticToken(q, "повторно", 0.72)
    if (LawSearch_HasPhrase(norm, "закрытая территория") || LawSearch_HasPhrase(norm, "закрытой территории"))
    {
        LawSearch_AddSyntheticToken(q, "территория", 0.65)
        LawSearch_AddSyntheticToken(q, "ограниченный", 0.60)
        LawSearch_AddSyntheticToken(q, "доступ", 0.60)
    }
    if (LawSearch_HasPhrase(norm, "желтая зона"))
    {
        LawSearch_AddSyntheticToken(q, "служебный", 0.45)
        LawSearch_AddSyntheticToken(q, "территория", 0.45)
        LawSearch_AddSyntheticToken(q, "покинуть", 0.35)
    }
    if (LawSearch_HasPhrase(norm, "ветви власти") || LawSearch_HasPhrase(norm, "виды государственной власти"))
    {
        LawSearch_AddSyntheticToken(q, "исполнительный", 0.62)
        LawSearch_AddSyntheticToken(q, "судебный", 0.62)
        LawSearch_AddSyntheticToken(q, "законодательный", 0.62)
        LawSearch_AddSyntheticToken(q, "вертикаль", 0.45)
    }
}

LawSearch_AddSyntheticToken(ByRef q, word, weight)
{
    word := LawSearch_CanonicalToken(LawSearch_Normalize(word))
    if (word = "" || InStr(word, " "))
        return
    Loop % q.Tokens.Length()
        if (q.Tokens[A_Index].Word = word)
            return
    Loop % q.SyntheticTokens.Length()
    {
        if (q.SyntheticTokens[A_Index].Word = word)
        {
            if (weight > q.SyntheticTokens[A_Index].Weight)
                q.SyntheticTokens[A_Index].Weight := weight
            return
        }
    }
    q.SyntheticTokens.Push({Word: word, Weight: weight, Original: 0})
}

LawSearch_GetSynonyms(word)
{
    static map := ""
    if (!IsObject(map))
    {
        map := {}
        LawSearch_AddSynonymGroup(map, "дважды|повторно|неоднократно")
        LawSearch_AddSynonymGroup(map, "наказать|наказание|привлечь|осуждение|осудить")
        LawSearch_AddSynonymGroup(map, "нарушение|правонарушение|преступление")
        LawSearch_AddSynonymGroup(map, "полицейский|полиция|сотрудник")
        LawSearch_AddSynonymGroup(map, "обыск|досмотр|личный")
        LawSearch_AddSynonymGroup(map, "арест|задержание|стража")
        LawSearch_AddSynonymGroup(map, "машина|автомобиль|транспорт|транспортный")
        LawSearch_AddSynonymGroup(map, "выгнать|покинуть|выпроводить|выдворение")
        LawSearch_AddSynonymGroup(map, "закрытый|ограниченный|служебный")
        LawSearch_AddSynonymGroup(map, "удостоверение|документ")
    }
    word := LawSearch_CanonicalToken(word)
    return map.HasKey(word) ? map[word] : []
}

LawSearch_AddSynonymGroup(ByRef map, groupText)
{
    words := StrSplit(groupText, "|")
    Loop % words.Length()
    {
        source := LawSearch_CanonicalToken(words[A_Index])
        related := []
        Loop % words.Length()
        {
            target := LawSearch_CanonicalToken(words[A_Index])
            if (target != source)
                related.Push(target)
        }
        map[source] := related
    }
}

LawSearch_IsReferenceLabel(word)
{
    return InStr("|глава|статья|часть|пункт|подпункт|гл|ст|ч|п|", "|" . word . "|") > 0
}

LawSearch_IsDocAbbreviation(word)
{
    return InStr("|ву|фп|фзоп|фзотод|отод|тк|арг|ук|фкзовв|коап|пдд|фзоо|упк|кас|фзофсб|фсб|фзофсин|фсин|фзовс|фкзосс|фзоорд|орд|фкзогт|", "|" . word . "|") > 0
}

LawSearch_IsCommonWord(word)
{
    return InStr("|лицо|право|закон|сотрудник|гражданин|может|должен|область|государственный|орган|", "|" . word . "|") > 0
}

LawSearch_QueryHasWord(q, expected)
{
    Loop % q.Tokens.Length()
        if (q.Tokens[A_Index].Word = expected)
            return true
    Loop % q.SyntheticTokens.Length()
        if (q.SyntheticTokens[A_Index].Word = expected)
            return true
    return false
}

LawSearch_QueryPhrase(tokens)
{
    phrase := ""
    Loop % tokens.Length()
    {
        if (phrase != "")
            phrase .= " "
        phrase .= tokens[A_Index].Word
    }
    return phrase
}

LawSearch_ScoreParsed(item, q)
{
    for _, phrase in q.RequiredPhrases {
        if !LawSearch_HasPhrase(item.NormTitle . " " . item.NormBody, phrase)
            return ""
    }
    for _, excluded in q.ExcludedTokens {
        if (LawSearch_HasExactWord(item.NormTitle, excluded) || LawSearch_HasExactWord(item.NormBody, excluded))
            return ""
    }
    score := 0
    exactRank := 0
    matchedOriginal := 0
    originalWeight := 0.0
    matchedWeight := 0.0
    approximate := 0
    strongMatches := 0
    fuzzyMatches := 0
    bestOriginalValue := 0

    for code, strength in q.DocMatches
    {
        if (code = item.DocCode)
        {
            score += q.DocOnly ? 2600 : 520 + (strength * 70)
            exactRank += q.DocOnly ? 4 : 2
            docMatched := 1
            break
        }
    }
    if (q.DocOnly && !docMatched)
        return ""
    if (q.HasStrongDoc && q.Structured && !docMatched)
        return ""

    if (q.Article != "")
    {
        if (LawSearch_NormalizeNumber(item.Article) != LawSearch_NormalizeNumber(q.Article))
            return ""
        score += 2200
        exactRank += 5
    }
    if (q.Chapter != "")
    {
        if (LawSearch_NormalizeNumber(item.Chapter) != LawSearch_NormalizeNumber(q.Chapter))
            return ""
        score += 850
        exactRank += 2
    }
    if (q.Part != "")
    {
        if (LawSearch_NormalizeNumber(item.Part) != LawSearch_NormalizeNumber(q.Part))
            return ""
        score += 1250
        exactRank += 3
    }
    if (q.Point != "")
    {
        if (LawSearch_NormalizeNumber(item.Point) != LawSearch_NormalizeNumber(q.Point))
            return ""
        score += 950
        exactRank += 2
    }
    if (q.Article != "" && q.Part != "")
        score += 450
    if (q.Article != "" && docMatched)
        score += 350

    Loop % q.Tokens.Length()
    {
        token := q.Tokens[A_Index]
        originalWeight += token.Weight
        match := LawSearch_MatchItemToken(item, token.Word, q.AllowFuzzy)
        if (!IsObject(match))
            continue
        matchedOriginal++
        matchedWeight += token.Weight
        addition := Round(match.Value * token.Weight)
        score += addition
        if (addition > bestOriginalValue)
            bestOriginalValue := addition
        if (match.Kind = "fuzzy")
        {
            approximate := 1
            fuzzyMatches++
        }
        else
        {
            strongMatches++
            if (match.Kind = "prefix")
                approximate := 1
        }
        if (StrLen(token.Word) >= 8 && match.Kind = "exact")
            score += 24
    }

    syntheticScore := 0
    Loop % q.SyntheticTokens.Length()
    {
        token := q.SyntheticTokens[A_Index]
        match := LawSearch_MatchItemToken(item, token.Word, 0)
        if (!IsObject(match))
            continue
        addition := Round(match.Value * token.Weight)
        if (addition > 75)
            addition := 75
        syntheticScore += addition
    }
    if (syntheticScore > 230)
        syntheticScore := 230
    score += syntheticScore

    totalOriginal := q.Tokens.Length()
    if (totalOriginal > 0)
    {
        coverage := matchedOriginal / totalOriginal
        weightedCoverage := originalWeight > 0 ? matchedWeight / originalWeight : coverage
        if (matchedOriginal = totalOriginal)
        {
            score += 280 + (totalOriginal * 35)
            exactRank += strongMatches = totalOriginal ? 2 : 1
        }
        else if (coverage >= 0.66)
            score += 135
        else if (coverage >= 0.5)
            score += 65

        minimumMatches := Ceil(totalOriginal * 0.4)
        if (minimumMatches < 1)
            minimumMatches := 1
        if (!q.Structured && !q.DocOnly && matchedOriginal < minimumMatches)
            return ""

        ; Раньше любой запрос из нескольких слов, найденный только по опечаткам,
        ; безусловно отбрасывался. Теперь допускаем его при полном покрытии.
        if (!q.Structured && !q.DocOnly && totalOriginal > 1 && strongMatches < 1)
        {
            if (matchedOriginal < totalOriginal || weightedCoverage < 0.82)
                return ""
        }
        if (!q.Structured && !q.DocOnly && totalOriginal = 1 && matchedOriginal = 0 && syntheticScore < 70)
            return ""
        if (!q.Structured && !q.DocOnly && totalOriginal = 1 && matchedOriginal = 1 && bestOriginalValue < 42)
            return ""
    }
    else
    {
        coverage := (q.Structured || q.DocOnly) ? 1.0 : 0.0
        weightedCoverage := coverage
    }

    if (q.SemanticPhrase != "" && q.Tokens.Length() > 1)
    {
        if (LawSearch_HasPhrase(item.NormTitle, q.SemanticPhrase))
        {
            score += 900
            exactRank += 4
        }
        else if (LawSearch_HasPhrase(item.NormBody, q.SemanticPhrase))
        {
            score += 650
            exactRank += 3
        }
    }

    ; Prefer a focused article heading over its broad inherited chapter heading.
    articleWords := LawSearch_BuildTokenSet(LawSearch_Normalize(item.ArticleTitle))
    articleMatches := 0
    for _, token in q.Tokens
        if articleWords.HasKey(token.Word)
            articleMatches++
    if (articleMatches > 0)
        score += Round(500 * articleMatches / Max(1, LawSearch_ObjectCount(articleWords)))
    if (q.DocOnly && item.Article != "")
        score += LawSearch_ArticleSortBonus(item.Article)
    return {Score: score, Coverage: weightedCoverage, ExactRank: exactRank, Approx: approximate && strongMatches = 0}
}

LawSearch_MatchItemToken(item, word, allowFuzzy := 1)
{
    if (IsObject(item.TitleTokens) && item.TitleTokens.HasKey(word))
        return {Value: 210, Kind: "exact", Where: "title", Quality: 1.0}
    if (IsObject(item.BodyTokens) && item.BodyTokens.HasKey(word))
        return {Value: 132, Kind: "exact", Where: "body", Quality: 1.0}

    stemMatch := LawSearch_FindStemMatch(item, word)
    if (IsObject(stemMatch))
        return stemMatch

    prefixMatch := LawSearch_FindPrefixMatch(item, word)
    if (IsObject(prefixMatch))
        return prefixMatch

    if (allowFuzzy && StrLen(word) >= 4)
    {
        maxDistance := LawSearch_MaxEditDistance(word)
        fuzzy := LawSearch_FindFuzzyMatch(item, word, maxDistance)
        if (IsObject(fuzzy))
            return fuzzy
    }
    return ""
}

LawSearch_FindFuzzyToken(item, word, maxDistance)
{
    match := LawSearch_FindFuzzyMatch(item, word, maxDistance)
    return IsObject(match) ? match.Token : ""
}



; ===== Law search v2: morphology, prefixes and typo tolerance =====
LawSearch_FixMixedCyrillic(word)
{
    if (!RegExMatch(word, "[а-яё]") || !RegExMatch(word, "[a-z]"))
        return word
    pairs := "a=а|c=с|e=е|o=о|p=р|x=х|y=у"
    Loop, Parse, pairs, |
    {
        pair := StrSplit(A_LoopField, "=")
        StringReplace, word, word, % pair[1], % pair[2], All
    }
    return word
}

LawSearch_KeyboardToRussian(word)
{
    if (!RegExMatch(word, "^[a-z\[\];',\.]+$") || StrLen(word) < 3)
        return ""
    source := "qwertyuiop[]asdfghjkl;'zxcvbnm,."
    target := "йцукенгшщзхъфывапролджэячсмитьбю"
    out := ""
    Loop, Parse, word
    {
        pos := InStr(source, A_LoopField, true)
        if (!pos)
            return ""
        out .= SubStr(target, pos, 1)
    }
    return out
}

LawSearch_BuildStemVariants(word)
{
    variants := []
    word := LawSearch_CanonicalToken(word)
    if (word = "")
        return variants
    LawSearch_AddUniqueString(variants, word)

    russian := LawSearch_RussianStem(word)
    if (StrLen(russian) >= 3)
        LawSearch_AddUniqueString(variants, russian)

    light := LawSearch_LightStem(word)
    if (StrLen(light) >= 3)
        LawSearch_AddUniqueString(variants, light)

    safe := LawSearch_BuildSafeStems(word)
    Loop % safe.Length()
        LawSearch_AddUniqueString(variants, safe[A_Index])
    return variants
}

LawSearch_AddUniqueString(ByRef list, value)
{
    value := Trim(value)
    if (value = "")
        return
    Loop % list.Length()
    {
        if (list[A_Index] = value)
            return
    }
    list.Push(value)
}

LawSearch_LightStem(word)
{
    len := StrLen(word)
    if (len < 5)
        return word
    endings := "иями|ями|ами|остью|остей|ение|ения|ений|енному|енными|енный|енная|енное|енные|анного|анному|анными|анный|анная|анное|анные|ировать|овать|евать|ного|ному|ными|ого|его|ому|ему|ыми|ими|ая|яя|ое|ее|ые|ие|ый|ий|ой|ым|им|ых|их|ую|юю|ам|ям|ах|ях|ов|ев|ей|ом|ем|ою|ею|а|я|ы|и|у|ю|е|о"
    list := StrSplit(endings, "|")
    Loop % list.Length()
    {
        ending := list[A_Index]
        eLen := StrLen(ending)
        if (len - eLen >= 4 && SubStr(word, len - eLen + 1) = ending)
            return SubStr(word, 1, len - eLen)
    }
    return word
}

LawSearch_RussianStem(word)
{
    if (!RegExMatch(word, "^[а-яё]+$") || StrLen(word) < 4)
        return word

    original := word
    rvStart := LawSearch_FindRVStart(word)
    if (rvStart < 1 || rvStart > StrLen(word))
        return word
    r2Start := LawSearch_FindR2Start(word)
    prefix := SubStr(word, 1, rvStart - 1)
    rv := SubStr(word, rvStart)

    if (!LawSearch_RemovePerfectiveGerund(rv))
    {
        LawSearch_RemoveSuffixList(rv, "ся|сь")
        if (!LawSearch_RemoveAdjectival(rv))
        {
            if (!LawSearch_RemoveVerb(rv))
                LawSearch_RemoveNoun(rv)
        }
    }

    if (SubStr(rv, 0) = "и")
        rv := SubStr(rv, 1, StrLen(rv) - 1)
    result := prefix . rv

    if (r2Start > 0)
    {
        if (SubStr(result, 0 - 3) = "ость" && StrLen(result) - 3 >= r2Start)
            result := SubStr(result, 1, StrLen(result) - 4)
        else if (SubStr(result, 0 - 2) = "ост" && StrLen(result) - 2 >= r2Start)
            result := SubStr(result, 1, StrLen(result) - 3)
    }

    if (SubStr(result, 0 - 1) = "нн")
        result := SubStr(result, 1, StrLen(result) - 1)
    else
    {
        if (LawSearch_RemoveEndingFromWhole(result, "ейше|ейш"))
        {
            if (SubStr(result, 0 - 1) = "нн")
                result := SubStr(result, 1, StrLen(result) - 1)
        }
        else if (SubStr(result, 0) = "ь")
            result := SubStr(result, 1, StrLen(result) - 1)
    }

    if (StrLen(result) < 3 || !LawSearch_HasRussianVowel(result))
        return original
    return result
}

LawSearch_FindRVStart(word)
{
    Loop, Parse, word
    {
        if (InStr("аеиоуыэюя", A_LoopField))
            return A_Index + 1
    }
    return 0
}

LawSearch_FindR2Start(word)
{
    r1 := LawSearch_FindRegionAfterVowelConsonant(word, 1)
    if (!r1)
        return 0
    return LawSearch_FindRegionAfterVowelConsonant(word, r1)
}

LawSearch_FindRegionAfterVowelConsonant(word, startPos)
{
    len := StrLen(word)
    seenVowel := 0
    Loop % len - startPos + 1
    {
        pos := startPos + A_Index - 1
        ch := SubStr(word, pos, 1)
        isVowel := InStr("аеиоуыэюя", ch) > 0
        if (!seenVowel)
        {
            if (isVowel)
                seenVowel := 1
            continue
        }
        if (!isVowel)
            return pos + 1
    }
    return 0
}

LawSearch_HasRussianVowel(word)
{
    Loop, Parse, word
    {
        if (InStr("аеиоуыэюя", A_LoopField))
            return true
    }
    return false
}

LawSearch_RemovePerfectiveGerund(ByRef rv)
{
    if (LawSearch_RemoveSuffixList(rv, "ившись|ывшись|ивши|ывши|ив|ыв"))
        return true
    return LawSearch_RemoveSuffixList(rv, "вшись|вши|в", 1)
}

LawSearch_RemoveAdjectival(ByRef rv)
{
    endings := "ими|ыми|его|ого|ему|ому|ее|ие|ые|ое|ей|ий|ый|ой|ем|им|ым|ом|их|ых|ую|юю|ая|яя|ою|ею"
    if (!LawSearch_RemoveSuffixList(rv, endings))
        return false
    if (!LawSearch_RemoveSuffixList(rv, "ивш|ывш|ующ"))
        LawSearch_RemoveSuffixList(rv, "ем|нн|вш|ющ|щ", 1)
    return true
}

LawSearch_RemoveVerb(ByRef rv)
{
    if (LawSearch_RemoveSuffixList(rv, "ила|ыла|ена|ейте|уйте|ите|или|ыли|ило|ыло|ено|ей|уй|ил|ыл|им|ым|ен|ят|ует|уют|ит|ыт|ены|ить|ыть|ишь|ую|ю"))
        return true
    return LawSearch_RemoveSuffixList(rv, "ла|на|ете|йте|ли|ло|но|ет|ют|ны|ть|ешь|нно|й|л|ем|н", 1)
}

LawSearch_RemoveNoun(ByRef rv)
{
    return LawSearch_RemoveSuffixList(rv, "иями|ями|ами|ией|иям|ием|иях|ью|ия|ья|ие|ье|еи|ии|ей|ой|ий|ям|ем|ам|ом|ах|ях|ию|ев|ов|а|е|и|й|о|у|ы|ь|ю|я")
}

LawSearch_RemoveSuffixList(ByRef value, suffixes, requirePrevAY := 0)
{
    list := StrSplit(suffixes, "|")
    len := StrLen(value)
    Loop % list.Length()
    {
        suffix := list[A_Index]
        sLen := StrLen(suffix)
        if (sLen > len || SubStr(value, len - sLen + 1) != suffix)
            continue
        if (requirePrevAY)
        {
            prevPos := len - sLen
            if (prevPos < 1)
                continue
            prev := SubStr(value, prevPos, 1)
            if (prev != "а" && prev != "я")
                continue
        }
        value := SubStr(value, 1, len - sLen)
        return true
    }
    return false
}

LawSearch_RemoveEndingFromWhole(ByRef value, suffixes)
{
    return LawSearch_RemoveSuffixList(value, suffixes)
}

LawSearch_FindStemMatch(item, word)
{
    variants := LawSearch_BuildStemVariants(word)
    Loop % variants.Length()
    {
        stem := variants[A_Index]
        if (StrLen(stem) < 3)
            continue
        if (IsObject(item.TitleStems) && item.TitleStems.HasKey(stem))
            return {Value: 166, Kind: "stem", Where: "title", Quality: 0.92}
        if (IsObject(item.BodyStems) && item.BodyStems.HasKey(stem))
            return {Value: 102, Kind: "stem", Where: "body", Quality: 0.88}
    }
    return ""
}

LawSearch_FindPrefixMatch(item, word)
{
    title := LawSearch_FindPrefixInSet(item.TitleTokens, word)
    if (IsObject(title))
        return {Value: 112 + Round(title.Quality * 58), Kind: "prefix", Where: "title", Quality: title.Quality, Token: title.Token}
    body := LawSearch_FindPrefixInSet(item.BodyTokens, word)
    if (IsObject(body))
        return {Value: 63 + Round(body.Quality * 42), Kind: "prefix", Where: "body", Quality: body.Quality, Token: body.Token}
    return ""
}

LawSearch_FindPrefixInSet(tokenSet, word)
{
    if (!IsObject(tokenSet) || StrLen(word) < 3)
        return ""
    bestQuality := 0.0
    bestToken := ""
    for token, unused in tokenSet
    {
        quality := LawSearch_PrefixQuality(word, token)
        if (quality > bestQuality)
        {
            bestQuality := quality
            bestToken := token
        }
    }
    return bestToken != "" ? {Token: bestToken, Quality: bestQuality} : ""
}

LawSearch_PrefixQuality(queryWord, token)
{
    qLen := StrLen(queryWord)
    tLen := StrLen(token)
    if (qLen < 3 || tLen < 3)
        return 0

    if (SubStr(token, 1, qLen) = queryWord)
    {
        ratio := qLen / tLen
        if (qLen = 3 && ratio < 0.48)
            return 0
        return 0.70 + (ratio * 0.30)
    }
    if (SubStr(queryWord, 1, tLen) = token && tLen >= 4 && qLen - tLen <= 3)
        return 0.64 + ((tLen / qLen) * 0.28)

    ; Родственные формы часто расходятся после общей основы:
    ; эваку-ация / эваку-ировать, преследован-ие / преследован-и.
    common := LawSearch_CommonPrefixLength(queryWord, token)
    shorter := qLen < tLen ? qLen : tLen
    if (common >= 5 && common / shorter >= 0.62)
        return 0.72 + ((common / Max(qLen, tLen)) * 0.22)
    return 0
}

LawSearch_MaxEditDistance(word)
{
    len := StrLen(word)
    if (len >= 10)
        return 3
    if (len >= 6)
        return 2
    return 1
}

LawSearch_FindFuzzyMatch(item, word, maxDistance)
{
    title := LawSearch_FindFuzzyInSet(item.TitleTokens, word, maxDistance)
    if (IsObject(title))
        return {Value: 64 + Round(title.Quality * 58), Kind: "fuzzy", Where: "title", Quality: title.Quality, Token: title.Token}
    body := LawSearch_FindFuzzyInSet(item.BodyTokens, word, maxDistance)
    if (IsObject(body))
        return {Value: 38 + Round(body.Quality * 44), Kind: "fuzzy", Where: "body", Quality: body.Quality, Token: body.Token}
    return ""
}

LawSearch_FindFuzzyInSet(tokenSet, word, maxDistance)
{
    global LawSearchFuzzyStartTick, LawSearchFuzzyBudgetMs, LawSearchFuzzyChecksLeft, LawSearchFuzzyBudgetHit
    if (!IsObject(tokenSet))
        return ""
    if (LawSearchFuzzyStartTick > 0 && TickNow() - LawSearchFuzzyStartTick > LawSearchFuzzyBudgetMs)
    {
        LawSearchFuzzyBudgetHit := 1
        return ""
    }

    bestQuality := 0.0
    bestToken := ""
    for token, unused in tokenSet
    {
        if (LawSearchFuzzyChecksLeft <= 0)
        {
            LawSearchFuzzyBudgetHit := 1
            break
        }
        if (LawSearchFuzzyStartTick > 0 && TickNow() - LawSearchFuzzyStartTick > LawSearchFuzzyBudgetMs)
        {
            LawSearchFuzzyBudgetHit := 1
            break
        }
        if (RegExMatch(token, "^[0-9]+(?:\.[0-9]+)*$") || Abs(StrLen(token) - StrLen(word)) > maxDistance)
            continue
        if (!LawSearch_QuickFuzzyGate(word, token, maxDistance))
            continue

        LawSearchFuzzyChecksLeft--
        distance := LawSearch_DamerauDistanceWithin(word, token, maxDistance)
        if (distance < 0)
            continue
        quality := 1.0 - (distance / Max(StrLen(word), StrLen(token)))
        if (quality > bestQuality)
        {
            bestQuality := quality
            bestToken := token
        }
    }
    return bestToken != "" ? {Token: bestToken, Quality: bestQuality} : ""
}


LawSearch_CommonPrefixLength(first, second)
{
    limit := StrLen(first) < StrLen(second) ? StrLen(first) : StrLen(second)
    count := 0
    Loop % limit
    {
        if (SubStr(first, A_Index, 1) != SubStr(second, A_Index, 1))
            break
        count++
    }
    return count
}

LawSearch_QuickFuzzyGate(first, second, maxDistance)
{
    if (Abs(StrLen(first) - StrLen(second)) > maxDistance)
        return false
    if (SubStr(first, 1, 1) = SubStr(second, 1, 1))
        return true
    if (SubStr(first, 2, 1) = SubStr(second, 2, 1) || SubStr(first, 3, 1) = SubStr(second, 3, 1))
        return true
    return LawSearch_CommonBigramCount(first, second, 1) >= 1
}

LawSearch_CommonBigramCount(first, second, stopAfter := 2)
{
    if (StrLen(first) < 2 || StrLen(second) < 2)
        return 0
    count := 0
    seen := {}
    Loop % StrLen(first) - 1
    {
        pair := SubStr(first, A_Index, 2)
        if (seen.HasKey(pair))
            continue
        seen[pair] := 1
        if (InStr(second, pair))
        {
            count++
            if (count >= stopAfter)
                return count
        }
    }
    return count
}

LawSearch_DamerauDistanceWithin(first, second, maxDistance)
{
    global LawSearchDistanceCache, LawSearchDistanceCacheCount

    maxDistance := Round(maxDistance)
    if (maxDistance < 0)
        return -1
    if (first = second)
        return 0
    lenA := StrLen(first)
    lenB := StrLen(second)
    if (Abs(lenA - lenB) > maxDistance)
        return -1

    if (first < second)
        cacheKey := maxDistance . "|" . first . "|" . second
    else
        cacheKey := maxDistance . "|" . second . "|" . first
    if IsObject(LawSearchDistanceCache) && LawSearchDistanceCache.HasKey(cacheKey)
        return LawSearchDistanceCache[cacheKey]

    prev2 := []
    prev := []
    Loop % lenB + 1
        prev[A_Index] := A_Index - 1

    finalDistance := -1
    Loop % lenA
    {
        i := A_Index
        curr := []
        curr[1] := i
        rowMin := curr[1]
        Loop % lenB
        {
            j := A_Index
            cost := SubStr(first, i, 1) = SubStr(second, j, 1) ? 0 : 1
            deletion := prev[j + 1] + 1
            insertion := curr[j] + 1
            substitution := prev[j] + cost
            value := deletion < insertion ? deletion : insertion
            if (substitution < value)
                value := substitution
            if (i > 1 && j > 1 && SubStr(first, i, 1) = SubStr(second, j - 1, 1) && SubStr(first, i - 1, 1) = SubStr(second, j, 1))
            {
                transposition := prev2[j - 1] + 1
                if (transposition < value)
                    value := transposition
            }
            curr[j + 1] := value
            if (value < rowMin)
                rowMin := value
        }
        if (rowMin > maxDistance)
        {
            LawSearch_DistanceCacheStore(cacheKey, -1)
            return -1
        }
        prev2 := prev
        prev := curr
    }
    finalDistance := prev[lenB + 1]
    if (finalDistance > maxDistance)
        finalDistance := -1
    LawSearch_DistanceCacheStore(cacheKey, finalDistance)
    return finalDistance
}

LawSearch_DistanceCacheStore(cacheKey, value)
{
    global LawSearchDistanceCache, LawSearchDistanceCacheCount
    if !IsObject(LawSearchDistanceCache)
    {
        LawSearchDistanceCache := {}
        LawSearchDistanceCacheCount := 0
    }
    if (!LawSearchDistanceCache.HasKey(cacheKey))
    {
        if (LawSearchDistanceCacheCount >= 5000)
        {
            LawSearchDistanceCache := {}
            LawSearchDistanceCacheCount := 0
        }
        LawSearchDistanceCacheCount++
    }
    LawSearchDistanceCache[cacheKey] := value
}
; ===== end Law search v2 =====

LawSearch_LevenshteinCacheStore(cacheKey, value)
{
    global LawSearchLevenshteinCache, LawSearchLevenshteinCacheCount
    if !IsObject(LawSearchLevenshteinCache)
    {
        LawSearchLevenshteinCache := {}
        LawSearchLevenshteinCacheCount := 0
    }
    if (!LawSearchLevenshteinCache.HasKey(cacheKey))
    {
        if (LawSearchLevenshteinCacheCount >= 3000)
        {
            LawSearchLevenshteinCache := {}
            LawSearchLevenshteinCacheCount := 0
        }
        LawSearchLevenshteinCacheCount++
    }
    LawSearchLevenshteinCache[cacheKey] := value ? 1 : 0
    return value ? true : false
}

LawSearch_LevenshteinWithin(first, second, maxDistance)
{
    return LawSearch_DamerauDistanceWithin(first, second, maxDistance) >= 0
}

LawSearch_NormalizeNumber(number)
{
    number := Trim(number)
    number := RegExReplace(number, "[^0-9\.]", "")
    return number
}

LawSearch_ArticleSortBonus(article)
{
    if (!RegExMatch(article, "^([0-9]+)", m))
        return 0
    value := m1 + 0
    bonus := 80 - value
    return bonus > 0 ? bonus : 0
}

LawSearch_MinScoreParsed(q)
{
    if (q.Structured || q.DocOnly)
        return 500
    if (q.Tokens.Length() = 1)
    {
        word := q.Tokens[1].Word
        if (LawSearch_IsCommonWord(word))
            return 35
        if (StrLen(word) <= 4)
            return 48
        return 72
    }
    return 120
}

LawSearch_ObjectCount(obj)
{
    count := 0
    if (IsObject(obj))
        for unusedKey, unusedValue in obj
            count++
    return count
}

LawSearch_ResultKey(item, q)
{
    article := item.Article != "" ? item.Article : item.ItemId
    if ((q.NumberOnly || q.DocOnly) && q.Part = "")
        return item.DocCode . "|" . article
    return item.DocCode . "|" . article . "|" . item.Part . "|" . item.Point . "|" . item.SubPoint . "|" . item.Level
}

LawSearch_InsertInto(ByRef results, result, maxResults)
{
    if (!IsObject(results))
        results := []

    if (result.Key != "")
    {
        Loop % results.Length()
        {
            if (results[A_Index].Key = result.Key)
            {
                if (LawSearch_ResultBefore(result, results[A_Index]))
                {
                    results.RemoveAt(A_Index)
                    break
                }
                return
            }
        }
    }

    inserted := 0
    Loop % results.Length()
    {
        if (LawSearch_ResultBefore(result, results[A_Index]))
        {
            results.InsertAt(A_Index, result)
            inserted := 1
            break
        }
    }
    if (!inserted)
        results.Push(result)
    if (results.Length() > maxResults)
        results.RemoveAt(maxResults + 1)
}

LawSearch_ResultBefore(first, second)
{
    if (first.Score != second.Score)
        return first.Score > second.Score
    if (first.Coverage != second.Coverage)
        return first.Coverage > second.Coverage
    if (first.Item.DocOrder != second.Item.DocOrder)
        return first.Item.DocOrder < second.Item.DocOrder
    hierarchyFirst := LawSearch_HierarchyKey(first.Item)
    hierarchySecond := LawSearch_HierarchyKey(second.Item)
    if (hierarchyFirst != hierarchySecond)
        return hierarchyFirst < hierarchySecond
    return first.Item.IndexOrder < second.Item.IndexOrder
}

LawSearch_HierarchyKey(item)
{
    key := LawSearch_NumberHierarchyKey(item.Article)
    key .= "|" . LawSearch_NumberHierarchyKey(item.Part)
    key .= "|" . LawSearch_NumberHierarchyKey(item.Point)
    key .= "|" . LawSearch_NumberHierarchyKey(item.SubPoint)
    return key
}

LawSearch_NumberHierarchyKey(value)
{
    value := Trim(value)
    if (value = "")
        return "999999.999999.999999.999999"
    key := ""
    parts := StrSplit(value, ".")
    Loop, 4
    {
        part := A_Index <= parts.Length() ? parts[A_Index] : 0
        if RegExMatch(part, "^\d+$")
            encoded := Format("{:06}", part + 0)
        else
            encoded := "999998" . LawSearch_Normalize(part)
        key .= (key = "" ? "" : ".") . encoded
    }
    return key
}

LawSearch_CheckExpected(query, docCode, expectedDoc, expectedArticle := "", expectedPart := "", topN := 3)
{
    package := LawSearch_Find(docCode, query, 15)
    results := package.Results
    Loop % results.Length()
    {
        if (A_Index > topN)
            break
        item := results[A_Index].Item
        if (item.DocCode != expectedDoc)
            continue
        if (expectedArticle != "" && item.Article != expectedArticle)
            continue
        if (expectedPart != "" && item.Part != expectedPart)
            continue
        return true
    }
    return false
}

LawSearch_CheckNoResults(query, docCode := "ALL")
{
    package := LawSearch_Find(docCode, query, 5)
    return package.Results.Length() = 0
}

LawSearch_CheckScope(query, docCode)
{
    package := LawSearch_Find(docCode, query, 15)
    if (package.Results.Length() = 0)
        return false
    Loop % package.Results.Length()
        if (package.Results[A_Index].Item.DocCode != docCode)
            return false
    return true
}

LawSearch_CheckMultipleDocs(query)
{
    package := LawSearch_Find("ALL", query, 15)
    docs := {}
    Loop % package.Results.Length()
        docs[package.Results[A_Index].Item.DocCode] := 1
    return LawSearch_ObjectCount(docs) >= 2
}
; ===== END EMBEDDED helper.ahk =====
if HasCommandLineArg("--audit-selftest")
{
    auditPassed := RunAuditSelfTest()
    ExitApp, % auditPassed ? 0 : 1
}

if HasCommandLineArg("--selftest")
{
    selfTestOk := RunSelfTestV1()
    selfTestExitCode := selfTestOk ? 0 : 1
    ExitApp, %selfTestExitCode%
}

if HasCommandLineArg("--diagnostics")
{
    diagnosticsOk := RunDiagnosticsExport()
    ExitApp, % diagnosticsOk ? 0 : 1
}

if HasCommandLineArg("--context-mocktest")
{
    contextMockOk := RunContextAssistantMockTest()
    ExitApp, % contextMockOk ? 0 : 1
}

if HasCommandLineArg("--autoreport-mocktest")
{
    autoReportMockOk := RunAutoReportMockTest()
    autoReportExitCode := autoReportMockOk ? 0 : 1
    ExitApp, %autoReportExitCode%
}

if HasCommandLineArg("--law-search-test")
{
    lawSearchTestOk := RunLawSearchRegression()
    lawSearchExitCode := lawSearchTestOk ? 0 : 1
    ExitApp, %lawSearchExitCode%
}

if HasCommandLineArg("--v1-mocktest")
{
    v1MockOk := RunV1MockRegression()
    v1MockExitCode := v1MockOk ? 0 : 1
    ExitApp, %v1MockExitCode%
}

global AppInstanceMutex := 0
global LawUiPreviewMode := HasCommandLineArg("--law-ui-preview") ? 1 : 0
global UiPreviewMode := (HasCommandLineArg("--ui-preview") || LawUiPreviewMode) ? 1 : 0
global UiPreviewWindows := HasCommandLineArg("--ui-preview-windows") ? 1 : 0
global MemoryLiveTestMode := HasCommandLineArg("--memory-live-test") ? 1 : 0
if (!UiPreviewMode && !AcquireAppInstance())
    ExitApp

global AppVersion := "1.0"
global ConfigVersion := 14
global ConfigFile := FileExist(A_ScriptDir . "\profiles_updated.ini") ? A_ScriptDir . "\profiles_updated.ini" : A_ScriptDir . "\profiles.ini"
global ThemesFile := A_ScriptDir . "\themes.ini"
global LogDir := A_ScriptDir . "\logs"
global ModernLogFile := LogDir . "\amz_gos.log"
global MaxLogBytes := 262144

global CurrentProfile := "Основной"
global SettingsVisible := 0
global BindListVisible := 0
global BindOverlayVisible := 0
global hBindOverlayWnd := 0
global BindOverlayW := 400
global BindOverlayH := 500
global BindMenuEditMode := false
global BindMenuVisible := false
global hBindMenuWnd := 0
global BindMenuW := 620
global BindMenuH := 820
global HUDVisible := 1
global SettingsTargetTab := 1
global SettingsPage := "profile"
global SettingsNavLV := ""
global SettingsStatusText := ""
global SettingsLastAction := ""
global SettingsLastActionTick := 0
global SettingsNavigationBusy := 0
global SettingsGuiReady := 0
global AppExitInProgress := 0

global ThemeMode := "Graphite"
global ActionCooldownMs := 250
global SequenceLineDelay := 700
global ProfileSaveBackups := "On"
global LastActionTick := 0
global LastCuffActionTick := 0
global CuffFollowupWindowMs := 3000
global LastDejectActionTick := 0
global DejectFollowupWindowMs := 1000
global CustomMenuColor := ""
global CustomTextColor := ""
global CustomBorderColor := ""
global CustomTabColor := ""
global CustomBindListColor := ""
global UIRoundness := 18
global InnerRoundness := 14
global GuiTransparency := 225
global FullscreenSafeGui := "Auto"
global BackgroundImageURL := ""
global BackgroundImageFile := ""
global ProfileMode := "ППС"
global HUDMode := "Полный"
global MenuTransparency := 225
global HUDTransparency := 225
global BindListTransparency := 225
global SettingsX := 120
global SettingsY := 60
global SettingsW := 1180
global SettingsH := 800
global TabGuiHeaderText := "AMZ Helper | sbezruk180"

global SafeModeEnabled := "Off"
global SafeBlockWhenChat := "Off"
global SafeVehicleChecks := "Off"
global SafeRequireChatForEditable := "Off"
global SafeTooltipWarnings := "Off"
global SafeDistanceChecks := "Off"
global SafeDistanceLimit := 12
global EvidenceScreenshotMode := "Off"
global EvidenceScreenshotMethod := "Alt+F1"
global EvidenceScreenshotQueue := []
global EvidencePendingEvents := {}
global EvidenceLastCaptureTick := 0
global EvidenceDocumentContext := {}
global EvidenceDocumentActivationMode := "Только радиус"
global EvidenceDocumentWaitSec := 90
global EvidenceDocumentDistanceLimit := 20
global EvidenceDocumentWindowExpires := 0
global ChatWizardMode := ""
global TextSendMode := "Auto"
global IDEntryMode := "Перехват цифр"
global IDCaptureTimeoutSec := 3
global GameWindowTitle := "AMAZING ONLINE"
global GameProcessName := "gta_sa.exe"
global AzmpExpectedSHA256 := ""
global AzmpInfoCache := ""
global MockMode := "Off"
global ChatQueueEnabled := "On"
global ChatQueueMinDelay := 700
global ChatQueueMaxItems := 200
global ChatQueueMaxRetries := 2
global ChatTransportStatus := "Ожидание"
global ChatTransportLastMemoryFailureTick := 0
global ChatTransportMemoryRetryMs := 15000

global ChatLogReaderEnabled := "On"
global ChatLogPath := "C:\Amazing Games\Amazing Online\PC\amazing\chatlog.txt"
global ChatLogPlayerNickname := "Semen_Lukashenko"
global ChatLogAutoCleanupEnabled := "Off"
global ChatLogMaxSizeKB := 512
global ChatLogKeepTailKB := 32
global ChatLogCleanupLastCheckTick := 0
global ChatLogCleanupObservedSize := -1
global ChatLogCleanupStableSinceTick := 0
global ChatLogLastPos := 0
global ChatLogFileSeen := false
global ChatLogPendingIdResultLine := 0
global ChatLogLookupAction := ""
global ChatLogLookupVariant := ""
global ChatLogLookupName := ""
global ChatLogLookupStartedTick := 0
global ChatLogActionCooldowns := {}
global ChatLogRescuePending := 0

global AutoTargetIDEnabled := "On"
global AutoTargetCandidateID := -1
global AutoTargetCandidateReads := 0
global AutoTargetCandidatePed := 0
global AutoTargetCandidateMatchType := 0
global AutoTargetRButtonLatched := 0
global AutoTargetStableReads := 1
global AutoTargetLastScanTick := 0
global AutoTargetAimStartedTick := 0
global AutoTargetDiagCode := "INIT"
global AutoTargetDiagDetail := ""
global AutoTargetDiagFailStreak := 0
global AutoTargetDiagFirstFailTick := 0
global AutoTargetDiagLastRunTick := 0
global AutoTargetDiagLastNoticeTick := 0
global AutoTargetDiagFile := A_ScriptDir . "\logs\autoid_diagnostics.log"
global AutoTargetMaxAimAngle := 22.0

global NotifySoundEnabled := "On"
global NotifyVolume := 65
global NotifyPlayer := ""

global UserID := ""
global ActiveID := 0
global TargetNickname := ""
global TargetIsMask := 0

global ContextAssistantAction := ""
global ContextAssistantInput := ""
global ContextAssistantVariant := ""
global ContextAssistantTargetName := ""
global ContextAssistantStatus := ""
global ContextAssistantMode := ""
global hContextAssistantWnd := 0
global ContextNotificationMode := "Плашка"
global ContextNotificationTimeoutSec := 8
global AssistOOPEnabled := "On"
global AssistStunEnabled := "On"
global AssistChaseEnabled := "On"
global AssistHouseEnabled := "On"
global AssistDrugsEnabled := "On"
global AssistPDPCuffEnabled := "On"
global AssistOOPCommand := "/find {ID}"
global AssistTaserCommand := "/tazer {ID}"
global AssistBatonCommand := "/baton {ID}"

global IDOverlayVisible := 0
global hIDOverlayWnd := 0
global IDOverlayText := ""
global IDOverlayX := 20
global IDOverlayY := 420
global IDOverlayW := 120
global IDOverlayH := 34

global IntroRole := "начальником МДС ГАИ"
global Rank := "лейтенант"
global ReportRank := "лейтенант"
global ReportRole := "Начальник МДС ГАИ"
global Surname := "Лукашенко"
global PersonalBadge := ""

global PatrolRoute := "г.Арзамас"
global PostRoute := "пост: мост г. Южный"
global ConvoyRoute := "C-2, К-1"
global PatrolUnit := "Р0043"
global PatrolCrewCount := "2"
global PostUnit := "Р0049"
global PostCrewCount := "2"

global T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}."
global T_Dep := "/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь."
global T_SOSStart := "/r докладывает {SURNAME}: реагирую на вызов срочной помощи."
global T_SOSArrive := "/r докладывает {SURNAME}: прибыл на вызов срочной помощи."
global T_HijackStart := "/r Экипаж {PATROL_UNIT}, приняли сообщение об угоне, выдвигаемся."
global T_HijackArrive := "/r Экипаж {PATROL_UNIT}, прибыли по сообщению об угоне."
global T_CallStart := "/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП."
global T_CallArrive := "/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП."
global T_CallWorkStart := "/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП."
global T_CallWorkEnd := "/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП."
global T_CivilCallStart := "/r докладывает {SURNAME}: принял вызов гражданского."
global T_CivilCallArrive := "/r докладывает {SURNAME}: прибыл на вызов гражданского."
global T_PatrolStart := "/r докладывает экипаж {PATROL_UNIT}: заступили на патрулирование по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
global T_PatrolContinue := "/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
global T_PatrolEnd := "/r докладывает экипаж {PATROL_UNIT}: завершили патруль по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
global T_PostStart := "/r докладывает экипаж {POST_UNIT}: заступили на пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
global T_PostContinue := "/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
global T_PostEnd := "/r докладывает экипаж {POST_UNIT}: покинули пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
global T_ConvoyStart := "/r докладывает экипаж {PATROL_UNIT}: начали сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
global T_ConvoyCont := "/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
global T_ConvoyEnd := "/r докладывает экипаж {PATROL_UNIT}: закончили сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
global MDS_FormationInitial := "/r МДС, построение на АП ГАИ. Время на сбор — {MINUTES}. Неявка без уважительной причины — выговор по п. 8.1 ВУ ОВД."
global MDS_FormationCountdown := "/r МДС, построение на АП ГАИ. Время на сбор — {MINUTES}. Неявка без уважительной причины — выговор по п. 8.1 ВУ ОВД."
global MDS_FormationFinish := "/r МДС, построение на АП ГАИ. Время на сбор — окончено. Неявка без уважительной причины — выговор по п. 8.1 ВУ ОВД."
global RP_StopChase := "/m [ПОЛИЦИЯ] Водитель, примите вправо и остановитесь у обочины.`n/m [ПОЛИЦИЯ] Заглушите двигатель и оставайтесь в автомобиле."
global RP_Deject := "/me подошел к патрульному автомобилю.`n/me открыл дверь патрульного автомобиля.`n/me отстегнул задержанного ремнем безопасности.`n/me аккуратно достал задержанного из автомобиля"
global RP_InCar := "/me подошел к патрульному автомобилю.`n/me открыл дверь патрульного автомобиля.`n/me аккуратно посадил задержанного в автомобиль.`n/me пристегнул задержанного ремнем безопасности.`n/do Задержанный находится на заднем сиденье патрульного автомобиля."
global RP_Doc := "/do Служебное удостоверение находится в нагрудном кармане формы.`n/me достал служебное удостоверение из нагрудного кармана.`n/me раскрыл удостоверение.`n/me показал удостоверение человеку напротив.`n/me после ознакомления закрыл удостоверение.`n/me убрал удостоверение обратно в нагрудный карман"
global RP_Search := "/do Чистые резиновые перчатки находятся в кармане формы.`n/me достал резиновые перчатки из кармана.`n/me надел резиновые перчатки на руки.`n/do Резиновые перчатки надеты.`n/me начал проводить личный досмотр человека напротив.`n/me проверил карманы, пояс и личные вещи гражданина.`n/me внимательно осмотрел содержимое карманов.`n/do Личный досмотр гражданина завершен."
global RP_TowStart := "/r докладывает {SURNAME}: начал эвакуировать ТС на штрафстоянку.`n/me подошел к эвакуируемому автомобилю.`n/me достал крюк эвакуатора и закрепил его за автомобиль.`n/do Крюк эвакуатора закреплен на автомобиле.`n/tow"
global RP_TowEnd := "/me остановил эвакуатор на территории штраф стоянки.`n/me отцепил крюк эвакуатора от автомобиля.`n/do Автомобиль находится на территории штраф стоянки.`n/r докладывает {SURNAME}: эвакуировал ТС на штрафстоянку."
global RP_CarSearch := "/do Резиновые перчатки находятся в кармане формы.`n/me достал резиновые перчатки из кармана.`n/me надел резиновые перчатки на руки.`n/do Перчатки надеты.`n/me открыл дверь автомобиля.`n/me начал осматривать салон автомобиля.`n/me проверил бардачок, карманы дверей и пространство под сиденьями.`n/me открыл багажник автомобиля.`n/me внимательно осмотрел содержимое багажника.`n/do Досмотр транспортного средства завершен."
global RP_Arrest := "/me взял рацию с плеча.`n/me нажал кнопку передачи на рации.`n/me вызвал дежурного.`n/do Сообщение по рации передано дежурному.`n/do Дежурный подошел к сотруднику полиции.`n/me передал задержанного дежурному.`n/me передал сопроводительную информацию по задержанному.`n/do Дежурный увел задержанного и поместил его в КПЗ."
global RP_Fine := "/do КПК находится в подсумке на поясе сотрудника.`n/me достал КПК из подсумка.`n/me включил КПК.`n/me авторизовался в системе МВД.`n/me ввел данные гражданина с лицензии.`n/do Данные гражданина найдены в базе данных.`n/me начал оформлять штраф через КПК.`n/me внес статью нарушения и сумму штрафа.`n/do Штраф успешно оформлен."
global RP_Protocol := "/do Бланк протокола находится в планшете сотрудника.`n/me достал бланк протокола и ручку.`n/me разложил бланк протокола на планшете.`n/me начал заполнять протокол.`n/me вписал личные данные задержанного.`n/me указал обстоятельства и причину задержания.`n/me указал дату и время составления протокола.`n/me внимательно проверил заполненные данные.`n/me поставил подпись в протоколе.`n/do Протокол заполнен.`nРасписываться в протоколе будете?"
global RP_Rights := "Вы имеете право на отказ от дачи показаний против себя и своих близких.`nВы имеете на ознакомление со всеми протоколами, составленными при задержании.`nВы имеете право на адвоката, переводчика и медицинскую помощь. Вам они будут предоставлены в ИВС.`nВы имеете право на один телефонный звонок.`nЕсли вы желаете обжаловать задержание, можете оставить жалобу на официальном портале области."
global RP_CardDS := "/me достал визитку из нагрудного кармана и передал человеку напротив.`n/b Это дискорд: «sbezruk180.»"
global RP_CardVK := "/me достал визитку из нагрудного кармана и передал человеку напротив.`n/b Это ВК: «sbezruk180.»"

global Bind_OpenSettings := "F10"
global Bind_ToggleBindList := "F11"
global Bind_ToggleHUD := "F12"
global Bind_IDOverlay := "F5"
global Bind_ConfirmID := "F1"
global Bind_RejectID := "F2"
global Bind_ToggleLastLawDoc := ""
global Bind_HideLawGui := "Pause"
global IDCheckEnabled := True
global LawGuiTextColor := "FFFFFF"
global LawGuiBgColor := "000000"
global SearchModeActive := 0
global SearchDoc := ""
global SearchDocName := ""
global SearchLastQuery := ""
global SearchResults := ""
global SearchCurrentIndex := 0
global SearchCurrentPart := 1
global SearchGuiVisible := 0
global SearchInitialized := 0
global SearchIndex := ""
global SearchIndexCounts := ""
global SearchLastPossible := 0
global SearchLastChecked := 0
global SearchLastPassed := 0
global SearchMinScore := 0
global hStopTimerWnd := 0
global StopTimerActive := 0
global StopTimerCustomSound := ""
global StopTimerCounter := 0
global StopTimerX := 100
global StopTimerY := 90
global StopTimerLabel := ""
global StopTimerCount := ""
global StopTimerWidth := 170
global StopTimerHeight := 76
global StopTimerTransparency := 255
global StopTimerBorderColor := ""
global StopTimerTextColor := ""
global StopTimerBgColor := ""
global StopTimerVolume := 65
global StopTimerPlayer := ""
global Bind_ResetID := "^Numpad0"

global Bind_EnterID := "!1"
global Bind_Intro := "!2"
global Bind_Chase := "!3"
global Bind_ChaseNoID := "Insert"
global Bind_LawSearchSubmit := "^+f"
global Bind_Deject := "!4"
global Bind_Cuff := "!5"
global Bind_InCar := "!6"
global Bind_StopChase := "!7"
global Bind_Doc := "!8"
global Bind_Search := "!9"
global Bind_SOS := "F9"

global Bind_Dep := ""
global Bind_WantedList := ""
global Bind_SOSStart := ""
global Bind_SOSArrive := ""
global Bind_HijackStart := ""
global Bind_HijackArrive := ""
global Bind_CallStart := ""
global Bind_CallArrive := ""
global Bind_CallWorkStart := ""
global Bind_CallWorkEnd := ""
global Bind_CivilCallStart := ""
global Bind_CivilCallArrive := ""
global Bind_VehicleLookup := ""
global Bind_WantedRemoval := ""
global Bind_PatrolStart := ""
global Bind_PatrolCont := ""
global Bind_PatrolEnd := ""
global Bind_PostStart := ""
global Bind_PostCont := ""
global Bind_PostEnd := ""
global Bind_ConvoyStart := ""
global Bind_ConvoyCont := ""
global Bind_ConvoyEnd := ""
global Bind_TowStart := ""
global Bind_TowEnd := ""
global Bind_CarSearch := ""
global Bind_Arrest := ""
global Bind_Fine := ""
global Bind_Protocol := ""
global Bind_Rights := ""
global Bind_CardDS := ""
global Bind_CardVK := ""
global Bind_MDSFormation := ""
global Bind_AutoPatrol := ""
global Bind_AutoPost := ""
global Bind_AssistOOP := ""
global Bind_AssistStun := ""
global Bind_AssistChase := ""
global Bind_AssistHouse := ""
global Bind_AssistDrugs := ""
global Bind_AssistPDPCuff := ""
global Bind_OpenBindsTab := ""
global Bind_MaskCall := ""
global Bind_RecordCheck := ""
global Bind_TrainCrash := ""
global Bind_PersonalFile := ""
global Bind_Su := ""
global Bind_MDC := ""

global MDSFormationActive := 0
global MDSFormationEndTick := 0
global MDSFormationLastMinute := -1
global MDSFormationMaxMinutes := 60
global AutoReportMode := "Патруль"
global AutoReportDurationMin := 15
global TerritoryMapMode := "Local"
global AutoReportActive := 0
global AutoReportStartTick := 0
global AutoReportEndTick := 0
global AutoReportNextTick := 0
global AutoReportLastDispatchTick := 0
global AutoReportSentCount := 0
global AutoReportSkippedCount := 0
global EvacuationTimerEnabled := "On"
global PatrolTimerEnabled := "On"
global PostTimerEnabled := "On"
global ActionTimerItems := {}
global hActionTimerWnd := 0
global ActionTimerBody := ""
global ActionTimerLastHeight := 0
global ActionTimerRenderBusy := 0
global ActionTimerX := 100
global ActionTimerY := 180

global CFG_ProfileName := ""
global CFG_ThemeMode := ""
global CFG_ActionCooldownMs := ""
global CFG_SequenceLineDelay := ""
global CFG_ProfileSaveBackups := ""
global CFG_CustomMenuColor := ""
global CFG_CustomTextColor := ""
global CFG_CustomBorderColor := ""
global CFG_CustomTabColor := ""
global CFG_CustomBindListColor := ""
global CFG_UIRoundness := ""
global CFG_InnerRoundness := ""
global CFG_GuiTransparency := ""
global CFG_BackgroundImageURL := ""
global CFG_FullscreenSafeGui := ""
global CFG_ProfileMode := ""
global CFG_SettingsPageIdx := 1
global CFG_HUDMode := ""
global CFG_MenuTransparency := ""
global CFG_HUDTransparency := ""
global CFG_BindListTransparency := ""
global CFG_SafeModeEnabled := ""
global CFG_SafeBlockWhenChat := ""
global CFG_SafeVehicleChecks := ""
global CFG_SafeRequireChatForEditable := ""
global CFG_SafeTooltipWarnings := ""
global CFG_SafeDistanceChecks := ""
global CFG_SafeDistanceLimit := ""
global CFG_EvidenceScreenshotMode := ""
global CFG_EvidenceScreenshotMethod := ""
global CFG_EvidenceDocumentActivationMode := ""
global CFG_EvidenceDocumentWaitSec := ""
global CFG_EvidenceDocumentDistanceLimit := ""
global CFG_IDCheckEnabled := ""
global CFG_StopTimerVolume := ""
global CFG_EvacuationTimerEnabled := ""
global CFG_PatrolTimerEnabled := ""
global CFG_PostTimerEnabled := ""
global CFG_TextSendMode := ""
global CFG_ChatTypingDelayMs := ""
global CFG_ChatFactionCommands := ""
global CFG_IDEntryMode := ""
global CFG_IDCaptureTimeoutSec := ""
global CFG_GameWindowTitle := ""
global CFG_GameProcessName := ""
global CFG_AzmpExpectedSHA256 := ""
global CFG_MockMode := ""
global CFG_ChatQueueEnabled := ""
global CFG_ChatQueueMinDelay := ""
global CFG_ChatLogReaderEnabled := ""
global CFG_ChatLogPath := ""
global CFG_ChatLogPlayerNickname := ""
global CFG_AutoTargetIDEnabled := 1
global CFG_ContextNotificationMode := ""
global CFG_ContextNotificationTimeoutSec := ""
global CFG_AssistOOPEnabled := 1
global CFG_AssistStunEnabled := 1
global CFG_AssistChaseEnabled := 1
global CFG_AssistHouseEnabled := 1
global CFG_AssistDrugsEnabled := 1
global CFG_AssistPDPCuffEnabled := 1

global CFG_NotifySoundEnabled := ""
global CFG_NotifyVolume := ""
global CFG_IntroRole := ""
global CFG_Rank := ""
global CFG_ReportRank := ""
global CFG_ReportRole := ""
global CFG_Surname := ""
global CFG_PersonalBadge := ""
global CFG_PatrolRoute := ""
global CFG_PostRoute := ""
global CFG_ConvoyRoute := ""
global CFG_PatrolUnit := ""
global CFG_PatrolCrewCount := ""
global CFG_PostUnit := ""
global CFG_PostCrewCount := ""
global CFG_T_Intro := ""
global CFG_T_Dep := ""
global CFG_T_SOSStart := ""
global CFG_T_SOSArrive := ""
global CFG_T_HijackStart := ""
global CFG_T_HijackArrive := ""
global CFG_T_CallStart := ""
global CFG_T_CallArrive := ""
global CFG_T_CallWorkStart := ""
global CFG_T_CallWorkEnd := ""
global CFG_T_CivilCallStart := ""
global CFG_T_CivilCallArrive := ""
global CFG_T_PatrolStart := ""
global CFG_T_PatrolContinue := ""
global CFG_T_PatrolEnd := ""
global CFG_T_PostStart := ""
global CFG_T_PostContinue := ""
global CFG_T_PostEnd := ""
global CFG_T_ConvoyStart := ""
global CFG_T_ConvoyCont := ""
global CFG_T_ConvoyEnd := ""
global CFG_MDS_FormationInitial := ""
global CFG_MDS_FormationCountdown := ""
global CFG_MDS_FormationFinish := ""

global CFG_RP_StopChase := ""
global CFG_RP_Deject := ""
global CFG_RP_InCar := ""
global CFG_RP_Doc := ""
global CFG_RP_Search := ""
global CFG_RP_TowStart := ""
global CFG_RP_TowEnd := ""
global CFG_RP_CarSearch := ""
global CFG_RP_Arrest := ""
global CFG_RP_Fine := ""
global CFG_RP_Protocol := ""
global CFG_RP_Rights := ""
global CFG_RP_CardDS := ""
global CFG_RP_CardVK := ""

global BindListItems := "OpenBindsTab`nAutoPatrol`nAutoPost`nConfirmID`nRejectID`nIntro`nSOS`nEnterID`nResetID`nChase`nChaseNoID`nDeject`nCuff`nInCar`nStopChase`nDoc`nSearch`nPersonalFile`nSu`nVehicleLookup`nWantedRemoval`nCivilCallStart`nCivilCallArrive`nMaskCall`nRecordCheck`nTrainCrash`nGpsD`nGpsOS`nVU`nFP`nKON`nFZOP`nTER`nTK`nARG`nUK`nVV`nKOAP`nPDD`nORUZH`nUPK`nKAS`nFSB`nFSIN`nVS`nSUD`nORD`nGT"

global Trig_VU := "!вузакон"
global Trig_FP := "!фп"
global Trig_KON := "!кон"
global Trig_FZOP := "!фзоп"
global Trig_TER := "!тер"
global Trig_TK := "!тк"
global Trig_ARG := "!арг"
global Trig_UK := "!ук"
global Trig_VV := "!вв"
global Trig_KOAP := "!коап"
global Trig_PDD := "!пдд"
global Trig_ORUZH := "!оруж"
global Trig_UPK := "!упк"
global Trig_KAS := "!кас"
global Trig_FSB := "!фсб"
global Trig_FSIN := "!фсин"
global Trig_VS := "!фзовс"
global Trig_SUD := "!суд"
global Trig_ORD := "!орд"
global Trig_GT := "!гостайна"

global Trig_Intro := ""
global Trig_SOS := ""
global Trig_EnterID := ""
global Trig_ResetID := ""
global Trig_Chase := ""
global Trig_ChaseNoID := ""
global Trig_Deject := ""
global Trig_Cuff := ""
global Trig_InCar := ""
global Trig_StopChase := ""
global Trig_Doc := ""
global Trig_Search := ""
global Trig_Dep := "!деп"
global Trig_WantedList := "!р"
global Trig_SOSStart := "!сос"
global Trig_SOSArrive := "!сос1"
global Trig_HijackStart := "!угон"
global Trig_HijackArrive := "!угон1"
global Trig_CallStart := "!выз"
global Trig_CallArrive := "!выз1"
global Trig_CallWorkStart := ""
global Trig_CallWorkEnd := ""
global Trig_CivilCallStart := ""
global Trig_CivilCallArrive := ""
global Trig_VehicleLookup := "!поисктс"
global Trig_WantedRemoval := "!снятие"
global Trig_PatrolStart := "!патруль"
global Trig_PatrolCont := "!патруль1"
global Trig_PatrolEnd := "!патруль2"
global Trig_PostStart := "!пост"
global Trig_PostCont := "!пост1"
global Trig_PostEnd := "!пост2"
global Trig_ConvoyStart := "!вк"
global Trig_ConvoyCont := ""
global Trig_ConvoyEnd := "!вк1"
global Trig_TowStart := "!эв"
global Trig_TowEnd := "!эв1"
global Trig_CarSearch := "!обтс"
global Trig_Arrest := "!ар"
global Trig_Fine := "!ш"
global Trig_Protocol := "!протокол"
global Trig_Rights := "!права"
global Trig_CardDS := "!визиткадс"
global Trig_CardVK := "!визиткавк"
global Trig_MDSFormation := "!строй"
global Trig_AutoPatrol := "!апатруль"
global Trig_AutoPost := "!апост"
global Trig_AssistOOP := "!ооп"
global Trig_AssistStun := "!оглуш"
global Trig_AssistChase := "!погоня"
global Trig_AssistHouse := "!домgps"
global Trig_AssistDrugs := "!наркоид"
global Trig_AssistPDPCuff := "!пдпнаруч"
global Trig_OpenBindsTab := "!бинды"
global Trig_MaskCall := "!м"
global Trig_RecordCheck := "!упр"
global Trig_TrainCrash := "!поезд"
global Trig_PersonalFile := "!лд"
global Trig_Su := "!су"
global Trig_GpsD := "!д"
global Trig_GpsOS := "!ос"

global Prev_Trig_Intro := ""
global Prev_Trig_SOS := ""
global Prev_Trig_EnterID := ""
global Prev_Trig_ResetID := ""
global Prev_Trig_Chase := ""
global Prev_Trig_Deject := ""
global Prev_Trig_Cuff := ""
global Prev_Trig_InCar := ""
global Prev_Trig_StopChase := ""
global Prev_Trig_Doc := ""
global Prev_Trig_Search := ""
global Prev_Trig_Dep := ""
global Prev_Trig_WantedList := ""
global Prev_Trig_SOSStart := ""
global Prev_Trig_SOSArrive := ""
global Prev_Trig_HijackStart := ""
global Prev_Trig_HijackArrive := ""
global Prev_Trig_CallStart := ""
global Prev_Trig_CallArrive := ""
global Prev_Trig_CallWorkStart := ""
global Prev_Trig_CallWorkEnd := ""
global Prev_Trig_PatrolStart := ""
global Prev_Trig_PatrolCont := ""
global Prev_Trig_PatrolEnd := ""
global Prev_Trig_PostStart := ""
global Prev_Trig_PostCont := ""
global Prev_Trig_PostEnd := ""
global Prev_Trig_ConvoyStart := ""
global Prev_Trig_ConvoyCont := ""
global Prev_Trig_ConvoyEnd := ""
global Prev_Trig_TowStart := ""
global Prev_Trig_TowEnd := ""
global Prev_Trig_CarSearch := ""
global Prev_Trig_Arrest := ""
global Prev_Trig_Fine := ""
global Prev_Trig_Protocol := ""
global Prev_Trig_Rights := ""
global Prev_Trig_CardDS := ""
global Prev_Trig_CardVK := ""
global Prev_Trig_MDSFormation := ""
global Prev_Trig_AssistOOP := ""
global Prev_Trig_AssistStun := ""
global Prev_Trig_AssistChase := ""
global Prev_Trig_AssistHouse := ""
global Prev_Trig_AssistDrugs := ""
global Prev_Trig_AssistPDPCuff := ""
global Prev_Trig_OpenBindsTab := ""
global Prev_Trig_MaskCall := ""
global Prev_Trig_RecordCheck := ""
global Prev_Trig_TrainCrash := ""
global Prev_Trig_PersonalFile := ""
global Prev_Trig_Su := ""
global Prev_Trig_GpsD := ""
global Prev_Trig_GpsOS := ""
global Prev_Trig_MDC := ""

global Prev_Trig_VU := ""
global Prev_Trig_FP := ""
global Prev_Trig_KON := ""
global Prev_Trig_FZOP := ""
global Prev_Trig_TER := ""
global Prev_Trig_TK := ""
global Prev_Trig_ARG := ""
global Prev_Trig_UK := ""
global Prev_Trig_VV := ""
global Prev_Trig_KOAP := ""
global Prev_Trig_PDD := ""
global Prev_Trig_ORUZH := ""
global Prev_Trig_UPK := ""
global Prev_Trig_KAS := ""
global Prev_Trig_FSB := ""
global Prev_Trig_FSIN := ""
global Prev_Trig_VS := ""
global Prev_Trig_SUD := ""
global Prev_Trig_ORD := ""
global Prev_Trig_GT := ""
global Prev_Trig_BindMenu := ""
global Prev_Trig_VehicleLookup := ""
global Prev_Trig_WantedRemoval := ""
global Prev_Trig_Codes := ""
global ServiceCodesGuiVisible := 0
global Prev_SearchTrig_ALL := ""
global Prev_SearchTrig_KOAP := ""
global Prev_SearchTrig_UK := ""
global Prev_SearchTrig_UPK := ""
global Prev_SearchTrig_KAS := ""
global Prev_SearchTrig_FSB := ""
global Prev_SearchTrig_FSIN := ""
global Prev_SearchTrig_VS := ""
global Prev_SearchTrig_SUD := ""
global Prev_SearchTrig_ORD := ""
global Prev_SearchTrig_GT := ""
global Prev_SearchTrig_PDD := ""
global Prev_SearchTrig_FZOP := ""
global Prev_SearchTrig_TK := ""
global Prev_SearchTrig_TER := ""
global Prev_SearchTrig_ARG := ""
global Prev_SearchTrig_VU := ""
global Prev_SearchTrig_VV := ""
global Prev_SearchTrig_ORUZH := ""
global Prev_SearchTrig_KON := ""
global Prev_SearchTrig_RUN := ""

global CFG_Trig_Intro := ""
global CFG_Trig_SOS := ""
global CFG_Trig_EnterID := ""
global CFG_Trig_ResetID := ""
global CFG_Trig_Chase := ""
global CFG_Trig_ChaseNoID := ""
global CFG_Trig_Deject := ""
global CFG_Trig_Cuff := ""
global CFG_Trig_InCar := ""
global CFG_Trig_StopChase := ""
global CFG_Trig_Doc := ""
global CFG_Trig_Search := ""
global CFG_Trig_Dep := ""
global CFG_Trig_WantedList := ""
global CFG_Trig_SOSStart := ""
global CFG_Trig_SOSArrive := ""
global CFG_Trig_HijackStart := ""
global CFG_Trig_HijackArrive := ""
global CFG_Trig_CallStart := ""
global CFG_Trig_CallArrive := ""
global CFG_Trig_CallWorkStart := ""
global CFG_Trig_CallWorkEnd := ""
global CFG_Trig_CivilCallStart := ""
global CFG_Trig_CivilCallArrive := ""
global CFG_Trig_VehicleLookup := ""
global CFG_Trig_WantedRemoval := ""
global CFG_Trig_PatrolStart := ""
global CFG_Trig_PatrolCont := ""
global CFG_Trig_PatrolEnd := ""
global CFG_Trig_PostStart := ""
global CFG_Trig_PostCont := ""
global CFG_Trig_PostEnd := ""
global CFG_Trig_ConvoyStart := ""
global CFG_Trig_ConvoyCont := ""
global CFG_Trig_ConvoyEnd := ""
global CFG_Trig_TowStart := ""
global CFG_Trig_TowEnd := ""
global CFG_Trig_CarSearch := ""
global CFG_Trig_Arrest := ""
global CFG_Trig_Fine := ""
global CFG_Trig_Protocol := ""
global CFG_Trig_Rights := ""
global CFG_Trig_CardDS := ""
global CFG_Trig_CardVK := ""
global CFG_Trig_MDSFormation := ""
global CFG_Trig_AutoPatrol := ""
global CFG_Trig_AutoPost := ""
global CFG_Trig_AssistOOP := ""
global CFG_Trig_AssistStun := ""
global CFG_Trig_AssistChase := ""
global CFG_Trig_AssistHouse := ""
global CFG_Trig_AssistDrugs := ""
global CFG_Trig_AssistPDPCuff := ""
global CFG_Trig_OpenBindsTab := ""
global CFG_Trig_MaskCall := ""
global CFG_Trig_RecordCheck := ""
global CFG_Trig_TrainCrash := ""
global CFG_Trig_PersonalFile := ""
global CFG_Trig_Su := ""
global CFG_Trig_GpsD := ""
global CFG_Trig_GpsOS := ""
global CFG_Trig_MDC := ""
global CFG_Trig_VU := ""
global CFG_Trig_FP := ""
global CFG_Trig_KON := ""
global CFG_Trig_FZOP := ""
global CFG_Trig_TER := ""
global CFG_Trig_TK := ""
global CFG_Trig_ARG := ""
global CFG_Trig_UK := ""
global CFG_Trig_VV := ""
global CFG_Trig_KOAP := ""
global CFG_Trig_PDD := ""
global CFG_Trig_ORUZH := ""
global CFG_Trig_UPK := ""
global CFG_Trig_KAS := ""
global CFG_Trig_FSB := ""
global CFG_Trig_FSIN := ""
global CFG_Trig_VS := ""
global CFG_Trig_SUD := ""
global CFG_Trig_ORD := ""
global CFG_Trig_GT := ""
global CFG_BindListItems := ""
global CFG_ThemePresetName := ""
global CFG_TabGuiHeaderText := ""

global BindListLV := ""
global BindListInfoText := ""
global BindListTitleText := ""
global BindListProfileText := ""
global BindListResizeGripText := ""
global BindListRefreshText := ""
global BindListCloseText := ""
global SettingsBG := ""
global HUDBG := ""
global BindListBG := ""
global HUDBorderTop := ""
global HUDBorderBottom := ""
global HUDBorderLeft := ""
global HUDBorderRight := ""
global BindListBorderTop := ""
global BindListBorderBottom := ""
global BindListBorderLeft := ""
global BindListBorderRight := ""

global CFG_Bind_OpenSettings := ""
global CFG_Bind_ToggleLastLawDoc := ""
global CFG_Bind_HideLawGui := ""
global CFG_Bind_ToggleBindList := ""
global CFG_Bind_ToggleHUD := ""
global CFG_Bind_IDOverlay := ""
global CFG_Bind_ConfirmID := ""
global CFG_Bind_RejectID := ""
global CFG_Bind_ResetID := ""
global CFG_Bind_EnterID := ""
global CFG_Bind_Intro := ""
global CFG_Bind_Chase := ""
global CFG_Bind_ChaseNoID := ""
global CFG_Bind_LawSearchSubmit := ""
global CFG_Bind_Deject := ""
global CFG_Bind_Cuff := ""
global CFG_Bind_InCar := ""
global CFG_Bind_StopChase := ""
global CFG_Bind_Doc := ""
global CFG_Bind_Search := ""
global CFG_Bind_SOS := ""
global CFG_Bind_Dep := ""
global CFG_Bind_WantedList := ""
global CFG_Bind_SOSStart := ""
global CFG_Bind_SOSArrive := ""
global CFG_Bind_HijackStart := ""
global CFG_Bind_HijackArrive := ""
global CFG_Bind_CallStart := ""
global CFG_Bind_CallArrive := ""
global CFG_Bind_CallWorkStart := ""
global CFG_Bind_CallWorkEnd := ""
global CFG_Bind_CivilCallStart := ""
global CFG_Bind_CivilCallArrive := ""
global CFG_Bind_VehicleLookup := ""
global CFG_Bind_WantedRemoval := ""
global CFG_Bind_PatrolStart := ""
global CFG_Bind_PatrolCont := ""
global CFG_Bind_PatrolEnd := ""
global CFG_Bind_PostStart := ""
global CFG_Bind_PostCont := ""
global CFG_Bind_PostEnd := ""
global CFG_Bind_ConvoyStart := ""
global CFG_Bind_ConvoyCont := ""
global CFG_Bind_ConvoyEnd := ""
global CFG_Bind_TowStart := ""
global CFG_Bind_TowEnd := ""
global CFG_Bind_CarSearch := ""
global CFG_Bind_Arrest := ""
global CFG_Bind_Fine := ""
global CFG_Bind_Protocol := ""
global CFG_Bind_Rights := ""
global CFG_Bind_CardDS := ""
global CFG_Bind_CardVK := ""
global CFG_Bind_MDSFormation := ""
global CFG_Bind_AutoPatrol := ""
global CFG_Bind_AutoPost := ""
global CFG_Bind_AssistOOP := ""
global CFG_Bind_AssistStun := ""
global CFG_Bind_AssistChase := ""
global CFG_Bind_AssistHouse := ""
global CFG_Bind_AssistDrugs := ""
global CFG_Bind_AssistPDPCuff := ""
global CFG_Bind_OpenBindsTab := ""
global CFG_Bind_MaskCall := ""
global CFG_Bind_RecordCheck := ""
global CFG_Bind_TrainCrash := ""
global CFG_Bind_PersonalFile := ""
global CFG_Bind_Su := ""
global CFG_Bind_MDC := ""

global SettingsTabs := ""
global HUDTimeText := ""
global HUDProfileText := ""
global HUDIDText := ""
global HUDMenuText := ""
global HUDBindListText := ""

global HudX := 10
global HudY := 10
global BindListX := 300
global BindListY := 70
global BindListW := 460
global BindListH := 330
global BindListSearch := ""
global BindListCategory := "Все"
global BindListSearchEdit := ""
global BindListCategoryDDL := ""
global hBindListCategoryDDL := 0
global BindListCountText := ""

global hHUDWnd := 0
global hBindListWnd := 0
global hSettingsWnd := 0
global hBindListLV := 0

global BindListDragFromRow := 0
global BindListDragHoverRow := 0
global BindListDragActive := 0
global GuiHotkeyActionMap := {}
global HotkeyDispatchMap := {}
global RegisteredBindHotkeys := []
global IDConfirmHotkeyContext := Func("ContextAssistant_IDHotkeyContext")
global RegisteredGameTextHotstrings := []
global BindMenuTextTriggersSuspended := false
global PendingHUDVisible := -1
global PendingBindListVisible := -1
global PendingSettingsVisible := -1

global CustomFunctionsFile := A_ScriptDir . "\custom_functions.ini"
global CustomFunctions := []
global CustomFunctionMaxCount := 20
global CustomFunctionSelected := 0
global CustomFunctionGuiVisible := 0
global hCustomFunctionWnd := 0
global CustomFunctionHotkeyMap := {}
global CustomFunctionRegisteredHotkeys := []
global CustomFunctionHotkeyContext := Func("CustomFunction_HotkeyAllowed")
global GameTextHotkeyContext := Func("GameTextTriggerAllowed")
global CustomFunctionRunState := ""
global CFB_List := ""
global CFB_Name := ""
global CFB_Hotkey := ""
global CFB_Trigger := ""
global CFB_Script := ""
global CFB_Status := ""
global hCFBScript := 0

global CFG_BindsStatusText := ""
global CFG_AutoReportMode := ""
global CFG_AutoReportDurationMin := ""
global CFG_TerritoryMapMode := ""
global CFG_AutoReportStatus := "Автодоклад: выключен"
global TaskSchedulerItems := {}
global TaskSchedulerBusy := 0
global TaskSchedulerNextDueTick := 0
global TaskSchedulerLastStatusTick := 0
global TaskSchedulerGeneration := 0
global TaskSchedulerMaxCallbacksPerTick := 3
global ChatQueueItems := []
global ChatQueueBusy := 0
global ChatQueueLastSendTick := 0
global ChatQueueNextSendTick := 0
global ChatQueuePreviewText := ""
global ChatQueuePreviewLineCount := 0
global ChatQueuePreviewKnownLength := 0
global hMockPreviewWnd := 0
global MockPreviewEdit := ""
global MockPreviewCountText := ""
global PendingToolPid := 0
global PendingToolReport := ""
global MemoryLiveTestResult := ""

global flvu1 := False
global flfp1 := False
global flkon1 := False
global flfzop1 := False
global flter1 := False
global fltk1 := False
global flarg1 := False
global fluk1 := False
global flvv1 := False
global flkoap1 := False
global flpdd1 := False
global floruzh1 := False
global flupk1 := False
global flkas1 := False
global flfsb1 := False
global flfsin1 := False
global flvs1 := False
global flsud1 := False
global flord1 := False
global flgt1 := False
global current_doc := 0
global last_doc := 0
global LawDocCurrentPages := {}
global ErrorLogFile := A_ScriptDir . "\error_log.txt"

InitProfiles()
MigrateConfigIfNeeded()
LoadUISettings()
LoadWindowStates()
LoadLastProfile()
LoadCustomFunctions()
InitChatLogReader()
if (MemoryLiveTestMode)
{
    OnExit, HandleAppExit
    SetTimer, TaskSchedulerTimerTick, 100
    SetTimer, RunMemoryLiveTestCliLabel, -120
    LogError("MemoryLiveTest", "Isolated CLI live-test startup", "INFO")
    return
}
if (UiPreviewMode)
{
    MockMode := "On"
    SettingsVisible := 1
    SettingsPage := LawUiPreviewMode ? "documents" : "profile"
    SettingsTargetTab := SettingsPageIndex(SettingsPage)
    if (UiPreviewWindows)
    {
        HUDVisible := 1
        BindListVisible := 1
        CreateHUD()
        UpdateHUD()
        CreateBindList()
        UpdateBindList()
    }
}
else
{
    ApplyAllBinds()
    CreateHUD()
    UpdateHUD()
    if (!HUDVisible)
        Gui, 12:Hide
    if (BindListVisible)
    {
        CreateBindList()
        UpdateBindList()
    }
}
if (SettingsVisible || UiPreviewMode)
    OpenSettings(SettingsPage)
if (LawUiPreviewMode)
    SetTimer, LawUiPreviewOpenTimer, -350
SetupTrayMenu()
OnMessage(0x232, "WM_EXITSIZEMOVE")
OnMessage(0x115, "Settings_ScrollMessage")
OnMessage(0x114, "Settings_ScrollMessage")
OnMessage(0x20A, "Settings_MouseWheel")
SetTimer, MemoryRemotePollTimer, 50
SetTimer, CaptureRefreshTimer, 300
OnMessage(0x201, "BindList_OnLButtonDown")
OnMessage(0x200, "BindList_OnMouseMove")
OnMessage(0x202, "BindList_OnLButtonUp")
OnMessage(0x111, "BindList_OnCommand")
OnMessage(0x84, "WM_NCHITTEST")
OnExit, HandleAppExit
SetTimer, UpdateHUDTimer, 1000
SetTimer, TaskSchedulerTimerTick, 100
SetTimer, ChatQueueTimerTick, 150
SetTimer, ChatLogReaderTick, 250
SetTimer, AutoTargetIDTick, Off
LogError("System", "Script start", "INFO")
return

HasCommandLineArg(argName) {
    argName := Trim(argName)
    if (argName = "")
        return false

    argLower := argName
    StringLower, argLower, argLower

    if IsObject(A_Args)
    {
        for index, argValue in A_Args
        {
            argCheck := Trim(argValue)
            StringLower, argCheck, argCheck
            if (argCheck = argLower)
                return true
        }
    }

    Loop, %0%
    {
        legacyArg := %A_Index%
        argCheck := Trim(legacyArg)
        StringLower, argCheck, argCheck
        if (argCheck = argLower)
            return true
    }

    cmdLine := DllCall("GetCommandLine", "Str")
    cmdLineLower := cmdLine
    StringLower, cmdLineLower, cmdLineLower
    return InStr(" " . cmdLineLower . " ", " " . argLower . " ") > 0
}

RunContextAssistantMockTest() {
    global MockMode, ChatQueueEnabled, ChatQueueMinDelay, ChatQueueItems, ChatQueueBusy
    global ChatQueueLastSendTick, ChatQueueNextSendTick
    global ChatQueuePreviewText, ChatTransportStatus, ActionCooldownMs, LastActionTick
    global SafeModeEnabled, SafeBlockWhenChat, SafeDistanceChecks, SafeTooltipWarnings
    global NotifySoundEnabled, ThemeMode, AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    global UserID, ActiveID, ModernLogFile, ErrorLogFile, LogDir, MaxLogBytes

    MockMode := "On"
    ChatQueueEnabled := "Off"
    ChatQueueMinDelay := 250
    ChatQueueItems := []
    ChatQueueBusy := 0
    ChatQueuePreviewText := ""
    ChatTransportStatus := "Ожидание"
    ActionCooldownMs := 0
    LastActionTick := 0
    SafeModeEnabled := "Off"
    SafeBlockWhenChat := "Off"
    SafeDistanceChecks := "Off"
    SafeTooltipWarnings := "Off"
    NotifySoundEnabled := "Off"
    ThemeMode := "Graphite"
    AssistOOPCommand := "/find {ID}"
    AssistTaserCommand := "/tazer {ID}"
    AssistBatonCommand := "/baton {ID}"
    UserID := ""
    ActiveID := 0
    LogDir := A_ScriptDir . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    ErrorLogFile := A_ScriptDir . "\error_log.txt"
    MaxLogBytes := 262144

    ok := true
    ok := ContextAssistant_Execute("OOPSearch", "41") && ok
    ok := ContextAssistant_Execute("Stun", "42", "taser") && ok
    ok := ContextAssistant_Execute("Stun", "43", "baton") && ok
    ok := ContextAssistant_Execute("Chase", "44") && ok
    ok := ContextAssistant_Execute("Chase", "1002") && ok
    ok := ContextAssistant_Execute("HouseAlarm", "155") && ok
    ok := ContextAssistant_Execute("DrugsNearby", "46") && ok
    ok := ContextAssistant_Execute("PDPCuff", "47") && ok

    parserIdOk := (ChatLogReader_ExtractID("Вы оглушили Test_Player[77] с помощью электрошокера") = 77)
    parserChaseTargetOk := (ChatLogReader_ExtractChaseTargetID("Officer_Name[15] начал преследование Player_Name[77]") = 77)
    parserChaseSingleOk := (ChatLogReader_ExtractChaseTargetID("Вы начали преследование Player_Name[88]") = 88)
    parserNameOk := (ChatLogReader_ExtractNickname("Вы оглушили Test_Player с помощью электрошокера") = "Test_Player")
    ChatQueue_Clear(0)
    ChatQueueLastSendTick := 0
    ChatQueueNextSendTick := 0
    lookupQueueOk := ChatLogReader_BeginLookup("OOPSearch", "Test_Player")
    ChatQueue_Tick()
    lookupQueueOk := lookupQueueOk && InStr(ChatQueuePreviewText, "/id Test_Player")
    ChatLogReader_ClearLookup()
    ok := parserIdOk && parserChaseTargetOk && parserChaseSingleOk && parserNameOk && lookupQueueOk && ok

    expectedLines := ["/find 41", "/tazer 42", "/baton 43", "/chase 44", "/chase 1002", "[GPS] Отметить дом №155 по сигнализации", "[ID] Наркотики рядом — сохранён ID 46", "/cuff 47", "/id Test_Player"]
    report := "AHK FOR GOS BY SBEZRUK context assistant MockMode test`r`n"
    report .= "Time: " . A_YYYY . "-" . A_MM . "-" . A_DD . " " . A_Hour . ":" . A_Min . ":" . A_Sec . "`r`n`r`n"
    Loop % expectedLines.Length()
    {
        expectedLine := expectedLines[A_Index]
        found := InStr(ChatQueuePreviewText, expectedLine) > 0
        if (!found)
            ok := false
        report .= (found ? "[PASS] " : "[FAIL] ") . expectedLine . "`r`n"
    }
    report .= (parserIdOk ? "[PASS] " : "[FAIL] ") . "ChatLog ID parser`r`n"
    report .= (parserChaseTargetOk ? "[PASS] " : "[FAIL] ") . "Chase parser selects second ID`r`n"
    report .= (parserChaseSingleOk ? "[PASS] " : "[FAIL] ") . "Chase parser keeps single ID`r`n"
    report .= (parserNameOk ? "[PASS] " : "[FAIL] ") . "ChatLog nickname parser`r`n"
    report .= (lookupQueueOk ? "[PASS] " : "[FAIL] ") . "ChatLog /id through ChatQueue`r`n"
    report .= "`r`nStatus: " . (ok ? "PASS" : "FAIL") . "`r`n"
    report .= "Final ID: " . UserID . "`r`n"
    report .= "`r`nPreview:`r`n" . ChatQueuePreviewText . "`r`n"

    reportPath := A_ScriptDir . "\context_assistant_test.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    Gui, 41:Destroy
    return ok
}

AcquireAppInstance() {
    global AppInstanceMutex
    duplicateFound := false
    previousDetectHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, legacyInstances, List, AMZ_GOS_BY_SBEZRUK_vu_fixed.ahk ahk_class AutoHotkey
    Loop, %legacyInstances%
    {
        legacyHwnd := legacyInstances%A_Index%
        if (legacyHwnd != A_ScriptHwnd)
        {
            duplicateFound := true
            break
        }
    }
    DetectHiddenWindows, %previousDetectHidden%
    if (duplicateFound)
    {
        MsgBox, 48, AHK FOR GOS BY SBEZRUK, AHK FOR GOS BY SBEZRUK уже запущен из другой папки.`nЗакрой предыдущую копию перед запуском новой.
        return false
    }

    mutexName := "Local\AMZ_GOS_SBEZRUK_RUNTIME_V3"
    AppInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 1, "Str", mutexName, "Ptr")
    if (!AppInstanceMutex)
    {
        MsgBox, 16, AHK FOR GOS BY SBEZRUK, Не удалось создать защиту экземпляра приложения.
        return false
    }
    if (A_LastError = 183)
    {
        DllCall("CloseHandle", "Ptr", AppInstanceMutex)
        AppInstanceMutex := 0
        MsgBox, 48, AHK FOR GOS BY SBEZRUK, AHK FOR GOS BY SBEZRUK уже запущен из другой папки.`nЗакрой предыдущую копию перед запуском новой.
        return false
    }
    return true
}

V1_FileName(path) {
    SplitPath, path, name
    return name
}

V1_GetBetween(text, startMarker, endMarker) {
    startPos := InStr(text, "`n" . startMarker)
    if !startPos
        startPos := InStr(text, startMarker)
    if !startPos
        return ""
    endPos := InStr(text, "`n" . endMarker, false, startPos + StrLen(startMarker))
    if !endPos
        endPos := StrLen(text) + 1
    return SubStr(text, startPos, endPos - startPos)
}

V1_HasOnlyCrlf(path) {
    file := FileOpen(path, "r")
    if !IsObject(file)
        return false
    size := file.Length
    VarSetCapacity(data, size, 0)
    read := file.RawRead(data, size)
    file.Close()
    previous := -1, hasLf := false
    Loop % read
    {
        value := NumGet(data, A_Index - 1, "UChar")
        if (value = 10) {
            hasLf := true
            if (previous != 13)
                return false
        }
        previous := value
    }
    return hasLf
}

V1_BraceBalance(text) {
    balance := 0
    Loop, Parse, text, `n, `r
    {
        line := A_LoopField
        inString := false
        index := 1
        while (index <= StrLen(line))
        {
            char := SubStr(line, index, 1)
            if (char = """") {
                if (inString && SubStr(line, index + 1, 1) = """") {
                    index += 2
                    continue
                }
                inString := !inString
            } else if (!inString && char = ";")
                break
            else if (!inString && char = "{")
                balance++
            else if (!inString && char = "}")
                balance--
            index++
        }
    }
    return balance
}

V1_Join(items) {
    out := ""
    count := IsObject(items) ? items.Length() : 0
    Loop % count
        out .= (out = "" ? "" : ", ") . items[A_Index]
    return out
}

V1_HasDuplicateFunctions(text, ByRef details) {
    seen := {}, duplicates := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "^([A-Za-z_][A-Za-z0-9_]*)\([^)]*\)\s*\{", match)
            continue
        key := match1
        StringLower, key, key
        if seen.HasKey(key)
            duplicates.Push(match1)
        else
            seen[key] := 1
    }
    details := V1_Join(duplicates)
    return duplicates.Length() > 0
}

V1_HasDuplicateLabels(text, ByRef details) {
    seen := {}, duplicates := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "^([A-Za-z_][A-Za-z0-9_]*):\s*$", match)
            continue
        key := match1
        StringLower, key, key
        if seen.HasKey(key)
            duplicates.Push(match1)
        else
            seen[key] := 1
    }
    details := V1_Join(duplicates)
    return duplicates.Length() > 0
}

V1_AllGosubTargetsExist(text, ByRef details) {
    checked := {}, missing := []
    Loop, Parse, text, `n, `r
    {
        if !RegExMatch(A_LoopField, "i)^\s*Gosub,\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", match)
            continue
        key := match1
        StringLower, key, key
        if checked.HasKey(key)
            continue
        checked[key] := 1
        if !RegExMatch(text, "im)^" . match1 . ":\s*$")
            missing.Push(match1)
    }
    details := V1_Join(missing)
    return missing.Length() = 0
}

V1_RunMigrationTest(ByRef details) {
    global AppVersion
    AppVersion := "1.0"
    dir := A_Temp . "\AMZ_GOS_V13_" . DllCall("GetCurrentProcessId") . "_" . TickNow()
    FileCreateDir, %dir%
    fileName := dir . "\profiles.ini"
    seed := "[Profiles]`r`nNames=Основной|Резервный`r`nLast=Основной`r`n[Profile_Основной]`r`n"
    seed .= "ReportRole=Моя должность`r`nT_CivilCallStart=Мой доклад`r`n"
    seed .= "Bind_ToggleHUD=F9`r`nTerritoryMapMode=Forum`r`nUnknownLegacyKey=keep-me`r`n"
    seed .= "MDS_EvacReminder=remove-me`r`nBind_MDSEvacReminder=F8`r`nTrig_MDSEvacReminder=!эвдок`r`n"
    seed .= "[Profile_Резервный]`r`nSurname=Тестов`r`n"
    seed .= "[Meta]`r`nConfigVersion=10`r`n"
    FileAppend, %seed%, %fileName%
    firstOk := MigrateV11Configuration(fileName) && MigrateV12Configuration(fileName) && MigrateV13Configuration(fileName)
    firstText := SelfTest_ReadFile(fileName)
    secondOk := MigrateV11Configuration(fileName) && MigrateV12Configuration(fileName) && MigrateV13Configuration(fileName)
    secondText := SelfTest_ReadFile(fileName)
    IniRead, role, %fileName%, Profile_Основной, ReportRole, ERROR
    civil := IniReadText(fileName, "Profile_Основной", "T_CivilCallStart", "ERROR")
    IniRead, hud, %fileName%, Profile_Основной, Bind_ToggleHUD, ERROR
    IniRead, legacy, %fileName%, Profile_Основной, UnknownLegacyKey, ERROR
    IniRead, chase, %fileName%, Profile_Основной, Bind_ChaseNoID, ERROR
    IniRead, lawKey, %fileName%, Profile_Основной, Bind_LawSearchSubmit, ERROR
    IniRead, autoMode, %fileName%, Profile_Основной, AutoReportMode, ERROR
    IniRead, mapMode, %fileName%, Profile_Основной, TerritoryMapMode, ERROR
    IniRead, reserveMapMode, %fileName%, Profile_Резервный, TerritoryMapMode, ERROR
    IniRead, autoPatrolTrigger, %fileName%, Profile_Основной, Trig_AutoPatrol, ERROR
    IniRead, autoPostTrigger, %fileName%, Profile_Основной, Trig_AutoPost, ERROR
    IniRead, removedMds, %fileName%, Profile_Основной, MDS_EvacReminder, __REMOVED__
    ok := firstOk && secondOk && firstText = secondText
        && role = "Моя должность" && civil = "Мой доклад" && hud = "F9"
        && legacy = "keep-me" && chase = "Insert" && lawKey = "^+f" && autoMode = "Патруль"
        && mapMode = "Forum" && reserveMapMode = "Local"
        && autoPatrolTrigger = "!апатруль" && autoPostTrigger = "!апост" && removedMds = "__REMOVED__"
    details := ok ? "repeat is byte-stable; new commands added; obsolete MDS keys removed" : "migration assertion failed"
    FileDelete, %fileName%
    FileRemoveDir, %dir%
    return ok
}

V1_CheckV12Pipeline(mainText, ByRef details) {
    migration := V1_GetBetween(mainText, "MigrateV11Configuration(", "MigrateConfigIfNeeded(")
    loader := V1_GetBetween(mainText, "LoadProfileV9FieldsFromIni(", "WriteProfileV9FieldsToIni(")
    writer := V1_GetBetween(mainText, "WriteProfileV9FieldsToIni(", "NormalizeProfileMode(")
    fields := ["ReportRole", "T_CivilCallStart", "T_CivilCallArrive"
        , "Bind_CivilCallStart", "Bind_CivilCallArrive", "Trig_CivilCallStart", "Trig_CivilCallArrive"
        , "Bind_VehicleLookup", "Trig_VehicleLookup", "Bind_WantedRemoval", "Trig_WantedRemoval"
        , "Bind_ChaseNoID", "Trig_ChaseNoID", "Bind_LawSearchSubmit"
        , "AutoReportMode", "AutoReportDurationMin", "TerritoryMapMode"]
    missing := []
    Loop % fields.Length()
    {
        field := fields[A_Index]
        if (!InStr(migration, field) || !InStr(loader, field) || !InStr(writer, field)
            || !InStr(mainText, "global CFG_" . field . " :="))
            missing.Push(field)
    }
    backupPos := InStr(mainText, "backupFile := CreateConfigBackup(""migrate_v""")
    migratePos := InStr(mainText, "storedVersion < 12 && !MigrateV12Configuration(", false, backupPos)
    backupOk := backupPos > 0 && migratePos > backupPos
    details := missing.Length() ? V1_Join(missing) : (backupOk ? "17 fields and pre-migration backup" : "backup hook missing")
    return missing.Length() = 0 && backupOk
}

V1_CheckTemplates(ByRef details) {
    global IntroRole, ReportRole, Rank, ReportRank, Surname
    global PatrolUnit, PatrolRoute, PatrolCrewCount, PostUnit, PostRoute, PostCrewCount, ConvoyRoute
    saved := {IntroRole:IntroRole, ReportRole:ReportRole, Rank:Rank, ReportRank:ReportRank, Surname:Surname
        , PatrolUnit:PatrolUnit, PatrolRoute:PatrolRoute, PatrolCrewCount:PatrolCrewCount
        , PostUnit:PostUnit, PostRoute:PostRoute, PostCrewCount:PostCrewCount, ConvoyRoute:ConvoyRoute}
    IntroRole := "начальником МДС ГАИ", ReportRole := "Начальник МДС ГАИ"
    Rank := "лейтенант", ReportRank := "лейтенант", Surname := "Лукашенко"
    PatrolUnit := "Р101", PatrolRoute := "А-1", PatrolCrewCount := "2"
    PostUnit := "Р202", PostRoute := "АП ГАИ", PostCrewCount := "3", ConvoyRoute := "А-Б"
    pairs := []
    pairs.Push(["Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}.", "Здравия желаю, являюсь начальником МДС ГАИ, лейтенант полиции Лукашенко."])
    pairs.Push(["/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь.", "/d [ГАИ/] говорит Начальник МДС ГАИ, лейтенант полиции Лукашенко, на связь."])
    pairs.Push(["/r докладывает {SURNAME}: реагирую на вызов срочной помощи.", "/r докладывает Лукашенко: реагирую на вызов срочной помощи."])
    pairs.Push(["/r докладывает {SURNAME}: прибыл на вызов срочной помощи.", "/r докладывает Лукашенко: прибыл на вызов срочной помощи."])
    pairs.Push(["/r докладывает {SURNAME}: принял вызов гражданского.", "/r докладывает Лукашенко: принял вызов гражданского."])
    pairs.Push(["/r докладывает {SURNAME}: прибыл на вызов гражданского.", "/r докладывает Лукашенко: прибыл на вызов гражданского."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП.", "/r докладывает экипаж Р101: принял вызов о ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП.", "/r докладывает экипаж Р101: прибыли на вызов о ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП.", "/r докладывает экипаж Р101: приступили к оформлению ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП.", "/r докладывает экипаж Р101: завершили оформление ДТП."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек.", "/r докладывает экипаж Р101: патрулируем по маршруту А-1 в составе 2 человек."])
    pairs.Push(["/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек.", "/r докладывает экипаж Р202: продолжаем стоять на посту АП ГАИ в составе 3 человек."])
    pairs.Push(["/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}.", "/r докладывает экипаж Р101: продолжаем сопровождение военной колонны по маршруту А-Б."])
    ok := true
    Loop % pairs.Length()
    {
        actual := ApplyTemplate(pairs[A_Index][1])
        if (actual != pairs[A_Index][2] || RegExMatch(actual, "\{[A-Z0-9_]+\}"))
            ok := false
    }
    IntroRole := saved.IntroRole, ReportRole := saved.ReportRole, Rank := saved.Rank
    ReportRank := saved.ReportRank, Surname := saved.Surname, PatrolUnit := saved.PatrolUnit
    PatrolRoute := saved.PatrolRoute, PatrolCrewCount := saved.PatrolCrewCount
    PostUnit := saved.PostUnit, PostRoute := saved.PostRoute, PostCrewCount := saved.PostCrewCount
    ConvoyRoute := saved.ConvoyRoute
    details := ok ? pairs.Length() . " exact expansions" : "template mismatch or unresolved placeholder"
    return ok
}

V1_CheckCatalog(ByRef details) {
    catalog := GetBindCatalog(), seen := {}, issues := []
    required := {"CivilCallStart":0, "CivilCallArrive":0, "VehicleLookup":0
        , "WantedRemoval":0, "ChaseNoID":0, "LawSearchSubmit":0
        , "AutoPatrol":0, "AutoPost":0}
    assist := {"AssistOOP":0, "AssistStun":0, "AssistChase":0
        , "AssistHouse":0, "AssistDrugs":0, "AssistPDPCuff":0}
    special := {"OpenSettings":1, "ToggleBindList":1, "ToggleHUD":1, "GpsD":1, "GpsOS":1}
    hijackCount := 0
    Loop % catalog.Length()
    {
        meta := catalog[A_Index], key := meta.Token
        StringLower, key, key
        if seen.HasKey(key)
            issues.Push("duplicate " . meta.Token)
        seen[key] := 1
        if required.HasKey(meta.Token)
            required[meta.Token] := BindCatalog_IsRegistrable(meta) && BindCatalog_IsUserVisible(meta)
        if assist.HasKey(meta.Token)
            assist[meta.Token] := meta.InternalOnly && !meta.Enabled && !meta.ExposeInSettings
                && !BindCatalog_IsRegistrable(meta)
        if (meta.Token = "HijackStart" || meta.Token = "HijackArrive") {
            if (meta.LegacyOnly && !meta.Enabled && !meta.ExposeInSettings && !BindCatalog_IsRegistrable(meta))
                hijackCount++
        }
        if BindCatalog_IsRegistrable(meta) && !special.HasKey(meta.Token) {
            handler := GetBoundLabelByToken(meta.Token)
            if (handler = "" || !IsLabel(handler))
                issues.Push("handler " . meta.Token)
        }
    }
    for token, present in required
        if !present
            issues.Push("required " . token)
    for token, hidden in assist
        if !hidden
            issues.Push("Assist " . token)
    if (hijackCount != 2)
        issues.Push("Hijack legacy flags")
    details := issues.Length() ? V1_Join(issues) : catalog.Length() . " unique items; 8 required; 6 Assist internal; 2 Hijack legacy"
    return issues.Length() = 0
}

V1_CheckProfileConflicts(fileName, ByRef details) {
    IniRead, profile, %fileName%, Profiles, Last, Основной
    section := "Profile_" . profile
    hotkeys := {}, triggers := {}, conflicts := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.HotkeyVar != "") {
            iniKey := meta.HotkeyVar
            IniRead, value, %fileName%, %section%, %iniKey%,
            value := NormalizeHotkeyId(value)
            if (value != "" && hotkeys.HasKey(value))
                conflicts.Push(value . ": " . hotkeys[value] . "/" . meta.Token)
            else if (value != "")
                hotkeys[value] := meta.Token
        }
        if (meta.TriggerVar != "") {
            iniKey := meta.TriggerVar
            IniRead, value, %fileName%, %section%, %iniKey%,
            value := Trim(value)
            StringLower, value, value
            if (value != "" && triggers.HasKey(value))
                conflicts.Push(value . ": " . triggers[value] . "/" . meta.Token)
            else if (value != "")
                triggers[value] := meta.Token
        }
    }
    details := conflicts.Length() ? V1_Join(conflicts) : "no conflicts"
    return conflicts.Length() = 0
}

RunSelfTestV1() {
    global SelfTestCriticalFailed, SelfTestHighFailed, SelfTestMediumWarnings, SelfTestLowNotes, SelfTestTotal
    global AppVersion, ConfigVersion
    global LawSearchDocCatalog

    AppVersion := "1.0", ConfigVersion := 13
    SelfTestCriticalFailed := 0, SelfTestHighFailed := 0
    SelfTestMediumWarnings := 0, SelfTestLowNotes := 0, SelfTestTotal := 0

    root := A_ScriptDir
    mainPath := A_ScriptFullPath
    profilePath := FileExist(root . "\profiles_updated.ini") ? root . "\profiles_updated.ini" : root . "\profiles.ini"
    paths := [mainPath, root . "\profiles.ini", root . "\UDF.ahk", root . "\common.ahk"]
    mainText := SelfTest_ReadFile(mainPath)
    helperText := ""
    udfText := SelfTest_ReadFile(root . "\UDF.ahk")
    commonText := SelfTest_ReadFile(root . "\common.ahk")

    report := "AHK FOR GOS BY SBEZRUK v1.0 regression self-test`r`n"
    report .= "Runtime: AutoHotkey " . A_AhkVersion . " | ANSI=" . (!A_IsUnicode) . " | PtrSize=" . A_PtrSize . "`r`n"
    report .= "Project: " . root . "`r`nLIVE GAME: NOT RUN`r`n`r`n"

    Loop % paths.Length()
    {
        path := paths[A_Index]
        SelfTest_Add(report, "Critical", "file exists: " . V1_FileName(path), SelfTest_FileExistsNonEmpty(path))
        SelfTest_Add(report, "High", "CP1251 artifact has no BOM: " . V1_FileName(path), SelfTest_HasNoBom(path))
        SelfTest_Add(report, "High", "CRLF only: " . V1_FileName(path), V1_HasOnlyCrlf(path))
    }
    LawSearch_InitCatalog()
    Loop % LawSearchDocCatalog.Length()
    {
        lawMeta := LawSearchDocCatalog[A_Index]
        lawPath := root . "\laws\" . lawMeta.FileName
        SelfTest_Add(report, "Critical", "official law exists: " . lawMeta.Code, SelfTest_FileExistsNonEmpty(lawPath))
        SelfTest_Add(report, "High", "official law has no BOM: " . lawMeta.Code, SelfTest_HasNoBom(lawPath))
        SelfTest_Add(report, "High", "official law CRLF only: " . lawMeta.Code, V1_HasOnlyCrlf(lawPath))
    }
    SelfTest_Add(report, "Critical", "AHK v1.1 ANSI 32-bit runtime"
        , !A_IsUnicode && A_PtrSize = 4 && SubStr(A_AhkVersion, 1, 4) = "1.1.")
    SelfTest_Add(report, "Critical", "release v1.0 and schema v13"
        , InStr(mainText, "AppVersion := ""1.0""") && InStr(mainText, "ConfigVersion := 13"))
    IniRead, iniSchema, %profilePath%, Meta, ConfigVersion, 0
    IniRead, iniRelease, %profilePath%, Meta, AppVersion, 0
    SelfTest_Add(report, "Critical", "active INI uses v1.0/v13", iniSchema = 13 && iniRelease = "1.0")
    SelfTest_Add(report, "Critical", "include contract"
        , InStr(mainText, "#Include %A_ScriptDir%\UDF.ahk")
        && InStr(mainText, "BEGIN EMBEDDED helper.ahk")
        && (InStr(udfText, "#include common.ahk") || InStr(udfText, "#Include common.ahk")))
    removedMethodFile := "method_" . "helper.ahk"
    methodRemovedOk := !FileExist(root . "\" . removedMethodFile)
        && !InStr(mainText, removedMethodFile)
        && !InStr(mainText, "RegisterTextTrigger(""Meth" . "od_")
        && !InStr(mainText, "DoMeth" . "od")
        && !InStr(mainText, "Meth" . "odDoc")
        && !InStr(mainText, "Meth" . "odSearch")
    SelfTest_Add(report, "Critical", "method helper is fully removed", methodRemovedOk)
    SelfTest_Add(report, "Critical", "pointer validation supports x86 LargeAddressAware"
        , IsLikelyPointer(0x80000000) && IsLikelyPointer(0xFFFEFFFF)
            && !IsLikelyPointer(0xFFFF0000))
    SelfTest_Add(report, "Critical", "Auto ID keeps a validated cache across stable reads"
        , InStr(udfText, "AZMP_TARGET_CACHE_TTL := 1000")
            && InStr(udfText, "AZMP_GetPlayerInfo(AZMP_TARGET_CACHE_ID, playerPool, 1)"))
    SelfTest_Add(report, "High", "NOT_IN_POOL uses soft pool refresh"
        , InStr(udfText, "AZMP_TargetDiagMaybeRefreshNotInPool(targetPed, playerPool, detail)")
            && InStr(mainText, "AutoTargetID_IsHardRecoveryCode(code)"))
    serviceCodesSection := V1_GetBetween(mainText, "ServiceCodes_" . "Show() {", "DoBindMenuToggle:")
    serviceCodesLabelSection := V1_GetBetween(mainText, "DoServiceCodes" . "Gui:", "DoVehicleLookup:")
    SelfTest_Add(report, "High", "!коды reuses legislation GUI"
        , InStr(serviceCodesSection, "LawGui_" . "Show(1, ""Служебные коды""")
            && InStr(serviceCodesLabelSection, "Helper_CloseChatAfterGui()")
            && InStr(mainText, "#If (Service" . "CodesGuiVisible)"))

    allCode := mainText . "`n" . udfText . "`n" . commonText
    SelfTest_Add(report, "Critical", "balanced code braces", V1_BraceBalance(allCode) = 0
        , "delta=" . V1_BraceBalance(allCode))
    SelfTest_Add(report, "Critical", "no duplicate functions", !V1_HasDuplicateFunctions(allCode, duplicateFunctions), duplicateFunctions)
    SelfTest_Add(report, "Critical", "no duplicate labels", !V1_HasDuplicateLabels(mainText, duplicateLabels), duplicateLabels)
    SelfTest_Add(report, "Critical", "literal Gosub targets exist", V1_AllGosubTargetsExist(mainText, missingGosub), missingGosub)

    SelfTest_Add(report, "Critical", "v13 migration is idempotent and legacy-safe"
        , V1_RunMigrationTest(migrationDetails), migrationDetails)
    SelfTest_Add(report, "Critical", "all v12 fields are in read/write pipeline"
        , V1_CheckV12Pipeline(mainText, pipelineDetails), pipelineDetails)

    SelfTest_Add(report, "Critical", "two role forms and exact templates"
        , V1_CheckTemplates(templateDetails), templateDetails)
    towStartSection := V1_GetBetween(mainText, "DoTow" . "Start:", "DoTow" . "End:")
    formationFinishOk := InStr(mainText, "Время на сбор — окончено") > 0
    towStartTextOk := InStr(mainText, "начал эвакуировать ТС на штрафстоянку.") > 0
    towEnsureOk := InStr(mainText, "TowStart_EnsureTowLast") > 0
    towLastOk := InStr(mainText, "Крюк эвакуатора закреплен на автомобиле.``n/tow") > 0
    towTimerOk := InStr(towStartSection, "ActionTimer_StartEvacuation()") > 0
    removedMdsOk := !InStr(mainText, "Token: ""MDSEvacReminder""")
    towEndTextOk := InStr(mainText, "эвакуировал ТС на штрафстоянку.") > 0
    formationTowOk := formationFinishOk && towStartTextOk && towEnsureOk && towLastOk && towTimerOk && removedMdsOk && towEndTextOk
    formationTowDetails := "formation=" . formationFinishOk . ", start=" . towStartTextOk . ", ensure=" . towEnsureOk
        . ", tow-last=" . towLastOk . ", timer=" . towTimerOk . ", removed-mds=" . removedMdsOk . ", end=" . towEndTextOk
    SelfTest_Add(report, "High", "formation and tow workflow wording"
        , formationTowOk, formationTowDetails)
    SelfTest_Add(report, "Critical", "configurable !апатруль and !апост"
        , InStr(mainText, "Trig_AutoPatrol := ""!апатруль""")
        && InStr(mainText, "Trig_AutoPost := ""!апост""")
        && InStr(mainText, "IniRead, Trig_AutoPatrol")
        && InStr(mainText, "IniRead, Trig_AutoPost")
        && InStr(mainText, "AutoReport_IsValidDuration(minutesText)"))
    patrolHooks := V1_GetBetween(mainText, "DoPatrol" . "Start:", "DoPost" . "Start:")
    postHooks := V1_GetBetween(mainText, "DoPost" . "Start:", "DoConvoy" . "Start:")
    towHooks := V1_GetBetween(mainText, "DoTow" . "Start:", "DoCar" . "Search:")
    SelfTest_Add(report, "Critical", "action timers are wired to patrol, post and evacuation"
        , InStr(patrolHooks, "ActionTimer_StartManualService(""Патруль"")")
        && InStr(patrolHooks, "ActionTimer_Stop(""Patrol"")")
        && InStr(postHooks, "ActionTimer_StartManualService(""Пост"")")
        && InStr(postHooks, "ActionTimer_Stop(""Post"")")
        && InStr(towHooks, "ActionTimer_StartEvacuation()")
        && InStr(towHooks, "ActionTimer_Stop(""Evac"")"))
    SelfTest_Add(report, "High", "action timer lifecycle and position persistence"
        , InStr(mainText, "ActionTimer" . "Tick:")
        && InStr(mainText, "StartActionTimer" . "Drag:")
        && InStr(V1_GetBetween(mainText, "RebuildFloatingGUI()", "GetNotifySoundPath("), "ActionTimer_Rebuild()")
        && InStr(V1_GetBetween(mainText, "CancelAllAutomation(showStatus := 1)", "SendChatKeyboard("), "ActionTimer_Clear()")
        && InStr(V1_GetBetween(mainText, "WM_EXIT" . "SIZEMOVE(", "CloseAll" . "Docs("), "ActionTimerX := x")
        && InStr(V1_GetBetween(mainText, "ExitScript" . "Label:", "StartSettings" . "Drag:"), "SetTimer, ActionTimerTick, Off"))

    pages := GetSettingsPageCatalog()
    pageSeen := {}, pagesOk := pages.Length() = 13
    Loop % pages.Length()
    {
        pageId := pages[A_Index].Id
        if (pageId = "" || pageSeen.HasKey(pageId))
            pagesOk := false
        pageSeen[pageId] := 1
    }
    SelfTest_Add(report, "Critical", "13 unique settings pages", pagesOk)
    SelfTest_Add(report, "High", "profile UI exposes both role forms"
        , InStr(mainText, "profileItems.Push([""Должность"", ""CFG_IntroRole""")
        && InStr(mainText, "profileItems.Push([""Должность для /d (именительный падеж)"", ""CFG_ReportRole"""))
    SelfTest_Add(report, "High", "civil reports visible; Hijack rows hidden"
        , InStr(mainText, "reportItems.Push([""Гражданский вызов принят"", ""CFG_T_CivilCallStart""")
        && InStr(mainText, "reportItems.Push([""Гражданский вызов: прибыл"", ""CFG_T_CivilCallArrive""")
        && !InStr(mainText, "reportItems.Push([""Угон выехал"""))

    SelfTest_Add(report, "Critical", "catalog tokens, visibility and handlers"
        , V1_CheckCatalog(catalogDetails), catalogDetails)
    SelfTest_Add(report, "High", "active profile has no bind conflicts"
        , V1_CheckProfileConflicts(profilePath, conflictDetails), conflictDetails)
    SelfTest_Add(report, "High", "text hotstrings are game/chat scoped"
        , InStr(mainText, "Hotkey, If, % GameTextHotkeyContext")
        && InStr(V1_GetBetween(mainText, "GameTextTriggerAllowed(", "RegisterTextTrigger("), "IsGameActive()")
        && InStr(V1_GetBetween(mainText, "GameTextTriggerAllowed(", "RegisterTextTrigger("), "isInChat()"))

    SelfTest_Add(report, "Critical", "default F12/F5/Pause and independent Chase binds"
        , InStr(mainText, "Bind_ToggleHUD := ""F12""")
        && InStr(mainText, "Bind_IDOverlay := ""F5""")
        && InStr(mainText, "Bind_HideLawGui := ""Pause""")
        && InStr(mainText, "Bind_Chase := ""!3""")
        && InStr(mainText, "Bind_ChaseNoID := ""Insert"""))
    chaseNoIdText := V1_GetBetween(mainText, "DoChaseNoID:", "DoDeject:")
    SelfTest_Add(report, "Critical", "Chase ID and no-ID commands"
        , ContextAssistant_BuildCommand("Chase", 4321) = "/chase 4321"
        && InStr(chaseNoIdText, "ChatQueue_Enqueue(""/chase""")
        && !InStr(mainText, "ChatQueue_Enqueue(""/chaseid"))

    captureText := V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand(")
    SelfTest_Add(report, "Critical", "law query is captured locally and cancelled with Escape"
        , InStr(captureText, "{Esc}") && InStr(captureText, "^a^c")
        && !InStr(captureText, "{Enter}") && !InStr(captureText, "{F6}")
        && !InStr(captureText, "SendChat(") && !InStr(captureText, "ChatQueue"))
    SelfTest_Add(report, "High", "law-search submit key is configurable Ctrl+Shift+F"
        , InStr(mainText, "Bind_LawSearchSubmit := ""^+f""")
        && InStr(mainText, "Token: ""LawSearchSubmit""")
        && !RegExMatch(mainText, "m)^\^!f::"))

    evidence := Evidence_RunRecognitionMatrix()
    SelfTest_Add(report, "Critical", "evidence recognition matrix", evidence.Ok
        , evidence.Passed . "/" . evidence.Total)
    SelfTest_Add(report, "High", "evidence retains report identity, pending, focus-retry and cooldown guards"
        , InStr(mainText, "Evidence_IsOwnReportLine(line)")
        && InStr(mainText, "Evidence_IsPending(reportEvent)")
        && InStr(mainText, "Снимок ожидает возврата фокуса в игру")
        && InStr(mainText, "ChatLogReader_CanTrigger(""Evidence:"" . evidenceEvent, 3000)"))

    lawAudit := LawSearch_AuditIndex()
    SelfTest_Add(report, "Critical", "law index covers 20 documents and every article heading"
        , lawAudit.Ok && lawAudit.Documents = 20
        , "docs=" . lawAudit.Documents . ", pages=" . lawAudit.Pages
            . ", headings=" . lawAudit.Headings . ", failures=" . lawAudit.Failures.Length())
    corpusAudit := LawCorpus_Audit()
    SelfTest_Add(report, "Critical", "official offline corpus: 20 readable documents"
        , corpusAudit.Ok && corpusAudit.Documents = 20
        , "docs=" . corpusAudit.Documents . ", chars=" . corpusAudit.Characters
            . ", failures=" . corpusAudit.Issues.Length())
    mapAudit := TerritoryMap_AuditCatalog()
    SelfTest_Add(report, "Critical", "territory maps: 11 groups and every local asset"
        , mapAudit.Ok && mapAudit.Groups = 11
        , "groups=" . mapAudit.Groups . ", failures=" . mapAudit.Issues.Length())
    SelfTest_Add(report, "High", "territory map profile mode and two UI choices"
        , (TerritoryMapMode_ToUiLabel("Local") = "Локальные копии")
        && (TerritoryMapMode_ToUiLabel("Forum") = "Официальные ссылки")
        && (TerritoryMapMode_FromUiLabel("Официальные ссылки") = "Forum")
        && InStr(mainText, "CFG_TerritoryMapMode")
        && InStr(mainText, "MigrateV12Configuration("))
    SelfTest_Add(report, "Critical", "current KOAP article 17.5 is present"
        , InStr(LawCorpus_GetText("koap"), "Статья 17.5. Нарушение масочного режима"))
    SelfTest_Add(report, "Critical", "current VU point 3.20 is present"
        , InStr(LawCorpus_GetText("vu"), "3.20 Сотрудники специализированных подразделений"))
    SelfTest_Add(report, "Critical", "current TER access additions are present"
        , InStr(LawCorpus_GetText("ter"), "6. начальник Главного управления Министерства внутренних дел")
        && InStr(LawCorpus_GetText("ter"), "11) начальник Главного управления Министерства внутренних дел"))
    SelfTest_Add(report, "Critical", "current TER one/two-demand rule is present"
        , InStr(LawCorpus_GetText("ter"), "одно законное требование покинуть территорию")
        && InStr(LawCorpus_GetText("ter"), "двух законных требований покинуть территорию с интервалом 10 секунд"))
    SelfTest_Add(report, "Critical", "deleted FZOP article 8 point 10 is absent"
        , LawSearch_CheckNoResults("ФЗОП статья 8 пункт 10", "ALL"))
    SelfTest_Add(report, "High", "dynamic corpus pagination replaces fixed summaries"
        , LawCorpus_PageCount("kas") > 4 && LawCorpus_PageCount("upk") > 41
        && IsFunc("LawDoc_ShowPage") && IsFunc("LawDoc_GetCurrentPage"))
    SelfTest_Add(report, "High", "law exact and compact references"
        , LawSearch_CheckExpected("ФЗОТОД гл. 3 ст. 9.2 ч. 2", "ALL", "TER", "9.2", "2", 3)
        && LawSearch_CheckExpected("ФЗОТОД гл3 ст9.2 ч2", "ALL", "TER", "9.2", "2", 3))
    SelfTest_Add(report, "High", "law natural query, word forms and permutation"
        , LawSearch_CheckExpected("кто считается сотрудником полиции", "ALL", "FZOP", "16", "1", 5)
        && LawSearch_CheckExpected("сотрудника полиции", "ALL", "FZOP", "16", "1", 5)
        && LawSearch_CheckExpected("полиции сотрудник", "ALL", "FZOP", "16", "1", 5))
    SelfTest_Add(report, "High", "law bounded typo and negative example"
        , LawSearch_CheckExpected("сотрудник полицеи", "ALL", "FZOP", "16", "1", 5)
        && LawSearch_CheckNoResults("квазиплазменный телепортатор", "ALL"))
    searchPackage := LawSearch_Find("ALL", "сотрудник", 99)
    SelfTest_Add(report, "High", "law results cap at 30 and retain total count"
        , searchPackage.Results.Length() <= 30 && searchPackage.Passed >= searchPackage.Results.Length())
    SelfTest_Add(report, "High", "no article-specific search bonuses"
        , !InStr(helperText, "terZoneIntent") && !InStr(helperText, "repeatIntent"))

    SelfTest_Add(report, "Critical", "AutoReport scheduler mock", RunAutoReportMockTest())
    SelfTest_Add(report, "High", "AutoReport UI and cancellation hooks"
        , InStr(mainText, "vCFG_AutoReportMode") && InStr(mainText, "gAutoReportStartLabel")
        && InStr(V1_GetBetween(mainText, "LoadProfile(profileName)", "FinalizeLoadedProfileState("), "AutoReport_Stop")
        && InStr(V1_GetBetween(mainText, "CancelAllAutomation(showStatus := 1)", "SendChatKeyboard("), "AutoReport_Stop")
        && InStr(V1_GetBetween(mainText, "ExitScriptLabel:", "HandleAppExit:"), "AutoReport_Stop"))

    status := (SelfTestCriticalFailed || SelfTestHighFailed) ? "FAIL"
        : ((SelfTestMediumWarnings || SelfTestLowNotes) ? "WARN" : "PASS")
    report .= "`r`nSummary: " . status . "`r`n"
    report .= "Total checks: " . SelfTestTotal . "`r`n"
    report .= "Critical failed: " . SelfTestCriticalFailed . "`r`n"
    report .= "High failed: " . SelfTestHighFailed . "`r`n"
    report .= "Medium warnings: " . SelfTestMediumWarnings . "`r`n"
    report .= "Low notes: " . SelfTestLowNotes . "`r`nLIVE GAME: NOT RUN`r`n"
    SelfTest_WriteReport(report)
    return status != "FAIL"
}

RunSelfTest() {
    ; Compatibility entry point: the v1.0/v13 suite is the single authoritative self-test.
    return RunSelfTestV1()
}

SelfTest_Add(ByRef report, severity, name, ok, details := "") {
    global SelfTestCriticalFailed, SelfTestHighFailed, SelfTestMediumWarnings, SelfTestLowNotes, SelfTestTotal

    SelfTestTotal += 1
    if (ok)
        status := "PASS"
    else if (severity = "Medium")
        status := "WARN"
    else if (severity = "Low")
        status := "NOTE"
    else
        status := "FAIL"

    if (!ok)
    {
        if (severity = "Critical")
            SelfTestCriticalFailed += 1
        else if (severity = "High")
            SelfTestHighFailed += 1
        else if (severity = "Medium")
            SelfTestMediumWarnings += 1
        else
            SelfTestLowNotes += 1
    }

    report .= "[" . status . "] " . severity . " | " . name
    if (details != "")
        report .= " | " . details
    report .= "`r`n"
}

SelfTest_ReadFile(path) {
    if (!FileExist(path))
        return ""
    FileRead, content, %path%
    if (ErrorLevel)
        return ""
    return content
}

SelfTest_FileExistsNonEmpty(path) {
    if (!FileExist(path))
        return false
    FileGetSize, fileSize, %path%
    return (fileSize > 0)
}

SelfTest_HasNoBom(path) {
    if (!FileExist(path))
        return false
    file := FileOpen(path, "r")
    if !IsObject(file)
        return false
    VarSetCapacity(buf, 3, 0)
    bytesRead := file.RawRead(buf, 3)
    file.Close()
    if (bytesRead >= 3)
    {
        b1 := NumGet(buf, 0, "UChar")
        b2 := NumGet(buf, 1, "UChar")
        b3 := NumGet(buf, 2, "UChar")
        if (b1 = 0xEF && b2 = 0xBB && b3 = 0xBF)
            return false
    }
    if (bytesRead >= 2)
    {
        b1 := NumGet(buf, 0, "UChar")
        b2 := NumGet(buf, 1, "UChar")
        if ((b1 = 0xFF && b2 = 0xFE) || (b1 = 0xFE && b2 = 0xFF))
            return false
    }
    return true
}

SelfTest_TextContains(text, needle) {
    return (InStr(text, needle) > 0)
}

SelfTest_SectionContains(text, marker, needle, limit := 1200) {
    pos := InStr(text, "`n" . marker)
    if (pos)
        pos += 1
    else if (SubStr(text, 1, StrLen(marker)) = marker)
        pos := 1
    if (!pos)
        return false
    section := SubStr(text, pos, limit)
    return (InStr(section, needle) > 0)
}

SelfTest_BraceBalance(text) {
    balance := 0
    Loop, Parse, text
    {
        if (A_LoopField = "{")
            balance += 1
        else if (A_LoopField = "}")
            balance -= 1
    }
    return balance
}

SelfTest_ContinuationBalance(text) {
    openCount := 0
    closeCount := 0
    Loop, Parse, text, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "(")
            openCount += 1
        else if (line = ")")
            closeCount += 1
    }
    return openCount - closeCount
}

SelfTest_CheckSyntaxText(ByRef report, name, text) {
    braceDelta := SelfTest_BraceBalance(text)
    contDelta := SelfTest_ContinuationBalance(text)
    SelfTest_Add(report, "High", name . " has no AHK v2 arrow syntax", !SelfTest_TextContains(text, "=" . ">"))
    SelfTest_Add(report, "High", name . " static brace heuristic (not interpreter validation)", (braceDelta = 0), "delta=" . braceDelta)
    SelfTest_Add(report, "Medium", name . " static continuation heuristic", (contDelta = 0), "delta=" . contDelta)
}

SelfTest_WriteReport(report) {
    reportPath := A_ScriptDir . "\selftest_report.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    return !ErrorLevel
}
RunDiagnosticsExport() {
    global DiagnosticsFailCount, DiagnosticsWarnCount, DiagnosticsNoteCount, DiagnosticsTotal

    DiagnosticsFailCount := 0
    DiagnosticsWarnCount := 0
    DiagnosticsNoteCount := 0
    DiagnosticsTotal := 0

    projectDir := A_ScriptDir
    mainPath := A_ScriptFullPath
    helperPath := projectDir . "\helper.ahk"
    commonPath := projectDir . "\common.ahk"
    udfPath := projectDir . "\UDF.ahk"
    profilesPath := Diagnostics_GetActiveConfigPath(projectDir)
    themesPath := projectDir . "\themes.ini"
    selftestPath := projectDir . "\selftest_report.txt"
    errorLogPath := projectDir . "\error_log.txt"
    modernLogPath := projectDir . "\logs\amz_gos.log"
    activeLogPath := FileExist(modernLogPath) ? modernLogPath : errorLogPath

    mainText := SelfTest_ReadFile(mainPath)
    commonText := SelfTest_ReadFile(commonPath)
    udfText := SelfTest_ReadFile(udfPath)

    report := "AHK FOR GOS BY SBEZRUK diagnostics report`r`n"
    report .= "Time: " . A_YYYY . "-" . A_MM . "-" . A_DD . " " . A_Hour . ":" . A_Min . ":" . A_Sec . "`r`n"
    report .= "Project: " . projectDir . "`r`n"
    report .= "Script: " . mainPath . "`r`n"
    report .= "Mode: CLI read-only diagnostics`r`n`r`n"

    Diagnostics_AddSection(report, "Runtime safety")
    Diagnostics_AddLine(report, "No GUI, hotkeys, timers, clipboard, GTA memory, profiles/themes writes, or game actions are intentionally used in this mode.")
    Diagnostics_AddCheck(report, "High", "diagnostics guard before normal startup (static)", SelfTest_TextContains(mainText, "if HasCommandLineArg(" . Chr(34) . "--diagnostics" . Chr(34) . ")"), "guard is in auto-execute before InitProfiles/ApplyAllBinds/CreateHUD")

    Diagnostics_AddSection(report, "Capture")
    Diagnostics_AddLine(report, Capture_GetDiagnosticsText())

    Diagnostics_AddSection(report, "Files")
    Diagnostics_CollectFileInfo(report, mainPath, "main")
    Diagnostics_CollectFileInfo(report, helperPath, "helper")
    Diagnostics_CollectFileInfo(report, commonPath, "common")
    Diagnostics_CollectFileInfo(report, udfPath, "UDF")
    Diagnostics_CollectFileInfo(report, profilesPath, "active profiles config")
    if FileExist(themesPath)
        Diagnostics_CollectFileInfo(report, themesPath, "themes")
    else
        Diagnostics_AddLine(report, "themes.ini: optional file is not present; built-in themes remain available")

    Diagnostics_AddSection(report, "Self-test summary")
    Diagnostics_ReadSelfTestSummary(report, selftestPath)

    Diagnostics_AddSection(report, "Error log tail")
    if FileExist(activeLogPath)
    {
        Diagnostics_AddLine(report, "Source: " . activeLogPath)
        Diagnostics_AddLine(report, Diagnostics_ReadTail(activeLogPath, 40))
    }
    else
        Diagnostics_AddLine(report, "No log file found")

    Diagnostics_AddSection(report, "Profile and theme summary")
    currentProfile := Diagnostics_ReadIniValue(profilesPath, "Profiles", "Last", "")
    if (currentProfile = "" || currentProfile = "ERROR")
        currentProfile := "Основной"
    profileSection := "Profile_" . currentProfile
    Diagnostics_AddLine(report, "Active config: " . profilesPath)
    Diagnostics_AddLine(report, "Active profile: " . currentProfile)
    themeMode := Diagnostics_ReadIniValue(profilesPath, "UI", "ThemeMode", "")
    if (themeMode = "" || themeMode = "ERROR")
        themeMode := "<missing>"
    Diagnostics_AddLine(report, "ThemeMode: " . themeMode)
    Diagnostics_AddLine(report, "themes.ini: " . (FileExist(themesPath) ? "present" : "missing"))

    Diagnostics_AddSection(report, "Safe settings")
    Diagnostics_AddLine(report, "SafeModeEnabled=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeModeEnabled", "<missing>"))
    Diagnostics_AddLine(report, "SafeBlockWhenChat=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeBlockWhenChat", "<missing>"))
    Diagnostics_AddLine(report, "SafeVehicleChecks=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeVehicleChecks", "<missing>"))
    Diagnostics_AddLine(report, "SafeRequireChatForEditable=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeRequireChatForEditable", "<missing>"))
    Diagnostics_AddLine(report, "SafeTooltipWarnings=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeTooltipWarnings", "<missing>"))
    Diagnostics_AddLine(report, "SafeDistanceChecks=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeDistanceChecks", "<missing>"))
    Diagnostics_AddLine(report, "SafeDistanceLimit=" . Diagnostics_ReadIniValue(profilesPath, "UI", "SafeDistanceLimit", "<missing>"))

    Diagnostics_AddSection(report, "Chat transport")
    Diagnostics_AddLine(report, "TextSendMode=" . Diagnostics_ReadIniValue(profilesPath, "UI", "TextSendMode", "Auto"))
    Diagnostics_AddLine(report, "GameWindowTitle=" . Diagnostics_ReadIniValue(profilesPath, "UI", "GameWindowTitle", "AMAZING ONLINE"))
    Diagnostics_AddLine(report, "GameProcessName=" . Diagnostics_ReadIniValue(profilesPath, "UI", "GameProcessName", "gta_sa.exe"))
    Diagnostics_AddLine(report, "AzmpExpectedSHA256=" . Diagnostics_ReadIniValue(profilesPath, "UI", "AzmpExpectedSHA256", "<not set>"))
    Diagnostics_AddLine(report, "MockMode=" . Diagnostics_ReadIniValue(profilesPath, "UI", "MockMode", "Off"))
    Diagnostics_AddCheck(report, "Critical", "unified chat transport wrapper", SelfTest_TextContains(mainText, "ChatTransport_Send(text") && SelfTest_TextContains(mainText, "SendChatMemory(text)"))
    Diagnostics_AddCheck(report, "High", "Auto send mode is available", SelfTest_TextContains(mainText, "Auto|Memory|Keyboard"))
    Diagnostics_AddCheck(report, "High", "window-title locator and EXE fallback are present", SelfTest_TextContains(commonText, "GameLocator_Find(ByRef pid") && SelfTest_TextContains(commonText, "source := ""title""") && SelfTest_TextContains(commonText, "source := ""exe"""))

    Diagnostics_AddSection(report, "ChatLog and target ID")
    Diagnostics_AddLine(report, "ChatLog.Enabled=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "Enabled", "On"))
    Diagnostics_AddLine(report, "ChatLog.Path=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "Path", "<missing>"))
    Diagnostics_AddLine(report, "ChatLog.PlayerNickname=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "PlayerNickname", "<not set>"))
    Diagnostics_AddLine(report, "ChatLog.AutoCleanup=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "AutoCleanup", "On"))
    Diagnostics_AddLine(report, "ChatLog.MaxSizeKB=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "MaxSizeKB", "512"))
    Diagnostics_AddLine(report, "ChatLog.KeepTailKB=" . Diagnostics_ReadIniValue(profilesPath, "ChatLog", "KeepTailKB", "32"))
    Diagnostics_AddLine(report, "AutoTargetIDEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AutoTargetIDEnabled", "On"))
    Diagnostics_AddCheck(report, "High", "ChatLogReader routes lookups through queue", SelfTest_SectionContains(mainText, "ChatLogReader_BeginLookup(actionName", "ChatQueue_Enqueue(""/id ", 2600))
    Diagnostics_AddCheck(report, "High", "RMB target resolver is present", SelfTest_TextContains(mainText, "AutoTargetID_Poll()") && SelfTest_TextContains(udfText, "getPlayerIdByPed(targetPed)"))

    Diagnostics_AddSection(report, "Context assistant (legacy/internal)")
    Diagnostics_AddLine(report, "AssistOOPEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistOOPEnabled", "On"))
    Diagnostics_AddLine(report, "AssistStunEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistStunEnabled", "On"))
    Diagnostics_AddLine(report, "AssistChaseEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistChaseEnabled", "On"))
    Diagnostics_AddLine(report, "AssistHouseEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistHouseEnabled", "On"))
    Diagnostics_AddLine(report, "AssistDrugsEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistDrugsEnabled", "On"))
    Diagnostics_AddLine(report, "AssistPDPCuffEnabled=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "AssistPDPCuffEnabled", "On"))
    Diagnostics_AddLine(report, "Registration: disabled; profile values are retained only for backward compatibility")
    Diagnostics_AddCheck(report, "High", "six context actions remain internal and unregistered"
        , V1_CheckCatalog(contextCatalogDetails), contextCatalogDetails)
    Diagnostics_AddCheck(report, "Critical", "context actions use queue", SelfTest_SectionContains(mainText, "ContextAssistant_Execute(actionName", "ChatQueue_Enqueue(commandText", 7000))

    Diagnostics_AddSection(report, "Official legislation corpus")
    corpusAudit := LawCorpus_Audit()
    lawAudit := LawSearch_AuditIndex()
    mapAudit := TerritoryMap_AuditCatalog()
    Diagnostics_AddLine(report, "Source: https://forum.amazing-online.com/forums/zakonodatelstvo.732/")
    Diagnostics_AddLine(report, "TerritoryMapMode=" . Diagnostics_ReadIniValue(profilesPath, profileSection, "TerritoryMapMode", "Local"))
    Diagnostics_AddCheck(report, "Critical", "20 official documents are readable"
        , corpusAudit.Ok && corpusAudit.Documents = 20
        , "docs=" . corpusAudit.Documents . ", chars=" . corpusAudit.Characters)
    Diagnostics_AddCheck(report, "Critical", "every detected article heading is indexed"
        , lawAudit.Ok && lawAudit.Documents = 20
        , "pages=" . lawAudit.Pages . ", headings=" . lawAudit.Headings . ", failures=" . lawAudit.Failures.Length())
    Diagnostics_AddCheck(report, "High", "11 territory map groups and all local assets"
        , mapAudit.Ok && mapAudit.Groups = 11
        , "groups=" . mapAudit.Groups . ", failures=" . mapAudit.Issues.Length())
    Diagnostics_AddCheck(report, "Critical", "law-query capture never submits chat"
        , InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "{Esc}")
        && !InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "{Enter}")
        && !InStr(V1_GetBetween(mainText, "CaptureChatClipboard(cancelChat := false)", "MatchGpsEnterCommand("), "SendChat("))

    Diagnostics_AddSection(report, "Bind-list summary")
    catalog := GetBindCatalog()
    hotkeyVarCount := 0
    triggerVarCount := 0
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            hotkeyVarCount += 1
        if (meta.TriggerVar != "")
            triggerVarCount += 1
    }
    Diagnostics_AddLine(report, "Catalog items: " . catalog.Length())
    Diagnostics_AddLine(report, "Hotkey fields: " . hotkeyVarCount)
    Diagnostics_AddLine(report, "Trigger fields: " . triggerVarCount)

    Diagnostics_AddSection(report, "Bind conflict scan")
    Diagnostics_CheckBindConflicts(report, mainText, profilesPath, profileSection)

    status := "PASS"
    if (DiagnosticsFailCount > 0)
        status := "FAIL"
    else if (DiagnosticsWarnCount > 0 || DiagnosticsNoteCount > 0)
        status := "WARN"

    Diagnostics_AddSection(report, "Summary")
    Diagnostics_AddLine(report, "Status: " . status)
    Diagnostics_AddLine(report, "Total checks: " . DiagnosticsTotal)
    Diagnostics_AddLine(report, "Failures: " . DiagnosticsFailCount)
    Diagnostics_AddLine(report, "Warnings: " . DiagnosticsWarnCount)
    Diagnostics_AddLine(report, "Notes: " . DiagnosticsNoteCount)

    wroteReport := Diagnostics_WriteReport(report)
    return wroteReport && DiagnosticsFailCount = 0
}

Diagnostics_AddSection(ByRef report, title) {
    report .= "`r`n== " . title . " ==`r`n"
}

Diagnostics_AddLine(ByRef report, line) {
    report .= line . "`r`n"
}

Diagnostics_AddCheck(ByRef report, severity, name, ok, details := "") {
    global DiagnosticsFailCount, DiagnosticsWarnCount, DiagnosticsNoteCount, DiagnosticsTotal

    DiagnosticsTotal += 1
    if (ok)
        status := "PASS"
    else if (severity = "Low")
        status := "NOTE"
    else if (severity = "Medium")
        status := "WARN"
    else
        status := "FAIL"

    if (!ok)
    {
        if (severity = "Critical" || severity = "High")
            DiagnosticsFailCount += 1
        else if (severity = "Medium")
            DiagnosticsWarnCount += 1
        else
            DiagnosticsNoteCount += 1
    }

    report .= "[" . status . "] " . severity . " | " . name
    if (details != "")
        report .= " | " . details
    report .= "`r`n"
}

Diagnostics_WriteReport(report) {
    reportPath := A_ScriptDir . "\diagnostics_report.txt"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    return !ErrorLevel
}

Diagnostics_CollectFileInfo(ByRef report, path, label) {
    exists := FileExist(path)
    Diagnostics_AddCheck(report, "High", label . " exists", exists, path)
    if (!exists)
        return

    FileGetSize, fileSize, %path%
    Diagnostics_AddCheck(report, "High", label . " non-empty", (fileSize > 0), "size=" . fileSize)
    Diagnostics_AddCheck(report, "High", label . " has no BOM", SelfTest_HasNoBom(path), path)
}

Diagnostics_ReadSelfTestSummary(ByRef report, selftestPath) {
    if (!FileExist(selftestPath))
    {
        Diagnostics_AddCheck(report, "Medium", "selftest_report.txt exists", false, selftestPath)
        return
    }

    tail := Diagnostics_ReadTail(selftestPath, 8)
    Diagnostics_AddLine(report, tail)
}

Diagnostics_ReadTail(path, maxLines := 40) {
    if (!FileExist(path))
        return "not found: " . path

    FileRead, content, %path%
    if (ErrorLevel)
        return "read failed: " . path

    lines := []
    Loop, Parse, content, `n, `r
        lines.Push(A_LoopField)

    total := lines.Length()
    if (total <= 0)
        return "<empty>"

    startIndex := total - maxLines + 1
    if (startIndex < 1)
        startIndex := 1

    out := ""
    Loop % total - startIndex + 1
    {
        idx := startIndex + A_Index - 1
        if (out != "")
            out .= "`r`n"
        out .= lines[idx]
    }
    return out
}

Diagnostics_GetActiveConfigPath(projectDir) {
    updatedPath := projectDir . "\profiles_updated.ini"
    if FileExist(updatedPath)
        return updatedPath
    return projectDir . "\profiles.ini"
}

Diagnostics_ReadIniValue(filePath, sectionName, keyName, defaultValue := "") {
    if (!FileExist(filePath) || sectionName = "" || keyName = "")
        return defaultValue
    IniRead, value, %filePath%, %sectionName%, %keyName%, %defaultValue%
    return value
}

Diagnostics_GetGlobalDefault(text, varName) {
    marker := "global " . varName . " :="
    pos := InStr(text, marker)
    if (!pos)
        return ""

    lineEnd := InStr(text, "`n", false, pos)
    if (!lineEnd)
        lineEnd := StrLen(text) + 1
    line := SubStr(text, pos, lineEnd - pos)
    assignPos := InStr(line, ":=")
    if (!assignPos)
        return ""

    value := Trim(SubStr(line, assignPos + 2))
    if (SubStr(value, 1, 1) = """")
    {
        value := SubStr(value, 2)
        quotePos := InStr(value, """")
        if (quotePos)
            value := SubStr(value, 1, quotePos - 1)
    }
    return value
}

Diagnostics_NormalizeHotkeyForCompare(value) {
    value := Trim(value)
    if (value = "ERROR")
        return ""
    StringLower, value, value
    return value
}

Diagnostics_NormalizeTriggerForCompare(value) {
    value := Trim(value)
    if (value = "ERROR")
        return ""
    if (value != "" && SubStr(value, 1, 1) != "!")
        value := "!" . value
    StringLower, value, value
    return value
}

Diagnostics_AppendList(ByRef text, item) {
    if (text != "")
        text .= "; "
    text .= item
}

Diagnostics_TextHasLabel(text, labelName) {
    if (labelName = "")
        return false
    return (InStr(text, labelName . ":") > 0)
}

Diagnostics_CheckBindConflicts(ByRef report, mainText, profilesPath, profileSection) {
    catalog := GetBindCatalog()
    tokens := {}
    hotkeys := {}
    triggers := {}
    duplicateTokens := ""
    duplicateHotkeys := ""
    duplicateTriggers := ""
    missingLabels := ""
    wantedTrigger := ""
    searchTriggerConflict := false

    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        token := meta.Token
        if (tokens.HasKey(token))
            Diagnostics_AppendList(duplicateTokens, token)
        else
            tokens[token] := 1

        if (meta.HotkeyVar != "")
        {
            defaultHotkey := Diagnostics_GetGlobalDefault(mainText, meta.HotkeyVar)
            hotkeyValue := Diagnostics_ReadIniValue(profilesPath, profileSection, meta.HotkeyVar, defaultHotkey)
            hotkeyKey := Diagnostics_NormalizeHotkeyForCompare(hotkeyValue)
            if (hotkeyKey != "")
            {
                if (hotkeys.HasKey(hotkeyKey))
                    Diagnostics_AppendList(duplicateHotkeys, hotkeyValue . " -> " . hotkeys[hotkeyKey] . " / " . meta.HotkeyVar)
                else
                    hotkeys[hotkeyKey] := meta.HotkeyVar
            }

            if (token != "OpenSettings" && token != "ToggleBindList" && token != "ToggleHUD")
            {
                labelName := GetBoundLabelByToken(token)
                if (labelName = "" || !Diagnostics_TextHasLabel(mainText, labelName))
                    Diagnostics_AppendList(missingLabels, token . " -> " . labelName)
            }
        }

        if (meta.TriggerVar != "")
        {
            defaultTrigger := Diagnostics_GetGlobalDefault(mainText, meta.TriggerVar)
            triggerValue := Diagnostics_ReadIniValue(profilesPath, profileSection, meta.TriggerVar, defaultTrigger)
            triggerKey := Diagnostics_NormalizeTriggerForCompare(triggerValue)
            if (meta.TriggerVar = "Trig_WantedList")
                wantedTrigger := triggerValue
            if (triggerKey != "")
            {
                if (triggers.HasKey(triggerKey))
                    Diagnostics_AppendList(duplicateTriggers, triggerValue . " -> " . triggers[triggerKey] . " / " . meta.TriggerVar)
                else
                    triggers[triggerKey] := meta.TriggerVar
            }
        }
    }

    searchKey := "!пнайти"
    StringLower, searchKey, searchKey
    if (triggers.HasKey(searchKey))
        searchTriggerConflict := true

    Diagnostics_AddCheck(report, "High", "duplicate catalog tokens", (duplicateTokens = ""), duplicateTokens)
    Diagnostics_AddCheck(report, "Medium", "duplicate non-empty hotkeys", (duplicateHotkeys = ""), duplicateHotkeys)
    Diagnostics_AddCheck(report, "Medium", "duplicate non-empty triggers", (duplicateTriggers = ""), duplicateTriggers)
    Diagnostics_AddCheck(report, "High", "missing labels for hotkey catalog actions", (missingLabels = ""), missingLabels)
    Diagnostics_AddCheck(report, "Medium", "WantedList trigger is present", (Trim(wantedTrigger) != ""), "Trig_WantedList=" . wantedTrigger)
    Diagnostics_AddCheck(report, "Medium", "fixed search trigger conflict", !searchTriggerConflict, "!пнайти")
}
NormalizeColorNumber(ByRef val) {

    original := val
    val := Trim(val)
    val := StrReplace(val, "#")
    val := StrReplace(val, "0x")
    val := StrReplace(val, "0X")
    if (val = "ERROR")
        val := ""
    if (val = "")
        return
    if !RegExMatch(val, "i)^[0-9A-F]{6}$")
    {
        LogUIError("Bad HEX color reset: " . original)
        val := ""
    }
}

LogError(source, message, level := "ERROR") {
    global LogDir, ModernLogFile, AuditTestMode
    if (LogDir = "")
        LogDir := A_ScriptDir . "\logs"
    if (ModernLogFile = "")
        ModernLogFile := LogDir . "\amz_gos.log"
    try {
    FileCreateDir, %LogDir%
    RotateOwnedLog(ModernLogFile)
    line := "[" . A_Now . "] [" . level . "] [" . source . "] " . SubStr(message, 1, 4096) . "`r`n"
    FileAppend, %line%, %ModernLogFile%, CP1251
    return !ErrorLevel
    } catch e {
        return false
    }
}

LogUIError(message) {
    LogError("UI", message)
}

ColorBrightness(hex) {
    NormalizeColorNumber(hex)
    if (hex = "")
        return 0
    r := HexToDec(SubStr(hex,1,2))
    g := HexToDec(SubStr(hex,3,2))
    b := HexToDec(SubStr(hex,5,2))
    return (r*299 + g*587 + b*114) // 1000
}

ShiftHexColor(hex, delta) {
    NormalizeColorNumber(hex)
    if (hex = "")
        return ""
    r := HexToDec(SubStr(hex,1,2)) + delta
    g := HexToDec(SubStr(hex,3,2)) + delta
    b := HexToDec(SubStr(hex,5,2)) + delta
    if (r < 0)
        r := 0
    if (r > 255)
        r := 255
    if (g < 0)
        g := 0
    if (g > 255)
        g := 255
    if (b < 0)
        b := 0
    if (b > 255)
        b := 255
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

NormalizeNumberRange(ByRef val, defaultVal, minVal, maxVal) {
    val := Trim(val)
    if (val = "" or val = "ERROR")
    {
        val := defaultVal
        return
    }
    val += 0
    if (val < minVal)
        val := minVal
    if (val > maxVal)
        val := maxVal
}

NormalizeOnOff(ByRef val, defaultVal := "Off") {
    val := Trim(val)
    if (val != "On" && val != "Off")
        val := defaultVal
}

NormalizeFullscreenSafeGui(ByRef val) {
    val := Trim(val)
    if (val != "Auto" && val != "On" && val != "Off")
        val := "Auto"
}

NormalizeThemeMode(ByRef val) {
    val := Trim(val)
    if (val != "Graphite" && val != "Light" && val != "Black" && val != "Midnight" && val != "Emerald" && val != "Amber" && val != "Rose")
        val := "Graphite"
}

NormalizeTextSendMode(ByRef val) {
    val := ChatTyping_ModeFromLabel(val)
}

NormalizeIDEntryMode(ByRef val) {
    val := Trim(val)
    if (val != "Перехват цифр" && val != "Через чат")
        val := "Перехват цифр"
}

NormalizeGameProcessName(ByRef val) {
    val := Trim(val)
    SplitPath, val, fileName
    if (fileName != "")
        val := fileName
    if !RegExMatch(val, "i)^[a-z0-9_.-]+\.exe$")
        val := "gta_sa.exe"
}

NormalizeGameWindowTitle(ByRef val) {
    val := Trim(RegExReplace(val, "(`r|`n)+", " "))
    if (val = "")
        val := "AMAZING ONLINE"
}

NormalizeSHA256(ByRef val) {
    val := RegExReplace(Trim(val), "i)[^a-f0-9]")
    StringUpper, val, val
    if (val != "" && StrLen(val) != 64)
        val := ""
}

ApplyGameProcessSelector() {
    global GameWindowTitle, GameProcessName
    NormalizeGameWindowTitle(GameWindowTitle)
    NormalizeGameProcessName(GameProcessName)
    GameLocator_Configure(GameWindowTitle, GameProcessName)
}

NormalizeProfileNameValue(ByRef val) {
    val := Trim(val)
    val := StrReplace(val, "|", " ")
    val := StrReplace(val, "[", "(")
    val := StrReplace(val, "]", ")")
    val := StrReplace(val, ";", ",")
    val := StrReplace(val, "=", "-")
    val := RegExReplace(val, "(`r|`n)+", " ")
    val := RegExReplace(val, "\+", "-")
    val := RegExReplace(val, "/+", "-")
    val := RegExReplace(val, "\s{2,}", " ")
    if (val = "")
        val := "Основной"
}

NormalizeSingleLineValue(ByRef val, defaultVal := "") {
    val := Trim(val)
    val := RegExReplace(val, "(`r|`n)+", " ")
    val := RegExReplace(val, "\s{2,}", " ")
    if (val = "")
        val := defaultVal
}

CreateConfigBackup(reason := "save", force := 0) {
    global ConfigFile, ProfileSaveBackups

    if (!force && ProfileSaveBackups != "On")
        return ""
    if !FileExist(ConfigFile)
    {
        LogError("CreateConfigBackup", "Config file not found: " . ConfigFile)
        return ""
    }

    backupDir := A_ScriptDir . "\backups"
    FileCreateDir, %backupDir%
    if (ErrorLevel)
    {
        LogError("CreateConfigBackup", "Cannot create backup directory: " . backupDir)
        return ""
    }
    safeReason := RegExReplace(reason, "[^0-9A-Za-z_-]+", "_")
    backupFile := backupDir . "\profiles_backup_" . A_Now . "_" . TickNow() . "_" . safeReason . ".ini"
    FileCopy, %ConfigFile%, %backupFile%, 1
    if (ErrorLevel || !FileExist(backupFile))
    {
        LogError("CreateConfigBackup", "Backup copy failed: " . ConfigFile . " -> " . backupFile)
        return ""
    }
    PruneOwnedBackups(backupDir)
    return backupFile
}

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
        bg := "121821"
        panel := "1B2430"
        text := "EBF0F7"
        accent := "79A8F5"
        muted := "A8B5C7"
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
    controlText := EnsureTextContrast(controlText, controlBg, controlBg)
}

HexToBGR(hex) {
    NormalizeColorNumber(hex)
    if (hex = "")
        return 0
    value := "0x" . hex
    red := (value >> 16) & 255
    green := (value >> 8) & 255
    blue := value & 255
    return (blue << 16) | (green << 8) | red
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

PromoteOverlayWindow(hwnd, keepShown := 1, noActivate := 0) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return
    flags := 0x0001 | 0x0002
    if (noActivate)
        flags |= 0x0010
    if (keepShown && DllCall("IsWindowVisible", "Ptr", hwnd))
        flags |= 0x0040
    WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
}

AddOutlinedPanel(guiNum, x, y, w, h, fillColor, borderColor, borderSize := 3) {
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

SaveThemePreset(themeName) {
    global ThemesFile, CFG_ThemePresetName, CFG_ThemeMode
    NormalizeProfileNameValue(themeName)
    if (themeName = "")
        return false
    stage := ConfigStage(ThemesFile)
    if (stage = "")
        return false
    WriteCurrentThemeToFile(stage, "Theme_" . themeName)
    if !ConfigCommit(stage, ThemesFile)
        return false
    CFG_ThemePresetName := themeName
    CFG_ThemeMode := themeName
    return true
}

LoadThemePreset(themeName) {
    global ThemesFile, CFG_ThemePresetName, CFG_ThemeMode
    NormalizeProfileNameValue(themeName)
    if (themeName = "")
    {
        LogError("LoadThemePreset", "Empty preset name.")
        return 0
    }
    section := "Theme_" . themeName
    if !LoadThemeFromFile(ThemesFile, section)
    {
        LogError("LoadThemePreset", "Preset not found or invalid: " . themeName)
        return 0
    }
    CFG_ThemePresetName := themeName
    CFG_ThemeMode := themeName
    return 1
}

ShowSettingsWindow() {
    global SettingsX, SettingsY, SettingsW, SettingsH, hSettingsWnd
    global MenuTransparency, UIRoundness, InnerRoundness
    Settings_NormalizeViewport()
    Gui, 2:-DPIScale
    Capture_BeforeShow("2")
    Gui, 2:Show, % "x" . SettingsX . " y" . SettingsY . " w" . SettingsW . " h" . SettingsH, Настройки профиля
    Gui, 2:+DPIScale
    Settings_UpdateScrollbars()
    WinActivate, ahk_id %hSettingsWnd%
    settingsAlpha := 255
    PromoteOverlayWindow(hSettingsWnd)
    WinSet, Transparent, %settingsAlpha%, ahk_id %hSettingsWnd%
    ApplyRoundedCorners(hSettingsWnd, 0)
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

UpdateLawGuiColors() {
    global LawGuiTextColor, LawGuiBgColor
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    LawGuiBgColor := panel
    LawGuiTextColor := text
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

GetNotifySoundPath(kind := "info") {
    mediaDir := A_WinDir . "\Media\"

    if (kind = "warn" || kind = "error")
    {
        if FileExist(mediaDir . "Windows Critical Stop.wav")
            return mediaDir . "Windows Critical Stop.wav"
        if FileExist(mediaDir . "Windows Error.wav")
            return mediaDir . "Windows Error.wav"
        if FileExist(mediaDir . "Windows Exclamation.wav")
            return mediaDir . "Windows Exclamation.wav"
    }

    if FileExist(mediaDir . "Windows Notify System Generic.wav")
        return mediaDir . "Windows Notify System Generic.wav"
    if FileExist(mediaDir . "Windows Notify Calendar.wav")
        return mediaDir . "Windows Notify Calendar.wav"
    if FileExist(mediaDir . "notify.wav")
        return mediaDir . "notify.wav"
    if FileExist(mediaDir . "chimes.wav")
        return mediaDir . "chimes.wav"
    if FileExist(mediaDir . "ding.wav")
        return mediaDir . "ding.wav"

    return ""
}

PlayNotifySound(kind := "info") {
    global NotifySoundEnabled, NotifyVolume, NotifyPlayer

    if (NotifySoundEnabled != "On")
        return

    NormalizeNumberRange(NotifyVolume, 65, 0, 100)
    soundFile := GetNotifySoundPath(kind)

    if (soundFile != "")
    {
        try
        {
            if IsObject(NotifyPlayer)
                NotifyPlayer.controls.stop()
        }
        try
        {
            NotifyPlayer := ComObjCreate("WMPlayer.OCX.7")
            NotifyPlayer.settings.volume := NotifyVolume
            NotifyPlayer.URL := soundFile
            NotifyPlayer.controls.play()
            return
        }
    }

    if (kind = "warn" || kind = "error")
        SoundBeep, 500, 120
    else
        SoundBeep, 900, 90
}

PlayStopTimerSound() {
    global StopTimerCustomSound, StopTimerVolume, StopTimerPlayer

    NormalizeNumberRange(StopTimerVolume, 65, 0, 100)
    soundFile := ""
    if (StopTimerCustomSound != "" && FileExist(StopTimerCustomSound))
        soundFile := StopTimerCustomSound
    else
        soundFile := GetNotifySoundPath("info")

    if (soundFile != "")
    {
        try
        {
            if IsObject(StopTimerPlayer)
                StopTimerPlayer.controls.stop()
        }
        try
        {
            StopTimerPlayer := ComObjCreate("WMPlayer.OCX.7")
            StopTimerPlayer.settings.volume := StopTimerVolume
            StopTimerPlayer.URL := soundFile
            StopTimerPlayer.controls.play()
            return
        }
    }

    if (StopTimerVolume > 0)
        SoundBeep, 900, 90
}

Notify(kind := "info") {
    PlayNotifySound(kind)
}

GameNotify(message, level := "INFO") {
    global MockMode
    message := Trim(message)
    if (message = "")
        return false

    if (level = "ERROR")
        color := 0xE45B5B
    else if (level = "WARN")
        color := 0xE0A64B
    else
        color := 0x3AA675

    if (MockMode = "On") {
        MockPreview_Append("[AHK FOR GOS BY SBEZRUK] " . message)
        return true
    }

    pid := GameLocator_GetPID()
    if (pid && addChatMessageEx(color, "{3AA675}[AHK FOR GOS BY SBEZRUK]{FFFFFF} " . message) = 1)
        return true

    ToolTip, %message%
    SetTimer, RemoveToolTip, -2200
    return false
}

GameInterface_ShowDialog(caption, text, style := 0, button1 := "OK", button2 := "", id := 32000) {
    global MockMode
    if (MockMode = "On") {
        MockPreview_Append("[DIALOG] " . caption . ": " . text)
        return true
    }
    if (GameLocator_GetPID() && showDialog(style, caption, text, button1, button2, id) = 1)
        return true
    GameNotify(caption . ": " . RegExReplace(text, "(`r|`n)+", " "), "WARN")
    return false
}

GetAzmpModuleInfo(force := 0) {
    global AzmpInfoCache, AzmpExpectedSHA256, GAME_MP_ModulePath
    info := {Ready: 0, Path: "", Version: "", SHA256: "", Expected: "", Match: 0, Status: ""}
    if !(refreshGTA() && refreshSAMP(1)) {
        info.Status := MemoryGetShortError()
        return info
    }

    modulePath := GAME_MP_ModulePath
    if (modulePath = "" || !FileExist(modulePath)) {
        info.Status := "путь azmp.dll не получен"
        return info
    }

    FileGetSize, moduleSize, %modulePath%
    FileGetTime, moduleTime, %modulePath%, M
    cacheKey := modulePath . "|" . moduleSize . "|" . moduleTime . "|" . AzmpExpectedSHA256
    if (!force && IsObject(AzmpInfoCache) && AzmpInfoCache.CacheKey = cacheKey)
        return AzmpInfoCache

    expectedHash := AzmpExpectedSHA256
    NormalizeSHA256(expectedHash)
    moduleHash := FileSHA256(modulePath)
    moduleVersion := GetFileVersionSafe(modulePath)
    if (moduleVersion = "")
        moduleVersion := "нет FileVersion"

    info.Ready := (moduleHash != "") ? 1 : 0
    info.Path := modulePath
    info.Version := moduleVersion
    info.SHA256 := moduleHash
    info.Expected := expectedHash
    info.Match := (expectedHash != "" && moduleHash = expectedHash) ? 1 : 0
    if (!info.Ready)
        info.Status := "SHA-256 не вычислен"
    else if (expectedHash = "")
        info.Status := "SHA-256 получен, эталон не задан"
    else if (info.Match)
        info.Status := "SHA-256 совпадает"
    else
        info.Status := "SHA-256 НЕ совпадает"
    info.CacheKey := cacheKey
    AzmpInfoCache := info
    return info
}

GetAzmpCompatibilitySummary(force := 0) {
    info := GetAzmpModuleInfo(force)
    if (!info.Ready)
        return "azmp.dll: " . info.Status
    shortHash := SubStr(info.SHA256, 1, 12)
    return "azmp.dll " . info.Version . " | SHA-256 " . shortHash . "... | " . info.Status
}

MemoryLiveTest_WriteReport(state, finalStatus := "") {
    global MemoryLiveTestResult, GameWindowTitle, GameProcessName
    reportPath := A_ScriptDir . "\memory_live_test_report.txt"
    if !IsObject(MemoryLiveTestResult)
        MemoryLiveTestResult := {}
    FormatTime, completedAt,, yyyy-MM-dd HH:mm:ss
    report := "AHK FOR GOS BY SBEZRUK Memory live-test`r`n"
    report .= "Completed: " . completedAt . "`r`n"
    report .= "WindowTitle: " . GameWindowTitle . "`r`n"
    report .= "FallbackEXE: " . GameProcessName . "`r`n"
    report .= "azmp.dll: " . (MemoryLiveTestResult.HasKey("Azmp") ? MemoryLiveTestResult.Azmp : GetAzmpCompatibilitySummary(1)) . "`r`n"
    report .= "/time: " . (MemoryLiveTestResult.HasKey("Time") ? MemoryLiveTestResult.Time : "не выполнялся") . "`r`n"
    report .= "Russian message: " . (MemoryLiveTestResult.HasKey("Russian") ? MemoryLiveTestResult.Russian : "не выполнялось") . "`r`n"
    report .= "Result: " . finalStatus . "`r`n"
    report .= "Last memory state: " . MemoryGetStatusText() . "`r`n"
    FileDelete, %reportPath%
    FileAppend, %report%, %reportPath%
    MemoryLiveTestResult.ReportPath := reportPath
    MemoryLiveTestResult.State := state
    return reportPath
}

MemoryLiveTest_Finish(success, statusText) {
    global MemoryLiveTestMode, MemoryLiveTestResult
    reportPath := MemoryLiveTest_WriteReport(success ? "PASS" : "FAIL", statusText)
    LogError("MemoryLiveTest", statusText . " | report=" . reportPath, success ? "INFO" : "ERROR")
    GameNotify(statusText, success ? "INFO" : "ERROR")
    if (MemoryLiveTestMode)
        SetTimer, MemoryLiveTestExitLabel, -350
    return success
}

MemoryLiveTest_SendRussian(payload := "") {
    global MemoryLiveTestResult
    testMessage := (payload != "") ? payload : "Проверка Memory AHK FOR GOS BY SBEZRUK: русское сообщение."
    result := SendChatMemory(testMessage)
    memoryStatus := MemoryGetStatusText()
    if !IsObject(MemoryLiveTestResult)
        MemoryLiveTestResult := {}
    MemoryLiveTestResult.Russian := (result = 1) ? "PASS | " . memoryStatus : "FAIL | " . memoryStatus
    if (result != 1)
        return MemoryLiveTest_Finish(false, "Русское сообщение не отправлено: " . MemoryGetShortError())
    return MemoryLiveTest_Finish(true, "Memory live-тест пройден: /time и русское сообщение отправлены.")
}

RunMemoryLiveTest(showPrompt := 1) {
    global MockMode, MemoryLiveTestMode, MemoryLiveTestResult
    MemoryLiveTestResult := {}
    if (MemoryLiveTestMode)
        MockMode := "Off"
    if (MockMode = "On") {
        MemoryLiveTestResult.Time := "FAIL | MockMode включён"
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "Отключи MockMode для live-теста Memory.")
    }

    ApplyGameProcessSelector()
    if !checkHandles() {
        MemoryLiveTestResult.Time := "FAIL | " . MemoryGetStatusText()
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "Memory не подключён: " . MemoryGetShortError())
    }

    MemoryLiveTestResult.Azmp := GetAzmpCompatibilitySummary(1)
    result := SendChatMemory("/time")
    memoryStatus := MemoryGetStatusText()
    MemoryLiveTestResult.Time := (result = 1) ? "PASS | " . memoryStatus : "FAIL | " . memoryStatus
    if (result != 1) {
        MemoryLiveTestResult.Russian := "не выполнялось"
        return MemoryLiveTest_Finish(false, "/time не отправлен: " . MemoryGetShortError())
    }

    TaskScheduler_Set("MemoryLiveTest", 1200, "MemoryLiveTest_SendRussian", "Memory live-test", "Проверка Memory AHK FOR GOS BY SBEZRUK: русское сообщение.")
    if (showPrompt)
        GameNotify("/time отправлен. Через 1.2 сек. будет отправлена русская тестовая строка.", "INFO")
    return true
}

AzmpAllowsTargetRead() {
    return checkReadHandles()
}

HasCurrentID() {
    global UserID
    return RegExMatch(UserID . "", "^\d+$") ? true : false
}

IsGameActive() {
    global MockMode
    if (MockMode = "On")
        return true
    return GameLocator_IsActive()
}

EnsureGameActive() {
    global MockMode
    if (MockMode = "On")
        return true
    if IsGameActive()
        return true
    Notify("warn")
    return false
}

GetCrosshairTargetPed(ByRef errorCode := "", ByRef errorDetail := "") {
    global hGTA
    errorCode := ""
    errorDetail := ""
    if (!checkReadHandles()) {
        errorCode := "HANDLE_CHECK_FAILED"
        errorDetail := MemoryGetStatusText()
        return 0
    }

    ; В GTA SA адрес 0xB6F3B8 используется как Pointer to Target/current entity.
    ; Именно от него +0x79C исторически даёт Targetted CPed и этот путь работал
    ; в Amazing/SA-MP до fixed8. 0xB6F5F0 оставляем только резервным CPlayerPed.
    primaryBase := readDWORD(hGTA, 0xB6F3B8)
    fallbackBase := readDWORD(hGTA, 0xB6F5F0)
    primaryTarget := IsLikelyPointer(primaryBase) ? readDWORD(hGTA, primaryBase + 0x79C) : 0
    fallbackTarget := IsLikelyPointer(fallbackBase) ? readDWORD(hGTA, fallbackBase + 0x79C) : 0

    localPed := 0
    pedPtr1 := 0
    targetSource := ""

    ; Сначала используем старый рабочий источник. Резерв выбирается только если
    ; первый не даёт живой CPed из GTA pool. Так fixed8 больше не подменяет цель
    ; полем из другого объекта, но остаётся запасной путь для обычной GTA SA.
    if (IsLikelyPointer(primaryTarget) && AZMP_IsPedInGtaPool(primaryTarget, primarySlot, 1)) {
        localPed := primaryBase
        pedPtr1 := primaryTarget
        targetSource := "B6F3B8"
    } else if (IsLikelyPointer(fallbackTarget) && AZMP_IsPedInGtaPool(fallbackTarget, fallbackSlot, 1)) {
        localPed := fallbackBase
        pedPtr1 := fallbackTarget
        targetSource := "B6F5F0_FALLBACK"
    }

    if (!localPed) {
        if (!IsLikelyPointer(primaryBase) && !IsLikelyPointer(fallbackBase)) {
            errorCode := "TARGET_MANAGER_INVALID"
            errorDetail := "targetBase=" . primaryBase . ", playerBase=" . fallbackBase
                . ", " . MemoryGetStatusText()
            return 0
        }
        if (!IsLikelyPointer(primaryTarget) && !IsLikelyPointer(fallbackTarget)) {
            errorCode := "NO_CROSSHAIR_PED"
            errorDetail := "B6F3B8 target=" . primaryTarget . ", B6F5F0 target=" . fallbackTarget
            return 0
        }
        errorCode := "TARGET_PED_OUTSIDE_GTA_POOL"
        errorDetail := "B6F3B8 target=" . Format("0x{:08X}", primaryTarget)
            . ", B6F5F0 target=" . Format("0x{:08X}", fallbackTarget)
            . ", ни один адрес не является занятым CPed GTA pool"
        return 0
    }

    ; Два чтения защищают от смены цели; после поиска ID цель проверяется заново.
    pedPtr2 := readDWORD(hGTA, localPed + 0x79C)
    if (pedPtr2 != pedPtr1) {
        errorCode := "TARGET_PED_UNSTABLE"
        errorDetail := targetSource . ": target changed " . Format("0x{:08X}", pedPtr1)
            . " -> " . Format("0x{:08X}", pedPtr2)
        return 0
    }

    if !AZMP_IsPedInGtaPool(pedPtr1, pedSlot, 1) {
        errorCode := "TARGET_PED_OUTSIDE_GTA_POOL"
        errorDetail := targetSource . ": target=" . Format("0x{:08X}", pedPtr1)
            . ", адрес перестал быть занятым элементом GTA CPed pool"
        return 0
    }

    matrixPtr := readDWORD(hGTA, pedPtr1 + 0x14)
    if (!IsLikelyPointer(matrixPtr) || Mod(matrixPtr, 4) != 0) {
        errorCode := "TARGET_PED_STALE"
        errorDetail := targetSource . ": ped=" . Format("0x{:08X}", pedPtr1) . ", matrix=" . matrixPtr
        return 0
    }
    return pedPtr1
}

GetPedCoordinates(pedPtr) {
    if (!checkReadHandles() || !AZMP_IsValidGamePed(pedPtr))
        return 0
    return AZMP_GetGamePedCoordinates(pedPtr)
}

GetCrosshairTargetDistance(ByRef source := "") {
    global ActiveID, UserID, TargetIsMask
    source := ""
    selfCoords := getPlayerCoordinates()
    if !IsObject(selfCoords)
        return -1

    pedPtr := 0
    if (ActiveID && !TargetIsMask && RegExMatch(UserID . "", "^\d{1,4}$")) {
        pedPtr := getPlayerPedById(UserID + 0)
        if IsLikelyPointer(pedPtr)
            source := "выбранный ID " . UserID
    }

    if !IsLikelyPointer(pedPtr) {
        pedPtr := GetCrosshairTargetPed()
        if IsLikelyPointer(pedPtr)
            source := "персонаж под прицелом"
    }
    if !IsLikelyPointer(pedPtr)
        return -1

    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(targetCoords)
        return -1

    dx := selfCoords[1] - targetCoords[1]
    dy := selfCoords[2] - targetCoords[2]
    dz := selfCoords[3] - targetCoords[3]
    return Sqrt(dx*dx + dy*dy + dz*dz)
}

GetCameraLookAngleToPed(pedPtr) {
    camera := getCameraCoordinates()
    selfCoords := getPlayerCoordinates()
    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(camera) || !IsObject(selfCoords) || !IsObject(targetCoords)
        return -1

    vx := selfCoords[1] - camera[1]
    vy := selfCoords[2] - camera[2]
    vz := selfCoords[3] - camera[3]
    tx := targetCoords[1] - camera[1]
    ty := targetCoords[2] - camera[2]
    tz := targetCoords[3] - camera[3]
    viewLen := Sqrt(vx*vx + vy*vy + vz*vz)
    targetLen := Sqrt(tx*tx + ty*ty + tz*tz)
    if (viewLen < 0.2 || targetLen < 0.2)
        return -1
    cosine := (vx*tx + vy*ty + vz*tz) / (viewLen * targetLen)
    if (cosine > 1)
        cosine := 1
    else if (cosine < -1)
        cosine := -1
    return ACos(cosine) * 57.295779513
}

AutoTargetID_SetDiagnostic(code, detail := "") {
    global AutoTargetDiagCode, AutoTargetDiagDetail
    AutoTargetDiagCode := (code = "") ? "UNKNOWN" : code
    AutoTargetDiagDetail := detail
    return AutoTargetDiagCode
}

AutoTargetID_CodeDescription(code) {
    static descriptions := ""
    if !IsObject(descriptions) {
        descriptions := {}
        descriptions["HANDLE_INVALID"] := "потерян дескриптор процесса GTA"
        descriptions["HANDLE_CHECK_FAILED"] := "не удалось подготовить чтение памяти"
        descriptions["PLAYER_POOL_UNAVAILABLE"] := "не найден пул игроков azmp.dll"
        descriptions["POOL_READ_INCOMPLETE"] := "массив игроков прочитан не полностью"
        descriptions["NO_VALID_PLAYER_INFO"] := "в пуле не читаются структуры игроков"
        descriptions["NO_VALID_PEDS"] := "не читаются CPed игроков"
        descriptions["DUPLICATE_TARGET_PED"] := "один CPed связан с несколькими ID"
        descriptions["TARGET_MANAGER_INVALID"] := "сломался указатель менеджера прицела"
        descriptions["TARGET_PED_STALE"] := "указатель цели устарел"
        descriptions["TARGET_POINTER_OFF_AIM"] := "прицел завис на предыдущей цели"
        descriptions["TARGET_IS_LOCAL_PLAYER"] := "игра вернула собственного персонажа"
        descriptions["TARGET_NOT_IN_POOL"] := "цель не найдена в текущем пуле игроков"
        descriptions["TARGET_POOL_LAYOUT_UNRESOLVED"] := "структура PlayerInfo не дала точную связь с выбранным CPed"
        descriptions["TARGET_PED_OUTSIDE_GTA_POOL"] := "игра вернула адрес вне активного GTA CPed pool"
        descriptions["TARGET_PED_UNSTABLE"] := "цель изменилась во время чтения"
        descriptions["TARGET_POOL_DESYNC"] := "прицел GTA и пул игроков AZMP рассинхронизированы"
        descriptions["TARGET_POOL_DESYNC_REPAIRED"] := "устаревший код резервного поиска; ID не должен приниматься"
        descriptions["TARGET_CHANGED_DURING_AIM_FALLBACK"] := "цель изменилась во время резервной проверки"
        descriptions["TARGET_CHANGED_DURING_SCAN"] := "слот игрока изменился во время чтения"
        descriptions["TARGET_NAME_UNSTABLE"] := "ник изменился во время двух проверок"
        descriptions["MASK_LINK_PED_MISMATCH"] := "ID маски не соответствует выбранному PED"
        descriptions["NO_CROSSHAIR_PED"] := "под прицелом нет читаемой цели"
        descriptions["NO_EXACT_ID"] := "для CPed не найден точный ID"
        descriptions["AUTO_RECOVERY"] := "выполнено восстановление чтения памяти"
        descriptions["AUTO_RECOVERY_REOPEN_FAILED"] := "после сброса не удалось повторно открыть память игры"
    }
    return descriptions.HasKey(code) ? descriptions[code] : "неизвестная ошибка Auto ID"
}

AutoTargetID_ClearFailure() {
    global AutoTargetDiagFailStreak, AutoTargetDiagFirstFailTick
    AutoTargetDiagFailStreak := 0
    AutoTargetDiagFirstFailTick := 0
    return true
}

AutoTargetID_ResetDiagnosticState() {
    global AutoTargetDiagCode, AutoTargetDiagDetail
    AutoTargetDiagCode := "INIT"
    AutoTargetDiagDetail := ""
    return true
}

AutoTargetID_IsHardRecoveryCode(code) {
    return (code = "HANDLE_INVALID" || code = "HANDLE_CHECK_FAILED"
        || code = "PLAYER_POOL_UNAVAILABLE" || code = "POOL_READ_INCOMPLETE"
        || code = "NO_VALID_PLAYER_INFO" || code = "NO_VALID_PEDS"
        || code = "TARGET_MANAGER_INVALID")
}

AutoTargetID_WriteDiagnostic(code, detail, targetPed := 0, repaired := "") {
    global AutoTargetDiagFile
    FileCreateDir, % A_ScriptDir . "\logs"
    if IsFunc("AZMP_TargetDiagnosticSnapshot")
        snapshot := AZMP_TargetDiagnosticSnapshot(targetPed)
    else
        snapshot := MemoryGetStatusText()
    line := "[" . A_Now . "] code=" . code . "; detail=" . detail
        . "; repaired=" . repaired . "; " . snapshot . "`r`n"
    RotateOwnedLog(AutoTargetDiagFile)
    try FileAppend, %line%, %AutoTargetDiagFile%, CP1251
    LogError("AutoID-DIAG", code . ": " . detail . " | repaired=" . repaired . " | " . snapshot, "WARN")
    return snapshot
}

AutoTargetID_HardReset(reason := "") {
    global AutoTargetLastScanTick, AutoTargetRButtonLatched

    AutoTargetLastScanTick := 0
    AutoTargetRButtonLatched := 0
    AutoTargetID_ResetCandidate()
    AutoTargetID_ClearFailure()
    AutoTargetID_ResetDiagnosticState()
    if IsFunc("AZMP_ResetAutoIDRuntime")
        AZMP_ResetAutoIDRuntime(reason != "" ? reason : "Auto ID hard reset")
    else {
        AZMP_ResetTargetCache(reason != "" ? reason : "Auto ID hard reset")
        if IsFunc("AZMP_ResetGtaPedPoolCache")
            AZMP_ResetGtaPedPoolCache()
    }
    return true
}

AutoTargetID_DiagnoseAndRecover(showNotice := 1, attemptRepair := 1, knownTargetPed := 0) {
    global AutoTargetDiagCode, AutoTargetDiagDetail, AutoTargetDiagLastRunTick
    global AutoTargetDiagLastNoticeTick, hGTA, dwGTAPID

    if (!knownTargetPed) {
        knownTargetPed := GetCrosshairTargetPed(crossCode, crossDetail)
    } else {
        crossCode := ""
        crossDetail := ""
    }

    code := AutoTargetDiagCode
    detail := AutoTargetDiagDetail
    if (crossCode != "") {
        code := crossCode
        detail := crossDetail
    } else if IsFunc("AZMP_TargetDiagGetCode") {
        lowCode := AZMP_TargetDiagGetCode()
        lowDetail := AZMP_TargetDiagGetDetail()
        lowIsCurrent := !knownTargetPed || !IsFunc("AZMP_TargetDiagIsCurrent")
            || AZMP_TargetDiagIsCurrent(knownTargetPed, 750)
        if (lowIsCurrent && lowCode != "" && lowCode != "TARGET_OK" && lowCode != "INIT") {
            code := lowCode
            detail := lowDetail
        }
    }
    if (code = "" || code = "INIT") {
        code := knownTargetPed ? "NO_EXACT_ID" : "NO_CROSSHAIR_PED"
        detail := knownTargetPed ? "CPed цели есть, но ID не сопоставлен" : "под прицелом нет валидного CPed"
    }

    recoverable := AutoTargetID_IsHardRecoveryCode(code)
    softResettable := (code = "TARGET_PED_STALE" || code = "TARGET_PED_OUTSIDE_GTA_POOL"
        || code = "TARGET_PED_UNSTABLE" || code = "TARGET_POOL_LAYOUT_UNRESOLVED"
        || code = "TARGET_POOL_DESYNC" || code = "NO_EXACT_ID"
        || code = "DUPLICATE_TARGET_PED" || code = "TARGET_CHANGED_DURING_SCAN"
        || code = "TARGET_CHANGED_DURING_AIM_FALLBACK")
    repaired := "нет"
    if (attemptRepair && recoverable) {
        ; Все автоматические переоткрытия проходят через один координатор UDF.
        ; Его общий cooldown исключает двойной reset из UDF и main подряд.
        if IsFunc("AZMP_TargetDiagMaybeRecover") {
            if IsFunc("AZMP_TargetDiagSetContext")
                AZMP_TargetDiagSetContext(knownTargetPed, 0)
            if IsFunc("AZMP_TargetDiagSet")
                AZMP_TargetDiagSet(code, detail, 1, 0)
            recovered := AZMP_TargetDiagMaybeRecover(code, detail, 1)
            recoveryStatus := IsFunc("AZMP_TargetDiagGetRecoveryStatus")
                ? AZMP_TargetDiagGetRecoveryStatus() : ""
            repaired := recovered ? recoveryStatus
                : ((recoveryStatus != "") ? recoveryStatus : "восстановление не запущено")
        } else {
            recoveryStarted := IsFunc("MemoryInvalidateGameHandle")
                ? MemoryInvalidateGameHandle("Auto ID diagnostic: " . code) : false
            if (recoveryStarted) {
                Sleep, 30
                handleOk := checkReadHandles()
                poolOk := handleOk && IsFunc("AZMP_GetGtaPedPoolInfo")
                    && AZMP_GetGtaPedPoolInfo(recoverPool, recoverObjects, recoverFlags, recoverSize, 1)
                repaired := handleOk ? (poolOk ? "полностью переоткрыты память и CPed pool"
                    : "память переоткрыта; CPed pool будет перечитан") : "переоткрытие не удалось"
            } else {
                repaired := "восстановление отложено: память занята"
            }
        }
    } else if (attemptRepair && code = "TARGET_NOT_IN_POOL") {
        ; Сохраняем привязанную к CPed серию: после четырёх свежих отказов UDF
        ; сам обновит модуль и оба пула. Полный runtime reset здесь мешал этому
        ; порогу и создавал бесконечный цикл частичных сбросов.
        AutoTargetID_ResetCandidate()
        AZMP_ResetTargetCache("diagnostic TARGET_NOT_IN_POOL")
        if IsFunc("AZMP_ResetGtaPedPoolCache")
            AZMP_ResetGtaPedPoolCache()
        repaired := "обновлены кэши цели и GTA CPed pool; дескриптор игры не закрывался"
    } else if (attemptRepair && softResettable) {
        AutoTargetID_HardReset("diagnostic stale CPed/layout mapping: " . code)
        repaired := "полностью сброшены состояние Auto ID и кэш GTA CPed pool"
    }

    AutoTargetDiagLastRunTick := TickNow()
    snapshot := AutoTargetID_WriteDiagnostic(code, detail, knownTargetPed, repaired)
    if (showNotice) {
        shortDetail := detail
        if (StrLen(shortDetail) > 90)
            shortDetail := SubStr(shortDetail, 1, 87) . "..."
        humanError := AutoTargetID_CodeDescription(code)
        GameNotify("Auto ID: " . humanError . " [" . code . "]. " . shortDetail
            . ". Лог: logs\\autoid_diagnostics.log", recoverable ? "ERROR" : "WARN")
        AutoTargetDiagLastNoticeTick := TickNow()
    }
    return code
}

AutoTargetID_RecordFailure(code, detail := "", targetPed := 0) {
    global AutoTargetDiagFailStreak, AutoTargetDiagFirstFailTick, AutoTargetDiagLastRunTick
    global AutoTargetDiagLastNoticeTick
    AutoTargetID_SetDiagnostic(code, detail)
    meaningful := AutoTargetID_IsHardRecoveryCode(code)
    if (!meaningful) {
        AutoTargetID_ClearFailure()
        return false
    }
    if (AutoTargetDiagFailStreak = 0)
        AutoTargetDiagFirstFailTick := TickNow()
    AutoTargetDiagFailStreak += 1

    ; Диагностика запускается только при устойчивом отказе, чтобы обычное
    ; отсутствие цели под прицелом не создавало шум и не переоткрывало процесс.
    if (meaningful && AutoTargetDiagFailStreak >= 8
        && AZMP_TickElapsed(AutoTargetDiagFirstFailTick) >= 1200
        && (AutoTargetDiagLastRunTick = 0 || AZMP_TickElapsed(AutoTargetDiagLastRunTick) >= 6000))
    {
        showAutoNotice := (AutoTargetDiagLastNoticeTick = 0
            || AZMP_TickElapsed(AutoTargetDiagLastNoticeTick) >= 15000)
        AutoTargetID_DiagnoseAndRecover(showAutoNotice, 1, targetPed)
    }
    return false
}

AutoTargetID_ResetCandidate() {
    global AutoTargetCandidateID, AutoTargetCandidateReads
    global AutoTargetCandidatePed, AutoTargetCandidateMatchType
    AutoTargetCandidateID := -1
    AutoTargetCandidateReads := 0
    AutoTargetCandidatePed := 0
    AutoTargetCandidateMatchType := 0
}

AutoTargetID_ReadAimedID(ByRef targetPed := 0, ByRef angle := -1, ByRef targetName := "", ByRef isMask := 0, ByRef matchType := 0) {
    global hGTA
    targetName := ""
    isMask := 0
    matchType := 0
    angle := -1
    targetPed := GetCrosshairTargetPed(targetError, targetDetail)
    if !IsLikelyPointer(targetPed) {
        AutoTargetID_SetDiagnostic(targetError, targetDetail)
        return -1
    }

    localPed := readDWORD(hGTA, 0xB6F5F0)
    if (IsLikelyPointer(localPed) && targetPed = localPed) {
        AutoTargetID_SetDiagnostic("TARGET_IS_LOCAL_PLAYER", "targetPed совпал с локальным CPed " . localPed)
        return -1
    }

    ; m_pPlayerTargettedPed уже является выбранным игрой CPed. Дополнительный
    ; выбор по псевдоуглу камера->локальный игрок был неточным и удалён.
    playerMatch := getPlayerDataByPed(targetPed, aimedId, targetName, 0)
    if (playerMatch = 1 && aimedId >= 0) {
        ; The pool scan may take longer on a populated server. A live target
        ; check after it must agree, even when the exact mapping was found.
        finalTarget := GetCrosshairTargetPed(finalTargetCode, finalTargetDetail)
        if (finalTarget != targetPed) {
            AutoTargetID_SetDiagnostic("TARGET_CHANGED_DURING_SCAN", "цель изменилась после точного поиска CPed")
            return -1
        }
        matchType := 1
        if AZMP_IsMaskDisplayName(targetName)
            targetName := ""
        AutoTargetID_SetDiagnostic("TARGET_OK", "ID " . aimedId . ", ped=" . Format("0x{:08X}", targetPed))
        return aimedId
    }

    ; Полный обход player pool неатомарен. Если за это время прицел перешёл
    ; на другой CPed, ошибка предыдущей цели не должна попадать в recovery.
    targetAfterScan := GetCrosshairTargetPed(postScanCode, postScanDetail)
    if (targetAfterScan != targetPed) {
        changedDetail := "target changed during player-pool scan "
            . Format("0x{:08X}", targetPed) . " -> "
            . (targetAfterScan ? Format("0x{:08X}", targetAfterScan) : "none")
        if (postScanCode != "")
            changedDetail .= "; " . postScanCode . ": " . postScanDetail
        if IsFunc("AZMP_TargetDiagSetContext")
            AZMP_TargetDiagSetContext(targetAfterScan, 0)
        if IsFunc("AZMP_TargetDiagSet")
            AZMP_TargetDiagSet("TARGET_CHANGED_DURING_SCAN", changedDetail)
        AutoTargetID_SetDiagnostic("TARGET_CHANGED_DURING_SCAN", changedDetail)
        return -1
    }

    lowCode := IsFunc("AZMP_TargetDiagGetCode") ? AZMP_TargetDiagGetCode() : "NO_EXACT_ID"
    lowDetail := IsFunc("AZMP_TargetDiagGetDetail") ? AZMP_TargetDiagGetDetail() : ""

    ; ID по направлению прицела больше не угадывается. При ошибке структуры
    ; безопаснее вернуть диагностику, чем назначить чужой ник.
    ; TARGET_NOT_IN_POOL сохраняется отдельным transient-кодом: NPC и короткий
    ; stream-in/out не должны переоткрывать весь дескриптор игры.

    maskResult := getMaskDataByPed(targetPed, maskNumber, linkedPlayerId, 1.15, 3.0)
    if (maskResult > 0) {
        matchType := (linkedPlayerId >= 0) ? 3 : 4
        if (linkedPlayerId >= 0) {
            linkedInfo := AZMP_GetPlayerInfo(linkedPlayerId, 0, 0)
            if (!IsLikelyPointer(linkedInfo) || !AZMP_PlayerInfoMatchesPed(linkedInfo, targetPed, maskLayout)) {
                AutoTargetID_SetDiagnostic("MASK_LINK_PED_MISMATCH", "маска привязана к ID " . linkedPlayerId . ", но CPed не совпал")
                return -1
            }
            targetName := getPlayerNameById(linkedPlayerId)
            if AZMP_IsMaskDisplayName(targetName)
                targetName := ""
            AutoTargetID_SetDiagnostic("TARGET_MASK_LINKED", "ID " . linkedPlayerId . ", layout " . maskLayout)
            return linkedPlayerId
        }
        if (maskNumber != "") {
            isMask := 1
            targetName := ""
            AutoTargetID_SetDiagnostic("TARGET_MASK_ONLY", "маска " . maskNumber)
            return maskNumber
        }
    }

    AutoTargetID_SetDiagnostic(lowCode, lowDetail)
    return -1
}

AutoTargetID_RequestConfirmation(aimedValue, targetPed := 0, angle := -1, source := "RMB", targetName := "", isMask := 0) {
    if (aimedValue = -1 || aimedValue = "")
        return false
    if ContextAssistant_ConfirmHotkeysActive()
        return false

    requestValue := isMask ? ("__MASK__:" . aimedValue) : aimedValue
    if !ContextAssistant_Request("EnterID", requestValue, "", targetName)
        return false

    angleText := (angle >= 0) ? " | угол " . Round(angle, 1) . "°" : ""
    valueText := isMask ? ("Маска " . aimedValue) : ("ID " . aimedValue)
    nameText := (!isMask && targetName != "") ? (" | ник " . targetName) : ""
    LogError("AutoTargetID", source . ": " . valueText . nameText . ", ped " . targetPed . angleText, "INFO")
    return true
}

AutoTargetID_ObserveCandidate(aimedValue, targetName, targetPed, matchType) {
    global AutoTargetCandidateID, AutoTargetCandidateReads
    global AutoTargetCandidatePed, AutoTargetCandidateMatchType
    candidateKey := aimedValue . "|" . targetName . "|" . targetPed . "|" . matchType
    if (candidateKey = AutoTargetCandidateID)
        AutoTargetCandidateReads += 1
    else {
        AutoTargetCandidateID := candidateKey
        AutoTargetCandidateReads := 1
        AutoTargetCandidatePed := targetPed
        AutoTargetCandidateMatchType := matchType
    }
    return AutoTargetCandidateReads
}

AutoTargetID_RequiredReads(matchType, isMask) {
    return (!isMask && matchType = 1) ? 1 : 3
}

AutoTargetID_CaptureNow(showFailure := 1) {
    if IsObject(IDCaptureState)
        return false
    global AutoTargetIDEnabled, AutoTargetDiagCode, AutoTargetDiagDetail, MockMode
    captureEpoch := AutomationEpoch
    if (MockMode = "On" || !GameLocator_IsActive())
        return false
    if (AutoTargetIDEnabled != "On") {
        if (showFailure)
            GameNotify("Автозахват ID отключён в профиле.", "WARN")
        return false
    }
    if !AzmpAllowsTargetRead() {
        if (showFailure)
            GameNotify("Захват ID недоступен: " . MemoryGetShortError(), "ERROR")
        return false
    }
    aimedValue := AutoTargetID_ReadAimedID(targetPed, angle, targetName, isMask, matchType)
    if (aimedValue = -1 || aimedValue = "") {
        AutoTargetID_RecordFailure(AutoTargetDiagCode, AutoTargetDiagDetail, targetPed)
        if (showFailure)
            AutoTargetID_DiagnoseAndRecover(1, 1, targetPed)
        return false
    }
    AutoTargetID_ClearFailure()
    if (captureEpoch != AutomationEpoch || !GameLocator_IsActive())
        return false
    return AutoTargetID_RequestConfirmation(aimedValue, targetPed, angle, "Ручной захват", targetName, isMask)
}

AutoTargetID_BeginAim() {
    global AutoTargetIDEnabled, MockMode, AutoTargetLastScanTick
    global AutoTargetAimStartedTick, AutoTargetRButtonLatched
    if (AutoTargetIDEnabled != "On" || MockMode = "On" || !GameLocator_IsActive())
        return false
    if IsObject(IDCaptureState) {
        AutoTargetRButtonLatched := 1
        return false
    }
    if ContextAssistant_ConfirmHotkeysActive()
        return false
    AutoTargetRButtonLatched := 0
    AutoTargetLastScanTick := 0
    AutoTargetAimStartedTick := TickNow()
    AutoTargetID_ResetCandidate()
    ; Let GTA process the new RMB before reading its target on the next frame.
    SetTimer, AutoTargetIDTick, 20
    return true
}

AutoTargetID_EndAim() {
    global AutoTargetLastScanTick, AutoTargetAimStartedTick, AutoTargetRButtonLatched
    SetTimer, AutoTargetIDTick, Off
    AutoTargetLastScanTick := 0
    AutoTargetAimStartedTick := 0
    AutoTargetRButtonLatched := 0
    AutoTargetID_ResetCandidate()
    AutoTargetID_ClearFailure()
}

AutoTargetID_Poll() {
    global AutoTargetIDEnabled, MockMode, AutoTargetCandidateID, AutoTargetCandidateReads
    global AutoTargetCandidatePed, AutoTargetCandidateMatchType
    global AutoTargetRButtonLatched, AutoTargetStableReads, AutoTargetLastScanTick
    global AutoTargetAimStartedTick
    global UserID, ActiveID, AutoTargetDiagCode, AutoTargetDiagDetail

    if IsObject(IDCaptureState) {
        AutoTargetRButtonLatched := 1
        AutoTargetID_ResetCandidate()
        return
    }
    if (!GetKeyState("RButton", "P")) {
        AutoTargetID_EndAim()
        return
    }
    if (AutoTargetIDEnabled != "On" || MockMode = "On" || AutoTargetRButtonLatched) {
        SetTimer, AutoTargetIDTick, Off
        return
    }
    if (PhysicalInputBusy || (AutoTargetAimStartedTick && AZMP_TickElapsed(AutoTargetAimStartedTick) < 20))
        return
    if ContextAssistant_ConfirmHotkeysActive()
        return
    if !GameLocator_IsActive() {
        SetTimer, AutoTargetIDTick, Off
        AutoTargetID_ResetCandidate()
        return
    }
    captureEpoch := AutomationEpoch
    capturePID := dwGTAPID
    captureGeneration := g_HandleGeneration

    chatState := isInChat()
    if (chatState != 0) {
        AutoTargetID_ResetCandidate()
        return
    }

    if (AutoTargetLastScanTick != 0 && AZMP_TickElapsed(AutoTargetLastScanTick) < 20)
        return
    AutoTargetLastScanTick := TickNow()
    if !AzmpAllowsTargetRead() {
        AutoTargetID_ResetCandidate()
        return
    }
    capturePID := dwGTAPID
    captureGeneration := g_HandleGeneration

    aimedValue := AutoTargetID_ReadAimedID(targetPed, angle, targetName, isMask, matchType)
    if (aimedValue = -1 || aimedValue = "") {
        AutoTargetID_RecordFailure(AutoTargetDiagCode, AutoTargetDiagDetail, targetPed)
        AutoTargetID_ResetCandidate()
        return
    }
    AutoTargetID_ClearFailure()

    ; PED включён в ключ стабильности: один и тот же ID от другой сущности
    ; не может продолжить счётчик предыдущей цели.
    AutoTargetID_ObserveCandidate(aimedValue, targetName, targetPed, matchType)

    ; Exact ID/PED mapping is accepted on the first scan; masks and indirect
    ; matches retain three observations. Every path still verifies again below.
    requiredReads := AutoTargetID_RequiredReads(matchType, isMask)
    if (AutoTargetCandidateReads < requiredReads)
        return

    ; Финальная проверка сразу перед показом подтверждения.
    verifyValue := AutoTargetID_ReadAimedID(verifyPed, verifyAngle, verifyName, verifyIsMask, verifyMatch)
    if (verifyValue != aimedValue || verifyPed != targetPed || verifyIsMask != isMask || verifyMatch != matchType) {
        AutoTargetID_ResetCandidate()
        return
    }
    targetName := verifyName
    angle := verifyAngle
    if (captureEpoch != AutomationEpoch || capturePID != dwGTAPID
        || captureGeneration != g_HandleGeneration || !GameLocator_IsActive()
        || !GetKeyState("RButton", "P") || PhysicalInputBusy || IsObject(IDCaptureState)) {
        AutoTargetID_ResetCandidate()
        return
    }

    if (ActiveID) {
        if (!isMask && HasCurrentID() && (UserID + 0 = aimedValue + 0)) {
            AutoTargetRButtonLatched := 1
            AutoTargetID_ResetCandidate()
            return
        }
        if (isMask && ("M" . UserID = "M" . aimedValue)) {
            AutoTargetRButtonLatched := 1
            AutoTargetID_ResetCandidate()
            return
        }
    }

    if AutoTargetID_RequestConfirmation(aimedValue, targetPed, angle, "Автозахват ПКМ", targetName, isMask)
        AutoTargetRButtonLatched := 1
    AutoTargetID_ResetCandidate()
}

SafeWarn(msg) {
    global SafeTooltipWarnings
    Notify("warn")
    if (SafeTooltipWarnings = "On")
    {
        ToolTip, %msg%
        SetTimer, RemoveToolTip, -1600
    }
    return false
}

Evidence_IsAllowedEvent(eventCode) {
    static allowed := {"FINE":1, "ARREST":1, "SEARCH_PERSON":1, "SEARCH_TRUNK":1
        , "DOC_LICENSE":1, "DOC_TECHPASSPORT":1, "EVAC_START":1, "EVAC_END":1
        , "REPORT":1
        , "SOS_START":1, "SOS_ARRIVE":1, "CIVIL_START":1, "CIVIL_ARRIVE":1
        , "CALL_START":1, "CALL_ARRIVE":1, "CALL_WORK_START":1, "CALL_WORK_END":1
        , "PATROL_START":1, "PATROL_CONTINUE":1
        , "PATROL_END":1, "POST_START":1, "POST_CONTINUE":1, "POST_END":1}
    return allowed.HasKey(eventCode)
}

Evidence_EventLabel(eventCode) {
    static labels := {"FINE":"Штраф", "ARREST":"Арест", "SEARCH_PERSON":"Личный досмотр"
        , "SEARCH_TRUNK":"Досмотр багажника", "DOC_LICENSE":"Получена лицензия"
        , "DOC_TECHPASSPORT":"Получен техпаспорт", "EVAC_START":"Начало эвакуации"
        , "EVAC_END":"Завершение эвакуации", "REPORT":"Доклад", "SOS_START":"Доклад SOS: выехал"
        , "SOS_ARRIVE":"Доклад SOS: прибыл", "CIVIL_START":"Гражданский вызов: принят"
        , "CIVIL_ARRIVE":"Гражданский вызов: прибыл", "CALL_START":"ДТП: вызов принят"
        , "CALL_ARRIVE":"ДТП: экипаж прибыл", "CALL_WORK_START":"ДТП: оформление начато"
        , "CALL_WORK_END":"ДТП: оформление завершено", "PATROL_START":"Доклад патруля: начало"
        , "PATROL_CONTINUE":"Доклад патруля: продолжение", "PATROL_END":"Доклад патруля: конец"
        , "POST_START":"Доклад поста: начало", "POST_CONTINUE":"Доклад поста: продолжение"
        , "POST_END":"Доклад поста: конец"}
    return labels.HasKey(eventCode) ? labels[eventCode] : eventCode
}

Evidence_Arm(eventCode, timeoutMs := 45000) {
    global EvidenceScreenshotMode, EvidencePendingEvents
    if (EvidenceScreenshotMode != "On" || !Evidence_IsAllowedEvent(eventCode))
        return false
    if !IsObject(EvidencePendingEvents)
        EvidencePendingEvents := {}
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 3000)
        timeoutMs := 3000
    else if (timeoutMs > 180000)
        timeoutMs := 180000
    EvidencePendingEvents[eventCode] := TickNow() + timeoutMs
    LogError("Evidence", "Ожидание подтверждения в чате: " . Evidence_EventLabel(eventCode), "INFO")
    return true
}

Evidence_PurgeExpiredPending() {
    global EvidencePendingEvents
    if !IsObject(EvidencePendingEvents)
        EvidencePendingEvents := {}
    expired := []
    for eventCode, expiresAt in EvidencePendingEvents
        if (expiresAt <= TickNow())
            expired.Push(eventCode)
    Loop % expired.Length()
        EvidencePendingEvents.Delete(expired[A_Index])
}

Evidence_IsPending(eventCode) {
    global EvidencePendingEvents
    Evidence_PurgeExpiredPending()
    return IsObject(EvidencePendingEvents) && EvidencePendingEvents.HasKey(eventCode)
}

Evidence_ConsumePending(eventCode) {
    global EvidencePendingEvents
    Evidence_PurgeExpiredPending()
    if (!IsObject(EvidencePendingEvents) || !EvidencePendingEvents.HasKey(eventCode))
        return false
    EvidencePendingEvents.Delete(eventCode)
    return true
}

Evidence_ClearDocumentContext(clearPending := false) {
    global EvidenceDocumentContext, EvidencePendingEvents
    EvidenceDocumentContext := {}
    if (clearPending && IsObject(EvidencePendingEvents)) {
        EvidencePendingEvents.Delete("DOC_LICENSE")
        EvidencePendingEvents.Delete("DOC_TECHPASSPORT")
    }
}

Evidence_ArmDocumentsForPlayer(playerId, timeoutMs := 90000) {
    global EvidenceScreenshotMode, EvidenceDocumentContext
    if (EvidenceScreenshotMode != "On")
        return false
    if !RegExMatch(playerId . "", "^\d{1,4}$")
        return false

    playerId += 0
    playerName := getPlayerNameById(playerId)
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 3000)
        timeoutMs := 3000
    else if (timeoutMs > 180000)
        timeoutMs := 180000

    Evidence_ClearDocumentContext(true)
    EvidenceDocumentContext := {ID: playerId, Name: playerName, Expires: TickNow() + timeoutMs}
    Evidence_Arm("DOC_LICENSE", timeoutMs)
    Evidence_Arm("DOC_TECHPASSPORT", timeoutMs)
    LogError("Evidence", "Ожидаются документы после досмотра ID " . playerId
        . ((playerName != "") ? " (" . playerName . ")" : ""), "INFO")
    return true
}

Evidence_GetDistanceToPlayerID(playerId, ByRef distance) {
    distance := -1
    if !RegExMatch(playerId . "", "^\d{1,4}$")
        return false
    selfCoords := getPlayerCoordinates()
    if !IsObject(selfCoords)
        return false
    pedPtr := getPlayerPedById(playerId + 0)
    if !IsLikelyPointer(pedPtr)
        return false
    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(targetCoords)
        return false
    dx := targetCoords[1] - selfCoords[1]
    dy := targetCoords[2] - selfCoords[2]
    dz := targetCoords[3] - selfCoords[3]
    distance := Sqrt(dx * dx + dy * dy + dz * dz)
    return true
}

Evidence_FindPlayerIDByName(playerName) {
    targetName := Evidence_NormalizeNickname(playerName)
    if (targetName = "")
        return -1
    Loop, 1004
    {
        playerId := A_Index - 1
        currentName := getPlayerNameById(playerId)
        if (currentName = "")
            continue
        if (Evidence_NormalizeNickname(currentName) = targetName)
            return playerId
    }
    return -1
}

Evidence_DocumentContextValid() {
    global EvidenceDocumentContext
    if !IsObject(EvidenceDocumentContext) || !EvidenceDocumentContext.HasKey("ID")
        return false
    if (!EvidenceDocumentContext.HasKey("Expires") || EvidenceDocumentContext.Expires <= TickNow()) {
        Evidence_ClearDocumentContext(true)
        return false
    }
    return true
}

Evidence_DocumentSenderMatches(line) {
    global EvidenceDocumentContext
    if !Evidence_DocumentContextValid()
        return false

    targetId := EvidenceDocumentContext.ID + 0
    targetName := EvidenceDocumentContext.HasKey("Name") ? EvidenceDocumentContext.Name : ""
    liveName := getPlayerNameById(targetId)
    if (liveName != "")
        targetName := liveName

    parsedId := ChatLogReader_ExtractID(line, targetName)
    if (parsedId >= 0)
        return (parsedId + 0 = targetId)

    senderName := ChatLogReader_ExtractNickname(line)
    if (senderName = "")
        return false

    senderLower := senderName
    targetLower := targetName
    StringLower, senderLower, senderLower
    StringLower, targetLower, targetLower
    if (targetLower != "" && senderLower = targetLower)
        return true

    resolvedId := Evidence_FindPlayerIDByName(senderName)
    return (resolvedId >= 0 && resolvedId = targetId)
}

Evidence_DocumentSenderIsNear() {
    global EvidenceDocumentContext, EvidenceDocumentDistanceLimit
    if !Evidence_DocumentContextValid()
        return false

    limit := EvidenceDocumentDistanceLimit
    NormalizeNumberRange(limit, 20, 2, 100)
    distance := -1
    if !Evidence_GetDistanceToPlayerID(EvidenceDocumentContext.ID, distance) {
        LogError("Evidence", "Документ отклонён: расстояние до владельца документов не определено.", "WARN")
        return false
    }
    if (distance > limit) {
        LogError("Evidence", "Документ отклонён: ID " . EvidenceDocumentContext.ID . " находится в "
            . Round(distance, 1) . " м, лимит " . limit . " м.", "WARN")
        return false
    }
    LogError("Evidence", "Документ от ID " . EvidenceDocumentContext.ID . ": расстояние "
        . Round(distance, 2) . " м.", "INFO")
    return true
}

Evidence_MaybeClearDocumentContext() {
    if (!Evidence_IsPending("DOC_LICENSE") && !Evidence_IsPending("DOC_TECHPASSPORT"))
        Evidence_ClearDocumentContext(false)
}

Evidence_NormalizeChatLine(line) {
    text := Trim(line, " `t`r`n")
    text := RegExReplace(text, "i)(?:\{|\[)[0-9A-F]{6,8}(?:\}|\])")
    text := RegExReplace(text, "^\s*\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*")
    text := StrReplace(text, "ё", "е")
    text := StrReplace(text, "Ё", "Е")
    text := RegExReplace(text, "\s+", " ")
    StringLower, text, text
    return Trim(text)
}

Evidence_NormalizeNickname(nickname) {
    nickname := Evidence_NormalizeChatLine(nickname)
    nickname := StrReplace(nickname, "\", "")
    nickname := RegExReplace(nickname, "[^a-zа-я0-9]")
    return nickname
}

Evidence_LineContainsNickname(line, nickname) {
    wanted := Evidence_NormalizeNickname(nickname)
    if (wanted = "")
        return false
    return InStr(Evidence_NormalizeNickname(line), wanted) > 0
}

Evidence_ExtractOtherNickname(line, ownNickname) {
    ownNormalized := Evidence_NormalizeNickname(ownNickname)
    searchPos := 1
    pattern := "i)([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})"
    while (searchPos := RegExMatch(line, pattern, match, searchPos))
    {
        candidate := match1
        if (Evidence_NormalizeNickname(candidate) != ownNormalized)
            return candidate
        searchPos += StrLen(match)
    }
    return ""
}

Evidence_BeginDocumentWindow() {
    global EvidenceScreenshotMode, EvidenceDocumentActivationMode, EvidenceDocumentWaitSec
    global EvidenceDocumentWindowExpires, EvidenceDocumentDistanceLimit, ChatLogPlayerNickname
    if (EvidenceScreenshotMode != "On" || EvidenceDocumentActivationMode != "После представления")
        return false
    if (Evidence_NormalizeNickname(ChatLogPlayerNickname) = "") {
        GameNotify("Автоскрин документов не включён: укажите свой Nick_Name в настройках «Автоскриншоты».", "WARN")
        return false
    }
    NormalizeNumberRange(EvidenceDocumentWaitSec, 90, 5, 300)
    Evidence_ClearDocumentContext(true)
    EvidenceDocumentWindowExpires := TickNow() + EvidenceDocumentWaitSec * 1000
    GameNotify("Ожидание документов: " . EvidenceDocumentWaitSec . " сек., радиус "
        . EvidenceDocumentDistanceLimit . " ед.", "INFO")
    return true
}

Evidence_DocumentActivationAllowed() {
    global EvidenceScreenshotMode, EvidenceDocumentActivationMode, EvidenceDocumentWindowExpires
    global ChatLogPlayerNickname
    if (EvidenceScreenshotMode != "On" || Evidence_NormalizeNickname(ChatLogPlayerNickname) = "")
        return false
    if (EvidenceDocumentActivationMode = "Только радиус")
        return true
    if (EvidenceDocumentActivationMode != "После представления")
        return false
    return (EvidenceDocumentWindowExpires > TickNow())
}

Evidence_IsOwnReportLine(text) {
    global Surname, PatrolUnit, PostUnit, ChatLogPlayerNickname
    normalized := Evidence_NormalizeChatLine(text)
    if (normalized = "")
        return false

    ownNickname := Evidence_NormalizeNickname(ChatLogPlayerNickname)
    if (ownNickname != "" && Evidence_LineContainsNickname(normalized, ownNickname))
        return true

    surnameText := Evidence_NormalizeChatLine(Surname)
    patrolText := Evidence_NormalizeChatLine(PatrolUnit)
    postText := Evidence_NormalizeChatLine(PostUnit)
    if (surnameText != "" && InStr(normalized, surnameText))
        return true
    if (patrolText != "" && InStr(normalized, patrolText))
        return true
    if (postText != "" && InStr(normalized, postText))
        return true
    return InStr(normalized, "вы ") || InStr(normalized, "вам ")
}

Evidence_IsOwnActionLine(text) {
    global ChatLogPlayerNickname
    ownName := Evidence_NormalizeNickname(ChatLogPlayerNickname)
    if (ownName = "")
        return false
    normalized := Evidence_NormalizeChatLine(text)
    if (Evidence_LineContainsNickname(normalized, ownName) || InStr(normalized, "вы ") || InStr(normalized, "вам "))
        return true
    return false
}

Evidence_DetectChatEvent(line) {
    text := Evidence_NormalizeChatLine(line)
    if (text = "")
        return ""

    documentEvent := Evidence_DetectReceivedDocument(line)
    if (documentEvent != "")
        return documentEvent

    ; Pending state already ties these confirmations to an action started by this script.
    ; Do not require the server line to contain our nickname: many server messages are impersonal.
    if (Evidence_IsPending("FINE")
        && RegExMatch(text, "i)(выписал[аи]?|выписан[ао]?|оштрафовал[аи]?|оштрафован[ао]?|назначил[аи]?\s+штраф|штраф\s+(?:успешно\s+)?(?:выписан|назначен|выдан|оформлен))"))
        return "FINE"

    if (Evidence_IsPending("ARREST")
        && RegExMatch(text, "i)(арестовал[аи]?|арестован[аоы]?|поместил[аи]?.*(?:кпз|камер|тюрьм)|посадил[аи]?.*(?:кпз|камер|тюрьм)|отправил[аи]?.*(?:кпз|тюрьм)|заключил[аи]?.*под\s+страж|доставлен[ао]?.*(?:кпз|камер)|заключен[ао]?\s+под\s+страж)"))
        return "ARREST"

    if (Evidence_IsPending("SEARCH_TRUNK")
        && (RegExMatch(text, "i)(обыскал[аи]?|обыскива|досмотрел[аи]?|досматрива|пров(?:е|ё)л[аи]?|проверил[аи]?|проверя|произв(?:е|ё)л[аи]?|осмотрел[аи]?|осматрива).*(багажник|автомобил|транспортн\w*\s+средств|тс)")
        || RegExMatch(text, "i)(багажник|автомобил|транспортн\w*\s+средств|тс).*(досмотрен|обыскан|осмотрен|проверен)")))
        return "SEARCH_TRUNK"

    if (Evidence_IsPending("SEARCH_PERSON")
        && (RegExMatch(text, "i)(обыскал[аи]?|обыскива|досмотрел[аи]?|досматрива|пров(?:е|ё)л[аи]?|проверил[аи]?|произв(?:е|ё)л[аи]?|выполнил[аи]?).*(обыск|личн\w*\s+досмотр|граждан|игрок)")
        || RegExMatch(text, "i)(личн\w*\s+досмотр|обыск).*(проведен|проведён|выполнен|завершен|завершён|начат)")))
        return "SEARCH_PERSON"

    reportEvent := Evidence_ClassifyReportText(text)
    if (reportEvent != "" && Evidence_IsPending(reportEvent) && Evidence_IsOwnReportLine(line))
        return reportEvent

    return ""
}

Evidence_RequestScreenshot(eventCode, delayMs := 700) {
    global EvidenceScreenshotMode, EvidenceScreenshotQueue, EvidenceScreenshotMethod
    if (EvidenceScreenshotMode != "On" || !Evidence_IsAllowedEvent(eventCode))
        return false
    if !IsObject(EvidenceScreenshotQueue)
        EvidenceScreenshotQueue := []
    delayMs := Round(delayMs)
    if (delayMs < 100)
        delayMs := 100
    else if (delayMs > 10000)
        delayMs := 10000

    dueTick := TickNow() + delayMs
    expiresTick := dueTick + 20000
    ; The same chat line can be observed by both the direct-send and chatlog paths.
    ; Merge only near-identical requests, without suppressing later real events.
    for index, queuedItem in EvidenceScreenshotQueue
    {
        if (queuedItem.Code = eventCode && Abs(queuedItem.Due - dueTick) <= 800) {
            if (dueTick < queuedItem.Due)
                queuedItem.Due := dueTick
            if (!queuedItem.HasKey("Expires") || queuedItem.Expires < expiresTick)
                queuedItem.Expires := expiresTick
            SetTimer, EvidenceScreenshotTimer, 100
            return true
        }
    }

    EvidenceScreenshotQueue.Push({Code:eventCode, Due:dueTick, Expires:expiresTick
        , Attempts:0, InactiveLogged:0})
    SetTimer, EvidenceScreenshotTimer, 100
    LogError("Evidence", "Запланирован снимок (" . EvidenceScreenshotMethod . "): "
        . Evidence_EventLabel(eventCode), "INFO")
    return true
}

Evidence_ClassifyReportText(text) {
    global Surname, PatrolUnit, PostUnit
    normalized := Evidence_NormalizeChatLine(ApplyActionTemplate(text))
    hasRadioPrefix := RegExMatch(normalized, "^/(?:r|radio)\s+")
    if (hasRadioPrefix)
        normalized := RegExReplace(normalized, "^/(?:r|radio)\s+")

    if RegExMatch(normalized, "^докладывает\s+[^:]{1,100}:\s*(.+)$", report)
        action := report1
    else {
        ; Organization presets often omit the word "докладывает".
        if !hasRadioPrefix
            return ""
        surnameText := Evidence_NormalizeChatLine(Surname)
        patrolText := Evidence_NormalizeChatLine(PatrolUnit)
        postText := Evidence_NormalizeChatLine(PostUnit)
        presetPrefix := InStr(normalized, "экипаж ") = 1
            || InStr(normalized, "оперативная группа ") = 1
            || InStr(normalized, "специальная группа ") = 1
            || InStr(normalized, "военный патруль ") = 1
            || InStr(normalized, "караул ") = 1
        ownIdentity := (surnameText != "" && InStr(normalized, surnameText))
            || (patrolText != "" && InStr(normalized, patrolText))
            || (postText != "" && InStr(normalized, postText))
        if (!presetPrefix && !ownIdentity)
            return ""
        action := normalized
    }

    isSos := InStr(action, "sos") || (InStr(action, "срочн") && InStr(action, "помощ"))
        || (InStr(action, "сигнал") && InStr(action, "помощ"))
    if (isSos) {
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "SOS_ARRIVE"
        if RegExMatch(action, "(реагир|принял|приняла|приняли|выехал|выехала|выехали|выдвиг|выдвин|направил|направила|направили)")
            return "SOS_START"
    }

    if (InStr(action, "вызов") && InStr(action, "гражданск")) {
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "CIVIL_ARRIVE"
        if RegExMatch(action, "(принял|приняла|приняли|реагир|выехал|выехала|выехали|выдвиг|выдвин|направил|направила|направили)")
            return "CIVIL_START"
    }

    ; Some built-in organization presets describe work without repeating ДТП/происшествие.
    if (RegExMatch(action, "(приступил|приступила|приступили|начал|начала|начали).*(оперативн[а-яё]*\s+мероприят|выполнен[а-яё]*\s+задач|обеспечен[а-яё]*\s+поряд)"))
        return "CALL_WORK_START"
    if (RegExMatch(action, "(оперативн[а-яё]*\s+мероприят|выполнен[а-яё]*\s+задач).*(завершил|завершила|завершили|завершен|завершена)")
        || RegExMatch(action, "задач[а-яё]*.*(выполнил|выполнила|выполнили)"))
        return "CALL_WORK_END"

    if (InStr(action, "дтп") || InStr(action, "происшеств") || InStr(action, "авари")) {
        if RegExMatch(action, "(завершил|завершила|завершили|закончил|закончила|закончили|выполнил|выполнила|выполнили).*(оформлен|работ|мероприят|задач|поряд)")
            || RegExMatch(action, "(оформлен|работ|мероприят|задач).*(завершен|завершена|завершили|выполнен|выполнена)")
            return "CALL_WORK_END"
        if RegExMatch(action, "(приступил|приступила|приступили|начал|начала|начали).*(оформлен|работ|мероприят|задач|поряд)")
            return "CALL_WORK_START"
        if RegExMatch(action, "(прибыл|прибыла|прибыли|на месте)")
            return "CALL_ARRIVE"
        if RegExMatch(action, "(принял|приняла|приняли|реагир|сообщен|сообщён)")
            return "CALL_START"
    }

    if (RegExMatch(action, "(начал|начала|начали|приступил|приступила|приступили).*(эваку|погруз)")
        || RegExMatch(action, "(эвакуац|погруз).*(начат|началась|начата)"))
        return "EVAC_START"
    if (RegExMatch(action, "(эвакуировал|эвакуировала|эвакуировали|завершил|завершила|завершили|доставил|доставила|доставили).*(тс|автомобил|транспорт|эвакуац|штраф|стоянк)")
        || RegExMatch(action, "(тс|автомобил|транспорт|эвакуац).*(эвакуирован|завершен|завершена|доставлен|перемещен)"))
        return "EVAC_END"

    isPatrol := InStr(action, "патрул") || (InStr(action, "маршрут") && InStr(action, "служб"))
    if (isPatrol) {
        if RegExMatch(action, "(завершил|завершила|завершили|окончил|окончила|окончили|закончил|закончила|закончили|покида)")
            return "PATROL_END"
        if RegExMatch(action, "(патрулиру|продолжа|обстановка|без происшеств|несение службы)")
            return "PATROL_CONTINUE"
        if RegExMatch(action, "(заступил|заступила|заступили|начал|начала|начали|приступил|приступила|приступили|выехал|выехала|выехали)")
            return "PATROL_START"
    }

    isPost := InStr(action, "пост") || InStr(action, "караул")
        || (InStr(action, "объект") && RegExMatch(action, "(заступ|приступ|продолжа|работ|служб|заверш)"))
    if (isPost) {
        if RegExMatch(action, "(покинул|покинула|покинули|покида|завершил|завершила|завершили|снялся|снялась|снялись|закончил|закончила|закончили)")
            return "POST_END"
        if RegExMatch(action, "(продолжа|стоим|стоять|обстановка|без происшеств|несение службы|работа на объекте|работу на объекте)")
            return "POST_CONTINUE"
        if RegExMatch(action, "(заступил|заступила|заступили|начал|начала|начали|прибыл|прибыла|прибыли|приступил|приступила|приступили)")
            return "POST_START"
    }
    return ""
}

Evidence_IsReportText(text) {
    normalized := Evidence_NormalizeChatLine(ApplyActionTemplate(text))
    return RegExMatch(normalized, "^/(?:r|radio)\s+\S") > 0
        || InStr(normalized, "докладывает") > 0
}

Evidence_MaybeCaptureReportText(text) {
    if !Evidence_IsReportText(text)
        return false
    eventCode := Evidence_ClassifyReportText(text)
    if (eventCode != "") {
        Evidence_Arm(eventCode, 120000)
        ; Direct fallback removes dependence on chatlog timing/path. A chatlog request
        ; for the same event is merged by Evidence_RequestScreenshot.
        return Evidence_RequestScreenshot(eventCode, 650)
    }
    ; Unknown user-defined radio reports cannot be confirmed by phrase classification.
    ; Capture them directly after the line has had time to appear in chat.
    return Evidence_RequestScreenshot("REPORT", 500)
}

Evidence_RunRecognitionMatrix() {
    cases := []
    cases.Push({Text:"/r докладывает Лукашенко: реагирую на вызов срочной помощи.", Event:"SOS_START"})
    cases.Push({Text:"{33CCFF}[12:04:07] /R ДОКЛАДЫВАЕТ Лукашенко: прибыл на вызов срочной помощи!!!", Event:"SOS_ARRIVE"})
    cases.Push({Text:"/r докладывает Лукашенко: принял вызов гражданскго.", Event:"CIVIL_START"})
    cases.Push({Text:"/r  докладывает  Лукашенко:  прибыл на вызов гражданского.", Event:"CIVIL_ARRIVE"})
    cases.Push({Text:"/r докладывает экипаж Р101: принял вызов о ДТП.", Event:"CALL_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: прибыли на вызов о ДТП.", Event:"CALL_ARRIVE"})
    cases.Push({Text:"/r докладывает экипаж Р101: приступили к оформлению ДТП.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: завершили оформление ДТП.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r докладывает Лукашенко: начал эвакуировать ТС на штрафстоянку.", Event:"EVAC_START"})
    cases.Push({Text:"/r докладывает Лукашенко: эвакуировал ТС на штрафстоянку.", Event:"EVAC_END"})
    cases.Push({Text:"/r докладывает экипаж Р101: заступили на патрулирование.", Event:"PATROL_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: патрулируем по маршруту.", Event:"PATROL_CONTINUE"})
    cases.Push({Text:"/r докладывает экипаж Р101: завершили патруль.", Event:"PATROL_END"})
    cases.Push({Text:"/r докладывает экипаж Р101: заступили на пост.", Event:"POST_START"})
    cases.Push({Text:"/r докладывает экипаж Р101: продолжаем стоять на посту.", Event:"POST_CONTINUE"})
    cases.Push({Text:"/r докладывает экипаж Р101: покинули пост.", Event:"POST_END"})
    cases.Push({Text:"/r Экипаж Р101, выдвигаемся на вызов SOS.", Event:"SOS_START"})
    cases.Push({Text:"/r Экипаж Р101, прибыли на вызов SOS.", Event:"SOS_ARRIVE"})
    cases.Push({Text:"/r Оперативная группа Р101, приняла сообщение о происшествии.", Event:"CALL_START"})
    cases.Push({Text:"/r Оперативная группа Р101, прибыла на место происшествия.", Event:"CALL_ARRIVE"})
    cases.Push({Text:"/r Специальная группа Р101, приступила к выполнению задачи на месте происшествия.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r Специальная группа Р101, выполнение задачи на месте происшествия завершила.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r Военный патруль Р101, продолжает несение службы по маршруту А-1.", Event:"PATROL_CONTINUE"})
    cases.Push({Text:"/r Оперативная группа Р202, работу на объекте КПП завершила.", Event:"POST_END"})
    cases.Push({Text:"/r Оперативная группа Р101, выдвинулась на вызов SOS.", Event:"SOS_START"})
    cases.Push({Text:"/r Оперативная группа Р101, приступила к оперативным мероприятиям.", Event:"CALL_WORK_START"})
    cases.Push({Text:"/r Оперативная группа Р101, оперативные мероприятия завершила.", Event:"CALL_WORK_END"})
    cases.Push({Text:"/r Военный патруль Р101, задачу выполнил.", Event:"CALL_WORK_END"})
    cases.Push({Text:"В чате обсуждают патруль и пост.", Event:""})
    cases.Push({Text:"/r докладывает Лукашенко: гражданский находится рядом.", Event:""})
    cases.Push({Text:"/r докладывает экипаж Р101: ДТП.", Event:""})
    cases.Push({Text:"/r сотрудник начал эвакуировать ТС.", Event:""})

    failures := []
    Loop % cases.Length()
    {
        item := cases[A_Index]
        actual := Evidence_ClassifyReportText(item.Text)
        if (actual != item.Event)
            failures.Push(A_Index . ": ожидалось " . item.Event . ", получено " . actual)
    }
    return {Ok: failures.Length() = 0, Total: cases.Length()
        , Passed: cases.Length() - failures.Length(), Failures: failures}
}

Evidence_SendKeyPress(keyName, modifier := "") {
    global MockMode
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[SCREENSHOT requested] " . modifier . "+" . keyName)
        return true
    }
    if (PhysicalInputBusy || !GameLocator_IsActive())
        return false
    PhysicalInputBusy := 1
    epoch := AutomationEpoch
    modifierDown := false, keyDown := false
    try {
        if (modifier != "") {
            modifierDown := SafeSend("{" . modifier . " down}", "Input", epoch)
            if (!modifierDown)
                return false
            Sleep, 30
        }
        keyDown := SafeSend("{" . keyName . " down}", "Input", epoch)
        if (!keyDown)
            return false
        Sleep, 60
        return epoch = AutomationEpoch && GameLocator_IsActive()
    } finally {
        ; Releases never depend on focus: a held modifier must not remain stuck after Alt-Tab.
        if (keyDown)
            SendInput, {%keyName% up}
        if (modifierDown)
            SendInput, {%modifier% up}
        PhysicalInputBusy := 0
    }
}

Evidence_SendScreenshot() {
    global EvidenceScreenshotMethod
    method := EvidenceScreenshotMethod
    if (method = "PrintScreen")
        Evidence_SendKeyPress("PrintScreen")
    else if (method = "Win+PrintScreen")
        Evidence_SendKeyPress("PrintScreen", "LWin")
    else if (method = "Alt+PrintScreen")
        Evidence_SendKeyPress("PrintScreen", "LAlt")
    else if (method = "F8")
        Evidence_SendKeyPress("F8")
    else if (method = "F12")
        Evidence_SendKeyPress("F12")
    else {
        method := "Alt+F1"
        Evidence_SendKeyPress("F1", "LAlt")
    }
    return method
}

Evidence_ProcessScreenshotQueue() {
    global EvidenceScreenshotMode, EvidenceScreenshotQueue, EvidencePendingEvents, EvidenceLastCaptureTick
    if (EvidenceScreenshotMode != "On") {
        EvidenceScreenshotQueue := []
        EvidencePendingEvents := {}
        SetTimer, EvidenceScreenshotTimer, Off
        return false
    }
    if !IsObject(EvidenceScreenshotQueue) || EvidenceScreenshotQueue.Length() = 0 {
        SetTimer, EvidenceScreenshotTimer, Off
        return false
    }

    item := EvidenceScreenshotQueue[1]
    if (TickNow() < item.Due)
        return false
    if (EvidenceLastCaptureTick > 0 && TickNow() - EvidenceLastCaptureTick < 1200) {
        EvidenceScreenshotQueue[1].Due := EvidenceLastCaptureTick + 1200
        return false
    }

    if !item.HasKey("Expires")
        item.Expires := item.Due + 20000
    if !item.HasKey("Attempts")
        item.Attempts := 0
    if !item.HasKey("InactiveLogged")
        item.InactiveLogged := 0

    if !IsGameActive() {
        item.Attempts += 1
        if (TickNow() < item.Expires) {
            item.Due := TickNow() + 250
            if (!item.InactiveLogged) {
                item.InactiveLogged := 1
                LogError("Evidence", "Снимок ожидает возврата фокуса в игру: "
                    . Evidence_EventLabel(item.Code), "INFO")
            }
            return false
        }
        EvidenceScreenshotQueue.RemoveAt(1)
        LogError("Evidence", "Снимок отменён: игра не стала активной за 20 сек.: "
            . Evidence_EventLabel(item.Code), "WARN")
        if (EvidenceScreenshotQueue.Length() = 0)
            SetTimer, EvidenceScreenshotTimer, Off
        return false
    }

    EvidenceScreenshotQueue.RemoveAt(1)
    try {
        usedMethod := Evidence_SendScreenshot()
        EvidenceLastCaptureTick := TickNow()
        LogError("Evidence", "Нажат " . usedMethod . ": " . Evidence_EventLabel(item.Code), "INFO")
    } catch e {
        if (TickNow() < item.Expires) {
            item.Due := TickNow() + 400
            item.Attempts += 1
            EvidenceScreenshotQueue.InsertAt(1, item)
            LogError("Evidence", "Повтор снимка после ошибки отправки клавиши: " . e.Message, "WARN")
        } else {
            LogError("Evidence", "Снимок не выполнен: " . e.Message, "ERROR")
        }
    }

    if (EvidenceScreenshotQueue.Length() = 0)
        SetTimer, EvidenceScreenshotTimer, Off
    return true
}

Evidence_DetectReceivedDocument(line) {
    global ChatLogPlayerNickname, EvidenceDocumentContext, EvidenceDocumentWaitSec
    if !Evidence_DocumentActivationAllowed()
        return ""

    lowerLine := Evidence_NormalizeChatLine(line)
    if (lowerLine = "")
        return ""
    ownContext := Evidence_LineContainsNickname(lowerLine, ChatLogPlayerNickname)
        || RegExMatch(lowerLine, "i)(?:^|[\s,:])(вам|вы|вас|ваш|ваши|вашего|вашему)(?:[\s,:.!?]|$)")
    if !ownContext
        return ""

    documentEvent := ""
    if (RegExMatch(lowerLine, "i)тех[\s\.\-]*паспорт")
        || RegExMatch(lowerLine, "i)техническ(?:ий|ого|ому|им|ом)?\s+паспорт")
        || (InStr(lowerLine, "свидетельств") && InStr(lowerLine, "регистрац")))
        documentEvent := "DOC_TECHPASSPORT"
    else if InStr(lowerLine, "лиценз")
        documentEvent := "DOC_LICENSE"
    if (documentEvent = "")
        return ""

    actionMatch := RegExMatch(lowerLine, "i)(посмотр|просматр|провер|изуч|ознаком|предъяв|показ|получ|переда|достае|берет|берёт|открыл|открыла|демонстр|предостав)")
    if (!actionMatch && !(InStr(lowerLine, "документ") && InStr(lowerLine, "лиценз")))
        return ""

    targetName := Evidence_ExtractOtherNickname(line, ChatLogPlayerNickname)
    if (targetName = "") {
        LogError("Evidence", "Документ отклонён: в строке не найден Nick_Name проверяемого игрока.", "WARN")
        return ""
    }
    targetId := Evidence_FindPlayerIDByName(targetName)
    if (targetId < 0) {
        LogError("Evidence", "Документ отклонён: игрок " . targetName . " не найден рядом/в списке.", "WARN")
        return ""
    }

    NormalizeNumberRange(EvidenceDocumentWaitSec, 90, 5, 300)
    EvidenceDocumentContext := {ID: targetId, Name: targetName
        , Expires: TickNow() + EvidenceDocumentWaitSec * 1000}
    if !Evidence_DocumentSenderIsNear()
        return ""
    Evidence_Arm(documentEvent, 5000)
    LogError("Evidence", "Документы " . targetName . " (ID " . targetId . ") распознаны по строке chatlog.", "INFO")
    return documentEvent
}

CanRunAction(actionName, needsID := false, checkChatClosed := true, requireVehicle := false, requireChatOpen := false, requireCloseRange := false) {
    if (IsObject(IDCaptureState) || PhysicalInputBusy)
        return false
    global ActionCooldownMs, LastActionTick
    global SafeModeEnabled, SafeBlockWhenChat, SafeVehicleChecks, SafeRequireChatForEditable
    global SafeDistanceChecks, SafeDistanceLimit

    if !EnsureGameActive()
        return false

    if (needsID && !CheckID())
        return false

    masterSafe := (SafeModeEnabled = "On")
    requireOpenCheck := requireChatOpen && (masterSafe || SafeRequireChatForEditable = "On")
    requireClosedCheck := checkChatClosed && (masterSafe || SafeBlockWhenChat = "On")
    if (requireOpenCheck || requireClosedCheck)
    {
        chatState := isInChat()
        if (requireOpenCheck && chatState != 1)
            return SafeWarn("Открой чат перед действием: " . actionName)
        if (requireClosedCheck && chatState = 1)
            return SafeWarn("Закрой чат перед действием: " . actionName)
    }

    if (requireVehicle && (masterSafe || SafeVehicleChecks = "On") && isPlayerInAnyVehicle() <= 0)
        return SafeWarn("Действие требует транспорт: " . actionName)

    shouldCheckDistance := requireCloseRange || (needsID && SafeDistanceChecks = "On")
    if (shouldCheckDistance && (masterSafe || SafeDistanceChecks = "On"))
    {
        NormalizeNumberRange(SafeDistanceLimit, 12, 2, 50)
        distSource := ""
        dist := GetCrosshairTargetDistance(distSource)
        if (dist < 0)
            return SafeWarn("Не удалось определить расстояние до цели: " . actionName)
        if (dist > SafeDistanceLimit)
            return SafeWarn("Цель слишком далеко: " . Round(dist, 1) . " м, лимит " . SafeDistanceLimit . " м")
        LogError("DistanceCheck", actionName . ": " . Round(dist, 2) . " м | " . distSource, "INFO")
    }

    NormalizeNumberRange(ActionCooldownMs, 250, 0, 5000)
    if (ActionCooldownMs > 0)
    {
        elapsed := TickNow() - LastActionTick
        if (LastActionTick > 0 && elapsed < ActionCooldownMs)
            return false
    }

    LastActionTick := TickNow()
    return true
}

CheckID() {
    global IDCheckEnabled
    if (!IDCheckEnabled)
        return true
    if HasCurrentID()
        return true
    if (GetKeyState("RButton", "P") && AutoTargetID_CaptureNow(0))
        return HasCurrentID()
    Notify("warn")
    GameNotify("ID не задан. Зажми ПКМ, наведи на игрока или используй !цель.", "WARN")
    return false
}

CanRunCuffFollowup() {
    global SafeModeEnabled, SafeBlockWhenChat
    if !EnsureGameActive()
        return false
    if !CheckID()
        return false
    if ((SafeModeEnabled = "On" || SafeBlockWhenChat = "On") && isInChat() = 1)
        return SafeWarn("Закрой чат перед действием: cuff follow-up")
    return true
}

DoCuffFollowup(inputEpoch := 0) {
    global UserID
    inputEpoch := AutomationEpoch
    if (SendChatForEpoch(inputEpoch, "/frac " . UserID) != 1)
        return
    Sleep, 250
    if (SendChatForEpoch(inputEpoch, "/fracid " . UserID) != 1)
        return
    Sleep, 250
    SafeSend("{1}", "Input", inputEpoch)
    Sleep, 80
    SafeSend("{1}", "Input", inputEpoch)
    Sleep, 120
    SafeSend("{4}", "Input", inputEpoch)
    Sleep, 80
    SafeSend("{4}", "Input", inputEpoch)
}

CanRunDejectFollowup() {
    global SafeModeEnabled, SafeBlockWhenChat
    if !EnsureGameActive()
        return false
    if !CheckID()
        return false
    if ((SafeModeEnabled = "On" || SafeBlockWhenChat = "On") && isInChat() = 1)
        return SafeWarn("Закрой чат перед RP eject")
    return true
}

SendDejectRPAfterCommand() {
    global RP_Deject
    SplitConfigSequenceMiddle(RP_Deject, rpBefore, rpAfter)
    if (rpBefore != "")
        SendConfigSequence(rpBefore, 700)
    if (rpAfter != "")
        SendConfigSequence(rpAfter, 700)
    if (rpBefore = "" && rpAfter = "" && RP_Deject != "")
        SendConfigSequence(RP_Deject, 700)
}

ContextAssistant_IsEnabled(actionName) {
    global AssistOOPEnabled, AssistStunEnabled, AssistChaseEnabled
    global AssistHouseEnabled, AssistDrugsEnabled, AssistPDPCuffEnabled

    if (actionName = "OOPSearch")
        return AssistOOPEnabled = "On"
    if (actionName = "Stun")
        return AssistStunEnabled = "On"
    if (actionName = "Chase")
        return AssistChaseEnabled = "On"
    if (actionName = "HouseAlarm")
        return AssistHouseEnabled = "On"
    if (actionName = "DrugsNearby")
        return AssistDrugsEnabled = "On"
    if (actionName = "PDPCuff")
        return AssistPDPCuffEnabled = "On"
    return true
}

ContextAssistant_GetMeta(actionName, ByRef title, ByRef prompt, ByRef confirmText, ByRef maxValue) {
    title := "Контекстный помощник"
    prompt := "Введите ID цели."
    confirmText := "Продолжить"
    maxValue := 999999

    if (actionName = "EnterID")
    {
        title := "ID цели"
        prompt := "Введите ID подозреваемого. Он появится в HUD и будет использоваться другими действиями."
        confirmText := "Сохранить ID"
    }
    else if (actionName = "OOPSearch")
    {
        title := "Пробив ООП"
        prompt := "Введите ID. После подтверждения будет отправлен запрос местоположения /find."
        confirmText := "Запросить"
    }
    else if (actionName = "Stun")
    {
        title := "Оглушение"
        prompt := "Введите ID, затем выберите средство: тазер или дубинка."
        confirmText := "Тазер"
    }
    else if (actionName = "Chase")
    {
        title := "Преследование"
        prompt := "Введите ID. Для обычного и расширенного ID команда будет выбрана автоматически."
        confirmText := "Начать погоню"
    }
    else if (actionName = "HouseAlarm")
    {
        title := "Сигнализация дома"
        prompt := "Введите номер дома. После подтверждения дом будет предложено отметить в GPS."
        confirmText := "Отметить дом"
        maxValue := 10000
    }
    else if (actionName = "DrugsNearby")
    {
        title := "Наркотики рядом"
        prompt := "Введите ID замеченного игрока. ID будет сохранён как текущая цель без отправки команды."
        confirmText := "Сохранить ID"
    }
    else if (actionName = "PDPCuff")
    {
        title := "Наручники после ПДП"
        prompt := "Введите ID спасённого подозреваемого. Наручники надеваются только после подтверждения."
        confirmText := "Надеть наручники"
    }
    else if (actionName = "TrainCrash")
    {
        title := "Крушение поезда"
        prompt := "Выберите место: 1 — пгт. Батырево, 2 — г. Лыткарино, 3 — завод г. Арзамас."
        confirmText := "Отправить доклад"
        maxValue := 3
    }
}

ContextAssistant_ValidateNumber(value, maxValue, ByRef normalizedValue, minValue := 0) {
    normalizedValue := Trim(value)
    if !RegExMatch(normalizedValue, "^\d+$")
        return false
    normalizedValue += 0
    if (normalizedValue < minValue || normalizedValue > maxValue)
        return false
    normalizedValue := "" . normalizedValue
    return true
}

ContextAssistant_ShowStatus(statusText) {
    global ContextAssistantStatus, hContextAssistantWnd
    ContextAssistantStatus := statusText
    if (hContextAssistantWnd)
        GuiControl, 42:, ContextAssistantStatus, %statusText%
}

ContextAssistant_Close(clearState := 1) {
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName
    global ContextAssistantStatus, ContextAssistantMode, hContextAssistantWnd
    SetTimer, ContextAssistantTimeoutLabel, Off
    Gui, 42:Destroy
    hContextAssistantWnd := 0
    if (clearState)
    {
        ContextAssistantAction := ""
        ContextAssistantInput := ""
        ContextAssistantVariant := ""
        ContextAssistantTargetName := ""
        ContextAssistantStatus := ""
        ContextAssistantMode := ""
    }
}

ContextAssistant_ConfirmHotkeysActive() {
    global ContextAssistantMode
    return (ContextAssistantMode = "confirm")
}

ContextAssistant_IDHotkeyContext() {
    if !ContextAssistant_ConfirmHotkeysActive()
        return false
    if !IsGameActive()
        return false
    return (isInChat() != 1)
}

ContextAssistant_GetOverlayPosition(width, height, ByRef outX, ByRef outY) {
    activeHwnd := WinExist("A")
    if (activeHwnd)
    {
        WinGetPos, winX, winY, winW, winH, ahk_id %activeHwnd%
        if (winW >= width && winH >= height)
        {
            outX := winX + Floor((winW - width) / 2)
            outY := winY + 72
            return true
        }
    }
    outX := Floor((A_ScreenWidth - width) / 2)
    outY := 72
    return true
}

ContextAssistant_MakeWindowPassive(hwnd) {
    if (!hwnd)
        return false

    exStyle := DllCall("GetWindowLong", "UInt", hwnd, "Int", -20, "UInt")
    DllCall("SetWindowLong", "UInt", hwnd, "Int", -20, "UInt", exStyle | 0x08000020)
    return true
}

ContextAssistant_ShowConfirmationOverlay(title, prompt, statusText) {
    global hContextAssistantWnd, UIRoundness

    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    overlayW := 310
    overlayH := 54
    ContextAssistant_GetOverlayPosition(overlayW, overlayH, overlayX, overlayY)

    Gui, 42:Destroy
    Gui, 42:+HwndhContextAssistantWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000020
    Gui, 42:Color, %panel%
    Gui, 42:Margin, 0, 0
    Gui, 42:Add, Progress, -Theme x0 y0 w4 h%overlayH% Disabled Vertical Background%panel% c%accent%, 100
    Gui, 42:Font, s8 Bold c%textColor%, Segoe UI
    Gui, 42:Add, Text, x14 y6 w286 h20 0x200 BackgroundTrans, %prompt%
    Gui, 42:Font, Norm s8 c%muted%, Segoe UI
    Gui, 42:Add, Text, x14 y29 w286 h17 vContextAssistantStatus BackgroundTrans, %statusText%
    Capture_BeforeShow("42")
    Gui, 42:Show, x%overlayX% y%overlayY% w%overlayW% h%overlayH% NoActivate, AHK FOR GOS BY SBEZRUK Notification
    ContextAssistant_MakeWindowPassive(hContextAssistantWnd)
    ApplyRoundedCorners(hContextAssistantWnd, (UIRoundness > 12) ? 12 : UIRoundness)
    return hContextAssistantWnd ? true : false
}

ContextAssistant_GetConfirmationPrompt(actionName, value, variant := "", targetName := "") {
    isMaskValue := RegExMatch(value . "", "^__MASK__:([0-9]{5,20})$", maskMatch)
    if (isMaskValue)
        targetText := "Маска " . maskMatch1
    else
        targetText := "ID " . value

    targetName := Trim(targetName)
    if (!isMaskValue && targetName != "" && targetName != "Маска")
        targetText .= " (" . targetName . ")"

    if (actionName = "HouseAlarm")
        return "Дом №" . value . " - отметить в GPS?"
    if (actionName = "OOPSearch")
        return targetText . " - отправить /find?"
    if (actionName = "Stun")
        return targetText . " - " . ((variant = "baton") ? "дубинка" : "тазер") . "?"
    if (actionName = "Chase")
        return targetText . " - начать погоню?"
    if (actionName = "DrugsNearby")
        return targetText . " - сохранить целью?"
    if (actionName = "PDPCuff")
        return targetText . " - надеть наручники?"
    return targetText . " - подставить?"
}

ContextAssistant_CloseGameChat(inputEpoch := 0) {
    global MockMode
    inputEpoch := AutomationEpoch
    if (MockMode = "On")
        return
    if (isInChat() != 1)
        return
    SafeSend("^a{Backspace}", "Input", inputEpoch)
    Sleep, 40
    SafeSend("{F6}", "Input", inputEpoch)
    Sleep, 80
}

ContextAssistant_Request(actionName, presetValue := "", presetVariant := "", targetName := "", inputEpoch := 0) {
    if (IsObject(IDCaptureState) || PhysicalInputBusy)
        return false
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName
    global ContextAssistantStatus, ContextAssistantMode, hContextAssistantWnd, UserID, MockMode, UIRoundness, TargetIsMask
    global ContextNotificationMode, ContextNotificationTimeoutSec, Bind_ConfirmID, Bind_RejectID
    inputEpoch := AutomationEpoch

    if !ContextAssistant_IsEnabled(actionName)
    {
        SafeWarn("Сценарий отключён в профиле: " . actionName)
        return false
    }

    if !EnsureGameActive()
    {
        ToolTip, Игра не активна. Для проверки без GTA включи MockMode в настройках чата.
        SetTimer, RemoveToolTip, -2600
        return false
    }

    title := "", prompt := "", confirmText := "", maxValue := 0
    ContextAssistant_GetMeta(actionName, title, prompt, confirmText, maxValue)
    usedCurrentTarget := false
    if (presetValue = "" && actionName != "HouseAlarm" && actionName != "TrainCrash") {
        presetValue := UserID
        usedCurrentTarget := true
    }
    if (usedCurrentTarget && TargetIsMask && RegExMatch(presetValue . "", "^[0-9]{5,20}$"))
        presetValue := "__MASK__:" . presetValue
    hasPresetValue := (presetValue != "")

    ContextAssistant_Close()
    ContextAssistantAction := actionName
    ContextAssistantInput := presetValue
    ContextAssistantVariant := presetVariant
    ContextAssistantTargetName := targetName

    if (hasPresetValue)
    {
        ContextAssistantMode := "confirm"
        prompt := ContextAssistant_GetConfirmationPrompt(actionName, presetValue, presetVariant, targetName)
        acceptKey := IsBindFieldFilled(Bind_ConfirmID) ? Bind_ConfirmID : "не задан"
        rejectKey := IsBindFieldFilled(Bind_RejectID) ? Bind_RejectID : "не задан"
        ContextAssistantStatus := acceptKey . " - Да    " . rejectKey . " - Нет"
        if (ContextNotificationMode != "Чат")
            ContextNotificationMode := "Плашка"
        NormalizeNumberRange(ContextNotificationTimeoutSec, 8, 2, 30)

        if (ContextNotificationMode = "Чат")
        {
            hContextAssistantWnd := 0
            GameNotify(prompt . "  [" . ContextAssistantStatus . "]", "INFO")
        }
        else if !ContextAssistant_ShowConfirmationOverlay(title, prompt, ContextAssistantStatus)
        {
            ContextAssistant_Close()
            return false
        }

        timeoutMs := -Abs(ContextNotificationTimeoutSec * 1000)
        SetTimer, ContextAssistantTimeoutLabel, %timeoutMs%
        return true
    }

    ContextAssistant_CloseGameChat()
    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    controlBg := "F7F8FA"
    inputText := "111418"

    Gui, 42:+HwndhContextAssistantWnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox -Resize
    Gui, 42:Color, %bg%, %controlBg%
    Gui, 42:Margin, 18, 14
    Gui, 42:Font, s14 Bold c%textColor%, Segoe UI
    Gui, 42:Add, Text, x18 y14 w524 h28 BackgroundTrans, %title%

    ContextAssistantMode := "input"
    ContextAssistantStatus := "Enter - подтвердить, Esc - отменить."
    Gui, 42:Font, Norm s9 c%muted%, Segoe UI
    Gui, 42:Add, Text, x18 y50 w524 h42 BackgroundTrans, %prompt%
    Gui, 42:Font, Norm s10 c%inputText%, Segoe UI
    Gui, 42:Add, Edit, x18 y104 w524 h32 Number Limit6 vContextAssistantInput, %presetValue%
    Gui, 42:Font, Norm s9 c%muted%, Segoe UI
    Gui, 42:Add, Text, x18 y142 w524 h22 vContextAssistantStatus BackgroundTrans, %ContextAssistantStatus%
    Gui, 42:Font, Norm s10 c%textColor%, Segoe UI
    if (actionName = "Stun")
    {
        Gui, 42:Add, Button, x18 y178 w164 h34 Default gContextAssistantTaserLabel, Тазер
        Gui, 42:Add, Button, x190 y178 w164 h34 gContextAssistantBatonLabel, Дубинка
        Gui, 42:Add, Button, x378 y178 w164 h34 gContextAssistantCancelLabel, Отмена
    }
    else
    {
        Gui, 42:Add, Button, x190 y178 w164 h34 Default gContextAssistantConfirmLabel, %confirmText%
        Gui, 42:Add, Button, x378 y178 w164 h34 gContextAssistantCancelLabel, Отмена
    }
    Capture_BeforeShow("42")
    Gui, 42:Show, w560 h230, AHK FOR GOS BY SBEZRUK - %title%
    ApplyRoundedCorners(hContextAssistantWnd, UIRoundness)
    GuiControl, 42:Focus, ContextAssistantInput
    SafeSend("^a", "Input", inputEpoch)
    SetTimer, ContextAssistantTimeoutLabel, -30000
    return true
}

ContextAssistant_RestoreGame() {
    global MockMode
    if (MockMode = "On")
        return true
    return GameLocator_Activate(0.7)
}

ContextAssistant_ExpandCommand(templateText, idValue) {
    commandText := StrReplace(templateText, "{ID}", idValue)
    commandText := StrReplace(commandText, "%ID%", idValue)
    return Trim(commandText)
}

ContextAssistant_BuildCommand(actionName, idValue, variant := "") {
    global AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    if (actionName = "OOPSearch")
        return ContextAssistant_ExpandCommand(AssistOOPCommand, idValue)
    if (actionName = "Stun")
        return ContextAssistant_ExpandCommand((variant = "baton") ? AssistBatonCommand : AssistTaserCommand, idValue)
    if (actionName = "Chase")
        return "/chase " . idValue
    if (actionName = "PDPCuff")
        return "/cuff " . idValue
    return ""
}

BuildTrainCrashReport(choice) {
    if (choice = 1)
        place := "в пгт. Батырево"
    else if (choice = 2)
        place := "в г. Лыткарино"
    else if (choice = 3)
        place := "на заводе г. Арзамас"
    else
        return ""
    return ApplyTemplate("/r Докладывает: {REPORT_RANK} {SURNAME}. Крушение поезда произошло " . place . ".")
}

SuElapsedNotify(payload := "") {
    global UserID
    targetId := (payload != "") ? payload : UserID
    GameNotify("Прошло 20 секунд после корректировки розыска ID " . targetId . ".", "INFO")
    return true
}

ContextAssistant_Execute(actionName, rawValue, variant := "", targetName := "") {
    global MockMode

    rawValue := Trim(rawValue)
    isMaskValue := RegExMatch(rawValue, "^__MASK__:([0-9]{5,20})$", maskMatch)
    if (isMaskValue) {
        value := maskMatch1
        targetName := ""
    } else {
        maxValue := (actionName = "HouseAlarm") ? 10000 : ((actionName = "TrainCrash") ? 3 : 999999)
        minValue := (actionName = "HouseAlarm" || actionName = "TrainCrash") ? 1 : 0
        if !ContextAssistant_ValidateNumber(rawValue, maxValue, value, minValue)
            return false
    }

    if (actionName = "EnterID" && isMaskValue)
    {
        ShowIDGui(value, "", 1)
        GameNotify("Выбрана цель: маска " . value . ".", "INFO")
        Notify("info")
        return true
    }

    if (actionName = "HouseAlarm")
    {
        if (MockMode = "On")
        {
            MockPreview_Append("[GPS] Отметить дом №" . value . " по сигнализации")
            LogError("ContextAssistant.HouseAlarm", "Mock GPS house: " . value, "INFO")
            return true
        }
        if !ContextAssistant_RestoreGame()
            return SafeWarn("Не удалось вернуть фокус в игру для GPS.")
        return RunGpsDialogAction("Сигнализация дома", 15, value)
    }

    if (actionName = "TrainCrash")
    {
        commandText := BuildTrainCrashReport(value)
        if (commandText = "")
            return false
        if !ContextAssistant_RestoreGame()
            return SafeWarn("Не удалось вернуть фокус в игру.")
        return ChatQueue_Enqueue(commandText, "TrainCrash")
    }

    ShowIDGui(value, targetName, isMaskValue ? 1 : 0)
    if (actionName = "EnterID" || actionName = "DrugsNearby")
    {
        if (actionName = "DrugsNearby")
        {
            LogError("ContextAssistant.DrugsNearby", "Saved nearby drug-use ID: " . value, "INFO")
            if (MockMode = "On")
                MockPreview_Append("[ID] Наркотики рядом — сохранён ID " . value)
            ToolTip, % "Сохранён ID " . value . " (наркотики рядом)."
            SetTimer, RemoveToolTip, -1800
        }
        if (actionName = "EnterID")
        {
            selectedText := "ID " . value
            if (targetName != "" && targetName != "Маска")
                selectedText .= " (" . targetName . ")"
            GameNotify("Выбрана цель: " . selectedText . ".", "INFO")
        }
        Notify("info")
        return true
    }

    commandText := ContextAssistant_BuildCommand(actionName, value, variant)
    if (commandText = "")
        return false

    if !ContextAssistant_RestoreGame()
        return SafeWarn("Не удалось вернуть фокус в игру.")

    requireCloseRange := (MockMode != "On" && (actionName = "Stun" || actionName = "PDPCuff"))
    if !CanRunAction(actionName, false, true, false, false, requireCloseRange)
        return false

    queued := ChatQueue_Enqueue(commandText, "ContextAssistant." . actionName)
    if (queued)
    {
        LogError("ContextAssistant", actionName . " prepared for ID " . value, "INFO")
        Notify("info")
    }
    return queued
}

ContextAssistant_Submit(variant := "") {
    global ContextAssistantAction, ContextAssistantInput, ContextAssistantVariant, ContextAssistantTargetName, ContextAssistantMode

    actionName := ContextAssistantAction
    rawValue := ContextAssistantInput
    targetName := ContextAssistantTargetName
    if (ContextAssistantMode = "confirm")
    {
        selectedVariant := (variant != "") ? variant : ContextAssistantVariant
        ContextAssistant_Close()
        return ContextAssistant_Execute(actionName, rawValue, selectedVariant, targetName)
    }

    Gui, 42:Submit, NoHide
    rawValue := ContextAssistantInput
    maxValue := (actionName = "HouseAlarm") ? 10000 : ((actionName = "TrainCrash") ? 3 : 999999)
    minValue := (actionName = "HouseAlarm" || actionName = "TrainCrash") ? 1 : 0
    if !ContextAssistant_ValidateNumber(rawValue, maxValue, normalizedValue, minValue)
    {
        ContextAssistant_ShowStatus("Введите целое число от " . minValue . " до " . maxValue . ".")
        Notify("warn")
        GuiControl, 42:Focus, ContextAssistantInput
        return false
    }

    ContextAssistant_Close()
    return ContextAssistant_Execute(actionName, normalizedValue, variant, targetName)
}

ResolveChatLogPath() {
    global ChatLogPath
    configured := Trim(ChatLogPath)
    if (SubStr(configured, 1, 1) = """" && SubStr(configured, 0) = """")
        configured := SubStr(configured, 2, StrLen(configured) - 2)
    if (configured != "")
        return configured

    candidates := []
    candidates.Push("C:\Amazing Games\Amazing Online\PC\amazing\chatlog.txt")
    candidates.Push(A_MyDocuments . "\GTA San Andreas User Files\SAMP\chatlog.txt")
    Loop % candidates.Length()
    {
        candidate := candidates[A_Index]
        if FileExist(candidate)
            return candidate
    }
    return configured
}

ChatLogReader_MaybeCleanup(path, fileSize := -1) {
    global ChatLogAutoCleanupEnabled
    ChatLogAutoCleanupEnabled := "Off"
    return false
}

InitChatLogReader() {
    global ChatLogLastPos, ChatLogFileSeen, ChatLogPendingIdResultLine
    global ChatLogLookupAction, ChatLogLookupVariant, ChatLogLookupName, ChatLogLookupStartedTick
    ChatLogReaderIdentity := ""
    ChatLogLastPos := 0
    ChatLogFileSeen := false
    ChatLogPendingIdResultLine := 0
    ChatLogLookupAction := ""
    ChatLogLookupVariant := ""
    ChatLogLookupName := ""
    ChatLogLookupStartedTick := 0

    path := ResolveChatLogPath()
    if (path = "" || !FileExist(path))
        return false
    file := FileOpen(path, "r", "CP1251")
    if !IsObject(file)
        return false
    file.Seek(0, 2)
    ChatLogLastPos := file.Pos
    file.Close()
    ChatLogFileSeen := true
    LogError("ChatLogReader", "Watching " . path . " from byte " . ChatLogLastPos, "INFO")
    return true
}

ChatLogReader_CanTrigger(actionKey, cooldownMs := 5000) {
    global ChatLogActionCooldowns
    if !IsObject(ChatLogActionCooldowns)
        ChatLogActionCooldowns := {}
    lastTick := ChatLogActionCooldowns.HasKey(actionKey) ? ChatLogActionCooldowns[actionKey] : 0
    if (lastTick > 0 && TickNow() - lastTick < cooldownMs)
        return false
    ChatLogActionCooldowns[actionKey] := TickNow()
    return true
}

ChatLogReader_ExtractID(line, lookupName := "") {
    if (lookupName != "") {
        if RegExMatch(line, "i)\Q" . lookupName . "\E\s*(?:\[|\(\s*ID\s*[:#]?\s*)(\d{1,6})", match)
            return match1 + 0
        if RegExMatch(line, "i)(?:\[|\bID\s*[:#]?\s*)(\d{1,6})\]?\s*[-:|]*\s*\Q" . lookupName . "\E", match)
            return match1 + 0
        spacedName := StrReplace(lookupName, "_", " ")
        if (spacedName != lookupName) {
            if RegExMatch(line, "i)\Q" . spacedName . "\E\s*(?:\[|\(\s*ID\s*[:#]?\s*)(\d{1,6})", match)
                return match1 + 0
            if RegExMatch(line, "i)(?:\[|\bID\s*[:#]?\s*)(\d{1,6})\]?\s*[-:|]*\s*\Q" . spacedName . "\E", match)
                return match1 + 0
        }
    }
    if RegExMatch(line, "i)\[(\d{1,6})\]", match)
        return match1 + 0
    if RegExMatch(line, "i)\bID\s*[:#]?\s*(\d{1,6})", match)
        return match1 + 0
    if (lookupName != "" && ChatLogReader_LineContainsName(line, lookupName)
        && RegExMatch(line, "i)(?:^|\s)(\d{1,6})(?:\s|$)", match))
        return match1 + 0
    return -1
}

ChatLogReader_ExtractChaseTargetID(line) {
    ids := []
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)\[(\d{1,6})\]", match)
        if (!found)
            break
        ids.Push(match1 + 0)
        offset += found + StrLen(match) - 1
    }

    ; В сообщении о начале преследования первый ID принадлежит инициатору,
    ; второй — игроку, которого начали преследовать.
    if (ids.Length() >= 2)
        return ids[2]
    if (ids.Length() = 1)
        return ids[1]

    ; Резерв для серверных форматов без квадратных скобок.
    ids := []
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)\bID\s*[:#]?\s*(\d{1,6})", match)
        if (!found)
            break
        ids.Push(match1 + 0)
        offset += found + StrLen(match) - 1
    }
    if (ids.Length() >= 2)
        return ids[2]
    if (ids.Length() = 1)
        return ids[1]
    return -1
}

ChatLogReader_ExtractNicknameByID(line, playerId) {
    if (playerId < 0)
        return ""
    namePattern := "([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})"
    if RegExMatch(line, "i)" . namePattern . "\s*\[\s*" . playerId . "\s*\]", match)
        return match1
    if RegExMatch(line, "i)\[\s*" . playerId . "\s*\]\s*" . namePattern, match)
        return match1
    return ""
}

ChatLogReader_ExtractNickname(line) {
    global ChatLogPlayerNickname
    ownName := ChatLogPlayerNickname
    StringLower, ownLower, ownName
    offset := 1
    while (offset <= StrLen(line))
    {
        found := RegExMatch(SubStr(line, offset), "i)([A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23}_[A-ZА-ЯЁ0-9][A-ZА-ЯЁa-zа-яё0-9]{1,23})", match)
        if (!found)
            break
        candidate := match1
        StringLower, candidateLower, candidate
        if (candidateLower != ownLower)
            return candidate
        offset += found + StrLen(match) - 1
    }
    return ""
}

ChatLogReader_ClearLookup() {
    global ChatLogPendingIdResultLine, ChatLogLookupAction, ChatLogLookupVariant
    global ChatLogLookupName, ChatLogLookupStartedTick
    ChatLogPendingIdResultLine := 0
    ChatLogLookupAction := ""
    ChatLogLookupVariant := ""
    ChatLogLookupName := ""
    ChatLogLookupStartedTick := 0
}

ChatLogReader_ApplyDetectedID(playerId, playerName := "", source := "") {
    if (playerId < 0)
        return false
    LogError("ChatLogReader", "Detected ID " . playerId . ((playerName != "") ? (" (" . playerName . ")") : "")
        . ((source != "") ? (" from " . source) : "") . "; command execution suppressed", "INFO")
    ; Чат-триггеры только подставляют ID как текущую цель.
    ; Они никогда не запускают /chase, /cuff, тазер, обыск и другие команды.
    return ContextAssistant_Execute("EnterID", playerId, "", playerName)
}

ChatLogReader_CompleteLookup(playerId) {
    global ChatLogLookupAction, ChatLogLookupName
    actionName := ChatLogLookupAction
    playerName := ChatLogLookupName
    ChatLogReader_ClearLookup()
    if (playerId < 0)
        return false
    return ChatLogReader_ApplyDetectedID(playerId, playerName, actionName . "/lookup")
}

ChatLogReader_BeginLookup(actionName, playerName, variant := "") {
    global ChatLogLookupAction, ChatLogLookupVariant, ChatLogLookupName
    global ChatLogLookupStartedTick, ChatLogPendingIdResultLine
    playerName := Trim(playerName)
    if (playerName = "")
        return false
    if (ChatLogLookupAction != "" && TickNow() - ChatLogLookupStartedTick < 12000) {
        LogError("ChatLogReader", "Lookup skipped while another request is active: " . playerName, "WARN")
        return false
    }
    ChatLogLookupAction := actionName
    ChatLogLookupVariant := variant
    ChatLogLookupName := playerName
    ChatLogLookupStartedTick := TickNow()
    ChatLogPendingIdResultLine := 0
    return ChatQueue_Enqueue("/id " . playerName, "ChatLogReader.Lookup", 0, 900, 1)
}

ChatLogReader_HandleTargetEvent(actionName, line, variant := "") {
    if !ContextAssistant_IsEnabled(actionName)
        return false
    if (actionName = "Chase")
        playerId := ChatLogReader_ExtractChaseTargetID(line)
    else
        playerId := ChatLogReader_ExtractID(line)
    if (playerId >= 0) {
        playerName := ChatLogReader_ExtractNicknameByID(line, playerId)
        return ChatLogReader_ApplyDetectedID(playerId, playerName, actionName)
    }
    playerName := ChatLogReader_ExtractNickname(line)
    if (playerName != "")
        return ChatLogReader_BeginLookup(actionName, playerName, variant)
    LogError("ChatLogReader", "Target not parsed for " . actionName . ": " . line, "WARN")
    return false
}

ChatLogReader_LineContainsName(line, playerName) {
    playerName := Trim(playerName)
    if (playerName = "")
        return false
    StringLower, lineLower, line
    StringLower, nameLower, playerName
    if InStr(lineLower, nameLower)
        return true
    spacedName := StrReplace(nameLower, "_", " ")
    return (spacedName != nameLower && InStr(lineLower, spacedName)) ? true : false
}

ChatLogReader_HandleLookupLine(line) {
    global ChatLogLookupAction, ChatLogLookupName, ChatLogLookupStartedTick, ChatLogPendingIdResultLine
    if (ChatLogLookupAction = "")
        return false
    if (AZMP_TickElapsed(ChatLogLookupStartedTick) > 12000) {
        LogError("ChatLogReader", "Lookup timeout for " . ChatLogLookupName, "WARN")
        ChatLogReader_ClearLookup()
        return false
    }

    if InStr(line, "Игроки онлайн:") {
        ChatLogPendingIdResultLine := 3
        return true
    }

    ; Никогда не принимаем произвольный ID из следующих строк. В загруженном
    ; варианте через две строки брался первый попавшийся [ID], из-за чего
    ; активная цель могла получать данные другого игрока.
    if ChatLogReader_LineContainsName(line, ChatLogLookupName) {
        playerId := ChatLogReader_ExtractID(line, ChatLogLookupName)
        if (playerId >= 0)
            return ChatLogReader_CompleteLookup(playerId)
    }

    if (ChatLogPendingIdResultLine > 0) {
        ChatLogPendingIdResultLine -= 1
        if (ChatLogPendingIdResultLine = 0)
            LogError("ChatLogReader", "Lookup response did not contain requested name: " . ChatLogLookupName, "WARN")
    }
    return false
}

ChatLogReader_ProcessLine(line) {
    global ChatLogPlayerNickname, ChatLogRescuePending
    line := Trim(line, " `t`r`n")
    if (line = "")
        return false
    if ChatLogReader_HandleLookupLine(line)
        return true

    StringLower, lowerLine, line
    ownName := ChatLogPlayerNickname
    StringLower, ownLower, ownName
    ownEvent := (ownLower != "" && InStr(lowerLine, ownLower)) || InStr(lowerLine, "вы ")

    evidenceEvent := Evidence_DetectChatEvent(line)
    if (evidenceEvent != "" && ChatLogReader_CanTrigger("Evidence:" . evidenceEvent, 3000)) {
        captureDelay := (evidenceEvent = "DOC_LICENSE" || evidenceEvent = "DOC_TECHPASSPORT"
            || evidenceEvent = "EVAC_START" || evidenceEvent = "EVAC_END"
            || evidenceEvent = "SOS_START" || evidenceEvent = "SOS_ARRIVE"
            || evidenceEvent = "CIVIL_START" || evidenceEvent = "CIVIL_ARRIVE"
            || evidenceEvent = "CALL_START" || evidenceEvent = "CALL_ARRIVE"
            || evidenceEvent = "CALL_WORK_START" || evidenceEvent = "CALL_WORK_END"
            || evidenceEvent = "PATROL_START" || evidenceEvent = "PATROL_CONTINUE"
            || evidenceEvent = "PATROL_END" || evidenceEvent = "POST_START"
            || evidenceEvent = "POST_CONTINUE" || evidenceEvent = "POST_END") ? 150 : 350
        isDocumentEvent := (SubStr(evidenceEvent, 1, 4) = "DOC_")
        if (isDocumentEvent) {
            if Evidence_ConsumePending(evidenceEvent)
                Evidence_RequestScreenshot(evidenceEvent, captureDelay)
            Evidence_MaybeClearDocumentContext()
        } else if Evidence_ConsumePending(evidenceEvent)
            Evidence_RequestScreenshot(evidenceEvent, captureDelay)
    }

    if RegExMatch(line, "i)Сработала сигнализация дома\s*(?:№|#)?\s*(\d{1,6})", houseMatch) {
        if ChatLogReader_CanTrigger("HouseAlarm:" . houseMatch1, 8000)
            return ContextAssistant_Request("HouseAlarm", houseMatch1)
        return false
    }

    if (InStr(lowerLine, "вы спасли") && IsObject(ChatLogRescuePending)) {
        ; Завершение спасения больше не запускает /cuff. ID уже был подставлен
        ; при первом сообщении, либо будет найден по нику ниже.
        rescue := ChatLogRescuePending
        ChatLogRescuePending := 0
        if (rescue.HasKey("ID") && rescue.ID >= 0)
            return ChatLogReader_ApplyDetectedID(rescue.ID, rescue.HasKey("Name") ? rescue.Name : "", "RescueComplete")
        if (rescue.HasKey("Name") && rescue.Name != "")
            return ChatLogReader_BeginLookup("RescueComplete", rescue.Name)
        return false
    }

    if (InStr(lowerLine, "спасать игрока") && InStr(lowerLine, "вы начал")) {
        rescueId := ChatLogReader_ExtractID(line)
        rescueName := ChatLogReader_ExtractNickname(line)
        ChatLogRescuePending := {ID: rescueId, Name: rescueName, StartedTick: TickNow()}
        if (rescueId >= 0)
            return ChatLogReader_ApplyDetectedID(rescueId, rescueName, "RescueStart")
        if (rescueName != "")
            return ChatLogReader_BeginLookup("RescueStart", rescueName)
        return true
    }

    if InStr(lowerLine, "вы оглушили") {
        variant := InStr(lowerLine, "дубин") ? "baton" : "taser"
        if ChatLogReader_CanTrigger("Stun", 5000)
            return ChatLogReader_HandleTargetEvent("Stun", line, variant)
        return false
    }

    if ((InStr(lowerLine, "употребил") || InStr(lowerLine, "употребила")) && (InStr(lowerLine, "мятн") || InStr(lowerLine, "зелен") || InStr(lowerLine, "зелён"))) {
        if ChatLogReader_CanTrigger("DrugsNearby", 7000)
            return ChatLogReader_HandleTargetEvent("DrugsNearby", line)
        return false
    }

    if (ownEvent && InStr(lowerLine, "местополож")) {
        if ChatLogReader_CanTrigger("OOPSearch", 5000)
            return ChatLogReader_HandleTargetEvent("OOPSearch", line)
        return false
    }

    if (ownEvent && InStr(lowerLine, "преследован")) {
        if ChatLogReader_CanTrigger("Chase", 5000)
            return ChatLogReader_HandleTargetEvent("Chase", line)
        return false
    }
    return false
}

ChatLogReader_Tick() {
    global ChatLogReaderEnabled, MockMode, ChatLogLastPos, ChatLogFileSeen, ChatLogReaderIdentity
    if (ChatLogReaderEnabled != "On" || MockMode = "On")
        return false
    path := ResolveChatLogPath()
    file := FileOpen(path, "r", "CP1251")
    if !IsObject(file) {
        ChatLogReader_ResetGeneration()
        return false
    }
    try {
        fileIdentity := ChatLogReader_FileIdentity(file)
        identity := path . "|" . fileIdentity
        if (fileIdentity = "")
            return false
        if (!ChatLogFileSeen || identity != ChatLogReaderIdentity || file.Length < ChatLogLastPos || (ChatLogCursorSignature != "" && ChatLogReader_CursorSignature(file, ChatLogLastPos) != ChatLogCursorSignature)) {
            ChatLogReader_ResetGeneration()
            ChatLogReaderIdentity := identity
            ChatLogFileSeen := true
            ChatLogLastPos := file.Length
            ChatLogCursorSignature := ChatLogReader_CursorSignature(file, ChatLogLastPos)
            return true
        }
        remaining := file.Length - ChatLogLastPos
        if (remaining <= 0)
            return true
        file.Pos := ChatLogLastPos
        readSize := Min(65536, remaining)
        VarSetCapacity(chunk, readSize, 0)
        bytes := file.RawRead(chunk, readSize)
        if (!bytes)
            return true
        lastBreak := 0, processed := 0, lineStart := 0
        Loop % bytes {
            if (NumGet(chunk, A_Index - 1, "UChar") != 10)
                continue
            length := A_Index - 1 - lineStart
            if (ChatLogReaderDroppingLine)
                ChatLogReaderDroppingLine := 0
            else if (length <= 16384)
            {
                completeLine := RTrim(StrGet(&chunk + lineStart, length, "CP1251"), "`r")
                if (AuditTestMode && IsObject(AuditReaderLines))
                    AuditReaderLines.Push(completeLine)
                else
                    ChatLogReader_ProcessLine(completeLine)
            }
            else
                LogError("ChatLogReader", "Пропущена строка длиннее 16 КиБ.", "WARN")
            lastBreak := A_Index
            lineStart := lastBreak
            processed++
            if (processed >= 200)
                break
        }
        ; Keep the byte checkpoint before an incomplete line. No fragment is dispatched.
        if (lastBreak = 0 && bytes >= 65536) {
            ChatLogReaderDroppingLine := 1
            ChatLogLastPos += bytes
        } else {
            ChatLogLastPos += lastBreak
        }
        ChatLogCursorSignature := ChatLogReader_CursorSignature(file, ChatLogLastPos)
        return true
    } finally {
        file.Close()
    }
}

NormalizeTextTrigger(ByRef val) {
    val := Trim(val)
    if (val = "ERROR")
        val := ""
    if (val != "" && SubStr(val, 1, 1) != "!")
        val := "!" . val
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

GetDefaultBindListItems() {
    return "OpenBindsTab`nAutoPatrol`nAutoPost`nConfirmID`nRejectID`nIntro`nSOS`nEnterID`nResetID`nChase`nChaseNoID`nDeject`nCuff`nInCar`nStopChase`nDoc`nSearch`nPersonalFile`nSu`nVehicleLookup`nWantedRemoval`nCivilCallStart`nCivilCallArrive`nMaskCall`nRecordCheck`nTrainCrash`nGpsD`nGpsOS`nVU`nFP`nKON`nFZOP`nTER`nTK`nARG`nUK`nVV`nKOAP`nPDD`nORUZH`nUPK`nKAS`nFSB`nFSIN`nVS`nSUD`nORD`nGT"
}

NormalizeBindListToken(item) {
    item := Trim(item)
    if (item = "")
        return ""

    compact := RegExReplace(item, "[\s_\-]+")
    StringLower, compact, compact

    if (compact = "opensettings" or compact = "settings" or compact = "menu")
        return "OpenSettings"
    if (compact = "togglebindlist" or compact = "bindlist" or compact = "showbindlist")
        return "ToggleBindList"
    if (compact = "togglelastlawdoc" or compact = "lastlawdoc" or compact = "lastdoc" or compact = "lawlast")
        return "ToggleLastLawDoc"
    if (compact = "togglehud" or compact = "hud")
        return "ToggleHUD"
    if (compact = "intro")
        return "Intro"
    if (compact = "sos")
        return "SOS"
    if (compact = "enterid")
        return "EnterID"
    if (compact = "resetid")
        return "ResetID"
    if (compact = "confirmid" or compact = "acceptid")
        return "ConfirmID"
    if (compact = "rejectid" or compact = "declineid")
        return "RejectID"
    if (compact = "capturetargetid" or compact = "targetid")
        return ""
    if (compact = "openbindstab" or compact = "bindsettings")
        return "OpenBindsTab"
    if (compact = "chase")
        return "Chase"
    if (compact = "deject")
        return "Deject"
    if (compact = "cuff")
        return "Cuff"
    if (compact = "incar")
        return "InCar"
    if (compact = "stopchase")
        return "StopChase"
    if (compact = "doc")
        return "Doc"
    if (compact = "search")
        return "Search"
    if (compact = "maskcall")
        return "MaskCall"
    if (compact = "recordcheck")
        return "RecordCheck"
    if (compact = "traincrash")
        return "TrainCrash"
    if (compact = "personalfile")
        return "PersonalFile"
    if (compact = "su")
        return "Su"
    if (compact = "gpsd" or compact = "д")
        return "GpsD"
    if (compact = "gpsos" or compact = "ос")
        return "GpsOS"
    if (compact = "dep")
        return "Dep"
    if (compact = "sosstart")
        return "SOSStart"
    if (compact = "sosarrive")
        return "SOSArrive"
    if (compact = "hijackstart")
        return "HijackStart"
    if (compact = "hijackarrive")
        return "HijackArrive"
    if (compact = "callstart")
        return "CallStart"
    if (compact = "callarrive")
        return "CallArrive"
    if (compact = "patrolstart")
        return "PatrolStart"
    if (compact = "patrolcont" or compact = "patrolcontinue")
        return "PatrolCont"
    if (compact = "patrolend")
        return "PatrolEnd"
    if (compact = "poststart")
        return "PostStart"
    if (compact = "postcont" or compact = "postcontinue")
        return "PostCont"
    if (compact = "postend")
        return "PostEnd"
    if (compact = "convoystart")
        return "ConvoyStart"
    if (compact = "convoyend")
        return "ConvoyEnd"
    if (compact = "towstart")
        return "TowStart"
    if (compact = "towend")
        return "TowEnd"
    if (compact = "carsearch")
        return "CarSearch"
    if (compact = "arrest")
        return "Arrest"
    if (compact = "fine")
        return "Fine"
    if (compact = "protocol")
        return "Protocol"
    if (compact = "rights")
        return "Rights"
    if (compact = "cardds")
        return "CardDS"
    if (compact = "cardvk")
        return "CardVK"
    if (compact = "vu" or compact = "ву")
        return "VU"
    if (compact = "fp" or compact = "фп")
        return "FP"
    if (compact = "kon" or compact = "кон")
        return "KON"
    if (compact = "fzop" or compact = "фзоп")
        return "FZOP"
    if (compact = "ter" or compact = "тер")
        return "TER"
    if (compact = "tk" or compact = "тк")
        return "TK"
    if (compact = "arg" or compact = "арг")
        return "ARG"
    if (compact = "uk" or compact = "ук")
        return "UK"
    if (compact = "vv" or compact = "вв")
        return "VV"
    if (compact = "koap" or compact = "коап")
        return "KOAP"
    if (compact = "pdd" or compact = "пдд")
        return "PDD"
    if (compact = "oruzh" or compact = "оруж")
        return "ORUZH"
    if (compact = "upk" or compact = "упк")
        return "UPK"
    if (compact = "kas" or compact = "кас")
        return "KAS"
    if (compact = "fsb" or compact = "фсб")
        return "FSB"
    if (compact = "fsin" or compact = "фсин")
        return "FSIN"
    if (compact = "vs" or compact = "фзовс" or compact = "военнаяслужба")
        return "VS"
    if (compact = "sud" or compact = "суд")
        return "SUD"
    if (compact = "ord" or compact = "орд")
        return "ORD"
    if (compact = "gt" or compact = "гт" or compact = "гостайна")
        return "GT"
    return item
}

NormalizeBindListItemsValue(ByRef val) {
    val := StrReplace(val, "|", "`n")
    val := StrReplace(val, ",", "`n")
    val := RegExReplace(val, "(`r`n|`r)", "`n")
    val := RegExReplace(val, "`n{2,}", "`n")

    clean := ""
    Loop, Parse, val, `n, `r
    {
        item := NormalizeBindListToken(A_LoopField)
        if (item = "")
            continue
        if (clean != "")
            clean .= "`n"
        clean .= item
    }

    if (clean = "")
        clean := GetDefaultBindListItems()

    val := clean
}

SetDynamicGlobalValue(varName, newValue) {
    global
    if (varName = "")
        return
    %varName% := newValue
}

NormalizeHotkeyValue(ByRef val) {
    val := Trim(val)
    if (val = "ERROR")
        val := ""
}

GetCfgHotkeyOrder() {
    static order := ""
    if IsObject(order)
        return order

    order := []
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            order.Push("CFG_" . meta.HotkeyVar)
    }
    return order
}

GetCfgHotkeyMetaMap() {
    static metaMap := ""
    if IsObject(metaMap)
        return metaMap

    metaMap := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar != "")
            metaMap["CFG_" . meta.HotkeyVar] := {Label: meta.Label, Token: meta.Token, BindVar: meta.HotkeyVar}
    }
    return metaMap
}

SetSettingsBindsStatus(statusText) {
    global CFG_BindsStatusText, SettingsVisible
    CFG_BindsStatusText := statusText
    if (SettingsVisible)
        GuiControl, 2:, CFG_BindsStatusText, %statusText%
}

BuildHotkeyConflictStatus(changes) {
    msg := "Конфликты hotkey: "
    Loop % changes.Length()
    {
        item := changes[A_Index]
        if (A_Index > 1)
            msg .= " | "
        msg .= item.Hotkey . ": " . item.LoserLabel . " -> снят, оставлен " . item.WinnerLabel
    }
    return msg
}

ResolveCfgHotkeyConflicts(changedVar := "", showTip := 1) {
    global

    order := GetCfgHotkeyOrder()
    metaMap := GetCfgHotkeyMetaMap()
    used := {}
    changes := []

    if (changedVar != "")
    {
        currentValue := GetDynamicGlobalValue(changedVar)
        NormalizeHotkeyValue(currentValue)
        SetDynamicGlobalValue(changedVar, currentValue)
        if (currentValue != "")
        {
            keyId := currentValue
            StringLower, keyId, keyId
            used[keyId] := changedVar
        }
    }

    Loop % order.Length()
    {
        varName := order[A_Index]
        curValue := GetDynamicGlobalValue(varName)
        NormalizeHotkeyValue(curValue)
        SetDynamicGlobalValue(varName, curValue)

        if (varName = changedVar && changedVar != "")
            continue
        if (curValue = "")
            continue

        keyId := curValue
        StringLower, keyId, keyId

        if (used.HasKey(keyId))
        {
            winnerVar := used[keyId]
            winnerLabel := metaMap.HasKey(winnerVar) ? metaMap[winnerVar].Label : winnerVar
            loserLabel := metaMap.HasKey(varName) ? metaMap[varName].Label : varName
            blank := ""
            SetDynamicGlobalValue(varName, "")
            GuiControl, 2:, %varName%, %blank%
            changes.Push({Hotkey: curValue, WinnerLabel: winnerLabel, LoserLabel: loserLabel})
            continue
        }

        used[keyId] := varName
    }

    if (changes.Length() > 0)
    {
        statusText := BuildHotkeyConflictStatus(changes)
        SetSettingsBindsStatus(statusText)
        if (showTip)
        {
            ToolTip, %statusText%
            SetTimer, RemoveToolTip, -1800
        }
    }
    else
    {
        SetSettingsBindsStatus("Конфликтов hotkey нет. Последний выбранный hotkey имеет приоритет.")
    }
}

TaskScheduler_Set(name, totalMs, callback, statusText := "", payload := "") {
    global TaskSchedulerItems, TaskSchedulerNextDueTick, TaskSchedulerGeneration
    if !IsObject(TaskSchedulerItems)
        TaskSchedulerItems := {}
    totalMs := Round(totalMs)
    if (name = "" || totalMs < 1)
        return false
    if (totalMs > 2147480000)
        totalMs := 2147480000

    TaskSchedulerGeneration++
    endTick := TickNow() + totalMs
    TaskSchedulerItems[name] := {Name: name, EndTick: endTick, Callback: callback, Status: statusText, Payload: payload, Generation: TaskSchedulerGeneration}
    if (TaskSchedulerNextDueTick = 0 || TaskScheduler_RemainingMs(endTick) < TaskScheduler_RemainingMs(TaskSchedulerNextDueTick))
        TaskSchedulerNextDueTick := endTick
    return true
}

TaskScheduler_Cancel(name) {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return false
    if !TaskSchedulerItems.HasKey(name)
        return false
    TaskSchedulerItems.Delete(name)
    TaskScheduler_RecalculateNextDue()
    return true
}

TaskScheduler_CancelAll() {
    global TaskSchedulerItems, TaskSchedulerNextDueTick
    count := TaskScheduler_Count()
    TaskSchedulerItems := {}
    TaskSchedulerNextDueTick := 0
    return count
}

TaskScheduler_Count() {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return 0
    count := 0
    for name, task in TaskSchedulerItems
        count++
    return count
}

TaskScheduler_StatusText() {
    global TaskSchedulerItems
    if !IsObject(TaskSchedulerItems)
        return "нет"
    out := ""
    nowTick := TickNow()
    for name, task in TaskSchedulerItems
    {
        leftSec := Ceil(TaskScheduler_RemainingMs(task.EndTick, nowTick) / 1000.0)
        if (leftSec < 0)
            leftSec := 0
        minutes := Floor(leftSec / 60)
        seconds := Mod(leftSec, 60)
        timeText := Format("{:02}:{:02}", minutes, seconds)
        label := task.Status != "" ? task.Status : name
        if (out != "")
            out .= "; "
        out .= label . " " . timeText
    }
    return out != "" ? out : "нет"
}

TaskScheduler_RemainingMs(endTick, nowTick := "") {
    return endTick - (nowTick = "" ? TickNow() : nowTick)
}

TaskScheduler_RecalculateNextDue(nowTick := "") {
    global TaskSchedulerItems, TaskSchedulerNextDueTick
    if (nowTick = "")
        nowTick := TickNow()
    TaskSchedulerNextDueTick := 0
    bestRemaining := ""
    if !IsObject(TaskSchedulerItems)
        return 0
    for name, task in TaskSchedulerItems
    {
        remaining := TaskScheduler_RemainingMs(task.EndTick, nowTick)
        if (bestRemaining = "" || remaining < bestRemaining)
        {
            bestRemaining := remaining
            TaskSchedulerNextDueTick := task.EndTick
        }
    }
    return TaskSchedulerNextDueTick
}

TaskScheduler_Tick() {
    global TaskSchedulerItems, TaskSchedulerBusy, TaskSchedulerNextDueTick
    global TaskSchedulerLastStatusTick, TaskSchedulerMaxCallbacksPerTick, MDSFormationActive

    if (TaskSchedulerBusy)
        return false
    TaskSchedulerBusy := 1
    nowTick := TickNow()
    changed := 0
    ok := true

    try
    {
        if (MDSFormationActive)
            HandleMDSFormationTimerTick(0)

        shouldScan := IsObject(TaskSchedulerItems) && TaskSchedulerNextDueTick != 0
            && TaskScheduler_RemainingMs(TaskSchedulerNextDueTick, nowTick) <= 0
        if (shouldScan)
        {
            due := []
            for name, task in TaskSchedulerItems
            {
                if (TaskScheduler_RemainingMs(task.EndTick, nowTick) <= 0)
                    due.Push({Name: name, Generation: task.Generation})
            }

            processed := 0
            Loop % due.Length()
            {
                if (processed >= TaskSchedulerMaxCallbacksPerTick)
                    break
                dueItem := due[A_Index]
                name := dueItem.Name
                if !TaskSchedulerItems.HasKey(name)
                    continue
                task := TaskSchedulerItems[name]
                if (task.Generation != dueItem.Generation || TaskScheduler_RemainingMs(task.EndTick, nowTick) > 0)
                    continue

                TaskSchedulerItems.Delete(name)
                changed := 1
                processed++
                TaskScheduler_Invoke(task)
                Sleep, -1
                nowTick := TickNow()
            }
            TaskScheduler_RecalculateNextDue(nowTick)
        }

        if (changed || TaskSchedulerLastStatusTick = 0 || nowTick - TaskSchedulerLastStatusTick >= 1000)
        {
            TaskSchedulerLastStatusTick := nowTick
            UpdateAutomationSettingsStatus()
        }
    }
    catch e
    {
        ok := false
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("TaskScheduler", "Tick error: " . errorText, "ERROR")
        TaskScheduler_RecalculateNextDue()
    }

    TaskSchedulerBusy := 0
    return ok
}

TaskScheduler_Invoke(task) {
    if !IsObject(task)
        return false
    callback := task.Callback
    try
    {
        if (callback = "MDSFormation") {
            HandleMDSFormationTimerTick(1)
            return true
        }
        if (callback != "" && IsFunc(callback)) {
            fn := Func(callback)
            fn.Call(task.Payload)
            return true
        }
        LogError("TaskScheduler", "Unknown callback: " . callback, "WARN")
        return false
    }
    catch e
    {
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("TaskScheduler", "Callback " . callback . " failed: " . errorText, "ERROR")
        return false
    }
}

AutoReport_NormalizeMode(ByRef mode, fallback := "Патруль") {
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        mode := fallback
    return mode
}

TerritoryMapMode_Normalize(ByRef mode, fallback := "Local") {
    mode := Trim(mode)
    if (mode != "Local" && mode != "Forum")
        mode := fallback
    return mode
}

TerritoryMapMode_ToUiLabel(mode) {
    TerritoryMapMode_Normalize(mode)
    return (mode = "Forum") ? "Официальные ссылки" : "Локальные копии"
}

TerritoryMapMode_FromUiLabel(label) {
    label := Trim(label)
    mode := (label = "Forum" || label = "Официальные ссылки") ? "Forum" : "Local"
    TerritoryMapMode_Normalize(mode)
    return mode
}

AutoReport_IsValidDuration(durationMin) {
    raw := Trim(durationMin . "")
    if !RegExMatch(raw, "^\d+$")
        return false
    value := raw + 0
    return value >= 10 && value <= 600
}

AutoReport_GetTemplate() {
    global AutoReportMode, T_PatrolContinue, T_PostContinue
    templateText := (AutoReportMode = "Пост") ? T_PostContinue : T_PatrolContinue
    return ApplyTemplate(templateText)
}

AutoReport_GetStatusText(nowTick := "") {
    global AutoReportActive, AutoReportMode, AutoReportEndTick, AutoReportNextTick
    global AutoReportSentCount, AutoReportSkippedCount
    if (!AutoReportActive)
        return "Автодоклад: выключен"
    if (nowTick = "")
        nowTick := TickNow()
    leftSec := Ceil(TaskScheduler_RemainingMs(AutoReportEndTick, nowTick) / 1000.0)
    if (leftSec < 0)
        leftSec := 0
    leftText := Format("{:02}:{:02}", Floor(leftSec / 60), Mod(leftSec, 60))
    if (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= TaskScheduler_RemainingMs(AutoReportEndTick, nowTick))
    {
        nextSec := Ceil(TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) / 1000.0)
        if (nextSec < 0)
            nextSec := 0
        nextText := Format("{:02}:{:02}", Floor(nextSec / 60), Mod(nextSec, 60))
    }
    else
        nextText := "—"
    return "Автодоклад: " . AutoReportMode . " | осталось " . leftText . " | следующий " . nextText . " | в очереди принято " . AutoReportAcceptedCount . " | транспорт выполнен " . AutoReportSentCount . " | пропущено " . AutoReportSkippedCount
}

AutoReport_UpdateStatus() {
    global CFG_AutoReportStatus
    CFG_AutoReportStatus := AutoReport_GetStatusText()
    if SettingsGui_CanUpdate()
    {
        try
            GuiControl, 2:, CFG_AutoReportStatus, %CFG_AutoReportStatus%
    }
}

AutoReport_ScheduleNext() {
    global AutoReportActive, AutoReportEndTick, AutoReportNextTick
    if (!AutoReportActive)
        return false
    nextRemaining := TaskScheduler_RemainingMs(AutoReportNextTick)
    endRemaining := TaskScheduler_RemainingMs(AutoReportEndTick)
    dueTick := (nextRemaining <= endRemaining) ? AutoReportNextTick : AutoReportEndTick
    delayMs := TaskScheduler_RemainingMs(dueTick)
    if (delayMs < 1)
        delayMs := 1
    return TaskScheduler_Set("AutoReport", delayMs, "AutoReport_OnTask", "Автодоклад")
}

AutoReport_Start(mode, durationMin, showStatus := 1) {
    global AutoReportMode, AutoReportDurationMin, AutoReportActive
    global AutoReportStartTick, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSentCount, AutoReportSkippedCount

    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
    {
        if (showStatus)
            GameNotify("Выберите режим автодоклада: Патруль или Пост.", "WARN")
        return false
    }
    if !AutoReport_IsValidDuration(durationMin)
    {
        if (showStatus)
            GameNotify("Продолжительность автодоклада: целое число от 10 до 600 минут.", "WARN")
        return false
    }

    AutoReport_Stop(0, "replace")
    AutoReportMode := mode
    AutoReportDurationMin := durationMin + 0
    AutoReportActive := 1
    AutoReportStartTick := TickNow()
    AutoReportEndTick := AutoReportStartTick + AutoReportDurationMin * 60000
    AutoReportNextTick := AutoReportStartTick + 600000
    AutoReportLastDispatchTick := 0
    AutoReportSentCount := 0
    AutoReportAcceptedCount := 0
    AutoReportSkippedCount := 0
    if !AutoReport_ScheduleNext()
    {
        AutoReportActive := 0
        if (showStatus)
            GameNotify("Не удалось поставить автодоклад в планировщик.", "ERROR")
        return false
    }
    AutoReportLastDispatchTick := AutoReportStartTick
    if !AutoReport_DispatchScheduled(AutoReportStartTick)
    {
        AutoReport_Stop(0, "initial-dispatch-failed")
        if (showStatus)
            GameNotify("Автодоклад не запущен: первый доклад не удалось поставить в очередь.", "ERROR")
        return false
    }
    LogError("AutoReport", "Started: mode=" . AutoReportMode . ", duration=" . AutoReportDurationMin . " min", "INFO")
    ActionTimer_StartAutoReport(AutoReportMode)
    AutoReport_UpdateStatus()
    UpdateAutomationSettingsStatus()
    if (showStatus)
        GameNotify("Автодоклад «" . AutoReportMode . "» запущен на " . FormatRussianMinutes(AutoReportDurationMin) . ". Первый доклад поставлен в очередь сразу. Следующий — через 10 минут.", "INFO")
    return true
}

AutoReport_Stop(showStatus := 1, reason := "manual") {
    global AutoReportActive, AutoReportMode, AutoReportStartTick, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSentCount, AutoReportSkippedCount
    wasActive := AutoReportActive
    stoppedMode := AutoReportMode
    TaskScheduler_Cancel("AutoReport")
    if (wasActive)
        LogError("AutoReport", "Stopped: reason=" . reason . ", sent=" . AutoReportSentCount . ", skipped=" . AutoReportSkippedCount, "INFO")
    if (reason != "completed")
        ChatQueue_RemoveBySource("AutoReport")
    AutoReportActive := 0
    AutoReportStartTick := 0
    AutoReportEndTick := 0
    AutoReportNextTick := 0
    AutoReportLastDispatchTick := 0
    AutoReportSentCount := 0
    AutoReportAcceptedCount := 0
    AutoReportSkippedCount := 0
    stoppedToken := (stoppedMode = "Пост") ? "Post" : "Patrol"
    ActionTimer_Stop(stoppedToken, 1, "AutoReport")
    AutoReport_UpdateStatus()
    UpdateAutomationSettingsStatus()
    if (wasActive && reason = "completed")
    {
        GameNotify("Автодоклад «" . stoppedMode . "» завершён.", "INFO")
        if ActionTimer_IsEnabled(stoppedMode)
            PlayStopTimerSound()
    }
    if (showStatus && wasActive)
        GameNotify("Автодоклад «" . stoppedMode . "» остановлен.", "INFO")
    return wasActive
}

AutoReport_DispatchScheduled(scheduledTick) {
    global MockMode, AutoReportAcceptedCount, AutoReportSkippedCount
    reportText := AutoReport_GetTemplate()
    if (Trim(reportText) = "")
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "Report template is empty; tick skipped.", "WARN")
        return false
    }
    if (MockMode = "On")
        queued := ChatQueue_Enqueue(reportText, "AutoReport", 1, 700, 1)
    else if !GameLocator_IsActive()
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "Game is unavailable; scheduled report skipped.", "WARN")
        return false
    }
    else
        queued := ChatQueue_Enqueue(reportText, "AutoReport", 0, 700, 1)

    if (queued)
        AutoReportAcceptedCount += 1
    else
    {
        AutoReportSkippedCount += 1
        LogError("AutoReport", "ChatQueue rejected scheduled report.", "WARN")
    }
    return queued
}

AutoReport_HandleTick(nowTick := "") {
    global AutoReportActive, AutoReportEndTick, AutoReportNextTick
    global AutoReportLastDispatchTick, AutoReportSkippedCount
    if (!AutoReportActive)
        return false
    if (nowTick = "")
        nowTick := TickNow()

    endRemaining := TaskScheduler_RemainingMs(AutoReportEndTick, nowTick)
    nextRemaining := TaskScheduler_RemainingMs(AutoReportNextTick, nowTick)
    if (nextRemaining <= endRemaining && nextRemaining <= 0)
    {
        scheduledTick := AutoReportNextTick
        missed := 0
        while (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= 0)
        {
            AutoReportNextTick := AutoReportNextTick + 600000
            missed += 1
        }
        lateness := -TaskScheduler_RemainingMs(scheduledTick, nowTick)
        if (missed > 1 || lateness > 60000)
        {
            AutoReportSkippedCount += missed
            LogError("AutoReport", "Missed " . missed . " interval(s); catch-up suppressed.", "WARN")
        }
        else if (AutoReportLastDispatchTick != scheduledTick)
        {
            AutoReportLastDispatchTick := scheduledTick
            AutoReport_DispatchScheduled(scheduledTick)
        }
    }

    if (TaskScheduler_RemainingMs(AutoReportEndTick, nowTick) <= 0)
    {
        AutoReport_Stop(0, "completed")
        return true
    }
    AutoReport_ScheduleNext()
    AutoReport_UpdateStatus()
    return true
}

AutoReport_OnTask(payload := "") {
    return AutoReport_HandleTick(TickNow())
}

RunV1MockRegression() {
    global MockMode, ChatQueueEnabled, ChatQueueMaxItems, ChatQueueItems, ChatQueueBusy
    global TaskSchedulerItems, SettingsVisible, LogDir, ModernLogFile, MaxLogBytes
    global IntroRole, ReportRole, Rank, ReportRank, Surname
    global PatrolUnit, PatrolRoute, PatrolCrewCount, PostUnit, PostRoute, PostCrewCount, ConvoyRoute
    global AutoReportActive
    MockMode := "On"
    ChatQueueEnabled := "On"
    ChatQueueMaxItems := 200
    ChatQueueItems := []
    ChatQueueBusy := 0
    TaskSchedulerItems := {}
    SettingsVisible := 0
    LogDir := A_ScriptDir . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    MaxLogBytes := 262144
    IntroRole := "начальником МДС ГАИ", ReportRole := "Начальник МДС ГАИ"
    Rank := "лейтенант", ReportRank := "лейтенант", Surname := "Лукашенко"
    PatrolUnit := "Р101", PatrolRoute := "А-1", PatrolCrewCount := "2"
    PostUnit := "Р202", PostRoute := "АП ГАИ", PostCrewCount := "3"
    ConvoyRoute := "Арзамас — Батырево"

    cases := []
    cases.Push(["представление", ApplyTemplate("Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}."), "начальником МДС ГАИ"])
    cases.Push(["/d", ApplyTemplate("/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь."), "/d [ГАИ/]"])
    cases.Push(["SOS принят", ApplyTemplate("/r докладывает {SURNAME}: реагирую на вызов срочной помощи."), "срочной помощи"])
    cases.Push(["SOS прибыл", ApplyTemplate("/r докладывает {SURNAME}: прибыл на вызов срочной помощи."), "прибыл"])
    cases.Push(["гражданский принят", ApplyTemplate("/r докладывает {SURNAME}: принял вызов гражданского."), "принял вызов гражданского"])
    cases.Push(["гражданский прибыл", ApplyTemplate("/r докладывает {SURNAME}: прибыл на вызов гражданского."), "прибыл на вызов гражданского"])
    cases.Push(["ДТП принят", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП."), "принял вызов о ДТП"])
    cases.Push(["ДТП прибыл", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП."), "прибыли"])
    cases.Push(["ДТП оформление", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП."), "приступили"])
    cases.Push(["ДТП завершено", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП."), "завершили"])
    cases.Push(["патруль", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."), "Р101"])
    cases.Push(["пост", ApplyTemplate("/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек."), "АП ГАИ"])
    cases.Push(["колонна", ApplyTemplate("/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}."), "военной колонны"])
    cases.Push(["эвакуация начало", ApplyTemplate("/r докладывает {SURNAME}: начал эвакуировать ТС на штрафстоянку."), "начал эвакуировать"])
    cases.Push(["эвакуация конец", ApplyTemplate("/r докладывает {SURNAME}: эвакуировал ТС на штрафстоянку."), "эвакуировал ТС"])
    cases.Push(["Chase с ID", ContextAssistant_BuildCommand("Chase", 4321), "/chase 4321"])
    cases.Push(["Chase без ID", "/chase", "/chase"])

    checks := []
    ok := true
    Loop % cases.Length()
    {
        item := cases[A_Index]
        queued := ChatQueue_Enqueue(item[2], "Mock." . item[1], 1)
        passed := queued && InStr(item[2], item[3]) && !RegExMatch(item[2], "\{[A-Z0-9_]+\}")
        checks.Push([item[1], passed])
        ok := passed && ok
    }

    serviceOk := VehicleLookup_ResolveCountry("!Россия", countryIndex, countryName)
        && countryIndex = 1 && VehicleLookup_ResolveRegion("!05", regionIndex, regionCode)
        && regionCode = "05" && VehicleLookup_NormalizePlate("а123аа") = "A123AA"
        && WantedRemoval_GetReason(3, removalReason) && removalReason = "самооборона"
        && Fine_ParseArticle("!20.6", fineArticle, fineChapter, fineItem, fineError)
        && fineArticle = "20.6" && fineChapter = 20 && fineItem = 6
        && GetBoundLabelByToken("VehicleLookup") = "DoVehicleLookup"
        && GetBoundLabelByToken("WantedRemoval") = "DoWantedRemoval"
    checks.Push(["сервисные мастера и штраф", serviceOk])
    ok := serviceOk && ok

    autoOk := RunAutoReportMockTest()
    checks.Push(["автоматический доклад", autoOk])
    ok := autoOk && ok

    ChatQueueItems := []
    TaskSchedulerItems := {}
    AutoReport_Start("Патруль", 20, 0)
    ChatQueue_Enqueue("/r mock pending", "Mock.Cancel", 1)
    CancelAllAutomation(0)
    cancelOk := !AutoReportActive && ChatQueue_Count() = 0 && TaskScheduler_Count() = 0
    checks.Push(["отмена всей автоматизации", cancelOk])
    ok := cancelOk && ok

    report := "AHK FOR GOS BY SBEZRUK v1.0 MockMode regression`r`n"
    Loop % checks.Length()
        report .= (checks[A_Index][2] ? "PASS" : "FAIL") . " | " . checks[A_Index][1] . "`r`n"
    report .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    path := A_ScriptDir . "\v1_mocktest_report.txt"
    FileDelete, %path%
    FileAppend, %report%, %path%
    return ok
}

RunLawSearchRegression() {
    audit := LawSearch_AuditIndex()
    corpusAudit := LawCorpus_Audit()
    mapAudit := TerritoryMap_AuditCatalog()
    checks := []
    checks.Push(["all documents/pages/headings indexed", audit.Ok])
    checks.Push(["official corpus 20/20", corpusAudit.Ok && corpusAudit.Documents = 20])
    checks.Push(["territory maps 11 groups/all assets", mapAudit.Ok && mapAudit.Groups = 11])
    checks.Push(["exact reference", LawSearch_CheckExpected("ФЗОТОД гл. 3 ст. 9.2 ч. 2", "ALL", "TER", "9.2", "2", 3)])
    checks.Push(["compact reference", LawSearch_CheckExpected("ФЗОТОД гл3 ст9.2 ч2", "ALL", "TER", "9.2", "2", 3)])
    checks.Push(["natural query", LawSearch_CheckExpected("кто считается сотрудником полиции", "ALL", "FZOP", "16", "1", 5)])
    checks.Push(["word permutation", LawSearch_CheckExpected("полиции сотрудник", "ALL", "FZOP", "16", "1", 5)])
    checks.Push(["word form", LawSearch_CheckExpected("сотрудника полиции", "ALL", "FZOP", "16", "1", 5)])
    checks.Push(["bounded typo", LawSearch_CheckExpected("сотрудник полицеи", "ALL", "FZOP", "16", "1", 5)])
    checks.Push(["negative query", LawSearch_CheckNoResults("квазиплазменный телепортатор", "ALL")])
    checks.Push(["KAS article reference", LawSearch_CheckExpected("КАС статья 1", "ALL", "KAS", "1", "", 5)])
    checks.Push(["current KOAP 17.5", LawSearch_CheckExpected("КоАП статья 17.5", "ALL", "KOAP", "17.5", "", 3)])
    checks.Push(["current KAS 135", LawSearch_CheckExpected("КАС статья 135", "ALL", "KAS", "135", "", 3)])
    checks.Push(["deleted FZOP 8.10 absent", LawSearch_CheckNoResults("ФЗОП статья 8 пункт 10", "ALL")])
    checks.Push(["dynamic full-document pages", LawCorpus_PageCount("kas") > 4 && LawCorpus_PageCount("upk") > 41])
    package := LawSearch_Find("ALL", "сотрудник", 99)
    checks.Push(["30-result cap and total", package.Results.Length() <= 30 && package.Passed >= package.Results.Length()])
    report := "AHK FOR GOS BY SBEZRUK v1.0 law-search regression`r`n"
    report .= "Documents=" . audit.Documents . " Pages=" . audit.Pages
        . " ArticleHeadings=" . audit.Headings . " AuditFailures=" . audit.Failures.Length() . "`r`n"
    report .= "OfficialCorpusDocs=" . corpusAudit.Documents . " CorpusChars=" . corpusAudit.Characters
        . " MapGroups=" . mapAudit.Groups . "`r`n"
    ok := true
    Loop % checks.Length()
    {
        item := checks[A_Index]
        report .= (item[2] ? "PASS" : "FAIL") . " | " . item[1] . "`r`n"
        if !item[2]
            ok := false
    }
    if (audit.Failures.Length() > 0) {
        report .= "`r`nIndex failures (first 30):`r`n"
        Loop % audit.Failures.Length() {
            if (A_Index > 30)
                break
            report .= "- " . audit.Failures[A_Index] . "`r`n"
        }
    }
    report .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    path := A_ScriptDir . "\law_search_test_report.txt"
    FileDelete, %path%
    FileAppend, %report%, %path%
    return ok
}

RunAutoReportMockTest() {
    global
    SettingsVisible := 0
    MockMode := "On"
    ChatQueueEnabled := "On"
    ChatQueueMaxItems := 200
    ChatQueueItems := []
    ChatQueueBusy := 0
    ChatQueueNextSendTick := 0
    ChatQueueLastSendTick := 0
    TaskSchedulerItems := {}
    MDSFormationActive := 0
    ChatWizardMode := ""
    LogDir := A_ScriptDir . "\logs"
    ModernLogFile := LogDir . "\amz_gos.log"
    MaxLogBytes := 262144
    T_PatrolContinue := "/r экипаж {PATROL_UNIT}: патрулируем {PATROL_ROUTE}, состав {PATROL_CREW_COUNT}."
    T_PostContinue := "/r экипаж {POST_UNIT}: пост {POST_ROUTE}, состав {POST_CREW_COUNT}."
    PatrolUnit := "Р101"
    PatrolRoute := "А-1"
    PatrolCrewCount := "2"
    PostUnit := "Р202"
    PostRoute := "КПП"
    PostCrewCount := "3"

    checks := []
    ok := true

    durationOk := AutoReport_IsValidDuration("10") && AutoReport_IsValidDuration("600")
        && !AutoReport_IsValidDuration("9") && !AutoReport_IsValidDuration("601")
        && !AutoReport_IsValidDuration("10a") && !AutoReport_IsValidDuration("10.5")
    checks.Push({Name: "strict duration 10-600", Ok: durationOk})
    ok := durationOk && ok

    startOk := AutoReport_Start("Патруль", 20, 0)
        && AutoReportActive
        && TaskSchedulerItems.HasKey("AutoReport")
        && (TaskScheduler_RemainingMs(AutoReportNextTick, AutoReportStartTick) = 600000)
        && AutoReportLastDispatchTick = AutoReportStartTick
        && ChatQueue_Count() = 1
        && AutoReportAcceptedCount = 1
    checks.Push({Name: "start and immediate first report", Ok: startOk})
    ok := startOk && ok

    firstTick := AutoReportNextTick
    AutoReport_HandleTick(firstTick)
    firstOk := (ChatQueue_Count() = 2 && AutoReportAcceptedCount = 2 && TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "ten-minute tick and reschedule", Ok: firstOk})
    ok := firstOk && ok

    AutoReport_HandleTick(firstTick)
    noDoubleOk := (ChatQueue_Count() = 2 && AutoReportAcceptedCount = 2)
    checks.Push({Name: "no double send", Ok: noDoubleOk})
    ok := noDoubleOk && ok

    replaceOk := AutoReport_Start("Пост", 15, 0)
        && AutoReportActive
        && AutoReportMode = "Пост"
        && AutoReportDurationMin = 15
        && ChatQueue_Count() = 1
        && AutoReportAcceptedCount = 1
        && TaskScheduler_Count() = 1
        && TaskSchedulerItems.HasKey("AutoReport")
    checks.Push({Name: "safe replacement", Ok: replaceOk})
    ok := replaceOk && ok

    AutoReport_Stop(0, "mock-stop")
    stopOk := (!AutoReportActive && ChatQueue_Count() = 0 && !TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "manual stop", Ok: stopOk})
    ok := stopOk && ok

    ChatQueueItems := []
    AutoReport_Start("Пост", 10, 0)
    completionTick := AutoReportEndTick
    AutoReport_HandleTick(completionTick)
    completionOk := (!AutoReportActive && ChatQueue_Count() = 2 && !TaskSchedulerItems.HasKey("AutoReport"))
    checks.Push({Name: "completion at duration", Ok: completionOk})
    ok := completionOk && ok

    ChatQueueItems := []
    AutoReport_Start("Патруль", 20, 0)
    CancelAllAutomation(0)
    cancelAllOk := (!AutoReportActive && ChatQueue_Count() = 0 && TaskScheduler_Count() = 0)
    checks.Push({Name: "CancelAllAutomation", Ok: cancelAllOk})
    ok := cancelAllOk && ok

    FileRead, sourceText, %A_ScriptFullPath%
    loadPos := RegExMatch(sourceText, "m)^LoadProfile\(profileName\) \{")
    finalizePos := InStr(sourceText, "FinalizeLoadedProfileState(profileName)", false, loadPos)
    loadSection := (loadPos > 0 && finalizePos > loadPos) ? SubStr(sourceText, loadPos, finalizePos - loadPos) : ""
    profileSwitchOk := InStr(loadSection, "AutoReport_Stop(0, ""profile-switch"")") > 0
    checks.Push({Name: "profile switch cancellation", Ok: profileSwitchOk})
    ok := profileSwitchOk && ok

    reportText := "AHK FOR GOS BY SBEZRUK v1 AutoReport mock test`r`n"
    Loop % checks.Length()
    {
        item := checks[A_Index]
        reportText .= (item.Ok ? "PASS" : "FAIL") . " | " . item.Name . "`r`n"
    }
    reportText .= (ok ? "RESULT=PASS" : "RESULT=FAIL") . "`r`nLIVE GAME: NOT RUN`r`n"
    reportPath := A_ScriptDir . "\autoreport_mocktest_report.txt"
    FileDelete, %reportPath%
    FileAppend, %reportText%, %reportPath%
    return ok
}

ChatQueue_Count() {
    global ChatQueueItems
    return IsObject(ChatQueueItems) ? ChatQueueItems.Length() : 0
}

ChatQueue_RemoveBySource(source) {
    global ChatQueueItems
    if !IsObject(ChatQueueItems)
        return 0
    kept := []
    removed := 0
    Loop % ChatQueueItems.Length()
    {
        item := ChatQueueItems[A_Index]
        if (IsObject(item) && item.HasKey("Source") && item.Source = source)
            removed += 1
        else
            kept.Push(item)
    }
    if (removed > 0)
    {
        ChatQueueItems := kept
        UpdateHUD()
    }
    return removed
}

ChatQueue_StatusText() {
    global ChatQueueBusy
    count := ChatQueue_Count()
    if (count <= 0)
        return ChatQueueBusy ? "отправка" : "пусто"
    return count . " в очереди"
}

ChatQueue_Enqueue(text, source := "ChatQueue", forceMock := 0, delayAfter := "", forceQueue := 0) {
    global ChatQueueItems, ChatQueueEnabled, ChatQueueMaxItems
    text := Trim(text)
    if (text = "")
        return false
    if (!forceMock && !forceQueue && ChatQueueEnabled != "On")
        return ChatQueue_SendNow(text, source)
    if !IsObject(ChatQueueItems)
        ChatQueueItems := []
    NormalizeNumberRange(ChatQueueMaxItems, 200, 10, 1000)
    if (ChatQueueItems.Length() >= ChatQueueMaxItems) {
        LogError(source, "Очередь переполнена, строка отклонена: " . text, "ERROR")
        Notify("warn")
        return false
    }
    if (delayAfter != "")
        NormalizeNumberRange(delayAfter, 700, 0, 30000)
    ChatQueueItems.Push({Text: text, Source: source, Tries: 0, ForceMock: forceMock ? 1 : 0, DelayAfter: delayAfter, Epoch: AutomationEpoch, Batch: 0})
    LogError(source, "Queued chat line: " . text, "INFO")
    UpdateHUD()
    return true
}

ChatQueue_SendNow(text, source := "ChatQueue") {
    return ChatQueue_TrySend(text, source)
}

ChatQueue_Tick() {
    global ChatQueueItems, ChatQueueBusy, ChatQueueLastSendTick, ChatQueueNextSendTick
    global ChatQueueMinDelay, ChatQueueMaxRetries, AutoReportSentCount, AutoReportSkippedCount
    global QueueFailureGeneration, AuditTransportResult, AuditTestMode, QueueBatchStates
    if (ChatQueueBusy || PhysicalInputBusy || IsObject(IDCaptureState) || !IsObject(ChatQueueItems) || !ChatQueueItems.Length())
        return
    if (ChatQueueNextSendTick > TickNow())
        return
    NormalizeNumberRange(ChatQueueMinDelay, 700, 250, 5000)
    NormalizeNumberRange(ChatQueueMaxRetries, 2, 0, 5)
    if (ChatQueueLastSendTick && TickNow() - ChatQueueLastSendTick < ChatQueueMinDelay)
        return
    ChatQueueBusy := 1
    item := ChatQueueItems.RemoveAt(1)
    try {
        epoch := item.HasKey("Epoch") ? item.Epoch : AutomationEpoch
        if (epoch != AutomationEpoch) {
            ChatQueue_CompleteItem(item, "cancelled")
            return
        }
        if (item.HasKey("Kind") && item.Kind = "Menu") {
            result := QueueMenu_Run(item) ? 1 : -1
        } else if (item.HasKey("ForceMock") && item.ForceMock) {
            MockPreview_Append(item.Text)
            result := 1
        } else
            result := AuditTestMode ? AuditTransportResult : ChatTransport_Send(item.Text, item.Source, item.HasKey("Role") ? item.Role : "")
        if (epoch != AutomationEpoch) {
            ChatQueue_CompleteItem(item, "cancelled")
            return
        }
        if (result = 1) {
            if (item.Source = "AutoReport")
                AutoReportSentCount++
            if (!AuditTestMode && !item.HasKey("Kind"))
                Evidence_MaybeCaptureReportText(item.Text)
            ChatQueueLastSendTick := TickNow()
            ChatQueueNextSendTick := TickNow() + (item.DelayAfter = "" ? ChatQueueMinDelay : item.DelayAfter)
            ChatQueue_CompleteItem(item, "sent")
        } else if (result != -2 && !item.HasKey("Kind") && !IsObject(g_RemoteOperation) && item.Tries < ChatQueueMaxRetries) {
            item.Tries++
            ChatQueueItems.InsertAt(1, item)
            ChatQueueNextSendTick := TickNow() + 1000
        } else {
            QueueFailureGeneration++
            if (item.Source = "AutoReport")
                AutoReportSkippedCount++
            ChatQueue_CompleteItem(item, result = -2 || IsObject(g_RemoteOperation) ? "unknown" : "failed")
            LogError(item.Source, "Отправка не подтверждена; остаток операции отменён: " . item.Text, "ERROR")
            ChatQueueNextSendTick := TickNow() + ChatQueueMinDelay
        }
    } catch e {
        QueueFailureGeneration++
        ChatQueue_CompleteItem(item, "failed")
        LogError("ChatQueue", e.Message, "ERROR")
    } finally {
        ChatQueueBusy := 0
        if (!AuditTestMode)
            UpdateHUD()
    }
}

ChatQueue_EnqueueSequence(sequenceText, source := "Sequence", delayAfter := 700) {
    lines := []
    sequenceText := StrReplace(StrReplace(sequenceText, "`r`n", "`n"), "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        if (Trim(A_LoopField) != "")
            lines.Push(ApplyActionTemplate(Trim(A_LoopField)))
    }
    return ChatQueue_EnqueueBatch(lines, source, delayAfter) ? lines.Length() : 0
}

ChatQueue_TrySend(text, source := "ChatQueue") {
    epoch := AutomationEpoch
    result := ChatTransport_Send(text, source)
    if (result = 1 && epoch = AutomationEpoch)
        Evidence_MaybeCaptureReportText(text)
    return result = 1
}

SendChat(text, source := "Direct") {
    result := ChatTransport_Send(text, source)
    if (result = 1)
        Evidence_MaybeCaptureReportText(text)
    return result
}

ChatTransport_SetStatus(status, source := "ChatTransport", level := "INFO") {
    global ChatTransportStatus
    if (status = ChatTransportStatus)
        return
    ChatTransportStatus := status
    LogError(source, "Chat transport: " . status, level)
}

ChatTransport_GetDisplayStatus() {
    global MockMode, TextSendMode, ChatTransportStatus
    if (MockMode = "On")
        return "Mock (без игры)"
    if (ChatTransportStatus != "" && ChatTransportStatus != "Ожидание")
        return ChatTransportStatus
    return TextSendMode
}

ChatTransport_GetConnectionSummary(runMemoryCheck := 0) {
    global MockMode, TextSendMode, GameWindowTitle, GameProcessName, GAME_MP_ModuleName
    global GAME_DETECTION_SOURCE
    NormalizeTextSendMode(TextSendMode)
    ApplyGameProcessSelector()
    if (MockMode = "On")
        return "Тест без игры включён | Реальная отправка отключена"

    gamePID := 0, gameSelector := "", locatorSource := ""
    if !GameLocator_Find(gamePID, gameSelector, locatorSource)
        return "PROCESS_LOOKUP: не найдено окно """ . GameWindowTitle . """ и EXE " . GameProcessName . " | Режим: " . TextSendMode

    sourceText := (locatorSource = "title") ? "заголовок" : "EXE (резерв)"
    activeText := WinActive(gameSelector) ? "окно активно" : "окно не активно"
    if (!runMemoryCheck)
        return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | Режим: " . TextSendMode

    memoryReady := checkHandles()
    if (memoryReady)
        return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | Memory готов | " . GetAzmpCompatibilitySummary()

    reason := MemoryGetShortError()
    if (TextSendMode = "Auto" && WinActive(gameSelector))
        reason .= " | Keyboard готов"
    else if (TextSendMode = "Auto")
        reason .= " | активируй окно для Keyboard"
    return "PID " . gamePID . " через " . sourceText . ", " . activeText . " | " . reason
}

ChatTransport_Send(text, source := "ChatTransport", role := "") {
    if IsObject(IDCaptureState)
        return -1
    global MockMode, TextSendMode, g_RemoteOperation
    global ChatTransportLastMemoryFailureTick, ChatTransportMemoryRetryMs
    text := "" . text
    if (text = "")
        return -1
    if (MockMode = "On")
    {
        MockPreview_Append(text)
        ChatTransport_SetStatus("Mock (без игры)", source)
        return true
    }

    ApplyGameProcessSelector()
    NormalizeTextSendMode(TextSendMode)
    if (TextSendMode = "FastTyping" || TextSendMode = "FactionTyping") {
        if ChatTyping_ShouldType(TextSendMode, text, ChatFactionCommands) {
            result := SendChatTyped(text, true, true, "", ChatTransport_TypingDelayOverride(source, role, text))
            status := result = 1 ? ChatTyping_ModeLabel(TextSendMode) : (result = -2 ? "Печать прервана; повтор отключён" : "Печать: " . (ChatTypingLastError != "" ? ChatTypingLastError : "отправка недоступна"))
            ChatTransport_SetStatus(status, source, result = 1 ? "INFO" : "WARN")
            return result
        }
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Вставка (остальной текст)" : "Вставка: отправка недоступна", source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }
    if (TextSendMode = "Keyboard")
    {
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Keyboard" : "Keyboard: игра не активна", source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }

    if (TextSendMode = "Memory")
    {
        result := SendChatMemory(text)
        if (result = 1)
            ChatTransport_SetStatus("Memory", source)
        else {
            memoryStatus := MemoryGetStatusText()
            memoryError := MemoryGetShortError()
            ChatTransport_SetStatus("Memory: " . memoryError, source, "ERROR")
            LogError(source, "Memory send failed | " . memoryStatus, "ERROR")
        }
        return IsObject(g_RemoteOperation) ? -2 : result
    }

    if IsObject(g_RemoteOperation)
        return -2
    memoryError := ""
    nowTick := TickNow()
    canRetryMemory := (ChatTransportLastMemoryFailureTick <= 0 || nowTick - ChatTransportLastMemoryFailureTick >= ChatTransportMemoryRetryMs)
    if (canRetryMemory)
    {
        result := SendChatMemory(text)
        if (result = 1)
        {
            ChatTransportLastMemoryFailureTick := 0
            ChatTransport_SetStatus("Memory (Auto)", source)
            return 1
        }
        if IsObject(g_RemoteOperation)
            return -2
        memoryStatus := MemoryGetStatusText()
        memoryError := MemoryGetShortError()
        LogError(source, "Auto Memory failed | " . memoryStatus, "WARN")
        ChatTransportLastMemoryFailureTick := nowTick
    }

    if GameLocator_IsActive()
    {
        ok := SendChatKeyboard(text)
        ChatTransport_SetStatus(ok ? "Keyboard (Auto)" : "Auto: Keyboard не отправил после " . memoryError, source, ok ? "INFO" : "WARN")
        return ok ? 1 : -1
    }

    if (memoryError = "")
        memoryError := MemoryGetShortError()
    ChatTransport_SetStatus("Auto: " . memoryError . "; активируй игру для Keyboard", source, "WARN")
    return -1
}

MockPreview_Append(text) {
    global ChatQueuePreviewText, ChatQueuePreviewLineCount, ChatQueuePreviewKnownLength
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
    if (!AuditTestMode)
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

ChatQueue_EnqueueMockDemo() {
    ChatQueue_Enqueue("/me проверил работу очереди сообщений.", "MockDemo", 1)
    ChatQueue_Enqueue("/do Первая строка доставлена без запуска GTA/SAMP.", "MockDemo", 1)
    ChatQueue_Enqueue("/r Тест очереди AHK FOR GOS BY SBEZRUK завершён.", "MockDemo", 1)
    MockPreview_Show()
    UpdateAutomationSettingsStatus()
    return 3
}

MockPreview_Show() {
    global hMockPreviewWnd, MockPreviewEdit, MockPreviewCountText, ChatQueuePreviewText, ThemeMode
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    controlBg := "F7F8FA", inputText := "111418", cardBg := "2A3037", cardEdge := "3A434D"
    if (ThemeMode = "Graphite")
        controlBg := bg, inputText := text
    else
        GetControlSurfaceColors(controlBg, inputText, cardBg, cardEdge, panel, text, accent)
    count := MockPreview_LineCount()
    if (!hMockPreviewWnd)
    {
        Gui, 41:Destroy
        Gui, 41:+HwndhMockPreviewWnd +AlwaysOnTop +ToolWindow -Resize
        Gui, 41:Color, %bg%, %controlBg%
        Gui, 41:Font, s14 Bold c%text%, Segoe UI
        Gui, 41:Add, Text, x14 y12 w400 h28 BackgroundTrans, Тестовый чат
        Gui, 41:Font, Norm s9 c%muted%, Segoe UI
        Gui, 41:Add, Text, x430 y18 w190 h20 Right vMockPreviewCountText BackgroundTrans, % "Строк: " . count
        Gui, 41:Font, Norm s10 c%inputText%, Consolas
        Gui, 41:Add, Edit, x14 y50 w612 h310 ReadOnly -Wrap vMockPreviewEdit, %ChatQueuePreviewText%
        Gui, 41:Font, Norm s10 c%text%, Segoe UI
        Gui, 41:Add, Button, x14 y374 w130 h30 gClearMockPreviewLabel, Очистить
        Gui, 41:Add, Button, x496 y374 w130 h30 gCloseMockPreviewLabel, Закрыть
        Capture_BeforeShow("41")
        Gui, 41:Show, w640 h420 NoActivate, AMZ MockMode - тест без игры
        WinSet, Transparent, 255, ahk_id %hMockPreviewWnd%
    }
    GuiControl, 41:, MockPreviewEdit, %ChatQueuePreviewText%
    GuiControl, 41:, MockPreviewCountText, % "Строк: " . count
}

CancelAllAutomation(showStatus := 1) {
    IDCapture_Complete("cancel")
    global ChatWizardMode, EvidenceScreenshotQueue, EvidencePendingEvents, EvidenceDocumentContext, EvidenceDocumentWindowExpires
    StopCustomFunctionRun(0)
    HideStopTimerGUI()
    EvidenceScreenshotQueue := []
    EvidencePendingEvents := {}
    EvidenceDocumentContext := {}
    EvidenceDocumentWindowExpires := 0
    ChatLogReader_ResetGeneration()
    SetTimer, EvidenceScreenshotTimer, Off
    Input
    ChatWizardMode := ""
    StopMDSFormationCountdown(0)
    AutoReport_Stop(0, "cancel-all")
    TaskScheduler_CancelAll()
    ChatQueue_Clear(0)
    ActionTimer_Clear()
    ContextAssistant_Close()
    UpdateHUD()
    UpdateAutomationSettingsStatus()
    if (showStatus)
    {
        ToolTip, Активные автоматизации остановлены.
        SetTimer, RemoveToolTip, -1600
    }
}
SendChatKeyboard(text) {
    if IsObject(IDCaptureState)
        return false
    global MockMode
    if (text = "")
        return false
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append(text)
        return true
    }
    previous := A_IsCritical
    Critical, On
    if (PhysicalInputBusy || IsObject(IDCaptureState) || !GameLocator_IsActive()) {
        Critical, %previous%
        return false
    }
    PhysicalInputBusy := 1
    epoch := AutomationEpoch
    Critical, %previous%
    try {
        chatState := isInChat()
        if (chatState < 0)
            return false
        if (chatState = 0) {
            if !SafeSend("{F6}", "Input", epoch)
                return false
            Sleep, 120
        }
        if !SafeSend("^a{Backspace}", "Input", epoch)
            return false
        Sleep, 50
        if (epoch != AutomationEpoch || !SafeLayout(0x4190419) || !PasteOnly(text, 1))
            return false
        Sleep, 70
        return SafeSend("{Enter}", "Input", epoch)
    } finally {
        PhysicalInputBusy := 0
    }
}

SendChatAuto(text) {
    trimmed := Trim(text)
    if (trimmed = "")
        return
    ChatQueue_Enqueue(trimmed, "SendChatAuto")
}

FormatRussianMinutes(minutes) {
    minutes += 0
    mod100 := Mod(minutes, 100)
    mod10 := Mod(minutes, 10)

    if (mod100 >= 11 && mod100 <= 14)
        word := "минут"
    else if (mod10 = 1)
        word := "минута"
    else if (mod10 >= 2 && mod10 <= 4)
        word := "минуты"
    else
        word := "минут"

    return minutes . " " . word
}

MDSApplyTemplate(template, minutes := "", verb := "", ending := "") {
    text := ApplyActionTemplate(template)
    if (minutes != "")
        text := StrReplace(text, "{MINUTES}", FormatRussianMinutes(minutes))
    if (verb != "")
        text := StrReplace(text, "{VERB}", verb)
    if (ending != "")
        text := StrReplace(text, "{ENDING}", ending)
    return text
}

MDSFormationInitialText(minutes) {
    global MDS_FormationInitial
    return MDSApplyTemplate(MDS_FormationInitial, minutes)
}

MDSFormationCountdownText(minutes) {
    global MDS_FormationCountdown
    verb := (Mod(minutes, 10) = 1 && Mod(minutes, 100) != 11) ? "осталась" : "осталось"
    ending := (minutes <= 1) ? "Всем занять место в строю." : "Прошу занять место в строю."
    return MDSApplyTemplate(MDS_FormationCountdown, minutes, verb, ending)
}

MDSFormationFinishText() {
    global MDS_FormationFinish
    return MDSApplyTemplate(MDS_FormationFinish)
}

CloseEmptyChatAfterMDSInput(inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if (isInChat() = 1)
    {
        SafeSend("^a{Backspace}", "Input", inputEpoch)
        Sleep, 50
        SafeSend("{Esc}", "Input", inputEpoch)
        Sleep, 80
    }
}

ReadMDSFormationMinutes(inputEpoch := 0) {
    global MDSFormationMaxMinutes, MockMode
    inputEpoch := AutomationEpoch

    if (MockMode = "On")
    {
        InputBox, minutesText, MDS MockMode, Время построения в минутах (1-%MDSFormationMaxMinutes%):
        if (ErrorLevel)
            return 0
        minutesText := Trim(minutesText)
        if !RegExMatch(minutesText, "^\d{1,2}$")
        {
            SafeWarn("Время построения должно быть целым числом минут.")
            return 0
        }
        minutes := minutesText + 0
        if (minutes < 1 || minutes > MDSFormationMaxMinutes)
        {
            SafeWarn("Допустимое время построения: от 1 до " . MDSFormationMaxMinutes . " минут.")
            return 0
        }
        return minutes
    }

    if !EnsureGameActive()
        return 0

    chatState := isInChat()
    if (chatState = 1)
    {
        SafeSend("^a{Backspace}", "Input", inputEpoch)
        Sleep, 50
    }
    else
    {
        SafeSend("{F6}", "Input", inputEpoch)
        Sleep, 120
    }

    EnsureRussianLayout()
    PasteOnlyForEpoch(inputEpoch, "Время построения в минутах (1-" . MDSFormationMaxMinutes . "): ")
    Input, minutesText, I L2 V T20, {Enter}{Escape}
    inputResult := ErrorLevel
    CloseEmptyChatAfterMDSInput()

    if (inputResult = "Timeout" || inputResult = "EndKey:Escape")
    {
        SafeWarn("Ввод времени построения отменён.")
        return 0
    }

    minutesText := Trim(minutesText)
    if !RegExMatch(minutesText, "^\d{1,2}$")
    {
        SafeWarn("Время построения должно быть целым числом минут.")
        return 0
    }

    minutes := minutesText + 0
    if (minutes < 1 || minutes > MDSFormationMaxMinutes)
    {
        SafeWarn("Допустимое время построения: от 1 до " . MDSFormationMaxMinutes . " минут.")
        return 0
    }

    return minutes
}

StopMDSFormationCountdown(showStatus := 1) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    TaskScheduler_Cancel("MDSFormation")
    MDSFormationActive := 0
    MDSFormationEndTick := 0
    MDSFormationLastMinute := -1

    if (showStatus)
    {
        Notify("info")
        ToolTip, Строй остановлен.
        SetTimer, RemoveToolTip, -1600
    }
    UpdateHUD()
}

StartMDSFormationCountdown(minutes) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    StopMDSFormationCountdown(0)
    MDSFormationActive := 1
    MDSFormationEndTick := TickNow() + minutes * 60000
    MDSFormationLastMinute := minutes

    ChatQueue_Enqueue(MDSFormationInitialText(minutes), "MDSFormation")
    TaskScheduler_Set("MDSFormation", minutes * 60000, "MDSFormation", "Строй")
    Notify("info")
    ToolTip, % "Строй запущен на " . FormatRussianMinutes(minutes) . ". Повторный вызов остановит отсчёт."
    SetTimer, RemoveToolTip, -2200
    UpdateHUD()
}

HandleMDSFormationTimerTick(finishOnly := 0) {
    global MDSFormationActive, MDSFormationEndTick, MDSFormationLastMinute

    if (!MDSFormationActive)
        return

    millisecondsLeft := TaskScheduler_RemainingMs(MDSFormationEndTick)
    if (finishOnly || millisecondsLeft <= 0)
    {
        ChatQueue_Enqueue(MDSFormationFinishText(), "MDSFormation")
        StopMDSFormationCountdown(0)
        Notify("info")
        ToolTip, Время сбора в строй истекло.
        SetTimer, RemoveToolTip, -1800
        return
    }

    minutesLeft := Ceil(millisecondsLeft / 60000.0)
    if (minutesLeft >= MDSFormationLastMinute)
        return

    MDSFormationLastMinute := minutesLeft
    ChatQueue_Enqueue(MDSFormationCountdownText(minutesLeft), "MDSFormation")
}

ToggleMDSFormationCountdown() {
    global MDSFormationActive

    if (MDSFormationActive)
    {
        StopMDSFormationCountdown(1)
        return
    }

    minutes := ReadMDSFormationMinutes()
    if (minutes > 0)
        StartMDSFormationCountdown(minutes)
}

ResetRegisteredGameTextHotstrings() {
    global RegisteredGameTextHotstrings, GameTextHotkeyContext
    Hotkey, If, % GameTextHotkeyContext
    if IsObject(RegisteredGameTextHotstrings)
    {
        Loop % RegisteredGameTextHotstrings.Length()
        {
            pattern := RegisteredGameTextHotstrings[A_Index]
            if (pattern != "")
            {
                try
                    Hotstring(pattern, "", "Off")
            }
        }
    }
    RegisteredGameTextHotstrings := []
    Hotkey, If
}

TrackRegisteredGameTextHotstring(pattern) {
    global RegisteredGameTextHotstrings
    if (pattern = "")
        return
    if !IsObject(RegisteredGameTextHotstrings)
        RegisteredGameTextHotstrings := []
    RegisteredGameTextHotstrings.Push(pattern)
}

SuspendGameTextTriggersForBindMenu() {
    global RegisteredGameTextHotstrings, BindMenuTextTriggersSuspended, GameTextHotkeyContext
    if !IsObject(RegisteredGameTextHotstrings)
        return

    Hotkey, If, % GameTextHotkeyContext
    Loop % RegisteredGameTextHotstrings.Length()
    {
        pattern := RegisteredGameTextHotstrings[A_Index]
        if (pattern != "")
        {
            try
                Hotstring(pattern, "", "Off")
        }
    }
    Hotkey, If
    BindMenuTextTriggersSuspended := true
}

ResumeGameTextTriggersAfterBindMenu() {
    global BindMenuTextTriggersSuspended
    if (!BindMenuTextTriggersSuspended)
        return

    BindMenuTextTriggersSuspended := false
    ok := 1
    errText := ""
    ApplyTextTriggers(ok, errText)
}

GameTextTriggerAllowed(hotkeyName := "") {
    return IsGameActive() && (isInChat() = 1)
}

RegisterTextTrigger(triggerName, ByRef prevTrig, currentTrig, callbackName, ByRef errText, ByRef usedTriggers) {
    currentTrig := Trim(currentTrig)

    if (currentTrig = "ERROR")
        currentTrig := ""

    if (currentTrig != "" && SubStr(currentTrig, 1, 1) != "!")
        currentTrig := "!" . currentTrig

    if (prevTrig != "")
    {
        try
            Hotstring(":?:" . prevTrig, "", "Off")
    }

    if (currentTrig = "")
    {
        prevTrig := ""
        return true
    }

    keyId := currentTrig
    StringLower, keyId, keyId

    if (usedTriggers.HasKey(keyId))
    {
        errText .= triggerName . " = " . currentTrig . "  -> дубликат с """ . usedTriggers[keyId] . """`n"
        prevTrig := ""
        return false
    }

    try
    {
        cb := Func("RunTriggerLabel").Bind(callbackName)
        Hotstring(":?:" . currentTrig, cb, "On")
        TrackRegisteredGameTextHotstring(":?:" . currentTrig)
    }
    catch e
    {
        errText .= triggerName . " = " . currentTrig . "  -> неверный или неподдерживаемый текстовый бинд`n"
        prevTrig := ""
        return false
    }

    usedTriggers[keyId] := triggerName
    prevTrig := currentTrig
    return true
}

RegisterSearchModeTrigger(triggerName, ByRef prevTrig, triggerText, docCode, docName, ByRef errText, ByRef usedTriggers) {
    triggerText := Trim(triggerText)
    if (triggerText = "")
        return true
    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText

    if (prevTrig != "")
    {
        try
            Hotstring(":?:" . prevTrig, "", "Off")
    }

    keyId := triggerText
    StringLower, keyId, keyId
    if (usedTriggers.HasKey(keyId))
    {
        errText .= triggerName . " = " . triggerText . "  -> дубликат с " . usedTriggers[keyId] . "`n"
        prevTrig := ""
        return false
    }

    try
    {
        cb := Func("RunSearchModeTrigger").Bind(docCode, docName)
        Hotstring(":?:" . triggerText, cb, "On")
        TrackRegisteredGameTextHotstring(":?:" . triggerText)
    }
    catch e
    {
        errText .= triggerName . " = " . triggerText . "  -> неверная команда поиска`n"
        prevTrig := ""
        return false
    }

    usedTriggers[keyId] := triggerName
    prevTrig := triggerText
    return true
}

RegisterGpsInputTextTrigger(triggerName, ByRef prevTrig, currentTrig, actionName, downCount, ByRef errText, ByRef usedTriggers) {
    currentTrig := Trim(currentTrig)

    if (currentTrig = "ERROR")
        currentTrig := ""

    if (currentTrig != "" && SubStr(currentTrig, 1, 1) != "!")
        currentTrig := "!" . currentTrig

    if (prevTrig != "")
    {
        Loop, 10
        {
            digit := A_Index - 1
            try
                Hotstring(":?*B0:" . prevTrig . digit, "", "Off")
        }
    }

    if (currentTrig = "")
    {
        prevTrig := ""
        return true
    }

    Loop, 10
    {
        digit := A_Index - 1
        fullTrig := currentTrig . digit
        keyId := fullTrig
        StringLower, keyId, keyId
        if (usedTriggers.HasKey(keyId))
        {
            errText .= triggerName . " = " . fullTrig . "  -> duplicate trigger`n"
            prevTrig := ""
            return false
        }
    }

    try
    {
        Loop, 10
        {
            digit := A_Index - 1
            cb := Func("RunGpsInputTrigger").Bind(currentTrig, actionName, downCount, "" . digit)
            pattern := ":?*B0:" . currentTrig . digit
            if !Hotstring_AdmitPattern(pattern) {
                ok := false
                errText .= "Достигнут предел новых TXT-триггеров за сеанс (512).`n"
                continue
            }
            Hotstring(pattern, cb, "On")
            TrackRegisteredGameTextHotstring(pattern)
        }
    }
    catch e
    {
        errText .= triggerName . " = " . currentTrig . "  -> cannot register gps trigger`n"
        prevTrig := ""
        return false
    }

    Loop, 10
    {
        digit := A_Index - 1
        fullTrig := currentTrig . digit
        keyId := fullTrig
        StringLower, keyId, keyId
        usedTriggers[keyId] := triggerName
    }

    prevTrig := currentTrig
    return true
}

ReadGpsInputNumber(ByRef wasCancelled, ByRef endKey) {
    wasCancelled := false
    endKey := ""
    gpsNumber := ""
    Input, gpsNumber, V I L4, {Space}{Enter}{Escape}{Tab}
    gpsNumber := Trim(gpsNumber)

    endReason := ErrorLevel
    if (SubStr(endReason, 1, 7) = "EndKey:")
    {
        endKey := SubStr(endReason, 8)
        StringLower, endKey, endKey
        if (endKey != "space")
            wasCancelled := true
    }
    else if (endReason != "")
    {
        wasCancelled := true
    }

    return gpsNumber
}

EraseGpsTypedCommand(triggerText, gpsNumber, endKey := "space", inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    eraseCount := StrLen(triggerText) + StrLen(gpsNumber)
    if (endKey = "space")
        eraseCount += 1
    if (eraseCount <= 0)
        return
    Loop, %eraseCount%
    {
        SafeSend("{BS}", "Input", inputEpoch)
        Sleep, 10
    }
}

RunGpsInputTrigger(triggerText, actionName, downCount, firstDigit) {
    global BindMenuEditMode
    if (BindMenuEditMode)
    {
        BindMenuWarn()
        return ""
    }

    if !IsGameActive()
        return ""

    if (isInChat() != 1)
        return ""

    wasCancelled := false
    endKey := ""
    gpsTail := ReadGpsInputNumber(wasCancelled, endKey)
    gpsNumber := firstDigit . gpsTail

    if (endKey != "")
        EraseGpsTypedCommand(triggerText, gpsNumber, endKey)

    if (wasCancelled)
        return ""

    if (gpsNumber = "")
        return ""

    if !RegExMatch(gpsNumber, "^(\d+)$")
    {
        Notify("warn")
        return ""
    }

    RunGpsDialogAction(actionName, downCount, gpsNumber)
    return ""
}

WaitForChatQueueIdle(timeoutMs := 20000) {
    global ChatQueueBusy
    timeoutMs := Round(timeoutMs)
    if (timeoutMs < 1000)
        timeoutMs := 1000
    epoch := AutomationEpoch
    failures := QueueFailureGeneration
    started := TickNow()
    Loop
    {
        if (epoch != AutomationEpoch || QueueFailureGeneration != failures)
            return false
        if (ChatQueue_Count() <= 0 && !ChatQueueBusy)
            return true
        if (TickNow() - started >= timeoutMs)
            return false
        Sleep, 50
    }
}

SendRadialNumberTwice(number, delayMs := 300, pressGapMs := 0, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !RegExMatch(number . "", "^\d$")
        return false
    key := "{" . number . "}"
    SafeSend(key, "Input", inputEpoch)
    pressGapMs := Round(pressGapMs)
    if (pressGapMs > 0)
        Sleep, %pressGapMs%
    SafeSend(key, "Input", inputEpoch)
    Sleep, %delayMs%
    return true
}

SendListSelection(position, stepDelayMs := 35, afterDelayMs := 220, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    position := Round(position)
    if (position < 1)
        return false
    downCount := position - 1
    if (downCount > 0)
    {
        Loop, %downCount%
        {
            SafeSend("{Down}", "Event", inputEpoch)
            Sleep, %stepDelayMs%
        }
    }
    SafeSend("{Enter}", "Event", inputEpoch)
    Sleep, %afterDelayMs%
    return true
}

EnsureEnglishLayout() {
    return SafeLayout(0x4090409)
}

ChatWizard_Begin(modeName, inputEpoch := 0) {
    global ChatWizardMode, BindMenuEditMode
    inputEpoch := AutomationEpoch
    if (ChatWizardMode != "") {
        GameNotify("Уже включён режим ввода: " . ChatWizardMode . ". Нажмите Esc для отмены.", "WARN")
        return false
    }
    if (BindMenuEditMode) {
        BindMenuWarn()
        return false
    }
    if !IsGameActive()
        return false
    if (isInChat() != 1) {
        SafeSend("{F6}", "Input", inputEpoch)
        Sleep, 120
    }
    if (isInChat() != 1) {
        GameNotify("Не удалось открыть игровой чат.", "ERROR")
        return false
    }
    ChatWizardMode := modeName
    ClearBindMenuChatLine(true)
    return true
}

ChatWizard_ReadToken(ByRef cancelled, maxLength := 40, timeoutSeconds := 90) {
    cancelled := false
    maxLength := Round(maxLength)
    timeoutSeconds := Round(timeoutSeconds)
    if (maxLength < 1)
        maxLength := 1
    else if (maxLength > 80)
        maxLength := 80
    if (timeoutSeconds < 10)
        timeoutSeconds := 10
    else if (timeoutSeconds > 180)
        timeoutSeconds := 180

    options := "V I L" . maxLength . " T" . timeoutSeconds
    Input, typedText, %options%, {Space}{Enter}{Escape}
    inputResult := ErrorLevel
    endKey := ""
    if (SubStr(inputResult, 1, 7) = "EndKey:") {
        endKey := SubStr(inputResult, 8)
        StringLower, endKey, endKey
    }

    if (isInChat() = 1)
        ClearBindMenuChatLine(true)

    if (endKey != "space") {
        cancelled := true
        return ""
    }
    return Trim(typedText)
}

ChatWizard_NormalizeToken(rawText) {
    text := Trim(rawText)
    while (SubStr(text, 1, 1) = "!")
        text := Trim(SubStr(text, 2))
    StringLower, text, text
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

ChatWizard_Finish(closeChat := true, inputEpoch := 0) {
    global ChatWizardMode
    inputEpoch := AutomationEpoch
    Input
    if (isInChat() = 1) {
        ClearBindMenuChatLine(true)
        if (closeChat) {
            SafeSend("{Enter}", "Input", inputEpoch)
            Sleep, 100
        }
    }
    ChatWizardMode := ""
}

ChatWizard_Cancel(message := "") {
    if (message != "")
        GameNotify(message, "WARN")
    ChatWizard_Finish(false)
    return false
}

VehicleLookup_ResolveCountry(rawText, ByRef countryIndex, ByRef countryName) {
    token := ChatWizard_NormalizeToken(rawText)
    token := StrReplace(token, ".", "")
    token := StrReplace(token, "-", " ")
    token := RegExReplace(token, "\s+", " ")
    countryIndex := 0
    countryName := ""

    if RegExMatch(token, "^\d$", match) {
        number := match + 0
        if (number >= 1 && number <= 8)
            countryIndex := number
    } else if (token = "россия" || token = "рф" || token = "российская федерация") {
        countryIndex := 1
    } else if (token = "беларусь" || token = "республика беларусь" || token = "белоруссия") {
        countryIndex := 2
    } else if (token = "армения" || token = "республика армения") {
        countryIndex := 3
    } else if (token = "казахстан" || token = "республика казахстан") {
        countryIndex := 4
    } else if (token = "украина") {
        countryIndex := 5
    } else if (token = "азербайджан" || token = "азербайджанская республика") {
        countryIndex := 6
    } else if (token = "грузия") {
        countryIndex := 7
    } else if (token = "евросоюз" || token = "ес" || token = "европейский союз") {
        countryIndex := 8
    }

    names := ["Российская Федерация", "Республика Беларусь", "Республика Армения"
        , "Республика Казахстан", "Украина", "Азербайджанская Республика"
        , "Грузия", "Европейский союз"]
    if (countryIndex < 1 || countryIndex > names.Length())
        return false
    countryName := names[countryIndex]
    return true
}

VehicleLookup_ResolveRegion(rawText, ByRef regionIndex, ByRef regionCode) {
    token := ChatWizard_NormalizeToken(rawText)
    token := RegExReplace(token, "i)^(регион|region)\s*")
    token := Trim(token)
    regionIndex := 0
    regionCode := ""
    if !RegExMatch(token, "^(\d{1,2})$", match)
        return false
    regionIndex := match1 + 0
    if (regionIndex < 1 || regionIndex > 99)
        return false
    regionCode := Format("{:02}", regionIndex)
    return true
}

VehicleLookup_NormalizePlate(rawText) {
    plate := ChatWizard_NormalizeToken(rawText)
    plate := StrReplace(plate, " ", "")
    plate := StrReplace(plate, "-", "")
    StringUpper, plate, plate
    cyrillic := ["А", "В", "Е", "К", "М", "Н", "О", "Р", "С", "Т", "У", "Х"]
    latin := ["A", "B", "E", "K", "M", "H", "O", "P", "C", "T", "Y", "X"]
    Loop % cyrillic.Length()
        plate := StrReplace(plate, cyrillic[A_Index], latin[A_Index])
    return plate
}

VehicleLookup_GetRegionListPosition(countryIndex, regionIndex) {
    countryIndex += 0
    regionIndex += 0
    if (countryIndex = 1) {
        if (regionIndex = 20)
            return 0
        if (regionIndex > 20)
            return regionIndex - 1
    }
    return regionIndex
}

VehicleLookup_RunWizard() {
    if !ChatWizard_Begin("поиск ТС")
        return false

    GameNotify("Поиск ТС включён. Введите страну, например !россия, и нажмите пробел.", "INFO")
    Loop
    {
        rawCountry := ChatWizard_ReadToken(cancelled, 32, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        if VehicleLookup_ResolveCountry(rawCountry, countryIndex, countryName)
            break
        GameNotify("Страна не распознана. Пример: !россия, !беларусь или !1.", "WARN")
    }
    GameNotify("Выбрана страна: " . countryName . ". Введите код региона, например !05.", "INFO")

    Loop
    {
        rawRegion := ChatWizard_ReadToken(cancelled, 12, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        if (VehicleLookup_ResolveRegion(rawRegion, regionIndex, regionCode)
            && VehicleLookup_GetRegionListPosition(countryIndex, regionIndex) > 0)
            break
        if (countryIndex = 1 && regionIndex = 20) {
            GameNotify("Код региона 20 отсутствует в списке РФ. Укажите действующий код.", "WARN")
            continue
        }
        GameNotify("Регион не распознан. Введите номер позиции, например !05.", "WARN")
    }
    GameNotify("Выбран регион: " . regionCode . ". Введите номер ТС в формате A123AA.", "INFO")

    EnsureEnglishLayout()
    Loop
    {
        rawPlate := ChatWizard_ReadToken(cancelled, 16, 120)
        if (cancelled)
            return ChatWizard_Cancel("Поиск ТС отменён.")
        plate := VehicleLookup_NormalizePlate(rawPlate)
        if RegExMatch(plate, "^[A-Z]\d{3}[A-Z]{2}$")
            break
        GameNotify("Неверный номер. Используйте формат A123AA без кода региона.", "WARN")
    }

    GameNotify("Поиск: " . countryName . ", регион " . regionCode . ", номер " . plate . ".", "INFO")
    ChatWizard_Finish(true)
    return VehicleLookup_Execute(countryIndex, regionIndex, plate)
}

VehicleLookup_Execute(countryIndex, regionIndex, plate, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !CanRunAction("поиск ТС по номеру", false, true)
        return false
    if (SendChatForEpoch(inputEpoch, "/frac") != 1)
        return
    Sleep, 320
    SendRadialNumberTwice(1, 280)
    SendRadialNumberTwice(3, 280)
    SendRadialNumberTwice(6, 320)
    SendListSelection(countryIndex, 45, 250)
    regionListPosition := VehicleLookup_GetRegionListPosition(countryIndex, regionIndex)
    if (regionListPosition < 1) {
        GameNotify("Выбранный регион отсутствует в игровом списке.", "ERROR")
        return false
    }
    SendListSelection(regionListPosition, 35, 280)
    EnsureEnglishLayout()
    if !PasteOnlyForEpoch(inputEpoch, plate)
        return false
    Sleep, 80
    SafeSend("{Enter}", "Event", inputEpoch)
    Sleep, 80
    EnsureRussianLayout()
    return true
}

WantedRemoval_GetReason(reasonNumber, ByRef reasonText) {
    reasons := {}
    reasons[1] := "ошибка КПК"
    reasons[2] := "явка с повинной"
    reasons[3] := "самооборона"
    reasons[4] := "менее 5 лет проживания в области"
    reasons[5] := "признание вины, незначительное нарушение"
    reasonNumber += 0
    if !reasons.HasKey(reasonNumber)
        return false
    reasonText := reasons[reasonNumber]
    return true
}

WantedRemoval_GetDepartmentTag() {
    global ProfileMode
    if (ProfileMode = "ГАИ" || ProfileMode = "ДПС")
        return "ГАИ"
    if (ProfileMode = "ФСБ")
        return "УФСБ"
    if (ProfileMode = "ВЧ" || ProfileMode = "Военная полиция")
        return "ВЧ"
    return "УМВД"
}

WantedRemoval_RunWizard() {
    if !ChatWizard_Begin("снятие розыска")
        return false

    GameNotify("Снятие розыска включено. Введите жетон игрока, например !321, и нажмите пробел.", "INFO")
    Loop
    {
        rawTarget := ChatWizard_ReadToken(cancelled, 16, 120)
        if (cancelled)
            return ChatWizard_Cancel("Снятие розыска отменено.")
        targetToken := ChatWizard_NormalizeToken(rawTarget)
        targetToken := RegExReplace(targetToken, "i)^id")
        if RegExMatch(targetToken, "^(\d{1,4})$", targetMatch) {
            targetId := targetMatch1 + 0
            break
        }
        GameNotify("Жетон не распознан. Введите, например, !321.", "WARN")
    }

    GameNotify("Основания: !1 ошибка КПК; !2 явка с повинной; !3 самооборона; !4 менее 5 лет; !5 признание вины.", "INFO")
    Loop
    {
        rawReason := ChatWizard_ReadToken(cancelled, 8, 120)
        if (cancelled)
            return ChatWizard_Cancel("Снятие розыска отменено.")
        reasonToken := ChatWizard_NormalizeToken(rawReason)
        if (RegExMatch(reasonToken, "^[1-5]$") && WantedRemoval_GetReason(reasonToken + 0, reasonText)) {
            reasonNumber := reasonToken + 0
            break
        }
        GameNotify("Выберите основание от !1 до !5.", "WARN")
    }

    GameNotify("Выбрано: жетон " . targetId . ", п." . reasonNumber . " — " . reasonText . ".", "INFO")
    ChatWizard_Finish(true)
    return WantedRemoval_Execute(targetId, reasonNumber)
}

WantedRemoval_Execute(targetId, reasonNumber, inputEpoch := 0) {
    global ReportRank, Surname
    inputEpoch := AutomationEpoch
    if !CanRunAction("снятие розыска", false, true)
        return false
    departmentTag := WantedRemoval_GetDepartmentTag()
    report := "/d [" . departmentTag . "] Говорит " . ReportRank . " полиции " . Surname
        . ",выношу из базы розыска жетон " . targetId
        . ",на основании ФЗоП гл.3 ст.7 ч.1 п." . reasonNumber
    sendResult := SendChatForEpoch(inputEpoch, report, "WantedRemovalReport")
    if (sendResult != 1) {
        GameNotify("Доклад о снятии розыска не отправлен. Действие отменено.", "ERROR")
        return false
    }
    Sleep, 700
    if (SendChatForEpoch(inputEpoch, "/frac") != 1)
        return
    Sleep, 320
    SendRadialNumberTwice(1, 280)
    SendRadialNumberTwice(4, 280)
    SendRadialNumberTwice(2, 320)
    if !PasteOnlyForEpoch(inputEpoch, targetId . "")
        return false
    Sleep, 80
    SafeSend("{Enter}", "Event", inputEpoch)
    return true
}

Fine_ParseArticle(rawText, ByRef article, ByRef chapterPosition, ByRef itemPosition, ByRef errorText) {
    text := ChatWizard_NormalizeToken(rawText)
    text := StrReplace(text, "коап", "")
    text := RegExReplace(text, "i)^(статья|ст\.?)\s*")
    text := StrReplace(text, " ", "")
    article := ""
    chapterPosition := 0
    itemPosition := 0
    errorText := ""

    if !RegExMatch(text, "^(\d{1,2})\.(\d{1,2})$", match) {
        errorText := "Введите статью КоАП с точкой, например !20.6."
        return false
    }
    chapter := match1 + 0
    item := match2 + 0
    counts := {1:2, 2:3, 3:4, 5:2, 6:1, 7:2, 8:5, 9:4, 10:3, 11:4
        , 12:2, 13:6, 14:5, 15:3, 16:4, 17:5, 18:6, 19:2, 20:7, 21:2}

    if (chapter = 2 && (item = 4 || item = 5)) {
        errorText := "Статьи 2.4 и 2.5 КоАП упразднены."
        return false
    }
    if (chapter = 4) {
        errorText := "Статьи главы 4 КоАП упразднены."
        return false
    }
    if !counts.HasKey(chapter) {
        errorText := "Такая глава не используется для выписывания штрафа."
        return false
    }
    if (item < 1 || item > counts[chapter]) {
        errorText := "Статья " . chapter . "." . item . " отсутствует в выбранной главе КоАП."
        return false
    }

    article := chapter . "." . item
    chapterPosition := chapter
    itemPosition := item
    return true
}

Fine_RunWizard() {
    if !ChatWizard_Begin("выбор статьи КоАП")
        return false
    GameNotify("Режим штрафа включён. Введите статью КоАП, например !20.6, и нажмите пробел.", "INFO")
    Loop
    {
        rawArticle := ChatWizard_ReadToken(cancelled, 24, 120)
        if (cancelled)
            return ChatWizard_Cancel("Оформление штрафа отменено.")
        if Fine_ParseArticle(rawArticle, article, chapterPosition, itemPosition, parseError)
            break
        GameNotify(parseError, "WARN")
    }
    GameNotify("КоАП ст. " . article . ": глава " . chapterPosition . ", позиция " . itemPosition . ".", "INFO")
    ChatWizard_Finish(true)
    return Fine_ExecuteArticle(article, chapterPosition, itemPosition)
}

Fine_ExecuteArticle(article, chapterPosition, itemPosition, inputEpoch := 0) {
    global RP_Fine, UserID
    inputEpoch := AutomationEpoch
    if !CanRunAction("штраф КоАП " . article, true)
        return false
    Evidence_Arm("FINE", 60000)
    SplitConfigSequenceMiddle(RP_Fine, rpBefore, rpAfter)
    if (rpBefore != "") {
        SendConfigSequence(rpBefore, 700)
        if !WaitForChatQueueIdle(20000) {
            GameNotify("Не удалось дождаться RP-подготовки штрафа.", "ERROR")
            return false
        }
        Sleep, 900
    }
    sendResult := SendChatForEpoch(inputEpoch, "/frac " . UserID, "Fine.OpenMenu")
    if (sendResult != 1) {
        GameNotify("Не удалось открыть /frac " . UserID . ". Оформление штрафа отменено.", "ERROR")
        return false
    }
    Sleep, 800
    SendRadialNumberTwice(1, 480, 110)
    SendRadialNumberTwice(6, 480, 110)
    SendRadialNumberTwice(1, 550, 110)
    SafeSend("{Enter}", "Event", inputEpoch)
    Sleep, 450
    SendListSelection(chapterPosition, 45, 350)
    SendListSelection(itemPosition, 45, 450)
    if (rpAfter != "")
        SendConfigSequence(rpAfter, 700)
    return true
}

BindMenuWarn(msg := "") {
    if (msg = "")
        msg := "Меню биндов открыто. Используй !меню для закрытия."
    Notify("warn")
    ToolTip, %msg%
    SetTimer, RemoveToolTip, -1600
    return false
}

BindMenuHotkeyBlockedWarn() {
    static lastWarnTick := 0
    nowTick := TickNow()
    if (lastWarnTick > 0 && nowTick - lastWarnTick < 1200)
        return
    lastWarnTick := nowTick
    Notify("warn")
    ToolTip, Меню биндов открыто. Закрой !меню перед действием.
    SetTimer, RemoveToolTip, -1400
}

ClearBindMenuChatLine(force := false, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !IsGameActive()
        return
    if (!force && isInChat() != 1)
        return

    SafeSend("{Alt up}", "Input", inputEpoch)
    Sleep, 20
    SafeSend("^a", "Input", inputEpoch)
    Sleep, 30
    SafeSend("{Backspace}", "Input", inputEpoch)
    Sleep, 30
}

NormalizeBindMenuHotkeyText(rawText) {
    rawText := Trim(rawText)
    if (rawText = "")
        return ""

    lowered := rawText
    StringLower, lowered, lowered
    lowered := RegExReplace(lowered, "\s+")

    if (lowered = "off" || lowered = "none" || lowered = "clear" || lowered = "пусто" || lowered = "нет" || lowered = "-")
        return ""

    if RegExMatch(rawText, "^[!^+#].+")
        return rawText

    parts := StrSplit(lowered, "+")
    mods := ""
    key := ""
    Loop % parts.Length()
    {
        part := parts[A_Index]
        if (part = "alt")
            mods .= "!"
        else if (part = "ctrl" || part = "control")
            mods .= "^"
        else if (part = "shift")
            mods .= "+"
        else if (part = "win" || part = "windows")
            mods .= "#"
        else
            key := part
    }

    if (key = "")
        return rawText

    if RegExMatch(key, "^f\d+$")
        StringUpper, key, key
    return mods . key
}

NormalizeBindMenuAliasText(aliasText) {
    aliasText := Trim(aliasText)
    if (aliasText = "")
        return ""
    StringLower, aliasText, aliasText
    aliasText := RegExReplace(aliasText, "\s+")
    if (SubStr(aliasText, 1, 1) != "!")
        aliasText := "!" . aliasText
    return aliasText
}

NormalizeBindMenuFixedName(name) {
    name := Trim(name)
    if (SubStr(name, 1, 1) = "!")
        name := SubStr(name, 2)
    StringLower, name, name
    name := RegExReplace(name, "\s+")
    return name
}

GetBindMenuFixedName(meta) {
    static fixedNameMap := ""
    if !IsObject(meta)
        return ""

    if !IsObject(fixedNameMap)
    {
        fixedNameMap := {}
        fixedNameMap["OpenSettings"] := "settings"
        fixedNameMap["ToggleBindList"] := "bindlist"
        fixedNameMap["ToggleLastLawDoc"] := "lastdoc"
        fixedNameMap["HideLawGui"] := "hidelaw"
        fixedNameMap["ToggleHUD"] := "hud"
        fixedNameMap["IDOverlay"] := "idoverlay"
        fixedNameMap["EnterID"] := "id"
        fixedNameMap["ResetID"] := "resetid"
        fixedNameMap["Intro"] := "intro"
        fixedNameMap["SOS"] := "sos"
        fixedNameMap["Chase"] := "chase"
        fixedNameMap["Deject"] := "deject"
        fixedNameMap["Cuff"] := "cuff"
        fixedNameMap["InCar"] := "incar"
        fixedNameMap["StopChase"] := "stop"
        fixedNameMap["Doc"] := "doc"
        fixedNameMap["Search"] := "search"
        fixedNameMap["Dep"] := "dep"
        fixedNameMap["WantedList"] := "wanted"
        fixedNameMap["SOSStart"] := "sosstart"
        fixedNameMap["SOSArrive"] := "sosarrive"
        fixedNameMap["HijackStart"] := "hijackstart"
        fixedNameMap["HijackArrive"] := "hijackarrive"
        fixedNameMap["CallStart"] := "callstart"
        fixedNameMap["CallArrive"] := "callarrive"
        fixedNameMap["CallWorkStart"] := "callworkstart"
        fixedNameMap["CallWorkEnd"] := "callworkend"
        fixedNameMap["PatrolStart"] := "patrolstart"
        fixedNameMap["PatrolCont"] := "patrolcont"
        fixedNameMap["PatrolEnd"] := "patrolend"
        fixedNameMap["PostStart"] := "poststart"
        fixedNameMap["PostCont"] := "postcont"
        fixedNameMap["PostEnd"] := "postend"
        fixedNameMap["AutoPatrol"] := "апатруль"
        fixedNameMap["AutoPost"] := "апост"
        fixedNameMap["ConvoyStart"] := "convoystart"
        fixedNameMap["ConvoyCont"] := "convoycont"
        fixedNameMap["ConvoyEnd"] := "convoyend"
        fixedNameMap["TowStart"] := "towstart"
        fixedNameMap["TowEnd"] := "towend"
        fixedNameMap["CarSearch"] := "carsearch"
        fixedNameMap["Arrest"] := "arrest"
        fixedNameMap["Fine"] := "fine"
        fixedNameMap["Protocol"] := "protocol"
        fixedNameMap["Rights"] := "rights"
        fixedNameMap["CardDS"] := "cardds"
        fixedNameMap["CardVK"] := "cardvk"
    }

    if (fixedNameMap.HasKey(meta.Token))
        return fixedNameMap[meta.Token]

    name := meta.Token
    StringLower, name, name
    return RegExReplace(name, "[^a-z0-9_]")
}

GetBindMenuMetaByFixedName(fixedName) {
    fixedName := NormalizeBindMenuFixedName(fixedName)
    if (fixedName = "")
        return ""

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsUserVisible(meta)
            continue
        if (meta.HotkeyVar = "" && meta.TriggerVar = "")
            continue
        if (NormalizeBindMenuFixedName(GetBindMenuFixedName(meta)) = fixedName)
            return meta

        aliases := BuildBindMenuAliasList(meta)
        Loop % aliases.Length()
        {
            aliasName := NormalizeBindMenuFixedName(aliases[A_Index])
            if (aliasName != "" && aliasName = fixedName)
                return meta
        }
    }
    return ""
}

GetActiveTextTriggerSet() {
    used := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.TriggerVar = "")
            continue
        triggerValue := NormalizeBindMenuAliasText(GetDynamicGlobalValue(meta.TriggerVar))
        if (triggerValue != "")
            used[triggerValue] := meta.TriggerVar
    }
    used["!меню"] := "BindMenu"
    used["!пвсе"] := "Search_ALL"
    used["!пкоап"] := "Search_KOAP"
    used["!пук"] := "Search_UK"
    used["!пупк"] := "Search_UPK"
    used["!ппдд"] := "Search_PDD"
    used["!пфзоп"] := "Search_FZOP"
    used["!птк"] := "Search_TK"
    used["!птер"] := "Search_TER"
    used["!парг"] := "Search_ARG"
    used["!пву"] := "Search_VU"
    used["!пвв"] := "Search_VV"
    used["!поружие"] := "Search_ORUZH"
    used["!пкон"] := "Search_KON"
    used["!пнайти"] := "Search_RUN"
    global CustomFunctions
    if IsObject(CustomFunctions)
    {
        Loop % CustomFunctions.Length()
        {
            fn := CustomFunctions[A_Index]
            trig := NormalizeCustomFunctionTrigger(fn.Trigger)
            if (trig != "")
                used[trig] := "Пользовательская функция: " . fn.Name
        }
    }
    return used
}

GetBindMenuTriggerOwnerLabel(owner) {
    if (owner = "")
        return ""

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        other := catalog[A_Index]
        if (other.TriggerVar = owner)
        {
            if (other.Label != "")
                return other.Label
            return other.Token
        }
    }

    static ownerLabels := ""
    if !IsObject(ownerLabels)
    {
        ownerLabels := {}
        ownerLabels["BindMenu"] := "Меню биндов"
        ownerLabels["VehicleLookup"] := "Поиск ТС по номеру"
        ownerLabels["WantedRemoval"] := "Снятие розыска"
        ownerLabels["Search_ALL"] := "Поиск: все материалы"
        ownerLabels["Search_KOAP"] := "Поиск: КоАП"
        ownerLabels["Search_UK"] := "Поиск: УК"
        ownerLabels["Search_UPK"] := "Поиск: УПК"
        ownerLabels["Search_PDD"] := "Поиск: ПДД"
        ownerLabels["Search_FZOP"] := "Поиск: ФЗОП"
        ownerLabels["Search_TK"] := "Поиск: ТК"
        ownerLabels["Search_TER"] := "Поиск: Территории"
        ownerLabels["Search_ARG"] := "Поиск: АРГ"
        ownerLabels["Search_VU"] := "Поиск: ВУ"
        ownerLabels["Search_VV"] := "Поиск: Вертикаль власти"
        ownerLabels["Search_ORUZH"] := "Поиск: Оружие"
        ownerLabels["Search_KON"] := "Поиск: Конституция"
        ownerLabels["Search_RUN"] := "Поиск по законам"
    }

    if (ownerLabels.HasKey(owner))
        return ownerLabels[owner]
    return owner
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

GetBindMenuDisplayCommand(meta) {
    if !IsObject(meta)
        return "-"
    if (meta.HotkeyVar = "" && meta.TriggerVar = "")
        return "-"

    fixedName := GetBindMenuFixedName(meta)
    if (fixedName = "")
        return "-"
    return "!" . fixedName
}

ValidateBindMenuHotkey(meta, hotkeyText, oldHotkey, ByRef errMsg) {
    errMsg := ""
    if (hotkeyText = "")
        return true

    newKeyId := NormalizeHotkeyId(hotkeyText)
    if (newKeyId = "")
    {
        errMsg := "Некорректный hotkey: " . hotkeyText
        return false
    }

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        other := catalog[A_Index]
        if !BindCatalog_IsRegistrable(other)
            continue
        if (other.HotkeyVar = "" || other.HotkeyVar = meta.HotkeyVar)
            continue
        otherValue := GetDynamicGlobalValue(other.HotkeyVar)
        NormalizeBindValue(otherValue)
        otherKeyId := NormalizeHotkeyId(otherValue)
        if (otherKeyId != "" && otherKeyId = newKeyId)
        {
            ownerLabel := other.Label
            if (ownerLabel = "")
                ownerLabel := other.Token
            errMsg := "Hotkey уже занят: " . hotkeyText . " -> " . ownerLabel
            return false
        }
    }
    return true
}

NormalizeBindMenuTriggerText(rawText) {
    triggerText := Trim(rawText)
    if (triggerText = "")
        return ""
    triggerText := RegExReplace(triggerText, "\s+")
    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText
    return triggerText
}

ValidateBindMenuTrigger(meta, triggerText, ByRef errMsg) {
    errMsg := ""
    if (triggerText = "")
    {
        errMsg := "Некорректный TXT-trigger: " . triggerText
        return false
    }

    checkText := triggerText
    StringLower, checkText, checkText
    if (checkText = "!меню" || checkText = "!menu")
    {
        errMsg := "TXT-trigger зарезервирован: " . triggerText
        return false
    }

    used := GetActiveTextTriggerSet()
    if (used.HasKey(checkText) && used[checkText] != meta.TriggerVar)
    {
        owner := used[checkText]
        ownerLabel := GetBindMenuTriggerOwnerLabel(owner)
        if (ownerLabel = "")
            ownerLabel := owner
        errMsg := "Триггер уже занят: " . triggerText . " -> " . ownerLabel
        return false
    }
    return true
}

ApplyBindMenuTrigger(meta, triggerText) {
    global CurrentProfile, SettingsVisible, BindListVisible, BindOverlayVisible, BindMenuVisible
    if (meta.TriggerVar = "")
        return BindMenuWarn("Для этой команды нет TXT-триггера.")

    triggerText := NormalizeBindMenuTriggerText(triggerText)
    errMsg := ""
    if !ValidateBindMenuTrigger(meta, triggerText, errMsg)
    {
        if (errMsg = "")
            errMsg := "Некорректный TXT-trigger: " . triggerText
        return BindMenuWarn(errMsg)
    }

    SetDynamicGlobalValue(meta.TriggerVar, triggerText)
    cfgVar := "CFG_" . meta.TriggerVar
    SetDynamicGlobalValue(cfgVar, triggerText)
    if (SettingsVisible)
        GuiControl, 2:, %cfgVar%, %triggerText%

    ApplyAllBinds()
    if !SaveProfile(CurrentProfile)
        return
    SaveUISettings()
    if (BindListVisible)
        UpdateBindList()
    if (BindOverlayVisible)
        ShowBindOverlay()
    if (BindMenuVisible)
        ShowChatBindMenu()

    Notify("info")
    ToolTip, % "TXT updated: " . meta.Label . " = " . triggerText
    SetTimer, RemoveToolTip, -1600
    return true
}

GetBindMenuCommandMode(ByRef argText) {
    rawText := Trim(argText)
    lowered := rawText
    StringLower, lowered, lowered

    if RegExMatch(lowered, "^(hk|hotkey|bind)\s+(.+)$", m)
    {
        argText := Trim(m2)
        return "HK"
    }
    if RegExMatch(lowered, "^(txt|text|trig|trigger)\s+(.+)$", m)
    {
        argText := Trim(m2)
        return "TRIG"
    }

    argText := rawText
    if (SubStr(rawText, 1, 1) = "!")
        return "TRIG"
    return "HK"
}

ApplyBindMenuHotkey(meta, hotkeyText) {
    global CurrentProfile, SettingsVisible, BindListVisible, BindOverlayVisible, BindMenuVisible
    oldHotkey := GetDynamicGlobalValue(meta.HotkeyVar)
    errMsg := ""
    if !ValidateBindMenuHotkey(meta, hotkeyText, oldHotkey, errMsg)
    {
        if (errMsg = "")
            errMsg := "Некорректный hotkey: " . hotkeyText
        return BindMenuWarn(errMsg)
    }

    SetDynamicGlobalValue(meta.HotkeyVar, hotkeyText)
    cfgVar := "CFG_" . meta.HotkeyVar
    SetDynamicGlobalValue(cfgVar, hotkeyText)
    if (SettingsVisible)
        GuiControl, 2:, %cfgVar%, %hotkeyText%

    ApplyAllBinds()
    if !SaveProfile(CurrentProfile)
        return
    SaveUISettings()
    if (BindListVisible)
        UpdateBindList()
    if (BindOverlayVisible)
        ShowBindOverlay()
    if (BindMenuVisible)
    {
        SuspendGameTextTriggersForBindMenu()
        ShowChatBindMenu()
    }

    Notify("info")
    ToolTip, % "Бинд обновлен: " . meta.Label . " = " . hotkeyText
    SetTimer, RemoveToolTip, -1600
    return true
}

TryHandleBindMenuLine(lineText) {
    global BindMenuEditMode
    if (!BindMenuEditMode)
        return false

    normalized := Trim(lineText)
    if (normalized = "")
        return false
    lineText := normalized

    lowered := normalized
    StringLower, lowered, lowered
    if (lowered = "!меню" || lowered = "!menu")
    {
        ClearBindMenuChatLine()
        ForceCloseBindMenuEditMode("Меню биндов закрыто.")
        return true
    }

    firstChar := SubStr(lineText, 1, 1)
    if (firstChar != "!")
        return false

    splitAt := RegExMatch(lineText, "\s")
    if (splitAt > 0)
    {
        firstWord := SubStr(lineText, 1, splitAt - 1)
        commandArg := Trim(SubStr(lineText, splitAt + 1))
    }
    else
    {
        firstWord := lineText
        commandArg := ""
    }

    fixedName := NormalizeBindMenuFixedName(firstWord)
    meta := GetBindMenuMetaByFixedName(fixedName)
    if !IsObject(meta)
    {
        ClearBindMenuChatLine()
        BindMenuWarn("Command not found. Use a name from !menu.")
        return true
    }

    if (commandArg = "")
    {
        ClearBindMenuChatLine()
        BindMenuWarn("Use bind or TXT: !" . GetBindMenuFixedName(meta) . " alt+r")
        return true
    }

    commandMode := GetBindMenuCommandMode(commandArg)
    ClearBindMenuChatLine()
    if (commandMode = "TRIG")
        ApplyBindMenuTrigger(meta, commandArg)
    else
    {
        hotkeyText := NormalizeBindMenuHotkeyText(commandArg)
        if (meta.HotkeyVar = "")
            BindMenuWarn("No HK bind for this command.")
        else
            ApplyBindMenuHotkey(meta, hotkeyText)
    }
    return true
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

ForceCloseBindMenuEditMode(reason := "") {
    global BindMenuVisible, BindMenuEditMode, hBindMenuWnd
    Gui, 19:Destroy
    hBindMenuWnd := 0
    BindMenuVisible := false
    BindMenuEditMode := false
    ResumeGameTextTriggersAfterBindMenu()
    ApplyAllBinds()
    if (reason != "")
    {
        Notify("info")
        ToolTip, %reason%
        SetTimer, RemoveToolTip, -1200
    }
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

    AddOutlinedPanel(19, 10, 10, overlayW - 20, overlayH - 20, cardBg, accent, 2)

    Gui, 19:Font, s14 Bold c%text%, Segoe UI
    Gui, 19:Add, Text, % "x" contentX " y" headerY " w" contentW " h26 Center BackgroundTrans +0x200 +0x4000", Меню биндов
    Gui, 19:Font, Norm s8 c%muted%, Segoe UI
    Gui, 19:Add, Text, % "x" contentX " y" helpY " w" contentW " h16 Center BackgroundTrans +0x200 +0x4000", Закрыть: напиши !меню и нажми Alt+F
    Gui, 19:Add, Text, % "x" contentX " y" formatY " w" contentW " h16 Center BackgroundTrans +0x200 +0x4000", Format: !name hotkey or !name !trigger
    Gui, 19:Add, Text, % "x" contentX " y" examplesY " w" contentW " h16 Center BackgroundTrans +0x200 +0x4000", Examples: !wanted alt+r | !dep !департамент | !cuff ctrl+f8
    Gui, 19:Add, Progress, % "-Theme " . "x" contentX " y108 w" contentW " h2 Disabled Background" cardBg " c" accent, 100

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
        Gui, 19:Font, s7 Bold c%accent%, Segoe UI
        Gui, 19:Add, Text, % "x" colX " y" tableHeaderY " w" nameW " h16 +0x200 +0x4000 BackgroundTrans", Функция
        Gui, 19:Add, Text, % "x" cmdX " y" tableHeaderY " w" cmdW " h16 +0x200 +0x4000 BackgroundTrans", Имя
        Gui, 19:Add, Text, % "x" hkX " y" tableHeaderY " w" hkW " h16 +0x200 +0x4000 BackgroundTrans", HK
        Gui, 19:Add, Text, % "x" trigX " y" tableHeaderY " w" trigW " h16 +0x200 +0x4000 BackgroundTrans", TXT
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
            Gui, 19:Font, s7 Bold c%accent%, Segoe UI
            Gui, 19:Add, Text, % "x" x " y" y " w" colW " h" categoryH " +0x200 +0x4000 BackgroundTrans", % row.Category
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

        Gui, 19:Font, Norm s7 c%text%, Segoe UI
        Gui, 19:Add, Text, % "x" x " y" y " w" nameW " h" rowH " +0x200 +0x4000 BackgroundTrans", % row.Label
        Gui, 19:Font, Norm s7 c%muted%, Segoe UI
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
    ToolTip, Меню биндов открыто. Используй !меню для закрытия.
    SetTimer, RemoveToolTip, -1600
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

RunSearchModeTrigger(docCode, docName) {
    global BindMenuEditMode
    if (BindMenuEditMode)
    {
        BindMenuWarn()
        return ""
    }
    LawSearch_ModeHotstring(docCode, docName)
    return ""
}

RunTriggerLabel(labelName) {
    global BindMenuEditMode
    if (BindMenuEditMode)
    {
        if (labelName = "DoBindMenuToggle")
        {
            ToggleBindMenuEditMode()
            return ""
        }
        BindMenuWarn()
        return ""
    }
    SetTimer, %labelName%, -1
    return ""
}

ApplyTextTriggers(ByRef ok, ByRef errText) {
    global
    Hotkey, If, % GameTextHotkeyContext
    ResetRegisteredGameTextHotstrings()
    Hotkey, If, % GameTextHotkeyContext
    usedTriggers := {}

    if !RegisterTextTrigger("BindMenu", Prev_Trig_BindMenu, "!меню", "DoBindMenuToggle", errText, usedTriggers)
        ok := 0
    if !RegisterTextTrigger("Codes", Prev_Trig_Codes, "!коды", "DoServiceCodesGui", errText, usedTriggers)
        ok := 0
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta) || meta.TriggerVar = ""
            continue
        callbackName := GetBoundLabelByToken(meta.Token)
        if (callbackName = "")
            continue
        previousTrigger := ""
        currentTrigger := GetDynamicGlobalValue(meta.TriggerVar)
        if !RegisterTextTrigger(meta.TriggerVar, previousTrigger, currentTrigger, callbackName, errText, usedTriggers)
            ok := 0
    }
    if !RegisterGpsInputTextTrigger("Trig_GpsD", Prev_Trig_GpsD, Trig_GpsD, "GPS Д", 15, errText, usedTriggers)
        ok := 0
    if !RegisterGpsInputTextTrigger("Trig_GpsOS", Prev_Trig_GpsOS, Trig_GpsOS, "GPS ОС", 16, errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ALL", Prev_SearchTrig_ALL, "!пвсе", "ALL", "всем материалам", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KOAP", Prev_SearchTrig_KOAP, "!пкоап", "KOAP", "КоАП", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_UK", Prev_SearchTrig_UK, "!пук", "UK", "УК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_UPK", Prev_SearchTrig_UPK, "!пупк", "UPK", "УПК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KAS", Prev_SearchTrig_KAS, "!пкас", "KAS", "КАС", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FSB", Prev_SearchTrig_FSB, "!пфсб", "FSB", "ФЗ о ФСБ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FSIN", Prev_SearchTrig_FSIN, "!пфсин", "FSIN", "ФЗ о ФСИН", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VS", Prev_SearchTrig_VS, "!пвс", "VS", "Военная служба", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_SUD", Prev_SearchTrig_SUD, "!псуд", "SUD", "Судебная система", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ORD", Prev_SearchTrig_ORD, "!порд", "ORD", "ОРД", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_GT", Prev_SearchTrig_GT, "!пгт", "GT", "Государственная тайна", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_PDD", Prev_SearchTrig_PDD, "!ппдд", "PDD", "ПДД", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_FZOP", Prev_SearchTrig_FZOP, "!пфзоп", "FZOP", "ФЗ О полиции", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_TK", Prev_SearchTrig_TK, "!птк", "TK", "ТК", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_TER", Prev_SearchTrig_TER, "!птер", "TER", "Территории", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ARG", Prev_SearchTrig_ARG, "!парг", "ARG", "АРГ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VU", Prev_SearchTrig_VU, "!пву", "VU", "ВУ", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_VV", Prev_SearchTrig_VV, "!пвв", "VV", "Вертикаль власти", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_ORUZH", Prev_SearchTrig_ORUZH, "!поружие", "ORUZH", "Оружие", errText, usedTriggers)
        ok := 0
    if !RegisterSearchModeTrigger("Search_KON", Prev_SearchTrig_KON, "!пкон", "KON", "Конституция", errText, usedTriggers)
        ok := 0
    if !RegisterTextTrigger("Search_RUN", Prev_SearchTrig_RUN, "!пнайти", "DoLawSearchClipboard", errText, usedTriggers)
        ok := 0
    ApplyCustomFunctionTextTriggers(ok, errText, usedTriggers)
    if (BindMenuEditMode)
        SuspendGameTextTriggersForBindMenu()
    Hotkey, If
}

ApplyTemplate(str) {
    global IntroRole, ReportRole, Rank, ReportRank, Surname, PersonalBadge
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount
    str := StrReplace(str, "{INTRO_ROLE}", IntroRole)
    str := StrReplace(str, "{REPORT_ROLE}", ReportRole)
    str := StrReplace(str, "{RANK}", Rank)
    str := StrReplace(str, "{REPORT_RANK}", ReportRank)
    str := StrReplace(str, "{SURNAME}", Surname)
    str := StrReplace(str, "{BADGE}", PersonalBadge)
    str := StrReplace(str, "{PERSONAL_BADGE}", PersonalBadge)
    str := StrReplace(str, "{TOKEN}", PersonalBadge)
    str := StrReplace(str, "{PATROL_ROUTE}", PatrolRoute)
    str := StrReplace(str, "{POST_ROUTE}", PostRoute)
    str := StrReplace(str, "{CONVOY_ROUTE}", ConvoyRoute)
    str := StrReplace(str, "{PATROL_UNIT}", PatrolUnit)
    str := StrReplace(str, "{PATROL_CREW_COUNT}", PatrolCrewCount)
    str := StrReplace(str, "{POST_UNIT}", PostUnit)
    str := StrReplace(str, "{POST_CREW_COUNT}", PostCrewCount)
    return str
}

ApplyActionTemplate(str) {
    global UserID, CurrentProfile, TargetNickname, TargetIsMask
    str := ApplyTemplate(str)
    str := StrReplace(str, "{USER_ID}", UserID)
    str := StrReplace(str, "{ID}", TargetIsMask ? "" : UserID)
    str := StrReplace(str, "{MASK}", TargetIsMask ? UserID : "")
    str := StrReplace(str, "{TARGET}", UserID)
    str := StrReplace(str, "{TARGET_NICK}", TargetNickname)
    str := StrReplace(str, "{NICK}", TargetNickname)
    str := StrReplace(str, "{TARGET_FULL}", GetTargetFullLabel())
    str := StrReplace(str, "{PROFILE}", CurrentProfile)
    FormatTime, psNowTime,, HH:mm:ss
    FormatTime, psNowDate,, dd.MM.yyyy
    str := StrReplace(str, "{TIME}", psNowTime)
    str := StrReplace(str, "{DATE}", psNowDate)
    return str
}

GetTargetFullLabel() {
    global UserID, ActiveID, TargetNickname, TargetIsMask
    if (!ActiveID || UserID = "")
        return "Цель не выбрана"
    if (TargetIsMask)
        return "Маска " . UserID
    return "ID " . UserID . (TargetNickname != "" ? " (" . TargetNickname . ")" : "")
}

SendConfigSequence(sequenceText, delayMs := "") {
    global SequenceLineDelay
    NormalizeNumberRange(SequenceLineDelay, 700, 250, 3000)
    if (delayMs = "" || delayMs < SequenceLineDelay)
        delayMs := SequenceLineDelay
    return ChatQueue_EnqueueSequence(sequenceText, "RPSequence", delayMs)
}

SplitConfigSequenceMiddle(sequenceText, ByRef firstPart, ByRef secondPart) {
    lines := []
    firstPart := ""
    secondPart := ""

    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")

    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        lines.Push(line)
    }

    total := lines.Length()
    if (total <= 0)
        return

    splitIndex := Floor(total / 2)
    Loop % total
    {
        line := lines[A_Index]
        if (A_Index <= splitIndex)
        {
            if (firstPart != "")
                firstPart .= "`n"
            firstPart .= line
        }
        else
        {
            if (secondPart != "")
                secondPart .= "`n"
            secondPart .= line
        }
    }
}

SplitConfigReportLine(sequenceText, ByRef reportLine, ByRef remainingText) {
    reportLine := ""
    remainingText := ""
    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        normalized := Evidence_NormalizeChatLine(line)
        if (reportLine = "" && RegExMatch(normalized, "^/r\s+докладывает(?:\s|$)")) {
            reportLine := line
            continue
        }
        if (remainingText != "")
            remainingText .= "`n"
        remainingText .= line
    }
    return (reportLine != "")
}

TowStart_EnsureTowLast(sequenceText) {
    cleaned := ""
    sequenceText := StrReplace(sequenceText, "`r`n", "`n")
    sequenceText := StrReplace(sequenceText, "`r", "`n")
    Loop, Parse, sequenceText, `n
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        lineLower := line
        StringLower, lineLower, lineLower
        if (lineLower = "/tow")
            continue
        if (cleaned != "")
            cleaned .= "`n"
        cleaned .= line
    }
    if (cleaned != "")
        cleaned .= "`n"
    cleaned .= "/tow"
    return cleaned
}

EncodeIniText(value) {
    size := StrPut(value, "CP1251") - 1
    VarSetCapacity(buffer, size + 1, 0)
    StrPut(value, &buffer, size + 1, "CP1251")
    encoded := ""
    Loop % size
        encoded .= Format("{:02X}", NumGet(buffer, A_Index - 1, "UChar"))
    return "H1:" . size . ":" . encoded
}

DecodeIniText(value, codec := "legacy") {
    if (codec = "hex1") {
        if !RegExMatch(value, "^H1:([0-9]+):([A-F0-9]*)$", parts)
            return ""
        if (StrLen(parts2) != parts1 * 2)
            return ""
        VarSetCapacity(buffer, parts1 + 1, 0)
        Loop % parts1
            NumPut("0x" . SubStr(parts2, A_Index * 2 - 1, 2), buffer, A_Index - 1, "UChar")
        return parts1 ? StrGet(&buffer, parts1, "CP1251") : ""
    }
    value := StrReplace(value, "{NL}", "`r`n")
    value := StrReplace(value, "{RAW_NL}", "{NL}")
    value := StrReplace(value, "{RAW2_NL}", "{RAW_NL}")
    return value
}

IniReadText(fileName, sectionName, keyName, defaultValue := "") {
    IniRead, section, %fileName%, %sectionName%
    if (ErrorLevel)
        return defaultValue
    present := false
    Loop, Parse, section, `n, `r
    {
        equals := InStr(A_LoopField, "=")
        if (equals && Trim(SubStr(A_LoopField, 1, equals - 1)) = keyName) {
            present := true
            break
        }
    }
    if (!present)
        return defaultValue
    IniRead, outValue, %fileName%, %sectionName%, %keyName%,
    codecKey := sectionName . "|" . keyName
    IniRead, codec, %fileName%, TextEncoding, %codecKey%, legacy
    if (codec != "legacy" && codec != "hex1")
        return defaultValue
    return DecodeIniText(outValue, codec)
}

IniWriteText(value, fileName, sectionName, keyName) {
    encodedValue := EncodeIniText(value)
    codecKey := sectionName . "|" . keyName
    if !CheckedIniWrite(encodedValue, fileName, sectionName, keyName)
        return false
    return CheckedIniWrite("hex1", fileName, "TextEncoding", codecKey)
}

EnsureRussianLayout() {
    return SafeLayout(0x4190419)
}

PasteOnly(text, alreadyOwned := 0, contextGuard := "", expectedHwnd := 0) {
    if IsObject(IDCaptureState)
        return false
    global MockMode
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[TYPE] " . text)
        return true
    }
    if (!GameLocator_IsActive() || (!alreadyOwned && PhysicalInputBusy))
        return false
    if (!alreadyOwned)
        PhysicalInputBusy := 1
    epoch := AutomationEpoch
    ownerHwnd := expectedHwnd ? expectedHwnd : WinExist("A")
    if !ChatTyping_IsReady(epoch, ownerHwnd, contextGuard) {
        if (!alreadyOwned)
            PhysicalInputBusy := 0
        return false
    }
    saved := ClipboardAll
    sequence := -1
    try {
        Clipboard := text
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        ClipWait, 0.5
        if (ErrorLevel || !ChatTyping_IsReady(epoch, ownerHwnd, contextGuard)
            || sequence != DllCall("GetClipboardSequenceNumber", "UInt"))
            return false
        if !SafeSend("^v", "Input", epoch)
            return false
        Sleep, 50
        return ChatTyping_IsReady(epoch, ownerHwnd, contextGuard)
    } finally {
        if (sequence >= 0 && sequence = DllCall("GetClipboardSequenceNumber", "UInt"))
            Clipboard := saved
        VarSetCapacity(saved, 0)
        if (!alreadyOwned)
            PhysicalInputBusy := 0
    }
}

SendTemplateChat(template) {
    text := ApplyTemplate(template)
    SendChatAuto(text)
}

SendTemplateOpen(template, leftCount := 0, inputEpoch := 0) {
    global PhysicalInputBusy
    inputEpoch := AutomationEpoch
    text := ApplyTemplate(template)
    previous := A_IsCritical
    Critical, On
    try {
        ownerHwnd := WinExist("A")
        if (PhysicalInputBusy || IsObject(IDCaptureState))
            return false
        if !TypeChatForEpoch(inputEpoch, text)
            return false
        if (leftCount <= 0)
            return true
        ; Typed input restores this critical thread before returning. Claim its
        ; caret tail before allowing another sender or hotkey to interrupt.
        if (PhysicalInputBusy || inputEpoch != AutomationEpoch || WinExist("A") != ownerHwnd)
            return false
        PhysicalInputBusy := 1
        Critical, Off
        try {
            Sleep, 50
            if (inputEpoch != AutomationEpoch || WinExist("A") != ownerHwnd)
                return false
            return SafeSend("{Left " . leftCount . "}", "Input", inputEpoch)
        } finally {
            Critical, On
            PhysicalInputBusy := 0
        }
    } finally {
        Critical, %previous%
    }
}

NormalizeHotkeyId(hotkeyName) {
    hotkeyName := Trim(hotkeyName)
    if (hotkeyName = "" || hotkeyName = "ERROR")
        return ""
    keyId := hotkeyName
    StringLower, keyId, keyId
    return keyId
}

HandleGuiHotkeyDispatch(hotkeyName) {
    global GuiHotkeyActionMap, HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab

    keyId := NormalizeHotkeyId(hotkeyName)
    if (keyId = "" || !IsObject(GuiHotkeyActionMap) || !GuiHotkeyActionMap.HasKey(keyId))
        return

    actionToken := GuiHotkeyActionMap[keyId]
    targetHUD := HUDVisible
    targetBindList := BindListVisible
    targetSettings := SettingsVisible

    if (actionToken = "OpenSettings")
    {
        targetSettings := !SettingsVisible
        RequestIndependentGuiState(targetHUD, targetBindList, targetSettings, SettingsTargetTab)
        return
    }
    if (actionToken = "ToggleBindList")
    {
        targetBindList := !BindListVisible
        RequestIndependentGuiState(targetHUD, targetBindList, targetSettings, SettingsTargetTab)
        return
    }
    if (actionToken = "ToggleHUD")
    {
        targetHUD := !HUDVisible
        RequestIndependentGuiState(targetHUD, targetBindList, targetSettings, SettingsTargetTab)
        return
    }
}

NormalizeBindValue(ByRef val) {
    if (val = "ERROR")
        val := ""
}

ClearRegisteredBindHotkeys() {
    global RegisteredBindHotkeys, HotkeyDispatchMap, IDConfirmHotkeyContext

    if (IsObject(RegisteredBindHotkeys))
    {
        Loop % RegisteredBindHotkeys.Length()
        {
            item := RegisteredBindHotkeys[A_Index]
            if IsObject(item)
            {
                hk := item.Key
                contextual := item.Contextual
            }
            else
            {
                hk := item
                contextual := false
            }

            if (contextual)
                Hotkey, If, % IDConfirmHotkeyContext
            if (hk != "")
                Hotkey, %hk%, DispatchBoundHotkey, Off UseErrorLevel
            if (contextual)
                Hotkey, If
        }
    }

    RegisteredBindHotkeys := []
    HotkeyDispatchMap := {}
}

RegisterBoundHotkey(bindName, currentKey, token, ByRef errText, ByRef usedKeys) {
    global RegisteredBindHotkeys, HotkeyDispatchMap, IDConfirmHotkeyContext

    currentKey := Trim(currentKey)
    if (currentKey = "" || currentKey = "ERROR")
        return true

    keyId := NormalizeHotkeyId(currentKey)
    if (keyId = "")
        return false

    if (usedKeys.HasKey(keyId))
    {
        errText .= bindName . " = " . currentKey . "  -> дубликат с """ . usedKeys[keyId] . """`n"
        return false
    }

    contextual := (token = "ConfirmID" || token = "RejectID")
    if (contextual)
        Hotkey, If, % IDConfirmHotkeyContext
    Hotkey, %currentKey%, DispatchBoundHotkey, On UseErrorLevel
    registerError := ErrorLevel
    if (contextual)
        Hotkey, If

    if (registerError)
    {
        errText .= bindName . " = " . currentKey . "  -> неверный или неподдерживаемый hotkey`n"
        return false
    }

    usedKeys[keyId] := bindName
    HotkeyDispatchMap[keyId] := token
    RegisteredBindHotkeys.Push({Key: currentKey, Contextual: contextual})
    return true
}

GetBoundLabelByToken(token) {
    static labelMap := ""
    if !IsObject(labelMap)
    {
        labelMap := {}
        labelMap["ToggleLastLawDoc"] := "DoToggleLastLawDoc"
        labelMap["HideLawGui"] := "DoHideLawGui"
        labelMap["EnterID"] := "DoEnterID"
        labelMap["ResetID"] := "DoResetID"
        labelMap["OpenBindsTab"] := "DoOpenBindsTab"
        labelMap["IDOverlay"] := "DoToggleIDOverlay"
        labelMap["ConfirmID"] := "DoConfirmID"
        labelMap["RejectID"] := "DoRejectID"
        labelMap["Intro"] := "DoIntro"
        labelMap["SOS"] := "DoSOS"
        labelMap["Chase"] := "DoChase"
        labelMap["ChaseNoID"] := "DoChaseNoID"
        labelMap["Deject"] := "DoDeject"
        labelMap["Cuff"] := "DoCuff"
        labelMap["InCar"] := "DoInCar"
        labelMap["StopChase"] := "DoStopChase"
        labelMap["Doc"] := "DoDoc"
        labelMap["Search"] := "DoSearch"
        labelMap["PersonalFile"] := "DoPersonalFile"
        labelMap["Su"] := "DoSu"
        labelMap["MDC"] := "DoMDC"
        labelMap["Dep"] := "DoDep"
        labelMap["WantedList"] := "DoWantedList"
        labelMap["SOSStart"] := "DoSOSStart"
        labelMap["SOSArrive"] := "DoSOSArrive"
        labelMap["HijackStart"] := "DoHijackStart"
        labelMap["HijackArrive"] := "DoHijackArrive"
        labelMap["CallStart"] := "DoCallStart"
        labelMap["CallArrive"] := "DoCallArrive"
        labelMap["CallWorkStart"] := "DoCallWorkStart"
        labelMap["CallWorkEnd"] := "DoCallWorkEnd"
        labelMap["CivilCallStart"] := "DoCivilCallStart"
        labelMap["CivilCallArrive"] := "DoCivilCallArrive"
        labelMap["VehicleLookup"] := "DoVehicleLookup"
        labelMap["WantedRemoval"] := "DoWantedRemoval"
        labelMap["LawSearchSubmit"] := "DoLawSearchClipboard"
        labelMap["MaskCall"] := "DoMaskCall"
        labelMap["RecordCheck"] := "DoRecordCheck"
        labelMap["TrainCrash"] := "DoTrainCrash"
        labelMap["PatrolStart"] := "DoPatrolStart"
        labelMap["PatrolCont"] := "DoPatrolCont"
        labelMap["PatrolEnd"] := "DoPatrolEnd"
        labelMap["PostStart"] := "DoPostStart"
        labelMap["PostCont"] := "DoPostCont"
        labelMap["PostEnd"] := "DoPostEnd"
        labelMap["ConvoyStart"] := "DoConvoyStart"
        labelMap["ConvoyCont"] := "DoConvoyCont"
        labelMap["ConvoyEnd"] := "DoConvoyEnd"
        labelMap["TowStart"] := "DoTowStart"
        labelMap["TowEnd"] := "DoTowEnd"
        labelMap["CarSearch"] := "DoCarSearch"
        labelMap["Arrest"] := "DoArrest"
        labelMap["Fine"] := "DoFine"
        labelMap["Protocol"] := "DoProtocol"
        labelMap["Rights"] := "DoRights"
        labelMap["CardDS"] := "DoCardDS"
        labelMap["CardVK"] := "DoCardVK"
        labelMap["MDSFormation"] := "DoMDSFormation"
        labelMap["AutoPatrol"] := "DoAutoPatrolToggle"
        labelMap["AutoPost"] := "DoAutoPostToggle"
        labelMap["AssistOOP"] := "DoAssistOOP"
        labelMap["AssistStun"] := "DoAssistStun"
        labelMap["AssistChase"] := "DoAssistChase"
        labelMap["AssistHouse"] := "DoAssistHouse"
        labelMap["AssistDrugs"] := "DoAssistDrugs"
        labelMap["AssistPDPCuff"] := "DoAssistPDPCuff"
        labelMap["VU"] := "DoToggleVU"
        labelMap["FP"] := "DoToggleFP"
        labelMap["KON"] := "DoToggleKON"
        labelMap["FZOP"] := "DoToggleFZOP"
        labelMap["TER"] := "DoToggleTER"
        labelMap["TK"] := "DoToggleTK"
        labelMap["ARG"] := "DoToggleARG"
        labelMap["UK"] := "DoToggleUK"
        labelMap["VV"] := "DoToggleVV"
        labelMap["KOAP"] := "DoToggleKOAP"
        labelMap["PDD"] := "DoTogglePDD"
        labelMap["ORUZH"] := "DoToggleORUZH"
        labelMap["UPK"] := "DoToggleUPK"
        labelMap["KAS"] := "DoToggleKAS"
        labelMap["FSB"] := "DoToggleFSB"
        labelMap["FSIN"] := "DoToggleFSIN"
        labelMap["VS"] := "DoToggleVS"
        labelMap["SUD"] := "DoToggleSUD"
        labelMap["ORD"] := "DoToggleORD"
        labelMap["GT"] := "DoToggleGT"
    }

    if (labelMap.HasKey(token))
        return labelMap[token]
    return ""
}

ExecuteBindToken(token) {
    global HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab

    if RegExMatch(token, "^CustomFunction:(\d+)$", customMatch)
    {
        RunCustomFunction(customMatch1)
        return
    }

    if (token = "OpenSettings")
    {
        RequestIndependentGuiState(HUDVisible, BindListVisible, !SettingsVisible, SettingsTargetTab)
        return
    }
    if (token = "ToggleBindList")
    {
        RequestIndependentGuiState(HUDVisible, !BindListVisible, SettingsVisible, SettingsTargetTab)
        return
    }
    if (token = "ToggleHUD")
    {
        RequestIndependentGuiState(!HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab)
        return
    }

    labelName := GetBoundLabelByToken(token)
    if (labelName != "")
        SetTimer, %labelName%, -1
}

HandleBoundHotkey(hotkeyName) {
    global HotkeyDispatchMap, BindMenuEditMode
    keyId := NormalizeHotkeyId(hotkeyName)
    if (keyId = "" || !IsObject(HotkeyDispatchMap) || !HotkeyDispatchMap.HasKey(keyId))
        return

    token := HotkeyDispatchMap[keyId]
    if (BindMenuEditMode && GetBoundLabelByToken(token) != "")
    {
        BindMenuHotkeyBlockedWarn()
        return
    }
    ExecuteBindToken(token)
}

ApplyAllBinds() {
    global
    ok := 1
    errText := ""
    usedKeys := {}

    ClearRegisteredBindHotkeys()
    ClearCustomFunctionHotkeys()

    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !BindCatalog_IsRegistrable(meta)
            continue
        if (meta.HotkeyVar = "")
            continue

        hotkeyValue := GetDynamicGlobalValue(meta.HotkeyVar)
        NormalizeBindValue(hotkeyValue)
        SetDynamicGlobalValue(meta.HotkeyVar, hotkeyValue)

        if !RegisterBoundHotkey(meta.HotkeyVar, hotkeyValue, meta.Token, errText, usedKeys)
            ok := 0
    }

    ApplyCustomFunctionHotkeys(ok, errText, usedKeys)
    ApplyTextTriggers(ok, errText)

    UpdateHUD()
    UpdateBindList()

    if (!ok)
        MsgBox, 48, Ошибка биндов, Не применились следующие бинды:`n`n%errText%
}

LoadUIAppearanceFromIni(fileName) {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global CFG_ThemePresetName
    global UIRoundness, InnerRoundness, GuiTransparency, BackgroundImageURL, FullscreenSafeGui
    global ProfileMode, HUDMode, MenuTransparency, HUDTransparency, BindListTransparency, TabGuiHeaderText

    IniRead, ThemeMode, %fileName%, UI, ThemeMode, Graphite
    IniRead, CFG_ThemePresetName, %fileName%, UI, ThemePresetName,
    if (CFG_ThemePresetName != "" && !ThemePresetExists(CFG_ThemePresetName))
        CFG_ThemePresetName := ""
    IniRead, CustomMenuColor, %fileName%, UI, CustomMenuColor,
    IniRead, CustomTextColor, %fileName%, UI, CustomTextColor,
    IniRead, CustomBorderColor, %fileName%, UI, CustomBorderColor,
    IniRead, CustomTabColor, %fileName%, UI, CustomTabColor,
    IniRead, CustomBindListColor, %fileName%, UI, CustomBindListColor,
    IniRead, UIRoundness, %fileName%, UI, UIRoundness, 18
    IniRead, InnerRoundness, %fileName%, UI, InnerRoundness, 14
    IniRead, GuiTransparency, %fileName%, UI, GuiTransparency, 225
    IniRead, BackgroundImageURL, %fileName%, UI, BackgroundImageURL,
    IniRead, FullscreenSafeGui, %fileName%, UI, FullscreenSafeGui, Auto
    IniRead, ProfileMode, %fileName%, UI, ProfileMode, ППС
    IniRead, HUDMode, %fileName%, UI, HUDMode, Полный
    IniRead, MenuTransparency, %fileName%, UI, MenuTransparency, 225
    IniRead, HUDTransparency, %fileName%, UI, HUDTransparency, 225
    IniRead, BindListTransparency, %fileName%, UI, BindListTransparency, 225
    TabGuiHeaderText := IniReadText(fileName, "UI", "TabGuiHeaderText", "AMZ Helper | sbezruk180")
    IniRead, OBSHideWindows, %fileName%, UI, OBSHideWindows, Off
    NormalizeOnOff(OBSHideWindows, "Off")
}

LoadUISafetyAndAudioFromIni(fileName) {
    global SafeModeEnabled, SafeBlockWhenChat, SafeVehicleChecks, SafeRequireChatForEditable, SafeTooltipWarnings
    global SafeDistanceChecks, SafeDistanceLimit, IDCheckEnabled, StopTimerWidth, StopTimerHeight
    global StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor, StopTimerVolume
    global StopTimerX, StopTimerY, EvacuationTimerEnabled, PatrolTimerEnabled, PostTimerEnabled
    global ActionTimerX, ActionTimerY, TextSendMode, GameWindowTitle, GameProcessName, AzmpExpectedSHA256, MockMode, ChatQueueEnabled, ChatQueueMinDelay, NotifySoundEnabled, NotifyVolume, ActionCooldownMs
    global ChatLogReaderEnabled, ChatLogPath, ChatLogPlayerNickname
    global ChatLogAutoCleanupEnabled, ChatLogMaxSizeKB, ChatLogKeepTailKB
    global ContextNotificationMode, ContextNotificationTimeoutSec, EvidenceScreenshotMode, EvidenceScreenshotMethod
    global EvidenceDocumentActivationMode, EvidenceDocumentWaitSec, EvidenceDocumentDistanceLimit
    global SequenceLineDelay, ProfileSaveBackups

    IniRead, SafeModeEnabled, %fileName%, UI, SafeModeEnabled, Off
    IniRead, SafeBlockWhenChat, %fileName%, UI, SafeBlockWhenChat, Off
    IniRead, SafeVehicleChecks, %fileName%, UI, SafeVehicleChecks, Off
    IniRead, SafeRequireChatForEditable, %fileName%, UI, SafeRequireChatForEditable, Off
    IniRead, SafeTooltipWarnings, %fileName%, UI, SafeTooltipWarnings, Off
    IniRead, SafeDistanceChecks, %fileName%, UI, SafeDistanceChecks, Off
    IniRead, SafeDistanceLimit, %fileName%, UI, SafeDistanceLimit, 12
    IniRead, IDCheckEnabled, %fileName%, UI, IDCheckEnabled, 1
    IniRead, StopTimerWidth, %fileName%, UI, StopTimerWidth, 170
    IniRead, StopTimerHeight, %fileName%, UI, StopTimerHeight, 76
    IniRead, StopTimerTransparency, %fileName%, UI, StopTimerTransparency, 255
    IniRead, StopTimerBorderColor, %fileName%, UI, StopTimerBorderColor,
    IniRead, StopTimerTextColor, %fileName%, UI, StopTimerTextColor,
    IniRead, StopTimerBgColor, %fileName%, UI, StopTimerBgColor,
    IniRead, StopTimerVolume, %fileName%, UI, StopTimerVolume, 65
    IniRead, StopTimerX, %fileName%, UI, StopTimerX, 100
    IniRead, StopTimerY, %fileName%, UI, StopTimerY, 90
    IniRead, EvacuationTimerEnabled, %fileName%, UI, EvacuationTimerEnabled, On
    IniRead, PatrolTimerEnabled, %fileName%, UI, PatrolTimerEnabled, On
    IniRead, PostTimerEnabled, %fileName%, UI, PostTimerEnabled, On
    IniRead, ActionTimerX, %fileName%, UI, ActionTimerX, 100
    IniRead, ActionTimerY, %fileName%, UI, ActionTimerY, 180
    IniRead, TextSendMode, %fileName%, UI, TextSendMode, Auto
    IniRead, ChatTypingDelayMs, %fileName%, UI, ChatTypingDelayMs, 5
    ChatFactionCommands := IniReadText(fileName, "UI", "ChatFactionCommands", ChatTyping_DefaultCommands())
    IniRead, IDEntryMode, %fileName%, UI, IDEntryMode, Перехват цифр
    IniRead, IDCaptureTimeoutSec, %fileName%, UI, IDCaptureTimeoutSec, 3
    IniRead, GameWindowTitle, %fileName%, UI, GameWindowTitle, AMAZING ONLINE
    IniRead, GameProcessName, %fileName%, UI, GameProcessName, gta_sa.exe
    IniRead, AzmpExpectedSHA256, %fileName%, UI, AzmpExpectedSHA256,
    IniRead, MockMode, %fileName%, UI, MockMode, Off
    IniRead, ChatQueueEnabled, %fileName%, UI, ChatQueueEnabled, On
    IniRead, ChatQueueMinDelay, %fileName%, UI, ChatQueueMinDelay, 700
    IniRead, NotifySoundEnabled, %fileName%, UI, NotifySoundEnabled, On
    IniRead, NotifyVolume, %fileName%, UI, NotifyVolume, 65
    IniRead, ActionCooldownMs, %fileName%, UI, ActionCooldownMs, 250
    IniRead, SequenceLineDelay, %fileName%, UI, SequenceLineDelay, 700
    IniRead, ProfileSaveBackups, %fileName%, UI, ProfileSaveBackups, On
    IniRead, ContextNotificationMode, %fileName%, UI, ContextNotificationMode, Плашка
    IniRead, ContextNotificationTimeoutSec, %fileName%, UI, ContextNotificationTimeoutSec, 8
    IniRead, EvidenceScreenshotMode, %fileName%, UI, EvidenceScreenshotMode, Off
    IniRead, EvidenceScreenshotMethod, %fileName%, UI, EvidenceScreenshotMethod, Alt+F1
    IniRead, EvidenceDocumentActivationMode, %fileName%, UI, EvidenceDocumentActivationMode, Только радиус
    IniRead, EvidenceDocumentWaitSec, %fileName%, UI, EvidenceDocumentWaitSec, 90
    IniRead, EvidenceDocumentDistanceLimit, %fileName%, UI, EvidenceDocumentDistanceLimit, 20
    IniRead, ChatLogReaderEnabled, %fileName%, ChatLog, Enabled, On
    ChatLogPath := IniReadText(fileName, "ChatLog", "Path", "C:\Amazing Games\Amazing Online\PC\amazing\chatlog.txt")
    ChatLogPlayerNickname := IniReadText(fileName, "ChatLog", "PlayerNickname", "Semen_Lukashenko")
    IniRead, ChatLogAutoCleanupEnabled, %fileName%, ChatLog, AutoCleanup, On
    IniRead, ChatLogMaxSizeKB, %fileName%, ChatLog, MaxSizeKB, 512
    IniRead, ChatLogKeepTailKB, %fileName%, ChatLog, KeepTailKB, 32

    ; Upgrade the previous cleanup defaults so an existing profiles.ini
    ; immediately uses the more frequent rotation policy.
    if (ChatLogMaxSizeKB = 2048) {
        ChatLogMaxSizeKB := 512
        CheckedIniWrite("512", fileName, "ChatLog", "MaxSizeKB")
    }
    if (ChatLogKeepTailKB = 64) {
        ChatLogKeepTailKB := 32
        CheckedIniWrite("32", fileName, "ChatLog", "KeepTailKB")
    }
}

LoadUIWindowPrefsFromIni(fileName) {
    global HudX, HudY, BindListX, BindListY, BindListW, BindListH
    global SettingsTargetTab, SettingsPage, SettingsX, SettingsY, SettingsW, SettingsH
    global HUDVisible, BindListVisible, SettingsVisible

    IniRead, HudX, %fileName%, UI, HudX, 10
    IniRead, HudY, %fileName%, UI, HudY, 10
    IniRead, BindListX, %fileName%, UI, BindListX, 300
    IniRead, BindListY, %fileName%, UI, BindListY, 70
    IniRead, BindListW, %fileName%, UI, BindListW, 520
    IniRead, BindListH, %fileName%, UI, BindListH, 390
    IniRead, SettingsTargetTab, %fileName%, UI, SettingsTargetTab, 1
    IniRead, SettingsPage, %fileName%, UI, SettingsPage, % SettingsPageIdFromLegacyTab(SettingsTargetTab)
    IniRead, SettingsX, %fileName%, UI, SettingsX, 120
    IniRead, SettingsY, %fileName%, UI, SettingsY, 60
    IniRead, SettingsW, %fileName%, UI, SettingsW, 1180
    IniRead, SettingsH, %fileName%, UI, SettingsH, 800
    IniRead, HUDVisible, %fileName%, UI, HUDVisible, 1
    IniRead, BindListVisible, %fileName%, UI, BindListVisible, 0
    IniRead, SettingsVisible, %fileName%, UI, SettingsVisible, 0
}

NormalizeLoadedUISettings() {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global UIRoundness, InnerRoundness, GuiTransparency, FullscreenSafeGui, ProfileMode, HUDMode
    global MenuTransparency, HUDTransparency, BindListTransparency, SafeModeEnabled, SafeBlockWhenChat
    global SafeVehicleChecks, SafeRequireChatForEditable, SafeTooltipWarnings, SafeDistanceChecks
    global SafeDistanceLimit, IDCheckEnabled, StopTimerWidth, StopTimerHeight, StopTimerTransparency
    global StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor, StopTimerVolume, StopTimerX, StopTimerY
    global EvacuationTimerEnabled, PatrolTimerEnabled, PostTimerEnabled, ActionTimerX, ActionTimerY
    global TextSendMode, GameWindowTitle, GameProcessName, AzmpExpectedSHA256, MockMode, ChatQueueEnabled, ChatQueueMinDelay, NotifySoundEnabled, NotifyVolume, ActionCooldownMs, SequenceLineDelay
    global ChatLogReaderEnabled, ChatLogPath, ChatLogPlayerNickname, ChatLogAutoCleanupEnabled, ChatLogMaxSizeKB, ChatLogKeepTailKB
    global ContextNotificationMode, ContextNotificationTimeoutSec, EvidenceScreenshotMode, EvidenceScreenshotMethod
    global EvidenceDocumentActivationMode, EvidenceDocumentWaitSec, EvidenceDocumentDistanceLimit
    global ProfileSaveBackups, HudX, HudY, BindListX, BindListY, BindListW, BindListH
    global SettingsTargetTab, SettingsPage, SettingsX, SettingsY, SettingsW, SettingsH, HUDVisible, BindListVisible, SettingsVisible

    NormalizeThemeMode(ThemeMode)
    NormalizeColorNumber(CustomMenuColor)
    NormalizeColorNumber(CustomTextColor)
    NormalizeColorNumber(CustomBorderColor)
    NormalizeColorNumber(CustomTabColor)
    NormalizeColorNumber(CustomBindListColor)
    NormalizeNumberRange(UIRoundness, 18, 0, 45)
    NormalizeNumberRange(InnerRoundness, 14, 0, 45)
    NormalizeNumberRange(GuiTransparency, 225, 120, 255)
    NormalizeNumberRange(MenuTransparency, 225, 120, 255)
    NormalizeNumberRange(HUDTransparency, 225, 120, 255)
    NormalizeNumberRange(BindListTransparency, 225, 120, 255)
    if (ProfileMode = "")
        ProfileMode := "ППС"
    if (HUDMode = "")
        HUDMode := "Полный"
    if (ProfileMode = "" or ProfileMode = "ERROR")
        ProfileMode := "ППС"
    if (HUDMode = "" or HUDMode = "ERROR")
        HUDMode := "Полный"
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
    ChatTyping_NormalizeDelay(ChatTypingDelayMs)
    ChatTyping_NormalizeCommands(ChatFactionCommands)
    NormalizeIDEntryMode(IDEntryMode)
    IDCaptureTimeoutSec := IDCapture_NormalizeTimeout(IDCaptureTimeoutSec)
    NormalizeGameWindowTitle(GameWindowTitle)
    NormalizeGameProcessName(GameProcessName)
    NormalizeSHA256(AzmpExpectedSHA256)
    ApplyGameProcessSelector()
    NormalizeOnOff(MockMode, "Off")
    NormalizeOnOff(ChatQueueEnabled, "On")
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
    NormalizeOnOff(ChatLogReaderEnabled, "On")
    NormalizeOnOff(ChatLogAutoCleanupEnabled, "Off")
    NormalizeNumberRange(ChatLogMaxSizeKB, 512, 256, 65536)
    NormalizeNumberRange(ChatLogKeepTailKB, 32, 0, 1024)
    if (ChatLogKeepTailKB > ChatLogMaxSizeKB // 2)
        ChatLogKeepTailKB := ChatLogMaxSizeKB // 2
    ChatLogPath := Trim(ChatLogPath)
    ChatLogPlayerNickname := Trim(ChatLogPlayerNickname)
    NormalizeFullscreenSafeGui(FullscreenSafeGui)
    NormalizeNumberRange(HudX, 10, -4000, 8000)
    NormalizeNumberRange(HudY, 10, -4000, 8000)
    NormalizeNumberRange(BindListX, 300, -4000, 8000)
    NormalizeNumberRange(BindListY, 70, -4000, 8000)
    NormalizeNumberRange(BindListW, 520, 420, 720)
    NormalizeNumberRange(BindListH, 390, 300, 700)
    NormalizeNumberRange(SettingsX, 120, -4000, 8000)
    NormalizeNumberRange(SettingsY, 60, -4000, 8000)
    Settings_NormalizeViewport()
    NormalizeSettingsPage(SettingsPage)
    SettingsTargetTab := SettingsPageIndex(SettingsPage)
    HUDVisible := HUDVisible ? 1 : 0
    BindListVisible := BindListVisible ? 1 : 0
    SettingsVisible := SettingsVisible ? 1 : 0
}

WriteUIAppearanceToIni(fileName) {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global CFG_ThemePresetName
    global UIRoundness, InnerRoundness, GuiTransparency, BackgroundImageURL, FullscreenSafeGui
    global ProfileMode, HUDMode, MenuTransparency, HUDTransparency, BindListTransparency, TabGuiHeaderText

    CheckedIniWrite(ThemeMode, fileName, "UI", "ThemeMode")
    CheckedIniWrite(CFG_ThemePresetName, fileName, "UI", "ThemePresetName")
    CheckedIniWrite(CustomMenuColor, fileName, "UI", "CustomMenuColor")
    CheckedIniWrite(CustomTextColor, fileName, "UI", "CustomTextColor")
    CheckedIniWrite(CustomBorderColor, fileName, "UI", "CustomBorderColor")
    CheckedIniWrite(CustomTabColor, fileName, "UI", "CustomTabColor")
    CheckedIniWrite(CustomBindListColor, fileName, "UI", "CustomBindListColor")
    CheckedIniWrite(UIRoundness, fileName, "UI", "UIRoundness")
    CheckedIniWrite(InnerRoundness, fileName, "UI", "InnerRoundness")
    CheckedIniWrite(GuiTransparency, fileName, "UI", "GuiTransparency")
    CheckedIniWrite(BackgroundImageURL, fileName, "UI", "BackgroundImageURL")
    CheckedIniWrite(FullscreenSafeGui, fileName, "UI", "FullscreenSafeGui")
    CheckedIniWrite(ProfileMode, fileName, "UI", "ProfileMode")
    CheckedIniWrite(HUDMode, fileName, "UI", "HUDMode")
    CheckedIniWrite(MenuTransparency, fileName, "UI", "MenuTransparency")
    CheckedIniWrite(HUDTransparency, fileName, "UI", "HUDTransparency")
    CheckedIniWrite(BindListTransparency, fileName, "UI", "BindListTransparency")
    IniWriteText(TabGuiHeaderText, fileName, "UI", "TabGuiHeaderText")
    CheckedIniWrite(OBSHideWindows, fileName, "UI", "OBSHideWindows")
    return !ConfigWriteFailed
}

WriteUISafetyAndAudioToIni(fileName) {
    global SafeModeEnabled, SafeBlockWhenChat, SafeVehicleChecks, SafeRequireChatForEditable, SafeTooltipWarnings
    global SafeDistanceChecks, SafeDistanceLimit, IDCheckEnabled, StopTimerWidth, StopTimerHeight
    global StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor, StopTimerVolume
    global StopTimerX, StopTimerY, EvacuationTimerEnabled, PatrolTimerEnabled, PostTimerEnabled
    global ActionTimerX, ActionTimerY, TextSendMode, GameWindowTitle, GameProcessName, AzmpExpectedSHA256, MockMode, ChatQueueEnabled, ChatQueueMinDelay, NotifySoundEnabled, NotifyVolume, ActionCooldownMs
    global ChatLogReaderEnabled, ChatLogPath, ChatLogPlayerNickname
    global ChatLogAutoCleanupEnabled, ChatLogMaxSizeKB, ChatLogKeepTailKB
    global ContextNotificationMode, ContextNotificationTimeoutSec, EvidenceScreenshotMode, EvidenceScreenshotMethod
    global EvidenceDocumentActivationMode, EvidenceDocumentWaitSec, EvidenceDocumentDistanceLimit
    global SequenceLineDelay, ProfileSaveBackups

    CheckedIniWrite(SafeModeEnabled, fileName, "UI", "SafeModeEnabled")
    CheckedIniWrite(SafeBlockWhenChat, fileName, "UI", "SafeBlockWhenChat")
    CheckedIniWrite(SafeVehicleChecks, fileName, "UI", "SafeVehicleChecks")
    CheckedIniWrite(SafeRequireChatForEditable, fileName, "UI", "SafeRequireChatForEditable")
    CheckedIniWrite(SafeTooltipWarnings, fileName, "UI", "SafeTooltipWarnings")
    CheckedIniWrite(SafeDistanceChecks, fileName, "UI", "SafeDistanceChecks")
    CheckedIniWrite(SafeDistanceLimit, fileName, "UI", "SafeDistanceLimit")
    CheckedIniWrite(IDCheckEnabled, fileName, "UI", "IDCheckEnabled")
    CheckedIniWrite(StopTimerWidth, fileName, "UI", "StopTimerWidth")
    CheckedIniWrite(StopTimerHeight, fileName, "UI", "StopTimerHeight")
    CheckedIniWrite(StopTimerTransparency, fileName, "UI", "StopTimerTransparency")
    CheckedIniWrite(StopTimerBorderColor, fileName, "UI", "StopTimerBorderColor")
    CheckedIniWrite(StopTimerTextColor, fileName, "UI", "StopTimerTextColor")
    CheckedIniWrite(StopTimerBgColor, fileName, "UI", "StopTimerBgColor")
    CheckedIniWrite(StopTimerVolume, fileName, "UI", "StopTimerVolume")
    CheckedIniWrite(StopTimerX, fileName, "UI", "StopTimerX")
    CheckedIniWrite(StopTimerY, fileName, "UI", "StopTimerY")
    CheckedIniWrite(EvacuationTimerEnabled, fileName, "UI", "EvacuationTimerEnabled")
    CheckedIniWrite(PatrolTimerEnabled, fileName, "UI", "PatrolTimerEnabled")
    CheckedIniWrite(PostTimerEnabled, fileName, "UI", "PostTimerEnabled")
    CheckedIniWrite(ActionTimerX, fileName, "UI", "ActionTimerX")
    CheckedIniWrite(ActionTimerY, fileName, "UI", "ActionTimerY")
    CheckedIniWrite(TextSendMode, fileName, "UI", "TextSendMode")
    CheckedIniWrite(ChatTypingDelayMs, fileName, "UI", "ChatTypingDelayMs")
    IniWriteText(ChatFactionCommands, fileName, "UI", "ChatFactionCommands")
    CheckedIniWrite(IDEntryMode, fileName, "UI", "IDEntryMode")
    CheckedIniWrite(IDCaptureTimeoutSec, fileName, "UI", "IDCaptureTimeoutSec")
    CheckedIniWrite(GameWindowTitle, fileName, "UI", "GameWindowTitle")
    CheckedIniWrite(GameProcessName, fileName, "UI", "GameProcessName")
    CheckedIniWrite(AzmpExpectedSHA256, fileName, "UI", "AzmpExpectedSHA256")
    CheckedIniWrite(MockMode, fileName, "UI", "MockMode")
    CheckedIniWrite(ChatQueueEnabled, fileName, "UI", "ChatQueueEnabled")
    CheckedIniWrite(ChatQueueMinDelay, fileName, "UI", "ChatQueueMinDelay")
    CheckedIniWrite(NotifySoundEnabled, fileName, "UI", "NotifySoundEnabled")
    CheckedIniWrite(NotifyVolume, fileName, "UI", "NotifyVolume")
    CheckedIniWrite(ActionCooldownMs, fileName, "UI", "ActionCooldownMs")
    CheckedIniWrite(SequenceLineDelay, fileName, "UI", "SequenceLineDelay")
    CheckedIniWrite(ProfileSaveBackups, fileName, "UI", "ProfileSaveBackups")
    CheckedIniWrite(ContextNotificationMode, fileName, "UI", "ContextNotificationMode")
    CheckedIniWrite(ContextNotificationTimeoutSec, fileName, "UI", "ContextNotificationTimeoutSec")
    CheckedIniWrite(EvidenceScreenshotMode, fileName, "UI", "EvidenceScreenshotMode")
    CheckedIniWrite(EvidenceScreenshotMethod, fileName, "UI", "EvidenceScreenshotMethod")
    CheckedIniWrite(EvidenceDocumentActivationMode, fileName, "UI", "EvidenceDocumentActivationMode")
    CheckedIniWrite(EvidenceDocumentWaitSec, fileName, "UI", "EvidenceDocumentWaitSec")
    CheckedIniWrite(EvidenceDocumentDistanceLimit, fileName, "UI", "EvidenceDocumentDistanceLimit")
    CheckedIniWrite(ChatLogReaderEnabled, fileName, "ChatLog", "Enabled")
    IniWriteText(ChatLogPath, fileName, "ChatLog", "Path")
    IniWriteText(ChatLogPlayerNickname, fileName, "ChatLog", "PlayerNickname")
    CheckedIniWrite(ChatLogAutoCleanupEnabled, fileName, "ChatLog", "AutoCleanup")
    CheckedIniWrite(ChatLogMaxSizeKB, fileName, "ChatLog", "MaxSizeKB")
    CheckedIniWrite(ChatLogKeepTailKB, fileName, "ChatLog", "KeepTailKB")
    return !ConfigWriteFailed
}

WriteUIWindowPrefsToIni(fileName) {
    global HudX, HudY, BindListX, BindListY, BindListW, BindListH
    global HUDVisible, BindListVisible, SettingsVisible, SettingsTargetTab, SettingsPage, SettingsX, SettingsY, SettingsW, SettingsH

    CheckedIniWrite(HudX, fileName, "UI", "HudX")
    CheckedIniWrite(HudY, fileName, "UI", "HudY")
    CheckedIniWrite(BindListX, fileName, "UI", "BindListX")
    CheckedIniWrite(BindListY, fileName, "UI", "BindListY")
    CheckedIniWrite(BindListW, fileName, "UI", "BindListW")
    CheckedIniWrite(BindListH, fileName, "UI", "BindListH")
    CheckedIniWrite(HUDVisible, fileName, "UI", "HUDVisible")
    CheckedIniWrite(BindListVisible, fileName, "UI", "BindListVisible")
    CheckedIniWrite(SettingsVisible, fileName, "UI", "SettingsVisible")
    CheckedIniWrite(SettingsTargetTab, fileName, "UI", "SettingsTargetTab")
    CheckedIniWrite(SettingsPage, fileName, "UI", "SettingsPage")
    CheckedIniWrite(SettingsX, fileName, "UI", "SettingsX")
    CheckedIniWrite(SettingsY, fileName, "UI", "SettingsY")
    CheckedIniWrite(SettingsW, fileName, "UI", "SettingsW")
    CheckedIniWrite(SettingsH, fileName, "UI", "SettingsH")
    return !ConfigWriteFailed
}

SaveUISettings() {
    global ConfigFile, UiPreviewMode
    if (ConfigFile = "" || UiPreviewMode || ConfigTransactionBusy)
        return false
    target := ConfigStage(ConfigFile)
    if (target = "")
        return false
    WriteUIAppearanceToIni(target)
    WriteUISafetyAndAudioToIni(target)
    WriteUIWindowPrefsToIni(target)
    return ConfigCommit(target, ConfigFile)
}

LoadUISettings() {
    global ConfigFile
    if (ConfigFile = "")
        return
    LoadUIAppearanceFromIni(ConfigFile)
    LoadUISafetyAndAudioFromIni(ConfigFile)
    LoadUIWindowPrefsFromIni(ConfigFile)
    NormalizeLoadedUISettings()
    ResolveBackgroundImage()
    UpdateLawGuiColors()
}

LoadHudWindowStateFromIni(fileName) {
    global HudX, HudY, HUDVisible

    IniRead, HudX, %fileName%, WINDOW_HUD, X, %HudX%
    IniRead, HudY, %fileName%, WINDOW_HUD, Y, %HudY%
    IniRead, HUDVisible, %fileName%, WINDOW_HUD, Visible, %HUDVisible%
}

LoadBindListWindowStateFromIni(fileName) {
    global BindListX, BindListY, BindListW, BindListH, BindListVisible

    IniRead, BindListX, %fileName%, WINDOW_BINDLIST, X, %BindListX%
    IniRead, BindListY, %fileName%, WINDOW_BINDLIST, Y, %BindListY%
    IniRead, BindListW, %fileName%, WINDOW_BINDLIST, W, %BindListW%
    IniRead, BindListH, %fileName%, WINDOW_BINDLIST, H, %BindListH%
    IniRead, BindListVisible, %fileName%, WINDOW_BINDLIST, Visible, %BindListVisible%
}

LoadSettingsWindowStateFromIni(fileName) {
    global SettingsX, SettingsY, SettingsW, SettingsH, SettingsVisible, SettingsTargetTab, SettingsPage

    IniRead, SettingsX, %fileName%, WINDOW_SETTINGS, X, %SettingsX%
    IniRead, SettingsY, %fileName%, WINDOW_SETTINGS, Y, %SettingsY%
    IniRead, SettingsW, %fileName%, WINDOW_SETTINGS, W, %SettingsW%
    IniRead, SettingsH, %fileName%, WINDOW_SETTINGS, H, %SettingsH%
    IniRead, SettingsVisible, %fileName%, WINDOW_SETTINGS, Visible, %SettingsVisible%
    IniRead, SettingsTargetTab, %fileName%, WINDOW_SETTINGS, Tab, %SettingsTargetTab%
    IniRead, SettingsPage, %fileName%, WINDOW_SETTINGS, Page, % SettingsPageIdFromLegacyTab(SettingsTargetTab)
}

ChatQueue_Clear(showStatus := 1) {
    global ChatQueueItems, ChatQueueBusy, ChatQueueNextSendTick, ChatQueueLastSendTick
    ChatQueueItems := []
    AutomationEpoch++
    ChatQueue_CancelBatches()
    ChatQueueNextSendTick := 0
    ChatQueueLastSendTick := 0
    if (showStatus)
    {
        ToolTip, Очередь сообщений очищена.
        SetTimer, RemoveToolTip, -1400
    }
    UpdateHUD()
    UpdateAutomationSettingsStatus()
}

SettingsGui_CanUpdate() {
    global SettingsVisible, SettingsGuiReady, hSettingsWnd
    return SettingsVisible && SettingsGuiReady && hSettingsWnd && DllCall("IsWindow", "Ptr", hSettingsWnd)
}

UpdateAutomationSettingsStatus() {
    global SafeModeEnabled, MockMode, CFG_AutoReportStatus, SettingsGuiReady
    if !SettingsGui_CanUpdate()
        return
    queueText := "Очередь: " . ChatQueue_StatusText()
    taskText := "Задачи: " . TaskScheduler_StatusText()
    safeText := "SafeMode: " . SafeModeEnabled . "   |   MockMode: " . MockMode . "   |   Чат: " . ChatTransport_GetDisplayStatus()
    try
    {
        GuiControl, 2:, CFG_AutomationQueueStatus, %queueText%
        GuiControl, 2:, CFG_AutomationTaskStatus, %taskText%
        GuiControl, 2:, CFG_AutomationSafeStatus, %safeText%
        CFG_AutoReportStatus := AutoReport_GetStatusText()
        GuiControl, 2:, CFG_AutoReportStatus, %CFG_AutoReportStatus%
    }
    catch e
        SettingsGuiReady := 0
}

RunBackgroundTool(argName, reportName) {
    global PendingToolPid, PendingToolReport, PendingToolHandle
    if (PendingToolPid)
    {
        ToolTip, Проверка уже выполняется.
        SetTimer, RemoveToolTip, -1400
        return false
    }
    reportPath := A_ScriptDir . "\" . reportName
    FileDelete, %reportPath%
    if FileExist(reportPath)
        return false
    q := Chr(34)
    cmd := A_IsCompiled ? q . A_ScriptFullPath . q . " /f " . argName
        : q . A_AhkPath . q . " /f /CP1251 " . q . A_ScriptFullPath . q . " " . argName
    Run, %cmd%, %A_ScriptDir%, Hide UseErrorLevel, childPid
    if (ErrorLevel || !childPid)
        return false
    PendingToolHandle := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", childPid, "Ptr")
    PendingToolPid := childPid
    PendingToolReport := A_ScriptDir . "\" . reportName
    SetTimer, BackgroundToolPoll, 500
    return true
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
    NormalizeNumberRange(BindListW, 520, 420, 720)
    NormalizeNumberRange(BindListH, 390, 300, 700)
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

LoadWindowStates() {
    global ConfigFile
    if (ConfigFile = "")
        return
    LoadHudWindowStateFromIni(ConfigFile)
    LoadBindListWindowStateFromIni(ConfigFile)
    LoadSettingsWindowStateFromIni(ConfigFile)
    NormalizeWindowStates()
}

WriteHudWindowStateToIni(fileName) {
    global HudX, HudY, HUDVisible
    CheckedIniWrite(HudX, fileName, "WINDOW_HUD", "X")
    CheckedIniWrite(HudY, fileName, "WINDOW_HUD", "Y")
    CheckedIniWrite(HUDVisible, fileName, "WINDOW_HUD", "Visible")
    return !ConfigWriteFailed
}

WriteBindListWindowStateToIni(fileName) {
    global BindListX, BindListY, BindListW, BindListH, BindListVisible
    CheckedIniWrite(BindListX, fileName, "WINDOW_BINDLIST", "X")
    CheckedIniWrite(BindListY, fileName, "WINDOW_BINDLIST", "Y")
    CheckedIniWrite(BindListW, fileName, "WINDOW_BINDLIST", "W")
    CheckedIniWrite(BindListH, fileName, "WINDOW_BINDLIST", "H")
    CheckedIniWrite(BindListVisible, fileName, "WINDOW_BINDLIST", "Visible")
    return !ConfigWriteFailed
}

WriteSettingsWindowStateToIni(fileName) {
    global SettingsX, SettingsY, SettingsW, SettingsH, SettingsVisible, SettingsTargetTab, SettingsPage
    CheckedIniWrite(SettingsX, fileName, "WINDOW_SETTINGS", "X")
    CheckedIniWrite(SettingsY, fileName, "WINDOW_SETTINGS", "Y")
    CheckedIniWrite(SettingsW, fileName, "WINDOW_SETTINGS", "W")
    CheckedIniWrite(SettingsH, fileName, "WINDOW_SETTINGS", "H")
    CheckedIniWrite(SettingsVisible, fileName, "WINDOW_SETTINGS", "Visible")
    CheckedIniWrite(SettingsTargetTab, fileName, "WINDOW_SETTINGS", "Tab")
    CheckedIniWrite(SettingsPage, fileName, "WINDOW_SETTINGS", "Page")
    return !ConfigWriteFailed
}

SaveHUDWindowState() {
    global ConfigFile, UiPreviewMode
    if (ConfigFile = "" || UiPreviewMode)
        return
    WriteHudWindowStateToIni(ConfigFile)
}

SaveBindListWindowState() {
    global ConfigFile, UiPreviewMode
    if (ConfigFile = "" || UiPreviewMode)
        return
    WriteBindListWindowStateToIni(ConfigFile)
}

SaveSettingsWindowState() {
    global ConfigFile, UiPreviewMode
    if (ConfigFile = "" || UiPreviewMode)
        return
    WriteSettingsWindowStateToIni(ConfigFile)
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

RequestIndependentGuiState(targetHUD, targetBindList, targetSettings, settingsTab := 1) {
    SetPendingGuiStateValues(targetHUD, targetBindList, targetSettings)
    ApplyPendingGuiState(settingsTab)
    SetTimer, EnforceIndependentGuiState, -80
}

EnforceIndependentGuiState:
global SettingsTargetTab
ApplyPendingGuiState(SettingsTargetTab)
ClearPendingGuiStateValues()
return

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
        path := A_ScriptDir . "\" . path
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
    hudAlpha := HUDTransparency
    NormalizeNumberRange(hudAlpha, 245, 180, 255)

    if (HUDMode = "Компактный")
        hudW := 280, hudH := 138
    else if (HUDMode = "Профиль + ID")
        hudW := 280, hudH := 112
    else
        hudW := 304, hudH := 186

    hudRight := hudW - 2
    hudBottom := hudH - 2
    accentH := hudH - 20
    valueX := 100
    valueW := hudW - valueX - 12
    labelW := 64
    lineW := hudW - 40

    Gui, 12:Destroy
    Gui, 12:+HwndhHUDWnd +AlwaysOnTop -Caption +ToolWindow +LastFound
    Gui, 12:Color, %panel%
    Gui, 12:Margin, 0, 0
    SafePicture(12, 0, 0, hudW, hudH, "HUDBG", BackgroundImageFile)
    Gui, 12:Add, Progress, -Theme x0 y0 w%hudW% h2 Disabled Background%panel% c%accent% vHUDBorderTop, 100
    Gui, 12:Add, Progress, -Theme x0 y%hudBottom% w%hudW% h2 Disabled Background%panel% c%accent% vHUDBorderBottom, 100
    Gui, 12:Add, Progress, -Theme x0 y0 w2 h%hudH% Disabled Vertical Background%panel% c%accent% vHUDBorderLeft, 100
    Gui, 12:Add, Progress, -Theme x%hudRight% y0 w2 h%hudH% Disabled Vertical Background%panel% c%accent% vHUDBorderRight, 100
    Gui, 12:Add, Progress, -Theme x8 y10 w4 h%accentH% Disabled Vertical Background%panel% c%accent%, 100
    Gui, 12:Add, Text, x0 y0 w%hudW% h34 vHUDDragZone gStartHUDDrag BackgroundTrans,

    Gui, 12:Font, s10 Bold c%text%, Segoe UI
    Gui, 12:Add, Text, x20 y10 gStartHUDDrag w%lineW% h22 +0x4000 BackgroundTrans, %TabGuiHeaderText%
    Gui, 12:Font, Norm s7 c%muted%, Segoe UI
    Gui, 12:Add, Text, x20 y36 w%lineW% h16 BackgroundTrans, Статус персонажа

    rowY := 60
    Gui, 12:Font, Norm s8 c%muted%, Segoe UI
    if (HUDMode != "Профиль + ID")
    {
        Gui, 12:Add, Text, x20 y%rowY% w%labelW% h18 BackgroundTrans, Время
        rowY += 24
    }
    Gui, 12:Add, Text, x20 y%rowY% w%labelW% h18 BackgroundTrans, Профиль
    rowY += 24
    Gui, 12:Add, Text, x20 y%rowY% w%labelW% h18 BackgroundTrans, Цель
    if (HUDMode = "Полный")
    {
        rowY += 24
        Gui, 12:Add, Text, x20 y%rowY% w%labelW% h18 BackgroundTrans, Меню
        rowY += 24
        Gui, 12:Add, Text, x20 y%rowY% w%labelW% h18 BackgroundTrans, Бинды
    }

    rowY := 60
    Gui, 12:Font, s8 Bold c%text%, Segoe UI
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
        GuiControl, 12:, HUDTimeText, %timeNow%
    GuiControl, 12:, HUDProfileText, %CurrentProfile%
    GuiControl, 12:, HUDIDText, %currentTarget%

    if (HUDMode = "Полный")
    {
        GuiControl, 12:, HUDMenuText, %Bind_OpenSettings%
        GuiControl, 12:, HUDBindListText, %Bind_ToggleBindList%
    }
    UpdateAutomationSettingsStatus()
}

GetDynamicGlobalValue(varName, fallback := "") {
    global
    if (varName = "")
        return fallback
    value := %varName%
    if (value = "ERROR")
        return fallback
    return value
}

IsBindFieldFilled(val) {
    val := Trim(val)
    return !(val = "" or val = "ERROR" or val = "—")
}

NormalizeCustomFunctionTrigger(value) {
    value := Trim(value)
    if (value = "" || value = "ERROR")
        return ""
    if (SubStr(value, 1, 1) != "!")
        value := "!" . value
    StringLower, value, value
    return value
}

NormalizeCustomFunctionName(value, fallback := "Новая функция") {
    value := Trim(value)
    value := StrReplace(value, "|", "/")
    value := RegExReplace(value, "[\r\n\t]+", " ")
    if (value = "")
        value := fallback
    if (StrLen(value) > 60)
        value := SubStr(value, 1, 60)
    return value
}

CreateDefaultCustomFunction() {
    return {Name: "Пример: RP с паузой", Hotkey: "", Trigger: "", Script: "SEND /me начал выполнять действие.`nWAIT 1000`nSEND /do Действие продолжается.`nTIMER 15|Контроль времени`nNOTICE Пользовательская функция запущена."}
}

LoadCustomFunctions() {
    global CustomFunctionsFile, CustomFunctions, CustomFunctionMaxCount
    CustomFunctions := []
    IniRead, count, %CustomFunctionsFile%, General, Count, 0
    NormalizeNumberRange(count, 0, 0, CustomFunctionMaxCount)
    Loop % count
    {
        section := "Function" . A_Index
        name := IniReadText(CustomFunctionsFile, section, "Name", "Функция " . A_Index)
        IniRead, hotkeyValue, %CustomFunctionsFile%, %section%, Hotkey,
        triggerValue := IniReadText(CustomFunctionsFile, section, "Trigger", "")
        scriptValue := IniReadText(CustomFunctionsFile, section, "Script", "")
        name := NormalizeCustomFunctionName(name, "Функция " . A_Index)
        triggerValue := NormalizeCustomFunctionTrigger(triggerValue)
        CustomFunctions.Push({Name: name, Hotkey: Trim(hotkeyValue), Trigger: triggerValue, Script: scriptValue})
    }
    if (CustomFunctions.Length() = 0)
        CustomFunctions.Push(CreateDefaultCustomFunction())
}

SaveCustomFunctions() {
    global CustomFunctionsFile, CustomFunctions
    stage := ConfigStage(CustomFunctionsFile)
    if (stage = "")
        return false
    count := IsObject(CustomFunctions) ? CustomFunctions.Length() : 0
    CheckedIniWrite(count, stage, "General", "Count")
    Loop % count {
        item := CustomFunctions[A_Index]
        section := "Function" . A_Index
        IniWriteText(item.Name, stage, section, "Name")
        CheckedIniWrite(item.Hotkey, stage, section, "Hotkey")
        IniWriteText(item.Trigger, stage, section, "Trigger")
        IniWriteText(item.Script, stage, section, "Script")
    }
    return ConfigCommit(stage, CustomFunctionsFile)
}

CustomFunction_HotkeyAllowed() {
    global GameProcessName, CustomFunctionGuiVisible, BindMenuEditMode
    if (CustomFunctionGuiVisible || BindMenuEditMode)
        return false
    if !WinActive("ahk_exe " . GameProcessName)
        return false
    return (isInChat() != 1)
}

ClearCustomFunctionHotkeys() {
    global CustomFunctionRegisteredHotkeys, CustomFunctionHotkeyMap, CustomFunctionHotkeyContext
    if IsObject(CustomFunctionRegisteredHotkeys)
    {
        Hotkey, If, % CustomFunctionHotkeyContext
        Loop % CustomFunctionRegisteredHotkeys.Length()
        {
            hk := CustomFunctionRegisteredHotkeys[A_Index]
            if (hk != "")
                Hotkey, %hk%, DispatchCustomFunctionHotkey, Off UseErrorLevel
        }
        Hotkey, If
    }
    CustomFunctionRegisteredHotkeys := []
    CustomFunctionHotkeyMap := {}
}

ApplyCustomFunctionHotkeys(ByRef ok, ByRef errText, ByRef usedKeys) {
    global CustomFunctions, CustomFunctionRegisteredHotkeys, CustomFunctionHotkeyMap, CustomFunctionHotkeyContext
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        hk := Trim(fn.Hotkey)
        if (hk = "" || hk = "ERROR")
            continue
        keyId := NormalizeHotkeyId(hk)
        if (keyId = "")
            continue
        owner := "Пользовательская функция «" . fn.Name . "»"
        if (usedKeys.HasKey(keyId))
        {
            errText .= owner . " = " . hk . "  -> дубликат с """ . usedKeys[keyId] . """`n"
            ok := 0
            continue
        }
        Hotkey, If, % CustomFunctionHotkeyContext
        Hotkey, %hk%, DispatchCustomFunctionHotkey, On UseErrorLevel
        registerError := ErrorLevel
        Hotkey, If
        if (registerError)
        {
            errText .= owner . " = " . hk . "  -> неверный hotkey`n"
            ok := 0
            continue
        }
        usedKeys[keyId] := owner
        CustomFunctionHotkeyMap[keyId] := A_Index
        CustomFunctionRegisteredHotkeys.Push(hk)
    }
}

ApplyCustomFunctionTextTriggers(ByRef ok, ByRef errText, ByRef usedTriggers) {
    global CustomFunctions
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        trig := NormalizeCustomFunctionTrigger(fn.Trigger)
        if (trig = "")
            continue
        keyId := trig
        StringLower, keyId, keyId
        owner := "Пользовательская функция «" . fn.Name . "»"
        if (usedTriggers.HasKey(keyId))
        {
            errText .= owner . " = " . trig . "  -> дубликат с """ . usedTriggers[keyId] . """`n"
            ok := 0
            continue
        }
        try
        {
            cb := Func("RunCustomFunctionTrigger").Bind(A_Index)
            Hotstring(":?:" . trig, cb, "On")
            TrackRegisteredGameTextHotstring(":?:" . trig)
            usedTriggers[keyId] := owner
        }
        catch e
        {
            errText .= owner . " = " . trig . "  -> неверный TXT-триггер`n"
            ok := 0
        }
    }
}

RunCustomFunctionTrigger(index) {
    RunCustomFunction(index)
    return ""
}

CustomFunction_Parse(scriptText, ByRef errorText) {
    steps := []
    errorText := ""
    scriptText := StrReplace(scriptText, "`r`n", "`n")
    scriptText := StrReplace(scriptText, "`r", "`n")
    lineNo := 0
    Loop, Parse, scriptText, `n
    {
        lineNo += 1
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "i)^WAIT\s+(\d+)$", m)
        {
            waitMs := m1 + 0
            NormalizeNumberRange(waitMs, 1000, 0, 300000)
            steps.Push({Type: "WAIT", Value: waitMs})
        }
        else if RegExMatch(line, "i)^TIMER\s+(\d+)(?:\|(.*))?$", m)
        {
            seconds := m1 + 0
            NormalizeNumberRange(seconds, 15, 1, 3600)
            label := Trim(m2)
            steps.Push({Type: "TIMER", Value: seconds, Label: label})
        }
        else if RegExMatch(line, "i)^NOTICE\s+(.+)$", m)
            steps.Push({Type: "NOTICE", Value: m1})
        else if RegExMatch(line, "i)^(?:TYPE|OPEN)\s+(.+)$", m)
            steps.Push({Type: "TYPE", Value: m1})
        else if RegExMatch(line, "i)^(?:SEND|CHAT)\s+(.+)$", m)
            steps.Push({Type: "SEND", Value: m1})
        else if RegExMatch(line, "i)^STOP$", m)
            steps.Push({Type: "STOP", Value: ""})
        else if RegExMatch(line, "i)^[A-Z_]+(?:\s|$)")
        {
            errorText := "Строка " . lineNo . ": неизвестная команда."
            return []
        }
        else
            steps.Push({Type: "SEND", Value: line})
        if (steps.Length() > 120)
        {
            errorText := "Слишком много шагов. Максимум: 120."
            return []
        }
    }
    if (steps.Length() = 0)
        errorText := "Функция не содержит выполняемых шагов."
    return steps
}

RunCustomFunction(index) {
    global CustomFunctions, CustomFunctionRunState
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return false
    if IsObject(CustomFunctionRunState)
    {
        GameNotify("Уже выполняется функция «" . CustomFunctionRunState.Name . "». Останови её в конструкторе.", "WARN")
        return false
    }
    fn := CustomFunctions[index]
    errorText := ""
    steps := CustomFunction_Parse(fn.Script, errorText)
    if (errorText != "")
    {
        GameNotify("Ошибка функции «" . fn.Name . "»: " . errorText, "ERROR")
        return false
    }
    CustomFunctionRunState := {Name: fn.Name, Steps: steps, Index: 1, NextTick: TickNow(), WaitingForQueue: 0, Epoch: AutomationEpoch, Profile: CurrentProfile, Target: UserID, Failures: QueueFailureGeneration}
    SetTimer, CustomFunctionRunnerTick, 60
    GameNotify("Запущена функция: " . fn.Name)
    return true
}

StopCustomFunctionRun(showNotice := 1) {
    global CustomFunctionRunState
    SetTimer, CustomFunctionRunnerTick, Off
    wasActive := IsObject(CustomFunctionRunState)
    CustomFunctionRunState := ""
    if (showNotice && wasActive)
        GameNotify("Пользовательская функция остановлена.", "WARN")
}

CustomFunction_InputIsCurrent(state) {
    global CustomFunctionRunState, AutomationEpoch, CurrentProfile, UserID, QueueFailureGeneration
    return IsObject(state) && IsObject(CustomFunctionRunState) && CustomFunctionRunState == state
        && state.Epoch = AutomationEpoch && state.Profile = CurrentProfile && state.Target = UserID
        && state.Failures = QueueFailureGeneration
}

CustomFunction_StopIfCurrent(state) {
    global CustomFunctionRunState
    if (IsObject(CustomFunctionRunState) && CustomFunctionRunState == state)
        StopCustomFunctionRun(0)
}

CustomFunctionRunner_Process(inputEpoch := 0) {
    global CustomFunctionRunState, ChatQueueBusy, StopTimerActive, StopTimerCounter, StopTimerLabel
    inputEpoch := AutomationEpoch
    if !IsObject(CustomFunctionRunState)
    {
        SetTimer, CustomFunctionRunnerTick, Off
        return
    }
    state := CustomFunctionRunState
    if (state.Epoch != AutomationEpoch || state.Failures != QueueFailureGeneration || state.Profile != CurrentProfile || state.Target != UserID) {
        StopCustomFunctionRun(0)
        return
    }
    if (PhysicalInputBusy || IsObject(IDCaptureState))
        return
    if (state.NextTick > TickNow())
        return
    if (state.WaitingForQueue)
    {
        if (ChatQueue_Count() > 0 || ChatQueueBusy)
            return
        state.WaitingForQueue := 0
    }
    Loop, 20
    {
        if !CustomFunction_InputIsCurrent(state) {
            CustomFunction_StopIfCurrent(state)
            return
        }
        if (state.Index > state.Steps.Length())
        {
            completedName := state.Name
            StopCustomFunctionRun(0)
            GameNotify("Функция завершена: " . completedName)
            return
        }
        step := state.Steps[state.Index]
        state.Index += 1
        if (step.Type = "WAIT")
        {
            state.NextTick := TickNow() + step.Value
            return
        }
        if (step.Type = "SEND")
        {
            if (ChatQueue_Count() > 0 || ChatQueueBusy)
            {
                state.Index -= 1
                return
            }
            text := ApplyActionTemplate(step.Value)
            if (ChatQueue_Enqueue(text, "CustomFunction." . state.Name, 0, 0, 1)) {
                state.WaitingForQueue := 1
            } else {
                state.Index -= 1
                state.NextTick := TickNow() + 1000
                LogError("CustomFunction", "Очередь отклонила строку функции «" . state.Name . "».", "WARN")
            }
            return
        }
        if (step.Type = "NOTICE")
        {
            GameNotify(ApplyActionTemplate(step.Value))
            continue
        }
        if (step.Type = "TIMER")
        {
            StopTimerActive := 1
            StopTimerCounter := step.Value
            StopTimerLabel := ApplyActionTemplate(step.Label)
            ShowStopTimerGUI()
            if (StopTimerLabel != "")
                GameNotify(StopTimerLabel . ": " . step.Value . " сек.")
            continue
        }
        if (step.Type = "TYPE")
        {
            if (MockMode = "On" || AuditTestMode) {
                MockPreview_Append("[TYPE] " . ApplyActionTemplate(step.Value))
                continue
            }
            if !EnsureGameActive()
            {
                state.Index -= 1
                return
            }
            if !CustomFunction_InputIsCurrent(state) {
                CustomFunction_StopIfCurrent(state)
                return
            }
            if (PhysicalInputBusy || IsObject(IDCaptureState)) {
                state.Index -= 1
                return
            }
            if !TypeChatForEpoch(inputEpoch, ApplyActionTemplate(step.Value), Func("CustomFunction_InputIsCurrent").Bind(state)) {
                CustomFunction_StopIfCurrent(state)
                LogError("CustomFunction", "Ввод текста не завершён; зависимые шаги отменены.", "WARN")
                return
            }
            continue
        }
        if (step.Type = "STOP")
        {
            StopCustomFunctionRun(0)
            return
        }
    }
}

AppendCustomFunctionBindRows(ByRef rows) {
    global CustomFunctions
    if !IsObject(CustomFunctions)
        return
    Loop % CustomFunctions.Length()
    {
        fn := CustomFunctions[A_Index]
        hk := ShowHotkeyValue(fn.Hotkey)
        trig := ShowTriggerValue(fn.Trigger)
        hasHotkey := IsBindFieldFilled(hk)
        hasTrigger := IsBindFieldFilled(trig)
        if (!hasHotkey && !hasTrigger)
            continue
        bindValue := hasHotkey ? hk : ""
        if (hasTrigger)
            bindValue .= (bindValue != "" ? " | " : "") . "! " . trig
        status := (hasHotkey && hasTrigger) ? "[MIX] Hotkey + !" : (hasHotkey ? "[HK] Hotkey" : "[TXT] ! Триггер")
        rows.Push({Token: "CustomFunction:" . A_Index, Label: fn.Name, Category: "Свои функции", Hotkey: hk, Trigger: trig, BindValue: bindValue, Status: status})
    }
}

CustomFunctionBuilder_ListText() {
    global CustomFunctions
    listText := ""
    if !IsObject(CustomFunctions)
        return listText
    Loop % CustomFunctions.Length()
    {
        name := NormalizeCustomFunctionName(CustomFunctions[A_Index].Name, "Функция " . A_Index)
        listText .= (listText = "" ? "" : "|") . name
    }
    return listText
}

CustomFunctionBuilder_RefreshList(selectIndex := 1) {
    global CustomFunctions, CustomFunctionSelected
    count := IsObject(CustomFunctions) ? CustomFunctions.Length() : 0
    if (count <= 0)
    {
        CustomFunctions := [CreateDefaultCustomFunction()]
        count := 1
    }
    if (selectIndex < 1 || selectIndex > count)
        selectIndex := 1
    listText := CustomFunctionBuilder_ListText()
    GuiControl, 40:, CFB_List, % "|" . listText
    GuiControl, 40:Choose, CFB_List, %selectIndex%
    CustomFunctionSelected := selectIndex
    CustomFunctionBuilder_LoadSelection(selectIndex)
}

CustomFunctionBuilder_LoadSelection(index) {
    global CustomFunctions, CustomFunctionSelected
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return
    fn := CustomFunctions[index]
    CustomFunctionSelected := index
    GuiControl, 40:, CFB_Name, % fn.Name
    GuiControl, 40:, CFB_Hotkey, % fn.Hotkey
    GuiControl, 40:, CFB_Trigger, % fn.Trigger
    GuiControl, 40:, CFB_Script, % fn.Script
    GuiControl, 40:, CFB_Status, % "Шагов можно до 120. Строка без команды считается SEND."
}

CustomFunctionBuilder_StoreFields(index) {
    global CustomFunctions, CFB_Name, CFB_Hotkey, CFB_Trigger, CFB_Script
    index += 0
    if !IsObject(CustomFunctions) || index < 1 || index > CustomFunctions.Length()
        return false
    CustomFunctions[index] := {Name: NormalizeCustomFunctionName(CFB_Name, "Функция " . index), Hotkey: Trim(CFB_Hotkey), Trigger: NormalizeCustomFunctionTrigger(CFB_Trigger), Script: CFB_Script}
    return true
}

CustomFunctionBuilder_SaveCurrent(applyBinds := 1) {
    global CustomFunctions, CustomFunctionSelected, CFB_Name, CFB_Hotkey, CFB_Trigger, CFB_Script
    Gui, 40:Submit, NoHide
    index := CustomFunctionSelected
    if (index < 1 || index > CustomFunctions.Length())
        return false
    name := NormalizeCustomFunctionName(CFB_Name, "Функция " . index)
    triggerValue := NormalizeCustomFunctionTrigger(CFB_Trigger)
    errorText := ""
    CustomFunction_Parse(CFB_Script, errorText)
    if (errorText != "")
    {
        GuiControl, 40:, CFB_Status, % "Ошибка: " . errorText
        Notify("warn")
        return false
    }
    previous := CustomFunctions[index]
    CustomFunctions[index] := {Name: name, Hotkey: Trim(CFB_Hotkey), Trigger: triggerValue, Script: CFB_Script}
    if !SaveCustomFunctions() {
        CustomFunctions[index] := previous
        GuiControl, 40:, CFB_Status, Ошибка записи. Изменения не сохранены.
        return false
    }
    CustomFunctionBuilder_RefreshList(index)
    if (applyBinds)
        ApplyAllBinds()
    GuiControl, 40:, CFB_Status, Сохранено. Hotkey работает только в игре и при закрытом чате.
    return true
}

CustomFunctionBuilder_AppendStep(text) {
    global CFB_Script, hCFBScript
    GuiControlGet, CFB_Script, 40:, CFB_Script
    if (CFB_Script != "" && SubStr(CFB_Script, 0) != "`n")
        CFB_Script .= "`r`n"
    CFB_Script .= text
    GuiControl, 40:, CFB_Script, %CFB_Script%
    if (hCFBScript)
        SendMessage, 0xB1, -1, -1,, ahk_id %hCFBScript%
}

OpenCustomFunctionBuilder(selectIndex := 1) {
    global hCustomFunctionWnd, CustomFunctionGuiVisible, CustomFunctionSelected
    global UIRoundness, InnerRoundness, GuiTransparency, CustomMenuColor, CustomTextColor
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    if (CustomMenuColor != "")
        panel := CustomMenuColor
    if (CustomTextColor != "")
        text := CustomTextColor
    controlBg := "", controlText := "", cardBg := "", cardEdge := ""
    GetControlSurfaceColors(controlBg, controlText, cardBg, cardEdge, panel, text, accent)

    Gui, 40:Destroy
    Gui, 40:+HwndhCustomFunctionWnd +AlwaysOnTop -Resize
    Gui, 40:Color, %bg%, %controlBg%
    Gui, 40:Margin, 0, 0
    Gui, 40:Add, Progress, -Theme x0 y0 w940 h4 Disabled Background%bg% c%accent%, 100
    Gui, 40:Font, s15 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x20 y14 w560 h30 BackgroundTrans, Конструктор функций
    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x20 y44 w880 h18 BackgroundTrans, Собирай последовательности из сообщений, пауз, таймеров и уведомлений. Hotkey действует только в игре при закрытом чате.
    Gui, 40:Add, Progress, -Theme x18 y70 w904 h1 Disabled Background%bg% c%cardEdge%, 100

    AddOutlinedPanel(40, 18, 84, 238, 500, cardBg, cardEdge, 1)
    AddOutlinedPanel(40, 270, 84, 652, 500, cardBg, cardEdge, 1)

    Gui, 40:Font, s9 Bold c%text%, Segoe UI
    Gui, 40:Add, Text, x32 y98 w210 h20 BackgroundTrans, МОИ ФУНКЦИИ
    Gui, 40:Font, Norm s9 c%controlText%, Segoe UI
    Gui, 40:Add, ListBox, x32 y126 w210 h402 vCFB_List gCustomFunctionListChanged AltSubmit
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x32 y540 w98 h30 gCustomFunctionNewLabel, Новая
    Gui, 40:Add, Button, x144 y540 w98 h30 gCustomFunctionDeleteLabel, Удалить

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y100 w250 h18 BackgroundTrans, Название
    Gui, 40:Add, Text, x552 y100 w150 h18 BackgroundTrans, Hotkey
    Gui, 40:Add, Text, x718 y100 w184 h18 BackgroundTrans, TXT-триггер
    Gui, 40:Font, Norm s9 c%controlText%, Segoe UI
    Gui, 40:Add, Edit, x286 y120 w250 h28 vCFB_Name
    Gui, 40:Add, Hotkey, x552 y120 w150 h28 vCFB_Hotkey
    Gui, 40:Add, Edit, x718 y120 w184 h28 vCFB_Trigger

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y164 w616 h18 BackgroundTrans, Сценарий
    Gui, 40:Font, Norm s9 c%controlText%, Consolas
    Gui, 40:Add, Edit, x286 y184 w616 h302 vCFB_Script hwndhCFBScript WantTab -Wrap Background%controlBg%

    Gui, 40:Font, Norm s8 c%text%, Segoe UI
    Gui, 40:Add, Button, x286 y500 w88 h28 gCustomFunctionAddSendLabel, + SEND
    Gui, 40:Add, Button, x380 y500 w88 h28 gCustomFunctionAddWaitLabel, + Пауза
    Gui, 40:Add, Button, x474 y500 w88 h28 gCustomFunctionAddTimerLabel, + Таймер
    Gui, 40:Add, Button, x568 y500 w104 h28 gCustomFunctionAddNoticeLabel, + Уведомл.
    Gui, 40:Add, Button, x678 y500 w88 h28 gCustomFunctionAddTypeLabel, + TYPE
    Gui, 40:Add, Button, x772 y500 w130 h28 gCustomFunctionAddIDLabel, + Переменная ID

    Gui, 40:Font, Norm s8 c%muted%, Segoe UI
    Gui, 40:Add, Text, x286 y542 w616 h20 vCFB_Status BackgroundTrans,
    Gui, 40:Font, Norm s9 c%text%, Segoe UI
    Gui, 40:Add, Button, x286 y594 w132 h32 gCustomFunctionSaveLabel Default, Сохранить
    Gui, 40:Add, Button, x430 y594 w132 h32 gCustomFunctionRunLabel, Запустить
    Gui, 40:Add, Button, x574 y594 w132 h32 gCustomFunctionStopLabel, Остановить
    Gui, 40:Add, Button, x770 y594 w132 h32 gCustomFunctionCloseLabel, Закрыть

    Capture_BeforeShow("40")

    Gui, 40:Show, w940 h644, AHK FOR GOS BY SBEZRUK - Конструктор функций
    CustomFunctionGuiVisible := 1
    if (selectIndex < 1)
        selectIndex := CustomFunctionSelected > 0 ? CustomFunctionSelected : 1
    CustomFunctionBuilder_RefreshList(selectIndex)
    alpha := GuiTransparency
    NormalizeNumberRange(alpha, 245, 180, 255)
    WinSet, Transparent, %alpha%, ahk_id %hCustomFunctionWnd%
    ApplyRoundedCorners(hCustomFunctionWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hCustomFunctionWnd, InnerRoundness)
}

CloseCustomFunctionBuilder(saveCurrent := 0) {
    global CustomFunctionGuiVisible, hCustomFunctionWnd
    if (saveCurrent)
        CustomFunctionBuilder_SaveCurrent(1)
    Gui, 40:Destroy
    CustomFunctionGuiVisible := 0
    hCustomFunctionWnd := 0
}

GetBindCatalog() {
    static catalog := ""
    if IsObject(catalog)
        return catalog

    catalog := []
    catalog.Push({Token: "OpenSettings", Label: "Открыть меню", Category: "Системные", HotkeyVar: "Bind_OpenSettings", TriggerVar: ""})
    catalog.Push({Token: "ToggleBindList", Label: "Показать bind-list", Category: "Системные", HotkeyVar: "Bind_ToggleBindList", TriggerVar: ""})
    catalog.Push({Token: "ToggleLastLawDoc", Label: "Последний закон", Category: "Системные", HotkeyVar: "Bind_ToggleLastLawDoc", TriggerVar: ""})
    catalog.Push({Token: "HideLawGui", Label: "Скрыть окно закона", Category: "Системные", HotkeyVar: "Bind_HideLawGui", TriggerVar: ""})
    catalog.Push({Token: "LawSearchSubmit", Label: "Запустить поиск законов", Category: "Системные", HotkeyVar: "Bind_LawSearchSubmit", TriggerVar: ""})
    catalog.Push({Token: "ToggleHUD", Label: "Показать HUD", Category: "Системные", HotkeyVar: "Bind_ToggleHUD", TriggerVar: ""})
    catalog.Push({Token: "IDOverlay", Label: "ID-плашка", Category: "Системные", HotkeyVar: "Bind_IDOverlay", TriggerVar: ""})
    catalog.Push({Token: "ConfirmID", Label: "Принять найденный ID", Category: "Системные", HotkeyVar: "Bind_ConfirmID", TriggerVar: ""})
    catalog.Push({Token: "RejectID", Label: "Отклонить найденный ID", Category: "Системные", HotkeyVar: "Bind_RejectID", TriggerVar: ""})
    catalog.Push({Token: "EnterID", Label: "Ввести ID вручную", Category: "Системные", HotkeyVar: "Bind_EnterID", TriggerVar: "Trig_EnterID"})
    catalog.Push({Token: "ResetID", Label: "Сброс ID", Category: "Системные", HotkeyVar: "Bind_ResetID", TriggerVar: "Trig_ResetID"})
    catalog.Push({Token: "OpenBindsTab", Label: "Настройки биндов", Category: "Системные", HotkeyVar: "Bind_OpenBindsTab", TriggerVar: "Trig_OpenBindsTab", Hint: "Открыть страницу основных клавиш"})

    catalog.Push({Token: "Intro", Label: "Представление", Category: "Задержание и RP", HotkeyVar: "Bind_Intro", TriggerVar: "Trig_Intro"})
    catalog.Push({Token: "SOS", Label: "SOS", Category: "Задержание и RP", HotkeyVar: "Bind_SOS", TriggerVar: "Trig_SOS"})
    catalog.Push({Token: "Chase", Label: "Chase с ID", Category: "Задержание и RP", HotkeyVar: "Bind_Chase", TriggerVar: "Trig_Chase"})
    catalog.Push({Token: "ChaseNoID", Label: "Chase без ID", Category: "Задержание и RP", HotkeyVar: "Bind_ChaseNoID", TriggerVar: "Trig_ChaseNoID"})
    catalog.Push({Token: "Deject", Label: "Deject", Category: "Задержание и RP", HotkeyVar: "Bind_Deject", TriggerVar: "Trig_Deject"})
    catalog.Push({Token: "Cuff", Label: "Cuff", Category: "Задержание и RP", HotkeyVar: "Bind_Cuff", TriggerVar: "Trig_Cuff"})
    catalog.Push({Token: "InCar", Label: "InCar", Category: "Задержание и RP", HotkeyVar: "Bind_InCar", TriggerVar: "Trig_InCar"})
    catalog.Push({Token: "StopChase", Label: "Остановка", Category: "Задержание и RP", HotkeyVar: "Bind_StopChase", TriggerVar: "Trig_StopChase"})
    catalog.Push({Token: "Doc", Label: "Служебное удостоверение", Category: "Задержание и RP", HotkeyVar: "Bind_Doc", TriggerVar: "Trig_Doc"})
    catalog.Push({Token: "Search", Label: "Досмотр", Category: "Задержание и RP", HotkeyVar: "Bind_Search", TriggerVar: "Trig_Search"})
    catalog.Push({Token: "PersonalFile", Label: "Личное дело", Category: "Задержание и RP", HotkeyVar: "Bind_PersonalFile", TriggerVar: "Trig_PersonalFile"})
    catalog.Push({Token: "Su", Label: "Корректировка розыска", Category: "Задержание и RP", HotkeyVar: "Bind_Su", TriggerVar: "Trig_Su", Hint: "Команда /su и RP-последовательность"})

    catalog.Push({Token: "Dep", Label: "Деп", Category: "Доклады", HotkeyVar: "Bind_Dep", TriggerVar: "Trig_Dep"})
    catalog.Push({Token: "WantedList", Label: "Розыскиваемые", Category: "Доклады", HotkeyVar: "Bind_WantedList", TriggerVar: "Trig_WantedList"})
    catalog.Push({Token: "SOSStart", Label: "SOS выехал", Category: "Доклады", HotkeyVar: "Bind_SOSStart", TriggerVar: "Trig_SOSStart"})
    catalog.Push({Token: "SOSArrive", Label: "SOS прибыл", Category: "Доклады", HotkeyVar: "Bind_SOSArrive", TriggerVar: "Trig_SOSArrive"})
    catalog.Push({Token: "HijackStart", Label: "Угон выехал", Category: "Доклады", HotkeyVar: "Bind_HijackStart", TriggerVar: "Trig_HijackStart", Enabled: 0, ExposeInSettings: 0, LegacyOnly: 1})
    catalog.Push({Token: "HijackArrive", Label: "Угон прибыл", Category: "Доклады", HotkeyVar: "Bind_HijackArrive", TriggerVar: "Trig_HijackArrive", Enabled: 0, ExposeInSettings: 0, LegacyOnly: 1})
    catalog.Push({Token: "CallStart", Label: "ДТП вызов принят", Category: "Доклады", HotkeyVar: "Bind_CallStart", TriggerVar: "Trig_CallStart"})
    catalog.Push({Token: "CallArrive", Label: "ДТП прибыли", Category: "Доклады", HotkeyVar: "Bind_CallArrive", TriggerVar: "Trig_CallArrive"})
    catalog.Push({Token: "CallWorkStart", Label: "ДТП оформление старт", Category: "Доклады", HotkeyVar: "Bind_CallWorkStart", TriggerVar: "Trig_CallWorkStart"})
    catalog.Push({Token: "CallWorkEnd", Label: "ДТП оформление конец", Category: "Доклады", HotkeyVar: "Bind_CallWorkEnd", TriggerVar: "Trig_CallWorkEnd"})
    catalog.Push({Token: "CivilCallStart", Label: "Гражданский вызов принят", Category: "Доклады", HotkeyVar: "Bind_CivilCallStart", TriggerVar: "Trig_CivilCallStart"})
    catalog.Push({Token: "CivilCallArrive", Label: "Гражданский вызов: прибыл", Category: "Доклады", HotkeyVar: "Bind_CivilCallArrive", TriggerVar: "Trig_CivilCallArrive"})
    catalog.Push({Token: "MaskCall", Label: "Маска и звонок", Category: "Доклады", HotkeyVar: "Bind_MaskCall", TriggerVar: "Trig_MaskCall"})
    catalog.Push({Token: "RecordCheck", Label: "Проверка записи", Category: "Доклады", HotkeyVar: "Bind_RecordCheck", TriggerVar: "Trig_RecordCheck"})
    catalog.Push({Token: "TrainCrash", Label: "Крушение поезда", Category: "Доклады", HotkeyVar: "Bind_TrainCrash", TriggerVar: "Trig_TrainCrash"})

    catalog.Push({Token: "PatrolStart", Label: "Патруль старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolStart", TriggerVar: "Trig_PatrolStart"})
    catalog.Push({Token: "PatrolCont", Label: "Патруль прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolCont", TriggerVar: "Trig_PatrolCont"})
    catalog.Push({Token: "PatrolEnd", Label: "Патруль конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_PatrolEnd", TriggerVar: "Trig_PatrolEnd"})
    catalog.Push({Token: "PostStart", Label: "Пост старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostStart", TriggerVar: "Trig_PostStart"})
    catalog.Push({Token: "PostCont", Label: "Пост прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostCont", TriggerVar: "Trig_PostCont"})
    catalog.Push({Token: "PostEnd", Label: "Пост конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_PostEnd", TriggerVar: "Trig_PostEnd"})
    catalog.Push({Token: "AutoPatrol", Label: "Автопатруль · 10 мин", Category: "Транспорт / прочее", HotkeyVar: "Bind_AutoPatrol", TriggerVar: "Trig_AutoPatrol", Hint: "Запрашивает длительность и отправляет доклад каждые 10 минут"})
    catalog.Push({Token: "AutoPost", Label: "Автопост · 10 мин", Category: "Транспорт / прочее", HotkeyVar: "Bind_AutoPost", TriggerVar: "Trig_AutoPost", Hint: "Запрашивает длительность и отправляет доклад каждые 10 минут"})
    catalog.Push({Token: "ConvoyStart", Label: "Колонна старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyStart", TriggerVar: "Trig_ConvoyStart"})
    catalog.Push({Token: "ConvoyCont", Label: "Колонна прод.", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyCont", TriggerVar: "Trig_ConvoyCont"})
    catalog.Push({Token: "ConvoyEnd", Label: "Колонна конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_ConvoyEnd", TriggerVar: "Trig_ConvoyEnd"})
    catalog.Push({Token: "TowStart", Label: "Эвакуация старт", Category: "Транспорт / прочее", HotkeyVar: "Bind_TowStart", TriggerVar: "Trig_TowStart"})
    catalog.Push({Token: "TowEnd", Label: "Эвакуация конец", Category: "Транспорт / прочее", HotkeyVar: "Bind_TowEnd", TriggerVar: "Trig_TowEnd"})
    catalog.Push({Token: "CarSearch", Label: "Осмотр ТС", Category: "Транспорт / прочее", HotkeyVar: "Bind_CarSearch", TriggerVar: "Trig_CarSearch"})
    catalog.Push({Token: "VehicleLookup", Label: "Пробив номера ТС", Category: "Транспорт / прочее", HotkeyVar: "Bind_VehicleLookup", TriggerVar: "Trig_VehicleLookup"})
    catalog.Push({Token: "WantedRemoval", Label: "Снятие розыска", Category: "Задержание и RP", HotkeyVar: "Bind_WantedRemoval", TriggerVar: "Trig_WantedRemoval"})
    catalog.Push({Token: "Arrest", Label: "Арест", Category: "Транспорт / прочее", HotkeyVar: "Bind_Arrest", TriggerVar: "Trig_Arrest"})
    catalog.Push({Token: "Fine", Label: "Штраф", Category: "Транспорт / прочее", HotkeyVar: "Bind_Fine", TriggerVar: "Trig_Fine"})
    catalog.Push({Token: "Protocol", Label: "Протокол", Category: "Транспорт / прочее", HotkeyVar: "Bind_Protocol", TriggerVar: "Trig_Protocol"})
    catalog.Push({Token: "Rights", Label: "Права", Category: "Транспорт / прочее", HotkeyVar: "Bind_Rights", TriggerVar: "Trig_Rights"})
    catalog.Push({Token: "CardDS", Label: "Визитка DS", Category: "Транспорт / прочее", HotkeyVar: "Bind_CardDS", TriggerVar: "Trig_CardDS"})
    catalog.Push({Token: "CardVK", Label: "Визитка VK", Category: "Транспорт / прочее", HotkeyVar: "Bind_CardVK", TriggerVar: "Trig_CardVK"})
    catalog.Push({Token: "MDSFormation", Label: "Строй", Category: "Доклады", HotkeyVar: "Bind_MDSFormation", TriggerVar: "Trig_MDSFormation"})
    catalog.Push({Token: "AssistOOP", Label: "Пробив ООП", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistOOP", TriggerVar: "Trig_AssistOOP", Hint: "Запрос ID и поиск местоположения", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistStun", Label: "Оглушение", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistStun", TriggerVar: "Trig_AssistStun", Hint: "Запрос ID и выбор тазера или дубинки", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistChase", Label: "Преследование", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistChase", TriggerVar: "Trig_AssistChase", Hint: "Запрос ID и автоматический /chase", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistHouse", Label: "Сигнализация дома", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistHouse", TriggerVar: "Trig_AssistHouse", Hint: "Предложение отметить дом в GPS", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistDrugs", Label: "Наркотики рядом", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistDrugs", TriggerVar: "Trig_AssistDrugs", Hint: "Предложение сохранить ID нарушителя", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "AssistPDPCuff", Label: "Наручники после ПДП", Category: "Контекстный помощник", HotkeyVar: "Bind_AssistPDPCuff", TriggerVar: "Trig_AssistPDPCuff", Hint: "Подтверждение наручников после помощи", Safe: "On", Enabled: 0, ExposeInSettings: 0, InternalOnly: 1})
    catalog.Push({Token: "GpsD", Label: "GPS Д", Category: "Транспорт / прочее", HotkeyVar: "", TriggerVar: "Trig_GpsD"})
    catalog.Push({Token: "GpsOS", Label: "GPS ОС", Category: "Транспорт / прочее", HotkeyVar: "", TriggerVar: "Trig_GpsOS"})
    catalog.Push({Token: "VU", Label: "ВУ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VU"})
    catalog.Push({Token: "FP", Label: "ФП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FP"})
    catalog.Push({Token: "KON", Label: "Конст.", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KON"})
    catalog.Push({Token: "FZOP", Label: "ФЗОП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FZOP"})
    catalog.Push({Token: "TER", Label: "Терр.", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_TER"})
    catalog.Push({Token: "TK", Label: "ТК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_TK"})
    catalog.Push({Token: "ARG", Label: "АРГ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ARG"})
    catalog.Push({Token: "UK", Label: "УК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_UK"})
    catalog.Push({Token: "VV", Label: "Вертикаль", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VV"})
    catalog.Push({Token: "KOAP", Label: "КоАП", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KOAP"})
    catalog.Push({Token: "PDD", Label: "ПДД", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_PDD"})
    catalog.Push({Token: "ORUZH", Label: "Оружие", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ORUZH"})
    catalog.Push({Token: "UPK", Label: "УПК", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_UPK"})
    catalog.Push({Token: "KAS", Label: "КАС", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_KAS"})
    catalog.Push({Token: "FSB", Label: "ФЗ о ФСБ", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FSB"})
    catalog.Push({Token: "FSIN", Label: "ФЗ о ФСИН", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_FSIN"})
    catalog.Push({Token: "VS", Label: "Военная служба", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_VS"})
    catalog.Push({Token: "SUD", Label: "Судебная система", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_SUD"})
    catalog.Push({Token: "ORD", Label: "ОРД", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_ORD"})
    catalog.Push({Token: "GT", Label: "Гостайна", Category: "Документы", HotkeyVar: "", TriggerVar: "Trig_GT"})

    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if !meta.HasKey("Handler")
            meta.Handler := meta.Token
        if !meta.HasKey("Hint")
            meta.Hint := meta.Label
        if !meta.HasKey("Safe")
            meta.Safe := "On"
        if !meta.HasKey("TemplateVar")
            meta.TemplateVar := ""
        if !meta.HasKey("Enabled")
            meta.Enabled := 1
        if !meta.HasKey("ExposeInSettings")
            meta.ExposeInSettings := 1
        if !meta.HasKey("InternalOnly")
            meta.InternalOnly := 0
        if !meta.HasKey("LegacyOnly")
            meta.LegacyOnly := 0
        catalog[A_Index] := meta
    }
    return catalog
}

BindCatalog_IsRegistrable(meta) {
    return IsObject(meta) && meta.Enabled && !meta.InternalOnly && !meta.LegacyOnly
}

BindCatalog_IsUserVisible(meta) {
    return BindCatalog_IsRegistrable(meta) && meta.ExposeInSettings
}

GetBindCatalogMap() {
    static tokenMap := ""
    if IsObject(tokenMap)
        return tokenMap

    tokenMap := {}
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        tokenMap[meta.Token] := meta
    }
    return tokenMap
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

CreateBindList() {
    global hBindListWnd, hBindListLV, BindListX, BindListY, BindListW, BindListH, UIRoundness, InnerRoundness, BackgroundImageFile
    global BindListBG, BindListBorderTop, BindListBorderBottom, BindListBorderLeft, BindListBorderRight, BindListDragZone
    global CurrentProfile, CustomBindListColor, CustomTextColor, TabGuiHeaderText, BindListTransparency
    global BindListLV, BindListInfoText, BindListTitleText, BindListProfileText, BindListResizeGripText, BindListRefreshText, BindListCloseText
    global BindListSearch, BindListCategory, BindListSearchEdit, BindListCategoryDDL, hBindListCategoryDDL, BindListCountText

    NormalizeNumberRange(BindListW, 460, 400, 540)
    NormalizeNumberRange(BindListH, 330, 280, 430)

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
    controlBg := "", bindInputText := "", cardBg := "", cardEdge := ""
    GetControlSurfaceColors(controlBg, bindInputText, cardBg, cardEdge, panel, text, accent)

    listW := BindListW - 24
    listH := BindListH - 128
    if (listH < 160)
        listH := 160
    infoY := 100 + listH + 6
    infoW := BindListW - 54
    bindRight := BindListW - 2
    bindBottom := BindListH - 2
    countX := BindListW - 130
    closeX := BindListW - 52
    gripX := BindListW - 34

    Gui, 13:Destroy
    Gui, 13:+HwndhBindListWnd +AlwaysOnTop -Caption +ToolWindow +LastFound +Resize +MinSize400x280 +MaxSize620x520
    Gui, 13:Color, %panel%, %controlBg%
    Gui, 13:Margin, 0, 0
    SafePicture(13, 0, 0, BindListW, BindListH, "BindListBG", BackgroundImageFile)
    Gui, 13:Add, Progress, -Theme x0 y0 w%BindListW% h2 Disabled Background%panel% c%accent% vBindListBorderTop, 100
    Gui, 13:Add, Progress, -Theme x0 y%bindBottom% w%BindListW% h2 Disabled Background%panel% c%accent% vBindListBorderBottom, 100
    Gui, 13:Add, Progress, -Theme x0 y0 w2 h%BindListH% Disabled Vertical Background%panel% c%accent% vBindListBorderLeft, 100
    Gui, 13:Add, Progress, -Theme x%bindRight% y0 w2 h%BindListH% Disabled Vertical Background%panel% c%accent% vBindListBorderRight, 100
    Gui, 13:Add, Progress, -Theme x10 y10 w4 h40 Disabled Vertical Background%panel% c%accent%, 100
    Gui, 13:Add, Text, x0 y0 w%BindListW% h48 vBindListDragZone gStartBindListDrag BackgroundTrans,

    Gui, 13:Font, s10 Bold c%text%, Segoe UI
    Gui, 13:Add, Text, x22 y8 w260 h20 vBindListTitleText gStartBindListDrag BackgroundTrans, БИНДЫ
    Gui, 13:Font, Norm s8 c%muted%, Segoe UI
    Gui, 13:Add, Text, x22 y29 w280 h16 vBindListProfileText gStartBindListDrag BackgroundTrans, %CurrentProfile%
    Gui, 13:Font, s8 Bold c%accent%, Segoe UI
    Gui, 13:Add, Text, x%countX% y12 w70 h18 Right vBindListCountText BackgroundTrans, 0 шт.
    Gui, 13:Font, s9 Bold c%text%, Segoe UI
    Gui, 13:Add, Button, x%closeX% y8 w34 h24 Center vBindListCloseText g13GuiClose BackgroundTrans, X
    Gui, 13:Add, Text, x0 y0 w0 h0 vBindListRefreshText Hidden,

    searchW := Max(150, BindListW - 286)
    catX := 18 + searchW
    Gui, 13:Font, Norm s9 c%bindInputText%, Segoe UI
    Gui, 13:Add, Edit, x12 y56 w%searchW% h26 vBindListSearchEdit gBindListFilterChanged, %BindListSearch%
    Gui, 13:Add, DropDownList, x%catX% y56 w190 r10 vBindListCategoryDDL hwndhBindListCategoryDDL gBindListFilterChanged, Все|Системные|Задержание и RP|Доклады|Транспорт / прочее|Документы|Пользовательское
    GuiControl, 13:ChooseString, BindListCategoryDDL, %BindListCategory%
    Gui, 13:Font, Norm s8 c%bindInputText%, Segoe UI
    Gui, 13:Add, ListView, x12 y94 w%listW% h%listH% vBindListLV hwndhBindListLV gBindListViewEvent AltSubmit -Multi Background%controlBg%, Команда|Клавиша|TXT|Token
    Gui, 13:Font, Norm s8 c%muted%, Segoe UI
    Gui, 13:Add, Text, x12 y%infoY% w%infoW% h18 vBindListInfoText BackgroundTrans, Бинды загружены.
    Gui, 13:Font, s9 Bold c%accent%, Segoe UI
    Gui, 13:Add, Text, x%gripX% y%infoY% w22 h18 Right vBindListResizeGripText BackgroundTrans, //

    Capture_BeforeShow("13")

    Gui, 13:Show, % "x" BindListX " y" BindListY " w" BindListW " h" BindListH, BindList
    PromoteOverlayWindow(hBindListWnd, 1, 0)
    bindListAlpha := BindListTransparency
    NormalizeNumberRange(bindListAlpha, 225, 150, 255)
    WinSet, Transparent, %bindListAlpha%, ahk_id %hBindListWnd%
    ApplyRoundedCorners(hBindListWnd, UIRoundness)
    ApplyRoundedPanelsForGui(hBindListWnd, InnerRoundness)
    ApplyListViewColors(hBindListLV, controlBg, bindInputText)
    ApplyPersistentAlwaysOnTop()
    UpdateBindListColumnLayout(listW)
}

13GuiSize:
if (A_EventInfo = 1)
    return

global BindListW, BindListH, hBindListWnd, UIRoundness, InnerRoundness
BindListW := A_GuiWidth
BindListH := A_GuiHeight
listW := BindListW - 24
listH := BindListH - 128
if (listH < 160)
    listH := 160
infoY := 100 + listH + 6
infoW := BindListW - 54
searchW := Max(150, BindListW - 286)
catX := 18 + searchW

GuiControl, 13:Move, BindListDragZone, % "x0 y0 w" . A_GuiWidth . " h48"
GuiControl, 13:Move, BindListTitleText, % "x22 y8 w260 h20"
GuiControl, 13:Move, BindListProfileText, % "x22 y29 w280 h16"
GuiControl, 13:Move, BindListCountText, % "x" . (A_GuiWidth - 130) . " y12 w70 h18"
GuiControl, 13:Move, BindListCloseText, % "x" . (A_GuiWidth - 52) . " y8 w34 h24"
GuiControl, 13:Move, BindListSearchEdit, % "x12 y56 w" . searchW . " h26"
GuiControl, 13:Move, BindListCategoryDDL, % "x" . catX . " y56 w190 h26"
GuiControl, 13:Move, BindListLV, % "x12 y94 w" . listW . " h" . listH
GuiControl, 13:Move, BindListInfoText, % "x12 y" . infoY . " w" . infoW . " h18"
GuiControl, 13:Move, BindListResizeGripText, % "x" . (A_GuiWidth - 34) . " y" . infoY . " w22 h18"
GuiControl, 13:Move, BindListBG, % "x0 y0 w" . A_GuiWidth . " h" . A_GuiHeight
GuiControl, 13:Move, BindListBorderTop, % "x0 y0 w" . A_GuiWidth . " h2"
GuiControl, 13:Move, BindListBorderBottom, % "x0 y" . (A_GuiHeight - 2) . " w" . A_GuiWidth . " h2"
GuiControl, 13:Move, BindListBorderLeft, % "x0 y0 w2 h" . A_GuiHeight
GuiControl, 13:Move, BindListBorderRight, % "x" . (A_GuiWidth - 2) . " y0 w2 h" . A_GuiHeight
UpdateBindListColumnLayout(listW)
ApplyRoundedCorners(hBindListWnd, UIRoundness)
ApplyRoundedPanelsForGui(hBindListWnd, InnerRoundness)
SetTimer, SaveUiDebounced, -500
return

13GuiEscape:
13GuiClose:
global BindListVisible, BindListDragFromRow, BindListDragHoverRow, BindListDragActive
Gui, 13:Hide
BindListVisible := 0
BindListDragFromRow := 0
BindListDragHoverRow := 0
BindListDragActive := 0
ToolTip
return

BindListViewEvent:
Gui, 13:Default
if (A_GuiEvent = "DoubleClick")
{
    rowIndex := A_EventInfo
    if (rowIndex > 0)
    {
        LV_GetText(actionText, rowIndex, 1)
        LV_GetText(hotkeyText, rowIndex, 2)
        LV_GetText(triggerText, rowIndex, 3)
        Clipboard := actionText . " | HK: " . hotkeyText . " | !: " . triggerText
        ToolTip, Строка bind-листа скопирована в буфер обмена.
        SetTimer, RemoveToolTip, -1200
    }
}
return

BindListRefreshLabel:
UpdateBindList()
return

BindListFilterChanged:
Gui, 13:Submit, NoHide
BindListSearch := BindListSearchEdit
BindListCategory := BindListCategoryDDL
UpdateBindList()
return

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
        ToolTip, % "Перемещение: " . BindListDragFromRow . " -> " . hoverRow
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
    ToolTip
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

    AddOutlinedPanel(18, 10, 10, overlayW - 20, overlayH - 20, cardBg, accent, 2)

    Gui, 18:Font, s10 Bold c%text%, Segoe UI
    Gui, 18:Add, Text, % "x" contentX " y16 w" contentW " h20 Center BackgroundTrans", Бинды
    Gui, 18:Font, Norm s7 c%muted%, Segoe UI
    Gui, 18:Add, Text, % "x" contentX " y38 w" contentW " h16 Center BackgroundTrans", Alt+X - скрыть | F11 - полный
    Gui, 18:Add, Progress, % "-Theme " . "x" contentX " y58 w" contentW " h2 Disabled Background" cardBg " c" accent, 100

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
                Gui, 18:Font, s7 Bold c%accent%, Segoe UI
                Gui, 18:Add, Text, % "x" contentX " y" rowY " w" contentW " h18 +0x200 BackgroundTrans", % row.Category
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

ActionTimer_EnterCritical(ByRef previousState) {
    previousState := A_IsCritical
    if (!previousState)
        Critical, On
}

ActionTimer_LeaveCritical(previousState) {
    if (!previousState)
        Critical, Off
}

ActionTimer_IsEnabled(kind) {
    global EvacuationTimerEnabled, PatrolTimerEnabled, PostTimerEnabled
    if (kind = "Evac" || kind = "Эвакуация")
        return EvacuationTimerEnabled = "On"
    if (kind = "Patrol" || kind = "Патруль")
        return PatrolTimerEnabled = "On"
    if (kind = "Post" || kind = "Пост")
        return PostTimerEnabled = "On"
    return false
}

ActionTimer_Count() {
    global ActionTimerItems
    count := 0
    if IsObject(ActionTimerItems)
        for token, item in ActionTimerItems
            count += 1
    return count
}

ActionTimer_FormatSeconds(seconds) {
    seconds := Ceil(seconds + 0)
    if (seconds < 0)
        seconds := 0
    hours := Floor(seconds / 3600)
    minutes := Floor(Mod(seconds, 3600) / 60)
    secs := Mod(seconds, 60)
    if (hours > 0)
        return Format("{:02}:{:02}:{:02}", hours, minutes, secs)
    return Format("{:02}:{:02}", minutes, secs)
}

ActionTimer_Start(token, label, durationSec, timerMode := "Manual", exactEndTick := "") {
    global ActionTimerItems, MockMode
    token := Trim(token)
    durationSec := Floor(durationSec + 0)
    ActionTimer_EnterCritical(previousCritical)
    if (token = "" || durationSec < 1 || !ActionTimer_IsEnabled(token) || MockMode = "On")
    {
        ActionTimer_LeaveCritical(previousCritical)
        return false
    }
    if !IsObject(ActionTimerItems)
        ActionTimerItems := {}
    endTick := (exactEndTick = "") ? TickNow() + durationSec * 1000 : exactEndTick + 0
    ActionTimerItems[token] := {Label: label, EndTick: endTick, Mode: timerMode}
    SetTimer, ActionTimerTick, 1000
    ActionTimer_Render()
    if (ActionTimer_Count() < 1)
        SetTimer, ActionTimerTick, Off
    ActionTimer_LeaveCritical(previousCritical)
    return true
}

ActionTimer_StartEvacuation() {
    return ActionTimer_Start("Evac", "ЭВАКУАЦИЯ · ОЖИДАНИЕ", 180)
}

ActionTimer_StartManualService(mode) {
    global AutoReportActive, AutoReportMode, AutoReportEndTick
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        return false
    ActionTimer_EnterCritical(previousCritical)
    token := (mode = "Пост") ? "Post" : "Patrol"
    if (AutoReportActive && AutoReportMode = mode && TaskScheduler_RemainingMs(AutoReportEndTick) > 0)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return true
    }
    label := (mode = "Пост") ? "ПОСТ · ДО ДОКЛАДА" : "ПАТРУЛЬ · ДО ДОКЛАДА"
    started := ActionTimer_Start(token, label, 600)
    ActionTimer_LeaveCritical(previousCritical)
    return started
}

ActionTimer_StartAutoReport(mode) {
    global AutoReportEndTick
    mode := Trim(mode)
    if (mode != "Патруль" && mode != "Пост")
        return false
    ActionTimer_EnterCritical(previousCritical)
    token := (mode = "Пост") ? "Post" : "Patrol"
    label := (mode = "Пост") ? "АВТОПОСТ" : "АВТОПАТРУЛЬ"
    durationSec := Ceil(TaskScheduler_RemainingMs(AutoReportEndTick) / 1000.0)
    if (durationSec < 1)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return false
    }
    started := ActionTimer_Start(token, label, durationSec, "AutoReport", AutoReportEndTick)
    ActionTimer_LeaveCritical(previousCritical)
    return started
}

ActionTimer_Stop(token, redraw := 1, expectedMode := "") {
    global ActionTimerItems
    ActionTimer_EnterCritical(previousCritical)
    removed := false
    if IsObject(ActionTimerItems) && ActionTimerItems.HasKey(token)
    {
        item := ActionTimerItems[token]
        if (expectedMode = "" || item.Mode = expectedMode)
        {
            ActionTimerItems.Delete(token)
            removed := true
        }
    }
    if (redraw)
        ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
    return removed
}

ActionTimer_Clear() {
    global ActionTimerItems
    ActionTimer_EnterCritical(previousCritical)
    ActionTimerItems := {}
    ActionTimer_Hide()
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_ReconcileSettings() {
    global ActionTimerItems, AutoReportActive, AutoReportMode
    ActionTimer_EnterCritical(previousCritical)
    if !IsObject(ActionTimerItems)
        ActionTimerItems := {}
    if !ActionTimer_IsEnabled("Evac")
        ActionTimerItems.Delete("Evac")
    if !ActionTimer_IsEnabled("Patrol")
        ActionTimerItems.Delete("Patrol")
    if !ActionTimer_IsEnabled("Post")
        ActionTimerItems.Delete("Post")
    if (AutoReportActive && ActionTimer_IsEnabled(AutoReportMode))
        ActionTimer_StartAutoReport(AutoReportMode)
    ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_PruneExpired(notifyUser := 1) {
    global ActionTimerItems
    if !IsObject(ActionTimerItems)
        return 0
    nowTick := TickNow()
    expired := []
    for token, item in ActionTimerItems
        if (TaskScheduler_RemainingMs(item.EndTick, nowTick) <= 0)
            expired.Push({Token: token, Item: item})
    shouldSound := false
    Loop % expired.Length()
    {
        expiredEntry := expired[A_Index]
        token := expiredEntry.Token
        item := expiredEntry.Item
        ActionTimerItems.Delete(token)
        if (!notifyUser || item.Mode = "AutoReport")
            continue
        if (token = "Evac")
            message := "3 минуты ожидания эвакуации истекли."
        else if (token = "Post")
            message := "10 минут на посту истекли — пора отправить доклад."
        else
            message := "10 минут патруля истекли — пора отправить доклад."
        GameNotify(message, "INFO")
        shouldSound := true
    }
    if (shouldSound)
        PlayStopTimerSound()
    return expired.Length()
}

ActionTimer_BuildBody(nowTick, ByRef lineCount) {
    global ActionTimerItems, AutoReportActive, AutoReportMode, AutoReportNextTick, AutoReportEndTick
    body := ""
    lineCount := 0
    order := ["Evac", "Patrol", "Post"]
    Loop % order.Length()
    {
        token := order[A_Index]
        if !IsObject(ActionTimerItems) || !ActionTimerItems.HasKey(token)
            continue
        item := ActionTimerItems[token]
        remainingSec := Ceil(TaskScheduler_RemainingMs(item.EndTick, nowTick) / 1000.0)
        if (remainingSec < 0)
            remainingSec := 0
        if (body != "")
            body .= "`n"
        body .= item.Label . "   " . ActionTimer_FormatSeconds(remainingSec)
        lineCount += 1
        expectedMode := (token = "Post") ? "Пост" : "Патруль"
        if (item.Mode = "AutoReport" && AutoReportActive && AutoReportMode = expectedMode)
        {
            nextText := "завершение"
            if (TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) <= TaskScheduler_RemainingMs(AutoReportEndTick, nowTick))
            {
                nextSec := Ceil(TaskScheduler_RemainingMs(AutoReportNextTick, nowTick) / 1000.0)
                if (nextSec < 0)
                    nextSec := 0
                nextText := ActionTimer_FormatSeconds(nextSec)
            }
            body .= "`nСЛЕДУЮЩИЙ ДОКЛАД   " . nextText
            lineCount += 1
        }
    }
    return body
}

ActionTimer_Hide(keepTick := 0) {
    global hActionTimerWnd, ActionTimerLastHeight, ActionTimerX, ActionTimerY
    ActionTimer_EnterCritical(previousCritical)
    if (!keepTick)
        SetTimer, ActionTimerTick, Off
    if (hActionTimerWnd && DllCall("IsWindow", "Ptr", hActionTimerWnd))
    {
        WinGetPos, currentX, currentY,,, ahk_id %hActionTimerWnd%
        if (currentX != "")
            ActionTimerX := currentX, ActionTimerY := currentY
    }
    Gui, ActionTimers:Destroy
    hActionTimerWnd := 0
    ActionTimerLastHeight := 0
    ActionTimer_LeaveCritical(previousCritical)
}

ActionTimer_Render() {
    global ActionTimerRenderBusy
    wasCritical := A_IsCritical
    if (!wasCritical)
        Critical, On
    if (ActionTimerRenderBusy)
    {
        if (!wasCritical)
            Critical, Off
        return
    }
    ActionTimerRenderBusy := 1
    try
        ActionTimer_RenderCore()
    catch e
    {
        errorText := IsObject(e) ? e.Message . " | " . e.What . " | line " . e.Line : e
        LogError("ActionTimer", "Render failed: " . errorText, "ERROR")
    }
    finally
    {
        ActionTimerRenderBusy := 0
        if (!wasCritical)
            Critical, Off
    }
}

ActionTimer_RenderCore() {
    global hActionTimerWnd, ActionTimerBody, ActionTimerLastHeight, ActionTimerX, ActionTimerY
    global StopTimerWidth, StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor, UIRoundness
    ActionTimer_PruneExpired(1)
    if (ActionTimer_Count() < 1)
    {
        ActionTimer_Hide()
        return
    }

    nowTick := TickNow()
    body := ActionTimer_BuildBody(nowTick, lineCount)
    if (body = "")
    {
        ActionTimer_Hide()
        return
    }
    ActionTimerBody := body
    overlayW := StopTimerWidth + 150
    NormalizeNumberRange(overlayW, 320, 300, 520)
    overlayH := 42 + lineCount * 24
    NormalizeNumberRange(overlayH, 90, 66, 170)
    NormalizeNumberRange(ActionTimerX, 100, -4000, 8000)
    NormalizeNumberRange(ActionTimerY, 180, -4000, 8000)

    bg := "", panel := "", textColor := "", accent := "", muted := ""
    GetThemeColors(bg, panel, textColor, accent, muted)
    borderColor := (StopTimerBorderColor != "") ? StopTimerBorderColor : accent
    timerTextColor := (StopTimerTextColor != "") ? StopTimerTextColor : textColor
    timerBgColor := (StopTimerBgColor != "") ? StopTimerBgColor : panel
    alpha := StopTimerTransparency
    NormalizeNumberRange(alpha, 255, 120, 255)

    needsCreate := !hActionTimerWnd || !DllCall("IsWindow", "Ptr", hActionTimerWnd) || ActionTimerLastHeight != overlayH
    if (needsCreate)
    {
        if (hActionTimerWnd)
            ActionTimer_Hide(1)
        bottomY := overlayH - 2
        rightX := overlayW - 2
        bodyH := overlayH - 34
        headerW := overlayW - 20
        bodyW := overlayW - 24
        Gui, ActionTimers:New, +HwndhActionTimerWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +Border +LastFound
        Gui, ActionTimers:Color, %timerBgColor%
        Gui, ActionTimers:Margin, 0, 0
        Gui, ActionTimers:Add, Progress, -Theme x0 y0 w%overlayW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x0 y%bottomY% w%overlayW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x0 y0 w2 h%overlayH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Add, Progress, -Theme x%rightX% y0 w2 h%overlayH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
        Gui, ActionTimers:Font, s8 Bold c%borderColor%, Segoe UI
        Gui, ActionTimers:Add, Text, x10 y5 w%headerW% h22 Center 0x200 gStartActionTimerDrag BackgroundTrans, ТАЙМЕРЫ ДЕЙСТВИЙ
        Gui, ActionTimers:Font, s11 Bold c%timerTextColor%, Segoe UI
        Gui, ActionTimers:Add, Text, x12 y30 w%bodyW% h%bodyH% Center 0x200 gStartActionTimerDrag vActionTimerBody BackgroundTrans, %body%
        ActionTimerLastHeight := overlayH
        showOpts := "x" . ActionTimerX . " y" . ActionTimerY . " w" . overlayW . " h" . overlayH . " NoActivate"
        Capture_BeforeShow("ActionTimers")
        Gui, ActionTimers:Show, %showOpts%, ActionTimers
        WinSet, Transparent, %alpha%, ahk_id %hActionTimerWnd%
        WinSet, AlwaysOnTop, On, ahk_id %hActionTimerWnd%
        ApplyRoundedCorners(hActionTimerWnd, UIRoundness)
    }
    else
        GuiControl, ActionTimers:, ActionTimerBody, %body%
}

ActionTimer_Rebuild() {
    ActionTimer_EnterCritical(previousCritical)
    if (ActionTimer_Count() < 1)
    {
        ActionTimer_LeaveCritical(previousCritical)
        return
    }
    ActionTimer_Hide(1)
    ActionTimer_Render()
    ActionTimer_LeaveCritical(previousCritical)
}

ShowStopTimerGUI() {
    global hStopTimerWnd, StopTimerActive, StopTimerCounter, StopTimerWidth, StopTimerHeight
    global StopTimerTransparency, StopTimerBorderColor, StopTimerTextColor, StopTimerBgColor
    global StopTimerX, StopTimerY, UIRoundness

    if (!StopTimerActive)
        return

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)

    borderColor := (StopTimerBorderColor != "" ? StopTimerBorderColor : accent)
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
    Gui, 15:+HwndhStopTimerWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +Border +LastFound
    Gui, 15:Color, %timerBgColor%
    Gui, 15:Margin, 0, 0
    Gui, 15:Add, Progress, -Theme x0 y0 w%timerW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
    bottomY := timerH - 2
    Gui, 15:Add, Progress, -Theme x0 y%bottomY% w%timerW% h2 Disabled Background%timerBgColor% c%borderColor%, 100
    Gui, 15:Add, Progress, -Theme x0 y0 w2 h%timerH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
    rightX := timerW - 2
    Gui, 15:Add, Progress, -Theme x%rightX% y0 w2 h%timerH% Disabled Vertical Background%timerBgColor% c%borderColor%, 100
    Gui, 15:Add, Text, x0 y0 w%timerW% h%timerH% Center 0x200 gStartStopTimerDrag vStopTimerCount BackgroundTrans, %StopTimerCounter%
    Gui, 15:Font, s26 Bold c%timerTextColor%, Segoe UI
    GuiControl, 15:Font, StopTimerCount
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

HideStopDemandGUI:
Gui, 14:Destroy
return

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
    if (!ActiveID || displayID = "" || displayID = "0" || displayID = "ERROR")
        return "—"
    return displayID
}

ShowIDOverlay() {
    global IDOverlayVisible, hIDOverlayWnd, IDOverlayText, IDOverlayX, IDOverlayY, IDOverlayW, IDOverlayH, UIRoundness

    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)

    overlayW := IDOverlayW
    overlayH := IDOverlayH
    NormalizeNumberRange(overlayW, 120, 90, 240)
    NormalizeNumberRange(overlayH, 34, 28, 80)
    if (IDOverlayX = "")
        IDOverlayX := 20
    if (IDOverlayY = "")
        IDOverlayY := 420

    borderRight := overlayW - 2
    borderBottom := overlayH - 2
    textW := overlayW - 16

    Gui, IDOverlay:Destroy
    Gui, IDOverlay:New, +HwndhIDOverlayWnd +AlwaysOnTop -Caption +ToolWindow +E0x08000000 +LastFound
    Gui, IDOverlay:Color, %panel%
    Gui, IDOverlay:Margin, 0, 0
    Gui, IDOverlay:Add, Progress, -Theme x0 y0 w%overlayW% h2 Disabled Background%panel% c%accent%, 100
    Gui, IDOverlay:Add, Progress, -Theme x0 y%borderBottom% w%overlayW% h2 Disabled Background%panel% c%accent%, 100
    Gui, IDOverlay:Add, Progress, -Theme x0 y0 w2 h%overlayH% Disabled Vertical Background%panel% c%accent%, 100
    Gui, IDOverlay:Add, Progress, -Theme x%borderRight% y0 w2 h%overlayH% Disabled Vertical Background%panel% c%accent%, 100
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
}

ApplyProfileModePreset(newMode) {
    global ProfileMode, IntroRole, ReportRole, Rank, ReportRank
    global T_Intro, T_Dep, T_SOSStart, T_SOSArrive, T_HijackStart, T_HijackArrive
    global T_CallStart, T_CallArrive, T_CallWorkStart, T_CallWorkEnd
    global T_PatrolStart, T_PatrolContinue, T_PatrolEnd
    global T_PostStart, T_PostContinue, T_PostEnd
    global T_ConvoyStart, T_ConvoyCont, T_ConvoyEnd
    global RP_StopChase

    SaveGuiToGlobals(1)

    if (newMode = "ДПС")
        newMode := "ГАИ"
    else if (newMode = "Военная полиция")
        newMode := "ВЧ"
    if (newMode != "ППС" && newMode != "ГАИ" && newMode != "ФСБ" && newMode != "Спец МВД" && newMode != "ВЧ")
        newMode := "ППС"
    ProfileMode := newMode

    if (Rank = "" or Rank = "ERROR")
        Rank := "лейтенант"
    if (ReportRank = "" or ReportRank = "ERROR")
        ReportRank := Rank

    if (newMode = "ППС")
    {
        IntroRole := "Сотрудник патрульно-постовой службы"
        ReportRole := "Сотрудник патрульно-постовой службы"
        T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}."
        T_Dep := "/d [УМВД/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь."
        RP_StopChase := "/m [ПОЛИЦИЯ] Водитель, примите вправо и остановитесь у обочины.`n/m [ПОЛИЦИЯ] Заглушите двигатель и оставайтесь в автомобиле."
        T_SOSStart := "/r Экипаж {PATROL_UNIT}, выдвигаемся на вызов SOS."
        T_SOSArrive := "/r Экипаж {PATROL_UNIT}, прибыли на вызов SOS."
        T_HijackStart := "/r Экипаж {PATROL_UNIT}, приняли сообщение об угоне, выдвигаемся."
        T_HijackArrive := "/r Экипаж {PATROL_UNIT}, прибыли по сообщению об угоне."
        T_CallStart := "/r Экипаж {PATROL_UNIT}, приняли сообщение о ДТП."
        T_CallArrive := "/r Экипаж {PATROL_UNIT}, прибыли на место ДТП."
        T_CallWorkStart := "/r Экипаж {PATROL_UNIT}, приступили к обеспечению порядка на месте ДТП."
        T_CallWorkEnd := "/r Экипаж {PATROL_UNIT}, работу на месте ДТП завершили."
        T_PatrolStart := "/r Экипаж {PATROL_UNIT}, заступили на патрулирование по маршруту {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolContinue := "/r Экипаж {PATROL_UNIT}, продолжаем патрулирование по маршруту {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolEnd := "/r Экипаж {PATROL_UNIT}, патрулирование по маршруту {PATROL_ROUTE} завершили."
        T_PostStart := "/r Экипаж {POST_UNIT}, заступили на пост {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostContinue := "/r Экипаж {POST_UNIT}, продолжаем несение службы на посту {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostEnd := "/r Экипаж {POST_UNIT}, несение службы на посту {POST_ROUTE} завершили."
        T_ConvoyStart := "/r Экипаж {PATROL_UNIT}, начали сопровождение по маршруту {CONVOY_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_ConvoyCont := "/r Экипаж {PATROL_UNIT}, продолжаем сопровождение по маршруту {CONVOY_ROUTE}."
        T_ConvoyEnd := "/r Экипаж {PATROL_UNIT}, сопровождение по маршруту {CONVOY_ROUTE} завершили."
    }
    else if (newMode = "ГАИ")
    {
        IntroRole := "начальником МДС ГАИ"
        ReportRole := "Начальник МДС ГАИ"
        T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}."
        T_Dep := "/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь."
        RP_StopChase := "/m [ГАИ] Водитель, примите вправо и остановитесь у обочины.`n/m [ГАИ] Заглушите двигатель и оставайтесь в автомобиле."
        T_SOSStart := "/r докладывает {SURNAME}: реагирую на вызов срочной помощи."
        T_SOSArrive := "/r докладывает {SURNAME}: прибыл на вызов срочной помощи."
        T_HijackStart := "/r Экипаж {PATROL_UNIT}, приняли сообщение об угоне, начинаем розыск."
        T_HijackArrive := "/r Экипаж {PATROL_UNIT}, прибыли по сообщению об угоне."
        T_CallStart := "/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП."
        T_CallArrive := "/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП."
        T_CallWorkStart := "/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП."
        T_CallWorkEnd := "/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП."
        T_PatrolStart := "/r докладывает экипаж {PATROL_UNIT}: заступили на патрулирование по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
        T_PatrolContinue := "/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
        T_PatrolEnd := "/r докладывает экипаж {PATROL_UNIT}: завершили патруль по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек."
        T_PostStart := "/r докладывает экипаж {POST_UNIT}: заступили на пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
        T_PostContinue := "/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
        T_PostEnd := "/r докладывает экипаж {POST_UNIT}: покинули пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек."
        T_ConvoyStart := "/r докладывает экипаж {PATROL_UNIT}: начали сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
        T_ConvoyCont := "/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
        T_ConvoyEnd := "/r докладывает экипаж {PATROL_UNIT}: закончили сопровождение военной колонны по маршруту {CONVOY_ROUTE}."
    }
    else if (newMode = "ФСБ")
    {
        IntroRole := "Военнослужащий Федеральной службы безопасности"
        ReportRole := "Военнослужащий Федеральной службы безопасности"
        T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} {SURNAME}. Личный жетон №{BADGE}."
        T_Dep := "/d [УФСБ/] говорит {REPORT_ROLE}, {REPORT_RANK} {SURNAME}, на связь."
        RP_StopChase := "/m [ФСБ] Водитель, примите вправо и остановите транспортное средство.`n/m Заглушите двигатель и оставайтесь в автомобиле."
        T_SOSStart := "/r Оперативная группа {PATROL_UNIT}, выдвинулась на вызов SOS."
        T_SOSArrive := "/r Оперативная группа {PATROL_UNIT}, прибыла на вызов SOS."
        T_HijackStart := "/r Оперативная группа {PATROL_UNIT}, приняла сообщение об угоне, выдвигается."
        T_HijackArrive := "/r Оперативная группа {PATROL_UNIT}, прибыла по сообщению об угоне."
        T_CallStart := "/r Оперативная группа {PATROL_UNIT}, приняла сообщение о происшествии."
        T_CallArrive := "/r Оперативная группа {PATROL_UNIT}, прибыла на место происшествия."
        T_CallWorkStart := "/r Оперативная группа {PATROL_UNIT}, приступила к оперативным мероприятиям."
        T_CallWorkEnd := "/r Оперативная группа {PATROL_UNIT}, оперативные мероприятия завершила."
        T_PatrolStart := "/r Оперативная группа {PATROL_UNIT}, приступила к патрулированию района {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolContinue := "/r Оперативная группа {PATROL_UNIT}, продолжает патрулирование района {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolEnd := "/r Оперативная группа {PATROL_UNIT}, патрулирование района {PATROL_ROUTE} завершила."
        T_PostStart := "/r Оперативная группа {POST_UNIT}, заступила на объект {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostContinue := "/r Оперативная группа {POST_UNIT}, продолжает работу на объекте {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostEnd := "/r Оперативная группа {POST_UNIT}, работу на объекте {POST_ROUTE} завершила."
        T_ConvoyStart := "/r Оперативная группа {PATROL_UNIT}, начала сопровождение по маршруту {CONVOY_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_ConvoyCont := "/r Оперативная группа {PATROL_UNIT}, продолжает сопровождение по маршруту {CONVOY_ROUTE}."
        T_ConvoyEnd := "/r Оперативная группа {PATROL_UNIT}, сопровождение завершила."
    }
    else if (newMode = "Спец МВД")
    {
        IntroRole := "Сотрудник специализированного подразделения МВД"
        ReportRole := "Сотрудник специализированного подразделения МВД"
        T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции, позывной {SURNAME}. Личный жетон №{BADGE}."
        T_Dep := "/d [УМВД/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции, позывной {SURNAME}, на связь."
        RP_StopChase := "/m [СПЕЦ МВД] Водитель, примите вправо и остановите транспортное средство.`n/m Заглушите двигатель и оставайтесь в автомобиле."
        T_SOSStart := "/r Специальная группа {PATROL_UNIT}, выдвигается на вызов SOS."
        T_SOSArrive := "/r Специальная группа {PATROL_UNIT}, прибыла на вызов SOS."
        T_HijackStart := "/r Специальная группа {PATROL_UNIT}, приняла сообщение об угоне, выдвигается."
        T_HijackArrive := "/r Специальная группа {PATROL_UNIT}, прибыла по сообщению об угоне."
        T_CallStart := "/r Специальная группа {PATROL_UNIT}, приняла сообщение о происшествии."
        T_CallArrive := "/r Специальная группа {PATROL_UNIT}, прибыла на место происшествия."
        T_CallWorkStart := "/r Специальная группа {PATROL_UNIT}, приступила к выполнению задачи."
        T_CallWorkEnd := "/r Специальная группа {PATROL_UNIT}, выполнение задачи завершила."
        T_PatrolStart := "/r Специальная группа {PATROL_UNIT}, приступила к патрулированию района {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolContinue := "/r Специальная группа {PATROL_UNIT}, продолжает патрулирование района {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolEnd := "/r Специальная группа {PATROL_UNIT}, патрулирование района {PATROL_ROUTE} завершила."
        T_PostStart := "/r Специальная группа {POST_UNIT}, заступила на объект {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostContinue := "/r Специальная группа {POST_UNIT}, продолжает работу на объекте {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostEnd := "/r Специальная группа {POST_UNIT}, работу на объекте {POST_ROUTE} завершила."
        T_ConvoyStart := "/r Специальная группа {PATROL_UNIT}, начала сопровождение по маршруту {CONVOY_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_ConvoyCont := "/r Специальная группа {PATROL_UNIT}, продолжает сопровождение по маршруту {CONVOY_ROUTE}."
        T_ConvoyEnd := "/r Специальная группа {PATROL_UNIT}, сопровождение завершила."
    }
    else
    {
        IntroRole := "Военнослужащий воинской части"
        ReportRole := "Военнослужащий воинской части"
        T_Intro := "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} {SURNAME}."
        T_Dep := "/d [ВЧ/] говорит {REPORT_ROLE}, {REPORT_RANK} {SURNAME}, на связь."
        RP_StopChase := "/m [ВЧ] Освободите маршрут движения военной колонны.`n/m Повторяю требование: не создавайте помех движению колонны."
        T_SOSStart := "/r Военный патруль {PATROL_UNIT}, выдвигается на сигнал помощи."
        T_SOSArrive := "/r Военный патруль {PATROL_UNIT}, прибыл на сигнал помощи."
        T_HijackStart := "/r Военный патруль {PATROL_UNIT}, принял сообщение о происшествии с транспортом, выдвигается."
        T_HijackArrive := "/r Военный патруль {PATROL_UNIT}, прибыл на место происшествия с транспортом."
        T_CallStart := "/r Военный патруль {PATROL_UNIT}, принял сообщение о происшествии."
        T_CallArrive := "/r Военный патруль {PATROL_UNIT}, прибыл на место происшествия."
        T_CallWorkStart := "/r Военный патруль {PATROL_UNIT}, приступил к выполнению задачи."
        T_CallWorkEnd := "/r Военный патруль {PATROL_UNIT}, задачу выполнил."
        T_PatrolStart := "/r Военный патруль {PATROL_UNIT}, заступил на маршрут {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolContinue := "/r Военный патруль {PATROL_UNIT}, продолжает несение службы по маршруту {PATROL_ROUTE}, состав: {PATROL_CREW_COUNT}."
        T_PatrolEnd := "/r Военный патруль {PATROL_UNIT}, патрулирование по маршруту {PATROL_ROUTE} завершил."
        T_PostStart := "/r Караул {POST_UNIT}, заступил на пост {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostContinue := "/r Караул {POST_UNIT}, продолжает несение службы на посту {POST_ROUTE}, состав: {POST_CREW_COUNT}."
        T_PostEnd := "/r Караул {POST_UNIT}, несение службы на посту {POST_ROUTE} завершил."
        T_ConvoyStart := "/r Военная колонна {PATROL_UNIT}, начала движение по маршруту {CONVOY_ROUTE}, состав охраны: {PATROL_CREW_COUNT}."
        T_ConvoyCont := "/r Военная колонна {PATROL_UNIT}, продолжает движение по маршруту {CONVOY_ROUTE}."
        T_ConvoyEnd := "/r Военная колонна {PATROL_UNIT}, сопровождение по маршруту {CONVOY_ROUTE} завершила."
    }
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
    settingsAlpha := 255
    PromoteOverlayWindow(hSettingsWnd)
    WinSet, Transparent, %settingsAlpha%, ahk_id %hSettingsWnd%
    ApplyRoundedCorners(hSettingsWnd, 0)
    ApplyRoundedPanelsForGui(hSettingsWnd, InnerRoundness)
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

SetupTrayMenu() {
    Menu, Tray, Tip, AHK FOR GOS BY SBEZRUK v1.0
    Menu, Tray, Add
    Menu, Tray, Add, Открыть настройки, TrayOpenSettingsLabel
    Menu, Tray, Add, Скрыть настройки, TrayHideSettingsLabel
    Menu, Tray, Add, Конструктор функций, TrayOpenCustomFunctionsLabel
    Menu, Tray, Add, Диагностика Auto ID, TrayAutoIDDiagnosticsLabel
    Menu, Tray, Add
    Menu, Tray, Add, Выход из AHK FOR GOS BY SBEZRUK, ExitScriptLabel
    Menu, Tray, Default, Открыть настройки
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
    global SettingsTargetTab, SettingsPage, SettingsNavigationBusy
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
    Settings_ActivateLayout(pageIndex)
    UpdateAutomationSettingsStatus()
    SettingsNavigationBusy := 0
    return true
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

NormalizeSettingsPage(ByRef pageId) {
    pageId := Trim(pageId)
    pages := GetSettingsPageCatalog()
    Loop % pages.Length()
        if (pages[A_Index].Id = pageId)
            return
    pageId := "profile"
}

Settings_AddControl(label, varName, value, x, y, w, controlType, options, textColor, inputColor) {
    Gui, 2:Font, s9 Norm c%textColor%, Segoe UI
    Gui, 2:Add, Text, % "x" x " y" y " w" w " h28 +Wrap BackgroundTrans", %label%
    Gui, 2:Font, s10 Norm c%inputColor%, Segoe UI
    opts := "x" x " y" (y + 32) " w" w " v" . varName
    if (controlType = "DropDown" || controlType = "Combo") {
        opts .= " r8"
        if (controlType = "DropDown")
            Gui, 2:Add, DropDownList, %opts%, %options%
        else
            Gui, 2:Add, ComboBox, %opts%, %options%
        GuiControl, 2:ChooseString, %varName%, %value%
    } else {
        opts .= " h30"
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
        h := controlType = "Multi" ? rowHeight - 46 : 30
        opts := "x" x " y" (y + 32) " w" w " h" h " v" . item[2]
        if (controlType = "Hotkey") {
            opts .= " gCfgHotkeyChanged"
            Gui, 2:Add, Hotkey, %opts%, %controlValue%
        } else {
            if (controlType = "Multi")
                opts .= " Multi WantTab +VScroll"
            Gui, 2:Add, Edit, %opts%, %controlValue%
        }
        Settings_RecordExtent(y + 32 + h + 12)
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
    Gui, 2:Add, Progress, -Theme x242 y100 w4 h44 Disabled Vertical Background%cardBg% c%cardEdge%, 100
    Gui, 2:Font, s15 Bold c%textColor%, Segoe UI
    Gui, 2:Add, Text, x258 y96 w870 h30 BackgroundTrans, %title%
    Gui, 2:Font, Norm s9 c%mutedColor%, Segoe UI
    Gui, 2:Add, Text, x258 y128 w870 h22 BackgroundTrans, %subtitle%
    Gui, 2:Add, Progress, -Theme x242 y156 w886 h1 Disabled Background%cardBg% c%cardEdge%, 100
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
    Gui, 2:Add, Progress, -Theme x0 y0 w1180 h4 Disabled Background%bg% c%accent% vSettingsBorderTop, 100
    Gui, 2:Add, Progress, -Theme x0 y796 w1180 h4 Disabled Background%bg% c%accent% vSettingsBorderBottom, 100
    Gui, 2:Add, Text, x0 y0 w216 h64 vSettingsDragZone gStartSettingsDrag BackgroundTrans,

    Gui, 2:Font, s12 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x20 y12 w210 h28 BackgroundTrans, ГОС / ПОМОЩНИК
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x20 y40 w190 h18 BackgroundTrans, SBEZRUK · Amazing Online
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Text, x238 y9 w210 h18 BackgroundTrans, АКТИВНЫЙ ПРОФИЛЬ
    Gui, 2:Font, Norm s10 c%inputText%, Segoe UI
    Gui, 2:Add, ComboBox, x238 y29 w214 r10 vCFG_ProfileName, %profiles%
    GuiControl, 2:ChooseString, CFG_ProfileName, %CurrentProfile%
    Gui, 2:Font, Norm s9 c%text%, Segoe UI
    Gui, 2:Add, Button, x466 y27 w82 h30 vSettingsBtnLoad gCfgLoadProfile, Загрузить
    Gui, 2:Add, Button, x554 y27 w82 h30 vSettingsBtnSave gCfgSaveProfile, Сохранить
    Gui, 2:Add, Button, x642 y27 w82 h30 vSettingsBtnCreate gCfgCreateProfile, Создать
    Gui, 2:Add, Button, x730 y27 w82 h30 vSettingsBtnDelete gCfgDeleteProfile, Удалить
    Gui, 2:Add, Button, x826 y27 w76 h30 vSettingsBtnImport gImportProfilesLabel, Импорт
    Gui, 2:Add, Button, x908 y27 w76 h30 vSettingsBtnExport gExportProfilesLabel, Экспорт
    Gui, 2:Add, Button, x1062 y27 w42 h30 vSettingsBtnHide gMinimizeSettingsLabel, -
    Gui, 2:Add, Button, x1110 y27 w48 h30 vSettingsBtnExit gExitScriptButtonLabel, X
    Gui, 2:Add, Progress, -Theme x18 y68 w1140 h2 Disabled Background%bg% c%accent%, 100

    AddOutlinedPanel(2, 16, 82, 210, 674, panel, cardEdge, 2)
    Gui, 2:Font, Norm s10 c%text%, Segoe UI
    Gui, 2:Add, ListView, x26 y94 w190 h648 -Hdr -Multi AltSubmit vSettingsNavLV hwndhSettingsNavLV gSettingsNavChanged Background%panel% NoSortHdr, Раздел
    Gui, 2:Default
    Gui, 2:ListView, SettingsNavLV
    Loop % pages.Length()
        LV_Add("", pages[A_Index].Label)
    LV_ModifyCol(1, 176)
    ApplyListViewColors(hSettingsNavLV, panel, text)

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
    Settings_AddControl("Режим отправки", "CFG_TextSendMode", textModeLabel, 240, 170, 190, "DropDown", "Авто|Память|Вставка|Печать всего|Печать фракции", text, inputText)
    Settings_AddControl("Тест без игры (Mock)", "CFG_MockMode", MockMode, 446, 170, 150, "DropDown", "Off|On", text, inputText)
    Settings_AddControl("Очередь чата", "CFG_ChatQueueEnabled", ChatQueueEnabled, 612, 170, 150, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("Проверка ID", "CFG_IDCheckEnabled", idChoice, 778, 170, 150, "DropDown", "On|Off", text, inputText)
    Settings_AddControl("SafeMode", "CFG_SafeModeEnabled", SafeModeEnabled, 944, 170, 180, "DropDown", "On|Off", text, inputText)
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

    AddOutlinedPanel(2, 240, 730, 904, 234, panel, cardEdge, 1)
    Gui, 2:Font, s11 Bold c%text%, Segoe UI
    Gui, 2:Add, Text, x256 y742 w868 h24 BackgroundTrans, Печать и ручной ввод ID
    Settings_AddControl("Интервал печати, мс (1–100)", "CFG_ChatTypingDelayMs", ChatTypingDelayMs, 256, 778, 214, "Edit", "", text, inputText)
    Settings_AddControl("Ручной ввод ID", "CFG_IDEntryMode", IDEntryMode, 490, 778, 258, "DropDown", "Перехват цифр|Через чат", text, inputText)
    Settings_AddControl("Время ввода ID, сек", "CFG_IDCaptureTimeoutSec", IDCaptureTimeoutSec, 768, 778, 164, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x950 y782 w174 h58 +Wrap BackgroundTrans, По бинду «Ввести ID вручную». Повтор бинда применяет ID.
    Settings_AddControl("Команды для режима «Печать фракции»", "CFG_ChatFactionCommands", ChatFactionCommands, 256, 852, 868, "Edit", "", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x256 y924 w868 h32 +Wrap BackgroundTrans, Интервал — между символами; RP до/после действия вводится без этой паузы. Фракционные команды: через пробел или `;. Остальной текст вставляется.
    Settings_RecordExtent(974)

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
    Settings_AddGrid(Settings_GetCatalogItems("Trigger", "commands"), 240, 166, 5, 180, 52, "Edit", text, inputText)

    SettingsBuildingPage := 9
    Gui, 2:Tab, 9
    Settings_AddPageFrame("Документы", "Кодексы открываются по TXT-командам и листаются PgUp / PgDn.", cardBg, cardEdge, text, muted)
    Settings_AddGrid(Settings_GetCatalogItems("Trigger", "documents"), 240, 174, 3, 300, 64, "Edit", text, inputText)
    AddOutlinedPanel(2, 242, 618, 884, 120, panel, cardEdge, 1)
    Settings_AddControl("Режим карт территорий", "CFG_TerritoryMapMode", CFG_TerritoryMapMode, 258, 630, 270, "DropDown", "Локальные копии|Официальные ссылки", text, inputText)
    Gui, 2:Font, Norm s9 c%muted%, Segoe UI
    Gui, 2:Add, Text, x548 y628 w560 h38 BackgroundTrans +Wrap, Локальные копии — открываются внутри AHK FOR GOS BY SBEZRUK без интернета; режим по умолчанию.
    Gui, 2:Add, Text, x548 y680 w560 h42 BackgroundTrans +Wrap, Официальные ссылки — соответствующий пост открывается через системный браузер; нужный спойлер необходимо развернуть вручную.

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
    Gui, 2:Add, Text, x18 y772 w900 h18 vSettingsStatusText BackgroundTrans, Изменения сохраняются кнопкой «Сохранить» или при закрытии окна.
    Gui, 2:Add, Text, x920 y772 w240 h18 Right vSettingsOwnerText BackgroundTrans, AHK FOR GOS BY SBEZRUK · SBezruk180
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

NormalizeCatalogTriggerGlobals() {
    global
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (meta.TriggerVar != "")
        {
            currentValue := GetDynamicGlobalValue(meta.TriggerVar)
            NormalizeTextTrigger(currentValue)
            SetDynamicGlobalValue(meta.TriggerVar, currentValue)
        }
    }
}

ApplyCfgUiValuesToGlobals() {
    global
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
    ChatFactionCommands := CFG_ChatFactionCommands
    IDEntryMode := CFG_IDEntryMode
    IDCaptureTimeoutSec := CFG_IDCaptureTimeoutSec
    ChatTyping_NormalizeDelay(ChatTypingDelayMs)
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

SaveGuiToGlobals(preserveLoadedProfile := 0) {
    global
    Gui, 2:Submit, NoHide
    ResolveCfgHotkeyConflicts("", 0)

    if (CFG_ProfileName = "")
        CFG_ProfileName := CurrentProfile

    NormalizeProfileNameValue(CFG_ProfileName)
    if (!preserveLoadedProfile)
        CurrentProfile := CFG_ProfileName
    if IsBuiltInThemeName(CFG_ThemeMode)
    {
        ThemeMode := CFG_ThemeMode
        NormalizeThemeMode(ThemeMode)
    }

    ApplyCfgUiValuesToGlobals()
    ApplyCfgProfileIdentityValuesToGlobals()
    ApplyCfgTemplateAndRpTextsToGlobals()
    ApplyCfgConfigOnlyProfileFieldsToGlobals()
    ApplyCfgCatalogValuesToGlobals()
    NormalizeCatalogTriggerGlobals()

    SaveUISettings()
    ApplyAllBinds()
    RebuildFloatingGUI()
}

HasUsableConfigFilePath() {
    global ConfigFile
    return (Trim(ConfigFile) != "")
}

EnsureConfigFilePath(opName, showMsg := 0) {
    global ConfigFile
    if HasUsableConfigFilePath()
        return 1
    LogError(opName, "Empty ConfigFile path.")
    if (showMsg)
        MsgBox, 48, Ошибка, Не задан путь к основному INI-файлу.
    return 0
}

GetSafeLastProfileName() {
    global ConfigFile
    lastProfile := "Основной"
    if !EnsureConfigFilePath("GetSafeLastProfileName")
        return lastProfile
    IniRead, lastProfile, %ConfigFile%, Profiles, Last, Основной
    NormalizeProfileNameValue(lastProfile)
    if !ProfileExists(lastProfile)
        lastProfile := "Основной"
    return lastProfile
}

CopyIniFileWithOverwrite(sourcePath, targetPath, opName) {
    if (sourcePath = "" || targetPath = "")
    {
        LogError(opName, "Empty source or target path.")
        return 0
    }
    if !FileExist(sourcePath)
    {
        LogError(opName, "Source file not found: " . sourcePath)
        return 0
    }
    FileCopy, %sourcePath%, %targetPath%, 1
    if (ErrorLevel)
    {
        LogError(opName, "File copy failed: " . sourcePath . " -> " . targetPath)
        return 0
    }
    return 1
}

RefreshAfterProfilesImport() {
    global SettingsVisible, SettingsTargetTab
    MigrateConfigIfNeeded()
    LoadUISettings()
    LoadProfile(GetSafeLastProfileName())
    RebuildFloatingGUI()
    if (SettingsVisible)
        OpenSettings(SettingsTargetTab)
}

RefreshAfterThemeImport() {
    global SettingsVisible, SettingsTargetTab
    RebuildFloatingGUI()
    if (SettingsVisible)
        OpenSettings(SettingsTargetTab)
}

MigrateContextAssistantProfiles(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    defaults := {}
    defaults["AssistOOPEnabled"] := "On"
    defaults["AssistStunEnabled"] := "On"
    defaults["AssistChaseEnabled"] := "On"
    defaults["AssistHouseEnabled"] := "On"
    defaults["AssistDrugsEnabled"] := "On"
    defaults["AssistPDPCuffEnabled"] := "On"
    defaults["AssistOOPCommand"] := "/find {ID}"
    defaults["AssistTaserCommand"] := "/tazer {ID}"
    defaults["AssistBatonCommand"] := "/baton {ID}"
    defaults["Bind_AssistOOP"] := ""
    defaults["Bind_AssistStun"] := ""
    defaults["Bind_AssistChase"] := ""
    defaults["Bind_AssistHouse"] := ""
    defaults["Bind_AssistDrugs"] := ""
    defaults["Bind_AssistPDPCuff"] := ""
    defaults["Trig_AssistOOP"] := "!ооп"
    defaults["Trig_AssistStun"] := "!оглуш"
    defaults["Trig_AssistChase"] := "!погоня"
    defaults["Trig_AssistHouse"] := "!домgps"
    defaults["Trig_AssistDrugs"] := "!наркоид"
    defaults["Trig_AssistPDPCuff"] := "!пдпнаруч"

    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        for keyName, defaultValue in defaults
        {
            IniRead, currentValue, %fileName%, %sectionName%, %keyName%, __MISSING__
            if (currentValue = "__MISSING__")
                CheckedIniWrite(defaultValue, fileName, sectionName, keyName)
        }
    }
}

MigrateV6Configuration(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    defaults := {}
    defaults["AutoTargetIDEnabled"] := "On"
    defaults["Bind_OpenBindsTab"] := ""
    defaults["Bind_ConfirmID"] := "F1"
    defaults["Bind_RejectID"] := "F2"
    defaults["Bind_MaskCall"] := ""
    defaults["Bind_RecordCheck"] := ""
    defaults["Bind_TrainCrash"] := ""
    defaults["Bind_PersonalFile"] := ""
    defaults["Bind_Su"] := ""
    defaults["Trig_OpenBindsTab"] := "!бинды"
    defaults["Trig_MaskCall"] := "!м"
    defaults["Trig_RecordCheck"] := "!упр"
    defaults["Trig_TrainCrash"] := "!поезд"
    defaults["Trig_PersonalFile"] := "!лд"
    defaults["Trig_Su"] := "!су"

    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        for keyName, defaultValue in defaults
        {
            IniRead, currentValue, %fileName%, %sectionName%, %keyName%, __MISSING__
            if (currentValue = "__MISSING__")
                CheckedIniWrite(defaultValue, fileName, sectionName, keyName)
        }
    }

    uiDefaults := {GameWindowTitle: "AMAZING ONLINE", GameProcessName: "gta_sa.exe", AzmpExpectedSHA256: ""
        , EvidenceScreenshotMethod: "Alt+F1", EvidenceDocumentActivationMode: "Только радиус"
        , EvidenceDocumentWaitSec: 90, EvidenceDocumentDistanceLimit: 20}
    for keyName, defaultValue in uiDefaults
    {
        IniRead, currentValue, %fileName%, UI, %keyName%, __MISSING__
        if (currentValue = "__MISSING__")
            CheckedIniWrite(defaultValue, fileName, "UI", keyName)
    }
    IniRead, currentValue, %fileName%, ChatLog, Enabled, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("On", fileName, "ChatLog", "Enabled")
    IniRead, currentValue, %fileName%, ChatLog, Path, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("C:\Amazing Games\Amazing Online\PC\amazing\chatlog.txt", fileName, "ChatLog", "Path")
    IniRead, currentValue, %fileName%, ChatLog, PlayerNickname, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("Semen_Lukashenko", fileName, "ChatLog", "PlayerNickname")
    IniRead, currentValue, %fileName%, ChatLog, AutoCleanup, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("On", fileName, "ChatLog", "AutoCleanup")
    IniRead, currentValue, %fileName%, ChatLog, MaxSizeKB, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("512", fileName, "ChatLog", "MaxSizeKB")
    IniRead, currentValue, %fileName%, ChatLog, KeepTailKB, __MISSING__
    if (currentValue = "__MISSING__")
        CheckedIniWrite("32", fileName, "ChatLog", "KeepTailKB")
}

MigrateV7Configuration(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"
    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        IniDelete, %fileName%, %sectionName%, MDS_EvacReminder
        IniDelete, %fileName%, %sectionName%, Bind_MDSEvacReminder
        IniDelete, %fileName%, %sectionName%, Trig_MDSEvacReminder
        IniDelete, %fileName%, %sectionName%, MDS_UrgentReminder
        IniDelete, %fileName%, %sectionName%, Bind_MDSUrgentReminder
        IniDelete, %fileName%, %sectionName%, Trig_MDSUrgentReminder
    }
}

IniWriteDefaultIfMissing(fileName, sectionName, keyName, defaultValue, encodeText := 0) {
    missingMarker := "__AHK_V9_MISSING_" . TickNow() . "_" . keyName . "__"
    IniRead, currentValue, %fileName%, %sectionName%, %keyName%, %missingMarker%
    if (currentValue != missingMarker)
        return true
    if (encodeText)
        return IniWriteText(defaultValue, fileName, sectionName, keyName)
    CheckedIniWrite(defaultValue, fileName, sectionName, keyName)
    return !ErrorLevel
}

MigrateV9Configuration(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    defaults := []
    defaults.Push({Key: "ReportRole", Value: "", Text: 0})
    defaults.Push({Key: "T_CivilCallStart", Value: "/r Экипаж {PATROL_UNIT}, приняли вызов от гражданского, выдвигаемся.", Text: 1})
    defaults.Push({Key: "T_CivilCallArrive", Value: "/r Экипаж {PATROL_UNIT}, прибыли на вызов от гражданского.", Text: 1})
    defaults.Push({Key: "Bind_CivilCallStart", Value: "", Text: 0})
    defaults.Push({Key: "Bind_CivilCallArrive", Value: "", Text: 0})
    defaults.Push({Key: "Trig_CivilCallStart", Value: "", Text: 0})
    defaults.Push({Key: "Trig_CivilCallArrive", Value: "", Text: 0})
    defaults.Push({Key: "Bind_VehicleLookup", Value: "", Text: 0})
    defaults.Push({Key: "Trig_VehicleLookup", Value: "!поисктс", Text: 0})
    defaults.Push({Key: "Bind_WantedRemoval", Value: "", Text: 0})
    defaults.Push({Key: "Trig_WantedRemoval", Value: "!снятие", Text: 0})
    defaults.Push({Key: "AutoReportMode", Value: "Off", Text: 0})
    defaults.Push({Key: "AutoReportDurationMin", Value: 15, Text: 0})

    ok := true
    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        Loop % defaults.Length()
        {
            item := defaults[A_Index]
            if !IniWriteDefaultIfMissing(fileName, sectionName, item.Key, item.Value, item.Text)
                ok := false
        }
    }
    return ok
}

MigrateV11Configuration(fileName) {
    global AppVersion
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    defaults := []
    defaults.Push({Key: "ReportRole", Value: "Начальник МДС ГАИ", Text: 0})
    defaults.Push({Key: "T_CivilCallStart", Value: "/r докладывает {SURNAME}: принял вызов гражданского.", Text: 1})
    defaults.Push({Key: "T_CivilCallArrive", Value: "/r докладывает {SURNAME}: прибыл на вызов гражданского.", Text: 1})
    defaults.Push({Key: "Bind_CivilCallStart", Value: "", Text: 0})
    defaults.Push({Key: "Bind_CivilCallArrive", Value: "", Text: 0})
    defaults.Push({Key: "Trig_CivilCallStart", Value: "", Text: 0})
    defaults.Push({Key: "Trig_CivilCallArrive", Value: "", Text: 0})
    defaults.Push({Key: "Bind_VehicleLookup", Value: "", Text: 0})
    defaults.Push({Key: "Trig_VehicleLookup", Value: "!поисктс", Text: 0})
    defaults.Push({Key: "Bind_WantedRemoval", Value: "", Text: 0})
    defaults.Push({Key: "Trig_WantedRemoval", Value: "!снятие", Text: 0})
    defaults.Push({Key: "Bind_ChaseNoID", Value: "Insert", Text: 0})
    defaults.Push({Key: "Trig_ChaseNoID", Value: "", Text: 0})
    defaults.Push({Key: "Bind_LawSearchSubmit", Value: "^+f", Text: 0})
    defaults.Push({Key: "AutoReportMode", Value: "Патруль", Text: 0})
    defaults.Push({Key: "AutoReportDurationMin", Value: 15, Text: 0})
    defaults.Push({Key: "Bind_ToggleHUD", Value: "F12", Text: 0})
    defaults.Push({Key: "Bind_IDOverlay", Value: "F5", Text: 0})
    defaults.Push({Key: "Bind_HideLawGui", Value: "Pause", Text: 0})

    ok := true
    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        Loop % defaults.Length()
        {
            item := defaults[A_Index]
            if !IniWriteDefaultIfMissing(fileName, sectionName, item.Key, item.Value, item.Text)
                ok := false
        }
    }
    if !IniWriteDefaultIfMissing(fileName, "Meta", "AppVersion", AppVersion)
        ok := false
    return ok
}

MigrateV12Configuration(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    ok := true
    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        if !IniWriteDefaultIfMissing(fileName, sectionName, "TerritoryMapMode", "Local")
            ok := false
    }
    return ok
}

MigrateV13Configuration(fileName) {
    IniRead, profileNames, %fileName%, Profiles, Names, Основной
    if (profileNames = "" || profileNames = "ERROR")
        profileNames := "Основной"

    defaultInitial := "/r МДС, построение на АП ГАИ. Время на сбор — {MINUTES}. Неявка без уважительной причины — выговор по п. 8.1 ВУ ОВД."
    defaultFinish := "/r МДС, построение на АП ГАИ. Время на сбор — окончено. Неявка без уважительной причины — выговор по п. 8.1 ВУ ОВД."
    brokenInitial := SubStr(defaultInitial, 4)
    brokenFinish := "r " . SubStr(defaultFinish, 4)
    ok := true
    Loop, Parse, profileNames, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        sectionName := "Profile_" . profileName
        if !IniWriteDefaultIfMissing(fileName, sectionName, "Bind_AutoPatrol", "")
            ok := false
        if !IniWriteDefaultIfMissing(fileName, sectionName, "Bind_AutoPost", "")
            ok := false
        if !IniWriteDefaultIfMissing(fileName, sectionName, "Trig_AutoPatrol", "!апатруль")
            ok := false
        if !IniWriteDefaultIfMissing(fileName, sectionName, "Trig_AutoPost", "!апост")
            ok := false

        formationInitial := IniReadText(fileName, sectionName, "MDS_FormationInitial", "")
        formationCountdown := IniReadText(fileName, sectionName, "MDS_FormationCountdown", "")
        formationFinish := IniReadText(fileName, sectionName, "MDS_FormationFinish", "")
        if (formationInitial = brokenInitial && !IniWriteText(defaultInitial, fileName, sectionName, "MDS_FormationInitial"))
            ok := false
        if (formationCountdown = brokenInitial && !IniWriteText(defaultInitial, fileName, sectionName, "MDS_FormationCountdown"))
            ok := false
        if (formationFinish = brokenFinish && !IniWriteText(defaultFinish, fileName, sectionName, "MDS_FormationFinish"))
            ok := false

        bindItems := IniReadText(fileName, sectionName, "BindListItems", GetDefaultBindListItems())
        normalizedItems := "`n" . StrReplace(bindItems, "`r", "") . "`n"
        bindItemsChanged := false
        if !InStr(normalizedItems, "`nAutoPatrol`n")
        {
            bindItems .= (bindItems = "" ? "" : "`n") . "AutoPatrol"
            bindItemsChanged := true
        }
        if !InStr("`n" . StrReplace(bindItems, "`r", "") . "`n", "`nAutoPost`n")
        {
            bindItems .= (bindItems = "" ? "" : "`n") . "AutoPost"
            bindItemsChanged := true
        }
        if (bindItemsChanged && !IniWriteText(bindItems, fileName, sectionName, "BindListItems"))
            ok := false

        IniDelete, %fileName%, %sectionName%, MDS_EvacReminder
        IniDelete, %fileName%, %sectionName%, Bind_MDSEvacReminder
        IniDelete, %fileName%, %sectionName%, Trig_MDSEvacReminder
        IniDelete, %fileName%, %sectionName%, MDS_UrgentReminder
        IniDelete, %fileName%, %sectionName%, Bind_MDSUrgentReminder
        IniDelete, %fileName%, %sectionName%, Trig_MDSUrgentReminder
    }
    if !IniWriteDefaultIfMissing(fileName, "UI", "EvacuationTimerEnabled", "On")
        ok := false
    if !IniWriteDefaultIfMissing(fileName, "UI", "PatrolTimerEnabled", "On")
        ok := false
    if !IniWriteDefaultIfMissing(fileName, "UI", "PostTimerEnabled", "On")
        ok := false
    return ok
}

MigrateConfigInPlace() {
    global ConfigFile, ConfigVersion, MockMode, ChatQueueEnabled, ChatQueueMinDelay, TextSendMode, GameProcessName
    if !EnsureConfigFilePath("MigrateConfigIfNeeded", 1)
        return
    IniRead, storedVersion, %ConfigFile%, Meta, ConfigVersion, 0
    storedVersion += 0
    if (storedVersion > ConfigVersion)
    {
        LogError("Config", "Configuration schema v" . storedVersion . " is newer than supported v" . ConfigVersion . "; migration skipped.", "WARN")
        ConfigReadOnly := 1
        return false
    }
    if (storedVersion = ConfigVersion)
        return true
    backupFile := CreateConfigBackup("migrate_v" . ConfigVersion, 1)
    if (backupFile = "")
    {
        LogError("Config", "Migration aborted: active INI backup failed.")
        return false
    }
    if (storedVersion < 3)
    {
        IniRead, legacyTab, %ConfigFile%, UI, SettingsTargetTab, 1
        pageId := SettingsPageIdFromLegacyTab(legacyTab)
        CheckedIniWrite(pageId, ConfigFile, "UI", "SettingsPage")
        CheckedIniWrite(pageId, ConfigFile, "WINDOW_SETTINGS", "Page")

        IniRead, oldTheme, %ConfigFile%, UI, ThemeMode, Graphite
        IniRead, customMenu, %ConfigFile%, UI, CustomMenuColor,
        IniRead, customText, %ConfigFile%, UI, CustomTextColor,
        IniRead, customBorder, %ConfigFile%, UI, CustomBorderColor,
        IniRead, customTab, %ConfigFile%, UI, CustomTabColor,
        if (oldTheme = "Black" && customMenu = "" && customText = "" && customBorder = "" && customTab = "")
            CheckedIniWrite("Graphite", ConfigFile, "UI", "ThemeMode")
    }
    if (storedVersion < 4)
    {
        IniRead, oldSendMode, %ConfigFile%, UI, TextSendMode, Memory
        TextSendMode := (oldSendMode = "Keyboard") ? "Keyboard" : "Auto"
        IniRead, GameProcessName, %ConfigFile%, UI, GameProcessName, gta_sa.exe
        NormalizeGameProcessName(GameProcessName)
        CheckedIniWrite(TextSendMode, ConfigFile, "UI", "TextSendMode")
        CheckedIniWrite(GameProcessName, ConfigFile, "UI", "GameProcessName")
    }
    if (storedVersion < 5)
        MigrateContextAssistantProfiles(ConfigFile)
    if (storedVersion < 6)
        MigrateV6Configuration(ConfigFile)
    if (storedVersion < 7)
        MigrateV7Configuration(ConfigFile)
    if (storedVersion < 9 && !MigrateV9Configuration(ConfigFile))
    {
        LogError("Config", "Migration v9 failed; ConfigVersion was not updated.")
        return false
    }
    if (storedVersion < 11 && !MigrateV11Configuration(ConfigFile))
    {
        LogError("Config", "Migration v11 failed; ConfigVersion was not updated.")
        return false
    }
    if (storedVersion < 12 && !MigrateV12Configuration(ConfigFile))
    {
        LogError("Config", "Migration v12 failed; ConfigVersion was not updated.")
        return false
    }
    if (storedVersion < 13 && !MigrateV13Configuration(ConfigFile))
    {
        LogError("Config", "Migration v13 failed; ConfigVersion was not updated.")
        return false
    }
    if !IniWriteDefaultIfMissing(ConfigFile, "UI", "MockMode", MockMode)
        return false
    if !IniWriteDefaultIfMissing(ConfigFile, "UI", "ChatQueueEnabled", ChatQueueEnabled)
        return false
    if !IniWriteDefaultIfMissing(ConfigFile, "UI", "ChatQueueMinDelay", ChatQueueMinDelay)
        return false
    CheckedIniWrite(ConfigVersion, ConfigFile, "Meta", "ConfigVersion")
    if (ErrorLevel)
    {
        LogError("Config", "Migration completed, but ConfigVersion could not be updated.")
        return false
    }
    LogError("Config", "Migrated config from v" . storedVersion . " to v" . ConfigVersion, "INFO")
    return true
}
InitProfiles() {
    global ConfigFile
    if !EnsureConfigFilePath("InitProfiles")
        return
    if !FileExist(ConfigFile)
    {
        if !SaveProfile("Основной")
            return
        CheckedIniWrite("Основной", ConfigFile, "Profiles", "Names")
        CheckedIniWrite("Основной", ConfigFile, "Profiles", "Last")
        SaveUISettings()
        return
    }
    IniRead, names, %ConfigFile%, Profiles, Names, ERROR
    if (names = "ERROR" or names = "")
    {
        CheckedIniWrite("Основной", ConfigFile, "Profiles", "Names")
        if !ProfileExists("Основной")
            if !SaveProfile("Основной")
                return
    }
}

ProfileExists(profileName) {
    global ConfigFile
    if !EnsureConfigFilePath("ProfileExists")
        return 0
    NormalizeProfileNameValue(profileName)
    section := "Profile_" . profileName
    IniRead, val, %ConfigFile%, %section%, IntroRole, __NO__
    return (val != "__NO__")
}

GetProfilesString() {
    global ConfigFile
    if !EnsureConfigFilePath("GetProfilesString")
        return "Основной"
    IniRead, names, %ConfigFile%, Profiles, Names, Основной
    return names
}

GetFirstProfileName() {
    names := GetProfilesString()
    Loop, Parse, names, |
    {
        if (A_LoopField != "")
            return A_LoopField
    }
    return "Основной"
}

AddProfileToList(profileName) {
    global ConfigFile
    if !EnsureConfigFilePath("AddProfileToList")
        return
    NormalizeProfileNameValue(profileName)
    names := GetProfilesString()
    found := false
    Loop, Parse, names, |
    {
        if (A_LoopField = profileName) {
            found := true
            break
        }
    }
    if !found
    {
        if (names = "" or names = "ERROR")
            names := profileName
        else
            names := names . "|" . profileName
        CheckedIniWrite(names, ConfigFile, "Profiles", "Names")
    }
}

RemoveProfileFromList(profileName) {
    global ConfigFile
    if !EnsureConfigFilePath("RemoveProfileFromList")
        return
    NormalizeProfileNameValue(profileName)
    names := GetProfilesString()
    newNames := ""
    Loop, Parse, names, |
    {
        item := A_LoopField
        if (item = "" or item = profileName)
            continue
        if (newNames = "")
            newNames := item
        else
            newNames := newNames . "|" . item
    }
    if (newNames = "")
        newNames := "Основной"
    CheckedIniWrite(newNames, ConfigFile, "Profiles", "Names")
}

LoadLastProfile() {
    if !EnsureConfigFilePath("LoadLastProfile")
        return
    LoadProfile(GetSafeLastProfileName())
}

WriteCurrentThemeToFile(filePath, sectionName) {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global UIRoundness, InnerRoundness, GuiTransparency, BackgroundImageURL
    global HUDMode, MenuTransparency, HUDTransparency, BindListTransparency
    if (filePath = "" || sectionName = "")
    {
        LogError("WriteCurrentThemeToFile", "Empty file path or section.")
        return 0
    }
    CheckedIniWrite(ThemeMode, filePath, sectionName, "ThemeMode")
    CheckedIniWrite(CustomMenuColor, filePath, sectionName, "CustomMenuColor")
    CheckedIniWrite(CustomTextColor, filePath, sectionName, "CustomTextColor")
    CheckedIniWrite(CustomBorderColor, filePath, sectionName, "CustomBorderColor")
    CheckedIniWrite(CustomTabColor, filePath, sectionName, "CustomTabColor")
    CheckedIniWrite(CustomBindListColor, filePath, sectionName, "CustomBindListColor")
    CheckedIniWrite(UIRoundness, filePath, sectionName, "UIRoundness")
    CheckedIniWrite(InnerRoundness, filePath, sectionName, "InnerRoundness")
    CheckedIniWrite(GuiTransparency, filePath, sectionName, "GuiTransparency")
    CheckedIniWrite(BackgroundImageURL, filePath, sectionName, "BackgroundImageURL")
    CheckedIniWrite(HUDMode, filePath, sectionName, "HUDMode")
    CheckedIniWrite(MenuTransparency, filePath, sectionName, "MenuTransparency")
    CheckedIniWrite(HUDTransparency, filePath, sectionName, "HUDTransparency")
    CheckedIniWrite(BindListTransparency, filePath, sectionName, "BindListTransparency")
    return !ConfigWriteFailed
}

LoadThemeFromFile(filePath, sectionName) {
    global ThemeMode, CustomMenuColor, CustomTextColor, CustomBorderColor, CustomTabColor, CustomBindListColor
    global UIRoundness, InnerRoundness, GuiTransparency, BackgroundImageURL, BackgroundImageFile
    global HUDMode, MenuTransparency, HUDTransparency, BindListTransparency
    if (!FileExist(filePath) || sectionName = "")
    {
        LogError("LoadThemeFromFile", "Missing file or section: " . filePath . " | " . sectionName)
        return 0
    }
    IniRead, ThemeMode, %filePath%, %sectionName%, ThemeMode, %ThemeMode%
    IniRead, CustomMenuColor, %filePath%, %sectionName%, CustomMenuColor, %CustomMenuColor%
    IniRead, CustomTextColor, %filePath%, %sectionName%, CustomTextColor, %CustomTextColor%
    IniRead, CustomBorderColor, %filePath%, %sectionName%, CustomBorderColor, %CustomBorderColor%
    IniRead, CustomTabColor, %filePath%, %sectionName%, CustomTabColor, %CustomTabColor%
    IniRead, CustomBindListColor, %filePath%, %sectionName%, CustomBindListColor, %CustomBindListColor%
    IniRead, UIRoundness, %filePath%, %sectionName%, UIRoundness, %UIRoundness%
    IniRead, InnerRoundness, %filePath%, %sectionName%, InnerRoundness, %InnerRoundness%
    IniRead, GuiTransparency, %filePath%, %sectionName%, GuiTransparency, %GuiTransparency%
    IniRead, BackgroundImageURL, %filePath%, %sectionName%, BackgroundImageURL, %BackgroundImageURL%
    IniRead, HUDMode, %filePath%, %sectionName%, HUDMode, %HUDMode%
    IniRead, MenuTransparency, %filePath%, %sectionName%, MenuTransparency, %MenuTransparency%
    IniRead, HUDTransparency, %filePath%, %sectionName%, HUDTransparency, %HUDTransparency%
    IniRead, BindListTransparency, %filePath%, %sectionName%, BindListTransparency, %BindListTransparency%
    NormalizeThemeMode(ThemeMode)
    NormalizeColorNumber(CustomMenuColor)
    NormalizeColorNumber(CustomTextColor)
    NormalizeColorNumber(CustomBorderColor)
    NormalizeColorNumber(CustomTabColor)
    NormalizeColorNumber(CustomBindListColor)
    NormalizeNumberRange(UIRoundness, 18, 0, 45)
    NormalizeNumberRange(InnerRoundness, 14, 0, 45)
    NormalizeNumberRange(GuiTransparency, 225, 120, 255)
    NormalizeNumberRange(MenuTransparency, 225, 120, 255)
    NormalizeNumberRange(HUDTransparency, 225, 120, 255)
    NormalizeNumberRange(BindListTransparency, 225, 120, 255)
    ResolveBackgroundImage()
    SaveUISettings()
    return 1
}

ExportProfilesPack() {
    global ConfigFile, CurrentProfile
    if !EnsureConfigFilePath("ExportProfilesPack", 1)
        return 0
    if (CurrentProfile = "")
        CurrentProfile := "Основной"
    if !SaveProfile(CurrentProfile)
        return
    SaveUISettings()
    defaultName := A_ScriptDir . "\profiles_export.ini"
    FileSelectFile, outPath, S16, %defaultName%, Экспорт профилей, INI Files (*.ini)
    if (outPath = "")
        return -1
    if !CopyIniFileWithOverwrite(ConfigFile, outPath, "ExportProfilesPack")
    {
        MsgBox, 48, Ошибка, Не удалось экспортировать профили.
        return 0
    }
    MsgBox, 64, Готово, Профили экспортированы.
    return 1
}

ValidateProfilesImportFile(filePath, ByRef errText) {
    errText := ""
    if (filePath = "" || !FileExist(filePath))
    {
        errText := "Файл профилей не найден."
        return false
    }

    FileGetSize, fileSize, %filePath%
    if (ErrorLevel || fileSize <= 0)
    {
        errText := "Файл профилей пустой."
        return false
    }

    IniRead, names, %filePath%, Profiles, Names, __MISSING__
    names := Trim(names)
    if (names = "" || names = "ERROR" || names = "__MISSING__")
    {
        errText := "В файле нет списка профилей [Profiles]/Names."
        return false
    }

    profileCount := 0
    missingSections := ""
    Loop, Parse, names, |
    {
        profileName := Trim(A_LoopField)
        if (profileName = "")
            continue
        NormalizeProfileNameValue(profileName)
        profileCount++
        section := "Profile_" . profileName
        IniRead, marker, %filePath%, %section%, IntroRole, __MISSING__
        if (marker = "__MISSING__")
        {
            if (missingSections = "")
                missingSections := section
            else
                missingSections := missingSections . ", " . section
        }
    }

    if (profileCount <= 0)
    {
        errText := "Список профилей пуст."
        return false
    }

    if (missingSections != "")
    {
        errText := "Не найдены секции профилей: " . missingSections
        return false
    }

    return true
}

ImportProfilesPack() {
    global ConfigFile
    if !EnsureConfigFilePath("ImportProfilesPack", 1)
        return 0
    FileSelectFile, inPath, 3,, Импорт профилей, INI Files (*.ini)
    if (inPath = "")
        return -1
    if !FileExist(inPath)
    {
        LogError("ImportProfilesPack", "Selected file not found: " . inPath)
        MsgBox, 48, Ошибка, Файл профилей не найден.
        return 0
    }
    if !ValidateProfilesImportFile(inPath, importErr)
    {
        LogError("ImportProfilesPack", "Validation failed: " . importErr)
        MsgBox, 48, Ошибка, %importErr%
        return 0
    }
    CreateConfigBackup("profiles_import")
    if !CopyIniFileWithOverwrite(inPath, ConfigFile, "ImportProfilesPack")
    {
        MsgBox, 48, Ошибка, Не удалось импортировать профили.
        return 0
    }
    RefreshAfterProfilesImport()
    MsgBox, 64, Готово, Профили импортированы.
    return 1
}

ExportThemeToFile() {
    defaultName := A_ScriptDir . "\theme_export.ini"
    FileSelectFile, outPath, S16, %defaultName%, Экспорт темы, INI Files (*.ini)
    if (outPath = "")
        return
    if !WriteCurrentThemeToFile(outPath, "Theme_Export")
    {
        LogError("ExportThemeToFile", "Write failed: " . outPath)
        MsgBox, 48, Ошибка, Не удалось экспортировать тему.
        return
    }
    MsgBox, 64, Готово, Тема экспортирована.
}

ImportThemeFromExternalFile() {
    FileSelectFile, inPath, 3,, Импорт темы, INI Files (*.ini)
    if (inPath = "")
        return
    if !FileExist(inPath)
    {
        LogError("ImportThemeFromExternalFile", "Selected file not found: " . inPath)
        MsgBox, 48, Ошибка, Файл темы не найден.
        return
    }
    if !LoadThemeFromFile(inPath, "Theme_Export")
    {
        LogError("ImportThemeFromExternalFile", "Load failed: " . inPath)
        MsgBox, 48, Ошибка, Не удалось импортировать тему.
        return
    }
    RefreshAfterThemeImport()
    MsgBox, 64, Готово, Тема импортирована.
}

LoadProfileIdentityFromIni(fileName, sectionName) {
    global IntroRole, Rank, ReportRank, Surname, PersonalBadge
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount

    IniRead, IntroRole, %fileName%, %sectionName%, IntroRole, Сотрудник патрульно-постовой службы
    IniRead, Rank, %fileName%, %sectionName%, Rank, лейтенант
    IniRead, ReportRank, %fileName%, %sectionName%, ReportRank, лейтенант
    IniRead, Surname, %fileName%, %sectionName%, Surname, Лукашенко
    IniRead, PersonalBadge, %fileName%, %sectionName%, PersonalBadge,

    IniRead, PatrolRoute, %fileName%, %sectionName%, PatrolRoute, г.Арзамас
    IniRead, PostRoute, %fileName%, %sectionName%, PostRoute, Дорожная сеть в центре г.Арзамас
    IniRead, ConvoyRoute, %fileName%, %sectionName%, ConvoyRoute, C-2, К-1
    IniRead, PatrolUnit, %fileName%, %sectionName%, PatrolUnit, Р0043
    IniRead, PatrolCrewCount, %fileName%, %sectionName%, PatrolCrewCount, 2
    IniRead, PostUnit, %fileName%, %sectionName%, PostUnit, Р0049
    IniRead, PostCrewCount, %fileName%, %sectionName%, PostCrewCount, 2
}

LoadProfileTemplateTextsFromIni(fileName, sectionName) {
    global T_Intro, T_Dep, T_SOSStart, T_SOSArrive
    global T_HijackStart, T_HijackArrive
    global T_CallStart, T_CallArrive, T_CallWorkStart, T_CallWorkEnd
    global T_PatrolStart, T_PatrolContinue, T_PatrolEnd
    global T_PostStart, T_PostContinue, T_PostEnd
    global T_ConvoyStart, T_ConvoyCont, T_ConvoyEnd

    T_Intro := IniReadText(fileName, sectionName, "T_Intro", "Здравия желаю, являюсь {INTRO_ROLE}, {RANK} полиции {SURNAME}.")
    T_Dep := IniReadText(fileName, sectionName, "T_Dep", "/d [ГАИ/] говорит {REPORT_ROLE}, {REPORT_RANK} полиции {SURNAME}, на связь.")
    T_SOSStart := IniReadText(fileName, sectionName, "T_SOSStart", "/r докладывает {SURNAME}: реагирую на вызов срочной помощи.")
    T_SOSArrive := IniReadText(fileName, sectionName, "T_SOSArrive", "/r докладывает {SURNAME}: прибыл на вызов срочной помощи.")
    T_HijackStart := IniReadText(fileName, sectionName, "T_HijackStart", "/r Экипаж {PATROL_UNIT}, приняли сообщение об угоне, выдвигаемся.")
    T_HijackArrive := IniReadText(fileName, sectionName, "T_HijackArrive", "/r Экипаж {PATROL_UNIT}, прибыли по сообщению об угоне.")
    T_CallStart := IniReadText(fileName, sectionName, "T_CallStart", "/r докладывает экипаж {PATROL_UNIT}: принял вызов о ДТП.")
    T_CallArrive := IniReadText(fileName, sectionName, "T_CallArrive", "/r докладывает экипаж {PATROL_UNIT}: прибыли на вызов о ДТП.")
    T_CallWorkStart := IniReadText(fileName, sectionName, "T_CallWorkStart", "/r докладывает экипаж {PATROL_UNIT}: приступили к оформлению ДТП.")
    T_CallWorkEnd := IniReadText(fileName, sectionName, "T_CallWorkEnd", "/r докладывает экипаж {PATROL_UNIT}: завершили оформление ДТП.")
    T_PatrolStart := IniReadText(fileName, sectionName, "T_PatrolStart", "/r докладывает экипаж {PATROL_UNIT}: заступили на патрулирование по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек.")
    T_PatrolContinue := IniReadText(fileName, sectionName, "T_PatrolContinue", "/r докладывает экипаж {PATROL_UNIT}: патрулируем по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек.")
    T_PatrolEnd := IniReadText(fileName, sectionName, "T_PatrolEnd", "/r докладывает экипаж {PATROL_UNIT}: завершили патруль по маршруту {PATROL_ROUTE} в составе {PATROL_CREW_COUNT} человек.")
    T_PostStart := IniReadText(fileName, sectionName, "T_PostStart", "/r докладывает экипаж {POST_UNIT}: заступили на пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек.")
    T_PostContinue := IniReadText(fileName, sectionName, "T_PostContinue", "/r докладывает экипаж {POST_UNIT}: продолжаем стоять на посту {POST_ROUTE} в составе {POST_CREW_COUNT} человек.")
    T_PostEnd := IniReadText(fileName, sectionName, "T_PostEnd", "/r докладывает экипаж {POST_UNIT}: покинули пост {POST_ROUTE} в составе {POST_CREW_COUNT} человек.")
    T_ConvoyStart := IniReadText(fileName, sectionName, "T_ConvoyStart", "/r докладывает экипаж {PATROL_UNIT}: начали сопровождение военной колонны по маршруту {CONVOY_ROUTE}.")
    T_ConvoyCont := IniReadText(fileName, sectionName, "T_ConvoyCont", "/r докладывает экипаж {PATROL_UNIT}: продолжаем сопровождение военной колонны по маршруту {CONVOY_ROUTE}.")
    T_ConvoyEnd := IniReadText(fileName, sectionName, "T_ConvoyEnd", "/r докладывает экипаж {PATROL_UNIT}: закончили сопровождение военной колонны по маршруту {CONVOY_ROUTE}.")
}

LoadProfileRpTextsFromIni(fileName, sectionName) {
    global RP_StopChase, RP_Deject, RP_InCar, RP_Doc, RP_Search, RP_TowStart, RP_TowEnd, RP_CarSearch, RP_Arrest, RP_Fine, RP_Protocol, RP_Rights, RP_CardDS, RP_CardVK
    global MDS_FormationInitial, MDS_FormationCountdown, MDS_FormationFinish

    RP_StopChase := IniReadText(fileName, sectionName, "RP_StopChase", "/m [ПОЛИЦИЯ] Водитель, примите вправо и остановитесь у обочины.`n/m [ПОЛИЦИЯ] Заглушите двигатель и оставайтесь в автомобиле.")
    RP_Deject := IniReadText(fileName, sectionName, "RP_Deject", "/me подошел к патрульному автомобилю.`n/me открыл дверь патрульного автомобиля.`n/me отстегнул задержанного ремнем безопасности.`n/me аккуратно достал задержанного из автомобиля")
    RP_InCar := IniReadText(fileName, sectionName, "RP_InCar", "/me подошел к патрульному автомобилю.`n/me открыл дверь патрульного автомобиля.`n/me аккуратно посадил задержанного в автомобиль.`n/me пристегнул задержанного ремнем безопасности.`n/do Задержанный находится на заднем сиденье патрульного автомобиля.")
    RP_Doc := IniReadText(fileName, sectionName, "RP_Doc", "/do Служебное удостоверение находится в нагрудном кармане формы.`n/me достал служебное удостоверение из нагрудного кармана.`n/me раскрыл удостоверение.`n/me показал удостоверение человеку напротив.`n/me после ознакомления закрыл удостоверение.`n/me убрал удостоверение обратно в нагрудный карман")
    RP_Search := IniReadText(fileName, sectionName, "RP_Search", "/do Чистые резиновые перчатки находятся в кармане формы.`n/me достал резиновые перчатки из кармана.`n/me надел резиновые перчатки на руки.`n/do Резиновые перчатки надеты.`n/me начал проводить личный досмотр человека напротив.`n/me проверил карманы, пояс и личные вещи гражданина.`n/me внимательно осмотрел содержимое карманов.`n/do Личный досмотр гражданина завершен.")
    RP_TowStart := IniReadText(fileName, sectionName, "RP_TowStart", "/r докладывает {SURNAME}: начал эвакуировать ТС на штрафстоянку.`n/me подошел к эвакуируемому автомобилю.`n/me достал крюк эвакуатора и закрепил его за автомобиль.`n/do Крюк эвакуатора закреплен на автомобиле.`n/tow")
    RP_TowStart := TowStart_EnsureTowLast(RP_TowStart)
    RP_TowEnd := IniReadText(fileName, sectionName, "RP_TowEnd", "/me остановил эвакуатор на территории штраф стоянки.`n/me отцепил крюк эвакуатора от автомобиля.`n/do Автомобиль находится на территории штраф стоянки.`n/r докладывает {SURNAME}: эвакуировал ТС на штрафстоянку.")
    RP_CarSearch := IniReadText(fileName, sectionName, "RP_CarSearch", "/do Резиновые перчатки находятся в кармане формы.`n/me достал резиновые перчатки из кармана.`n/me надел резиновые перчатки на руки.`n/do Перчатки надеты.`n/me открыл дверь автомобиля.`n/me начал осматривать салон автомобиля.`n/me проверил бардачок, карманы дверей и пространство под сиденьями.`n/me открыл багажник автомобиля.`n/me внимательно осмотрел содержимое багажника.`n/do Досмотр транспортного средства завершен.")
    RP_Arrest := IniReadText(fileName, sectionName, "RP_Arrest", "/me взял рацию с плеча.`n/me нажал кнопку передачи на рации.`n/me вызвал дежурного.`n/do Сообщение по рации передано дежурному.`n/do Дежурный подошел к сотруднику полиции.`n/me передал задержанного дежурному.`n/me передал сопроводительную информацию по задержанному.`n/do Дежурный увел задержанного и поместил его в КПЗ.")
    RP_Fine := IniReadText(fileName, sectionName, "RP_Fine", "/do КПК находится в подсумке на поясе сотрудника.`n/me достал КПК из подсумка.`n/me включил КПК.`n/me авторизовался в системе МВД.`n/me ввел данные гражданина с лицензии.`n/do Данные гражданина найдены в базе данных.`n/me начал оформлять штраф через КПК.`n/me внес статью нарушения и сумму штрафа.`n/do Штраф успешно оформлен.")
    RP_Protocol := IniReadText(fileName, sectionName, "RP_Protocol", "/do Бланк протокола находится в планшете сотрудника.`n/me достал бланк протокола и ручку.`n/me разложил бланк протокола на планшете.`n/me начал заполнять протокол.`n/me вписал личные данные задержанного.`n/me указал обстоятельства и причину задержания.`n/me указал дату и время составления протокола.`n/me внимательно проверил заполненные данные.`n/me поставил подпись в протоколе.`n/do Протокол заполнен.`nРасписываться в протоколе будете?")
    RP_Rights := IniReadText(fileName, sectionName, "RP_Rights", "Вы имеете право на отказ от дачи показаний против себя и своих близких.`nВы имеете на ознакомление со всеми протоколами, составленными при задержании.`nВы имеете право на адвоката, переводчика и медицинскую помощь. Вам они будут предоставлены в ИВС.`nВы имеете право на один телефонный звонок.`nЕсли вы желаете обжаловать задержание, можете оставить жалобу на официальном портале области.")
    RP_CardDS := IniReadText(fileName, sectionName, "RP_CardDS", "/me достал визитку из нагрудного кармана и передал человеку напротив.`n/b Это дискорд: «sbezruk180.»")
    RP_CardVK := IniReadText(fileName, sectionName, "RP_CardVK", "/me достал визитку из нагрудного кармана и передал человеку напротив.`n/b Это ВК: «sbezruk180.»")
    MDS_FormationInitial := IniReadText(fileName, sectionName, "MDS_FormationInitial", MDS_FormationInitial)
    MDS_FormationCountdown := IniReadText(fileName, sectionName, "MDS_FormationCountdown", MDS_FormationCountdown)
    MDS_FormationFinish := IniReadText(fileName, sectionName, "MDS_FormationFinish", MDS_FormationFinish)
}

LoadProfileV9FieldsFromIni(fileName, sectionName) {
    global ReportRole, T_CivilCallStart, T_CivilCallArrive
    global Bind_CivilCallStart, Bind_CivilCallArrive, Trig_CivilCallStart, Trig_CivilCallArrive
    global Bind_VehicleLookup, Trig_VehicleLookup, Bind_WantedRemoval, Trig_WantedRemoval
    global Bind_ChaseNoID, Trig_ChaseNoID, Bind_LawSearchSubmit
    global AutoReportMode, AutoReportDurationMin, TerritoryMapMode

    IniRead, ReportRole, %fileName%, %sectionName%, ReportRole, Начальник МДС ГАИ
    T_CivilCallStart := IniReadText(fileName, sectionName, "T_CivilCallStart", "/r докладывает {SURNAME}: принял вызов гражданского.")
    T_CivilCallArrive := IniReadText(fileName, sectionName, "T_CivilCallArrive", "/r докладывает {SURNAME}: прибыл на вызов гражданского.")
    IniRead, Bind_CivilCallStart, %fileName%, %sectionName%, Bind_CivilCallStart,
    IniRead, Bind_CivilCallArrive, %fileName%, %sectionName%, Bind_CivilCallArrive,
    IniRead, Trig_CivilCallStart, %fileName%, %sectionName%, Trig_CivilCallStart,
    IniRead, Trig_CivilCallArrive, %fileName%, %sectionName%, Trig_CivilCallArrive,
    IniRead, Bind_VehicleLookup, %fileName%, %sectionName%, Bind_VehicleLookup,
    IniRead, Trig_VehicleLookup, %fileName%, %sectionName%, Trig_VehicleLookup, !поисктс
    IniRead, Bind_WantedRemoval, %fileName%, %sectionName%, Bind_WantedRemoval,
    IniRead, Trig_WantedRemoval, %fileName%, %sectionName%, Trig_WantedRemoval, !снятие
    IniRead, Bind_ChaseNoID, %fileName%, %sectionName%, Bind_ChaseNoID, Insert
    IniRead, Trig_ChaseNoID, %fileName%, %sectionName%, Trig_ChaseNoID,
    IniRead, Bind_LawSearchSubmit, %fileName%, %sectionName%, Bind_LawSearchSubmit, ^+f
    IniRead, AutoReportMode, %fileName%, %sectionName%, AutoReportMode, Патруль
    IniRead, AutoReportDurationMin, %fileName%, %sectionName%, AutoReportDurationMin, 15
    IniRead, TerritoryMapMode, %fileName%, %sectionName%, TerritoryMapMode, Local
    TerritoryMapMode_Normalize(TerritoryMapMode)
    AutoReport_NormalizeMode(AutoReportMode)
    if !AutoReport_IsValidDuration(AutoReportDurationMin)
        AutoReportDurationMin := 15
}

WriteProfileV9FieldsToIni(fileName, sectionName) {
    global ReportRole, T_CivilCallStart, T_CivilCallArrive
    global Bind_CivilCallStart, Bind_CivilCallArrive, Trig_CivilCallStart, Trig_CivilCallArrive
    global Bind_VehicleLookup, Trig_VehicleLookup, Bind_WantedRemoval, Trig_WantedRemoval
    global Bind_ChaseNoID, Trig_ChaseNoID, Bind_LawSearchSubmit
    global AutoReportMode, AutoReportDurationMin, TerritoryMapMode

    ok := true
    CheckedIniWrite(ReportRole, fileName, sectionName, "ReportRole")
    if (ErrorLevel)
        ok := false
    if !IniWriteText(T_CivilCallStart, fileName, sectionName, "T_CivilCallStart")
        ok := false
    if !IniWriteText(T_CivilCallArrive, fileName, sectionName, "T_CivilCallArrive")
        ok := false
    CheckedIniWrite(Bind_CivilCallStart, fileName, sectionName, "Bind_CivilCallStart")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Bind_CivilCallArrive, fileName, sectionName, "Bind_CivilCallArrive")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Trig_CivilCallStart, fileName, sectionName, "Trig_CivilCallStart")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Trig_CivilCallArrive, fileName, sectionName, "Trig_CivilCallArrive")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Bind_VehicleLookup, fileName, sectionName, "Bind_VehicleLookup")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Trig_VehicleLookup, fileName, sectionName, "Trig_VehicleLookup")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Bind_WantedRemoval, fileName, sectionName, "Bind_WantedRemoval")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Trig_WantedRemoval, fileName, sectionName, "Trig_WantedRemoval")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Bind_ChaseNoID, fileName, sectionName, "Bind_ChaseNoID")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Trig_ChaseNoID, fileName, sectionName, "Trig_ChaseNoID")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(Bind_LawSearchSubmit, fileName, sectionName, "Bind_LawSearchSubmit")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(AutoReportMode, fileName, sectionName, "AutoReportMode")
    if (ErrorLevel)
        ok := false
    CheckedIniWrite(AutoReportDurationMin, fileName, sectionName, "AutoReportDurationMin")
    if (ErrorLevel)
        ok := false
    TerritoryMapMode_Normalize(TerritoryMapMode)
    CheckedIniWrite(TerritoryMapMode, fileName, sectionName, "TerritoryMapMode")
    if (ErrorLevel)
        ok := false
    return ok
}

LoadContextAssistantProfileFromIni(fileName, sectionName) {
    global AssistOOPEnabled, AssistStunEnabled, AssistChaseEnabled
    global AssistHouseEnabled, AssistDrugsEnabled, AssistPDPCuffEnabled
    global AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    global AutoTargetIDEnabled

    IniRead, AssistOOPEnabled, %fileName%, %sectionName%, AssistOOPEnabled, On
    IniRead, AssistStunEnabled, %fileName%, %sectionName%, AssistStunEnabled, On
    IniRead, AssistChaseEnabled, %fileName%, %sectionName%, AssistChaseEnabled, On
    IniRead, AssistHouseEnabled, %fileName%, %sectionName%, AssistHouseEnabled, On
    IniRead, AssistDrugsEnabled, %fileName%, %sectionName%, AssistDrugsEnabled, On
    IniRead, AssistPDPCuffEnabled, %fileName%, %sectionName%, AssistPDPCuffEnabled, On
    IniRead, AutoTargetIDEnabled, %fileName%, %sectionName%, AutoTargetIDEnabled, On
    NormalizeOnOff(AssistOOPEnabled, "On")
    NormalizeOnOff(AssistStunEnabled, "On")
    NormalizeOnOff(AssistChaseEnabled, "On")
    NormalizeOnOff(AssistHouseEnabled, "On")
    NormalizeOnOff(AssistDrugsEnabled, "On")
    NormalizeOnOff(AssistPDPCuffEnabled, "On")
    NormalizeOnOff(AutoTargetIDEnabled, "On")

    AssistOOPCommand := IniReadText(fileName, sectionName, "AssistOOPCommand", "/find {ID}")
    AssistTaserCommand := IniReadText(fileName, sectionName, "AssistTaserCommand", "/tazer {ID}")
    AssistBatonCommand := IniReadText(fileName, sectionName, "AssistBatonCommand", "/baton {ID}")
    if (Trim(AssistOOPCommand) = "")
        AssistOOPCommand := "/find {ID}"
    if (Trim(AssistTaserCommand) = "")
        AssistTaserCommand := "/tazer {ID}"
    if (Trim(AssistBatonCommand) = "")
        AssistBatonCommand := "/baton {ID}"
}

WriteContextAssistantProfileToIni(fileName, sectionName) {
    global AssistOOPEnabled, AssistStunEnabled, AssistChaseEnabled
    global AssistHouseEnabled, AssistDrugsEnabled, AssistPDPCuffEnabled
    global AssistOOPCommand, AssistTaserCommand, AssistBatonCommand
    global AutoTargetIDEnabled

    CheckedIniWrite(AssistOOPEnabled, fileName, sectionName, "AssistOOPEnabled")
    CheckedIniWrite(AssistStunEnabled, fileName, sectionName, "AssistStunEnabled")
    CheckedIniWrite(AssistChaseEnabled, fileName, sectionName, "AssistChaseEnabled")
    CheckedIniWrite(AssistHouseEnabled, fileName, sectionName, "AssistHouseEnabled")
    CheckedIniWrite(AssistDrugsEnabled, fileName, sectionName, "AssistDrugsEnabled")
    CheckedIniWrite(AssistPDPCuffEnabled, fileName, sectionName, "AssistPDPCuffEnabled")
    CheckedIniWrite(AutoTargetIDEnabled, fileName, sectionName, "AutoTargetIDEnabled")
    IniWriteText(AssistOOPCommand, fileName, sectionName, "AssistOOPCommand")
    IniWriteText(AssistTaserCommand, fileName, sectionName, "AssistTaserCommand")
    IniWriteText(AssistBatonCommand, fileName, sectionName, "AssistBatonCommand")
    return !ConfigWriteFailed
}

NormalizeCatalogHotkeyGlobals() {
    global
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (meta.HotkeyVar != "")
        {
            currentValue := GetDynamicGlobalValue(meta.HotkeyVar)
            NormalizeBindValue(currentValue)
            SetDynamicGlobalValue(meta.HotkeyVar, currentValue)
        }
    }
}

WriteCatalogHotkeysToIni(fileName, sectionName) {
    global
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (meta.HotkeyVar != "")
        {
            currentValue := GetDynamicGlobalValue(meta.HotkeyVar)
            CheckedIniWrite(currentValue, fileName, sectionName, meta.HotkeyVar)
        }
    }
    return !ConfigWriteFailed
}

WriteCatalogTriggersToIni(fileName, sectionName) {
    global
    catalog := GetBindCatalog()
    Loop % catalog.Length()
    {
        meta := catalog[A_Index]
        if (meta.TriggerVar != "")
        {
            currentValue := GetDynamicGlobalValue(meta.TriggerVar)
            CheckedIniWrite(currentValue, fileName, sectionName, meta.TriggerVar)
        }
    }
    return !ConfigWriteFailed
}

FinalizeLoadedProfileState(profileName) {
    global ConfigFile, CurrentProfile
    CurrentProfile := profileName
    SyncConfigOnlyProfileFieldsToCfg()
    CheckedIniWrite(profileName, ConfigFile, "Profiles", "Last")
    ApplyAllBinds()
    UpdateHUD()
    UpdateIDOverlay()
}

GetReplacementProfileAfterDelete(deletedProfile) {
    newProfile := GetFirstProfileName()
    NormalizeProfileNameValue(newProfile)
    if (newProfile = "" || newProfile = deletedProfile)
        newProfile := "Основной"
    return newProfile
}

LoadProfile(profileName) {
    global ConfigFile, CurrentProfile
    CancelAllAutomation(0)
    NormalizeProfileNameValue(profileName)
    if !EnsureConfigFilePath("LoadProfile", 1)
        return
    AutoReport_Stop(0, "profile-switch")
    ActionTimer_Clear()
    TerritoryMap_CloseAll()
    global IntroRole, Rank, ReportRank, Surname
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount
    global T_Intro, T_Dep, T_SOSStart, T_SOSArrive
    global T_HijackStart, T_HijackArrive
    global T_CallStart, T_CallArrive, T_CallWorkStart, T_CallWorkEnd
    global T_PatrolStart, T_PatrolContinue, T_PatrolEnd
    global T_PostStart, T_PostContinue, T_PostEnd
    global T_ConvoyStart, T_ConvoyCont, T_ConvoyEnd
    global RP_StopChase, RP_Deject, RP_InCar, RP_Doc, RP_Search, RP_TowStart, RP_TowEnd, RP_CarSearch, RP_Arrest, RP_Fine, RP_Protocol, RP_Rights, RP_CardDS, RP_CardVK
    global MDS_FormationInitial, MDS_FormationCountdown, MDS_FormationFinish
    global BindListItems
    global Trig_Intro, Trig_SOS, Trig_EnterID, Trig_ResetID, Trig_Chase, Trig_Deject, Trig_Cuff, Trig_InCar, Trig_StopChase, Trig_Doc, Trig_Search, Trig_Dep, Trig_WantedList, Trig_SOSStart, Trig_SOSArrive, Trig_HijackStart, Trig_HijackArrive, Trig_CallStart, Trig_CallArrive, Trig_CallWorkStart, Trig_CallWorkEnd, Trig_PatrolStart, Trig_PatrolCont, Trig_PatrolEnd, Trig_PostStart, Trig_PostCont, Trig_PostEnd, Trig_ConvoyStart, Trig_ConvoyCont, Trig_ConvoyEnd, Trig_TowStart, Trig_TowEnd, Trig_CarSearch, Trig_Arrest, Trig_Fine, Trig_Protocol, Trig_Rights, Trig_CardDS, Trig_CardVK, Trig_MDSFormation, Trig_AssistOOP, Trig_AssistStun, Trig_AssistChase, Trig_AssistHouse, Trig_AssistDrugs, Trig_AssistPDPCuff, Trig_OpenBindsTab, Trig_MaskCall, Trig_RecordCheck, Trig_TrainCrash, Trig_PersonalFile, Trig_Su, Trig_GpsD, Trig_GpsOS, Trig_MDC, Trig_VU, Trig_FP, Trig_KON, Trig_FZOP, Trig_TER, Trig_TK, Trig_ARG, Trig_UK, Trig_VV, Trig_KOAP, Trig_PDD, Trig_ORUZH, Trig_UPK, Trig_KAS, Trig_FSB, Trig_FSIN, Trig_VS, Trig_SUD, Trig_ORD, Trig_GT
    global Trig_AutoPatrol, Trig_AutoPost

    global Bind_OpenSettings, Bind_ToggleBindList, Bind_ToggleLastLawDoc, Bind_HideLawGui, Bind_ToggleHUD, Bind_IDOverlay, Bind_ConfirmID, Bind_RejectID, Bind_ResetID
    global Bind_EnterID, Bind_Intro, Bind_Chase, Bind_Deject, Bind_Cuff, Bind_InCar, Bind_StopChase, Bind_Doc, Bind_Search, Bind_SOS
    global Bind_Dep, Bind_WantedList, Bind_SOSStart, Bind_SOSArrive, Bind_HijackStart, Bind_HijackArrive, Bind_CallStart, Bind_CallArrive, Bind_CallWorkStart, Bind_CallWorkEnd
    global Bind_PatrolStart, Bind_PatrolCont, Bind_PatrolEnd
    global Bind_PostStart, Bind_PostCont, Bind_PostEnd
    global Bind_ConvoyStart, Bind_ConvoyCont, Bind_ConvoyEnd
    global Bind_TowStart, Bind_TowEnd, Bind_CarSearch, Bind_Arrest, Bind_Fine, Bind_Protocol, Bind_Rights, Bind_CardDS, Bind_CardVK, Bind_MDSFormation
    global Bind_AutoPatrol, Bind_AutoPost
    global Bind_AssistOOP, Bind_AssistStun, Bind_AssistChase, Bind_AssistHouse, Bind_AssistDrugs, Bind_AssistPDPCuff
    global Bind_OpenBindsTab, Bind_MaskCall, Bind_RecordCheck, Bind_TrainCrash, Bind_PersonalFile, Bind_Su, Bind_MDC

    section := "Profile_" . profileName

    LoadProfileIdentityFromIni(ConfigFile, section)

    LoadProfileTemplateTextsFromIni(ConfigFile, section)

    LoadProfileRpTextsFromIni(ConfigFile, section)

    LoadProfileV9FieldsFromIni(ConfigFile, section)

    LoadContextAssistantProfileFromIni(ConfigFile, section)

    IniRead, Bind_OpenSettings, %ConfigFile%, %section%, Bind_OpenSettings, F10
    IniRead, Bind_ToggleBindList, %ConfigFile%, %section%, Bind_ToggleBindList, F11
    IniRead, Bind_ToggleLastLawDoc, %ConfigFile%, %section%, Bind_ToggleLastLawDoc,
    IniRead, Bind_HideLawGui, %ConfigFile%, %section%, Bind_HideLawGui, Pause
    IniRead, Bind_ToggleHUD, %ConfigFile%, %section%, Bind_ToggleHUD, F12
    IniRead, Bind_IDOverlay, %ConfigFile%, %section%, Bind_IDOverlay, F5
    IniRead, Bind_ConfirmID, %ConfigFile%, %section%, Bind_ConfirmID, F1
    IniRead, Bind_RejectID, %ConfigFile%, %section%, Bind_RejectID, F2
    IniRead, Bind_ResetID, %ConfigFile%, %section%, Bind_ResetID, ^Numpad0
    IniRead, Bind_EnterID, %ConfigFile%, %section%, Bind_EnterID, !1
    IniRead, Bind_Intro, %ConfigFile%, %section%, Bind_Intro, !2
    IniRead, Bind_Chase, %ConfigFile%, %section%, Bind_Chase, !3
    IniRead, Bind_Deject, %ConfigFile%, %section%, Bind_Deject, !4
    IniRead, Bind_Cuff, %ConfigFile%, %section%, Bind_Cuff, !5
    IniRead, Bind_InCar, %ConfigFile%, %section%, Bind_InCar, !6
    IniRead, Bind_StopChase, %ConfigFile%, %section%, Bind_StopChase, !7
    IniRead, Bind_Doc, %ConfigFile%, %section%, Bind_Doc, !8
    IniRead, Bind_Search, %ConfigFile%, %section%, Bind_Search, !9
    IniRead, Bind_SOS, %ConfigFile%, %section%, Bind_SOS, F9
    IniRead, Bind_Dep, %ConfigFile%, %section%, Bind_Dep,
    IniRead, Bind_WantedList, %ConfigFile%, %section%, Bind_WantedList,
    IniRead, Bind_SOSStart, %ConfigFile%, %section%, Bind_SOSStart,
    IniRead, Bind_SOSArrive, %ConfigFile%, %section%, Bind_SOSArrive,
    IniRead, Bind_HijackStart, %ConfigFile%, %section%, Bind_HijackStart,
    IniRead, Bind_HijackArrive, %ConfigFile%, %section%, Bind_HijackArrive,
    IniRead, Bind_CallStart, %ConfigFile%, %section%, Bind_CallStart,
    IniRead, Bind_CallArrive, %ConfigFile%, %section%, Bind_CallArrive,
    IniRead, Bind_CallWorkStart, %ConfigFile%, %section%, Bind_CallWorkStart,
    IniRead, Bind_CallWorkEnd, %ConfigFile%, %section%, Bind_CallWorkEnd,
    IniRead, Bind_PatrolStart, %ConfigFile%, %section%, Bind_PatrolStart,
    IniRead, Bind_PatrolCont, %ConfigFile%, %section%, Bind_PatrolCont,
    IniRead, Bind_PatrolEnd, %ConfigFile%, %section%, Bind_PatrolEnd,
    IniRead, Bind_PostStart, %ConfigFile%, %section%, Bind_PostStart,
    IniRead, Bind_PostCont, %ConfigFile%, %section%, Bind_PostCont,
    IniRead, Bind_PostEnd, %ConfigFile%, %section%, Bind_PostEnd,
    IniRead, Bind_ConvoyStart, %ConfigFile%, %section%, Bind_ConvoyStart,
    IniRead, Bind_ConvoyCont, %ConfigFile%, %section%, Bind_ConvoyCont,
    IniRead, Bind_ConvoyEnd, %ConfigFile%, %section%, Bind_ConvoyEnd,
    IniRead, Bind_TowStart, %ConfigFile%, %section%, Bind_TowStart,
    IniRead, Bind_TowEnd, %ConfigFile%, %section%, Bind_TowEnd,
    IniRead, Bind_CarSearch, %ConfigFile%, %section%, Bind_CarSearch,
    IniRead, Bind_Arrest, %ConfigFile%, %section%, Bind_Arrest,
    IniRead, Bind_Fine, %ConfigFile%, %section%, Bind_Fine,
    IniRead, Bind_Protocol, %ConfigFile%, %section%, Bind_Protocol,
    IniRead, Bind_Rights, %ConfigFile%, %section%, Bind_Rights,
    IniRead, Bind_CardDS, %ConfigFile%, %section%, Bind_CardDS,
    IniRead, Bind_CardVK, %ConfigFile%, %section%, Bind_CardVK,
    IniRead, Bind_MDSFormation, %ConfigFile%, %section%, Bind_MDSFormation,
    IniRead, Bind_AutoPatrol, %ConfigFile%, %section%, Bind_AutoPatrol,
    IniRead, Bind_AutoPost, %ConfigFile%, %section%, Bind_AutoPost,
    IniRead, Bind_AssistOOP, %ConfigFile%, %section%, Bind_AssistOOP,
    IniRead, Bind_AssistStun, %ConfigFile%, %section%, Bind_AssistStun,
    IniRead, Bind_AssistChase, %ConfigFile%, %section%, Bind_AssistChase,
    IniRead, Bind_AssistHouse, %ConfigFile%, %section%, Bind_AssistHouse,
    IniRead, Bind_AssistDrugs, %ConfigFile%, %section%, Bind_AssistDrugs,
    IniRead, Bind_AssistPDPCuff, %ConfigFile%, %section%, Bind_AssistPDPCuff,
    IniRead, Bind_OpenBindsTab, %ConfigFile%, %section%, Bind_OpenBindsTab,
    IniRead, Bind_MaskCall, %ConfigFile%, %section%, Bind_MaskCall,
    IniRead, Bind_RecordCheck, %ConfigFile%, %section%, Bind_RecordCheck,
    IniRead, Bind_TrainCrash, %ConfigFile%, %section%, Bind_TrainCrash,
    IniRead, Bind_PersonalFile, %ConfigFile%, %section%, Bind_PersonalFile,
    IniRead, Bind_Su, %ConfigFile%, %section%, Bind_Su,
    BindListItems := IniReadText(ConfigFile, section, "BindListItems", GetDefaultBindListItems())
    NormalizeBindListItemsValue(BindListItems)
IniRead, Trig_Intro, %ConfigFile%, %section%, Trig_Intro,
    IniRead, Trig_SOS, %ConfigFile%, %section%, Trig_SOS,
    IniRead, Trig_EnterID, %ConfigFile%, %section%, Trig_EnterID,
    IniRead, Trig_ResetID, %ConfigFile%, %section%, Trig_ResetID,
    IniRead, Trig_Chase, %ConfigFile%, %section%, Trig_Chase,
    IniRead, Trig_Deject, %ConfigFile%, %section%, Trig_Deject,
    IniRead, Trig_Cuff, %ConfigFile%, %section%, Trig_Cuff,
    IniRead, Trig_InCar, %ConfigFile%, %section%, Trig_InCar,
    IniRead, Trig_StopChase, %ConfigFile%, %section%, Trig_StopChase,
    IniRead, Trig_Doc, %ConfigFile%, %section%, Trig_Doc,
    IniRead, Trig_Search, %ConfigFile%, %section%, Trig_Search,
    IniRead, Trig_Dep, %ConfigFile%, %section%, Trig_Dep, !деп
    IniRead, Trig_WantedList, %ConfigFile%, %section%, Trig_WantedList, !р
    IniRead, Trig_SOSStart, %ConfigFile%, %section%, Trig_SOSStart, !сос
    IniRead, Trig_SOSArrive, %ConfigFile%, %section%, Trig_SOSArrive, !сос1
    IniRead, Trig_HijackStart, %ConfigFile%, %section%, Trig_HijackStart, !угон
    IniRead, Trig_HijackArrive, %ConfigFile%, %section%, Trig_HijackArrive, !угон1
    IniRead, Trig_CallStart, %ConfigFile%, %section%, Trig_CallStart, !выз
    IniRead, Trig_CallArrive, %ConfigFile%, %section%, Trig_CallArrive, !выз1
    IniRead, Trig_CallWorkStart, %ConfigFile%, %section%, Trig_CallWorkStart,
    IniRead, Trig_CallWorkEnd, %ConfigFile%, %section%, Trig_CallWorkEnd,
    IniRead, Trig_PatrolStart, %ConfigFile%, %section%, Trig_PatrolStart, !патруль
    IniRead, Trig_PatrolCont, %ConfigFile%, %section%, Trig_PatrolCont, !патруль1
    IniRead, Trig_PatrolEnd, %ConfigFile%, %section%, Trig_PatrolEnd, !патруль2
    IniRead, Trig_PostStart, %ConfigFile%, %section%, Trig_PostStart, !пост
    IniRead, Trig_PostCont, %ConfigFile%, %section%, Trig_PostCont, !пост1
    IniRead, Trig_PostEnd, %ConfigFile%, %section%, Trig_PostEnd, !пост2
    IniRead, Trig_ConvoyStart, %ConfigFile%, %section%, Trig_ConvoyStart, !вк
    IniRead, Trig_ConvoyCont, %ConfigFile%, %section%, Trig_ConvoyCont,
    IniRead, Trig_ConvoyEnd, %ConfigFile%, %section%, Trig_ConvoyEnd, !вк1
    IniRead, Trig_TowStart, %ConfigFile%, %section%, Trig_TowStart, !эв
    IniRead, Trig_TowEnd, %ConfigFile%, %section%, Trig_TowEnd, !эв1
    IniRead, Trig_CarSearch, %ConfigFile%, %section%, Trig_CarSearch, !обтс
    IniRead, Trig_Arrest, %ConfigFile%, %section%, Trig_Arrest, !ар
    IniRead, Trig_Fine, %ConfigFile%, %section%, Trig_Fine, !ш
    IniRead, Trig_Protocol, %ConfigFile%, %section%, Trig_Protocol, !протокол
    IniRead, Trig_Rights, %ConfigFile%, %section%, Trig_Rights, !права
    IniRead, Trig_CardDS, %ConfigFile%, %section%, Trig_CardDS, !визиткадс
    IniRead, Trig_CardVK, %ConfigFile%, %section%, Trig_CardVK, !визиткавк
    IniRead, Trig_MDSFormation, %ConfigFile%, %section%, Trig_MDSFormation, !строй
    IniRead, Trig_AutoPatrol, %ConfigFile%, %section%, Trig_AutoPatrol, !апатруль
    IniRead, Trig_AutoPost, %ConfigFile%, %section%, Trig_AutoPost, !апост
    IniRead, Trig_AssistOOP, %ConfigFile%, %section%, Trig_AssistOOP, !ооп
    IniRead, Trig_AssistStun, %ConfigFile%, %section%, Trig_AssistStun, !оглуш
    IniRead, Trig_AssistChase, %ConfigFile%, %section%, Trig_AssistChase, !погоня
    IniRead, Trig_AssistHouse, %ConfigFile%, %section%, Trig_AssistHouse, !домgps
    IniRead, Trig_AssistDrugs, %ConfigFile%, %section%, Trig_AssistDrugs, !наркоид
    IniRead, Trig_AssistPDPCuff, %ConfigFile%, %section%, Trig_AssistPDPCuff, !пдпнаруч
    IniRead, Trig_OpenBindsTab, %ConfigFile%, %section%, Trig_OpenBindsTab, !бинды
    IniRead, Trig_MaskCall, %ConfigFile%, %section%, Trig_MaskCall, !м
    IniRead, Trig_RecordCheck, %ConfigFile%, %section%, Trig_RecordCheck, !упр
    IniRead, Trig_TrainCrash, %ConfigFile%, %section%, Trig_TrainCrash, !поезд
    IniRead, Trig_PersonalFile, %ConfigFile%, %section%, Trig_PersonalFile, !лд
    IniRead, Trig_Su, %ConfigFile%, %section%, Trig_Su, !су
    IniRead, Trig_GpsD, %ConfigFile%, %section%, Trig_GpsD, !д
    IniRead, Trig_GpsOS, %ConfigFile%, %section%, Trig_GpsOS, !ос
    IniRead, Trig_VU, %ConfigFile%, %section%, Trig_VU, !вузакон
    IniRead, Trig_FP, %ConfigFile%, %section%, Trig_FP, !фп
    IniRead, Trig_KON, %ConfigFile%, %section%, Trig_KON, !кон
    IniRead, Trig_FZOP, %ConfigFile%, %section%, Trig_FZOP, !фзоп
    IniRead, Trig_TER, %ConfigFile%, %section%, Trig_TER, !тер
    IniRead, Trig_TK, %ConfigFile%, %section%, Trig_TK, !тк
    IniRead, Trig_ARG, %ConfigFile%, %section%, Trig_ARG, !арг
    IniRead, Trig_UK, %ConfigFile%, %section%, Trig_UK, !ук
    IniRead, Trig_VV, %ConfigFile%, %section%, Trig_VV, !вв
    IniRead, Trig_KOAP, %ConfigFile%, %section%, Trig_KOAP, !коап
    IniRead, Trig_PDD, %ConfigFile%, %section%, Trig_PDD, !пдд
    IniRead, Trig_ORUZH, %ConfigFile%, %section%, Trig_ORUZH, !оруж
    IniRead, Trig_UPK, %ConfigFile%, %section%, Trig_UPK, !упк
    IniRead, Trig_KAS, %ConfigFile%, %section%, Trig_KAS, !кас
    IniRead, Trig_FSB, %ConfigFile%, %section%, Trig_FSB, !фсб
    IniRead, Trig_FSIN, %ConfigFile%, %section%, Trig_FSIN, !фсин
    IniRead, Trig_VS, %ConfigFile%, %section%, Trig_VS, !фзовс
    IniRead, Trig_SUD, %ConfigFile%, %section%, Trig_SUD, !суд
    IniRead, Trig_ORD, %ConfigFile%, %section%, Trig_ORD, !орд
    IniRead, Trig_GT, %ConfigFile%, %section%, Trig_GT, !гостайна

    NormalizeBindListItemsValue(BindListItems)

    NormalizeCatalogTriggerGlobals()
    NormalizeCatalogHotkeyGlobals()

    FinalizeLoadedProfileState(profileName)
}

WriteProfileIdentityToIni(fileName, sectionName) {
    global IntroRole, Rank, ReportRank, Surname, PersonalBadge
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount

    CheckedIniWrite(IntroRole, fileName, sectionName, "IntroRole")
    CheckedIniWrite(Rank, fileName, sectionName, "Rank")
    CheckedIniWrite(ReportRank, fileName, sectionName, "ReportRank")
    CheckedIniWrite(Surname, fileName, sectionName, "Surname")
    CheckedIniWrite(PersonalBadge, fileName, sectionName, "PersonalBadge")

    CheckedIniWrite(PatrolRoute, fileName, sectionName, "PatrolRoute")
    CheckedIniWrite(PostRoute, fileName, sectionName, "PostRoute")
    CheckedIniWrite(ConvoyRoute, fileName, sectionName, "ConvoyRoute")
    CheckedIniWrite(PatrolUnit, fileName, sectionName, "PatrolUnit")
    CheckedIniWrite(PatrolCrewCount, fileName, sectionName, "PatrolCrewCount")
    CheckedIniWrite(PostUnit, fileName, sectionName, "PostUnit")
    CheckedIniWrite(PostCrewCount, fileName, sectionName, "PostCrewCount")
    return !ConfigWriteFailed
}

WriteProfileTemplateTextsToIni(fileName, sectionName) {
    global T_Intro, T_Dep, T_SOSStart, T_SOSArrive
    global T_HijackStart, T_HijackArrive
    global T_CallStart, T_CallArrive, T_CallWorkStart, T_CallWorkEnd
    global T_PatrolStart, T_PatrolContinue, T_PatrolEnd
    global T_PostStart, T_PostContinue, T_PostEnd
    global T_ConvoyStart, T_ConvoyCont, T_ConvoyEnd

    IniWriteText(T_Intro, fileName, sectionName, "T_Intro")
    IniWriteText(T_Dep, fileName, sectionName, "T_Dep")
    IniWriteText(T_SOSStart, fileName, sectionName, "T_SOSStart")
    IniWriteText(T_SOSArrive, fileName, sectionName, "T_SOSArrive")
    IniWriteText(T_HijackStart, fileName, sectionName, "T_HijackStart")
    IniWriteText(T_HijackArrive, fileName, sectionName, "T_HijackArrive")
    IniWriteText(T_CallStart, fileName, sectionName, "T_CallStart")
    IniWriteText(T_CallArrive, fileName, sectionName, "T_CallArrive")
    IniWriteText(T_CallWorkStart, fileName, sectionName, "T_CallWorkStart")
    IniWriteText(T_CallWorkEnd, fileName, sectionName, "T_CallWorkEnd")
    IniWriteText(T_PatrolStart, fileName, sectionName, "T_PatrolStart")
    IniWriteText(T_PatrolContinue, fileName, sectionName, "T_PatrolContinue")
    IniWriteText(T_PatrolEnd, fileName, sectionName, "T_PatrolEnd")
    IniWriteText(T_PostStart, fileName, sectionName, "T_PostStart")
    IniWriteText(T_PostContinue, fileName, sectionName, "T_PostContinue")
    IniWriteText(T_PostEnd, fileName, sectionName, "T_PostEnd")
    IniWriteText(T_ConvoyStart, fileName, sectionName, "T_ConvoyStart")
    IniWriteText(T_ConvoyCont, fileName, sectionName, "T_ConvoyCont")
    IniWriteText(T_ConvoyEnd, fileName, sectionName, "T_ConvoyEnd")
    return !ConfigWriteFailed
}

WriteProfileRpTextsToIni(fileName, sectionName) {
    global RP_StopChase, RP_Deject, RP_InCar, RP_Doc, RP_Search, RP_TowStart, RP_TowEnd, RP_CarSearch, RP_Arrest, RP_Fine, RP_Protocol, RP_Rights, RP_CardDS, RP_CardVK
    global MDS_FormationInitial, MDS_FormationCountdown, MDS_FormationFinish

    IniWriteText(RP_StopChase, fileName, sectionName, "RP_StopChase")
    IniWriteText(RP_Deject, fileName, sectionName, "RP_Deject")
    IniWriteText(RP_InCar, fileName, sectionName, "RP_InCar")
    IniWriteText(RP_Doc, fileName, sectionName, "RP_Doc")
    IniWriteText(RP_Search, fileName, sectionName, "RP_Search")
    IniWriteText(RP_TowStart, fileName, sectionName, "RP_TowStart")
    IniWriteText(RP_TowEnd, fileName, sectionName, "RP_TowEnd")
    IniWriteText(RP_CarSearch, fileName, sectionName, "RP_CarSearch")
    IniWriteText(RP_Arrest, fileName, sectionName, "RP_Arrest")
    IniWriteText(RP_Fine, fileName, sectionName, "RP_Fine")
    IniWriteText(RP_Protocol, fileName, sectionName, "RP_Protocol")
    IniWriteText(RP_Rights, fileName, sectionName, "RP_Rights")
    IniWriteText(RP_CardDS, fileName, sectionName, "RP_CardDS")
    IniWriteText(RP_CardVK, fileName, sectionName, "RP_CardVK")
    IniWriteText(MDS_FormationInitial, fileName, sectionName, "MDS_FormationInitial")
    IniWriteText(MDS_FormationCountdown, fileName, sectionName, "MDS_FormationCountdown")
    IniWriteText(MDS_FormationFinish, fileName, sectionName, "MDS_FormationFinish")
    return !ConfigWriteFailed
}

SaveProfile(profileName) {
    global ConfigFile, CurrentProfile
    NormalizeProfileNameValue(profileName)
    if !EnsureConfigFilePath("SaveProfile", 1)
        return false
    global IntroRole, Rank, ReportRank, Surname
    global PatrolRoute, PostRoute, ConvoyRoute, PatrolUnit, PatrolCrewCount, PostUnit, PostCrewCount
    global T_Intro, T_Dep, T_SOSStart, T_SOSArrive
    global T_HijackStart, T_HijackArrive
    global T_CallStart, T_CallArrive, T_CallWorkStart, T_CallWorkEnd
    global T_PatrolStart, T_PatrolContinue, T_PatrolEnd
    global T_PostStart, T_PostContinue, T_PostEnd
    global T_ConvoyStart, T_ConvoyCont, T_ConvoyEnd
    global RP_StopChase, RP_Deject, RP_InCar, RP_Doc, RP_Search, RP_TowStart, RP_TowEnd, RP_CarSearch, RP_Arrest, RP_Fine, RP_Protocol, RP_Rights, RP_CardDS, RP_CardVK
    global MDS_FormationInitial, MDS_FormationCountdown, MDS_FormationFinish
    global BindListItems
    global Trig_Intro, Trig_SOS, Trig_EnterID, Trig_ResetID, Trig_Chase, Trig_Deject, Trig_Cuff, Trig_InCar, Trig_StopChase, Trig_Doc, Trig_Search, Trig_Dep, Trig_SOSStart, Trig_SOSArrive, Trig_HijackStart, Trig_HijackArrive, Trig_CallStart, Trig_CallArrive, Trig_CallWorkStart, Trig_CallWorkEnd, Trig_PatrolStart, Trig_PatrolCont, Trig_PatrolEnd, Trig_PostStart, Trig_PostCont, Trig_PostEnd, Trig_ConvoyStart, Trig_ConvoyCont, Trig_ConvoyEnd, Trig_TowStart, Trig_TowEnd, Trig_CarSearch, Trig_Arrest, Trig_Fine, Trig_Protocol, Trig_Rights, Trig_CardDS, Trig_CardVK, Trig_MDSFormation, Trig_VU, Trig_FP, Trig_KON, Trig_FZOP, Trig_TER, Trig_TK, Trig_ARG, Trig_UK, Trig_VV, Trig_KOAP, Trig_PDD, Trig_ORUZH, Trig_UPK, Trig_KAS, Trig_FSB, Trig_FSIN, Trig_VS, Trig_SUD, Trig_ORD, Trig_GT

    global Bind_OpenSettings, Bind_ToggleBindList, Bind_ToggleLastLawDoc, Bind_HideLawGui, Bind_ToggleHUD, Bind_IDOverlay, Bind_ConfirmID, Bind_RejectID, Bind_ResetID
    global Bind_EnterID, Bind_Intro, Bind_Chase, Bind_Deject, Bind_Cuff, Bind_InCar, Bind_StopChase, Bind_Doc, Bind_Search, Bind_SOS
    global Bind_Dep, Bind_SOSStart, Bind_SOSArrive, Bind_HijackStart, Bind_HijackArrive, Bind_CallStart, Bind_CallArrive, Bind_CallWorkStart, Bind_CallWorkEnd
    global Bind_PatrolStart, Bind_PatrolCont, Bind_PatrolEnd
    global Bind_PostStart, Bind_PostCont, Bind_PostEnd
    global Bind_ConvoyStart, Bind_ConvoyCont, Bind_ConvoyEnd
    global Bind_TowStart, Bind_TowEnd, Bind_CarSearch, Bind_Arrest, Bind_Fine, Bind_Protocol, Bind_Rights, Bind_CardDS, Bind_CardVK, Bind_MDSFormation

    if (profileName = "")
        profileName := "Основной"

    if (ProfileSaveBackups = "On" && FileExist(ConfigFile) && CreateConfigBackup("save") = "")
        return false
    target := ConfigStage(ConfigFile)
    if (target = "")
        return false
    section := "Profile_" . profileName

    WriteProfileIdentityToIni(target, section)

    WriteProfileTemplateTextsToIni(target, section)

    WriteProfileRpTextsToIni(target, section)

    WriteProfileV9FieldsToIni(target, section)

    WriteContextAssistantProfileToIni(target, section)

    WriteCatalogHotkeysToIni(target, section)
    NormalizeBindListItemsValue(BindListItems)
    IniWriteText(BindListItems, target, section, "BindListItems")
    WriteCatalogTriggersToIni(target, section)

    ConfigAddProfile(target, profileName)
    CheckedIniWrite(profileName, target, "Profiles", "Last")
    if !ConfigCommit(target, ConfigFile)
        return false
    CurrentProfile := profileName
    UpdateHUD()
    return true
}

DeleteProfile(profileName) {
    global ConfigFile
    NormalizeProfileNameValue(profileName)
    if !EnsureConfigFilePath("DeleteProfile", 1)
        return false
    if (profileName = "")
        return false

    names := GetProfilesString()
    count := 0
    Loop, Parse, names, |
        if (A_LoopField != "")
            count++

    if (count <= 1)
    {
        MsgBox, 48, Ошибка, Нельзя удалить единственный профиль.
        return false
    }

    target := ConfigStage(ConfigFile)
    if (target = "")
        return false
    section := "Profile_" . profileName
    IniDelete, %target%, %section%
    if (ErrorLevel)
        ConfigWriteFailed := 1
    newNames := ""
    Loop, Parse, names, |
        if (A_LoopField != "" && A_LoopField != profileName)
            newNames .= (newNames = "" ? "" : "|") . A_LoopField
    CheckedIniWrite(newNames, target, "Profiles", "Names")
    IniRead, lastProfile, %ConfigFile%, Profiles, Last, Основной
    newProfile := lastProfile
    if (lastProfile = profileName) {
        newProfile := StrSplit(newNames, "|")[1]
        CheckedIniWrite(newProfile, target, "Profiles", "Last")
    }
    if !ConfigCommit(target, ConfigFile)
        return false
    if (lastProfile = profileName)
        LoadProfile(newProfile)
    return true
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

CloseAllDocs() {
    global
    TerritoryMap_CloseAll()
    Gui, 1:Destroy
    ServiceCodesGuiVisible := 0
    LawDoc_ResetAllFlags()
}

LawDoc_PageCount(prefix) {
    if IsFunc("LawCorpus_PageCount")
    {
        fn := Func("LawCorpus_PageCount")
        corpusCount := fn.Call(prefix)
        if (corpusCount > 0)
            return corpusCount
    }
    if (prefix = "vu")
        return 3
    else if (prefix = "fp")
        return 4
    else if (prefix = "kon")
        return 4
    else if (prefix = "fzop")
        return 12
    else if (prefix = "ter")
        return 7
    else if (prefix = "tk")
        return 6
    else if (prefix = "arg")
        return 4
    else if (prefix = "uk")
        return 9
    else if (prefix = "vv")
        return 5
    else if (prefix = "koap")
        return 8
    else if (prefix = "pdd")
        return 10
    else if (prefix = "oruzh")
        return 3
    else if (prefix = "upk")
        return 41
    else if (prefix = "kas")
        return 4
    else if (prefix = "fsb")
        return 3
    else if (prefix = "fsin")
        return 2
    else if (prefix = "vs")
        return 2
    else if (prefix = "sud")
        return 2
    else if (prefix = "ord")
        return 2
    else if (prefix = "gt")
        return 2
    return 0
}

LawDoc_ResetAllFlags() {
    global
    LawDocCurrentPages := {}
    docPrefixes := ["vu", "fp", "kon", "fzop", "ter", "tk", "arg", "uk", "vv", "koap", "pdd", "oruzh", "upk", "kas", "fsb", "fsin", "vs", "sud", "ord", "gt"]
    Loop % docPrefixes.Length()
    {
        docPrefix := docPrefixes[A_Index]
        ; Navigation uses LawDocCurrentPages; only the legacy first-page flag exists.
        ; Resetting a window must not load and paginate every corpus document.
        flagName := "fl" . docPrefix . "1"
        %flagName% := False
    }
}

LawDoc_Navigate(prefix, direction) {
    global LawDocCurrentPages
    count := LawDoc_PageCount(prefix)
    if (count < 1)
        return

    currentIdx := IsFunc("LawDoc_GetCurrentPage") ? LawDoc_GetCurrentPage(prefix) : 1

    if (direction = "prev")
        nextIdx := currentIdx - 1
    else
        nextIdx := currentIdx + 1

    if (nextIdx < 1)
        nextIdx := count
    if (nextIdx > count)
        nextIdx := 1

    if IsFunc("LawDoc_ShowPage")
    {
        if !LawDoc_ShowPage(prefix, nextIdx)
            return false
        ApplyPersistentAlwaysOnTop()
        return true
    }
    return false
}

NavigateVU(direction) {
    LawDoc_Navigate("vu", direction)
}

NavigateFP(direction) {
    LawDoc_Navigate("fp", direction)
}

NavigateKON(direction) {
    LawDoc_Navigate("kon", direction)
}

NavigateFZOP(direction) {
    LawDoc_Navigate("fzop", direction)
}

NavigateTER(direction) {
    LawDoc_Navigate("ter", direction)
}

NavigateTK(direction) {
    LawDoc_Navigate("tk", direction)
}

NavigateARG(direction) {
    LawDoc_Navigate("arg", direction)
}

NavigateUK(direction) {
    LawDoc_Navigate("uk", direction)
}

NavigateVV(direction) {
    LawDoc_Navigate("vv", direction)
}

NavigateKOAP(direction) {
    LawDoc_Navigate("koap", direction)
}

NavigatePDD(direction) {
    LawDoc_Navigate("pdd", direction)
}

NavigateUPK(direction) {
    LawDoc_Navigate("upk", direction)
}

NavigateORUZH(direction) {
    LawDoc_Navigate("oruzh", direction)
}

NavigateKAS(direction) {
    LawDoc_Navigate("kas", direction)
}

NavigateFSB(direction) {
    LawDoc_Navigate("fsb", direction)
}

NavigateFSIN(direction) {
    LawDoc_Navigate("fsin", direction)
}

NavigateVS(direction) {
    LawDoc_Navigate("vs", direction)
}

NavigateSUD(direction) {
    LawDoc_Navigate("sud", direction)
}

NavigateORD(direction) {
    LawDoc_Navigate("ord", direction)
}

NavigateGT(direction) {
    LawDoc_Navigate("gt", direction)
}

LawUiPreviewOpenTimer:
ToggleLawDoc(5, "flter1", "ter1")
TerritoryMap_ShowCatalog()
return

UpdateHUDTimer:
UpdateHUD()
return

TaskSchedulerTimerTick:
TaskScheduler_Tick()
return

ChatQueueTimerTick:
ChatQueue_Tick()
return

ChatLogReaderTick:
ChatLogReader_Tick()
return

EvidenceScreenshotTimer:
Evidence_ProcessScreenshotQueue()
return

AutoTargetIDTick:
AutoTargetID_Poll()
if (AutoTargetRButtonLatched)
    SetTimer, AutoTargetIDTick, Off
return

RunMemoryLiveTestCliLabel:
RunMemoryLiveTest(0)
return

MemoryLiveTestExitLabel:
ExitApp
return

ClearMockPreviewLabel:
ChatQueuePreviewText := ""
GuiControl, 41:, MockPreviewEdit,
GuiControl, 41:, MockPreviewCountText, Строк: 0
return

CloseMockPreviewLabel:
Gui, 41:Destroy
hMockPreviewWnd := 0
return

RemoveToolTip:
ToolTip
return

LawSearch_WaitForQueryLabel:
LawSearch_WaitForQuery()
return

LawSearch_HideNoticeLabel:
Gui, 17:Destroy
return

ApplyPresetLabel:
SaveGuiToGlobals(1)
ApplyProfileModePreset(CFG_ProfileMode)
BuildSettingsGui()
ShowSettingsWindow()
RefreshSettingsTabs()
return

ResetStyleLabel:
ResetStyleDefaults()
SaveUISettings()
RebuildFloatingGUI()
BuildSettingsGui()
ShowSettingsWindow()
RefreshSettingsTabs()
return

ImportProfilesLabel:
if !SettingsActionAllowed("import", 1000)
    return
Gui, 2:+OwnDialogs
importResult := ImportProfilesPack()
if (importResult = 1)
    SetSettingsStatus("Профили импортированы и загружены.")
else if (importResult = -1)
    SetSettingsStatus("Импорт отменён.")
else
    SetSettingsStatus("Импорт не выполнен. Проверьте выбранный файл.")
return

ExportProfilesLabel:
if !SettingsActionAllowed("export", 1000)
    return
Gui, 2:+OwnDialogs
exportResult := ExportProfilesPack()
if (exportResult = 1)
    SetSettingsStatus("Профили экспортированы.")
else if (exportResult = -1)
    SetSettingsStatus("Экспорт отменён.")
else
    SetSettingsStatus("Экспорт не выполнен.")
return

SaveThemePresetLabel:
if !SettingsActionAllowed("save_theme")
    return
Gui, 2:+OwnDialogs
Gui, 2:Submit, NoHide
themeName := CFG_ThemeMode
NormalizeProfileNameValue(themeName)
if (themeName = "" || IsBuiltInThemeName(themeName))
{
    LogError("SaveThemePresetLabel", "Preset save blocked. Invalid name: " . CFG_ThemeMode)
    MsgBox, 48, Ошибка, Введите новое имя пресета в поле "Тема", затем снова нажмите сохранение.
    SetSettingsStatus("Для нового пресета введите собственное имя темы.")
    return
}
SaveGuiToGlobals(1)
if SaveThemePreset(themeName)
{
    SaveUISettings()
    BuildSettingsGui()
    ShowSettingsWindow()
    RefreshSettingsTabs()
    SetSettingsStatus("Пресет темы сохранён: " . themeName)
    Notify("info")
}
return

LoadThemePresetLabel:
if !SettingsActionAllowed("load_theme")
    return
Gui, 2:+OwnDialogs
Gui, 2:Submit, NoHide
themeName := CFG_ThemeMode
NormalizeProfileNameValue(themeName)
if (themeName = "")
{
    LogError("LoadThemePresetLabel", "Empty preset/theme name.")
    MsgBox, 48, Ошибка, Выберите встроенную тему или сохранённый пресет в поле "Тема".
    return
}
if IsBuiltInThemeName(themeName)
{
    CFG_ThemePresetName := ""
    CFG_ThemeMode := themeName
    ApplyGuiSettingsAuto(0, 1)
    SetSettingsStatus("Применена встроенная тема: " . themeName)
    Notify("info")
    return
}
if !ThemePresetExists(themeName)
{
    LogError("LoadThemePresetLabel", "Preset not found: " . themeName)
    MsgBox, 48, Ошибка, Указанный пресет темы не найден. Сначала сохраните его или выберите существующий.
    return
}
if !LoadThemePreset(themeName)
{
    LogError("LoadThemePresetLabel", "Load failed: " . themeName)
    MsgBox, 48, Ошибка, Не удалось применить выбранный стиль.
    return
}
SaveUISettings()
RebuildFloatingGUI()
BuildSettingsGui()
ShowSettingsWindow()
RefreshSettingsTabs()
ApplyPersistentAlwaysOnTop()
SetSettingsStatus("Применён пресет темы: " . themeName)
Notify("info")
return

ImportThemeLabel:
ImportThemeFromExternalFile()
return

ExportThemeLabel:
ExportThemeToFile()
return

CfgLoadProfile:
if !SettingsActionAllowed("load_profile")
    return
Gui, 2:+OwnDialogs
Gui, 2:Submit, NoHide
targetProfile := CFG_ProfileName
NormalizeProfileNameValue(targetProfile)
if (targetProfile = "")
{
    MsgBox, 48, Ошибка, Введи или выбери имя профиля.
    SetSettingsStatus("Профиль не выбран.")
    return
}
if !ProfileExists(targetProfile)
{
    MsgBox, 48, Ошибка, Такого профиля нет.
    SetSettingsStatus("Профиль не найден: " . targetProfile)
    return
}
currentPage := SettingsPage
SaveGuiToGlobals(1)
if !SaveProfile(CurrentProfile)
    return
LoadProfile(targetProfile)
OpenSettings(currentPage)
SetSettingsStatus("Загружен профиль: " . CurrentProfile)
Notify("info")
return

CfgCreateProfile:
if !SettingsActionAllowed("create_profile")
    return
Gui, 2:+OwnDialogs
Gui, 2:Submit, NoHide
newProfile := CFG_ProfileName
NormalizeProfileNameValue(newProfile)
if (newProfile = "")
{
    MsgBox, 48, Ошибка, Введи имя нового профиля в поле сверху.
    SetSettingsStatus("Не указано имя нового профиля.")
    return
}
if ProfileExists(newProfile)
{
    MsgBox, 48, Ошибка, Профиль с таким именем уже существует. Используй «Сохранить».
    SetSettingsStatus("Профиль уже существует: " . newProfile)
    return
}
currentPage := SettingsPage
SaveGuiToGlobals(1)
if !SaveProfile(newProfile)
    return
OpenSettings(currentPage)
SetSettingsStatus("Создан профиль: " . CurrentProfile)
Notify("info")
return

CfgSaveProfile:
if !SettingsActionAllowed("save_profile")
    return
Gui, 2:+OwnDialogs
currentPage := SettingsPage
SaveGuiToGlobals()
if !SaveProfile(CurrentProfile)
    return
OpenSettings(currentPage)
SetSettingsStatus("Профиль сохранён: " . CurrentProfile)
Notify("info")
return

PreviewNotifySoundLabel:
SaveGuiToGlobals(1)
PlayNotifySound("info")
return

PreviewStopTimerSoundLabel:
SaveGuiToGlobals(1)
PlayStopTimerSound()
return

SaveCustomizationOnlyLabel:
ApplyGuiSettingsAuto(0, 1)
Notify("info")
return

CfgDeleteProfile:
Gui, 2:Submit, NoHide
NormalizeProfileNameValue(CFG_ProfileName)
if (CFG_ProfileName = "")
{
    MsgBox, 48, Ошибка, Выбери профиль для удаления.
    return
}
MsgBox, 36, Подтверждение, Удалить профиль "%CFG_ProfileName%"?
IfMsgBox, No
    return
if (DeleteProfile(CFG_ProfileName))
{
    OpenSettings(1)
    Notify("info")
}
return

CfgHotkeyChanged:
Gui, 2:Submit, NoHide
ResolveCfgHotkeyConflicts(A_GuiControl, 1)
return

ThemePresetChanged:
Gui, 2:Submit, NoHide
themeCandidate := CFG_ThemeMode
NormalizeProfileNameValue(themeCandidate)
if (themeCandidate = "")
    return
if IsBuiltInThemeName(themeCandidate)
{
    CFG_ThemePresetName := ""
    CFG_ThemeMode := themeCandidate
    ApplyGuiSettingsAuto(0, 1)
    SetSettingsStatus("Применена тема: " . themeCandidate)
    return
}
if !ThemePresetExists(themeCandidate)
    return
if !LoadThemePreset(themeCandidate)
{
    LogError("ThemePresetChanged", "Failed to load preset: " . themeCandidate)
    MsgBox, 48, Ошибка, Не удалось загрузить выбранный пресет темы.
    return
}
SaveUISettings()
RebuildFloatingGUI()
BuildSettingsGui()
ShowSettingsWindow()
RefreshSettingsTabs()
ApplyPersistentAlwaysOnTop()
SetSettingsStatus("Применён пресет темы: " . themeCandidate)
Notify("info")
return

ActionTimerTick:
ActionTimer_Render()
return

StartActionTimerDrag:
global hActionTimerWnd
PostMessage, 0xA1, 2,,, ahk_id %hActionTimerWnd%
return

ActionTimersGuiClose:
ActionTimersGuiEscape:
ActionTimer_Clear()
return

StopTimerTick:
global StopTimerCounter, hStopTimerWnd, StopTimerActive, StopTimerCustomSound, HUDTransparency
StopTimerCounter -= 1
if (StopTimerCounter > 0)
{
    if (hStopTimerWnd)
        GuiControl, 15:, StopTimerCount, %StopTimerCounter%
}
else
{
    HideStopTimerGUI()
    PlayStopTimerSound()
}
return

StartStopTimerDrag:
global hStopTimerWnd
PostMessage, 0xA1, 2,,, ahk_id %hStopTimerWnd%
return

15GuiClose:
15GuiEscape:
HideStopTimerGUI()
return

OpenCustomFunctionBuilderLabel:
OpenCustomFunctionBuilder()
return

TrayOpenCustomFunctionsLabel:
OpenCustomFunctionBuilder()
return

CustomFunctionListChanged:
oldCustomFunctionIndex := CustomFunctionSelected
Gui, 40:Submit, NoHide
if (A_GuiEvent = "Normal" || A_GuiEvent = "DoubleClick")
{
    if (oldCustomFunctionIndex > 0 && oldCustomFunctionIndex != CFB_List)
        CustomFunctionBuilder_StoreFields(oldCustomFunctionIndex)
    CustomFunctionBuilder_LoadSelection(CFB_List)
}
return

CustomFunctionNewLabel:
global CustomFunctions, CustomFunctionMaxCount
if (CustomFunctions.Length() >= CustomFunctionMaxCount)
{
    GuiControl, 40:, CFB_Status, Максимум пользовательских функций: %CustomFunctionMaxCount%.
    return
}
CustomFunctions.Push({Name: "Новая функция " . (CustomFunctions.Length() + 1), Hotkey: "", Trigger: "", Script: "SEND "})
CustomFunctionBuilder_RefreshList(CustomFunctions.Length())
return

CustomFunctionDeleteLabel:
global CustomFunctions, CustomFunctionSelected
if (CustomFunctions.Length() <= 1)
{
    GuiControl, 40:, CFB_Status, Должна остаться хотя бы одна функция.
    return
}
MsgBox, 36, Удаление функции, Удалить выбранную пользовательскую функцию?
IfMsgBox, No
    return
deletedFunction := CustomFunctions.RemoveAt(CustomFunctionSelected)
if !SaveCustomFunctions() {
    CustomFunctions.InsertAt(CustomFunctionSelected, deletedFunction)
    GuiControl, 40:, CFB_Status, Удаление не сохранено; функция восстановлена.
    return
}
ApplyAllBinds()
CustomFunctionBuilder_RefreshList(CustomFunctionSelected > CustomFunctions.Length() ? CustomFunctions.Length() : CustomFunctionSelected)
return

CustomFunctionSaveLabel:
CustomFunctionBuilder_SaveCurrent(1)
return

CustomFunctionRunLabel:
if CustomFunctionBuilder_SaveCurrent(1)
    RunCustomFunction(CustomFunctionSelected)
return

CustomFunctionStopLabel:
StopCustomFunctionRun(1)
return

CustomFunctionCloseLabel:
if CustomFunctionBuilder_SaveCurrent(1)
    CloseCustomFunctionBuilder(0)
return

CustomFunctionAddSendLabel:
CustomFunctionBuilder_AppendStep("SEND /me текст действия")
return

CustomFunctionAddWaitLabel:
CustomFunctionBuilder_AppendStep("WAIT 1000")
return

CustomFunctionAddTimerLabel:
CustomFunctionBuilder_AppendStep("TIMER 15|Название таймера")
return

CustomFunctionAddNoticeLabel:
CustomFunctionBuilder_AppendStep("NOTICE Текст уведомления")
return

CustomFunctionAddTypeLabel:
CustomFunctionBuilder_AppendStep("TYPE текст без отправки")
return

CustomFunctionAddIDLabel:
CustomFunctionBuilder_AppendStep("SEND /command {ID}")
return

CustomFunctionRunnerTick:
CustomFunctionRunner_Process()
return

DispatchCustomFunctionHotkey:
global CustomFunctionHotkeyMap
keyId := NormalizeHotkeyId(A_ThisHotkey)
if (keyId != "" && CustomFunctionHotkeyMap.HasKey(keyId))
    RunCustomFunction(CustomFunctionHotkeyMap[keyId])
return

40GuiClose:
40GuiEscape:
CloseCustomFunctionBuilder(0)
return

HandleAppExit:
IDCapture_Shutdown()
SetTimer, ActionTimerTick, Off
Gui, ActionTimers:Destroy
TerritoryMap_CloseAll()
ReleaseGameHandle()
LogError("System", "Script exit: " . A_ExitReason, "INFO")
ExitApp

SettingsTabsChanged:
Settings_SwitchPage(SettingsTabs)
return

SettingsPageChanged:
Settings_SwitchPage(SettingsPageIndex(SettingsPage))
return

SettingsNavChanged:
if (SettingsNavigationBusy)
    return
if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "K")
    return
Gui, 2:Default
Gui, 2:ListView, SettingsNavLV
selectedPage := LV_GetNext(0, "F")
if (!selectedPage)
    selectedPage := A_EventInfo
pages := GetSettingsPageCatalog()
if (selectedPage < 1 || selectedPage > pages.Length())
    return
Settings_SwitchPage(selectedPage)
return

TestChatConnectionLabel:
Gui, 2:Submit, NoHide
TextSendMode := ChatTyping_ModeFromLabel(CFG_TextSendMode)
GameWindowTitle := CFG_GameWindowTitle
GameProcessName := CFG_GameProcessName
AzmpExpectedSHA256 := CFG_AzmpExpectedSHA256
MockMode := CFG_MockMode
NormalizeTextSendMode(TextSendMode)
NormalizeGameWindowTitle(GameWindowTitle)
NormalizeGameProcessName(GameProcessName)
NormalizeSHA256(AzmpExpectedSHA256)
NormalizeOnOff(MockMode, "Off")
ApplyGameProcessSelector()
connectionSummary := ChatTransport_GetConnectionSummary(1)
GuiControl, 2:, CFG_ChatConnectionStatus, %connectionSummary%
SetSettingsStatus(connectionSummary)
UpdateHUD()
return

RunMemoryLiveTestLabel:
Gui, 2:Submit, NoHide
GameWindowTitle := CFG_GameWindowTitle
GameProcessName := CFG_GameProcessName
AzmpExpectedSHA256 := CFG_AzmpExpectedSHA256
MockMode := CFG_MockMode
NormalizeGameWindowTitle(GameWindowTitle)
NormalizeGameProcessName(GameProcessName)
NormalizeSHA256(AzmpExpectedSHA256)
NormalizeOnOff(MockMode, "Off")
ApplyGameProcessSelector()
if RunMemoryLiveTest(1)
    SetSettingsStatus("Memory live-тест начат: отправлен /time.")
else
    SetSettingsStatus("Memory live-тест не запущен: " . MemoryGetShortError())
return

CheckAzmpLabel:
Gui, 2:Submit, NoHide
GameWindowTitle := CFG_GameWindowTitle
GameProcessName := CFG_GameProcessName
AzmpExpectedSHA256 := CFG_AzmpExpectedSHA256
NormalizeGameWindowTitle(GameWindowTitle)
NormalizeGameProcessName(GameProcessName)
NormalizeSHA256(AzmpExpectedSHA256)
ApplyGameProcessSelector()
azmpInfo := GetAzmpModuleInfo(1)
if (azmpInfo.Ready)
{
    azmpDetails := "Версия: " . azmpInfo.Version . "`nSHA-256: " . azmpInfo.SHA256 . "`nПроверка: " . azmpInfo.Status . "`nПуть: " . azmpInfo.Path
    SetSettingsStatus(GetAzmpCompatibilitySummary(0))
    MsgBox, 64, Проверка azmp.dll, %azmpDetails%
}
else
{
    azmpDetails := "azmp.dll не проверен: " . azmpInfo.Status . "`n" . MemoryGetStatusText()
    SetSettingsStatus(azmpDetails)
    GameInterface_ShowDialog("AHK FOR GOS BY SBEZRUK — azmp.dll", azmpDetails, 0, "OK")
}
return

AutoReportStartLabel:
Gui, 2:Submit, NoHide
if AutoReport_Start(CFG_AutoReportMode, CFG_AutoReportDurationMin, 1)
{
    AutoReportMode := CFG_AutoReportMode
    AutoReportDurationMin := CFG_AutoReportDurationMin + 0
}
return

AutoReportStopLabel:
AutoReport_Stop(1, "manual")
return

CancelAllAutomationLabel:
CancelAllAutomation(1)
UpdateAutomationSettingsStatus()
SetSettingsStatus("Все задачи остановлены, очередь сообщений очищена.")
return

ClearChatQueueLabel:
ChatQueue_Clear(1)
SetSettingsStatus("Очередь сообщений очищена.")
return

OpenMockPreviewLabel:
MockPreview_Show()
SetSettingsStatus("Открыт тестовый чат. Он не отправляет строки в игру.")
return

RunDiagnosticsFromGuiLabel:
if RunBackgroundTool("--diagnostics", "diagnostics_report.txt")
    SetSettingsStatus("Диагностика запущена в отдельном процессе.")
else
    SetSettingsStatus("Диагностика уже выполняется или не запустилась.")
return

RunSelfTestFromGuiLabel:
if RunBackgroundTool("--selftest", "selftest_report.txt")
    SetSettingsStatus("Self-test запущен в отдельном процессе.")
else
    SetSettingsStatus("Self-test уже выполняется или не запустился.")
return

RunMockQueueDemoLabel:
ChatQueue_EnqueueMockDemo()
SetSettingsStatus("В MockMode добавлены три тестовые строки очереди.")
return

BackgroundToolPoll:
global PendingToolPid, PendingToolReport
if (!PendingToolPid)
{
    SetTimer, BackgroundToolPoll, Off
    return
}
Process, Exist, %PendingToolPid%
if (ErrorLevel)
    return
SetTimer, BackgroundToolPoll, Off
childExit := 1
if (PendingToolHandle) {
    DllCall("GetExitCodeProcess", "Ptr", PendingToolHandle, "UInt*", childExit)
    DllCall("CloseHandle", "Ptr", PendingToolHandle)
    PendingToolHandle := 0
}
if FileExist(PendingToolReport)
{
    completedReport := PendingToolReport
    Run, %PendingToolReport%
    SetSettingsStatus((childExit = 0 ? "Проверка завершена: " : "Проверка выявила ошибки (" . childExit . "): ") . completedReport)
}
if !FileExist(PendingToolReport)
    SetSettingsStatus("Проверка не создала новый отчёт; код " . childExit)
PendingToolPid := 0
PendingToolReport := ""
return

41GuiClose:
41GuiEscape:
Gui, 41:Destroy
hMockPreviewWnd := 0
return

ContextAssistantConfirmLabel:
ContextAssistant_Submit("")
return

ContextAssistantTaserLabel:
ContextAssistant_Submit("taser")
return

ContextAssistantBatonLabel:
ContextAssistant_Submit("baton")
return

ContextAssistantCancelLabel:
42GuiClose:
42GuiEscape:
ContextAssistant_Close()
return

ContextAssistantTimeoutLabel:
ContextAssistant_Close()
return

MinimizeSettingsLabel:
CloseSettings()
return

ExitScriptButtonLabel:
Gosub, ExitScriptLabel
return

CloseSettingsLabel:
CloseSettings()
return

TrayAutoIDDiagnosticsLabel:
AutoTargetID_DiagnoseAndRecover(1, 1)
return

TrayOpenSettingsLabel:
OpenSettings(SettingsPage)
return

TrayHideSettingsLabel:
CloseSettings()
return

ExitScriptLabel:
if (AppExitInProgress)
    return
AppExitInProgress := 1
Critical
SetSettingsStatus("Сохранение данных и завершение AHK FOR GOS BY SBEZRUK...")
if (!UiPreviewMode)
{
    if (SettingsVisible)
        SaveGuiToGlobals(1)
    if !SaveProfile(CurrentProfile)
        return
    ActionTimer_Hide(1)
    SaveUISettings()
    SaveHUDWindowState()
    SaveBindListWindowState()
    SaveSettingsWindowState()
}
AutoReport_Stop(0, "exit")
ActionTimer_Clear()
TaskScheduler_CancelAll()
ChatQueue_Clear(0)
TerritoryMap_CloseAll()
SetTimer, UpdateHUDTimer, Off
SetTimer, TaskSchedulerTimerTick, Off
SetTimer, ChatQueueTimerTick, Off
SetTimer, ChatLogReaderTick, Off
SetTimer, EvidenceScreenshotTimer, Off
SetTimer, AutoTargetIDTick, Off
SetTimer, StopTimerTick, Off
SetTimer, ActionTimerTick, Off
SetTimer, BackgroundToolPoll, Off
ToolTip
StopTimerActive := 0
SettingsVisible := 0
SettingsGuiReady := 0
BindListVisible := 0
HUDVisible := 0
OnMessage(0x201, "")
OnMessage(0x200, "")
OnMessage(0x202, "")
OnMessage(0x111, "")
OnMessage(0x84, "")
Gui, 1:Destroy
Gui, 2:Destroy
Gui, 12:Destroy
Gui, 13:Destroy
Gui, 15:Destroy
Gui, 16:Destroy
Gui, 17:Destroy
Gui, IDOverlay:Destroy
Gui, 18:Destroy
Gui, 19:Destroy
Gui, 41:Destroy
Gui, 42:Destroy
Gui, ActionTimers:Destroy
ExitApp
return

StartSettingsDrag:
global hSettingsWnd
PostMessage, 0xA1, 2,,, ahk_id %hSettingsWnd%
return

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

2GuiSize:
if (A_EventInfo != 1)
    Settings_UpdateScrollbars()
return

2GuiEscape:
CloseSettings()
return

2GuiClose:
CloseSettings()
return

DispatchBoundHotkey:
HandleBoundHotkey(A_ThisHotkey)
return

DoGuiHotkeyDispatch:
HandleGuiHotkeyDispatch(A_ThisHotkey)
return

ExtractFirstNumber(text) {
    text := Trim(text)
    if RegExMatch(text, "(\d+)", m)
        return m1
    return ""
}

GetActiveChatText(inputEpoch := 0) {
    result := CaptureChatClipboard(false)
    return result.Ok ? result.Query : ""
}

LawSearch_CaptureAndCancelChat(inputEpoch := 0) {
    return CaptureChatClipboard(true)
}

CaptureChatClipboard(cancelChat := false) {
    global MockMode
    result := {Ok: 0, Query: "", Reason: "Не удалось прочитать игровой чат."}
    if (MockMode = "On" || AuditTestMode || PhysicalInputBusy || !GameLocator_IsActive() || isInChat() != 1)
        return result
    PhysicalInputBusy := 1
    epoch := AutomationEpoch
    saved := ClipboardAll
    sequence := -1
    try {
        Clipboard := ""
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        if !SafeSend("^a^c", "Input", epoch)
            return result
        ClipWait, 0.4
        if (ErrorLevel || epoch != AutomationEpoch || !GameLocator_IsActive() || isInChat() != 1)
            return result
        ; Only restore a clipboard update belonging to this foreground process.
        foreground := DllCall("GetForegroundWindow", "Ptr")
        owner := DllCall("GetClipboardOwner", "Ptr")
        DllCall("GetWindowThreadProcessId", "Ptr", foreground, "UInt*", foregroundPID)
        DllCall("GetWindowThreadProcessId", "Ptr", owner, "UInt*", ownerPID)
        if (!ownerPID || ownerPID != foregroundPID) {
            sequence := -1
            result.Reason := "Буфер обмена изменён другим приложением."
            return result
        }
        sequence := DllCall("GetClipboardSequenceNumber", "UInt")
        result.Query := Trim(Clipboard)
        if (sequence != DllCall("GetClipboardSequenceNumber", "UInt")) {
            sequence := -1
            return result
        }
        if (!cancelChat) {
            result.Ok := SafeSend("{End}", "Input", epoch)
            return result
        }
        if !SafeSend("^a{Backspace}", "Input", epoch)
            return result
        started := TickNow()
        while (isInChat() = 1 && TickNow() - started < 900) {
            if !SafeSend("{Esc}", "Input", epoch)
                return result
            Sleep, 70
        }
        result.Ok := epoch = AutomationEpoch && GameLocator_IsActive() && isInChat() = 0
        return result
    } finally {
        if (sequence >= 0 && sequence = DllCall("GetClipboardSequenceNumber", "UInt"))
            Clipboard := saved
        VarSetCapacity(saved, 0)
        PhysicalInputBusy := 0
    }
}

MatchGpsEnterCommand(lineText, triggerText, ByRef gpsNumber) {
    lineText := Trim(lineText)
    triggerText := Trim(triggerText)
    gpsNumber := ""

    if (triggerText = "" || triggerText = "ERROR")
        return false

    if (SubStr(triggerText, 1, 1) != "!")
        triggerText := "!" . triggerText

    if (SubStr(lineText, 1, StrLen(triggerText)) != triggerText)
        return false

    tailText := Trim(SubStr(lineText, StrLen(triggerText) + 1))
    if (tailText = "")
        return false

    if !RegExMatch(tailText, "^(\d+)$", m)
        return false

    gpsNumber := m1
    return true
}

TryHandleGpsEnterCommand(inputEpoch := 0) {
    global Trig_GpsD, Trig_GpsOS
    inputEpoch := AutomationEpoch

    if !IsGameActive()
        return false

    if (isInChat() != 1)
        return false

    lineText := GetActiveChatText()
    if (lineText = "")
        return false

    gpsNumber := ""
    actionName := ""
    downCount := 0

    if MatchGpsEnterCommand(lineText, Trig_GpsD, gpsNumber)
    {
        actionName := "GPS Д"
        downCount := 15
    }
    else if MatchGpsEnterCommand(lineText, Trig_GpsOS, gpsNumber)
    {
        actionName := "GPS ОБ"
        downCount := 16
    }
    else
        return false

    SafeSend("^a{Backspace}", "Input", inputEpoch)
    Sleep, 40
    SafeSend("{Enter}", "Input", inputEpoch)
    Sleep, 80
    return RunGpsDialogAction(actionName, downCount, gpsNumber)
}

SendGpsDialogDown(count, delayMs := 35, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if (count <= 0)
        return
    Loop %count%
    {
        SafeSend("{Down}", "Event", inputEpoch)
        Sleep, %delayMs%
    }
}

RunGpsDialogAction(actionName, downCount, gpsNumber, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    gpsNumber := ExtractFirstNumber(gpsNumber)
    if (gpsNumber = "")
    {
        Notify("warn")
        return false
    }

    gpsValue := gpsNumber + 0
    if (gpsValue < 1 || gpsValue > 10000)
    {
        Notify("warn")
        return false
    }

    if !CanRunAction(actionName, false, false)
        return false

    if (SendChatForEpoch(inputEpoch, "/gps") != 1)

        return
    Sleep, 260
    SendGpsDialogDown(downCount, 35)
    Sleep, 90
    SafeSend("{Enter}", "Event", inputEpoch)
    Sleep, 220
    PasteOnlyForEpoch(inputEpoch, gpsNumber)
    Sleep, 70
    SafeSend("{Enter}", "Event", inputEpoch)
    return true
}

ServiceCodes_GetText() {
    codesText =
    (LTrim
    1-1 Построение на парковке.
    1-2 Сбор на парковке управления ФСБ.
    1-3 На связь!
    1-4 Так точно/принял!
    1-5 Отмена/отбой! 
    1-6 Построение на плацу ВЧ.

    2-1 Начал участвовать в СО/МП.
    2-2 Продолжаю участвовать в СО/МП.
    2-3 Закончил участвовать в СО/МП.

    3-1 Выехали на вызов о срочной помощи "SOS".
    3-2 Прибыли на вызов срочной помощи "SOS".

    4-1 Выехали на вызов об ограблении дома/особняка.
    4-2 Прибыли на вызов об ограблении дома/особняка.
    4-3 Отработали вызов об ограблении дома/особняка.

    5-1 Выехали на вызов от гражданского.
    5-2 Прибыли на вызов от гражданского.
    5-3 Отработали вызов от гражданского.

    6-1 Начал патрулировать.
    6-2 Продолжаю патрулировать.
    6-3 Закончил патрулировать.

    7-1 Начал стоять на посту.
    7-2 Продолжаю стоять на посту.
    7-3 Закончил стоять на посту.
     
    8-1 Начал сопровождение ВК
    8-2 Закончил сопровождение ВК

    9-1 Начал выполнять служебную деятельность 
    9-2 Продолжаю выполнять служебную деятельность 
    9-3 Закончил выполнять служебную деятельность.
    )
    return codesText
}

ServiceCodes_Show() {
    global ServiceCodesGuiVisible, current_doc, last_doc
    if (ServiceCodesGuiVisible) {
        LawGui_Close()
        return false
    }

    if (current_doc) {
        last_doc := current_doc
        current_doc := 0
    }
    CloseAllDocs()
    LawGui_Show(1, "Служебные коды", ServiceCodes_GetText(), 1)
    ApplyPersistentAlwaysOnTop()
    ServiceCodesGuiVisible := 1
    return true
}

DoBindMenuToggle:
ToggleBindMenuEditMode()
return

DoServiceCodesGui:
if ServiceCodes_Show()
    Helper_CloseChatAfterGui()
return

ServiceCodes_Close:
ServiceCodesGuiEscape:
ServiceCodesGuiClose:
LawGui_Close()
return

DoMDC:
if !CanRunAction("MDC", true, false)
    return
ChatQueue_Enqueue("/mdc " . UserID, "MDC", 0, 700, 1)
return

DoVehicleLookup:
VehicleLookup_RunWizard()
return

DoWantedRemoval:
WantedRemoval_RunWizard()
return

DoOpenSettings:
ToggleSettings()
return

DoToggleBindList:
ToggleBindList()
return

DoLawSearchClipboard:
LawSearch_RunActiveFromChat()
return

DoHideLawGui:
if (TerritoryMapGuiVisible)
{
    TerritoryMap_CloseAll()
    return
}
if (ServiceCodesGuiVisible)
{
    LawGui_Close()
    return
}
if (SearchGuiVisible || SearchModeActive)
{
    Search_Close()
    return
}
if (current_doc)
{
    last_doc := current_doc
    CloseAllDocs()
    current_doc := 0
}
return

DoToggleHUD:
ToggleHUD()
return

DoToggleIDOverlay:
ToggleIDOverlay()
return

ToggleHUDLabel:
ToggleHUD()
return

ToggleBindListLabel:
ToggleBindList()
return

DoConfirmID:
if (isInChat() = 1)
    return
if ContextAssistant_ConfirmHotkeysActive()
    ContextAssistant_Submit("")
return

DoRejectID:
if (isInChat() = 1)
    return
if ContextAssistant_ConfirmHotkeysActive()
    ContextAssistant_Close()
return

DoResetID:
ResetCurrentID()
return

StartHUDDrag:
global hHUDWnd
PostMessage, 0xA1, 2,,, ahk_id %hHUDWnd%
return

StartBindListDrag:
global hBindListWnd
PostMessage, 0xA1, 2,,, ahk_id %hBindListWnd%
return

DoEnterID:
InputAction_DoEnterID()
return

InputAction_DoEnterID(inputEpoch := 0) {
    global
    if IsObject(IDCaptureState)
        return IDCapture_Complete("confirm")
    if !CanRunAction("ввод ID", false, false)
        return false
    NormalizeIDEntryMode(IDEntryMode)
    if (IDEntryMode = "Перехват цифр")
        return IDCapture_Start()
    inputEpoch := AutomationEpoch
    SafeLayout(0x4190419)
    SafeSend("{F6}", "Input", inputEpoch)
    Sleep, 100
    SafeSend("/Введите ID подозреваемого:{space}", "Input", inputEpoch)
    Sleep, 50
    Input, UserID, I L20 V, {Enter}
    if (UserID != "" && inputEpoch = AutomationEpoch)
        ShowIDGui(UserID)
    return
}

DoOpenBindsTab:
if (SettingsVisible)
    Settings_SwitchPage(SettingsPageIndex("hotkeys_main"))
else
    OpenSettings("hotkeys_main")
return

DoMaskCall:
if !CanRunAction("маска и звонок", false, true)
    return
ChatQueue_Enqueue("/mask", "MaskCall", 0, 600, 1)
ChatQueue_Enqueue("/call 97710514", "MaskCall", 0, 600, 1)
ChatQueue_Enqueue("/h", "MaskCall", 0, 700, 1)
return

DoRecordCheck:
if !CanRunAction("проверка записывающих устройств", false, true)
    return
ChatQueue_Enqueue("/do У человека имеются при себе видео/аудио записывающие устройства?", "RecordCheck", 0, 2000, 1)
ChatQueue_Enqueue("/b Ответ в /do: Да./Нет.", "RecordCheck", 0, 700, 1)
return

DoTrainCrash:
ContextAssistant_Request("TrainCrash")
return

DoPersonalFile:
if !CanRunAction("личное дело", false, true)
    return
ChatQueue_Enqueue("/me снял все предметы с лица гражданина, достал КПК", "PersonalFile", 0, 2000, 1)
ChatQueue_Enqueue("/me навел камеру КПК на лицо гражданина, сделал фоторобот", "PersonalFile", 0, 2000, 1)
ChatQueue_Enqueue("/me сделал запрос в базу данных МВД", "PersonalFile", 0, 2000, 1)
ChatQueue_Enqueue("/do Личное дело найдено.", "PersonalFile", 0, 700, 1)
return

DoSu:
if !CanRunAction("корректировка розыска", true, true)
    return
ChatQueue_Enqueue("/su " . UserID, "Su", 0, 500, 1)
ChatQueue_Enqueue("/me достал КПК, авторизовался, ввел данные гражданина", "Su", 0, 3000, 1)
ChatQueue_Enqueue("/do Личное дело найдено.", "Su", 0, 3000, 1)
ChatQueue_Enqueue("/me начал вводить корректировки", "Su", 0, 700, 1)
TaskScheduler_Set("SuReminder", 20000, "SuElapsedNotify", "Напоминание /su", UserID)
return

DoIntro:
if !CanRunAction("представление")
    return
SendTemplateChat(T_Intro)
Evidence_BeginDocumentWindow()
return

DoChase:
if !HasCurrentID()
{
    ContextAssistant_Request("Chase")
    return
}
if !CanRunAction("chase", false, true)
    return
ChatQueue_Enqueue(ContextAssistant_BuildCommand("Chase", UserID), "Chase")
return

DoChaseNoID:
if !CanRunAction("chase без ID", false, true)
    return
ChatQueue_Enqueue("/chase", "ChaseNoID")
return

DoDeject:
global LastDejectActionTick, DejectFollowupWindowMs
nowTick := TickNow()
if (LastDejectActionTick > 0 && nowTick - LastDejectActionTick <= DejectFollowupWindowMs)
{
    LastDejectActionTick := 0
    if !CanRunDejectFollowup()
        return
    SendDejectRPAfterCommand()
    return
}
if (LastDejectActionTick > 0 && nowTick - LastDejectActionTick > DejectFollowupWindowMs)
    LastDejectActionTick := 0
if !CanRunAction("deject", true, true, true)
    return
if (SendChat((UserID < 1000 ? "/deject " : "/dejectid ") . UserID) != 1)
    return
LastDejectActionTick := TickNow()
Sleep, 500
return

DoCuff:
global LastCuffActionTick, CuffFollowupWindowMs
nowTick := TickNow()
if (LastCuffActionTick > 0 && nowTick - LastCuffActionTick <= CuffFollowupWindowMs)
{
    LastCuffActionTick := 0
    if !CanRunCuffFollowup()
        return
    DoCuffFollowup()
    return
}
if (LastCuffActionTick > 0 && nowTick - LastCuffActionTick > CuffFollowupWindowMs)
    LastCuffActionTick := 0
if !CanRunAction("cuff", true, true)
    return
if (SendChat("/cuff " . UserID) != 1)
    return
LastCuffActionTick := TickNow()
Sleep, 1200
return

DoInCar:
Action_DoInCar()
return

Action_DoInCar() {
    global RP_InCar, UserID
    if !CanRunAction("incar", true, true, true)
        return false
    return QueueRpAction(RP_InCar, "/incar " . UserID, "DoInCar", [])
}

DoStopChase:
if !CanRunAction("требование остановки", true, true, true)
    return
global StopTimerActive, StopTimerCounter
StopTimerActive := 1
StopTimerCounter := 15
ShowStopTimerGUI()
Sleep 30
SendConfigSequence(RP_StopChase, 500)
return

DoDoc:
Action_DoDoc()
return

Action_DoDoc() {
    global RP_Doc, UserID
    if !CanRunAction("документы", true)
        return false
    return QueueRpAction(RP_Doc, "/doc " . UserID, "DoDoc", [])
}

DoSearch:
Action_DoSearch()
return

Action_DoSearch() {
    global RP_Search, UserID
    if !CanRunAction("досмотр", true, true, false, false, true)
        return false
    Evidence_Arm("SEARCH_PERSON", 60000)
    return QueueRpAction(RP_Search, "/frac " . UserID, "DoSearch", [1, 5, 1])
}

DoSOS:
InputAction_DoSOS()
return

InputAction_DoSOS(inputEpoch := 0) {
    global
    inputEpoch := AutomationEpoch
if !CanRunAction("SOS", false, true)
    return
if (SendChatForEpoch(inputEpoch, "/sos") != 1)
    return
Sleep 300
SafeSend("{Down}", "Input", inputEpoch)
Sleep 300
SafeSend("{Enter}", "Input", inputEpoch)
return
}

DoDep:
if !CanRunAction("/dep", false, false, false, true)
    return
SendTemplateOpen(T_Dep, 0)
return

DoWantedList:
InputAction_DoWantedList()
return

InputAction_DoWantedList(inputEpoch := 0) {
    global
    inputEpoch := AutomationEpoch
if !CanRunAction("Розыскиваемые", false, true)
    return
Sendchat("/frac")
Sleep 300
Loop, 8
{
    SafeSend("{1}", "Input", inputEpoch)
    Sleep, 50
}
StopTimerActive := 1
StopTimerCounter := 60
ShowStopTimerGUI()
return
}

DoSOSStart:
if !CanRunAction("SOS выехал", false, true)
    return
Evidence_Arm("SOS_START", 90000)
SendTemplateChat(T_SOSStart)
return

DoSOSArrive:
if !CanRunAction("SOS прибыл", false, true)
    return
Evidence_Arm("SOS_ARRIVE", 90000)
SendTemplateChat(T_SOSArrive)
return

DoCivilCallStart:
if !CanRunAction("гражданский вызов принят", false, true)
    return
Evidence_Arm("CIVIL_START", 90000)
SendTemplateChat(T_CivilCallStart)
return

DoCivilCallArrive:
if !CanRunAction("гражданский вызов: прибыл", false, true)
    return
Evidence_Arm("CIVIL_ARRIVE", 90000)
SendTemplateChat(T_CivilCallArrive)
return

DoHijackStart:
if !CanRunAction("угон выехал", false, true)
    return
SendTemplateChat(T_HijackStart)
return

DoHijackArrive:
if !CanRunAction("угон прибыл", false, true)
    return
SendTemplateChat(T_HijackArrive)
return

DoCallStart:
if !CanRunAction("вызов старт", false, true)
    return
Evidence_Arm("CALL_START", 90000)
SendTemplateChat(T_CallStart)
return

DoCallArrive:
if !CanRunAction("вызов прибыл", false, true)
    return
Evidence_Arm("CALL_ARRIVE", 90000)
SendTemplateChat(T_CallArrive)
return

DoCallWorkStart:
if !CanRunAction("оформление ДТП старт", false, true)
    return
Evidence_Arm("CALL_WORK_START", 90000)
SendTemplateChat(T_CallWorkStart)
return

DoCallWorkEnd:
if !CanRunAction("оформление ДТП конец", false, true)
    return
Evidence_Arm("CALL_WORK_END", 90000)
SendTemplateChat(T_CallWorkEnd)
return

DoPatrolStart:
if !CanRunAction("патруль старт", false, false, false, true)
    return
Evidence_Arm("PATROL_START", 120000)
SendTemplateChat(T_PatrolStart)
ActionTimer_StartManualService("Патруль")
return

DoPatrolCont:
if !CanRunAction("патруль продолжение", false, false, false, true)
    return
Evidence_Arm("PATROL_CONTINUE", 120000)
SendTemplateChat(T_PatrolContinue)
ActionTimer_StartManualService("Патруль")
return

DoPatrolEnd:
if !CanRunAction("патруль конец", false, false, false, true)
    return
Evidence_Arm("PATROL_END", 120000)
SendTemplateChat(T_PatrolEnd)
if (AutoReportActive && AutoReportMode = "Патруль")
    AutoReport_Stop(0, "patrol-end")
ActionTimer_Stop("Patrol")
return

DoPostStart:
if !CanRunAction("пост старт", false, false, false, true)
    return
Evidence_Arm("POST_START", 120000)
SendTemplateChat(T_PostStart)
ActionTimer_StartManualService("Пост")
return

DoPostCont:
if !CanRunAction("пост продолжение", false, false, false, true)
    return
Evidence_Arm("POST_CONTINUE", 120000)
SendTemplateChat(T_PostContinue)
ActionTimer_StartManualService("Пост")
return

DoPostEnd:
if !CanRunAction("пост конец", false, false, false, true)
    return
Evidence_Arm("POST_END", 120000)
SendTemplateChat(T_PostEnd)
if (AutoReportActive && AutoReportMode = "Пост")
    AutoReport_Stop(0, "post-end")
ActionTimer_Stop("Post")
return

DoConvoyStart:
if !CanRunAction("колонна старт", false, false, false, true)
    return
SendTemplateOpen(T_ConvoyStart, 6)
return

DoConvoyCont:
if !CanRunAction("колонна продолжение", false, false, false, true)
    return
SendTemplateOpen(T_ConvoyCont, 6)
return

DoConvoyEnd:
if !CanRunAction("колонна конец", false, false, false, true)
    return
SendTemplateOpen(T_ConvoyEnd, 6)
return

DoTowStart:
if !CanRunAction("эвакуация старт", false, true, true)
    return
Evidence_Arm("EVAC_START", 60000)
towTemplate := TowStart_EnsureTowLast(RP_TowStart)
hasReport := SplitConfigReportLine(towTemplate, reportLine, towSequence)
if (hasReport) {
    reportResult := SendChat(ApplyActionTemplate(reportLine), "TowStartReport")
    if (reportResult != 1) {
        GameNotify("Доклад о начале эвакуации не отправлен. Действие отменено.", "ERROR")
        return
    }
    Sleep, 500
} else {
    towSequence := towTemplate
}
towSequence := TowStart_EnsureTowLast(towSequence)
if !SendConfigSequence(towSequence, 700) {
    GameNotify("Последовательность эвакуации не поставлена в очередь.", "ERROR")
    return
}
if !WaitForChatQueueIdle(25000) {
    GameNotify("Отправка эвакуации не подтверждена; таймер не запущен.", "WARN")
    return
}
ActionTimer_StartEvacuation()
return

DoTowEnd:
if !CanRunAction("эвакуация конец", false, true, true)
    return
Evidence_Arm("EVAC_END", 90000)
if !SendConfigSequence(RP_TowEnd, 700)
{
    GameNotify("Завершение эвакуации не поставлено в очередь.", "ERROR")
    return
}
if !WaitForChatQueueIdle(20000)
{
    GameNotify("Не удалось дождаться доклада об эвакуации. Сдача ТС отменена.", "ERROR")
    return
}
ActionTimer_Stop("Evac")
Sleep 650
if (SendChat("/frac") != 1)
    return
Sleep 320
SendRadialNumberTwice(1, 280)
SendRadialNumberTwice(4, 280)
SendRadialNumberTwice(5, 320)
return

DoCarSearch:
if !CanRunAction("осмотр ТС", false, true)
    return
SendConfigSequence(RP_CarSearch, 700)
if !WaitForChatQueueIdle(20000)
{
    GameNotify("Не удалось дождаться RP-досмотра ТС.", "ERROR")
    return
}
Evidence_Arm("SEARCH_TRUNK", 45000)
if (SendChat("/frac") != 1)
    return
Sleep 320
SendRadialNumberTwice(1, 280)
SendRadialNumberTwice(4, 280)
SendRadialNumberTwice(1, 320)
return

DoArrest:
Action_DoArrest()
return

Action_DoArrest() {
    global RP_Arrest, UserID
    if !CanRunAction("арест", true)
        return false
    Evidence_Arm("ARREST", 60000)
    return QueueRpAction(RP_Arrest, "/frac " . UserID, "DoArrest", [1, 5, 8])
}

DoFine:
Fine_RunWizard()
return

DoProtocol:
if !CanRunAction("протокол", false, true, false, false, true)
    return
SendConfigSequence(RP_Protocol, 900)
return

DoRights:
if !CanRunAction("права", false, true, false, false, true)
    return
SendConfigSequence(RP_Rights, 1000)
return

DoCardDS:
if !CanRunAction("визитка DS", false, true, false, false, true)
    return
SendConfigSequence(RP_CardDS, 700)
return

DoCardVK:
if !CanRunAction("визитка VK", false, true, false, false, true)
    return
SendConfigSequence(RP_CardVK, 700)
return

DoMDSFormation:
ToggleMDSFormationCountdown()
return

DoAssistOOP:
ContextAssistant_Request("OOPSearch")
return

DoAssistStun:
ContextAssistant_Request("Stun")
return

DoAssistChase:
ContextAssistant_Request("Chase")
return

DoAssistHouse:
ContextAssistant_Request("HouseAlarm")
return

DoAssistDrugs:
ContextAssistant_Request("DrugsNearby")
return

DoAssistPDPCuff:
ContextAssistant_Request("PDPCuff")
return

ReadAutoReportMinutes(mode, inputEpoch := 0) {
    inputEpoch := AutomationEpoch
    if !EnsureGameActive()
        return 0

    GameNotify("Укажите время автодоклада «" . mode . "»: от 10 до 600 минут.", "INFO")

    chatState := isInChat()
    if (chatState = 1) {
        SafeSend("^a{Backspace}", "Input", inputEpoch)
        Sleep, 50
    } else {
        SafeSend("{F6}", "Input", inputEpoch)
        Sleep, 120
    }
    Input, minutesText, I L3 V T20, {Enter}{Escape}
    inputResult := ErrorLevel

    if (isInChat() = 1) {
        SafeSend("^a{Backspace}", "Input", inputEpoch)
        Sleep, 50
        SafeSend("{Esc}", "Input", inputEpoch)
        Sleep, 80
    }

    if (inputResult = "Timeout" || inputResult = "EndKey:Escape") {
        SafeWarn("Запуск автодоклада отменён.")
        return 0
    }

    minutesText := Trim(minutesText)
    if !AutoReport_IsValidDuration(minutesText) {
        SafeWarn("Допустимое время автодоклада: целое число от 10 до 600 минут.")
        return 0
    }
    minutes := minutesText + 0
    return minutes
}

DoAutoPatrolToggle:
if (AutoReportActive && AutoReportMode = "Патруль") {
    AutoReport_Stop(1, "manual toggle")
    return
}
patrolMins := ReadAutoReportMinutes("Патруль")
if (patrolMins > 0)
    AutoReport_Start("Патруль", patrolMins, 1)
return

DoAutoPostToggle:
if (AutoReportActive && AutoReportMode = "Пост") {
    AutoReport_Stop(1, "manual toggle")
    return
}
postMins := ReadAutoReportMinutes("Пост")
if (postMins > 0)
    AutoReport_Start("Пост", postMins, 1)
return

#If (ServiceCodesGuiVisible)
$Esc::
LawGui_Close()
return
#If

#If (BindMenuEditMode && IsGameActive() && isInChat() = 1)
$Enter::
HandleBindMenuEnter()
return

$NumpadEnter::
HandleBindMenuEnter()
return
#If

#If (BindMenuEditMode && IsGameActive())
$!f::
HandleBindMenuApplyHotkey()
return
#If

; Passive hooks leave RMB available to the game and stop polling on any release.
#If (AutoTargetIDEnabled = "On" && MockMode != "On" && GameLocator_IsActive())
~*RButton::
AutoTargetID_BeginAim()
return
#If

~*RButton Up::
AutoTargetID_EndAim()
return

#If IsGameActive()
Numpad1::
if (BindMenuEditMode)
{
    BindMenuHotkeyBlockedWarn()
    return
}
if !CanRunAction("быстрый /frac", true, true)
    return
if (SendChat("/frac " . UserID) != 1)
    return
return

!x::
ToggleBindOverlay()
return
#If

ToggleLawDoc(docId, firstFlagVar, showFuncName) {
    global current_doc, last_doc
    prefix := LawDoc_PrefixById(docId)
    if (prefix = "")
    {
        LogError("ToggleLawDoc", "Неизвестный документ: " . docId)
        return false
    }
    if (current_doc != docId)
    {
        CloseAllDocs()
        current_doc := docId
        last_doc := docId
        if !IsFunc("LawDoc_ShowPage") || !LawDoc_ShowPage(prefix, 1)
        {
            LogError("ToggleLawDoc", "Не удалось открыть официальный corpus: " . prefix)
            current_doc := 0
            return false
        }
        ApplyPersistentAlwaysOnTop()
    }
    else
    {
        last_doc := docId
        CloseAllDocs()
        current_doc := 0
    }
    return true
}

LawDoc_PrefixById(docId) {
    static prefixes := ["vu", "fp", "kon", "fzop", "ter", "tk", "arg", "uk", "vv", "koap"
        , "pdd", "oruzh", "upk", "kas", "fsb", "fsin", "vs", "sud", "ord", "gt"]
    docId += 0
    if (docId < 1 || docId > prefixes.Length())
        return ""
    return prefixes[docId]
}

ToggleLawDocFromChat(docId, firstFlagVar, showFuncName) {
    global current_doc
    wasCurrentDoc := current_doc
    ToggleLawDoc(docId, firstFlagVar, showFuncName)
    if (wasCurrentDoc != docId && current_doc = docId)
        Helper_CloseChatAfterGui()
}

GetLawDocMeta(docId, ByRef firstFlagVar, ByRef showFuncName) {
    firstFlagVar := ""
    showFuncName := ""
    if (docId = 1)
        firstFlagVar := "flvu1", showFuncName := "vu1"
    else if (docId = 2)
        firstFlagVar := "flfp1", showFuncName := "fp1"
    else if (docId = 3)
        firstFlagVar := "flkon1", showFuncName := "kon1"
    else if (docId = 4)
        firstFlagVar := "flfzop1", showFuncName := "fzop1"
    else if (docId = 5)
        firstFlagVar := "flter1", showFuncName := "ter1"
    else if (docId = 6)
        firstFlagVar := "fltk1", showFuncName := "tk1"
    else if (docId = 7)
        firstFlagVar := "flarg1", showFuncName := "arg1"
    else if (docId = 8)
        firstFlagVar := "fluk1", showFuncName := "uk1"
    else if (docId = 9)
        firstFlagVar := "flvv1", showFuncName := "vv1"
    else if (docId = 10)
        firstFlagVar := "flkoap1", showFuncName := "koap1"
    else if (docId = 11)
        firstFlagVar := "flpdd1", showFuncName := "pdd1"
    else if (docId = 12)
        firstFlagVar := "floruzh1", showFuncName := "oruzh1"
    else if (docId = 13)
        firstFlagVar := "flupk1", showFuncName := "upk1"
    else if (docId = 14)
        firstFlagVar := "flkas1", showFuncName := "kas1"
    else if (docId = 15)
        firstFlagVar := "flfsb1", showFuncName := "fsb1"
    else if (docId = 16)
        firstFlagVar := "flfsin1", showFuncName := "fsin1"
    else if (docId = 17)
        firstFlagVar := "flvs1", showFuncName := "vs1"
    else if (docId = 18)
        firstFlagVar := "flsud1", showFuncName := "sud1"
    else if (docId = 19)
        firstFlagVar := "flord1", showFuncName := "ord1"
    else if (docId = 20)
        firstFlagVar := "flgt1", showFuncName := "gt1"
    return (firstFlagVar != "" && showFuncName != "")
}

DoToggleLastLawDoc:
if (current_doc)
{
    last_doc := current_doc
    CloseAllDocs()
    current_doc := 0
    return
}
if (!last_doc)
    return
if GetLawDocMeta(last_doc, firstFlagVar, showFuncName)
    ToggleLawDoc(last_doc, firstFlagVar, showFuncName)
return

DoToggleVU:
    ToggleLawDocFromChat(1, "flvu1", "vu1")
return

DoToggleFP:
    ToggleLawDocFromChat(2, "flfp1", "fp1")
return

DoToggleKON:
    ToggleLawDocFromChat(3, "flkon1", "kon1")
return

DoToggleFZOP:
    ToggleLawDocFromChat(4, "flfzop1", "fzop1")
return

DoToggleTER:
    ToggleLawDocFromChat(5, "flter1", "ter1")
return

DoToggleTK:
    ToggleLawDocFromChat(6, "fltk1", "tk1")
return

DoToggleARG:
    ToggleLawDocFromChat(7, "flarg1", "arg1")
return

DoToggleUK:
    ToggleLawDocFromChat(8, "fluk1", "uk1")
return

DoToggleVV:
    ToggleLawDocFromChat(9, "flvv1", "vv1")
return

DoToggleKOAP:
    ToggleLawDocFromChat(10, "flkoap1", "koap1")
return

DoTogglePDD:
    ToggleLawDocFromChat(11, "flpdd1", "pdd1")
return

DoToggleORUZH:
    ToggleLawDocFromChat(12, "floruzh1", "oruzh1")
return

DoToggleUPK:
    ToggleLawDocFromChat(13, "flupk1", "upk1")
return

DoToggleKAS:
    ToggleLawDocFromChat(14, "flkas1", "kas1")
return

DoToggleFSB:
    ToggleLawDocFromChat(15, "flfsb1", "fsb1")
return

DoToggleFSIN:
    ToggleLawDocFromChat(16, "flfsin1", "fsin1")
return

DoToggleVS:
    ToggleLawDocFromChat(17, "flvs1", "vs1")
return

DoToggleSUD:
    ToggleLawDocFromChat(18, "flsud1", "sud1")
return

DoToggleORD:
    ToggleLawDocFromChat(19, "flord1", "ord1")
return

DoToggleGT:
    ToggleLawDocFromChat(20, "flgt1", "gt1")
return

#If (TerritoryMapGuiVisible || SearchGuiVisible || current_doc)
PgUp::
{
    global current_doc, SearchGuiVisible
    global TerritoryMapGuiVisible, TerritoryMapViewVisible
    if (TerritoryMapGuiVisible)
    {
        if (TerritoryMapViewVisible)
            TerritoryMap_Navigate("prev")
        return
    }
    if (SearchGuiVisible)
    {
        Search_ShowPrevResult()
        return
    }
    if (current_doc = 1)
        NavigateVU("prev")
    else if (current_doc = 2)
        NavigateFP("prev")
    else if (current_doc = 3)
        NavigateKON("prev")
    else if (current_doc = 4)
        NavigateFZOP("prev")
    else if (current_doc = 5)
        NavigateTER("prev")
    else if (current_doc = 6)
        NavigateTK("prev")
    else if (current_doc = 7)
        NavigateARG("prev")
    else if (current_doc = 8)
        NavigateUK("prev")
    else if (current_doc = 9)
        NavigateVV("prev")
    else if (current_doc = 10)
        NavigateKOAP("prev")
    else if (current_doc = 11)
        NavigatePDD("prev")
    else if (current_doc = 12)
        NavigateORUZH("prev")
    else if (current_doc = 13)
        NavigateUPK("prev")
    else if (current_doc = 14)
        NavigateKAS("prev")
    else if (current_doc = 15)
        NavigateFSB("prev")
    else if (current_doc = 16)
        NavigateFSIN("prev")
    else if (current_doc = 17)
        NavigateVS("prev")
    else if (current_doc = 18)
        NavigateSUD("prev")
    else if (current_doc = 19)
        NavigateORD("prev")
    else if (current_doc = 20)
        NavigateGT("prev")
    return
}

PgDn::
{
    global current_doc, SearchGuiVisible
    global TerritoryMapGuiVisible, TerritoryMapViewVisible
    if (TerritoryMapGuiVisible)
    {
        if (TerritoryMapViewVisible)
            TerritoryMap_Navigate("next")
        return
    }
    if (SearchGuiVisible)
    {
        Search_ShowNextResult()
        return
    }
    if (current_doc = 1)
        NavigateVU("next")
    else if (current_doc = 2)
        NavigateFP("next")
    else if (current_doc = 3)
        NavigateKON("next")
    else if (current_doc = 4)
        NavigateFZOP("next")
    else if (current_doc = 5)
        NavigateTER("next")
    else if (current_doc = 6)
        NavigateTK("next")
    else if (current_doc = 7)
        NavigateARG("next")
    else if (current_doc = 8)
        NavigateUK("next")
    else if (current_doc = 9)
        NavigateVV("next")
    else if (current_doc = 10)
        NavigateKOAP("next")
    else if (current_doc = 11)
        NavigatePDD("next")
    else if (current_doc = 12)
        NavigateORUZH("next")
    else if (current_doc = 13)
        NavigateUPK("next")
    else if (current_doc = 14)
        NavigateKAS("next")
    else if (current_doc = 15)
        NavigateFSB("next")
    else if (current_doc = 16)
        NavigateFSIN("next")
    else if (current_doc = 17)
        NavigateVS("next")
    else if (current_doc = 18)
        NavigateSUD("next")
    else if (current_doc = 19)
        NavigateORD("next")
    else if (current_doc = 20)
        NavigateGT("next")
    return
}
#If

:?:!фп1::return
:?:!фп2::return
:?:!фп3::return


MigrateConfigIfNeeded() {
    global ConfigFile, ConfigReadOnly, ConfigVersion
    IniRead, version, %ConfigFile%, Meta, ConfigVersion, 0
    if (version > ConfigVersion) {
        ConfigReadOnly := 1
        return false
    }
    if (version = ConfigVersion)
        return true
    original := ConfigFile
    stage := ConfigStage(original)
    if (stage = "") {
        ConfigReadOnly := 1
        return false
    }
    ConfigFile := stage
    try {
        ok := MigrateConfigInPlace()
    } finally {
        ConfigFile := original
    }
    if (!ok)
        ConfigWriteFailed := 1
    committed := ConfigCommit(stage, original)
    if (!committed)
        ConfigReadOnly := 1
    return committed
}


MemoryRemotePollTimer:
MemoryRemotePoll()
return

CaptureRefreshTimer:
Capture_RefreshWindows()
return

SaveUiDebounced:
SaveUISettings()
return
