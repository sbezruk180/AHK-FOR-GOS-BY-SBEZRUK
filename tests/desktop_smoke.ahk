; Explicit opt-in integration probe. Use a disposable --data-dir.
; Production functions/UI run in MockMode; no game actions or memory writes.
DesktopSmoke_Run() {
    global
    DesktopSmokeReport := "Desktop integration probe`r`nRuntime=" . A_AhkVersion . " | Unicode=" . A_IsUnicode . " | PtrSize=" . A_PtrSize . "`r`n"
    DesktopSmokeReport .= "Compiled=" . A_IsCompiled . " | Data=" . AppHost_DataDir() . "`r`nNo real game or OBS verification.`r`n"
    DesktopSmokeChecks := 0, DesktopSmokeFailures := 0
    DesktopSmoke_Memory("startup")
    try {
        MockMode := "On"
        DesktopSmoke_Assert("compiled standalone host", A_IsCompiled)
        DesktopSmoke_Assert("application mutex acquired", AcquireAppInstance())
        otherHandle := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Local\AMZ_GOS_SBEZRUK_RUNTIME_V3", "Ptr")
        alreadyExists := A_LastError = 183
        if (otherHandle)
            DllCall("CloseHandle", "Ptr", otherHandle)
        DesktopSmoke_Assert("duplicate application mutex detected", alreadyExists)
        DesktopSmoke_Assert("first startup creates compatible INI", FileExist(ConfigFile) && CurrentProfile != "")
        IniRead, schema, %ConfigFile%, Meta, ConfigVersion, 0
        DesktopSmoke_Assert("configuration schema 14", schema = 14)
        ApplyAllBinds()
        DesktopSmoke_Assert("hotkeys really registered", IsObject(RegisteredBindHotkeys) && RegisteredBindHotkeys.Length() >= 5)
        catalog := GetBindCatalog()
        labelsOK := V1_CheckCatalog(catalogDetails)
        DesktopSmoke_Assert("all catalog handlers including direct UI/GPS dispatch", labelsOK)
        OpenSettings("profile")
        pages := GetSettingsPageCatalog()
        for index, page in pages {
            switched := Settings_SwitchPage(index)
            DesktopSmoke_Assert("settings page " . page.Id, switched && SettingsPage = page.Id && DllCall("IsWindow", "Ptr", hSettingsWnd))
        }
        DesktopSmoke_Assert("settings catalog keeps all 13 pages", pages.Length() = 13)
        CreateHUD()
        UpdateHUD()
        DesktopSmoke_Assert("native HUD exists", DllCall("IsWindow", "Ptr", hHUDWnd))
        CreateBindList()
        UpdateBindList()
        DesktopSmoke_Assert("native bind list exists", DllCall("IsWindow", "Ptr", hBindListWnd))
        unknownSection := "DesktopCompatibility"
        CheckedIniWrite("keep-me", ConfigFile, unknownSection, "UnknownKey")
        expectedRole := "Должность проверки"
        IntroRole := expectedRole
        Bind_Intro := "^!8"
        Trig_Intro := "!desktopcheck"
        DesktopSmoke_Assert("actual atomic profile save", SaveProfile(CurrentProfile))
        IntroRole := "changed", Bind_Intro := "", Trig_Intro := ""
        LoadProfile(CurrentProfile)
        DesktopSmoke_Assert("identity and binds survive profile reload", IntroRole = expectedRole && Bind_Intro = "^!8" && Trig_Intro = "!desktopcheck")
        IniRead, unknown, %ConfigFile%, %unknownSection%, UnknownKey, missing
        DesktopSmoke_Assert("profile save preserves unknown keys", unknown = "keep-me")
        MockMode := "On"
        ChatQueueItems := [], ChatQueueNextSendTick := 0, ChatQueueLastSendTick := 0
        ChatQueue_Enqueue("/r Desktop smoke", "desktop-smoke")
        ChatQueue_Tick()
        DesktopSmoke_Assert("real queue reaches mock transport", InStr(ChatQueuePreviewText, "/r Desktop smoke"))
        CustomFunctions := [CreateDefaultCustomFunction()]
        CustomFunctions[1].Name := "Проверка сохранения"
        CustomFunctions[1].Script := "SEND /r Проверка`nWAIT 100`nNOTICE Готово"
        DesktopSmoke_Assert("custom function persistence", SaveCustomFunctions())
        LoadCustomFunctions()
        steps := CustomFunction_Parse(CustomFunctions[1].Script, parseError)
        DesktopSmoke_Assert("custom function reload and parser", CustomFunctions[1].Name = "Проверка сохранения" && parseError = "" && steps.Length() = 3)
        audit := LawCorpus_Audit()
        DesktopSmoke_Assert("20 documents available without external laws folder", audit.Ok && audit.Documents = 20 && !FileExist(A_ScriptDir . "\laws"))
        ToggleLawDoc(5, "flter1", "ter1")
        DesktopSmoke_Assert("native legislation viewer opens", current_doc = 5)
        CloseAllDocs()
        AutoTargetOfferedKey := ""
        AutoTargetID_RequestConfirmation(42, 0x200000, -1, "desktop-smoke", "First_Player")
        promptWindow := hContextAssistantWnd
        AutoTargetID_RequestConfirmation(43, 0x300000, -1, "desktop-smoke", "Second_Player")
        DesktopSmoke_Assert("auto ID updates existing native confirmation", promptWindow && hContextAssistantWnd = promptWindow && ContextAssistantInput = 43)
        DesktopSmoke_Assert("confirmation applies the displayed ID", ContextAssistant_Submit() && UserID = 43)
        AutoTargetOfferedKey := ""
        AutoTargetID_RequestConfirmation(44, 0x400000, -1, "desktop-smoke", "Third_Player")
        ContextAssistant_Close()
        DesktopSmoke_Assert("confirmation decline preserves selection", UserID = 43)
        CancelAllAutomation(0)
        DesktopSmoke_Assert("cancellation drains pending work", ChatQueue_Count() = 0 && TaskScheduler_Count() = 0)
        launched := RunBackgroundTool("--runtime-info", "runtime_info_report.txt")
        DesktopSmoke_Assert("diagnostic launch returns owned process HANDLE", launched && PendingToolHandle)
        started := A_TickCount
        while (PendingToolPid && A_TickCount - started < 8000)
            Sleep, 40
        childReport := AppHost_DataDir() . "\runtime_info_report.txt"
        DesktopSmoke_Assert("same-EXE diagnostic finishes in custom data directory", !PendingToolPid && FileExist(childReport))
        DesktopSmoke_Assert("diagnostic does not replace parent instance", DllCall("IsWindow", "Ptr", A_ScriptHwnd))
        DesktopSmoke_Assert("diagnostic report opens in own application GUI", ServiceUIDetailsHwnd && DllCall("IsWindow", "Ptr", ServiceUIDetailsHwnd))
        CloseSettings()
        DesktopSmoke_Assert("closing settings destroys its native window", !hSettingsWnd)
    } catch error {
        DesktopSmoke_Assert("unhandled exception: " . error.Message . " | " . error.What . " | " . error.Line, false)
    }
    DesktopSmoke_Memory("after native smoke")
    DesktopSmokeReport .= "Checks=" . DesktopSmokeChecks . " | Failed=" . DesktopSmokeFailures . "`r`n"
    report := AppHost_DataDir() . "\desktop_smoke_report.txt"
    FileDelete, %report%
    FileAppend, %DesktopSmokeReport%, %report%, UTF-8
    ExitApp, %DesktopSmokeFailures%
}

DesktopSmoke_Assert(name, ok) {
    global DesktopSmokeReport, DesktopSmokeChecks, DesktopSmokeFailures
    DesktopSmokeChecks++
    if !ok
        DesktopSmokeFailures++
    DesktopSmokeReport .= (ok ? "PASS" : "FAIL") . " | " . name . "`r`n"
}


DesktopSmoke_Memory(stage) {
    global DesktopSmokeReport
    bytes := A_PtrSize = 8 ? 80 : 44
    VarSetCapacity(info, bytes, 0)
    NumPut(bytes, info, 0, "UInt")
    if DllCall("psapi\GetProcessMemoryInfo", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "Ptr", &info, "UInt", bytes) {
        working := NumGet(info, 8 + A_PtrSize, "UPtr")
        peak := NumGet(info, 8, "UPtr")
        DesktopSmokeReport .= "INFO | " . stage . " WorkingSetMiB=" . Round(working / 1048576, 2) . " PeakMiB=" . Round(peak / 1048576, 2) . "`r`n"
    }
}
