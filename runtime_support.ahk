global LawSearchVocabulary := {}
; Shared runtime contracts for AutoHotkey v1.1 ANSI x86.
global QueueBatchStates := {}
global QueueBatchNextId := 0
global QueueFailureGeneration := 0
global AutoReportAcceptedCount := 0
global ChatLogReaderIdentity := ""
global ChatLogCursorSignature := ""
global ChatLogReaderDroppingLine := 0
global CaptureStatus := "Отключено"
global HistoricalHotstrings := {}
global HistoricalHotstringCount := 0
global SettingsScrollX := 0
global SettingsScrollY := 0
global PendingToolHandle := 0
global AuditTransportResult := 1
global AuditReaderLines := ""
global LawSearchCorpusSignature := ""
global LawSearchMissingDocuments := []
global LawSearchBuildBusy := 0

CheckedIniWrite(value, file, section, key) {
    if (ConfigReadOnly || file = "" || section = "" || key = "") {
        ConfigWriteFailed := 1
        ErrorLevel := 1
        return false
    }
    try {
        IniWrite, %value%, %file%, %section%, %key%
        failed := ErrorLevel
    } catch e {
        failed := 1
    }
    if (failed)
        ConfigWriteFailed := 1
    ErrorLevel := failed
    return !failed
}

ConfigStage(file) {
    if (ConfigTransactionBusy || ConfigReadOnly || file = "")
        return ""
    IniRead, schema, %file%, Meta, ConfigVersion, 0
    if (schema > 14) {
        ConfigReadOnly := 1
        return ""
    }
    ConfigTransactionBusy := 1
    ConfigWriteFailed := 0
    stage := file . ".stage_" . DllCall("GetCurrentProcessId") . "_" . TickNow()
    if FileExist(stage) {
        ConfigTransactionBusy := 0
        return ""
    }
    if FileExist(file) {
        try {
            FileCopy, %file%, %stage%, 0
            copyFailed := ErrorLevel
        } catch e {
            copyFailed := 1
        }
        if (copyFailed) {
            ConfigTransactionBusy := 0
            return ""
        }
    } else {
        stream := FileOpen(stage, "w", "CP1251")
        if !IsObject(stream) {
            ConfigTransactionBusy := 0
            return ""
        }
        stream.Close()
    }
    return stage
}

