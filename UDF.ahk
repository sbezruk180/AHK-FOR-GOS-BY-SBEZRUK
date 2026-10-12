#include common.ahk

global AZMP_SAMP_INFO_OFFSET := 0x26E8DC
global AZMP_POOLS_OFFSET := 0x3DE
global AZMP_PLAYER_POOL_OFFSET := 0x8
global AZMP_LABEL_POOL_OFFSET := 0x1C
global AZMP_PLAYER_INFO_ARRAY_OFFSET := 0x4
global AZMP_PLAYER_NOT_EMPTY_ARRAY_OFFSET := 0xFB4
global AZMP_PLAYER_INFO_REMOTE_OFFSET := 0x0
global AZMP_REMOTE_SAMP_PED_OFFSET := 0x0
global AZMP_SAMP_PED_GAME_OFFSET := 0x2A4 ; legacy-only, never trusted without GTA-pool validation
global AZMP_R3_PLAYER_DATA_OFFSET := 0x0
global AZMP_R3_ACTOR_OFFSET := 0x0
global AZMP_R3_ACTOR_GTA_PED_OFFSET := 0x40
global AZMP_R3_PED_GAME_OFFSET := 0x2A4
global GTA_PED_POOL_POINTER_ADDRESS := 0xB74490
global GTA_PED_POOL_OBJECT_SIZE := 0x7C4
global AZMP_LABEL_SIZE := 0x1D
global AZMP_LABEL_ACTIVE_ARRAY_OFFSET := 0xE800
global AZMP_MAX_LABELS := 2048
global AZMP_INVALID_ID := 0xFFFF

global AZMP_LEGACY_REMOTE_DATA_OFFSET := 0x8
global AZMP_LEGACY_ACTOR_OFFSET := 0x4
global AZMP_LEGACY_PED_OFFSET := 0x40
global AZMP_MAX_PLAYERS := 1004
global AZMP_TARGET_CACHE_PED := 0
global AZMP_TARGET_CACHE_ID := -1
global AZMP_TARGET_CACHE_TICK := 0
global AZMP_TARGET_CACHE_POOL := 0
global AZMP_TARGET_CACHE_INFO := 0
global AZMP_TARGET_CACHE_PID := 0
global AZMP_TARGET_CACHE_TTL := 1000
global AZMP_TARGET_FALLBACK_LIMIT := 1.15
global AZMP_PED_LAYOUT_PREFERRED := ""
global AZMP_TARGET_DIAG_CODE := "INIT"
global AZMP_TARGET_DIAG_DETAIL := ""
global AZMP_TARGET_DIAG_TICK := 0
global AZMP_TARGET_DIAG_FIRST_TICK := 0
global AZMP_TARGET_DIAG_STREAK := 0
global AZMP_TARGET_DIAG_PED := 0
global AZMP_TARGET_DIAG_POOL := 0
global AZMP_TARGET_DIAG_PID := 0
global AZMP_TARGET_DIAG_LAST_LOG_TICK := 0
global AZMP_TARGET_DIAG_LAST_LOG_CODE := ""
global AZMP_TARGET_DIAG_LAST_RECOVER_TICK := 0
global AZMP_TARGET_DIAG_RECOVER_COUNT := 0
global AZMP_TARGET_DIAG_LAST_SOFT_REFRESH_TICK := 0
global AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT := 0
global AZMP_TARGET_RECOVERY_BUSY := 0
global AZMP_TARGET_RECOVERY_STATUS := ""
global AZMP_TARGET_LAST_SUCCESS_TICK := 0
global AZMP_TARGET_LAST_SUCCESS_ID := -1
global AZMP_TARGET_LAST_SUCCESS_PED := 0
global AZMP_AIM_FALLBACK_MAX_ANGLE := 8.0
global AZMP_AIM_FALLBACK_STRONG_ANGLE := 5.0
global AZMP_AIM_FALLBACK_MIN_GAP := 2.0
global AZMP_AIM_FALLBACK_TARGET_DISTANCE := 0.45
global AZMP_GTA_PED_POOL_CACHE_TICK := 0
global AZMP_GTA_PED_POOL_CACHE_PID := 0
global AZMP_GTA_PED_POOL_CACHE_PTR := 0
global AZMP_GTA_PED_POOL_CACHE_OBJECTS := 0
global AZMP_GTA_PED_POOL_CACHE_FLAGS := 0
global AZMP_GTA_PED_POOL_CACHE_SIZE := 0

AZMP_TickElapsed(startTick, nowTick := "") {
    if (nowTick = "")
        nowTick := TickNow()
    elapsed := nowTick - startTick
    if (elapsed < 0)
        elapsed += 4294967296
    return elapsed
}

AZMP_ResetTargetCache(reason := "") {
    global AZMP_TARGET_CACHE_PED, AZMP_TARGET_CACHE_ID, AZMP_TARGET_CACHE_TICK
    global AZMP_TARGET_CACHE_POOL, AZMP_TARGET_CACHE_INFO, AZMP_TARGET_CACHE_PID
    AZMP_TARGET_CACHE_PED := 0
    AZMP_TARGET_CACHE_ID := -1
    AZMP_TARGET_CACHE_TICK := 0
    AZMP_TARGET_CACHE_POOL := 0
    AZMP_TARGET_CACHE_INFO := 0
    AZMP_TARGET_CACHE_PID := 0
    if (reason != "")
        MemorySetStage("TARGET_CACHE_RESET", 0, reason)
    return true
}

AZMP_CacheTarget(targetPed, playerId, playerInfo, playerPool) {
    global AZMP_TARGET_CACHE_PED, AZMP_TARGET_CACHE_ID, AZMP_TARGET_CACHE_TICK
    global AZMP_TARGET_CACHE_POOL, AZMP_TARGET_CACHE_INFO, AZMP_TARGET_CACHE_PID
    global dwGTAPID
    Critical, 30
    AZMP_TARGET_CACHE_PED := targetPed
    AZMP_TARGET_CACHE_ID := playerId
    AZMP_TARGET_CACHE_TICK := TickNow()
    AZMP_TARGET_CACHE_POOL := playerPool
    AZMP_TARGET_CACHE_INFO := playerInfo
    AZMP_TARGET_CACHE_PID := dwGTAPID
    Critical, Off
    return true
}

AZMP_TargetDiagSet(code, detail := "", isFailure := 1, forceLog := 0) {
    global AZMP_TARGET_DIAG_CODE, AZMP_TARGET_DIAG_DETAIL, AZMP_TARGET_DIAG_TICK
    global AZMP_TARGET_DIAG_FIRST_TICK, AZMP_TARGET_DIAG_STREAK
    global AZMP_TARGET_DIAG_LAST_LOG_TICK, AZMP_TARGET_DIAG_LAST_LOG_CODE

    code := Trim(code)
    if (code = "")
        code := "UNKNOWN"
    if (isFailure) {
        ; Серия относится только к свежим подряд идущим отказам. Старый код
        ; больше не может спустя минуты запустить восстановление другой цели.
        sameRecentFailure := (AZMP_TARGET_DIAG_CODE = code
            && AZMP_TARGET_DIAG_TICK != 0
            && AZMP_TickElapsed(AZMP_TARGET_DIAG_TICK) <= 2500)
        if (sameRecentFailure) {
            AZMP_TARGET_DIAG_STREAK += 1
        } else {
            AZMP_TARGET_DIAG_STREAK := 1
            AZMP_TARGET_DIAG_FIRST_TICK := TickNow()
        }
    } else {
        AZMP_TARGET_DIAG_STREAK := 0
        AZMP_TARGET_DIAG_FIRST_TICK := 0
    }
    AZMP_TARGET_DIAG_CODE := code
    AZMP_TARGET_DIAG_DETAIL := detail
    AZMP_TARGET_DIAG_TICK := TickNow()

    shouldLog := forceLog || AZMP_TARGET_DIAG_LAST_LOG_CODE != code
        || AZMP_TickElapsed(AZMP_TARGET_DIAG_LAST_LOG_TICK) >= 5000
    if (shouldLog) {
        AZMP_TARGET_DIAG_LAST_LOG_CODE := code
        AZMP_TARGET_DIAG_LAST_LOG_TICK := TickNow()
        if IsFunc("LogError")
            Func("LogError").Call("AutoID/" . code, detail, isFailure ? "WARN" : "INFO")
    }
    return code
}

AZMP_TargetDiagSetContext(targetPed := 0, playerPool := 0) {
    global AZMP_TARGET_DIAG_CODE, AZMP_TARGET_DIAG_DETAIL, AZMP_TARGET_DIAG_TICK
    global AZMP_TARGET_DIAG_FIRST_TICK, AZMP_TARGET_DIAG_STREAK
    global AZMP_TARGET_DIAG_PED, AZMP_TARGET_DIAG_POOL, AZMP_TARGET_DIAG_PID
    global dwGTAPID

    targetPed += 0
    playerPool += 0
    currentPID := dwGTAPID + 0
    if (AZMP_TARGET_DIAG_PED != targetPed || AZMP_TARGET_DIAG_POOL != playerPool
        || AZMP_TARGET_DIAG_PID != currentPID)
    {
        AZMP_TARGET_DIAG_CODE := "INIT"
        AZMP_TARGET_DIAG_DETAIL := ""
        AZMP_TARGET_DIAG_TICK := 0
        AZMP_TARGET_DIAG_FIRST_TICK := 0
        AZMP_TARGET_DIAG_STREAK := 0
    }
    AZMP_TARGET_DIAG_PED := targetPed
    AZMP_TARGET_DIAG_POOL := playerPool
    AZMP_TARGET_DIAG_PID := currentPID
    return true
}

