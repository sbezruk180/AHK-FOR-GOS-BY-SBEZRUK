; profiles subsystem. Definitions only; initialization is in bootstrap.

CreateConfigBackup(reason := "save", force := 0) {
    global ConfigFile, ProfileSaveBackups

    if (!force && ProfileSaveBackups != "On")
        return ""
    if !FileExist(ConfigFile)
    {
        LogError("CreateConfigBackup", "Config file not found: " . ConfigFile)
        return ""
    }

    backupDir := AppHost_DataDir() . "\backups"
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
    IniRead, BackgroundImageURL, %fileName%, UI, BackgroundImageURL, %A_Space%
    BackgroundImageURL := Trim(BackgroundImageURL)
    IniRead, TextTriggerInputMode, %fileName%, UI, TextTriggerInputMode, Игровой чат
    PrivateText_NormalizeMode(TextTriggerInputMode)
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
    IniRead, ChatTypingSpeedMode, %fileName%, UI, ChatTypingSpeedMode, Fixed
    IniRead, ChatTypingMinCPS, %fileName%, UI, ChatTypingMinCPS, 20
    IniRead, ChatTypingMaxCPS, %fileName%, UI, ChatTypingMaxCPS, 40
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
    ChatTyping_NormalizeSpeedConfig(ChatTypingSpeedMode, ChatTypingMinCPS, ChatTypingMaxCPS)
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
    CheckedIniWrite(TextTriggerInputMode, fileName, "UI", "TextTriggerInputMode")
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
    CheckedIniWrite(ChatTypingSpeedMode, fileName, "UI", "ChatTypingSpeedMode")
    CheckedIniWrite(ChatTypingMinCPS, fileName, "UI", "ChatTypingMinCPS")
    CheckedIniWrite(ChatTypingMaxCPS, fileName, "UI", "ChatTypingMaxCPS")
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
        ServiceUI_Message("Ошибка", "Не задан путь к основному INI-файлу.", "WARN")
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
    defaults["Bind_TextCommandInput"] := "!t"
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
    defaultName := AppHost_DataDir() . "\profiles_export.ini"
    FileSelectFile, outPath, S16, %defaultName%, Экспорт профилей, INI Files (*.ini)
    if (outPath = "")
        return -1
    if !CopyIniFileWithOverwrite(ConfigFile, outPath, "ExportProfilesPack")
    {
        ServiceUI_Message("Ошибка", "Не удалось экспортировать профили.", "WARN")
        return 0
    }
    ServiceUI_Message("Готово", "Профили экспортированы.", "INFO")
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
        ServiceUI_Message("Ошибка", "Файл профилей не найден.", "WARN")
        return 0
    }
    if !ValidateProfilesImportFile(inPath, importErr)
    {
        LogError("ImportProfilesPack", "Validation failed: " . importErr)
        ServiceUI_Message("Ошибка", importErr, "WARN")
        return 0
    }
    CreateConfigBackup("profiles_import")
    if !CopyIniFileWithOverwrite(inPath, ConfigFile, "ImportProfilesPack")
    {
        ServiceUI_Message("Ошибка", "Не удалось импортировать профили.", "WARN")
        return 0
    }
    RefreshAfterProfilesImport()
    ServiceUI_Message("Готово", "Профили импортированы.", "INFO")
    return 1
}

ExportThemeToFile() {
    defaultName := AppHost_DataDir() . "\theme_export.ini"
    FileSelectFile, outPath, S16, %defaultName%, Экспорт темы, INI Files (*.ini)
    if (outPath = "")
        return
    if !WriteCurrentThemeToFile(outPath, "Theme_Export")
    {
        LogError("ExportThemeToFile", "Write failed: " . outPath)
        ServiceUI_Message("Ошибка", "Не удалось экспортировать тему.", "WARN")
        return
    }
    ServiceUI_Message("Готово", "Тема экспортирована.", "INFO")
}

ImportThemeFromExternalFile() {
    FileSelectFile, inPath, 3,, Импорт темы, INI Files (*.ini)
    if (inPath = "")
        return
    if !FileExist(inPath)
    {
        LogError("ImportThemeFromExternalFile", "Selected file not found: " . inPath)
        ServiceUI_Message("Ошибка", "Файл темы не найден.", "WARN")
        return
    }
    if !LoadThemeFromFile(inPath, "Theme_Export")
    {
        LogError("ImportThemeFromExternalFile", "Load failed: " . inPath)
        ServiceUI_Message("Ошибка", "Не удалось импортировать тему.", "WARN")
        return
    }
    RefreshAfterThemeImport()
    ServiceUI_Message("Готово", "Тема импортирована.", "INFO")
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
    IniRead, Bind_TextCommandInput, %ConfigFile%, %section%, Bind_TextCommandInput, !t
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
    Guide_LoadProfile(ConfigFile, section)

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
        ServiceUI_Message("Ошибка", "Нельзя удалить единственный профиль.", "WARN")
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
