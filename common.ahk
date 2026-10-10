global MemoryInjectionOwnerActive := 0

global hGTA := 0x0
global dwGTAPID := 0x0
global dwSAMP := 0x0
global pMemory := 0x0
global pParam1 := 0x0
global pParam2 := 0x0
global pParam3 := 0x0
global pParam4 := 0x0
global pParam5 := 0x0
global pInjectFunc := 0x0
global iRefreshHandles := 0
global g_LastCheckHandlesResult := 0
global g_LastSampValidationTick := 0
global g_LastHandleValidationTick := 0
global g_HandleGeneration := 0
global g_HandleReopenCount := 0
global g_LastHandleError := ""
global ERROR_OK := 0
global ERROR_INVALID_HANDLE := 1
global ERROR_WAIT_FOR_OBJECT := 2
global ERROR_ALLOC_MEMORY := 3
global ERROR_FREE_MEMORY := 4
global ERROR_WRITE_MEMORY := 5
global ERROR_READ_MEMORY := 6
global ERROR_MODULE_NOT_FOUND := 7
global ERROR_ENUM_PROCESS_MODULES := 8
global ERROR_OPEN_PROCESS := 9
global ERROR_STRING_TOO_LONG := 10
global ERROR_MEMORY_BUSY := 11

global g_MemoryStage := "IDLE"
global g_MemoryStageCode := 0
global g_MemoryStageDetail := ""
global g_MemoryStageTick := 0
global g_MemoryInjectionBusy := 0

global GAME_MP_ModulePath := ""
global g_RemoteOperation := ""
global g_CompatibilityCache := ""
global g_ReadCompatibilityCache := ""
global ConfigWriteFailed := 0
global ConfigTransactionBusy := 0
global ConfigReadOnly := 0
global AutomationEpoch := 1
global PhysicalInputBusy := 0
global OBSHideWindows := "Off"
global CaptureWindowStates := {}
global AuditTestMode := 0

global GAME_MP_ModuleName := "azmp.dll"
global GAME_PID := "AMAZING ONLINE"

global GAME_WINDOW_TITLE := "AMAZING ONLINE"
global GAME_PROCESS_NAME := "gta_sa.exe"
global GAME_SELECTOR := "AMAZING ONLINE"
global GAME_DETECTION_SOURCE := ""

GameLocator_Configure(windowTitle, processName) {
    global GAME_WINDOW_TITLE, GAME_PROCESS_NAME, GAME_SELECTOR, GAME_PID
    global GAME_DETECTION_SOURCE, iRefreshHandles, g_LastCheckHandlesResult

    windowTitle := Trim(RegExReplace("" . windowTitle, "(`r|`n)+", " "))
    if (windowTitle = "")
        windowTitle := "AMAZING ONLINE"

    processName := Trim("" . processName)
    SplitPath, processName, processFileName
    if (processFileName != "")
        processName := processFileName
    if !RegExMatch(processName, "i)^[a-z0-9_.-]+\.exe$")
        processName := "gta_sa.exe"

    changed := (GAME_WINDOW_TITLE != windowTitle || GAME_PROCESS_NAME != processName)
    GAME_WINDOW_TITLE := windowTitle
    GAME_PROCESS_NAME := processName
    GAME_SELECTOR := windowTitle
    GAME_PID := windowTitle
    GAME_DETECTION_SOURCE := ""

    if (changed) {
        ReleaseGameHandle()
        iRefreshHandles := 0
        g_LastCheckHandlesResult := 0
    }
    return true
}

GameLocator_Find(ByRef pid, ByRef selector := "", ByRef source := "") {
    global GAME_WINDOW_TITLE, GAME_PROCESS_NAME, GAME_SELECTOR, GAME_PID, GAME_DETECTION_SOURCE

    pid := 0
    selector := ""
    source := ""
    windowTitle := Trim(GAME_WINDOW_TITLE)
    processName := Trim(GAME_PROCESS_NAME)

    if (windowTitle != "") {
        WinGet, titlePID, PID, %windowTitle%
        if (titlePID) {
            WinGet, titleProcessName, ProcessName, ahk_pid %titlePID%
            if (processName = "" || titleProcessName = processName) {
                pid := titlePID
                selector := "ahk_pid " . pid
                source := "title"
            }
        }
    }

    if (!pid && processName != "") {
        exeSelector := "ahk_exe " . processName
        WinGet, exePID, PID, %exeSelector%
        if (!exePID) {
            Process, Exist, %processName%
            exePID := ErrorLevel
        }
        if (exePID) {
            pid := exePID
            selector := "ahk_pid " . pid
            source := "exe"
        }
    }

    if (pid) {
        GAME_SELECTOR := selector
        GAME_PID := selector
        GAME_DETECTION_SOURCE := source
        return true
    }

    GAME_SELECTOR := windowTitle
    GAME_PID := windowTitle
    GAME_DETECTION_SOURCE := ""
    return false
}

GameLocator_GetPID() {
    pid := 0, selector := "", source := ""
    return GameLocator_Find(pid, selector, source) ? pid : 0
}