AZMP_TargetDiagIsCurrent(targetPed := 0, maxAge := 750) {
    global AZMP_TARGET_DIAG_TICK, AZMP_TARGET_DIAG_PED, AZMP_TARGET_DIAG_PID
    global dwGTAPID
    if (AZMP_TARGET_DIAG_TICK = 0 || AZMP_TickElapsed(AZMP_TARGET_DIAG_TICK) > maxAge)
        return false
    if (targetPed && AZMP_TARGET_DIAG_PED != targetPed)
        return false
    if (AZMP_TARGET_DIAG_PID && AZMP_TARGET_DIAG_PID != dwGTAPID)
        return false
    return true
}

AZMP_TargetDiagGetStreak() {
    global AZMP_TARGET_DIAG_STREAK
    return AZMP_TARGET_DIAG_STREAK
}

AZMP_ResetTargetDiagnostics() {
    global AZMP_TARGET_DIAG_CODE, AZMP_TARGET_DIAG_DETAIL, AZMP_TARGET_DIAG_TICK
    global AZMP_TARGET_DIAG_FIRST_TICK, AZMP_TARGET_DIAG_STREAK
    global AZMP_TARGET_DIAG_PED, AZMP_TARGET_DIAG_POOL, AZMP_TARGET_DIAG_PID
    AZMP_TARGET_DIAG_CODE := "INIT"
    AZMP_TARGET_DIAG_DETAIL := ""
    AZMP_TARGET_DIAG_TICK := 0
    AZMP_TARGET_DIAG_FIRST_TICK := 0
    AZMP_TARGET_DIAG_STREAK := 0
    AZMP_TARGET_DIAG_PED := 0
    AZMP_TARGET_DIAG_POOL := 0
    AZMP_TARGET_DIAG_PID := 0
    return true
}

AZMP_TargetDiagGetCode() {
    global AZMP_TARGET_DIAG_CODE
    return AZMP_TARGET_DIAG_CODE
}

AZMP_TargetDiagGetDetail() {
    global AZMP_TARGET_DIAG_DETAIL
    return AZMP_TARGET_DIAG_DETAIL
}

AZMP_TargetDiagGetText() {
    global AZMP_TARGET_DIAG_CODE, AZMP_TARGET_DIAG_DETAIL, AZMP_TARGET_DIAG_STREAK
    return AZMP_TARGET_DIAG_CODE . " (серия " . AZMP_TARGET_DIAG_STREAK . ")"
        . ((AZMP_TARGET_DIAG_DETAIL != "") ? (": " . AZMP_TARGET_DIAG_DETAIL) : "")
}

AZMP_TargetDiagSuccess(playerId, targetPed, layout, name := "") {
    global AZMP_TARGET_LAST_SUCCESS_TICK, AZMP_TARGET_LAST_SUCCESS_ID, AZMP_TARGET_LAST_SUCCESS_PED
    global AZMP_PED_LAYOUT_PREFERRED
    AZMP_TARGET_LAST_SUCCESS_TICK := TickNow()
    AZMP_TARGET_LAST_SUCCESS_ID := playerId
    AZMP_TARGET_LAST_SUCCESS_PED := targetPed
    if (layout != "")
        AZMP_PED_LAYOUT_PREFERRED := layout
    AZMP_TargetDiagSet("TARGET_OK", "ID " . playerId . ", layout " . layout
        . ((name != "") ? (", nick " . name) : ""), 0)
}

AZMP_TargetDiagMaybeRecover(code, detail := "", force := 0) {
    global AZMP_TARGET_DIAG_STREAK, AZMP_TARGET_DIAG_LAST_RECOVER_TICK, AZMP_TARGET_DIAG_RECOVER_COUNT
    global AZMP_TARGET_RECOVERY_BUSY, AZMP_TARGET_RECOVERY_STATUS
    recoverable := (code = "HANDLE_INVALID" || code = "HANDLE_CHECK_FAILED"
        || code = "PLAYER_POOL_UNAVAILABLE" || code = "POOL_READ_INCOMPLETE"
        || code = "NO_VALID_PLAYER_INFO" || code = "NO_VALID_PEDS"
        || code = "TARGET_MANAGER_INVALID")
    if (!recoverable || (!force && AZMP_TARGET_DIAG_STREAK < 5))
        return false
    if (AZMP_TARGET_RECOVERY_BUSY) {
        AZMP_TARGET_RECOVERY_STATUS := "восстановление уже выполняется"
        return false
    }
    if (AZMP_TARGET_DIAG_LAST_RECOVER_TICK != 0
        && AZMP_TickElapsed(AZMP_TARGET_DIAG_LAST_RECOVER_TICK) < 30000)
    {
        AZMP_TARGET_RECOVERY_STATUS := "пауза между переоткрытиями памяти"
        return false
    }
    if !IsFunc("MemoryInvalidateGameHandle") {
        AZMP_TARGET_RECOVERY_STATUS := "безопасное переоткрытие памяти недоступно"
        return false
    }

    AZMP_TARGET_RECOVERY_BUSY := 1
    recovered := false
    recoveryStarted := false
    try {
        recoveryStarted := Func("MemoryInvalidateGameHandle").Call("Auto ID recovery " . code . ": " . detail)
        if (recoveryStarted) {
            AZMP_TARGET_DIAG_LAST_RECOVER_TICK := TickNow()
            AZMP_TARGET_DIAG_RECOVER_COUNT += 1
            Sleep, 25
            handleOk := checkReadHandles()
            playerPoolOk := handleOk && IsLikelyPointer(AZMP_GetPlayerPool())
            gtaPoolOk := handleOk && AZMP_GetGtaPedPoolInfo(recoverPool, recoverObjects, recoverFlags, recoverSize, 1)
            recovered := handleOk && playerPoolOk && gtaPoolOk
        }
        AZMP_TARGET_RECOVERY_STATUS := recovered
            ? "память, SA-MP player pool и GTA CPed pool переоткрыты"
            : (recoveryStarted ? "переоткрытие выполнено, но проверка пулов не пройдена"
                : "восстановление отложено: модуль памяти занят")
        AZMP_TargetDiagSet(recovered ? "AUTO_RECOVERY" : (recoveryStarted
            ? "AUTO_RECOVERY_REOPEN_FAILED" : "AUTO_RECOVERY_DEFERRED")
            , AZMP_TARGET_RECOVERY_STATUS . " после " . code
                . ", попытка " . AZMP_TARGET_DIAG_RECOVER_COUNT
            , recovered ? 0 : 1, 1)
    } finally {
        AZMP_TARGET_RECOVERY_BUSY := 0
    }
    return recovered
}

AZMP_TargetDiagGetRecoveryStatus() {
    global AZMP_TARGET_RECOVERY_STATUS
    return AZMP_TARGET_RECOVERY_STATUS
}

AZMP_TargetDiagMaybeRefreshNotInPool(targetPed, playerPool, detail := "") {
    global AZMP_TARGET_DIAG_FIRST_TICK, AZMP_TARGET_DIAG_STREAK
    global AZMP_TARGET_DIAG_LAST_SOFT_REFRESH_TICK, AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT
    global AZMP_PED_LAYOUT_PREFERRED

    if (AZMP_TARGET_DIAG_STREAK < 4 || AZMP_TARGET_DIAG_FIRST_TICK = 0
        || AZMP_TickElapsed(AZMP_TARGET_DIAG_FIRST_TICK) < 500)
        return false
    if !AZMP_TargetDiagIsCurrent(targetPed, 1000)
        return false
    if (AZMP_TARGET_DIAG_LAST_SOFT_REFRESH_TICK != 0
        && AZMP_TickElapsed(AZMP_TARGET_DIAG_LAST_SOFT_REFRESH_TICK) < 10000)
        return false

    AZMP_TARGET_DIAG_LAST_SOFT_REFRESH_TICK := TickNow()
    AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT += 1
    AZMP_ResetTargetCache("soft refresh after TARGET_NOT_IN_POOL")
    AZMP_ResetGtaPedPoolCache()
    AZMP_PED_LAYOUT_PREFERRED := ""
    moduleOk := IsFunc("refreshSAMP") ? Func("refreshSAMP").Call(true) : true
    gtaPoolOk := moduleOk && AZMP_GetGtaPedPoolInfo(softPool, softObjects, softFlags, softSize, 1)
    refreshedPlayerPool := moduleOk ? AZMP_GetPlayerPool() : 0
    refreshOk := moduleOk && gtaPoolOk && IsLikelyPointer(refreshedPlayerPool)
    refreshDetail := "soft refresh " . AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT
        . ": playerPool=" . refreshedPlayerPool . ", gtaPool=" . (gtaPoolOk ? 1 : 0)
        . ", target=" . Format("0x{:08X}", targetPed)
    MemorySetStage(refreshOk ? "TARGET_POOL_REFRESHED" : "TARGET_POOL_REFRESH_FAILED", 0, refreshDetail)
    if IsFunc("LogError")
        Func("LogError").Call("AutoID/TARGET_POOL_REFRESH", refreshDetail . "; " . detail
            , refreshOk ? "INFO" : "WARN")
    return refreshOk
}

