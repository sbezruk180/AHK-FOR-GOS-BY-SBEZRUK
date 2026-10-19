; Application host: paths, immutable PE resources and source introspection.
; No hooks, game handles, executable extraction or helper processes at startup.
global AppDataRoot := ""
global AppPortableMode := 0

AppHost_Init() {
    global AppDataRoot, AppPortableMode
    for _, flag in ["--runtime-info", "--audit-selftest", "--selftest", "--diagnostics", "--context-mocktest", "--autoreport-mocktest", "--law-search-test", "--v1-mocktest", "--export-licenses"]
        if HasCommandLineArg(flag) {
            Suspend, On
            break
        }
    requested := AppHost_ArgumentValue("--data-dir")
    if (HasCommandLineArg("--desktop-smoke") && requested = "") {
        MsgBox, 16, AHK FOR GOS, Desktop smoke requires a disposable --data-dir.
        ExitApp, 2
    }
    legacy := FileExist(A_ScriptDir . "\profiles_updated.ini") || FileExist(A_ScriptDir . "\profiles.ini")
    portable := !A_IsCompiled || legacy || HasCommandLineArg("--portable") || FileExist(A_ScriptDir . "\portable.mode")
    root := requested != "" ? requested : (portable ? A_ScriptDir : A_AppData . "\AHK FOR GOS")
    if !AppHost_IsAbsolutePath(root) {
        MsgBox, 16, AHK FOR GOS, Путь --data-dir должен быть абсолютным.
        ExitApp, 2
    }
    if !AppHost_CanWrite(root) {
        if (requested != "" || HasCommandLineArg("--portable")) {
            MsgBox, 16, AHK FOR GOS, Папка данных недоступна для записи: %root%
            ExitApp, 2
        }
        root := A_AppData . "\AHK FOR GOS"
        if !AppHost_CanWrite(root) {
            MsgBox, 16, AHK FOR GOS, Не удалось открыть папку пользовательских данных: %root%
            ExitApp, 2
        }
        portable := false
    }
    AppDataRoot := RTrim(root, "\/")
    AppPortableMode := portable && AppDataRoot = A_ScriptDir
    if (legacy && AppDataRoot != A_ScriptDir)
        AppHost_ImportLegacy(A_ScriptDir, AppDataRoot)
    ; Optional user-supplied corpus overrides and local maps live here.
    FileCreateDir, % AppDataRoot . "\laws"
    FileCreateDir, % AppDataRoot . "\assets\law_maps"
    return true
}

AppHost_ArgumentValue(name) {
    if !IsObject(A_Args)
        return ""
    for i, value in A_Args {
        if (value = name && i < A_Args.Length())
            return A_Args[i + 1]
        if (SubStr(value, 1, StrLen(name) + 1) = name . "=")
            return SubStr(value, StrLen(name) + 2)
    }
    return ""
}

AppHost_IsAbsolutePath(path) {
    return RegExMatch(path, "i)^(?:[A-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)")
}

AppHost_CanWrite(root) {
    FileCreateDir, %root%
    path := RTrim(root, "\/") . "\.ahk_gos_write_" . DllCall("GetCurrentProcessId")
    file := FileOpen(path, "w")
    if !IsObject(file)
        return false
    file.Close()
    FileDelete, %path%
    return !FileExist(path)
}

AppHost_ImportLegacy(source, target) {
    ; Copy bytes once, never replace a destination config or modify its source.
    for _, name in ["profiles_updated.ini", "profiles.ini", "themes.ini", "custom_functions.ini"] {
        from := source . "\" . name, to := target . "\" . name
        if (FileExist(from) && !FileExist(to)) {
            FileCopy, %from%, %to%, 0
            copied := !ErrorLevel
            if (copied)
                FileSetAttrib, -R, %to%
            if (!copied || ErrorLevel) {
                MsgBox, 16, AHK FOR GOS, Не удалось перенести настройки: %from%
                ExitApp, 2
            }
        }
    }
    return true
}

AppHost_DataDir() {
    global AppDataRoot
    return AppDataRoot != "" ? AppDataRoot : A_ScriptDir
}

AppHost_ResourceText(name, encoding := "CP1251") {
    module := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
    resource := DllCall("FindResourceW", "Ptr", module, "WStr", name, "Ptr", 10, "Ptr")
    if !resource
        return ""
    size := DllCall("SizeofResource", "Ptr", module, "Ptr", resource, "UInt")
    loaded := DllCall("LoadResource", "Ptr", module, "Ptr", resource, "Ptr")
    address := loaded ? DllCall("LockResource", "Ptr", loaded, "Ptr") : 0
    return address && size ? StrGet(address, size, encoding) : ""
}