ConfigCommit(stage, target) {
    ok := false
    try {
        DllCall("WritePrivateProfileStringA", "Ptr", 0, "Ptr", 0, "Ptr", 0, "AStr", stage)
        DllCall("WritePrivateProfileStringA", "Ptr", 0, "Ptr", 0, "Ptr", 0, "AStr", target)
        if (ConfigWriteFailed || !FileExist(stage))
            return false
        handle := DllCall("CreateFileA", "AStr", stage, "UInt", 0x40000000, "UInt", 1, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
        if (handle = -1)
            return false
        flushed := DllCall("FlushFileBuffers", "Ptr", handle)
        DllCall("CloseHandle", "Ptr", handle)
        if (!flushed)
            return false
        if FileExist(target) {
            backup := target . ".bak"
            FileCopy, %target%, %backup%, 1
            if (ErrorLevel)
                return false
            ; ReplaceFile keeps the previous file intact if the atomic replacement fails.
            ok := DllCall("ReplaceFileA", "AStr", target, "AStr", stage, "Ptr", 0, "UInt", 0, "Ptr", 0, "Ptr", 0)
        } else
            ok := DllCall("MoveFileExA", "AStr", stage, "AStr", target, "UInt", 0x8)
        return ok ? true : false
    } catch e {
        return false
    } finally {
        if (!ok)
            LogError("Config", "Сохранение не выполнено; исходный файл сохранён.", "ERROR")
        ConfigTransactionBusy := 0
        if FileExist(stage) {
            try {
                FileDelete, %stage%
            } catch cleanupError {
                LogError("Config", "Не удалось удалить временный файл: " . stage, "WARN")
            }
        }
    }
}

ConfigAddProfile(file, name) {
    IniRead, names, %file%, Profiles, Names,
    found := false
    Loop, Parse, names, |
        if (A_LoopField = name)
            found := true
    if (!found)
        names .= (names = "" ? "" : "|") . name
    return CheckedIniWrite(names, file, "Profiles", "Names")
}

RotateOwnedLog(file) {
    if (file = "" || !FileExist(file))
        return
    FileGetSize, bytes, %file%
    if (bytes < 262144)
        return
    last := file . ".4"
    FileDelete, %last%
    Loop, 3 {
        index := 4 - A_Index
        old := file . "." . index
        next := file . "." . (index + 1)
        if FileExist(old)
            FileMove, %old%, %next%, 1
    }
    first := file . ".1"
    FileMove, %file%, %first%, 1
}

PruneOwnedBackups(dir) {
    entries := ""
    Loop, Files, % dir . "\profiles_backup_*.ini", F
    {
        if !RegExMatch(A_LoopFileName, "^profiles_backup_\d{14}_\d+_[A-Za-z0-9_-]+\.ini$")
            continue
        entries .= A_LoopFileTimeModified . "|" . A_LoopFileFullPath . "`n"
    }
    Sort, entries, R
    count := 0, migrationKept := 0
    Loop, Parse, entries, `n, `r
    {
        if (A_LoopField = "")
            continue
        path := SubStr(A_LoopField, 16)
        if (InStr(path, "_migrate_") && !migrationKept) {
            migrationKept := 1
            continue
        }
        if (++count > 10)
            FileDelete, %path%
    }
}

ChatLogReader_ResetGeneration() {
    global ChatLogLastPos, ChatLogFileSeen, ChatLogPendingIdResultLine, ChatLogRescuePending, ChatLogReaderLastTriggerTick
    ChatLogFileSeen := false
    ChatLogLastPos := 0
    ChatLogReaderIdentity := ""
    ChatLogCursorSignature := ""
    ChatLogReaderDroppingLine := 0
    ChatLogPendingIdResultLine := 0
    ChatLogRescuePending := 0
    ChatLogReaderLastTriggerTick := {}
    ChatLogReader_ClearLookup()
}

ChatLogReader_FileIdentity(file) {
    VarSetCapacity(info, 52, 0)
    if !DllCall("GetFileInformationByHandle", "Ptr", file.__Handle, "Ptr", &info)
        return ""
    identity := NumGet(info, 28, "UInt") . "|" . NumGet(info, 44, "UInt") . "|" . NumGet(info, 48, "UInt")
    ; Wine may emulate creation time with changing Unix ctime; native Windows is stable.
    wine := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "ntdll.dll", "Ptr"), "AStr", "wine_get_version", "Ptr")
    return identity . (wine ? "" : "|" . NumGet(info, 4, "Int64"))
}

ChatQueue_EnqueueBatch(lines, source, delayAfter := 700, menu := "") {
    global ChatQueueItems, ChatQueueMaxItems
    if (!IsObject(lines) || !lines.Length())
        return 0
    if !IsObject(ChatQueueItems)
        ChatQueueItems := []
    NormalizeNumberRange(ChatQueueMaxItems, 200, 10, 1000)
    prepared := []
    for _, text in lines {
        if IsObject(text) {
            if (text.Kind != "Menu" || !IsObject(text.Steps))
                return 0
            prepared.Push({Kind: "Menu", Steps: text.Steps.Clone(), Text: "[MENU]", Source: source, Tries: 0, ForceMock: 0, DelayAfter: 300, Epoch: AutomationEpoch})
        } else {
            if (Trim(text) = "")
                return 0
            prepared.Push({Text: text, Source: source, Tries: 0, ForceMock: 0, DelayAfter: delayAfter, Epoch: AutomationEpoch})
        }
    }
    previous := A_IsCritical
    Critical, On
    if (ChatQueueItems.Length() + prepared.Length() > ChatQueueMaxItems) {
        Critical, %previous%
        return 0
    }
    id := ++QueueBatchNextId
    QueueBatchStates[id] := {Pending: prepared.Length(), State: "queued", Epoch: AutomationEpoch, Menu: menu}
    for _, item in prepared {
        item.Batch := id
        ChatQueueItems.Push(item)
    }
    Critical, %previous%
    QueueBatch_Prune()
    return id
}