AZMP_ReadProcessByte(address, ByRef outValue) {
    global hGTA
    outValue := 0
    if !IsLikelyPointer(address)
        return false
    VarSetCapacity(byteBuffer, 1, 0)
    bytesRead := 0
    ok := DllCall("ReadProcessMemory", "Ptr", hGTA, "Ptr", address
        , "Ptr", &byteBuffer, "UPtr", 1, "UPtr*", bytesRead)
    if (!ok || bytesRead != 1)
        return false
    outValue := NumGet(byteBuffer, 0, "UChar")
    return true
}

AZMP_ResetGtaPedPoolCache() {
    global AZMP_GTA_PED_POOL_CACHE_TICK, AZMP_GTA_PED_POOL_CACHE_PID
    global AZMP_GTA_PED_POOL_CACHE_PTR, AZMP_GTA_PED_POOL_CACHE_OBJECTS
    global AZMP_GTA_PED_POOL_CACHE_FLAGS, AZMP_GTA_PED_POOL_CACHE_SIZE
    AZMP_GTA_PED_POOL_CACHE_TICK := 0
    AZMP_GTA_PED_POOL_CACHE_PID := 0
    AZMP_GTA_PED_POOL_CACHE_PTR := 0
    AZMP_GTA_PED_POOL_CACHE_OBJECTS := 0
    AZMP_GTA_PED_POOL_CACHE_FLAGS := 0
    AZMP_GTA_PED_POOL_CACHE_SIZE := 0
    return true
}

; Полный сброс состояния, от которого зависит Auto ID.
; В отличие от AZMP_ResetTargetCache очищает также снимок GTA CPed pool,
; предпочтённую раскладку CPed и данные последнего успешного сопоставления.
AZMP_ResetAutoIDRuntime(reason := "", resetDiagnostics := 1) {
    global AZMP_PED_LAYOUT_PREFERRED
    global AZMP_TARGET_LAST_SUCCESS_TICK, AZMP_TARGET_LAST_SUCCESS_ID, AZMP_TARGET_LAST_SUCCESS_PED

    AZMP_ResetTargetCache(reason != "" ? reason : "full Auto ID reset")
    AZMP_ResetGtaPedPoolCache()
    AZMP_PED_LAYOUT_PREFERRED := ""
    AZMP_TARGET_LAST_SUCCESS_TICK := 0
    AZMP_TARGET_LAST_SUCCESS_ID := -1
    AZMP_TARGET_LAST_SUCCESS_PED := 0
    if (resetDiagnostics)
        AZMP_ResetTargetDiagnostics()

    if IsFunc("AutoTargetID_ResetCandidate")
        Func("AutoTargetID_ResetCandidate").Call()
    if IsFunc("AutoTargetID_ResetDiagnosticState")
        Func("AutoTargetID_ResetDiagnosticState").Call()
    if IsFunc("AutoTargetID_ClearFailure")
        Func("AutoTargetID_ClearFailure").Call()
    return true
}

AZMP_GetGtaPedPoolInfo(ByRef poolPtr, ByRef objectsPtr, ByRef flagsPtr, ByRef poolSize, forceRefresh := 0) {
    global hGTA, dwGTAPID, GTA_PED_POOL_POINTER_ADDRESS
    global AZMP_GTA_PED_POOL_CACHE_TICK, AZMP_GTA_PED_POOL_CACHE_PID
    global AZMP_GTA_PED_POOL_CACHE_PTR, AZMP_GTA_PED_POOL_CACHE_OBJECTS
    global AZMP_GTA_PED_POOL_CACHE_FLAGS, AZMP_GTA_PED_POOL_CACHE_SIZE

    poolPtr := objectsPtr := flagsPtr := poolSize := 0
    if (!checkReadHandles()) {
        AZMP_ResetGtaPedPoolCache()
        return false
    }
    if (!forceRefresh && AZMP_GTA_PED_POOL_CACHE_PID = dwGTAPID
        && AZMP_GTA_PED_POOL_CACHE_TICK != 0
        && AZMP_TickElapsed(AZMP_GTA_PED_POOL_CACHE_TICK) < 1000
        && IsLikelyPointer(AZMP_GTA_PED_POOL_CACHE_PTR)
        && IsLikelyPointer(AZMP_GTA_PED_POOL_CACHE_OBJECTS)
        && IsLikelyPointer(AZMP_GTA_PED_POOL_CACHE_FLAGS)
        && AZMP_GTA_PED_POOL_CACHE_SIZE > 0)
    {
        poolPtr := AZMP_GTA_PED_POOL_CACHE_PTR
        objectsPtr := AZMP_GTA_PED_POOL_CACHE_OBJECTS
        flagsPtr := AZMP_GTA_PED_POOL_CACHE_FLAGS
        poolSize := AZMP_GTA_PED_POOL_CACHE_SIZE
        return true
    }

    poolPtr := readDWORD(hGTA, GTA_PED_POOL_POINTER_ADDRESS)
    if !IsLikelyPointer(poolPtr) {
        AZMP_ResetGtaPedPoolCache()
        return false
    }
    objectsPtr := readDWORD(hGTA, poolPtr + 0x0)
    flagsPtr := readDWORD(hGTA, poolPtr + 0x4)
    poolSize := readDWORD(hGTA, poolPtr + 0x8)
    if (!IsLikelyPointer(objectsPtr) || !IsLikelyPointer(flagsPtr)
        || poolSize < 1 || poolSize > 4096)
    {
        AZMP_ResetGtaPedPoolCache()
        return false
    }

    AZMP_GTA_PED_POOL_CACHE_TICK := TickNow()
    AZMP_GTA_PED_POOL_CACHE_PID := dwGTAPID
    AZMP_GTA_PED_POOL_CACHE_PTR := poolPtr
    AZMP_GTA_PED_POOL_CACHE_OBJECTS := objectsPtr
    AZMP_GTA_PED_POOL_CACHE_FLAGS := flagsPtr
    AZMP_GTA_PED_POOL_CACHE_SIZE := poolSize
    return true
}

AZMP_PedFitsPoolSnapshot(pedPtr, objectsPtr, poolSize, ByRef outSlot) {
    global GTA_PED_POOL_OBJECT_SIZE
    outSlot := -1
    delta := pedPtr - objectsPtr
    totalBytes := poolSize * GTA_PED_POOL_OBJECT_SIZE
    if (delta < 0 || delta >= totalBytes)
        return false
    if (Mod(delta, GTA_PED_POOL_OBJECT_SIZE) != 0)
        return false
    outSlot := Floor(delta / GTA_PED_POOL_OBJECT_SIZE)
    return true
}

AZMP_IsPedInGtaPool(pedPtr, ByRef outSlot := -1, requireUsed := 1) {
    outSlot := -1
    if (!IsLikelyPointer(pedPtr) || Mod(pedPtr, 4) != 0)
        return false
    if !AZMP_GetGtaPedPoolInfo(poolPtr, objectsPtr, flagsPtr, poolSize)
        return false

    if !AZMP_PedFitsPoolSnapshot(pedPtr, objectsPtr, poolSize, outSlot) {
        ; Пул может быть пересоздан без смены PID. Один раз обновляем снимок.
        if !AZMP_GetGtaPedPoolInfo(poolPtr, objectsPtr, flagsPtr, poolSize, 1)
            return false
        if !AZMP_PedFitsPoolSnapshot(pedPtr, objectsPtr, poolSize, outSlot)
            return false
    }

    if (requireUsed) {
        if !AZMP_ReadProcessByte(flagsPtr + outSlot, slotFlags)
            return false
        ; GTA CPool: старший бит означает свободный слот.
        if (slotFlags & 0x80)
            return false
    }
    return true
}

AZMP_IsValidGamePed(pedPtr) {
    global hGTA
    if !AZMP_IsPedInGtaPool(pedPtr, pedSlot, 1)
        return false
    matrixPtr := readDWORD(hGTA, pedPtr + 0x14)
    if (!IsLikelyPointer(matrixPtr) || Mod(matrixPtr, 4) != 0)
        return false
    if (!TryReadFloat(hGTA, matrixPtr + 0x30, x) || !TryReadFloat(hGTA, matrixPtr + 0x34, y) || !TryReadFloat(hGTA, matrixPtr + 0x38, z))
        return false
    if (Abs(x) > 20000 || Abs(y) > 20000 || Abs(z) > 5000)
        return false
    return true
}

AZMP_AddPedCandidate(ByRef candidates, pedPtr, layout) {
    ; Для точного сопоставления нельзя отбрасывать указатель до сравнения с
    ; targetPed: карта GTA-пула и матрица могут обновляться неатомарно.
    ; Здесь проверяется только форма указателя. Строгая проверка выполняется
    ; отдельно перед координатными/эвристическими операциями.
    if (!IsLikelyPointer(pedPtr) || Mod(pedPtr, 4) != 0)
        return false
    Loop % candidates.Length()
        if (candidates[A_Index].Ped = pedPtr)
            return false
    candidates.Push({Ped: pedPtr, Layout: layout})
    return true
}

