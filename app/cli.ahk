if HasCommandLineArg("--runtime-info") {
    runtimeOK := AppHost_RuntimeInfo()
    ExitApp, % runtimeOK ? 0 : 1
}
if HasCommandLineArg("--export-licenses") {
    licensesOK := AppHost_ExportLicenses()
    ExitApp, % licensesOK ? 0 : 1
}

if HasCommandLineArg("--audit-selftest")
{
    auditPassed := RunAuditSelfTest()
    ExitApp, % auditPassed ? 0 : 1
}

if HasCommandLineArg("--selftest")
{
    selfTestOk := RunSelfTestV1()
    selfTestExitCode := selfTestOk ? 0 : 1
    ExitApp, %selfTestExitCode%
}

if HasCommandLineArg("--diagnostics")
{
    diagnosticsOk := RunDiagnosticsExport()
    ExitApp, % diagnosticsOk ? 0 : 1
}

if HasCommandLineArg("--context-mocktest")
{
    contextMockOk := RunContextAssistantMockTest()
    ExitApp, % contextMockOk ? 0 : 1
}

if HasCommandLineArg("--autoreport-mocktest")
{
    autoReportMockOk := RunAutoReportMockTest()
    autoReportExitCode := autoReportMockOk ? 0 : 1
    ExitApp, %autoReportExitCode%
}

if HasCommandLineArg("--law-search-test")
{
    lawSearchTestOk := RunLawSearchRegression()
    lawSearchExitCode := lawSearchTestOk ? 0 : 1
    ExitApp, %lawSearchExitCode%
}

if HasCommandLineArg("--v1-mocktest")
{
    v1MockOk := RunV1MockRegression()
    v1MockExitCode := v1MockOk ? 0 : 1
    ExitApp, %v1MockExitCode%
}

