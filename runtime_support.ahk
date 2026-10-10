global SettingsPageExtents := {}
global SettingsPageFrames := {}
global SettingsBuildingPage := 0
global SettingsCanvasHeight := 800
global SettingsScale := 1
global LawSearchVocabulary := {}
; Shared runtime contracts for AutoHotkey v1.1 ANSI x86.
global QueueBatchStates := {}
global QueueBatchNextId := 0
global QueueFailureGeneration := 0
global AutoReportAcceptedCount := 0
global ChatLogReaderIdentity := ""
global ChatLogCursorSignature := ""
global ChatLogReaderDroppingLine := 0
global CaptureStatus := "Защита захвата выключена"
global CaptureLastError := 0
global CaptureDiagnostics := {}
global CaptureRefreshBusy := 0
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
    if IsObject(IDCaptureState)
        return false
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

Capture_GetEnvironment() {
    result := {Supported: false, Composition: false, Version: "", Error: 0, Reason: ""}
    try {
        VarSetCapacity(version, 284, 0)
        NumPut(284, version, 0, "UInt")
        code := DllCall("ntdll\RtlGetVersion", "Ptr", &version, "Int")
        if (code != 0) {
            result.Error := code
            result.Reason := "Не удалось определить версию Windows"
            return result
        }
        major := NumGet(version, 4, "UInt")
        minor := NumGet(version, 8, "UInt")
        build := NumGet(version, 12, "UInt")
        result.Version := major . "." . minor . "." . build
        result.Supported := major > 10 || (major = 10 && build >= 19041)
        if (!result.Supported) {
            result.Reason := "Нужна Windows 10 2004 / Windows 11"
            return result
        }
        composition := 0
        code := DllCall("dwmapi\DwmIsCompositionEnabled", "Int*", composition, "Int")
        result.Composition := code = 0 && composition
        if (!result.Composition) {
            result.Error := code
            result.Reason := "Защита захвата недоступна: DWM выключен"
        }
    } catch e {
        result.Error := -1
        result.Reason := "API защиты захвата недоступен"
    }
    return result
}

Capture_Supported() {
    environment := Capture_GetEnvironment()
    return environment.Supported && environment.Composition
}

Capture_IsOwnGui(hwnd) {
    if (!hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd))
        return false
    ownerProcess := 0
    DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", ownerProcess)
    if (ownerProcess != DllCall("kernel32\GetCurrentProcessId", "UInt"))
        return false
    if (DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != hwnd)
        return false
    ; Native class lookup also sees a just-created, still-hidden GUI.
    VarSetCapacity(className, 256, 0)
    length := DllCall("user32\GetClassNameA", "Ptr", hwnd, "Ptr", &className, "Int", 256, "Int")
    return length && StrGet(&className, length, "CP0") = "AutoHotkeyGUI"
}

Capture_ReadAffinity(hwnd, ByRef affinity, ByRef lastError) {
    affinity := 0
    lastError := 0
    try {
        DllCall("kernel32\SetLastError", "UInt", 0)
        verified := DllCall("user32\GetWindowDisplayAffinity", "Ptr", hwnd, "UInt*", affinity, "Int")
        lastError := verified ? 0 : A_LastError
        return !!verified
    } catch e {
        lastError := -1
        return false
    }
}

Capture_AffinityMatches(enabled, verified, affinity) {
    ; A failed read must never be treated as confirmation of cached success.
    return !!verified && affinity = (enabled ? 0x11 : 0)
}

Capture_ShouldRetry(state, enabled, now) {
    return !IsObject(state) || state.Enabled != enabled || now >= state.NextRetry
}

Capture_BeforeShow(guiName) {
    ; Resolve the named GUI while hidden, before its first visible frame.
    if (guiName = "")
        return false
    Gui, %guiName%:+HwndcaptureHwnd
    UI_PrepareWindow(captureHwnd)
    return Capture_ApplyWindow(captureHwnd)
}