GameLocator_IsActive() {
    pid := 0, selector := "", source := ""
    if !GameLocator_Find(pid, selector, source)
        return false
    return WinActive(selector) ? true : false
}

GameLocator_Activate(timeoutSeconds := 0.7) {
    pid := 0, selector := "", source := ""
    if !GameLocator_Find(pid, selector, source)
        return false
    WinActivate, %selector%
    WinWaitActive, %selector%,, %timeoutSeconds%
    return ErrorLevel ? false : true
}

MemoryTickElapsed(startTick, nowTick := "") {
    if (nowTick = "")
        nowTick := TickNow()
    elapsed := nowTick - startTick
    if (elapsed < 0)
        elapsed += 4294967296
    return elapsed
}

MemoryGetStatusText() {
    global g_MemoryStage, g_MemoryStageCode, g_MemoryStageDetail
    text := (g_MemoryStage = "" ? "IDLE" : g_MemoryStage)
    if (g_MemoryStageCode)
        text .= " [" . g_MemoryStageCode . "]"
    if (g_MemoryStageDetail != "")
        text .= ": " . g_MemoryStageDetail
    return text
}

MemoryGetShortError() {
    global g_MemoryStageCode, g_MemoryStageDetail
    global ERROR_OK, ERROR_INVALID_HANDLE, ERROR_WAIT_FOR_OBJECT, ERROR_ALLOC_MEMORY
    global ERROR_FREE_MEMORY, ERROR_WRITE_MEMORY, ERROR_READ_MEMORY, ERROR_MODULE_NOT_FOUND
    global ERROR_ENUM_PROCESS_MODULES, ERROR_OPEN_PROCESS, ERROR_STRING_TOO_LONG, ERROR_MEMORY_BUSY

    code := g_MemoryStageCode + 0
    if (code = ERROR_OK)
        shortText := "ошибок нет"
    else if (code = ERROR_INVALID_HANDLE)
        shortText := "неверный дескриптор процесса"
    else if (code = ERROR_WAIT_FOR_OBJECT)
        shortText := "ошибка ожидания потока"
    else if (code = ERROR_ALLOC_MEMORY)
        shortText := "не удалось выделить память"
    else if (code = ERROR_FREE_MEMORY)
        shortText := "не удалось освободить память"
    else if (code = ERROR_WRITE_MEMORY)
        shortText := "ошибка записи памяти"
    else if (code = ERROR_READ_MEMORY)
        shortText := "ошибка чтения памяти"
    else if (code = ERROR_MODULE_NOT_FOUND)
        shortText := "azmp.dll не найден"
    else if (code = ERROR_ENUM_PROCESS_MODULES)
        shortText := "не удалось прочитать модули процесса"
    else if (code = ERROR_OPEN_PROCESS)
        shortText := "не удалось открыть процесс игры"
    else if (code = ERROR_STRING_TOO_LONG)
        shortText := "некорректная длина строки"
    else if (code = ERROR_MEMORY_BUSY)
        shortText := "модуль памяти занят"
    else
        shortText := "ошибка памяти " . code

    if (g_MemoryStageDetail != "")
        shortText .= ": " . g_MemoryStageDetail
    return shortText
}

GetFileVersionSafe(path) {
    if !FileExist(path)
        return ""
    FileGetVersion, version, %path%
    return ErrorLevel ? "" : version
}

FileSHA256(path) {
    provider := 0, hash := 0, file := "", digest := ""
    if !FileExist(path)
        return ""
    try {
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", provider, "WStr", "SHA256", "Ptr", 0, "UInt", 0, "Int")
            return ""
        VarSetCapacity(sizeBuffer, 4, 0)
        if DllCall("bcrypt\BCryptGetProperty", "Ptr", provider, "WStr", "ObjectLength", "Ptr", &sizeBuffer, "UInt", 4, "UInt*", copied, "UInt", 0, "Int")
            return ""
        VarSetCapacity(hashObject, NumGet(sizeBuffer, 0, "UInt"), 0)
        if DllCall("bcrypt\BCryptCreateHash", "Ptr", provider, "Ptr*", hash, "Ptr", &hashObject, "UInt", VarSetCapacity(hashObject), "Ptr", 0, "UInt", 0, "UInt", 0, "Int")
            return ""
        file := FileOpen(path, "r")
        if !IsObject(file)
            return ""
        VarSetCapacity(chunk, 65536, 0)
        while (!file.AtEOF) {
            count := file.RawRead(chunk, 65536)
            if (!count || DllCall("bcrypt\BCryptHashData", "Ptr", hash, "Ptr", &chunk, "UInt", count, "UInt", 0, "Int"))
                return ""
        }
        VarSetCapacity(result, 32, 0)
        if DllCall("bcrypt\BCryptFinishHash", "Ptr", hash, "Ptr", &result, "UInt", 32, "UInt", 0, "Int")
            return ""
        Loop, 32
            digest .= Format("{:02X}", NumGet(result, A_Index - 1, "UChar"))
        return digest
    } catch e {
        return ""
    } finally {
        if IsObject(file)
            file.Close()
        if (hash)
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hash, "Int")
        if (provider)
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", provider, "UInt", 0, "Int")
    }
}