; Чтение точной цепочки старой рабочей версии без объектов на каждый ID.
; Указатели здесь не фильтруются по координатам: GTA-pool цели проверяется
; вызывающей функцией, а совпадение ID -> PlayerInfo -> CPed проверяется повторно.
AZMP_ReadGamePedLinks(playerInfo, ByRef gamePed, ByRef entityPed) {
    global hGTA, AZMP_R3_PLAYER_DATA_OFFSET, AZMP_R3_ACTOR_OFFSET
    global AZMP_R3_ACTOR_GTA_PED_OFFSET, AZMP_R3_PED_GAME_OFFSET
    gamePed := entityPed := 0
    if !IsLikelyPointer(playerInfo)
        return false
    remotePlayer := readDWORD(hGTA, playerInfo + AZMP_R3_PLAYER_DATA_OFFSET)
    if (ErrorLevel || !IsLikelyPointer(remotePlayer))
        return false
    sampPed := readDWORD(hGTA, remotePlayer + AZMP_R3_ACTOR_OFFSET)
    if (ErrorLevel || !IsLikelyPointer(sampPed))
        return false
    gamePed := readDWORD(hGTA, sampPed + AZMP_R3_PED_GAME_OFFSET)
    if (ErrorLevel || !IsLikelyPointer(gamePed) || Mod(gamePed, 4) != 0)
        gamePed := 0
    entityPed := readDWORD(hGTA, sampPed + AZMP_R3_ACTOR_GTA_PED_OFFSET)
    if (ErrorLevel || !IsLikelyPointer(entityPed) || Mod(entityPed, 4) != 0 || entityPed = gamePed)
        entityPed := 0
    return gamePed || entityPed
}

AZMP_GetGamePedCandidates(playerInfo) {
    candidates := []
    if AZMP_ReadGamePedLinks(playerInfo, gamePed, entityPed) {
        AZMP_AddPedCandidate(candidates, gamePed, "R3_PED_GAME")
        AZMP_AddPedCandidate(candidates, entityPed, "R3_ENTITY_GAME")
    }
    return candidates
}

AZMP_PlayerInfoMatchesPed(playerInfo, targetPed, ByRef matchedLayout := "") {
    matchedLayout := ""
    if (!IsLikelyPointer(targetPed) || !AZMP_ReadGamePedLinks(playerInfo, gamePed, entityPed))
        return false
    if (gamePed = targetPed)
        matchedLayout := "R3_PED_GAME"
    else if (entityPed = targetPed)
        matchedLayout := "R3_ENTITY_GAME"
    return matchedLayout != ""
}

isPlayerInAnyVehicle() {
    if (!checkReadHandles())
        return -1
    vehicle := readDWORD(hGTA, 0xBA18FC)
    if (ErrorLevel || (vehicle && !IsLikelyPointer(vehicle)))
        return -1
    return vehicle
}

getPlayerCoordinates() {
    if (!checkReadHandles())
        return -1
    pedPtr := readDWORD(hGTA, 0xB6F5F0)
    if !AZMP_IsValidGamePed(pedPtr)
        return -1
    return AZMP_GetGamePedCoordinates(pedPtr)
}

getCameraCoordinates() {
    if (!checkReadHandles())
        return -1
    if (!TryReadFloat(hGTA, 0xB6F9CC, x) || !TryReadFloat(hGTA, 0xB6F9D0, y) || !TryReadFloat(hGTA, 0xB6F9D4, z))
        return -1
    if (Abs(x) > 20000 || Abs(y) > 20000 || Abs(z) > 5000)
        return -1
    return [x, y, z]
}

SendChatMemory(text) {
    global g_RemoteLaunchSerial, PhysicalInputBusy, IDCaptureState
    if (PhysicalInputBusy || IsObject(IDCaptureState)
        || (IsFunc("ServiceUI_IsInputActive") && Func("ServiceUI_IsInputActive").Call()))
        return -1
    text := "" . text
    if (text = "" || StrLen(text) > 1023) {
        MemoryFail("WRITE_STRING", ERROR_STRING_TOO_LONG, "сообщение пустое или длиннее 1023 символов")
        return -1
    }
    if (!checkHandles())
        return -1
    if !MemoryInjectionEnter()
        return -1
    try {
        functionAddress := (SubStr(text, 1, 1) = "/") ? (dwSAMP + 0x69190) : (dwSAMP + 0x5820)
        MemorySetStage("WRITE_STRING", 0, "подготовка сообщения чата")
        beforeLaunch := g_RemoteLaunchSerial
        completed := callWithParams(hGTA, functionAddress, [["s", text]], false)
        errorCode := ErrorLevel
        result := MemoryAttemptResult(completed ? 1 : -1, beforeLaunch)
        if (result != 1) {
            if (result = -2)
                MemoryFail("SEND_UNCERTAIN", errorCode, "Удалённый вызов уже запускался; повтор отправки отключён.")
            else
                MemoryFail("SEND_CALL", errorCode, "не удалось подготовить функцию игрового чата")
            return result
        }
        MemorySetStage("SEND_OK", 0, (SubStr(text, 1, 1) = "/") ? "команда отправлена" : "сообщение отправлено")
        return 1
    } finally {
        MemoryInjectionLeave()
    }
}

addChatMessageEx(color, text) {
    text := "" . text
    if (text = "" || StrLen(text) > 1000)
        return -1
    if (!checkHandles())
        return -1
    if !MemoryInjectionEnter()
        return -1

    chatInfo := 0
    oldColor := 0
    colorChanged := false
    try {
        chatInfo := readDWORD(hGTA, dwSAMP + 0x26E8C8)
        if !IsLikelyPointer(chatInfo) {
            MemoryFail("MEMORY_READ", ERROR_READ_MEMORY, "не найден указатель игрового чата")
            return -1
        }

        oldColor := readDWORD(hGTA, chatInfo + 0x4)
        if (ErrorLevel)
            return -1
        VarSetCapacity(colorData, 4, 0)
        NumPut(color + 0, colorData, 0, "UInt")
        if !writeRaw(hGTA, chatInfo + 0x4, &colorData, 4)
            return -1
        colorChanged := true

        ok := callWithParams(hGTA, dwSAMP + 0x67970, [["p", chatInfo], ["s", text]], true, false, true)
        if (!ok)
            return -1
        MemorySetStage("NOTIFY_OK", 0, "уведомление добавлено в игровой чат")
        return 1
    } finally {
        if (colorChanged && IsObject(g_RemoteOperation)) {
            g_RemoteOperation.RestoreAddress := chatInfo + 0x4
            g_RemoteOperation.RestoreValue := oldColor
        } else if (colorChanged && IsLikelyPointer(chatInfo)) {
            VarSetCapacity(restoreData, 4, 0)
            NumPut(oldColor, restoreData, 0, "UInt")
            writeRaw(hGTA, chatInfo + 0x4, &restoreData, 4)
        }
        MemoryInjectionLeave()
    }
}

showDialog(style, caption, text, button1, button2 := "", id := 1) {
    style := Floor(style + 0)
    id := Floor(id + 0)
    caption := "" . caption
    text := "" . text
    button1 := "" . button1
    button2 := "" . button2

    if (id < 0 || id > 32767 || style < 0 || style > 5)
        return false
    if (StrLen(caption) > 64 || StrLen(text) > 1000 || StrLen(button1) > 10 || StrLen(button2) > 10)
        return false
    if (!checkHandles())
        return -1
    if !MemoryInjectionEnter()
        return -1

    try {
        dialogInfo := readDWORD(hGTA, dwSAMP + 0x26E898)
        if !IsLikelyPointer(dialogInfo) {
            MemoryFail("MEMORY_READ", ERROR_READ_MEMORY, "не найден указатель игрового диалога")
            return -1
        }

        captionPtr := pParam4
        button1Ptr := pParam4 + 128
        button2Ptr := pParam4 + 256
        textPtr := pParam1
        if !writeString(hGTA, captionPtr, caption)
            return -1
        if !writeString(hGTA, textPtr, text)
            return -1
        if !writeString(hGTA, button1Ptr, button1)
            return -1
        if !writeString(hGTA, button2Ptr, button2)
            return -1

        VarSetCapacity(injectData, 46, 0)
        NumPut(0xB9, injectData, 0, "UChar")
        NumPut(dialogInfo, injectData, 1, "UInt")
        NumPut(0x68, injectData, 5, "UChar")
        NumPut(1, injectData, 6, "UInt")
        NumPut(0x68, injectData, 10, "UChar")
        NumPut(button2Ptr, injectData, 11, "UInt")
        NumPut(0x68, injectData, 15, "UChar")
        NumPut(button1Ptr, injectData, 16, "UInt")
        NumPut(0x68, injectData, 20, "UChar")
        NumPut(textPtr, injectData, 21, "UInt")
        NumPut(0x68, injectData, 25, "UChar")
        NumPut(captionPtr, injectData, 26, "UInt")
        NumPut(0x68, injectData, 30, "UChar")
        NumPut(style, injectData, 31, "UInt")
        NumPut(0x68, injectData, 35, "UChar")
        NumPut(id, injectData, 36, "UInt")
        NumPut(0xE8, injectData, 40, "UChar")
        NumPut((dwSAMP + 0x6F8C0) - (pInjectFunc + 45), injectData, 41, "Int")
        NumPut(0xC2, injectData, 45, "UChar")
        NumPut(4, injectData, 46, "UShort")

        if !writeRaw(hGTA, pInjectFunc, &injectData, 48)
            return -1
        if !DllCall("FlushInstructionCache", "Ptr", hGTA, "Ptr", pInjectFunc, "UPtr", 48)
            return -1
        hThread := createRemoteThread(hGTA, 0, 0, pInjectFunc, 0, 0, 0)
        if (!hThread)
            return -1
        if !MemoryWaitRemote(hThread, hGTA, 2000)
            return -1
        MemorySetStage("DIALOG_OK", 0, "игровой диалог открыт")
        return 1
    } finally {
        MemoryInjectionLeave()
    }
}

