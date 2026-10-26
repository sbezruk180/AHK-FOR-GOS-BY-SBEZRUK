; core subsystem. Definitions only; initialization is in bootstrap.

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
        LogDir := AppHost_DataDir() . "\logs"
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
    if (val = "Через чат")
        val := "Окно ввода"
    if (val != "Перехват цифр" && val != "Окно ввода")
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
    ; Do not turn a malformed explicit hash into the blank legacy policy.
    val := RegExReplace(Trim(val), "\s+")
    StringUpper, val, val
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

UpdateLawGuiColors() {
    global LawGuiTextColor, LawGuiBgColor
    bg := "", panel := "", text := "", accent := "", muted := ""
    GetThemeColors(bg, panel, text, accent, muted)
    LawGuiBgColor := panel
    LawGuiTextColor := text
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
    global ChatWizardMode, ChatWizardPrompt
    if (ChatWizardMode != "")
        ChatWizardPrompt := message
    return ServiceUI_Notify(message, 6000, level)
}

GameInterface_ShowDialog(caption, text, style := 0, button1 := "OK", button2 := "", id := 32000) {
    return ServiceUI_ShowDetails(caption, text)
}

SafeWarn(msg) {
    global SafeTooltipWarnings
    Notify("warn")
    if (SafeTooltipWarnings = "On")
    {
        ServiceUI_Notify(msg, 1600)
    }
    return false
}

SetDynamicGlobalValue(varName, newValue) {
    global
    if (varName = "")
        return
    %varName% := newValue
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

EraseGpsTypedCommand(triggerText, gpsNumber, endKey := "space", inputEpoch := 0) {
    if (!inputEpoch)
        inputEpoch := AutomationEpoch
    if (inputEpoch != AutomationEpoch)
        return false
    eraseCount := StrLen(triggerText) + StrLen(gpsNumber)
    if (endKey = "space")
        eraseCount += 1
    if (eraseCount <= 0)
        return
    Loop, %eraseCount%
    {
        if !SafeSend("{BS}", "Input", inputEpoch)
            return false
        Sleep, 10
    }
    return inputEpoch = AutomationEpoch
}

GetTargetFullLabel() {
    global UserID, ActiveID, TargetNickname, TargetIsMask
    if (!ActiveID || UserID = "")
        return "Цель не выбрана"
    if (TargetIsMask)
        return "Маска " . UserID
    return "ID " . UserID . (TargetNickname != "" ? " (" . TargetNickname . ")" : "")
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

UpdateAutomationSettingsStatus() {
    global SafeModeEnabled, MockMode, CFG_AutoReportStatus, SettingsGuiReady
    if !SettingsGui_CanUpdate()
        return
    queueText := "Очередь: " . ChatQueue_StatusText()
    taskText := "Задачи: " . TaskScheduler_StatusText()
    safeText := "SafeMode: " . SafeModeEnabled . "   |   MockMode: " . MockMode . "   |   Чат: " . ChatTransport_GetDisplayStatus()
    try
    {
        UIStyle_SetTextIfChanged("2", "CFG_AutomationQueueStatus", queueText)
        UIStyle_SetTextIfChanged("2", "CFG_AutomationTaskStatus", taskText)
        UIStyle_SetTextIfChanged("2", "CFG_AutomationSafeStatus", safeText)
        CFG_AutoReportStatus := AutoReport_GetStatusText()
        UIStyle_SetTextIfChanged("2", "CFG_AutoReportStatus", CFG_AutoReportStatus)
    }
    catch e
        SettingsGuiReady := 0
}

RunBackgroundTool(argName, reportName) {
    global PendingToolPid, PendingToolReport, PendingToolHandle
    if (PendingToolPid)
    {
        ServiceUI_Notify("Проверка уже выполняется.", 1400)
        return false
    }
    reportPath := AppHost_DataDir() . "\" . reportName
    if FileExist(reportPath) {
        try {
            FileDelete, %reportPath%
        } catch deleteError {
            return false
        }
        if FileExist(reportPath)
            return false
    }
    q := Chr(34)
    cmd := A_IsCompiled ? q . A_ScriptFullPath . q . " " . argName
        : q . A_AhkPath . q . " /CP1251 " . q . A_ScriptFullPath . q . " " . argName
    cmd .= " --data-dir " . q . AppHost_DataDir() . q
    if !AppHost_SpawnDiagnostic(cmd, processHandle, childPid)
        return false
    PendingToolHandle := processHandle
    PendingToolPid := childPid
    PendingToolReport := AppHost_DataDir() . "\" . reportName
    SetTimer, BackgroundToolPoll, 500
    return true
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

NormalizeSettingsPage(ByRef pageId) {
    pageId := Trim(pageId)
    pages := GetSettingsPageCatalog()
    Loop % pages.Length()
        if (pages[A_Index].Id = pageId)
            return
    pageId := "profile"
}

ExtractFirstNumber(text) {
    text := Trim(text)
    if RegExMatch(text, "(\d+)", m)
        return m1
    return ""
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