AppHost_LawPath(name) {
    if !RegExMatch(name, "i)^[a-z0-9_]+\.txt$")
        return ""
    override := AppHost_DataDir() . "\laws\" . name
    return FileExist(override) ? override : A_ScriptDir . "\laws\" . name
}

AppHost_ReadLaw(name) {
    path := AppHost_LawPath(name)
    if (path = "")
        return ""
    if (FileExist(path) && !AppHost_UseUpdatedBundledLaw(name, path)) {
        FileRead, text, %path%
        return ErrorLevel ? "" : text
    }
    StringUpper, key, name
    return A_IsCompiled ? AppHost_ResourceText("LAW_" . StrReplace(key, ".TXT")) : ""
}

; Upgrade only byte-identical previous distribution files. Edited overrides stay
; authoritative and no user file is deleted, renamed or overwritten.
AppHost_UseUpdatedBundledLaw(name, path) {
    if (!A_IsCompiled || !FileExist(path))
        return false
    return AppHost_PreviousLawDigest(name) != "" && AppHost_IsPreviousLawDigest(name, FileSHA256(path))
}

AppHost_IsPreviousLawDigest(name, hash) {
    expected := AppHost_PreviousLawDigest(name)
    return expected != "" && hash = expected
}

AppHost_PreviousLawDigest(name) {
    static previous := ""
    if !IsObject(previous) {
        previous := {}
        previous["FSB.txt"] := "6EAA0F28AB6E270A3FB7D73CADFCD05A8E110E6BE6B528594CBA2BBBAD19E555"
        previous["FZOP.txt"] := "34A760908D8C2E2022066C66E606B35B831FA91A33F699678698F176F416BE14"
        previous["KOAP.txt"] := "4FA7D1A437C193E0F7DA395776DC6EACAE134062E8367629F2E83DEA73F1EE38"
        previous["KON.txt"] := "4C73783AAEDC924D03D658FD36CD154055BEB65C446EFAF2D405B0A1D668ED1C"
        previous["ORUZH.txt"] := "8E9765A2DA6362F658D7075BF6D80CCD73046D835A0D43CE24FC2CEA24B3E5ED"
        previous["TER.txt"] := "DA888AE9498414B988825F54E8549D0EA35E4F4AC98AA0DB70D5BFC7C3F822D2"
        previous["UK.txt"] := "CBF60893BD24045A20392E7CE1505F6F2B58039F5C4839CDFE789401897AA27E"
    }
    return previous.HasKey(name) ? previous[name] : ""
}

AppHost_AssetPath(name) {
    if InStr(name, "..")
        return ""
    relative := "\assets\law_maps\" . name
    own := AppHost_DataDir() . relative
    return FileExist(own) ? own : A_ScriptDir . relative
}

AppHost_SourceText() {
    if (A_IsCompiled)
        return AppHost_ResourceText("SOURCE_MAIN")
    seen := {}
    return AppHost_ExpandSource(A_ScriptFullPath, seen)
}

AppHost_ExpandSource(path, ByRef seen) {
    if (seen.HasKey(path))
        return ""
    seen[path] := true
    FileRead, text, %path%
    if (ErrorLevel)
        return ""
    result := ""
    Loop, Parse, text, `n, `r
    {
        line := A_LoopField
        if RegExMatch(line, "i)^\s*#include\s+(.+)$", match) {
            include := StrReplace(Trim(match1), "%A_ScriptDir%", A_ScriptDir)
            if (!AppHost_IsAbsolutePath(include))
                include := A_ScriptDir . "\" . include
            if !InStr(FileExist(include), "D")
                result .= AppHost_ExpandSource(include, seen) . "`r`n"
        } else
            result .= line . "`r`n"
    }
    return result
}

AppHost_SourceFile(path) {
    SplitPath, path, name
    StringUpper, name, name
    if (path = A_ScriptFullPath)
        return AppHost_SourceText()
    if RegExMatch(path, "i)[\\/]laws[\\/]([a-z0-9_]+\.txt)$", law)
        return AppHost_ReadLaw(law1)
    if (A_IsCompiled && RegExMatch(name, "i)\.ahk$"))
        return AppHost_ResourceText("SOURCE_" . name)
    FileRead, text, %path%
    return ErrorLevel ? "" : text
}

AppHost_Shutdown() {
    global AppInstanceMutex, PendingToolHandle, PendingToolPid
    if (PendingToolHandle) {
        if (DllCall("GetExitCodeProcess", "Ptr", PendingToolHandle, "UInt*", exitCode) && exitCode = 259) {
            DllCall("TerminateProcess", "Ptr", PendingToolHandle, "UInt", 2)
            DllCall("WaitForSingleObject", "Ptr", PendingToolHandle, "UInt", 1500)
        }
        DllCall("CloseHandle", "Ptr", PendingToolHandle)
        PendingToolHandle := 0
    }
    PendingToolPid := 0
    if (AppInstanceMutex) {
        DllCall("ReleaseMutex", "Ptr", AppInstanceMutex)
        DllCall("CloseHandle", "Ptr", AppInstanceMutex)
        AppInstanceMutex := 0
    }
}

