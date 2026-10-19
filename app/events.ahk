; Event adapters and original contextual hotkeys.




























































































































































































































; Verified aimed targets use the original passive F1/F2 confirmation overlay.
; Another target replaces its text while RMB remains held.






























































































































































































































































































































































































































































































































































EnforceIndependentGuiState:
global SettingsTargetTab
ApplyPendingGuiState(SettingsTargetTab)
ClearPendingGuiStateValues()
return

















































































13GuiSize:
if (A_EventInfo = 1)
    return
ResizeBindListGui(A_GuiWidth, A_GuiHeight)
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
ServiceUI_ClearNotice()
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
        ServiceUI_Notify("Строка bind-листа скопирована в буфер обмена.", 1200)
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









































































HideStopDemandGUI:
Gui, 14:Destroy
return





























































































































































































































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
ServiceUI_ClearNotice()
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
    ServiceUI_Message("Ошибка", "Введите новое имя пресета в поле ""Тема"", затем снова нажмите сохранение.", "WARN")
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
    ServiceUI_Message("Ошибка", "Выберите встроенную тему или сохранённый пресет в поле ""Тема"".", "WARN")
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
    ServiceUI_Message("Ошибка", "Указанный пресет темы не найден. Сначала сохраните его или выберите существующий.", "WARN")
    return
}
if !LoadThemePreset(themeName)
{
    LogError("LoadThemePresetLabel", "Load failed: " . themeName)
    ServiceUI_Message("Ошибка", "Не удалось применить выбранный стиль.", "WARN")
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
    ServiceUI_Message("Ошибка", "Введи или выбери имя профиля.", "WARN")
    SetSettingsStatus("Профиль не выбран.")
    return
}
if !ProfileExists(targetProfile)
{
    ServiceUI_Message("Ошибка", "Такого профиля нет.", "WARN")
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
    ServiceUI_Message("Ошибка", "Введи имя нового профиля в поле сверху.", "WARN")
    SetSettingsStatus("Не указано имя нового профиля.")
    return
}
if ProfileExists(newProfile)
{
    ServiceUI_Message("Ошибка", "Профиль с таким именем уже существует. Используй «Сохранить».", "WARN")
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
    ServiceUI_Message("Ошибка", "Выбери профиль для удаления.", "WARN")
    return
}
if !ServiceUI_Confirm("Подтверждение", "Удалить профиль """ . CFG_ProfileName . """?")
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
    ServiceUI_Message("Ошибка", "Не удалось загрузить выбранный пресет темы.", "WARN")
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
if !ServiceUI_Confirm("Удаление функции", "Удалить выбранную пользовательскую функцию?")
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
ServiceUI_Shutdown()
Capture_ShutdownDialogHook()
IDCapture_Shutdown()
UIStyle_Shutdown()
SetTimer, ActionTimerTick, Off
Gui, ActionTimers:Destroy
TerritoryMap_CloseAll()
ReleaseGameHandle()
LogError("System", "Script exit: " . A_ExitReason, "INFO")
AppHost_Shutdown()
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
    ServiceUI_Message("Проверка azmp.dll", azmpDetails, "INFO")
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
childExit := 1
if (PendingToolHandle) {
    if (DllCall("GetExitCodeProcess", "Ptr", PendingToolHandle, "UInt*", childExit) && childExit = 259)
        return
} else {
    Process, Exist, %PendingToolPid%
    if (ErrorLevel)
        return
}
SetTimer, BackgroundToolPoll, Off
if (PendingToolHandle) {
    DllCall("CloseHandle", "Ptr", PendingToolHandle)
    PendingToolHandle := 0
}
if FileExist(PendingToolReport)
{
    completedReport := PendingToolReport
    AppHost_ShowReport(completedReport, childExit)
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
    if !SaveProfile(CurrentProfile) {
        AppExitInProgress := 0
        Critical, Off
        return
    }
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
ServiceUI_Shutdown()
Capture_ShutdownDialogHook()
SetTimer, StopTimerTick, Off
SetTimer, ActionTimerTick, Off
SetTimer, BackgroundToolPoll, Off
ServiceUI_ClearNotice()
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





















DoBindMenuToggle:
ToggleBindMenuEditMode()
return

DoGuideSignals:
Guide_Toggle(21, true)
return

DoGuidePDP:
Guide_Toggle(22, true)
return

DoGuideSVU:
Guide_Toggle(23, true)
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



DoOpenBindsTab:
if (SettingsVisible)
    Settings_SwitchPage(SettingsPageIndex("hotkeys_main"))
else
    OpenSettings("hotkeys_main")
return

DoMaskCall:
if !CanRunAction("маска и звонок", false, true)
    return
QueueNamedAction([{Text: "/mask", DelayAfter: 600}, {Text: "/call 97710514", DelayAfter: 600}
    , {Text: "/h", DelayAfter: 700}], "MaskCall")
return

DoRecordCheck:
if !CanRunAction("проверка записывающих устройств", false, true)
    return
QueueNamedAction([{Text: "/do У человека имеются при себе видео/аудио записывающие устройства?", Role: "RP", DelayAfter: 2000}
    , {Text: "/b Ответ в /do: Да./Нет.", DelayAfter: 700}], "RecordCheck")
return

DoTrainCrash:
ContextAssistant_Request("TrainCrash")
return

DoPersonalFile:
if !CanRunAction("личное дело", false, true)
    return
QueueNamedAction([{Text: "/me снял все предметы с лица гражданина, достал КПК", Role: "RP", DelayAfter: 2000}
    , {Text: "/me навел камеру КПК на лицо гражданина, сделал фоторобот", Role: "RP", DelayAfter: 2000}
    , {Text: "/me сделал запрос в базу данных МВД", Role: "RP", DelayAfter: 2000}
    , {Text: "/do Личное дело найдено.", Role: "RP", DelayAfter: 700}], "PersonalFile")
return

DoSu:
if !CanRunAction("корректировка розыска", true, true)
    return
QueueNamedAction([{Text: "/su " . UserID, DelayAfter: 500}
    , {Text: "/me достал КПК, авторизовался, ввел данные гражданина", Role: "RP", DelayAfter: 3000}
    , {Text: "/do Личное дело найдено.", Role: "RP", DelayAfter: 3000}
    , {Text: "/me начал вводить корректировки", Role: "RP", DelayAfter: 700}], "Su", Func("Action_SuReminderAfterSent").Bind(UserID))
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
Action_DoDeject()
return

DoCuff:
Action_DoCuff()
return

DoInCar:
Action_DoInCar()
return



DoStopChase:
if !CanRunAction("требование остановки", true, true, true)
    return
if !SendConfigSequence(RP_StopChase, 500, stopBatch, Func("Action_StartStopTimer"))
    SafeWarn("Требование остановки не поставлено в очередь. Таймер не запущен.")
return

DoDoc:
Action_DoDoc()
return



DoSearch:
Action_DoSearch()
return



DoSOS:
InputAction_DoSOS()
return



DoDep:
if !CanRunAction("/dep", false, false, false, true)
    return
SendTemplateOpen(T_Dep, 0)
return

DoWantedList:
InputAction_DoWantedList()
return



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
Action_DoTowStart()
return

DoTowEnd:
Action_DoTowEnd()
return

DoCarSearch:
Action_DoCarSearch()
return

DoArrest:
Action_DoArrest()
return



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

#If (ServiceCodesGuiVisible || current_doc >= 21)
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
if IsObject(Guide_GetMeta(last_doc)) {
    Guide_Toggle(last_doc)
    return
}
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
    if IsObject(Guide_GetMeta(current_doc)) {
        Guide_Navigate("prev")
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
    if IsObject(Guide_GetMeta(current_doc)) {
        Guide_Navigate("next")
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





MemoryRemotePollTimer:
MemoryRemotePoll()
return

CaptureRefreshTimer:
Capture_RefreshWindows()
return

SaveUiDebounced:
SaveUISettings()
return

DesktopSmokeLabel:
DesktopSmoke_Run()
return

DoPrivateTextInput:
PrivateText_Open()
return