AZMP_GetPools() {
    if (!checkReadHandles())
        return 0
    sampInfo := readDWORD(hGTA, dwSAMP + AZMP_SAMP_INFO_OFFSET)
    if !IsLikelyPointer(sampInfo)
        return 0
    pools := readDWORD(hGTA, sampInfo + AZMP_POOLS_OFFSET)
    return IsLikelyPointer(pools) ? pools : 0
}

AZMP_GetPlayerPool() {
    pools := AZMP_GetPools()
    if !IsLikelyPointer(pools)
        return 0
    playerPool := readDWORD(hGTA, pools + AZMP_PLAYER_POOL_OFFSET)
    return IsLikelyPointer(playerPool) ? playerPool : 0
}

AZMP_GetLabelPool() {
    pools := AZMP_GetPools()
    if !IsLikelyPointer(pools)
        return 0
    labelPool := readDWORD(hGTA, pools + AZMP_LABEL_POOL_OFFSET)
    return IsLikelyPointer(labelPool) ? labelPool : 0
}

AZMP_IsPlayerListed(playerId, playerPool := 0) {
    if (playerId < 0 || playerId >= AZMP_MAX_PLAYERS)
        return false
    if !IsLikelyPointer(playerPool)
        playerPool := AZMP_GetPlayerPool()
    if !IsLikelyPointer(playerPool)
        return false

    listed := readDWORD(hGTA, playerPool + AZMP_PLAYER_NOT_EMPTY_ARRAY_OFFSET + playerId * 4)
    return (ErrorLevel = ERROR_OK && listed != 0) ? true : false
}

AZMP_GetPlayerInfo(playerId, playerPool := 0, requireListed := 1) {
    if (playerId < 0 || playerId >= AZMP_MAX_PLAYERS)
        return 0
    if !IsLikelyPointer(playerPool)
        playerPool := AZMP_GetPlayerPool()
    if !IsLikelyPointer(playerPool)
        return 0
    if (requireListed && !AZMP_IsPlayerListed(playerId, playerPool))
        return 0

    playerInfo := readDWORD(hGTA, playerPool + AZMP_PLAYER_INFO_ARRAY_OFFSET + playerId * 4)
    return IsLikelyPointer(playerInfo) ? playerInfo : 0
}

AZMP_ReadProcessString(processHandle, address, length) {
    if (!processHandle || !IsLikelyPointer(address) || length < 1 || length > 4096)
        return ""

    VarSetCapacity(buffer, length + 1, 0)
    bytesRead := 0
    ok := DllCall("ReadProcessMemory"
        , "UInt", processHandle
        , "UInt", address
        , "UInt", &buffer
        , "UInt", length
        , "UInt*", bytesRead
        , "UInt")
    if (!ok || bytesRead < 1)
        return ""

    NumPut(0, buffer, bytesRead, "UChar")
    VarSetCapacity(buffer, -1)
    if A_IsUnicode
        return StrGet(&buffer, bytesRead, "CP1251")
    return buffer
}

AZMP_ReadCString(address, maxLen := 192) {
    if (!IsLikelyPointer(address) || maxLen < 1 || maxLen > 4096)
        return ""

    VarSetCapacity(buffer, maxLen + 1, 0)
    bytesRead := 0
    ok := DllCall("ReadProcessMemory"
        , "UInt", hGTA
        , "UInt", address
        , "UInt", &buffer
        , "UInt", maxLen
        , "UInt*", bytesRead
        , "UInt")
    if (!ok || bytesRead < 1)
        return ""

    NumPut(0, buffer, bytesRead, "UChar")
    VarSetCapacity(buffer, -1)
    if A_IsUnicode
        value := StrGet(&buffer, bytesRead, "CP1251")
    else
        value := buffer
    nullPos := InStr(value, Chr(0))
    if (nullPos > 0)
        value := SubStr(value, 1, nullPos - 1)
    return Trim(value)
}

AZMP_CleanWorldLabelText(text) {
    text := RegExReplace(text, "i)\{[0-9A-F]{6,8}\}")
    text := RegExReplace(text, "i)~[A-Z0-9_]+~")
    text := StrReplace(text, "_", " ")
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    while InStr(text, "  ")
        text := StrReplace(text, "  ", " ")
    return Trim(text)
}

AZMP_ExtractMaskNumber(text) {
    rawText := RegExReplace(text, "i)\{[0-9A-F]{6,8}\}")
    rawText := RegExReplace(rawText, "i)~[A-Z0-9_]+~")
    hadUnderscore := InStr(rawText, "_") ? true : false
    clean := AZMP_CleanWorldLabelText(text)
    if (clean = "")
        return ""
    if RegExMatch(clean, "i)(?:маск(?:а|и|ой|е)?|mask)[^0-9]{0,20}([0-9]{5,20})", found)
        return found1
    if RegExMatch(clean, "^\s*(?:№|#)?\s*([0-9]{5,20})\s*$", found)
        return found1
    if (!hadUnderscore && RegExMatch(clean, "(?:^|[^0-9])([0-9]{5,20})(?:$|[^0-9])", found))
        return found1
    return ""
}

AZMP_IsMaskDisplayName(name) {
    return (AZMP_ExtractMaskNumber(name) != "") ? true : false
}

AZMP_ReadRemoteStdString(stringAddress, maxLen := 48) {
    if !IsLikelyPointer(stringAddress)
        return ""

    length := readDWORD(hGTA, stringAddress + 0x10)
    capacity := readDWORD(hGTA, stringAddress + 0x14)
    if (length < 1 || length > maxLen || capacity < length || capacity > 4096)
        return ""

    dataAddress := stringAddress
    if (capacity >= 16)
        dataAddress := readDWORD(hGTA, stringAddress)
    if !IsLikelyPointer(dataAddress)
        return ""

    value := AZMP_ReadProcessString(hGTA, dataAddress, length)
    value := Trim(StrReplace(value, Chr(0), ""))
    return value
}

AZMP_GetNicknameFromPlayerInfo(playerInfo) {
    if !IsLikelyPointer(playerInfo)
        return ""

    return AZMP_ReadRemoteStdString(playerInfo + 0x0C, 48)
}

getPlayerNameById(playerId) {
    playerInfo := AZMP_GetPlayerInfo(playerId)
    return AZMP_GetNicknameFromPlayerInfo(playerInfo)
}

getPlayerPedById(playerId) {
    if (!checkReadHandles())
        return 0
    if !RegExMatch(playerId . "", "^\d{1,4}$")
        return 0
    playerInfo := AZMP_GetPlayerInfo(playerId + 0)
    if !IsLikelyPointer(playerInfo)
        return 0
    return AZMP_GetGamePedFromPlayerInfo(playerInfo)
}

AZMP_GetGamePedFromPlayerInfo(playerInfo) {
    global AZMP_PED_LAYOUT_PREFERRED
    if !IsLikelyPointer(playerInfo)
        return 0

    candidates := AZMP_GetGamePedCandidates(playerInfo)
    if (candidates.Length() = 0)
        return 0

    ; Для получения координат/меток уже нужна строгая проверка живого GTA CPed.
    if (AZMP_PED_LAYOUT_PREFERRED != "") {
        Loop % candidates.Length() {
            item := candidates[A_Index]
            if (item.Layout = AZMP_PED_LAYOUT_PREFERRED && AZMP_IsValidGamePed(item.Ped))
                return item.Ped
        }
    }
    Loop % candidates.Length() {
        item := candidates[A_Index]
        if AZMP_IsValidGamePed(item.Ped)
            return item.Ped
    }
    return 0
}

AZMP_GetGamePedCoordinates(pedPtr) {
    if !IsLikelyPointer(pedPtr)
        return 0
    matrixPtr := readDWORD(hGTA, pedPtr + 0x14)
    if !IsLikelyPointer(matrixPtr)
        return 0
    if (!TryReadFloat(hGTA, matrixPtr + 0x30, x) || !TryReadFloat(hGTA, matrixPtr + 0x34, y) || !TryReadFloat(hGTA, matrixPtr + 0x38, z))
        return -1
    return [x, y, z]
}