ChatQueue_CompleteItem(item, result) {
    global ChatQueueItems
    if (!item.HasKey("Batch") || !item.Batch || !QueueBatchStates.HasKey(item.Batch))
        return
    batch := QueueBatchStates[item.Batch]
    batch.Pending--
    if (result != "sent") {
        batch.State := result
        kept := []
        for _, pending in ChatQueueItems {
            if (pending.HasKey("Batch") && pending.Batch = item.Batch)
                batch.Pending--
            else
                kept.Push(pending)
        }
        ChatQueueItems := kept
    } else if (!batch.Pending && batch.State = "queued")
        batch.State := "sent"
}

ChatQueue_CancelBatches() {
    for _, batch in QueueBatchStates {
        if (batch.State = "queued")
            batch.State := "cancelled"
    }
}

QueueBatch_Prune() {
    if (QueueBatchStates.Count() <= 256)
        return
    for id, batch in QueueBatchStates {
        if (batch.State != "queued")
            QueueBatchStates.Delete(id)
        if (QueueBatchStates.Count() <= 128)
            break
    }
}

QueueRpAction(template, command, source, menu) {
    global SequenceLineDelay
    SplitConfigSequenceMiddle(template, before, after)
    lines := []
    Loop, Parse, before, `n, `r
        if (Trim(A_LoopField) != "")
            lines.Push(ApplyActionTemplate(A_LoopField))
    lines.Push(command)
    if (menu.Length())
        lines.Push({Kind: "Menu", Steps: menu})
    Loop, Parse, after, `n, `r
        if (Trim(A_LoopField) != "")
            lines.Push(ApplyActionTemplate(A_LoopField))
    return ChatQueue_EnqueueBatch(lines, source, SequenceLineDelay) ? true : false
}

SafeSend(keys, mode := "Input", epoch := "") {
    global MockMode
    if (epoch != "" && epoch != AutomationEpoch)
        return false
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[INPUT " . mode . "] " . keys)
        return true
    }
    if !GameLocator_IsActive()
        return false
    if (mode = "Event")
        SendEvent, %keys%
    else
        SendInput, %keys%
    return true
}

SafeLayout(layout) {
    global MockMode
    if (MockMode = "On" || AuditTestMode)
        return true
    if !GameLocator_IsActive()
        return false
    SendMessage, 0x50,, %layout%,, A
    return !ErrorLevel
}

ColorLuminance(color) {
    total := 0.0
    for index, weight in [0.2126, 0.7152, 0.0722] {
        component := HexToDec(SubStr(color, index * 2 - 1, 2)) / 255.0
        linear := component <= 0.04045 ? component / 12.92 : ((component + 0.055) / 1.055) ** 2.4
        total += weight * linear
    }
    return total
}

ColorContrast(first, second) {
    a := ColorLuminance(first), b := ColorLuminance(second)
    return (Max(a, b) + 0.05) / (Min(a, b) + 0.05)
}

EnsureTextContrast(color, surfaces, ratio := 4.5) {
    best := color, bestScore := 0
    for _, candidate in [color, "111418", "F4F6F8"] {
        score := 21.0
        for _, surface in surfaces
            score := Min(score, ColorContrast(candidate, surface))
        if (score >= ratio)
            return candidate
        if (score > bestScore)
            best := candidate, bestScore := score
    }
    return best
}

Capture_Supported() {
    VarSetCapacity(version, 284, 0)
    NumPut(284, version, 0, "UInt")
    return DllCall("ntdll\RtlGetVersion", "Ptr", &version) = 0 && NumGet(version, 4, "UInt") >= 10 && NumGet(version, 12, "UInt") >= 19041
}