ReleaseGameHandle() {
    global hGTA, dwGTAPID, dwSAMP, pMemory, pParam1, pParam2, pParam3, pParam4, pParam5, pInjectFunc
    global iRefreshHandles, g_LastCheckHandlesResult, g_MemoryInjectionBusy, g_LastSampValidationTick
    global g_LastHandleValidationTick

    if (g_MemoryInjectionBusy) {
        MemoryRemotePoll()
        if (g_MemoryInjectionBusy)
            return false
    }
    if (hGTA) {
        if (pMemory && ProcessHandleIsValid(hGTA, dwGTAPID))
            virtualFreeEx(hGTA, pMemory, 0, 0x8000)
        closeProcess(hGTA)
    }
    hGTA := 0
    dwGTAPID := 0
    dwSAMP := 0
    GAME_MP_ModulePath := ""
    g_CompatibilityCache := ""
    g_ReadCompatibilityCache := ""
    pMemory := 0
    pParam1 := 0
    pParam2 := 0
    pParam3 := 0
    pParam4 := 0
    pParam5 := 0
    pInjectFunc := 0
    iRefreshHandles := 0
    g_LastCheckHandlesResult := 0
    g_MemoryInjectionBusy := 0
    g_LastSampValidationTick := 0
    g_LastHandleValidationTick := 0
    if IsFunc("AZMP_ResetAutoIDRuntime")
        Func("AZMP_ResetAutoIDRuntime").Call("game handle released")
    else if IsFunc("AZMP_ResetTargetCache")
        Func("AZMP_ResetTargetCache").Call("game handle released")
    return true
}

IsLikelyPointer(address) {
    address += 0
    ; Amazing Online использует 32-битный gta_sa.exe с флагом
    ; LARGE_ADDRESS_AWARE. На 64-битной Windows его валидные адреса могут
    ; находиться выше 0x7FFFFFFF. Верхние 64 КиБ оставляем за системными
    ; sentinel-адресами, а фактическую читаемость подтверждает RPM.
    if (address < 0)
        address += 0x100000000
    return (address >= 0x10000 && address < 0xFFFF0000)
}

ProcessHandleIsValid(hProcess, expectedPID := 0) {
    if (!hProcess)
        return false

    handlePID := DllCall("GetProcessId", "UInt", hProcess, "UInt")
    if (!handlePID || (expectedPID && handlePID != expectedPID))
        return false

    exitCode := 0
    if !DllCall("GetExitCodeProcess", "UInt", hProcess, "UInt*", exitCode, "UInt")
        return false
    return (exitCode = 259) ? true : false ; STILL_ACTIVE
}

MemoryInvalidateGameHandle(reason := "") {
    global hGTA, dwGTAPID, dwSAMP, pMemory, pParam1, pParam2, pParam3, pParam4, pParam5, pInjectFunc
    global iRefreshHandles, g_LastCheckHandlesResult, g_MemoryInjectionBusy, g_LastSampValidationTick
    global g_LastHandleValidationTick, g_HandleReopenCount, g_LastHandleError

    if (g_MemoryInjectionBusy) {
        g_LastHandleError := "восстановление отложено: модуль памяти занят; " . reason
        MemorySetStage("HANDLE_RECOVERY_DEFERRED", ERROR_MEMORY_BUSY, g_LastHandleError)
        return false
    }

    oldHandle := hGTA
    oldPID := dwGTAPID
    if (oldHandle) {
        if (pMemory && ProcessHandleIsValid(oldHandle, oldPID))
            virtualFreeEx(oldHandle, pMemory, 0, 0x8000)
        closeProcess(oldHandle)
    }

    hGTA := 0
    dwGTAPID := 0
    dwSAMP := 0
    GAME_MP_ModulePath := ""
    g_CompatibilityCache := ""
    g_ReadCompatibilityCache := ""
    pMemory := 0
    pParam1 := 0
    pParam2 := 0
    pParam3 := 0
    pParam4 := 0
    pParam5 := 0
    pInjectFunc := 0
    iRefreshHandles := 0
    g_LastCheckHandlesResult := 0
    g_MemoryInjectionBusy := 0
    g_LastSampValidationTick := 0
    g_LastHandleValidationTick := TickNow()
    g_HandleReopenCount += 1
    g_LastHandleError := reason
    if IsFunc("AZMP_ResetAutoIDRuntime")
        Func("AZMP_ResetAutoIDRuntime").Call("handle invalidated: " . reason)
    else if IsFunc("AZMP_ResetTargetCache")
        Func("AZMP_ResetTargetCache").Call("handle invalidated: " . reason)
    if (reason != "")
        MemorySetStage("HANDLE_REOPEN", ERROR_INVALID_HANDLE, reason)
    return true
}

