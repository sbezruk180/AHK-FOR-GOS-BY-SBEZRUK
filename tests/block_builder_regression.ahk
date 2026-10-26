; Block model and sandbox execution tests exercise production code without game input.
BlockBuilder_RunRegression() {
    global
    source := "; Общая заметка`r`nCHAT /r Оригинал`n`nWAIT 17`r`n;@AHK_DISABLED TYPE /cuff {ID}`r`n# конец`r`n"
    model := CustomBlocks_Parse(source)
    AuditAssert("Blocks: unchanged text round-trips exactly, including mixed EOL and comments", CustomBlocks_Serialize(model) == source)
    AuditAssert("Blocks: disabled operation is still an editable executable block", model.Rows[5].Executable && !model.Rows[5].Enabled && model.Rows[5].Raw = "TYPE /cuff {ID}")
    AuditAssert("Blocks: non-executable notes cannot be enabled", !CustomBlocks_Toggle(model, 1) && !CustomBlocks_Toggle(model, 3))
    AuditAssert("Blocks: reordering validates both positions", !CustomBlocks_Move(model, 0, 1) && !CustomBlocks_Move(model, 2, 99))
    AuditAssert("Blocks: moving block retains its original CHAT spelling", CustomBlocks_Move(model, 2, 4) && model.Rows[4].Raw = "CHAT /r Оригинал")
    serialized := CustomBlocks_Serialize(model)
    parsed := CustomFunction_Parse(serialized, errorText)
    AuditAssert("Blocks: serialization preserves all comments and disabled TYPE", InStr(serialized, "; Общая заметка") && InStr(serialized, ";@AHK_DISABLED TYPE /cuff {ID}") && InStr(serialized, "# конец"))
    AuditAssert("Blocks: runtime executes moved enabled blocks in order", errorText = "" && parsed.Length() = 2 && parsed[1].Type = "WAIT" && parsed[2].Type = "SEND")
    selected := CustomBlocks_SelectedScript(model, [1, 4, 5], errorText)
    AuditAssert("Blocks: selected script excludes notes and disabled actions", errorText = "" && selected = "CHAT /r Оригинал")
    selected := CustomBlocks_SelectedScript(model, [1, 5], errorText)
    AuditAssert("Blocks: empty selection reports an actionable error", selected = "" && errorText != "")
    AuditAssert("Blocks: enabling retained step preserves parameter syntax", CustomBlocks_Toggle(model, 5) && InStr(CustomBlocks_Serialize(model), "`r`nTYPE /cuff {ID}"))
    allDisabled := ";@AHK_DISABLED SEND /r draft"
    CustomFunction_Parse(allDisabled, errorText)
    AuditAssert("Blocks: all-disabled draft is recognized but does not execute", CustomBlocks_HasDisabledSteps(allDisabled) && errorText != "")
    info := CustomBlocks_RowInfo({Raw: "TIMER 15|Метка|дополнение", Executable: true, Enabled: true})
    AuditAssert("Blocks: timer label keeps literal separators", info.Type = "TIMER" && info.Value = "15|Метка|дополнение")
    info := CustomBlocks_RowInfo({Raw: "WAIT no", Executable: true, Enabled: true})
    AuditAssert("Blocks: invalid raw block remains visible for repair", info.Type = "Ошибка" && info.Value = "WAIT no")
    snapshot := {Run: CustomFunctionRunState, Mock: MockMode, Input: PhysicalInputBusy, ID: IDCaptureState, Queue: ChatQueueItems
        , Stop: StopTimerActive, Counter: StopTimerCounter, Label: StopTimerLabel, Preview: ChatQueuePreviewText, Lines: ChatQueuePreviewLineCount}
    CustomFunctionRunState := "", PhysicalInputBusy := 0, IDCaptureState := "", MockMode := "Off", ChatQueueItems := []
    clipboardSequence := DllCall("GetClipboardSequenceNumber", "UInt")
    ChatQueuePreviewText := "", ChatQueuePreviewLineCount := 0
    steps := CustomFunction_Parse("SEND /r only-block-test`nTYPE /cuff {ID}`nTIMER 2|no-live-timer`nNOTICE note`nWAIT 0`nSTOP`nSEND unreachable", errorText)
    started := CustomFunction_StartSteps("offline selection", steps, true)
    SetTimer, CustomFunctionRunnerTick, Off
    CustomFunctionRunner_Process()
    CustomFunctionRunner_Process()
    AuditAssert("Blocks: selected sandbox works with global MockMode OFF", started && InStr(ChatQueuePreviewText, "only-block-test") && InStr(ChatQueuePreviewText, "[BLOCK TEST] TYPE /cuff") && MockMode = "Off")
    AuditAssert("Blocks: sandbox never inserts a real chat queue item", ChatQueueItems.Length() = 0)
    AuditAssert("Blocks: sandbox leaves clipboard and real timers unchanged", DllCall("GetClipboardSequenceNumber", "UInt") = clipboardSequence && StopTimerActive = snapshot.Stop && StopTimerCounter = snapshot.Counter && StopTimerLabel = snapshot.Label)
    AuditAssert("Blocks: STOP prevents later selected actions", !IsObject(CustomFunctionRunState) && !InStr(ChatQueuePreviewText, "unreachable"))
    CustomFunctionRunState := {Name: "existing"}
    AuditAssert("Blocks: partial test cannot replace a running scenario", !CustomFunction_StartSteps("replacement", steps, true) && CustomFunctionRunState.Name = "existing")
    CustomFunctionRunState := snapshot.Run, MockMode := snapshot.Mock, PhysicalInputBusy := snapshot.Input, IDCaptureState := snapshot.ID
    ChatQueueItems := snapshot.Queue, ChatQueuePreviewText := snapshot.Preview, ChatQueuePreviewLineCount := snapshot.Lines
    Gui, 41:Destroy
}