; Формирует единый вектор направления камеры. В отличие от игрового target-pointer,
; этот вектор не закреплён за конкретным CPed и продолжает меняться при переводе прицела.
AZMP_GetAimContext(ByRef cameraX, ByRef cameraY, ByRef cameraZ
    , ByRef viewX, ByRef viewY, ByRef viewZ, ByRef viewLength)
{
    cameraX := cameraY := cameraZ := 0.0
    viewX := viewY := viewZ := 0.0
    viewLength := 0.0
    camera := getCameraCoordinates()
    localCoords := getPlayerCoordinates()
    if (!IsObject(camera) || !IsObject(localCoords))
        return false
    cameraX := camera[1], cameraY := camera[2], cameraZ := camera[3]
    viewX := localCoords[1] - cameraX
    viewY := localCoords[2] - cameraY
    viewZ := localCoords[3] - cameraZ
    viewLength := Sqrt(viewX*viewX + viewY*viewY + viewZ*viewZ)
    return (viewLength >= 0.20)
}

AZMP_GetAimAngleForPed(pedPtr, cameraX, cameraY, cameraZ
    , viewX, viewY, viewZ, viewLength)
{
    coords := AZMP_GetGamePedCoordinates(pedPtr)
    if !IsObject(coords)
        return -1
    targetX := coords[1] - cameraX
    targetY := coords[2] - cameraY
    targetZ := coords[3] - cameraZ
    targetLength := Sqrt(targetX*targetX + targetY*targetY + targetZ*targetZ)
    if (targetLength < 0.20 || viewLength < 0.20)
        return -1
    cosine := (viewX*targetX + viewY*targetY + viewZ*targetZ) / (viewLength * targetLength)
    if (cosine > 1)
        cosine := 1
    else if (cosine < -1)
        cosine := -1
    return ACos(cosine) * 57.295779513
}

AZMP_GetPedDistance(firstPed, secondPed) {
    firstCoords := AZMP_GetGamePedCoordinates(firstPed)
    secondCoords := AZMP_GetGamePedCoordinates(secondPed)
    if !IsObject(firstCoords) || !IsObject(secondCoords)
        return -1
    dx := firstCoords[1] - secondCoords[1]
    dy := firstCoords[2] - secondCoords[2]
    dz := firstCoords[3] - secondCoords[3]
    return Sqrt(dx*dx + dy*dy + dz*dz)
}

; Угадывание ID по направлению прицела отключено намеренно.
; Auto ID принимает только доказанную связь target CPed -> remote player ID.
AZMP_FindPlayerByAim(originalTargetPed, ByRef outId, ByRef outName
    , ByRef outPed, ByRef outAngle, ByRef outDetail)
{
    outId := -1
    outName := ""
    outPed := 0
    outAngle := -1
    outDetail := "резервный выбор ID по углу отключён: он не подтверждает связь CPed -> ID"
    AZMP_TargetDiagSet("TARGET_POOL_LAYOUT_UNRESOLVED", outDetail, 1, 1)
    return 0
}

getPlayerDataByPed(targetPed, ByRef outId, ByRef outName, nearestLimit := 0) {
    global AZMP_TARGET_CACHE_PED, AZMP_TARGET_CACHE_ID, AZMP_TARGET_CACHE_TICK
    global AZMP_TARGET_CACHE_POOL, AZMP_TARGET_CACHE_INFO, AZMP_TARGET_CACHE_PID
    global AZMP_TARGET_CACHE_TTL, AZMP_TARGET_FALLBACK_LIMIT, dwGTAPID, hGTA

    outId := -1
    outName := ""
    if !IsLikelyPointer(targetPed) {
        AZMP_TargetDiagSetContext(0, 0)
        AZMP_TargetDiagSet("TARGET_PED_INVALID", "указатель цели " . targetPed)
        return 0
    }
    if (!checkReadHandles()) {
        AZMP_TargetDiagSetContext(targetPed, 0)
        code := ProcessHandleIsValid(hGTA, dwGTAPID) ? "HANDLE_CHECK_FAILED" : "HANDLE_INVALID"
        detail := MemoryGetStatusText()
        AZMP_TargetDiagSet(code, detail)
        AZMP_TargetDiagMaybeRecover(code, detail)
        return 0
    }

    if !AZMP_IsPedInGtaPool(targetPed, targetSlot, 1) {
        AZMP_ResetTargetCache("target PED is not an occupied GTA pool slot")
        AZMP_TargetDiagSetContext(targetPed, 0)
        AZMP_TargetDiagSet("TARGET_PED_OUTSIDE_GTA_POOL", "цель не является занятым слотом CPed GTA")
        return 0
    }
    playerPool := AZMP_GetPlayerPool()
    if !IsLikelyPointer(playerPool) {
        AZMP_TargetDiagSetContext(targetPed, 0)
        AZMP_ResetTargetCache("player pool unavailable")
        AZMP_TargetDiagSet("PLAYER_POOL_UNAVAILABLE", "dwSAMP/pools/playerPool невалидны")
        AZMP_TargetDiagMaybeRecover("PLAYER_POOL_UNAVAILABLE", "playerPool=0")
        return 0
    }
    AZMP_TargetDiagSetContext(targetPed, playerPool)

    if (AZMP_TARGET_CACHE_PID != 0
        && (AZMP_TARGET_CACHE_PID != dwGTAPID || AZMP_TARGET_CACHE_POOL != playerPool))
        AZMP_ResetTargetCache("player pool changed")

    ; Кэш принимается только после свежей проверки всей связи ID -> PlayerInfo -> target CPed.
    if (targetPed = AZMP_TARGET_CACHE_PED && AZMP_TARGET_CACHE_ID >= 0
        && AZMP_TARGET_CACHE_PID = dwGTAPID && AZMP_TARGET_CACHE_POOL = playerPool
        && AZMP_TickElapsed(AZMP_TARGET_CACHE_TICK) < AZMP_TARGET_CACHE_TTL)
    {
        ; Кэш переживает пару стабильных опросов, но каждый hit заново проверяет
        ; m_bNotEmpty, PlayerInfo и точную цепочку до того же GTA CPed.
        cachedInfo := AZMP_GetPlayerInfo(AZMP_TARGET_CACHE_ID, playerPool, 1)
        if (cachedInfo = AZMP_TARGET_CACHE_INFO
            && AZMP_PlayerInfoMatchesPed(cachedInfo, targetPed, cachedLayout)) {
            outId := AZMP_TARGET_CACHE_ID
            outName := AZMP_GetNicknameFromPlayerInfo(cachedInfo)
            AZMP_TargetDiagSuccess(outId, targetPed, cachedLayout, outName)
            return 1
        }
        AZMP_ResetTargetCache("cached mapping is stale")
    }

    playerArrayBytes := AZMP_MAX_PLAYERS * 4
    VarSetCapacity(playerInfos, playerArrayBytes, 0)
    VarSetCapacity(playerFlags, playerArrayBytes, 0)
    infoBytesRead := 0
    flagBytesRead := 0
    readInfoOk := DllCall("ReadProcessMemory", "Ptr", hGTA
        , "Ptr", playerPool + AZMP_PLAYER_INFO_ARRAY_OFFSET
        , "Ptr", &playerInfos, "UPtr", playerArrayBytes, "UPtr*", infoBytesRead)
    readFlagsOk := DllCall("ReadProcessMemory", "Ptr", hGTA
        , "Ptr", playerPool + AZMP_PLAYER_NOT_EMPTY_ARRAY_OFFSET
        , "Ptr", &playerFlags, "UPtr", playerArrayBytes, "UPtr*", flagBytesRead)

    if (!readInfoOk || infoBytesRead != playerArrayBytes) {
        AZMP_ResetTargetCache("incomplete player info read")
        detail := "info " . infoBytesRead . "/" . playerArrayBytes
            . ", flags " . flagBytesRead . "/" . playerArrayBytes
        MemoryFail("TARGET_POOL_READ", ERROR_READ_MEMORY, detail)
        AZMP_TargetDiagSet("POOL_READ_INCOMPLETE", detail)
        AZMP_TargetDiagMaybeRecover("POOL_READ_INCOMPLETE", detail)
        return 0
    }

    ; m_bNotEmpty является частью официальной CPlayerPool. Без него старые
    ; указатели отключившихся игроков могут остаться в массиве m_pObject.
    flagsComplete := (readFlagsOk && flagBytesRead = playerArrayBytes)
    listedCount := 0
    infoCount := 0
    rawPedCandidateCount := 0
    strictPedCandidateCount := 0
    exactMatches := []
    targetCoords := (nearestLimit > 0) ? AZMP_GetGamePedCoordinates(targetPed) : 0
    fallbackLimit := nearestLimit + 0.0
    if (fallbackLimit > AZMP_TARGET_FALLBACK_LIMIT)
        fallbackLimit := AZMP_TARGET_FALLBACK_LIMIT
    if (fallbackLimit < 0)
        fallbackLimit := 0
    bestId := -1
    bestInfo := 0
    bestPed := 0
    bestLayout := ""
    bestDistance := 999999.0
    secondDistance := 999999.0

    Loop %AZMP_MAX_PLAYERS% {
        playerId := A_Index - 1
        isListed := flagsComplete ? (NumGet(playerFlags, playerId * 4, "Int") != 0) : AZMP_IsPlayerListed(playerId, playerPool)
        if !isListed
            continue
        listedCount += 1

        playerInfo := NumGet(playerInfos, playerId * 4, "UInt")
        if !IsLikelyPointer(playerInfo)
            continue
        infoCount += 1

        exactLayout := ""
        if (fallbackLimit = 0) {
            ; Основной Auto ID не создаёт массив и объекты для каждого из 1004 ID.
            ; Полный обход сохраняется: дубликат CPed у двух ID нельзя принять.
            if !AZMP_ReadGamePedLinks(playerInfo, gamePed, entityPed)
                continue
            rawPedCandidateCount += (gamePed ? 1 : 0) + (entityPed ? 1 : 0)
            if (gamePed = targetPed)
                exactLayout := "R3_PED_GAME"
            else if (entityPed = targetPed)
                exactLayout := "R3_ENTITY_GAME"
        } else {
            candidates := AZMP_GetGamePedCandidates(playerInfo)
            if (candidates.Length() = 0)
                continue
            rawPedCandidateCount += candidates.Length()
            Loop % candidates.Length() {
                candidate := candidates[A_Index]
                if (candidate.Ped = targetPed) {
                    exactLayout := candidate.Layout
                    break
                }
                if AZMP_IsValidGamePed(candidate.Ped)
                    strictPedCandidateCount += 1
            }
        }
        if (exactLayout != "") {
            exactMatches.Push({Id: playerId, Info: playerInfo, Layout: exactLayout})
            continue
        }

        if (fallbackLimit > 0 && IsObject(targetCoords)) {
            Loop % candidates.Length() {
                candidate := candidates[A_Index]
                if !AZMP_IsValidGamePed(candidate.Ped)
                    continue
                remoteCoords := AZMP_GetGamePedCoordinates(candidate.Ped)
                if !IsObject(remoteCoords)
                    continue
                dx := targetCoords[1] - remoteCoords[1]
                dy := targetCoords[2] - remoteCoords[2]
                dz := targetCoords[3] - remoteCoords[3]
                distance := Sqrt(dx*dx + dy*dy + dz*dz)
                if (distance < bestDistance) {
                    secondDistance := bestDistance
                    bestDistance := distance
                    bestId := playerId
                    bestInfo := playerInfo
                    bestPed := candidate.Ped
                    bestLayout := candidate.Layout
                } else if (distance < secondDistance) {
                    secondDistance := distance
                }
            }
        }
    }

    if (exactMatches.Length() = 1) {
        match := exactMatches[1]
        ; Финальная независимая проверка защищает от смены слота во время сканирования.
        currentInfo := AZMP_GetPlayerInfo(match.Id, playerPool, 1)
        if (currentInfo = match.Info
            && AZMP_PlayerInfoMatchesPed(currentInfo, targetPed, finalLayout)) {
            outId := match.Id
            name1 := AZMP_GetNicknameFromPlayerInfo(currentInfo)
            name2 := AZMP_GetNicknameFromPlayerInfo(currentInfo)
            outName := (name1 = name2) ? name1 : ""
            AZMP_CacheTarget(targetPed, outId, currentInfo, playerPool)
            AZMP_TargetDiagSuccess(outId, targetPed, finalLayout, outName)
            if (name1 != name2)
                AZMP_TargetDiagSet("TARGET_NAME_UNSTABLE", "ID " . outId . ": '" . name1 . "' / '" . name2 . "'", 1, 1)
            return 1
        }
        AZMP_TargetDiagSet("TARGET_CHANGED_DURING_SCAN", "слот ID " . match.Id . " изменился")
        return 0
    }

    if (exactMatches.Length() > 1) {
        ids := ""
        Loop % exactMatches.Length()
            ids .= (ids = "" ? "" : ",") . exactMatches[A_Index].Id
        AZMP_ResetTargetCache("same target ped found in multiple slots")
        AZMP_TargetDiagSet("DUPLICATE_TARGET_PED", "CPed " . targetPed . " найден у ID: " . ids, 1, 1)
        return 0
    }

    if (bestId >= 0 && bestDistance <= fallbackLimit) {
        gap := secondDistance - bestDistance
        unambiguous := (secondDistance >= 999999.0 || bestDistance <= 0.20 || gap >= 0.85)
        if (unambiguous
            && AZMP_GetPlayerInfo(bestId, playerPool, 0) = bestInfo
            && AZMP_PlayerInfoMatchesPed(bestInfo, bestPed, verifyLayout))
        {
            outId := bestId
            outName := AZMP_GetNicknameFromPlayerInfo(bestInfo)
            AZMP_TargetDiagSet("TARGET_NEAREST", "ID " . bestId . ", " . Round(bestDistance, 2) . " м, " . bestLayout, 0)
            return 2
        }
        AZMP_TargetDiagSet("TARGET_AMBIGUOUS", Round(bestDistance, 2) . " / " . Round(secondDistance, 2))
        return 0
    }

    if (infoCount = 0) {
        code := "NO_VALID_PLAYER_INFO"
        detail := "listed=" . listedCount . ", playerInfo=0"
        AZMP_TargetDiagSet(code, detail)
        AZMP_TargetDiagMaybeRecover(code, detail)
    } else if (rawPedCandidateCount = 0) {
        code := "NO_VALID_PEDS"
        detail := "listed=" . listedCount . ", playerInfo=" . infoCount . ", цепочка R3 не дала ни одного CPed"
        AZMP_TargetDiagSet(code, detail)
        AZMP_TargetDiagMaybeRecover(code, detail)
    } else {
        targetInGtaPool := AZMP_IsPedInGtaPool(targetPed, targetPoolSlot, 1) ? 1 : 0
        detail := "targetPed=" . Format("0x{:08X}", targetPed)
            . ", gtaPool=" . targetInGtaPool . ", gtaSlot=" . targetPoolSlot
            . ", listed=" . listedCount . ", info=" . infoCount
            . ", rawPedCandidates=" . rawPedCandidateCount
            . ", strictPedCandidates=" . strictPedCandidateCount
        AZMP_TargetDiagSet("TARGET_NOT_IN_POOL", detail)
        ; NOT_IN_POOL часто является короткой гонкой stream-in/out или NPC.
        ; Поэтому здесь обновляются только модуль и снимки пулов; hGTA не
        ; переоткрывается и чат/диалоги не прерываются.
        AZMP_TargetDiagMaybeRefreshNotInPool(targetPed, playerPool, detail)
    }
    return 0
}

