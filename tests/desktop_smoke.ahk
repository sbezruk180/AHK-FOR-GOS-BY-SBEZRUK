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
        DesktopSmoke_Assert("violet navigation blend uses real hex channels", UIStyle_BlendColors("845EFF", "161A29", 0.19) = "2B2752")
        savedFullscreen := FullscreenSafeGui
        FullscreenSafeGui := "On"
        Gui, FocusProbe:New, +HwndfocusProbeWindow -Caption +ToolWindow
        Gui, FocusProbe:Show, x650 y420 w260 h60, Foreground fixture
        WinActivate, ahk_id %focusProbeWindow%
        OpenSettings("profile")
        DesktopSmoke_Assert("fullscreen-safe settings preserve foreground", DllCall("GetForegroundWindow", "Ptr") = focusProbeWindow)
        pages := GetSettingsPageCatalog()
        for index, page in pages {
            switched := Settings_SwitchPage(index)
            DesktopSmoke_Assert("settings page " . page.Id, switched && SettingsPage = page.Id && DllCall("IsWindow", "Ptr", hSettingsWnd))
            clicked := Settings_NavClick(SettingsNavigationButtons[index])
            DesktopSmoke_Assert("sidebar button dispatch " . page.Id, clicked && SettingsPage = page.Id)
            DesktopSmoke_Assert("interactive controls do not overlap " . page.Id, DesktopSmoke_NoInputOverlap(hSettingsWnd))
        }
        DesktopSmoke_Assert("settings catalog keeps all 13 pages", pages.Length() = 13)
        DesktopSmoke_Assert("sidebar has one native button for each page", SettingsNavigationButtons.Length() = pages.Length())
        DesktopSmoke_Assert("legacy navigation is hidden", !DllCall("IsWindowVisible", "Ptr", hSettingsNavLV))
        CreateHUD()
        UpdateHUD()
        DesktopSmoke_Assert("native HUD exists", DllCall("IsWindow", "Ptr", hHUDWnd))
        CreateBindList()
        UpdateBindList()
        DesktopSmoke_Assert("native bind list exists", DllCall("IsWindow", "Ptr", hBindListWnd))
        priorBindColor := CustomBindListColor
        CustomBindListColor := "162231"
        CreateBindList()
        DesktopSmoke_Assert("custom bind list color survives shared styling", UIStyleWindows[hBindListWnd].Panel = "162231")
        CustomBindListColor := priorBindColor
        CreateBindList()
        UpdateBindList()
        priorTimerBg := StopTimerBgColor, priorTimerText := StopTimerTextColor
        StopTimerBgColor := "171C2C", StopTimerTextColor := "E4EAF8"
        Gui, ActionTimers:New, +HwndpaletteProbeWindow
        UIStyle_Apply("ActionTimers", paletteProbeWindow)
        DesktopSmoke_Assert("custom timer colors survive shared styling", UIStyleWindows[paletteProbeWindow].Background = "171C2C" && UIStyleWindows[paletteProbeWindow].Text = "E4EAF8")
        Gui, ActionTimers:Destroy
        StopTimerBgColor := priorTimerBg, StopTimerTextColor := priorTimerText
        for _, size in [[420, 320], [520, 390], [760, 740]] {
            Gui, 13:Show, % "w" . size[1] . " h" . size[2] . " NoActivate"
            ResizeBindListGui(size[1], size[2])
            DesktopSmoke_Assert("bind list controls do not overlap " . size[1] . "x" . size[2], DesktopSmoke_NoInputOverlap(hBindListWnd))
            VarSetCapacity(clientRect, 16, 0)
            DllCall("GetClientRect", "Ptr", hBindListWnd, "Ptr", &clientRect)
            DllCall("MapWindowPoints", "Ptr", hBindListWnd, "Ptr", 0, "Ptr", &clientRect, "UInt", 2)
            VarSetCapacity(listRect, 16, 0)
            DllCall("GetWindowRect", "Ptr", hBindListLV, "Ptr", &listRect)
            DesktopSmoke_Assert("bind list fits window " . size[1] . "x" . size[2], NumGet(listRect, 8, "Int") <= NumGet(clientRect, 8, "Int") && NumGet(listRect, 12, "Int") < NumGet(clientRect, 12, "Int"))
        }
        DesktopSmoke_Assert("HUD/list promotion does not activate another window", DllCall("GetForegroundWindow", "Ptr") = focusProbeWindow)
        FullscreenSafeGui := savedFullscreen
        Gui, FocusProbe:Destroy
        savedMode := TextTriggerInputMode
        TextTriggerInputMode := "Окно AHK"
        savedPreviewFlag := UiPreviewMode
        UiPreviewMode := 0
        savedUi := SaveUISettings()
        UiPreviewMode := savedPreviewFlag
        TextTriggerInputMode := "Игровой чат"
        LoadUIAppearanceFromIni(ConfigFile)
        DesktopSmoke_Assert("private TXT input mode survives INI reload", savedUi && TextTriggerInputMode = "Окно AHK")
        TextTriggerInputMode := savedMode
        Bind_TextCommandInput := "^!t"
        DesktopSmoke_Assert("private TXT opener is registered in dispatch map", GetBoundLabelByToken("TextCommandInput") = "DoPrivateTextInput")
        captureState := ServiceUI_NewInputState("TXT", "Private test", 180, 60, "!audit", false, AutomationEpoch, 0, CurrentProfile, TickNow())
        captureState.ForcePrivacy := true
        ServiceUI_CreateInputGui(captureState)
        DesktopSmoke_Assert("private TXT window requests privacy independently of global switch", CapturePrivateWindows.HasKey(captureState.GuiHwnd))
        actualPrivacy := CaptureWindowStates[captureState.GuiHwnd]
        DesktopSmoke_Assert("private window stays hidden without confirmed OS exclusion", (IsObject(actualPrivacy) && actualPrivacy.Verified && actualPrivacy.Enabled) || !DllCall("IsWindowVisible", "Ptr", captureState.GuiHwnd))
        extended := DllCall("GetWindowLong", "Ptr", captureState.GuiHwnd, "Int", -20, "UInt")
        DesktopSmoke_Assert("private TXT window never activates and is click-through", (extended & 0x08000020) = 0x08000020)
        Gui, ServiceInput:Destroy
        CapturePrivateWindows.Delete(captureState.GuiHwnd)
        unknownSection := "DesktopCompatibility"
        CheckedIniWrite("keep-me", ConfigFile, unknownSection, "UnknownKey")
        expectedPrivateBind := Bind_TextCommandInput
        expectedRole := "Должность проверки"
        IntroRole := expectedRole
        Bind_Intro := "^!8"
        Trig_Intro := "!desktopcheck"
        DesktopSmoke_Assert("actual atomic profile save", SaveProfile(CurrentProfile))
        IntroRole := "changed", Bind_Intro := "", Trig_Intro := ""
        LoadProfile(CurrentProfile)
        DesktopSmoke_Assert("private opener key survives profile reload", Bind_TextCommandInput = expectedPrivateBind)
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