Capture_ApplyWindow(hwnd, environment := "") {
    if (!Capture_IsOwnGui(hwnd))
        return false
    enabled := OBSHideWindows = "On"
    now := TickNow()
    state := {Enabled: enabled, Verified: false, Affinity: 0, Error: 0, Reason: "", LastChecked: now, NextRetry: now + 2000}
    if (enabled) {
        if (!IsObject(environment))
            environment := Capture_GetEnvironment()
        if (!environment.Supported || !environment.Composition) {
            state.Error := environment.Error
            state.Reason := environment.Reason
            CaptureWindowStates[hwnd] := state
            CaptureStatus := state.Reason
            return false
        }
    }
    try {
        DllCall("kernel32\SetLastError", "UInt", 0)
        ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", enabled ? 0x11 : 0, "Int")
        lastError := ok ? 0 : A_LastError
        if (!ok) {
            state.Error := lastError
            state.Reason := "SetWindowDisplayAffinity"
        } else {
            verified := Capture_ReadAffinity(hwnd, affinity, lastError)
            state.Affinity := affinity
            state.Verified := Capture_AffinityMatches(enabled, verified, affinity)
            if (!state.Verified) {
                state.Error := lastError
                state.Reason := verified ? "Windows вернула другой флаг захвата" : "GetWindowDisplayAffinity"
            } else {
                state.NextRetry := 0
            }
        }
    } catch e {
        state.Error := -1
        state.Reason := "API защиты захвата недоступен"
    }
    CaptureWindowStates[hwnd] := state
    if (state.Verified)
        CaptureStatus := enabled ? "Флаг защиты Windows подтверждён. Проверьте OBS." : "Защита захвата выключена"
    else
        CaptureStatus := "Защита не подтверждена: " . state.Reason . " (" . state.Error . ")"
    return state.Verified
}

Capture_RefreshWindows() {
    if (CaptureRefreshBusy)
        return
    CaptureRefreshBusy := 1
    previous := A_DetectHiddenWindows
    enabled := OBSHideWindows = "On"
    environment := enabled ? Capture_GetEnvironment() : {Supported: true, Composition: true, Version: "", Error: 0, Reason: ""}
    total := 0, confirmed := 0, failed := 0, lastError := 0, lastReason := ""
    now := TickNow()
    try {
        DetectHiddenWindows, On
        process := DllCall("kernel32\GetCurrentProcessId", "UInt")
        WinGet, windows, List, ahk_pid %process%
        expired := []
        for hwnd, state in CaptureWindowStates {
            if (!Capture_IsOwnGui(hwnd))
                expired.Push(hwnd)
        }
        ; Deleting during object enumeration can skip the following HWND.
        for _, hwnd in expired
            CaptureWindowStates.Delete(hwnd)
        Loop % windows {
            hwnd := windows%A_Index%
            if (!Capture_IsOwnGui(hwnd))
                continue
            total++
            state := CaptureWindowStates.HasKey(hwnd) ? CaptureWindowStates[hwnd] : ""
            if (enabled && (!environment.Supported || !environment.Composition)) {
                CaptureWindowStates[hwnd] := {Enabled: enabled, Verified: false, Affinity: 0, Error: environment.Error, Reason: environment.Reason, LastChecked: now, NextRetry: now + 2000}
                failed++
                lastError := environment.Error
                lastReason := environment.Reason
                continue
            }
            verified := Capture_ReadAffinity(hwnd, affinity, readError)
            if (Capture_AffinityMatches(enabled, verified, affinity)) {
                CaptureWindowStates[hwnd] := {Enabled: enabled, Verified: true, Affinity: affinity, Error: 0, Reason: "", LastChecked: now, NextRetry: 0}
                confirmed++
                continue
            }
            if (Capture_ShouldRetry(state, enabled, now))
                Capture_ApplyWindow(hwnd, environment)
            else {
                ; Remember a failed current read even when the retry is throttled.
                state.Verified := false
                state.Affinity := affinity
                state.Error := readError
                state.Reason := verified ? "Windows вернула другой флаг захвата" : "GetWindowDisplayAffinity"
                state.LastChecked := now
                CaptureWindowStates[hwnd] := state
            }
            state := CaptureWindowStates[hwnd]
            if (state.Verified)
                confirmed++
            else {
                failed++
                lastError := state.Error
                lastReason := state.Reason
            }
        }
        CaptureLastError := lastError
        CaptureDiagnostics := {Enabled: enabled, Windows: total, Confirmed: confirmed, Failed: failed, Version: environment.Version, Supported: environment.Supported, Composition: environment.Composition, Error: lastError, Reason: lastReason}
        if (enabled && (!environment.Supported || !environment.Composition))
            CaptureStatus := environment.Reason
        else if (!total)
            CaptureStatus := enabled ? "Защита включена; ожидается создание окна" : "Защита захвата выключена"
        else if (failed)
            CaptureStatus := "Windows: " . confirmed . "/" . total . " окон подтверждено; ошибка " . lastError . "."
        else if (enabled)
            CaptureStatus := "Windows: защита подтверждена для " . confirmed . " окон. Проверьте OBS."
        else
            CaptureStatus := "Защита захвата выключена"
        if (SettingsGui_CanUpdate())
            GuiControl, 2:, CaptureStatusText, %CaptureStatus%
    } finally {
        DetectHiddenWindows, %previous%
        CaptureRefreshBusy := 0
    }
}

