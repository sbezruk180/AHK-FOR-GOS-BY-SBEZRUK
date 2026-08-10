
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
        nowTick := A_TickCount
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
    if !FileExist(path)
        return ""
    tempFile := A_Temp . "\amz_gos_sha256_" . DllCall("GetCurrentProcessId") . "_" . A_TickCount . ".txt"
    command := ComSpec . " /d /c certutil -hashfile """ . path . """ SHA256 > """ . tempFile . """ 2>nul"
    RunWait, %command%,, Hide UseErrorLevel
    if (ErrorLevel) {
        FileDelete, %tempFile%
        return ""
    }
    FileRead, output, %tempFile%
    FileDelete, %tempFile%
    Loop, Parse, output, `n, `r
    {
        hashLine := RegExReplace(Trim(A_LoopField), "\s")
        if RegExMatch(hashLine, "i)^[a-f0-9]{64}$") {
            StringUpper, hashLine, hashLine
            return hashLine
        }
    }
    return ""
}

ReleaseGameHandle() {
    global hGTA, dwGTAPID, dwSAMP, pMemory, pParam1, pParam2, pParam3, pParam4, pParam5, pInjectFunc
    global iRefreshHandles, g_LastCheckHandlesResult, g_MemoryInjectionBusy, g_LastSampValidationTick
    global g_LastHandleValidationTick

    if (hGTA && ProcessHandleIsValid(hGTA, dwGTAPID)) {
        if (pMemory)
            virtualFreeEx(hGTA, pMemory, 0, 0x8000)
        closeProcess(hGTA)
    }
    hGTA := 0
    dwGTAPID := 0
    dwSAMP := 0
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
    if (oldHandle && ProcessHandleIsValid(oldHandle, oldPID)) {
        if (pMemory)
            virtualFreeEx(oldHandle, pMemory, 0, 0x8000)
        closeProcess(oldHandle)
    }

    hGTA := 0
    dwGTAPID := 0
    dwSAMP := 0
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
    g_LastHandleValidationTick := A_TickCount
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
    g_MemoryStageTick := A_TickCount
    ErrorLevel := g_MemoryStageCode
    return true
}

MemoryFail(stage, code, detail := "") {
    MemorySetStage(stage, code, detail)
    return false
}

MemoryInjectionEnter() {
    global g_MemoryInjectionBusy, ERROR_MEMORY_BUSY
    if (g_MemoryInjectionBusy) {
        ErrorLevel := ERROR_MEMORY_BUSY
        return false
    }
    g_MemoryInjectionBusy := 1
    return true
}

MemoryInjectionLeave() {
    global g_MemoryInjectionBusy
    g_MemoryInjectionBusy := 0
    return true
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
    NumPut(0xC3, injectData, codeLength, "UChar")
    codeLength += 1

    if !writeRaw(hProcess, pInjectFunc, &injectData, codeLength)
        return false
    hThread := createRemoteThread(hProcess, 0, 0, pInjectFunc, 0, 0, 0)
    if (!hThread)
        return false

    waitError := ERROR_OK
    if (waitThread) {
        waitForSingleObject(hThread, 0xFFFFFFFF)
        waitError := ErrorLevel
    }
    closeProcess(hThread)
    if (waitThread && waitError != ERROR_OK) {
        ErrorLevel := waitError
        return false
    }
    ErrorLevel := ERROR_OK
    return true
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
	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	VarSetCapacity(dwRead, 4, 0)
	dwRet := DllCall("ReadProcessMemory", "UInt", hProcess, "UInt", dwAddress, "Str", dwRead, "UInt", 4, "UInt*", 0, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_READ_MEMORY
		return 0
	}

	ErrorLevel := ERROR_OK
	return NumGet(dwRead, 0, "Float")
}
getModuleBaseAddress(sModule, hProcess) {
	if (!sModule) {
		ErrorLevel := ERROR_MODULE_NOT_FOUND
		return 0
	}

	if (!hProcess) {
		ErrorLevel := ERROR_INVALID_HANDLE
		return 0
	}

	dwSize = 1024*4
	VarSetCapacity(hMods, dwSize, 0)
	VarSetCapacity(cbNeeded, 4, 0)
	dwRet := DllCall("Psapi.dll\EnumProcessModules", "UInt", hProcess, "UInt", &hMods, "UInt", dwSize, "UInt*", cbNeeded, "UInt")
	if (dwRet == 0) {
		ErrorLevel := ERROR_ENUM_PROCESS_MODULES
		return 0
	}

	dwMods := cbNeeded / 4
	i := 0
	VarSetCapacity(hModule, 4, 0)
	VarSetCapacity(sCurModule, 260, 0)
	while(i < dwMods) {
		hModule := NumGet(hMods, i*4)
		DllCall("Psapi.dll\GetModuleFileNameEx", 	"UInt", hProcess, 	"UInt", hModule, 	"Str", sCurModule, 	"UInt", 260)
		SplitPath, sCurModule, sFilename
		if (sModule = sFilename) {
			ErrorLevel := ERROR_OK
			return hModule
		}
		i := i + 1
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
        g_LastSampValidationTick := A_TickCount
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
    g_LastSampValidationTick := A_TickCount
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
            pMemory := 0
            MemoryFail("OPEN_PROCESS", ERROR_OPEN_PROCESS, g_LastHandleError)
            return false
        }
        dwGTAPID := newPID
        dwSAMP := 0
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

    g_LastHandleValidationTick := A_TickCount
    return ProcessHandleIsValid(hGTA, dwGTAPID)
}

checkHandles() {
    global iRefreshHandles, g_LastCheckHandlesResult, g_LastSampValidationTick
    global hGTA, dwGTAPID

    if (iRefreshHandles != 0 && MemoryTickElapsed(iRefreshHandles) < 500) {
        if (g_LastCheckHandlesResult && !ProcessHandleIsValid(hGTA, dwGTAPID)) {
            MemoryInvalidateGameHandle("кэш checkHandles содержал недействительный hGTA")
        } else {
            return g_LastCheckHandlesResult
        }
    }

    refreshTick := A_TickCount
    forceModuleValidation := (g_LastSampValidationTick = 0
        || MemoryTickElapsed(g_LastSampValidationTick) >= 2000)

    g_LastCheckHandlesResult := (refreshGTA()
        && refreshSAMP(forceModuleValidation)
        && refreshMemory())
    ; MemoryInvalidateGameHandle сбрасывает iRefreshHandles, поэтому метка
    ; успешной/неуспешной проверки ставится после полного восстановления.
    iRefreshHandles := refreshTick
    return g_LastCheckHandlesResult
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