MemorySetStage(stage, code := 0, detail := "") {
    global g_MemoryStage, g_MemoryStageCode, g_MemoryStageDetail, g_MemoryStageTick
    g_MemoryStage := "" . stage
    g_MemoryStageCode := code + 0
    g_MemoryStageDetail := "" . detail
    g_MemoryStageTick := TickNow()
    ErrorLevel := g_MemoryStageCode
    return true
}

MemoryFail(stage, code, detail := "") {
    MemorySetStage(stage, code, detail)
    return false
}

MemoryInjectionEnter() {
    global g_MemoryInjectionBusy
    MemoryRemotePoll()
    oldCritical := A_IsCritical
    Critical, On
    if (g_MemoryInjectionBusy) {
        Critical, %oldCritical%
        ErrorLevel := ERROR_MEMORY_BUSY
        return false
    }
    g_MemoryInjectionBusy := 1
    MemoryInjectionOwnerActive := 1
    Critical, %oldCritical%
    return true
}

MemoryInjectionLeave() {
    global g_MemoryInjectionBusy, g_RemoteOperation
    MemoryInjectionOwnerActive := 0
    MemoryRemotePoll()
    if !IsObject(g_RemoteOperation)
        g_MemoryInjectionBusy := 0
    return !g_MemoryInjectionBusy
}

waitForSingleObject(hThread, dwMilliseconds) {
	if (!hThread) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwRet := DllCall("WaitForSingleObject", "UInt", hThread, "UInt", dwMilliseconds, "UInt")
	if (dwRet == 0xFFFFFFFF) {
		ErrorLevel := ERROR_WAIT_FOR_OBJECT
		return 0
	}

	ErrorLevel := ERROR_OK
	return dwRet
}
createRemoteThread(hProcess, lpThreadAttributes, dwStackSize, lpStartAddress, lpParameter, dwCreationFlags, lpThreadId) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwRet := DllCall("CreateRemoteThread", "UInt", hProcess, "UInt", lpThreadAttributes, "UInt", dwStackSize, "UInt", lpStartAddress, "UInt", lpParameter, "UInt", dwCreationFlags, "UInt", lpThreadId, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_ALLOC_MEMORY
		return 0
	}

	ErrorLevel := ERROR_OK
	return dwRet
}
virtualFreeEx(hProcess, lpAddress, dwSize, dwFreeType) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwRet := DllCall("VirtualFreeEx", "UInt", hProcess, "UInt", lpAddress, "UInt", dwSize, "UInt", dwFreeType, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_FREE_MEMORY
		return 0
	}
	ErrorLevel := ERROR_OK
	return dwRet
}
virtualAllocEx(hProcess, dwSize, flAllocationType, flProtect) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwRet := DllCall("VirtualAllocEx", "UInt", hProcess, "UInt", 0, "UInt", dwSize, "UInt", flAllocationType, "UInt", flProtect, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_ALLOC_MEMORY
		return 0
	}

	ErrorLevel := ERROR_OK
	return dwRet
}
callWithParams(hProcess, dwFunc, aParams, bCleanupStack = true, thiscall = false, waitThread = true) {
    global pInjectFunc, pParam1, pParam2, pParam3, pParam4, pParam5
    global ERROR_INVALID_HANDLE, ERROR_ALLOC_MEMORY, ERROR_WRITE_MEMORY, ERROR_WAIT_FOR_OBJECT, ERROR_OK
    if (!hProcess || !IsLikelyPointer(pInjectFunc) || !IsLikelyPointer(dwFunc)) {
        ErrorLevel := ERROR_INVALID_HANDLE
        return false
    }
    if !IsObject(aParams) {
        ErrorLevel := ERROR_WRITE_MEMORY
        return false
    }
    paramCount := aParams.MaxIndex()
    if (paramCount = "")
        paramCount := 0
    if (paramCount > 31) {
        ErrorLevel := ERROR_WRITE_MEMORY
        return false
    }

    instructionCount := 0
    stackParamCount := 0
    stringIndex := 1
    stringBuffers := [pParam1, pParam2, pParam3, pParam4, pParam5]
    VarSetCapacity(injectData, paramCount * 5 + 16, 0)
    i := paramCount
    while (i > 0) {
        param := aParams[i]
        if !IsObject(param) || param[1] = "" {
            i -= 1
            continue
        }
        paramType := param[1]
        paramValue := param[2]
        if (paramType = "p" || paramType = "i") {
            memoryAddress := paramValue + 0
        } else if (paramType = "s") {
            if (stringIndex > 5) {
                ErrorLevel := ERROR_WRITE_MEMORY
                return false
            }
            memoryAddress := stringBuffers[stringIndex]
            if !IsLikelyPointer(memoryAddress) {
                ErrorLevel := ERROR_ALLOC_MEMORY
                return false
            }
            if !writeString(hProcess, memoryAddress, paramValue)
                return false
            stringIndex += 1
        } else {
            ErrorLevel := ERROR_WRITE_MEMORY
            return false
        }

        codeOffset := instructionCount * 5
        if (thiscall && i = 1) {
            NumPut(0xB9, injectData, codeOffset, "UChar")
        } else {
            NumPut(0x68, injectData, codeOffset, "UChar")
            stackParamCount += 1
        }
        NumPut(memoryAddress, injectData, codeOffset + 1, "UInt")
        instructionCount += 1
        i -= 1
    }

    callOffset := instructionCount * 5
    relativeOffset := dwFunc - (pInjectFunc + callOffset + 5)
    NumPut(0xE8, injectData, callOffset, "UChar")
    NumPut(relativeOffset, injectData, callOffset + 1, "Int")
    codeLength := callOffset + 5
    if (bCleanupStack && stackParamCount > 0) {
        NumPut(0xC483, injectData, codeLength, "UShort")
        NumPut(stackParamCount * 4, injectData, codeLength + 2, "UChar")
        codeLength += 3
    }
    NumPut(0xC2, injectData, codeLength, "UChar")
    NumPut(4, injectData, codeLength + 1, "UShort")
    codeLength += 3

    if !writeRaw(hProcess, pInjectFunc, &injectData, codeLength)
        return false
    if !DllCall("FlushInstructionCache", "Ptr", hProcess, "Ptr", pInjectFunc, "UPtr", codeLength)
        return MemoryFail("FLUSH_CODE", ERROR_WRITE_MEMORY)
    hThread := createRemoteThread(hProcess, 0, 0, pInjectFunc, 0, 0, 0)
    if (!hThread)
        return false

    return MemoryWaitRemote(hThread, hProcess, waitThread ? 2000 : 0)

}