Capture_GetDiagnosticsText() {
    state := CaptureDiagnostics
    if (!IsObject(state) || !state.HasKey("Windows"))
        return "Защита захвата: состояние ещё не проверено."
    text := "Защита захвата: " . CaptureStatus
    text .= "`r`nWindows=" . state.Version . "; On=" . state.Enabled . "; DWM=" . state.Composition
    text .= "; окон=" . state.Windows . "; подтверждено=" . state.Confirmed . "; ошибки=" . state.Failed
    text .= "; API=" . state.Reason . "; код=" . state.Error
    text .= "`r`nПроверка подтверждает флаг Windows, а не результат в OBS."
    text .= "`r`nПроверьте запись выбранного источника OBS. BitBlt и сторонний захват могут не учитывать исключение."
    return text
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
    SettingsW := Min(Round(1180 * A_ScreenDPI / 96.0), Max(320, areaRight - areaLeft - 32))
    SettingsH := Min(Round(800 * A_ScreenDPI / 96.0), Max(240, areaBottom - areaTop - 56))
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
    SettingsScrollX := Max(0, Min(SettingsScrollX, Round(1180 * SettingsScale) - width))
    SettingsScrollY := Max(0, Min(SettingsScrollY, Round(SettingsCanvasHeight * SettingsScale) - height))
    if (oldX != SettingsScrollX || oldY != SettingsScrollY)
        DllCall("ScrollWindowEx", "Ptr", hSettingsWnd, "Int", oldX - SettingsScrollX, "Int", oldY - SettingsScrollY, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 7)
    for axis, canvas in [Round(1180 * SettingsScale), Round(SettingsCanvasHeight * SettingsScale)] {
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
    if (item.Epoch != AutomationEpoch || IsObject(IDCaptureState) || PhysicalInputBusy)
        return false
    if (MockMode = "On" || AuditTestMode) {
        MockPreview_Append("[MENU] " . item.Source . " " . JoinStrings(item.Steps, " > "))
        return true
    }
    previous := A_IsCritical
    Critical, On
    if (PhysicalInputBusy || IsObject(IDCaptureState) || !GameLocator_IsActive()) {
        Critical, %previous%
        return false
    }
    PhysicalInputBusy := 1
    ownerHwnd := WinExist("A")
    Critical, %previous%
    try {
        for _, digit in item.Steps {
            if (WinExist("A") != ownerHwnd || !SafeSend("{" . digit . "}{" . digit . "}", "Input", item.Epoch))
                return false
            Sleep, 300
        }
        return item.Epoch = AutomationEpoch && WinExist("A") = ownerHwnd
    } finally {
        PhysicalInputBusy := 0
    }
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

Settings_RecordExtent(bottom) {
    if (!SettingsBuildingPage)
        return
    old := SettingsPageExtents.HasKey(SettingsBuildingPage) ? SettingsPageExtents[SettingsBuildingPage] : 0
    SettingsPageExtents[SettingsBuildingPage] := Max(old, bottom)
}

Settings_ResetScroll() {
    global hSettingsWnd
    if (hSettingsWnd && (SettingsScrollX || SettingsScrollY))
        DllCall("ScrollWindowEx", "Ptr", hSettingsWnd, "Int", SettingsScrollX, "Int", SettingsScrollY, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 7)
    SettingsScrollX := 0, SettingsScrollY := 0
}

Settings_ActivateLayout(page) {
    SettingsCanvasHeight := Max(800, (SettingsPageExtents.HasKey(page) ? SettingsPageExtents[page] : 740) + 60)
    footerY := SettingsCanvasHeight - 28
    borderY := SettingsCanvasHeight - 4
    GuiControl, 2:Move, SettingsStatusText, y%footerY%
    GuiControl, 2:Move, SettingsOwnerText, y%footerY%
    GuiControl, 2:Move, SettingsBorderBottom, y%borderY%
    if SettingsPageFrames.HasKey(page) {
        frame := SettingsPageFrames[page]
        height := SettingsCanvasHeight - frame.Y - 44
        bottom := frame.Y + height - frame.Border
        GuiControl, 2:Move, % frame.Fill, h%height%
        GuiControl, 2:Move, % frame.Left, h%height%
        GuiControl, 2:Move, % frame.Right, h%height%
        GuiControl, 2:Move, % frame.Bottom, y%bottom%
        ApplyRoundedCorners(frame.Fill, InnerRoundness)
    }
    Settings_UpdateScrollbars()
}

UI_MeasureTextHeight(text, logicalWidth, pointSize := 9, bold := false) {
    scale := A_ScreenDPI / 96.0
    dc := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!dc)
        return 48
    font := DllCall("CreateFontA", "Int", -Round(pointSize * A_ScreenDPI / 72), "Int", 0, "Int", 0, "Int", 0, "Int", bold ? 700 : 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "AStr", "Segoe UI", "Ptr")
    previous := font ? DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr") : 0
    try {
        VarSetCapacity(rect, 16, 0)
        NumPut(Round(logicalWidth * scale), rect, 8, "Int")
        count := StrPut(text, "UTF-16")
        VarSetCapacity(buffer, count * 2, 0)
        StrPut(text, &buffer, count, "UTF-16")
        DllCall("DrawTextW", "Ptr", dc, "Ptr", &buffer, "Int", count - 1, "Ptr", &rect, "UInt", 0x400 | 0x10 | 0x800)
        return Ceil(NumGet(rect, 12, "Int") / scale) + 6
    } finally {
        if (previous)
            DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
        if (font)
            DllCall("DeleteObject", "Ptr", font)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", dc)
    }
}

UI_PrepareWindow(hwnd) {
    ; A nonexistent theme name disables themed painting without resetting it to
    ; the system default. Empty strings can restore the blue progress theme.
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return
    oldHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    try {
        WinGet, children, ControlListHwnd, ahk_id %hwnd%
        Loop, Parse, children, `n, `r
        {
            child := A_LoopField + 0
            VarSetCapacity(className, 128, 0)
            length := DllCall("GetClassNameW", "Ptr", child, "Ptr", &className, "Int", 64, "Int")
            if (length > 0 && StrGet(&className, length, "UTF-16") = "msctls_progress32")
                try DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ", "Int")
        }
    } finally {
        DetectHiddenWindows, %oldHidden%
    }
}