AppHost_RuntimeInfo() {
    ; ASCII probe is usable even on a Windows ANSI codepage other than 1251.
    report := "Product=AHK FOR GOS`r`nCompiled=" . (A_IsCompiled ? 1 : 0) . "`r`n"
    report .= "Runtime=" . A_AhkVersion . "`r`nPointerSize=" . A_PtrSize . "`r`nUnicode=" . (A_IsUnicode ? 1 : 0) . "`r`n"
    report .= "SystemCodepage=" . DllCall("GetACP") . "`r`nDataDir=" . AppHost_DataDir() . "`r`n"
    hasSource := InStr(AppHost_SourceText(), "AutoTargetID_Poll() {") > 0
    laws := 0, bundledMatches := 0
    for _, name in ["VU", "FP", "KON", "FZOP", "TER", "TK", "ARG", "UK", "VV", "KOAP", "PDD", "ORUZH", "UPK", "KAS", "FSB", "FSIN", "VS", "SUD", "ORD", "GT"] {
        activeText := AppHost_ReadLaw(name . ".txt")
        if (StrLen(activeText) > 100)
            laws++
        if (A_IsCompiled && activeText == AppHost_ResourceText("LAW_" . name))
            bundledMatches++
    }
    report .= "SourceIntrospection=" . hasSource . "`r`nLawDocuments=" . laws . "`r`n"
    report .= "LawBundleReceived=2026-10-19`r`nLawBundledMatches=" . bundledMatches . "`r`n"
    report .= "GameCompatibility=NOT_TESTED`r`nOBSFrames=NOT_TESTED`r`n"
    report .= "CyrillicLegacyRequirement=Windows system ANSI codepage 1251`r`n"
    path := AppHost_DataDir() . "\runtime_info_report.txt"
    FileDelete, %path%
    FileAppend, %report%, %path%, UTF-8
    return !ErrorLevel && hasSource && laws = 20
}

AppHost_ExportLicenses() {
    folder := AppHost_DataDir() . "\licenses"
    FileCreateDir, %folder%
    for _, entry in [{Key: "LICENSE_PROJECT", File: "Project-MIT.txt"}, {Key: "LICENSE_ENGINE", File: "AutoHotkey-GPL-2.0.txt"}] {
        text := AppHost_ResourceText(entry.Key, "UTF-8")
        if (!A_IsCompiled || text = "")
            return false
        path := folder . "\" . entry.File
        FileDelete, %path%
        FileAppend, %text%, %path%, UTF-8
        if (ErrorLevel)
            return false
    }
    return true
}

AppHost_SpawnDiagnostic(command, ByRef processHandle, ByRef processID) {
    processHandle := 0, processID := 0
    startupSize := A_PtrSize = 8 ? 104 : 68
    infoSize := A_PtrSize = 8 ? 24 : 16
    VarSetCapacity(startup, startupSize, 0)
    VarSetCapacity(info, infoSize, 0)
    NumPut(startupSize, startup, 0, "UInt")
    NumPut(1, startup, A_PtrSize = 8 ? 60 : 44, "UInt") ; STARTF_USESHOWWINDOW, SW_HIDE
    chars := StrPut(command, "UTF-16")
    VarSetCapacity(buffer, chars * 2, 0)
    StrPut(command, &buffer, chars, "UTF-16")
    ok := DllCall("CreateProcessW", "Ptr", 0, "Ptr", &buffer, "Ptr", 0, "Ptr", 0
        , "Int", 0, "UInt", 0x08000000, "Ptr", 0, "WStr", A_ScriptDir
        , "Ptr", &startup, "Ptr", &info, "Int")
    if (!ok)
        return false
    processHandle := NumGet(info, 0, "Ptr")
    threadHandle := NumGet(info, A_PtrSize, "Ptr")
    processID := NumGet(info, A_PtrSize * 2, "UInt")
    DllCall("CloseHandle", "Ptr", threadHandle)
    return processHandle && processID
}


AppHost_ShowReport(path, exitCode := 0) {
    file := FileOpen(path, "r")
    if !IsObject(file)
        return false
    try {
        text := file.Read(262144)
        if !file.AtEOF
            text .= "`r`n`r`nПоказан фрагмент; полный отчёт сохранён в указанном файле."
    } finally {
        file.Close()
    }
    text := "Файл: " . path . "`r`nКод завершения проверки: " . exitCode . "`r`n`r`n" . text
    return ServiceUI_ShowDetails("Результат проверки AHK FOR GOS", text, true)
}