writeRaw(hProcess, dwAddress, pBuffer, dwLen) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return false
	}

	dwRet := DllCall("WriteProcessMemory", "UInt", hProcess, "UInt", dwAddress, "UInt", pBuffer, "UInt", dwLen, "UInt", 0, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_WRITE_MEMORY
		return false
	}

	ErrorLevel := ERROR_OK
	return true
}
writeString(hProcess, dwAddress, wString) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return false
	}

	sString := wString
	if (A_IsUnicode)
		sString := __unicodeToAnsi(wString)

	dwRet := DllCall("WriteProcessMemory", "UInt", hProcess, "UInt", dwAddress, "Str", sString, "UInt", StrLen(sString) + 1, "UInt", 0, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_WRITE_MEMORY
		return false
	}

	ErrorLevel := ERROR_OK
	return true
}
readDWORD(hProcess, dwAddress) {
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	VarSetCapacity(dwRead, 4, 0)
	dwRet := DllCall("ReadProcessMemory", "UInt", hProcess, "UInt", dwAddress, "Str", dwRead, "UInt", 4, "UInt*", 0)
	if (dwRet == 0) {
		ErrorLevel := ERROR_READ_MEMORY
		return 0
	}

	ErrorLevel := ERROR_OK
	return NumGet(dwRead, 0, "UInt")
}
readFloat(hProcess, dwAddress) {
    return TryReadFloat(hProcess, dwAddress, value) ? value : ""
}
getModuleBaseAddress(sModule, hProcess) {
    global GAME_MP_ModulePath, GAME_MP_ModuleName
    if (!sModule || !hProcess) {
        ErrorLevel := ERROR_INVALID_HANDLE
        return 0
    }
    capacity := 4096
    Loop, 3 {
        VarSetCapacity(modules, capacity, 0)
        needed := 0
        if !DllCall("psapi\EnumProcessModules", "Ptr", hProcess, "Ptr", &modules, "UInt", capacity, "UInt*", needed) {
            ErrorLevel := ERROR_ENUM_PROCESS_MODULES
            return 0
        }
        if (needed <= capacity)
            break
        if (needed > 1048576 || A_Index = 3) {
            ErrorLevel := ERROR_ENUM_PROCESS_MODULES
            return 0
        }
        capacity := needed + 1024
    }
    count := needed // A_PtrSize
    Loop % count {
        module := NumGet(modules, (A_Index - 1) * A_PtrSize, "Ptr")
        VarSetCapacity(path, 32768, 0)
        chars := DllCall("psapi\GetModuleFileNameExA", "Ptr", hProcess, "Ptr", module, "Str", path, "UInt", 32768, "UInt")
        if (!chars || chars >= 32768)
            continue
        SplitPath, path, name
        if (name = sModule) {
            if (name = GAME_MP_ModuleName)
                GAME_MP_ModulePath := path
            ErrorLevel := ERROR_OK
            return module
        }
    }
    ErrorLevel := ERROR_MODULE_NOT_FOUND
    return 0
}
closeProcess(hProcess) {
	if (hProcess == 0) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwRet := DllCall("CloseHandle", "Uint", hProcess, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}
	ErrorLevel := ERROR_OK
	return 1
}
openProcess(dwPID, dwRights = 0x10043A) {
	hProcess := DllCall("OpenProcess", "UInt", dwRights, "int",  0, "UInt", dwPID, "Uint")
	if (hProcess == 0) {
		ErrorLevel := ERROR_OPEN_PROCESS
		return 0
	}

	ErrorLevel := ERROR_OK
	return hProcess
}
refreshMemory() {
	if (!pMemory) {
		pMemory	 := virtualAllocEx(hGTA, 6144, 0x1000 | 0x2000, 0x40)
		if (ErrorLevel) {
			pMemory := 0x0
			return false
		}
		pParam1	:= pMemory
		pParam2	:= pMemory + 1024
		pParam3 := pMemory + 2048
		pParam4	:= pMemory + 3072
		pParam5	:= pMemory + 4096
		pInjectFunc := pMemory + 5120
	}
	return true
}
refreshSAMP(forceValidation := false) {
    global dwSAMP, hGTA, GAME_MP_ModuleName, g_LastSampValidationTick

    if (dwSAMP && !forceValidation)
        return true

    newBase := getModuleBaseAddress(GAME_MP_ModuleName, hGTA)
    if (!newBase) {
        dwSAMP := 0
    GAME_MP_ModulePath := ""
    g_CompatibilityCache := ""
    g_ReadCompatibilityCache := ""
        g_LastSampValidationTick := TickNow()
        if IsFunc("AZMP_ResetAutoIDRuntime")
            Func("AZMP_ResetAutoIDRuntime").Call("azmp.dll unavailable")
        else if IsFunc("AZMP_ResetTargetCache")
            Func("AZMP_ResetTargetCache").Call("azmp.dll unavailable")
        return false
    }

    if (dwSAMP && dwSAMP != newBase) {
        if IsFunc("AZMP_ResetAutoIDRuntime")
            Func("AZMP_ResetAutoIDRuntime").Call("azmp.dll base changed")
        else if IsFunc("AZMP_ResetTargetCache")
            Func("AZMP_ResetTargetCache").Call("azmp.dll base changed")
    }
    dwSAMP := newBase
    g_LastSampValidationTick := TickNow()
    return true
}
refreshGTA() {
    global hGTA, dwGTAPID, dwSAMP, pMemory
    global pParam1, pParam2, pParam3, pParam4, pParam5, pInjectFunc
    global g_LastHandleValidationTick, g_HandleGeneration, g_LastHandleError

    newPID := 0, gameSelector := "", locatorSource := ""
    GameLocator_Find(newPID, gameSelector, locatorSource)
    if (!newPID) {
        if (hGTA)
            MemoryInvalidateGameHandle("процесс игры не найден")
        return false
    }

    ; Раньше ненулевой, но уже закрытый/испорченный hGTA считался рабочим навсегда.
    ; Это вызывало отказ Auto ID до полного перезапуска AHK.
    if (hGTA && dwGTAPID = newPID && !ProcessHandleIsValid(hGTA, newPID))
        MemoryInvalidateGameHandle("дескриптор GTA стал недействительным")

    if (hGTA && dwGTAPID != newPID)
        MemoryInvalidateGameHandle("PID GTA изменился с " . dwGTAPID . " на " . newPID)

    if (!hGTA) {
        hGTA := openProcess(newPID)
        if (!hGTA || ErrorLevel) {
            g_LastHandleError := "OpenProcess не открыл PID " . newPID
            dwGTAPID := 0
            hGTA := 0
            dwSAMP := 0
    GAME_MP_ModulePath := ""
    g_CompatibilityCache := ""
    g_ReadCompatibilityCache := ""
            pMemory := 0
            MemoryFail("OPEN_PROCESS", ERROR_OPEN_PROCESS, g_LastHandleError)
            return false
        }
        dwGTAPID := newPID
        dwSAMP := 0
    GAME_MP_ModulePath := ""
    g_CompatibilityCache := ""
    g_ReadCompatibilityCache := ""
        pMemory := 0
        pParam1 := 0
        pParam2 := 0
        pParam3 := 0
        pParam4 := 0
        pParam5 := 0
        pInjectFunc := 0
        g_HandleGeneration += 1
        g_LastHandleError := ""
        MemorySetStage("HANDLE_OK", 0, "GTA PID " . newPID . ", поколение " . g_HandleGeneration)
    }

    g_LastHandleValidationTick := TickNow()
    return ProcessHandleIsValid(hGTA, dwGTAPID)
}

