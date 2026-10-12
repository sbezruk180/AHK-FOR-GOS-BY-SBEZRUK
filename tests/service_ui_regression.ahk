; Public input contract in test mode: no hook, window, game send or clipboard access.
RunServiceUIRegression() {
    global AuditTestMode, MockMode, PhysicalInputBusy, IDCaptureState, ServiceUIAuditInputs, ServiceUIInputState
    global ServiceUIConfirmState, ServiceUIAuditConfirmations
    savedAudit := AuditTestMode, savedMock := MockMode, savedBusy := PhysicalInputBusy
    savedCapture := IDCaptureState, savedQueue := ServiceUIAuditInputs, savedState := ServiceUIInputState
    savedConfirm := ServiceUIConfirmState, savedConfirmQueue := ServiceUIAuditConfirmations
    try {
        AuditTestMode := 1, MockMode := "Off", PhysicalInputBusy := 0, IDCaptureState := "", ServiceUIInputState := "", ServiceUIConfirmState := ""
        ServiceUIAuditInputs := [{Confirm:1, Value:"Привет, мир! 20.6"}]
        value := "старое значение"
        ok := ServiceUI_Request("Поиск", "Введите запрос", value)
        AuditAssert("Service UI arbitrary Russian input preserves punctuation/spaces", ok && value = "Привет, мир! 20.6")
        AuditAssert("Service UI audit consumes exactly one input", ServiceUIAuditInputs.Length() = 0)
        AuditAssert("Service UI audit never acquires real input lock", PhysicalInputBusy = 0 && !ServiceUI_IsInputActive())

        value := "keep"
        AuditAssert("Service UI empty audit queue safely refuses", !ServiceUI_Request("", "", value) && value = "keep")
        ServiceUIAuditInputs := [{Confirm:0, Value:"cancelled"}]
        AuditAssert("Service UI cancellation preserves caller value", !ServiceUI_Request("", "", value) && value = "keep")
        ServiceUIAuditInputs := [{Confirm:1, Value:"12345"}]
        AuditAssert("Service UI overlength result cannot commit", !ServiceUI_Request("", "", value, 4) && value = "keep")

        ServiceUIAuditInputs := [{Confirm:1, Value:"0"}]
        PhysicalInputBusy := 1
        AuditAssert("Service UI never steals another sender lock", !ServiceUI_Request("", "", value) && PhysicalInputBusy = 1 && ServiceUIAuditInputs.Length() = 1)
        PhysicalInputBusy := 0, IDCaptureState := {Value:"1"}
        AuditAssert("Service UI refuses during digit capture", !ServiceUI_Request("", "", value) && ServiceUIAuditInputs.Length() = 1)
        IDCaptureState := "", ServiceUIInputState := {Pending:""}
        AuditAssert("Service UI refuses concurrent request", !ServiceUI_Request("", "", value) && ServiceUIAuditInputs.Length() = 1)
        ServiceUIInputState := ""
        AuditAssert("Service UI valid zero input is preserved", ServiceUI_Request("", "", value) && value = "0")
        MockMode := "On", AuditTestMode := 0, ServiceUIAuditInputs := [{Confirm:1, Value:"A123AA"}]
        AuditAssert("Service UI MockMode accepts scripted native text only", ServiceUI_Request("", "", value) && value = "A123AA" && !ServiceUI_IsInputActive())
        AuditAssert("Service UI MockMode without script stays noninteractive", !ServiceUI_Request("", "", value))
        AuditAssert("Service UI unknown severity stays informational", ServiceUI_NormalizeSeverity("unexpected") = "INFO")
        AuditAssert("Service UI warning severity is case independent", ServiceUI_NormalizeSeverity("warn") = "WARN")
        ServiceUIAuditConfirmations := []
        AuditAssert("Service UI confirmation defaults to false without user choice", !ServiceUI_Confirm("Удаление", "Удалить профиль?"))
        ServiceUIAuditConfirmations := [0, 1]
        AuditAssert("Service UI confirmation preserves explicit No", !ServiceUI_Confirm("Удаление", "Удалить профиль?"))
        AuditAssert("Service UI confirmation accepts explicit Yes", ServiceUI_Confirm("Удаление", "Удалить профиль?"))
        ServiceUIConfirmState := {Pending:""}
        AuditAssert("Service UI modal is considered active input", ServiceUI_IsInputActive())
        AuditAssert("Service UI common cancellation cancels modal", ServiceUI_CancelInput() && ServiceUIConfirmState.Pending = "cancel")
    } finally {
        AuditTestMode := savedAudit, MockMode := savedMock, PhysicalInputBusy := savedBusy
        IDCaptureState := savedCapture, ServiceUIAuditInputs := savedQueue, ServiceUIInputState := savedState
        ServiceUIConfirmState := savedConfirm, ServiceUIAuditConfirmations := savedConfirmQueue
    }
}
