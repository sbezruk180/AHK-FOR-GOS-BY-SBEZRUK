; Production parser/preview and real Edit/persistence checks. No game execution.
CustomBuilder_RunRegression() {
    global
    queued := ChatQueue_Count(), previousRun := CustomFunctionRunState
    errorText := ""
    preview := CustomFunctionBuilder_PreviewText("SEND /r Пример`nWAIT 1200`nTIMER 15|Тест`nSTOP`nSEND /r После остановки", errorText)
    AuditAssert("Builder: preview lists actions, pauses and timers", errorText = "" && InStr(preview, "1. SEND  /r Пример") && InStr(preview, "1200 мс") && InStr(preview, "15 сек."))
    AuditAssert("Builder: preview shows unreachable steps after STOP", InStr(preview, "После STOP") && !InStr(preview, "/r После остановки"))
    preview := CustomFunctionBuilder_PreviewText("WAIT неверно", errorText)
    AuditAssert("Builder: preview reports invalid source line", preview = "" && InStr(errorText, "Строка 1"))
    AuditAssert("Builder: preview has no runtime or queue effects", queued = ChatQueue_Count() && CustomFunctionRunState == previousRun)
}

CustomBuilder_RunDesktopChecks() {
    global
    OpenCustomFunctionBuilder(1)
    DesktopSmoke_Assert("builder opens native editor", DllCall("IsWindow", "Ptr", hCustomFunctionWnd) && DllCall("IsWindow", "Ptr", hCFBScript))
    original := "SEND /r один`r`nSEND /r два"
    GuiControl, 40:, CFB_Script, %original%
    caret := StrLen("SEND /r один")
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xB1, "Ptr", caret, "Ptr", caret)
    CustomFunctionBuilder_AppendStep("WAIT 100")
    ControlGetText, edited,, ahk_id %hCFBScript%
    DesktopSmoke_Assert("builder inserts step at selection without losing following lines", edited = "SEND /r один`r`nWAIT 100`r`nSEND /r два")
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xC7, "Ptr", 0, "Ptr", 0)
    ControlGetText, undone,, ahk_id %hCFBScript%
    DesktopSmoke_Assert("builder native undo restores source", undone = original)
    GuiControl, 40:, CFB_Script, WAIT неверно
    DesktopSmoke_Assert("builder check rejects an invalid step", !CustomFunctionBuilder_Check())
    script := "SEND /r Черновик`nWAIT 200"
    GuiControl, 40:, CFB_Script, %script%
    DesktopSmoke_Assert("builder check accepts valid editor contents", CustomFunctionBuilder_Check())
    queued := ChatQueue_Count(), running := CustomFunctionRunState
    DesktopSmoke_Assert("builder preview opens own details window", CustomFunctionBuilder_Preview() && DllCall("IsWindow", "Ptr", ServiceUIDetailsHwnd))
    DesktopSmoke_Assert("builder preview cannot run the script", queued = ChatQueue_Count() && running == CustomFunctionRunState)
    ServiceUI_CloseDetails()
    count := CustomFunctions.Length()
    GuiControl, 40:, CFB_Name, Проверка копии
    GuiControl, 40:, CFB_Hotkey, ^!F12
    GuiControl, 40:, CFB_Trigger, !buildertest
    DesktopSmoke_Assert("builder duplicate includes unsaved script", CustomFunctionBuilder_Duplicate() && CustomFunctions.Length() = count + 1 && CustomFunctions[count + 1].Script = script)
    DesktopSmoke_Assert("builder duplicate avoids bind conflicts", CustomFunctions[count + 1].Hotkey = "" && CustomFunctions[count + 1].Trigger = "")
    copyName := CustomFunctions[count + 1].Name
    CloseCustomFunctionBuilder(0)
    LoadCustomFunctions()
    DesktopSmoke_Assert("builder copy survives INI reload", CustomFunctions[count + 1].Name = copyName && CustomFunctions[count + 1].Script = script)
}
