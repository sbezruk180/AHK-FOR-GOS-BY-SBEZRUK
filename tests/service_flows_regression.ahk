RunServiceFlowsRegression() {
    global ServiceUIAuditInputs, ServiceUIAuditConfirmations, MDSFormationMaxMinutes
    global ChatWizardMode, ChatWizardPrompt, ChatWizardOpenedFromChat
    global SearchDocName, SearchLastQuery, ChatQueuePreviewText
    originalInputs := ServiceUIAuditInputs, originalConfirmations := ServiceUIAuditConfirmations
    originalMax := MDSFormationMaxMinutes, originalMode := ChatWizardMode
    originalPrompt := ChatWizardPrompt, originalOpened := ChatWizardOpenedFromChat
    originalDoc := SearchDocName, originalQuery := SearchLastQuery
    clipboardSequence := DllCall("GetClipboardSequenceNumber", "UInt")
    previewStart := StrLen(ChatQueuePreviewText)
    try {
        MDSFormationMaxMinutes := 60
        ServiceUIAuditInputs := [{Confirm: 1, Value: "12"}]
        AuditAssert("Service flow: formation minutes come from GUI", ReadMDSFormationMinutes() = 12)
        ServiceUIAuditInputs := [{Confirm: 0, Value: "12"}]
        AuditAssert("Service flow: cancelled formation does not start", ReadMDSFormationMinutes() = 0)
        ServiceUIAuditInputs := [{Confirm: 1, Value: "0"}]
        AuditAssert("Service flow: invalid formation duration refused", ReadMDSFormationMinutes() = 0)
        ServiceUIAuditInputs := [{Confirm: 1, Value: "30"}]
        AuditAssert("Service flow: autoreport duration comes from GUI", ReadAutoReportMinutes("Патруль") = 30)
        ServiceUIAuditInputs := [{Confirm: 1, Value: "601"}]
        AuditAssert("Service flow: autoreport GUI input keeps duration bounds", ReadAutoReportMinutes("Пост") = 0)
        ChatWizardMode := ""
        AuditAssert("Service flow: wizard begins without opening game chat", ChatWizard_Begin("Поиск ТС"))
        GameNotify("Страна или номер позиции")
        ServiceUIAuditInputs := [{Confirm: 1, Value: "!россия"}]
        token := ChatWizard_ReadToken(cancelled)
        AuditAssert("Service flow: wizard collects Russian token from GUI", !cancelled && token = "!россия")
        AuditAssert("Service flow: wizard prompts use own notice", ChatWizardPrompt = "Страна или номер позиции")
        ServiceUIAuditInputs := [{Confirm: 0, Value: "05"}]
        token := ChatWizard_ReadToken(cancelled)
        AuditAssert("Service flow: wizard cancellation remains distinct from empty token", cancelled && token = "")
        ChatWizardOpenedFromChat := false
        ChatWizard_Finish()
        AuditAssert("Service flow: finishing wizard clears its state", ChatWizardMode = "" && ChatWizardPrompt = "")
        ServiceUIAuditInputs := [{Confirm: 1, Value: "155"}]
        number := ReadGpsInputNumber(cancelled, endKey, "1")
        AuditAssert("Service flow: full GPS value comes from private seeded GUI", !cancelled && number = "155" && endKey = "gui")
        ServiceUIAuditInputs := [{Confirm: 0, Value: "155"}]
        number := ReadGpsInputNumber(cancelled, endKey, "1")
        AuditAssert("Service flow: GPS cancel has no partial result", cancelled && number = "" && endKey = "")
        SearchDocName := "КоАП", SearchLastQuery := ""
        ServiceUIAuditInputs := [{Confirm: 1, Value: "статья 17.5"}]
        query := ""
        AuditAssert("Service flow: LAW query uses dynamic GUI ByRef API", LawSearch_ReadServiceQuery(query) && query = "статья 17.5")
        ServiceUIAuditInputs := [{Confirm: 0, Value: "новая строка"}]
        query := "keep"
        AuditAssert("Service flow: cancelled LAW query preserves caller value", !LawSearch_ReadServiceQuery(query) && query = "keep")
        ServiceUIAuditInputs := [{Confirm: 1, Value: "!пвсе"}]
        AuditAssert("Service flow: LAW mode command is not executed as a query", !LawSearch_ReadServiceQuery(query))
        mode := "Через чат"
        NormalizeIDEntryMode(mode)
        AuditAssert("Service flow: legacy ID config migrates to own input window", mode = "Окно ввода")
        sha := "not-a-hash"
        NormalizeSHA256(sha)
        AuditAssert("Memory config: malformed explicit SHA cannot become blank compatibility", sha = "NOT-A-HASH" && !MemoryBuildPolicy(sha, true, true))
        sha := "  " . Format("{:064X}", 1) . "  "
        NormalizeSHA256(sha)
        AuditAssert("Memory config: trimmed valid SHA remains explicit", StrLen(sha) = 64 && MemoryBuildPolicy(sha, true, true))
        AuditAssert("Service flow: no prompt emits physical F6 or paste in audit preview", !InStr(SubStr(ChatQueuePreviewText, previewStart + 1), "[INPUT Input] {F6}"))
        AuditAssert("Service flow: service input leaves clipboard intact", DllCall("GetClipboardSequenceNumber", "UInt") = clipboardSequence)
    } finally {
        ServiceUIAuditInputs := originalInputs, ServiceUIAuditConfirmations := originalConfirmations
        MDSFormationMaxMinutes := originalMax, ChatWizardMode := originalMode
        ChatWizardPrompt := originalPrompt, ChatWizardOpenedFromChat := originalOpened
        SearchDocName := originalDoc, SearchLastQuery := originalQuery
    }
}
