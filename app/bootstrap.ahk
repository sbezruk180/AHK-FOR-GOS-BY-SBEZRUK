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
Capture_InstallDialogHook()
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
SetTimer, AutoTargetIDTick, 30
if HasCommandLineArg("--desktop-smoke")
    SetTimer, DesktopSmokeLabel, -150
LogError("System", "Script start", "INFO")
return

