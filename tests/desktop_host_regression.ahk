; Host tests use disposable data directories; no game, hooks, or UI interaction.
Audit_DesktopHost(scratch) {
    global AppDataRoot
    oldRoot := AppDataRoot
    target := scratch . "\desktop"
    source := scratch . "\legacy"
    FileCreateDir, %source%
    FileCreateDir, %target%
    try {
        AuditAssert("Desktop: absolute Windows paths accepted", AppHost_IsAbsolutePath("C:\Users\Example\Data") && AppHost_IsAbsolutePath("\\server\share\data"))
        AuditAssert("Desktop: relative and drive-relative paths rejected", !AppHost_IsAbsolutePath("data") && !AppHost_IsAbsolutePath("C:data"))
        AuditAssert("Desktop: data directory write probe leaves no file", AppHost_CanWrite(target) && !FileExist(target . "\.ahk_gos_write_" . DllCall("GetCurrentProcessId")))
        body := "[Profiles]`r`nLast=Legacy`r`nList=Legacy`r`n[Profile_Legacy]`r`nBind_Intro=!1`r`nUnknownUserKey=keep-me`r`n"
        file := source . "\profiles.ini"
        FileAppend, %body%, %file%, CP1251
        AppHost_ImportLegacy(source, target)
        FileRead, copied, % target . "\profiles.ini"
        AuditAssert("Desktop: existing INI migrated byte-compatible", copied = body)
        changed := "[Profiles]`r`nLast=Changed`r`n"
        FileDelete, %file%
        FileAppend, %changed%, %file%, CP1251
        AppHost_ImportLegacy(source, target)
        FileRead, copied, % target . "\profiles.ini"
        AuditAssert("Desktop: repeated migration never overwrites destination", copied = body)
        FileRead, original, %file%
        AuditAssert("Desktop: migration never modifies source config", original = changed)
        theme := source . "\themes.ini"
        FileAppend, [Example]`r`nColor=101010`r`n, %theme%
        FileSetAttrib, +R, %theme%
        AppHost_ImportLegacy(source, target)
        targetTheme := target . "\themes.ini"
        FileGetAttrib, targetAttributes, %targetTheme%
        FileGetAttrib, sourceAttributes, %theme%
        AuditAssert("Desktop: copied read-only config becomes writable", !InStr(targetAttributes, "R") && FileExist(targetTheme))
        AuditAssert("Desktop: original read-only config keeps its attributes", InStr(sourceAttributes, "R"))
        FileSetAttrib, -R, %theme%
        AppDataRoot := target
        AuditAssert("Desktop: active data root used", AppHost_DataDir() = target)
        FileCreateDir, % target . "\laws"
        file := target . "\laws\TER.txt"
        law := "Статья 999. Пользовательское дополнение.`r`n"
        FileAppend, %law%, %file%, CP1251
        AuditAssert("Desktop: user corpus override has priority", AppHost_ReadLaw("TER.txt") = law)
        FileDelete, %file%
        AuditAssert("Desktop: missing override falls back to full bundled corpus", InStr(AppHost_ReadLaw("TER.txt"), "территор"))
        AuditAssert("Desktop: corpus path traversal is rejected", AppHost_ReadLaw("..\profiles.ini") = "" && AppHost_LawPath("C:\outside.txt") = "")
        if (A_IsCompiled) {
            AuditAssert("Desktop: compiled source introspection reads resources", InStr(AppHost_SourceText(), "AutoTargetID_Poll() {") && InStr(AppHost_SourceFile("UDF.ahk"), "getPlayerDataByPed("))
            AuditAssert("Desktop: build manifest embedded", InStr(AppHost_ResourceText("BUILD_MANIFEST", "UTF-8"), "AHK FOR GOS"))
            AuditAssert("Desktop: project and engine licenses embedded", InStr(AppHost_ResourceText("LICENSE_PROJECT", "UTF-8"), "MIT") && InStr(AppHost_ResourceText("LICENSE_ENGINE", "UTF-8"), "GENERAL PUBLIC LICENSE"))
        } else {
            AuditAssert("Desktop: modular source introspection includes helper once", InStr(AppHost_SourceText(), "LawCorpus_GetText(prefix, forceReload := 0)") && InStr(AppHost_SourceText(), "ChatTransport_Send(text"))
            AuditSkip("Desktop compiled PE resources require a compiled test run")
        }
    } finally {
        AppDataRoot := oldRoot
        FileRemoveDir, %target%, 1
        FileRemoveDir, %source%, 1
    }
}