; Use actual native rectangles, including DPI scaling, and ignore hidden pages
; and the child edit inside a ComboBox. This checks geometry, not screenshots.
DesktopSmoke_NoInputOverlap(window) {
    controls := []
    WinGet, children, ControlListHwnd, ahk_id %window%
    Loop, Parse, children, `n, `r
    {
        child := A_LoopField + 0
        if (!DllCall("IsWindowVisible", "Ptr", child) || DllCall("GetParent", "Ptr", child, "Ptr") != window)
            continue
        VarSetCapacity(classBuffer, 128, 0)
        DllCall("GetClassNameW", "Ptr", child, "Ptr", &classBuffer, "Int", 64)
        class := StrGet(&classBuffer, "UTF-16")
        if (class != "Edit" && class != "ComboBox" && class != "Button" && class != "msctls_hotkey32")
            continue
        VarSetCapacity(rect, 16, 0)
        DllCall("GetWindowRect", "Ptr", child, "Ptr", &rect)
        item := {L: NumGet(rect, 0, "Int"), T: NumGet(rect, 4, "Int"), R: NumGet(rect, 8, "Int"), B: NumGet(rect, 12, "Int")}
        for _, prior in controls
            if (Min(item.R, prior.R) - Max(item.L, prior.L) > 1 && Min(item.B, prior.B) - Max(item.T, prior.T) > 1)
                return false
        controls.Push(item)
    }
    return true
}