Capture_ApplyWindow(hwnd) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return false
    enabled := OBSHideWindows = "On"
    if (enabled && !Capture_Supported()) {
        CaptureStatus := "Нужна Windows 10 2004 / Windows 11"
        return false
    }
    try {
        ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", enabled ? 0x11 : 0)
        if (!ok) {
            CaptureStatus := "Исключение захвата не применено (" . A_LastError . ")"
            return false
        }
        affinity := 0
        verified := DllCall("user32\GetWindowDisplayAffinity", "Ptr", hwnd, "UInt*", affinity)
        if (!verified || affinity != (enabled ? 0x11 : 0))
            return false
        CaptureWindowStates[hwnd] := {Enabled: enabled, Class: ""}
        CaptureStatus := enabled ? "Окна исключены из совместимого захвата" : "Отключено"
        return true
    } catch e {
        CaptureStatus := "Исключение захвата недоступно"
        return false
    }
}

Capture_RefreshWindows() {
    previous := A_DetectHiddenWindows
    DetectHiddenWindows, On
    process := DllCall("GetCurrentProcessId")
    WinGet, windows, List, ahk_pid %process%
    for hwnd, state in CaptureWindowStates {
        if !DllCall("IsWindow", "Ptr", hwnd)
            CaptureWindowStates.Delete(hwnd)
    }
    Loop % windows {
        hwnd := windows%A_Index%
        WinGetClass, class, ahk_id %hwnd%
        if (class != "AutoHotkeyGUI")
            continue
        expected := OBSHideWindows = "On"
        affinity := 0
        existing := DllCall("user32\GetWindowDisplayAffinity", "Ptr", hwnd, "UInt*", affinity)
        if (!CaptureWindowStates.HasKey(hwnd) || CaptureWindowStates[hwnd].Enabled != expected || (existing && affinity != (expected ? 0x11 : 0)))
            Capture_ApplyWindow(hwnd)
    }
    if (SettingsGui_CanUpdate())
        GuiControl, 2:, CaptureStatusText, %CaptureStatus%
    DetectHiddenWindows, %previous%
}

Settings_NormalizeViewport() {
    global SettingsX, SettingsY, SettingsW, SettingsH
    SysGet, monitors, MonitorCount
    SysGet, primary, MonitorPrimary
    selected := primary
    Loop % monitors {
        SysGet, area, MonitorWorkArea, %A_Index%
        if (SettingsX >= areaLeft && SettingsX < areaRight && SettingsY >= areaTop && SettingsY < areaBottom) {
            selected := A_Index
            break
        }
    }
    SysGet, area, MonitorWorkArea, %selected%
    SettingsW := Min(1180, Max(320, areaRight - areaLeft - 32))
    SettingsH := Min(800, Max(240, areaBottom - areaTop - 56))
    SettingsX := Max(areaLeft + 8, Min(SettingsX, areaRight - SettingsW - 24))
    SettingsY := Max(areaTop + 8, Min(SettingsY, areaBottom - SettingsH - 40))
}

Settings_UpdateScrollbars() {
    global hSettingsWnd
    if (!hSettingsWnd)
        return
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "Ptr", hSettingsWnd, "Ptr", &rect)
    width := NumGet(rect, 8, "Int"), height := NumGet(rect, 12, "Int")
    oldX := SettingsScrollX, oldY := SettingsScrollY
    SettingsScrollX := Max(0, Min(SettingsScrollX, 1180 - width))
    SettingsScrollY := Max(0, Min(SettingsScrollY, 800 - height))
    if (oldX != SettingsScrollX || oldY != SettingsScrollY)
        DllCall("ScrollWindowEx", "Ptr", hSettingsWnd, "Int", oldX - SettingsScrollX, "Int", oldY - SettingsScrollY, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 7)
    for axis, canvas in [1180, 800] {
        page := axis = 1 ? width : height
        offset := axis = 1 ? SettingsScrollX : SettingsScrollY
        VarSetCapacity(info, 28, 0)
        NumPut(28, info, 0, "UInt"), NumPut(7, info, 4, "UInt")
        NumPut(canvas - 1, info, 12, "Int"), NumPut(page, info, 16, "UInt"), NumPut(offset, info, 20, "Int")
        DllCall("SetScrollInfo", "Ptr", hSettingsWnd, "Int", axis - 1, "Ptr", &info, "Int", 1)
    }
}