BlockBuilder_RunDesktopChecks() {
    global
    OpenCustomFunctionBuilder(1)
    original := "; сохранить`r`nSEND /r один`r`nWAIT 10`r`nTYPE /cuff {ID}"
    GuiControl, 40:, CFB_Script, %original%
    DesktopSmoke_Assert("blocks: native block editor opens from text source", CustomBlocks_Open() && DllCall("IsWindow", "Ptr", CustomBlocksState.Hwnd))
    DesktopSmoke_Assert("blocks: opening alone does not modify source", CustomBlocks_Serialize(CustomBlocksState.Model) = original)
    CustomBlocks_SelectList()
    LV_Modify(0, "-Select"), LV_Modify(2, "Select Focus")
    DesktopSmoke_Assert("blocks: selected native row moves down", CustomBlocks_Down() && CustomBlocksState.Model.Rows[3].Raw = "SEND /r один")
    DesktopSmoke_Assert("blocks: moved native row disables without removal", CustomBlocks_ToggleSelected() && !CustomBlocksState.Model.Rows[3].Enabled)
    DesktopSmoke_Assert("blocks: apply transfers blocks to original edit control", CustomBlocks_Apply())
    ControlGetText, applied,, ahk_id %hCFBScript%
    DesktopSmoke_Assert("blocks: original text editor receives disabled marker and comment", InStr(applied, "; сохранить") && InStr(applied, ";@AHK_DISABLED SEND /r один") && InStr(applied, "WAIT 10`r`n;@AHK_DISABLED"))
    DllCall("SendMessage", "Ptr", hCFBScript, "UInt", 0xC7, "Ptr", 0, "Ptr", 0)
    ControlGetText, undone,, ahk_id %hCFBScript%
    DesktopSmoke_Assert("blocks: applying an entire block edit remains undoable", undone = original)
    DesktopSmoke_Assert("blocks: stale source is rejected instead of overwriting user text", !CustomBlocks_Apply())
    CustomBlocks_Close(false)
    GuiControl, 40:, CFB_Script, %original%
    CustomBlocks_Open()
    CustomBlocks_SelectList()
    LV_Modify(0, "-Select"), LV_Modify(4, "Select Focus")
    DesktopSmoke_Assert("blocks: selected preview opens native details GUI", CustomBlocks_Preview() && DllCall("IsWindow", "Ptr", ServiceUIDetailsHwnd))
    ServiceUI_CloseDetails()
    CustomBlocks_Close(false)
    CloseCustomFunctionBuilder(0)
    DesktopSmoke_Assert("blocks: closing removes state and drag timer window", !IsObject(CustomBlocksState))
}