getMaskDataByPed(targetPed, ByRef outMaskNumber, ByRef outPlayerId, playerRadius := 4.5, labelRadius := 3.5) {
    outMaskNumber := ""
    outPlayerId := -1
    if !IsLikelyPointer(targetPed)
        return 0
    if (!checkReadHandles())
        return 0

    targetCoords := AZMP_GetGamePedCoordinates(targetPed)
    if !IsObject(targetCoords)
        return 0

    labelPool := AZMP_GetLabelPool()
    if !IsLikelyPointer(labelPool)
        return 0

    labelsBytes := AZMP_LABEL_ACTIVE_ARRAY_OFFSET
    flagsBytes := AZMP_MAX_LABELS * 4

    VarSetCapacity(labels, labelsBytes, 0)
    VarSetCapacity(labelFlags, flagsBytes, 0)
    labelsRead := 0
    flagsRead := 0
    labelsOk := DllCall("ReadProcessMemory", "UInt", hGTA
        , "UInt", labelPool, "UInt", &labels, "UInt", labelsBytes, "UInt*", labelsRead, "UInt")
    flagsOk := DllCall("ReadProcessMemory", "UInt", hGTA
        , "UInt", labelPool + AZMP_LABEL_ACTIVE_ARRAY_OFFSET
        , "UInt", &labelFlags, "UInt", flagsBytes, "UInt*", flagsRead, "UInt")
    if (!labelsOk || !flagsOk || labelsRead != labelsBytes || flagsRead != flagsBytes)
        return 0

    bestScore := 999999.0
    secondScore := 999999.0
    bestMask := ""
    bestPlayerId := -1
    bestText := ""

    Loop %AZMP_MAX_LABELS% {
        labelIndex := A_Index - 1
        if (NumGet(labelFlags, labelIndex * 4, "Int") = 0)
            continue

        baseOffset := labelIndex * AZMP_LABEL_SIZE
        textAddress := NumGet(labels, baseOffset, "UInt")
        if !IsLikelyPointer(textAddress)
            continue
        labelText := AZMP_ReadCString(textAddress, 192)
        maskNumber := AZMP_ExtractMaskNumber(labelText)
        if (maskNumber = "")
            continue

        attachedPlayer := NumGet(labels, baseOffset + 25, "UShort")
        score := 999999.0
        candidatePlayerId := -1

        if (attachedPlayer != AZMP_INVALID_ID && attachedPlayer < AZMP_MAX_PLAYERS) {
            playerInfo := AZMP_GetPlayerInfo(attachedPlayer)
            if IsLikelyPointer(playerInfo) {
                gamePed := AZMP_GetGamePedFromPlayerInfo(playerInfo)
                if (gamePed = targetPed) {
                    score := 0.0
                    candidatePlayerId := attachedPlayer
                } else if IsLikelyPointer(gamePed) {
                    playerCoords := AZMP_GetGamePedCoordinates(gamePed)
                    if IsObject(playerCoords) {
                        dx := targetCoords[1] - playerCoords[1]
                        dy := targetCoords[2] - playerCoords[2]
                        dz := targetCoords[3] - playerCoords[3]
                        distance := Sqrt(dx*dx + dy*dy + dz*dz)
                        strictPlayerRadius := playerRadius
                        if (strictPlayerRadius > 1.15)
                            strictPlayerRadius := 1.15
                        if (distance <= strictPlayerRadius) {
                            score := distance
                            candidatePlayerId := attachedPlayer
                        }
                    }
                }
            }
        } else {
            labelX := NumGet(labels, baseOffset + 8, "Float")
            labelY := NumGet(labels, baseOffset + 12, "Float")
            labelZ := NumGet(labels, baseOffset + 16, "Float")
            dx := targetCoords[1] - labelX
            dy := targetCoords[2] - labelY
            dz := labelZ - targetCoords[3]
            horizontal := Sqrt(dx*dx + dy*dy)
            if (horizontal <= labelRadius && dz >= -1.5 && dz <= 5.5)
                score := horizontal + Abs(dz - 1.0) * 0.15 + 0.25
        }

        if (score < bestScore) {
            secondScore := bestScore
            bestScore := score
            bestMask := maskNumber
            bestPlayerId := candidatePlayerId
            bestText := labelText
        } else if (score < secondScore) {
            secondScore := score
        }
    }

    if (bestMask = "")
        return 0
    if (secondScore < 999999.0 && secondScore - bestScore < 0.35 && bestScore > 0.20) {
        MemorySetStage("TARGET_MASK_AMBIGUOUS", 0
            , "несколько близких меток: " . Round(bestScore, 2) . " / " . Round(secondScore, 2))
        return 0
    }

    outMaskNumber := bestMask
    outPlayerId := bestPlayerId
    if (bestPlayerId >= 0) {
        MemorySetStage("TARGET_MASK_TO_ID", 0
            , "3D-метка маски привязана к ID " . bestPlayerId . ", маска " . bestMask)
        return 2
    }
    MemorySetStage("TARGET_MASK_OK", 0
        , "найден номер маски " . bestMask . " в 3D-метке: " . AZMP_CleanWorldLabelText(bestText))
    return 1
}