Settings_ScrollMessage(wParam, lParam, message, hwnd) {
    global hSettingsWnd
    if (hwnd != hSettingsWnd || lParam)
        return
    axis := message = 0x115 ? 1 : 0
    old := axis ? SettingsScrollY : SettingsScrollX
    VarSetCapacity(info, 28, 0)
    NumPut(28, info, 0, "UInt"), NumPut(0x17, info, 4, "UInt")
    DllCall("GetScrollInfo", "Ptr", hwnd, "Int", axis, "Ptr", &info)
    maximum := Max(0, NumGet(info, 12, "Int") - NumGet(info, 16, "UInt") + 1)
    code := wParam & 0xFFFF
    next := old
    if (code = 0 || code = 1)
        next += code = 0 ? -36 : 36
    else if (code = 2 || code = 3)
        next += (code = 2 ? -1 : 1) * NumGet(info, 16, "UInt")
    else if (code = 4 || code = 5)
        next := NumGet(info, 24, "Int")
    else if (code = 6)
        next := 0
    else if (code = 7)
        next := maximum
    next := Max(0, Min(maximum, next))
    if (axis)
        SettingsScrollY := next
    else
        SettingsScrollX := next
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", axis ? 0 : old - next, "Int", axis ? old - next : 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 7)
    Settings_UpdateScrollbars()
    return 0
}

Settings_MouseWheel(wParam, lParam, message, hwnd) {
    global hSettingsWnd
    if (!hSettingsWnd || DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != hSettingsWnd)
        return
    ; Edits, lists and combo boxes retain their own wheel handling.
    WinGetClass, class, ahk_id %hwnd%
    if (class != "AutoHotkeyGUI")
        return
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 32767)
        delta -= 65536
    Loop % Max(1, Abs(delta) // 120)
        Settings_ScrollMessage(delta > 0 ? 0 : 1, 0, 0x115, hSettingsWnd)
    return 0
}

IsBindCatalogEntryEditable(meta) {
    return BindCatalog_IsUserVisible(meta)
}



LawSearch_CorpusFingerprint() {
    global LawSearchDocCatalog
    LawSearch_InitCatalog()
    signature := ""
    for _, doc in LawSearchDocCatalog {
        path := A_ScriptDir . "\laws\" . doc.FileName
        FileGetSize, size, %path%
        FileGetTime, modified, %path%, M
        signature .= doc.Code . ":" . (FileExist(path) ? size . ":" . modified . ":" . FileSHA256(path) : "missing") . "|"
    }
    return signature
}

LawSearch_QueryFilters(query) {
    phrases := [], excluded := [], searchText := query
    offset := 1
    while (found := RegExMatch(query, """([^""`r`n]+)""", match, offset)) {
        phrases.Push(LawSearch_Normalize(match1))
        offset := found + StrLen(match)
    }
    offset := 1
    while (found := RegExMatch(query, "(?:^|\s)-([A-Za-zА-Яа-яЁё0-9]+)", match, offset)) {
        excluded.Push(LawSearch_Normalize(match1))
        searchText := StrReplace(searchText, match, " ")
        offset := found + StrLen(match)
    }
    searchText := StrReplace(searchText, Chr(34), " ")
    return {Phrases: phrases, Excluded: excluded, SearchText: searchText}
}

Hotstring_AdmitPattern(pattern) {
    if HistoricalHotstrings.HasKey(pattern)
        return true
    if (HistoricalHotstringCount >= 512)
        return false
    HistoricalHotstrings[pattern] := true
    HistoricalHotstringCount++
    return true
}