checkHandles() {
    global iRefreshHandles, g_LastCheckHandlesResult, g_LastSampValidationTick
    global hGTA, dwGTAPID

    if (iRefreshHandles != 0 && MemoryTickElapsed(iRefreshHandles) < 500) {
        if (g_LastCheckHandlesResult && !ProcessHandleIsValid(hGTA, dwGTAPID)) {
            MemoryInvalidateGameHandle("кэш checkHandles содержал недействительный hGTA")
        } else {
            return g_LastCheckHandlesResult && MemoryBuildCompatible()
        }
    }

    refreshTick := TickNow()
    forceModuleValidation := (g_LastSampValidationTick = 0
        || MemoryTickElapsed(g_LastSampValidationTick) >= 2000)

    g_LastCheckHandlesResult := (refreshGTA()
        && refreshSAMP(forceModuleValidation)
        && MemoryBuildCompatible()
        && refreshMemory())
    ; MemoryInvalidateGameHandle сбрасывает iRefreshHandles, поэтому метка
    ; успешной/неуспешной проверки ставится после полного восстановления.
    iRefreshHandles := refreshTick
    return g_LastCheckHandlesResult
}

; Read-only discovery never calls refreshMemory or launches game code. An explicit
; build hash remains mandatory for writes/injection via the unchanged checkHandles.
checkReadHandles() {
    global hGTA, dwGTAPID, dwSAMP, g_HandleGeneration, g_LastSampValidationTick
    global GAME_MP_ModulePath, AzmpExpectedSHA256, g_ReadCompatibilityCache
    expected := Trim(AzmpExpectedSHA256)
    StringUpper, expected, expected
    if (expected != "" && !RegExMatch(expected, "^[A-F0-9]{64}$"))
        return MemoryFail("READ_BUILD_INVALID", ERROR_MODULE_NOT_FOUND, "Некорректный ожидаемый SHA-256; чтение цели заблокировано.")
    key := dwGTAPID . "|" . g_HandleGeneration . "|" . dwSAMP . "|" . expected
    if (IsObject(g_ReadCompatibilityCache) && g_ReadCompatibilityCache.Key = key
        && MemoryTickElapsed(g_ReadCompatibilityCache.Tick) < 500
        && ProcessHandleIsValid(hGTA, dwGTAPID))
        return g_ReadCompatibilityCache.Ready
    forceModule := !g_LastSampValidationTick || MemoryTickElapsed(g_LastSampValidationTick) >= 2000
    if !(refreshGTA() && refreshSAMP(forceModule))
        return false
    if (!MemoryReadModuleIsX86(hGTA, dwSAMP))
        return MemoryFail("READ_LAYOUT_INVALID", ERROR_MODULE_NOT_FOUND, "azmp.dll не является читаемым модулем PE x86 с ожидаемым диапазоном данных.")
    ; No hash is inferred or learned from an unknown build. Only structural reads
    ; are allowed when expected is empty; the caller must validate pool/PED links.
    allowed := MemoryReadBuildPolicy(expected, true, expected = "" ? false : MemoryBuildCompatible())
    key := dwGTAPID . "|" . g_HandleGeneration . "|" . dwSAMP . "|" . expected
    g_ReadCompatibilityCache := {Key: key, Tick: TickNow(), Ready: allowed}
    return allowed
}

