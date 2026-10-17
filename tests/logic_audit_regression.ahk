; Reproductions from the manual control-flow audit. All game transport is Mock.
RunLogicAuditRegression() {
    global
    logicSaved := {}
    logicNames := "AutomationEpoch,CurrentProfile,UserID,ChatQueueItems,ChatQueueBusy,ChatQueueMaxItems,ChatQueueLastSendTick,ChatQueueNextSendTick,ChatQueuePreviewText,QueueBatchStates,CustomFunctionRunState,HistoricalHotstrings,HistoricalHotstringCount,Trig_Intro,ActionCooldownMs,LastCuffActionTick,LastDejectActionTick,CuffFollowupWindowMs,DejectFollowupWindowMs,RP_Deject,RP_StopChase,SafeModeEnabled,SafeBlockWhenChat,SafeVehicleChecks,SafeDistanceChecks,NotifySoundEnabled,AuditTransportResult,ServiceUIAuditInputs,ChatWizardMode,ChatWizardPrompt,ChatWizardOpenedFromChat,ChatWizardEpoch,ChatWizardProfile,LastCuffActionTarget,LastCuffActionEpoch,LastDejectActionTarget,LastDejectActionEpoch"
    Loop, Parse, logicNames, `,
        logicSaved[A_LoopField] := GetDynamicGlobalValue(A_LoopField)
    try {
        PhysicalInputBusy := 0, GameMenuLease := "", GameMenuStarting := ""
        ChatQueueItems := [], ChatQueueBusy := 0, ChatQueueMaxItems := 10, QueueBatchStates := {}
        ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0, AuditTransportResult := 1
        SafeModeEnabled := "Off", SafeBlockWhenChat := "Off", SafeVehicleChecks := "Off", SafeDistanceChecks := "Off"
        ActionCooldownMs := 0, NotifySoundEnabled := "Off"
        ChatQueuePreviewText := ""
        logicStale := AutomationEpoch - 1
        AuditAssert("Logic: stale radial step refuses its first key", !SendRadialNumberTwice(1, 0, 0, logicStale) && ChatQueuePreviewText = "")
        ChatQueuePreviewText := ""
        AuditAssert("Logic: stale list selection refuses all keys", !SendListSelection(2, 0, 0, logicStale) && ChatQueuePreviewText = "")
        ChatQueuePreviewText := ""
        AuditAssert("Logic: stale GPS scroll refuses all keys", !SendGpsDialogDown(2, 0, logicStale) && ChatQueuePreviewText = "")

        ChatQueuePreviewText := ""
        AuditAssert("Logic: stale GPS cleanup refuses all backspaces", !EraseGpsTypedCommand("!gps", "1", "", logicStale) && ChatQueuePreviewText = "")
        ServiceUIAuditInputs := [{Confirm: 1, Value: "10000"}]
        logicNumber := ReadGpsInputNumber(logicCancelled, logicEnd, "1")
        AuditAssert("Logic: GPS input accepts its documented upper bound 10000", !logicCancelled && logicNumber == "10000")
        ChatWizardMode := ""
        ChatWizard_Begin("audit wizard")
        CancelAllAutomation(0)
        ServiceUIAuditInputs := [{Confirm: 1, Value: "must-not-read"}]
        ChatWizard_ReadToken(logicCancelled)
        AuditAssert("Logic: cancelled wizard cannot resume at its next prompt", logicCancelled && ServiceUIAuditInputs.Length() = 1)

        logicFilters := LawSearch_QueryFilters("-закон -законодательство")
        AuditAssert("Logic: excluded words with a common prefix leave no positive token", logicFilters.Excluded.Length() = 2 && Trim(logicFilters.SearchText) = "")
        logicFilters := LawSearch_QueryFilters("""документ -паспорт""")
        AuditAssert("Logic: minus inside a quoted phrase is not an exclusion", logicFilters.Phrases.Length() = 1 && logicFilters.Excluded.Length() = 0)

        Trig_Intro := "!logic-free"
        logicMeta := {TriggerVar: "Trig_Intro", Token: "Intro", Label: "Intro"}
        for _, logicReserved in ["!бинд", "!коды", "!пкас", "!пфсб", "!пгт"]
            AuditAssert("Logic: reserved TXT cannot replace a saved user command " . logicReserved, !ValidateBindMenuTrigger(logicMeta, logicReserved, logicError))
        HistoricalHotstrings := {}, HistoricalHotstringCount := 512
        logicPrev := "", logicError := "", logicUsed := {}
        AuditAssert("Logic: exhausted GPS registration reports refusal", !RegisterGpsInputTextTrigger("audit", logicPrev, "!logicgps", "GPS", 15, logicError, logicUsed) && logicError != "" && logicPrev = "")

        CurrentProfile := "Logic audit", UserID := "42"
        CustomFunctionRunState := {Name: "LogicPending", Steps: [{Type: "SEND", Value: "/r must-not-send-after-stop"}], Index: 1, NextTick: 0, WaitingForQueue: 0
            , Epoch: AutomationEpoch, Profile: CurrentProfile, Target: UserID, Failures: QueueFailureGeneration}
        CustomFunctionRunner_Process()
        AuditAssert("Logic: custom SEND was actually accepted before Stop", ChatQueue_Count() = 1)
        StopCustomFunctionRun(0)
        AuditAssert("Logic: stopping a custom function removes its pending SEND", ChatQueue_Count() = 0)
        ChatQueueItems := []
        UserID := "12345678901234567891"
        logicState := {Epoch: AutomationEpoch, Profile: CurrentProfile, Target: "12345678901234567890", Failures: QueueFailureGeneration}
        CustomFunctionRunState := logicState
        AuditAssert("Logic: different 20-digit masks cancel the old custom run", !CustomFunction_InputIsCurrent(logicState))
        StopCustomFunctionRun(0)

        UserID := "41", LastCuffActionTick := 0, CuffFollowupWindowMs := 10000
        ChatQueuePreviewText := ""
        Gosub, DoCuff
        UserID := "42"
        Gosub, DoCuff
        AuditAssert("Logic: Cuff on a new ID is a new command, not the old follow-up", InStr(ChatQueuePreviewText, "/cuff 41") && InStr(ChatQueuePreviewText, "/cuff 42") && !InStr(ChatQueuePreviewText, "/frac 42"))

        UserID := "41", LastDejectActionTick := 0, DejectFollowupWindowMs := 10000
        RP_Deject := "/me audit-old-follow-up", ChatQueuePreviewText := "", ChatQueueItems := []
        Gosub, DoDeject
        UserID := "42"
        Gosub, DoDeject
        AuditAssert("Logic: Deject on a new ID is a new command, not old RP", InStr(ChatQueuePreviewText, "/deject 41") && InStr(ChatQueuePreviewText, "/deject 42") && ChatQueue_Count() = 0)

        ChatQueueItems := []
        Loop, 9
            ChatQueue_Enqueue("pending " . A_Index, "logic", 0, 0, 1)
        Gosub, DoMaskCall
        AuditAssert("Logic: a full queue never accepts just the mask-call prefix", ChatQueue_Count() = 9)
        ChatQueueItems := []
        Loop, 10
            ChatQueue_Enqueue("pending " . A_Index, "logic", 0, 0, 1)
        RP_StopChase := "/m audit stop", UserID := "42"
        HideStopTimerGUI()
        Gosub, DoStopChase
        AuditAssert("Logic: a rejected stop request cannot start a countdown", !StopTimerActive)
        HideStopTimerGUI()
        ChatQueueItems := [], ChatQueueLastSendTick := 0, ChatQueueNextSendTick := 0
        Gosub, DoStopChase
        AuditAssert("Logic: queued stop request waits for delivery before countdown", !StopTimerActive && ChatQueue_Count() = 1)
        ChatQueue_Tick()
        AuditAssert("Logic: first delivered stop request starts the 15-second countdown", StopTimerActive && StopTimerCounter = 15)
        HideStopTimerGUI()
    } finally {
        StopCustomFunctionRun(0)
        HideStopTimerGUI()
        for logicName, logicValue in logicSaved
            SetDynamicGlobalValue(logicName, logicValue)
        PhysicalInputBusy := 0, GameMenuLease := "", GameMenuStarting := ""
    }
}