JoinStrings(values, separator := ", ") {
    result := ""
    for _, value in values
        result .= (result = "" ? "" : separator) . value
    return result
}

ChatQueue_CancelBatch(id) {
    global ChatQueueItems
    kept := []
    for _, item in ChatQueueItems {
        if (!item.HasKey("Batch") || item.Batch != id)
            kept.Push(item)
    }
    ChatQueueItems := kept
    if QueueBatchStates.HasKey(id)
        QueueBatchStates[id].State := "cancelled"
}

ImageDimensionsBounded(path, ByRef width, ByRef height) {
    ; GDI+ opens metadata before creating a HBITMAP; reject untrusted decompression dimensions first.
    token := 0, image := 0, width := 0, height := 0
    VarSetCapacity(input, A_PtrSize = 8 ? 24 : 16, 0)
    NumPut(1, input, 0, "UInt")
    if DllCall("gdiplus\GdiplusStartup", "Ptr*", token, "Ptr", &input, "Ptr", 0)
        return false
    try {
        if DllCall("gdiplus\GdipLoadImageFromFile", "WStr", path, "Ptr*", image)
            return false
        if (DllCall("gdiplus\GdipGetImageWidth", "Ptr", image, "UInt*", width)
            || DllCall("gdiplus\GdipGetImageHeight", "Ptr", image, "UInt*", height))
            return false
        return width > 0 && height > 0 && width <= 4096 && height <= 4096
    } finally {
        if (image)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", image)
        DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
    }
}

QueueMenu_Run(item) {
    global MockMode
    if (item.Epoch != AutomationEpoch)
        return false
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[MENU] " . item.Source . " " . JoinStrings(item.Steps, " > "))
        return true
    }
    for _, digit in item.Steps {
        if !SafeSend("{" . digit . "}{" . digit . "}", "Input", item.Epoch)
            return false
        Sleep, 300
    }
    return item.Epoch = AutomationEpoch
}

LawSearchVocabulary_Build() {
    global SearchIndex
    vocabulary := {}
    for _, item in SearchIndex {
        for word, unused in item.AllTokens {
            if (StrLen(word) < 4 || RegExMatch(word, "^[0-9.]+$"))
                continue
            vocabulary[word] := vocabulary.HasKey(word) ? vocabulary[word] + 1 : 1
        }
    }
    LawSearchVocabulary := vocabulary
}

LawSearch_CorrectToken(word) {
    if (StrLen(word) < 5 || !IsObject(LawSearchVocabulary) || LawSearchVocabulary.HasKey(word))
        return word
    best := word, bestDistance := 2, bestFrequency := 0, candidates := 0
    for candidate, frequency in LawSearchVocabulary {
        if (SubStr(candidate, 1, 2) != SubStr(word, 1, 2) || Abs(StrLen(candidate) - StrLen(word)) > 1)
            continue
        candidates++
        if (candidates > 400)
            break
        distance := LawSearch_DamerauDistanceWithin(word, candidate, 1)
        if (distance >= 0 && (distance < bestDistance || (distance = bestDistance && frequency > bestFrequency))) {
            best := candidate, bestDistance := distance, bestFrequency := frequency
        }
    }
    return best
}

SendChatForEpoch(epoch, text, source := "Direct") {
    if (epoch != AutomationEpoch)
        return -1
    return SendChat(text, source)
}

PasteOnlyForEpoch(epoch, text) {
    if (epoch != AutomationEpoch)
        return false
    return PasteOnly(text)
}

ChatLogReader_CursorSignature(file, position) {
    if (position <= 0)
        return "start"
    savedPosition := file.Pos
    try {
        count := Min(64, position)
        file.Pos := position - count
        VarSetCapacity(anchor, count, 0)
        if (file.RawRead(anchor, count) != count)
            return ""
        signature := ""
        Loop %count%
            signature .= Format("{:02X}", NumGet(anchor, A_Index - 1, "UChar"))
        return signature
    } finally {
        file.Pos := savedPosition
    }
}