MemoryReadBuildPolicy(expected, moduleX86, hashMatches := false) {
    expected := Trim(expected)
    return moduleX86 && (expected = "" || (RegExMatch(expected, "i)^[A-F0-9]{64}$") && hashMatches))
}

MemoryReadModuleIsX86(process, base) {
    if (!process || !IsLikelyPointer(base))
        return false
    VarSetCapacity(header, 4096, 0)
    bytes := 0
    if (!DllCall("ReadProcessMemory", "Ptr", process, "Ptr", base, "Ptr", &header
        , "UPtr", 4096, "UPtr*", bytes) || bytes != 4096)
        return false
    imageBase := base < 0 ? base + 0x100000000 : base
    return MemoryReadPe32Header(header, bytes)
        && imageBase + NumGet(header, NumGet(header, 0x3C, "UInt") + 80, "UInt") <= 0x100000000
}

MemoryReadPe32Header(ByRef header, bytes) {
    if (bytes < 64 || VarSetCapacity(header) < bytes || NumGet(header, 0, "UShort") != 0x5A4D)
        return false
    pe := NumGet(header, 0x3C, "UInt")
    if (pe < 64 || pe > bytes - 120 || NumGet(header, pe, "UInt") != 0x4550
        || NumGet(header, pe + 4, "UShort") != 0x14C
        || !(NumGet(header, pe + 22, "UShort") & 0x2000)
        || NumGet(header, pe + 24, "UShort") != 0x10B)
        return false
    optionalBytes := NumGet(header, pe + 20, "UShort")
    imageSize := NumGet(header, pe + 24 + 56, "UInt")
    headerSize := NumGet(header, pe + 24 + 60, "UInt")
    return optionalBytes >= 96 && pe + 24 + optionalBytes <= bytes
        && imageSize >= 0x26E8F8 && imageSize <= 0x10000000
        && headerSize >= pe + 24 + optionalBytes && headerSize <= imageSize
}

HexToDec(str) {
	local newStr := ""
	static comp := {0:0, 1:1, 2:2, 3:3, 4:4, 5:5, 6:6, 7:7, 8:8, 9:9, "a":10, "b":11, "c":12, "d":13, "e":14, "f":15}
	StringLower, str, str
	str := RegExReplace(str, "^0x|[^a-f0-9]+", "")
	Loop, % StrLen(str)
		newStr .= SubStr(str, (StrLen(str)-A_Index)+1, 1)
	newStr := StrSplit(newStr, "")
	local ret := 0
	for i,char in newStr
		ret += comp[char]*(16**(i-1))
	return ret
}