AZMP_TargetDiagnosticSnapshot(targetPed := 0) {
    global hGTA, dwGTAPID, dwSAMP, pMemory, g_HandleGeneration, g_HandleReopenCount, g_LastHandleError
    global AZMP_TARGET_CACHE_PED, AZMP_TARGET_CACHE_ID, AZMP_TARGET_CACHE_POOL, AZMP_TARGET_CACHE_INFO
    global AZMP_TARGET_DIAG_CODE, AZMP_TARGET_DIAG_DETAIL, AZMP_TARGET_DIAG_STREAK
    global AZMP_TARGET_DIAG_PED, AZMP_TARGET_DIAG_POOL, AZMP_TARGET_DIAG_PID
    global AZMP_TARGET_DIAG_RECOVER_COUNT, AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT
    global AZMP_PED_LAYOUT_PREFERRED

    handleValid := ProcessHandleIsValid(hGTA, dwGTAPID) ? 1 : 0
    playerPool := handleValid ? AZMP_GetPlayerPool() : 0
    pedPoolReady := AZMP_GetGtaPedPoolInfo(gtaPedPool, gtaPedObjects, gtaPedFlags, gtaPedPoolSize) ? 1 : 0
    targetPoolSlot := -1
    targetInGtaPool := (targetPed && AZMP_IsPedInGtaPool(targetPed, targetPoolSlot, 1)) ? 1 : 0
    text := "code=" . AZMP_TARGET_DIAG_CODE
        . "; detail=" . AZMP_TARGET_DIAG_DETAIL
        . "; streak=" . AZMP_TARGET_DIAG_STREAK
        . "; diagPed=" . AZMP_TARGET_DIAG_PED
        . "; diagPool=" . AZMP_TARGET_DIAG_POOL
        . "; diagPid=" . AZMP_TARGET_DIAG_PID
        . "; targetPed=" . targetPed
        . "; hGTA=" . hGTA
        . "; handleValid=" . handleValid
        . "; pid=" . dwGTAPID
        . "; dwSAMP=" . dwSAMP
        . "; pMemory=" . pMemory
        . "; handleGeneration=" . g_HandleGeneration
        . "; handleReopens=" . g_HandleReopenCount
        . "; lastHandleError=" . g_LastHandleError
        . "; playerPool=" . playerPool
        . "; preferredLayout=" . AZMP_PED_LAYOUT_PREFERRED
        . "; cachePed=" . AZMP_TARGET_CACHE_PED
        . "; cacheId=" . AZMP_TARGET_CACHE_ID
        . "; cachePool=" . AZMP_TARGET_CACHE_POOL
        . "; cacheInfo=" . AZMP_TARGET_CACHE_INFO
        . "; autoRecoveries=" . AZMP_TARGET_DIAG_RECOVER_COUNT
        . "; softPoolRefreshes=" . AZMP_TARGET_DIAG_SOFT_REFRESH_COUNT
        . "; gtaPedPoolReady=" . pedPoolReady
        . "; gtaPedPool=" . gtaPedPool
        . "; gtaPedObjects=" . gtaPedObjects
        . "; gtaPedPoolSize=" . gtaPedPoolSize
        . "; targetInGtaPool=" . targetInGtaPool
        . "; targetPoolSlot=" . targetPoolSlot

    if !IsLikelyPointer(playerPool)
        return text

    playerArrayBytes := AZMP_MAX_PLAYERS * 4
    VarSetCapacity(playerInfos, playerArrayBytes, 0)
    VarSetCapacity(playerFlags, playerArrayBytes, 0)
    infoRead := 0, flagsRead := 0
    infoOk := DllCall("ReadProcessMemory", "UInt", hGTA
        , "UInt", playerPool + AZMP_PLAYER_INFO_ARRAY_OFFSET
        , "UInt", &playerInfos, "UInt", playerArrayBytes, "UInt*", infoRead, "UInt")
    flagsOk := DllCall("ReadProcessMemory", "UInt", hGTA
        , "UInt", playerPool + AZMP_PLAYER_NOT_EMPTY_ARRAY_OFFSET
        , "UInt", &playerFlags, "UInt", playerArrayBytes, "UInt*", flagsRead, "UInt")
    if (!infoOk || infoRead != playerArrayBytes)
        return text . "; diagPoolRead=" . infoRead . "/" . playerArrayBytes

    flagsComplete := (flagsOk && flagsRead = playerArrayBytes)
    listedCount := 0, infoCount := 0, rawCandidateCount := 0, strictCandidateCount := 0, targetMatchCount := 0
    layoutCounts := {}
    Loop %AZMP_MAX_PLAYERS% {
        playerId := A_Index - 1
        isListed := flagsComplete ? (NumGet(playerFlags, playerId * 4, "Int") != 0) : AZMP_IsPlayerListed(playerId, playerPool)
        if !isListed
            continue
        listedCount += 1
        info := NumGet(playerInfos, playerId * 4, "UInt")
        if !IsLikelyPointer(info)
            continue
        infoCount += 1
        candidates := AZMP_GetGamePedCandidates(info)
        rawCandidateCount += candidates.Length()
        Loop % candidates.Length() {
            item := candidates[A_Index]
            layoutCounts[item.Layout] := layoutCounts.HasKey(item.Layout) ? layoutCounts[item.Layout] + 1 : 1
            if AZMP_IsValidGamePed(item.Ped)
                strictCandidateCount += 1
            if (targetPed && item.Ped = targetPed)
                targetMatchCount += 1
        }
    }
    layouts := ""
    for layoutName, layoutCount in layoutCounts
        layouts .= (layouts = "" ? "" : ",") . layoutName . "=" . layoutCount
    return text . "; listedCount=" . listedCount . "; infoCount=" . infoCount
        . "; rawCandidateCount=" . rawCandidateCount . "; strictCandidateCount=" . strictCandidateCount
        . "; targetMatchCount=" . targetMatchCount . "; layouts=" . layouts
}

getPlayerIdByPed(targetPed) {
    ; Неверный ID хуже отсутствия результата: только точное соответствие CPed.
    if (getPlayerDataByPed(targetPed, playerId, playerName, 0) = 1)
        return playerId
    return -1
}

isInChat() {
    if (!checkReadHandles())
        return -1
    inputInfoPtr := readDWORD(hGTA, dwSAMP + 0x26E8F4)
    if (ErrorLevel || !IsLikelyPointer(inputInfoPtr))
        return -1
    state := readDWORD(hGTA, inputInfoPtr + 0x61)
    return AZMP_ChatStateFromRead(state, ErrorLevel)
}

AZMP_ChatStateFromRead(rawState, readFailed := false) {
    ; Amazing uses a 32-bit BOOL here: every nonzero completed read means open.
    ; Keep failed reads unknown; a failed RPM must never masquerade as closed chat.
    if (readFailed || !RegExMatch(rawState . "", "^\d+$")
        || rawState < 0 || rawState > 0xFFFFFFFF || rawState != Floor(rawState))
        return -1
    return rawState = 0 ? 0 : 1
}