__unicodeToAnsi(wString, nLen = 0) {
	pString := wString + 1 > 65536 ? wString : &wString
	if (!nLen) {
		nLen := DllCall("WideCharToMultiByte", "Uint", 0, "Uint", 0, "Uint", pString, "int",  -1, "Uint", 0, "int",  0, "Uint", 0, "Uint", 0)
	}
	VarSetCapacity(sString, nLen)
	DllCall("WideCharToMultiByte", "Uint", 0, "Uint", 0, "Uint", pString, "int",  -1, "str",  sString, "int",  nLen, "Uint", 0, "Uint", 0)
	return sString
}


TryReadFloat(hProcess, address, ByRef value) {
    value := ""
    VarSetCapacity(buffer, 4, 0)
    bytes := 0
    if (!hProcess || !IsLikelyPointer(address)
        || !DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buffer, "UPtr", 4, "UPtr*", bytes) || bytes != 4) {
        ErrorLevel := ERROR_READ_MEMORY
        return false
    }
    if ((NumGet(buffer, 0, "UInt") & 0x7F800000) = 0x7F800000) {
        ErrorLevel := ERROR_READ_MEMORY
        return false
    }
    value := NumGet(buffer, 0, "Float")
    ErrorLevel := ERROR_OK
    return true
}

MemoryBuildCompatible() {
    global GAME_MP_ModulePath, AzmpExpectedSHA256, dwGTAPID, dwSAMP, g_HandleGeneration, g_CompatibilityCache
    expected := Trim(AzmpExpectedSHA256)
    StringUpper, expected, expected
    if (!RegExMatch(expected, "^[A-F0-9]{64}$") || !FileExist(GAME_MP_ModulePath))
        return MemoryFail("BUILD_UNVERIFIED", ERROR_MODULE_NOT_FOUND, "Укажите SHA-256 проверенной совместимой сборки azmp.dll; доступ к смещениям отключён.")
    FileGetSize, size, %GAME_MP_ModulePath%
    FileGetTime, modified, %GAME_MP_ModulePath%, M
    key := dwGTAPID . "|" . g_HandleGeneration . "|" . dwSAMP . "|" . GAME_MP_ModulePath . "|" . size . "|" . modified . "|" . expected
    if (!IsObject(g_CompatibilityCache) || g_CompatibilityCache.Key != key)
        g_CompatibilityCache := {Key: key, Match: FileSHA256(GAME_MP_ModulePath) = expected}
    return g_CompatibilityCache.Match ? true : MemoryFail("BUILD_MISMATCH", ERROR_MODULE_NOT_FOUND, "SHA-256 azmp.dll не совпадает; чтение и запись заблокированы.")
}

MemoryWaitRemote(thread, process, timeoutMs := 2000) {
    global g_RemoteOperation, g_MemoryInjectionBusy
    g_RemoteOperation := {Thread: thread, Process: process, Started: TickNow(), ExitCode: 259}
    g_MemoryInjectionBusy := 1
    started := TickNow()
    Loop {
        result := MemoryRemotePoll()
        if (result != 0)
            return result = 1
        if (MemoryTickElapsed(started) >= timeoutMs) {
            MemoryFail("REMOTE_PENDING", ERROR_MEMORY_BUSY, "Поток ещё выполняется; буферы сохранены, повтор и Keyboard запрещены.")
            return false
        }
        Sleep, 10
    }
}

MemoryRemotePoll() {
    global g_RemoteOperation, g_MemoryInjectionBusy
    if !IsObject(g_RemoteOperation)
        return 0
    op := g_RemoteOperation
    state := DllCall("WaitForSingleObject", "Ptr", op.Thread, "UInt", 0, "UInt")
    if (state != 0 && ProcessHandleIsValid(op.Process))
        return 0
    exitCode := 0
    gotExit := DllCall("GetExitCodeThread", "Ptr", op.Thread, "UInt*", exitCode)
    if (op.HasKey("RestoreAddress") && ProcessHandleIsValid(op.Process)) {
        VarSetCapacity(restore, 4, 0)
        NumPut(op.RestoreValue, restore, 0, "UInt")
        writeRaw(op.Process, op.RestoreAddress, &restore, 4)
    }
    closeProcess(op.Thread)
    g_RemoteOperation := ""
    if (!MemoryInjectionOwnerActive)
        g_MemoryInjectionBusy := 0
    if (state = 0 && gotExit && exitCode < 0xC0000000) {
        MemorySetStage("REMOTE_COMPLETE", 0, "удалённый поток завершён; серверное подтверждение не проверено")
        return 1
    }
    MemoryFail("REMOTE_FAILED", ERROR_WAIT_FOR_OBJECT, "поток/процесс завершился с ошибкой")
    return -1
}

MemoryShutdown() {
    global g_RemoteOperation, hGTA
    MemoryRemotePoll()
    if IsObject(g_RemoteOperation) {
        ; Never free code still executing in the target. The target OS reclaims it at process exit.
        closeProcess(g_RemoteOperation.Thread)
        g_RemoteOperation := ""
        if (hGTA)
            closeProcess(hGTA)
        hGTA := 0
        return
    }
    ReleaseGameHandle()
}

TickNow() {
    return DllCall("GetTickCount64", "Int64")
}
