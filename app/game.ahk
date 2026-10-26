; game subsystem. Definitions only; initialization is in bootstrap.

GetAzmpModuleInfo(force := 0) {
    global AzmpInfoCache, AzmpExpectedSHA256, GAME_MP_ModulePath
    info := {Ready: 0, Path: "", Version: "", SHA256: "", Expected: "", Match: 0, Status: ""}
    if !(refreshGTA() && refreshSAMP(1)) {
        info.Status := MemoryGetShortError()
        return info
    }

    modulePath := GAME_MP_ModulePath
    if (modulePath = "" || !FileExist(modulePath)) {
        info.Status := "путь azmp.dll не получен"
        return info
    }

    FileGetSize, moduleSize, %modulePath%
    FileGetTime, moduleTime, %modulePath%, M
    cacheKey := modulePath . "|" . moduleSize . "|" . moduleTime . "|" . AzmpExpectedSHA256 . "|" . dwGTAPID . "|" . g_HandleGeneration . "|" . dwSAMP
    if (!force && IsObject(AzmpInfoCache) && AzmpInfoCache.CacheKey = cacheKey)
        return AzmpInfoCache

    expectedHash := AzmpExpectedSHA256
    NormalizeSHA256(expectedHash)
    moduleHash := FileSHA256(modulePath)
    moduleVersion := GetFileVersionSafe(modulePath)
    if (moduleVersion = "")
        moduleVersion := "нет FileVersion"

    info.Ready := (moduleHash != "") ? 1 : 0
    info.Path := modulePath
    info.Version := moduleVersion
    info.SHA256 := moduleHash
    info.Expected := expectedHash
    info.Match := (expectedHash = "") ? MemoryLegacyLayoutCompatible(hGTA, dwSAMP) : (moduleHash = expectedHash)
    if (!info.Ready)
        info.Status := "SHA-256 не вычислен"
    else if (expectedHash = "")
        info.Status := info.Match ? "Совместимый метод примера; SHA-256 необязателен" : "Структура или функции DLL не подходят"
    else if (info.Match)
        info.Status := "SHA-256 совпадает"
    else
        info.Status := "SHA-256 НЕ совпадает"
    info.CacheKey := cacheKey
    AzmpInfoCache := info
    return info
}

GetAzmpCompatibilitySummary(force := 0) {
    info := GetAzmpModuleInfo(force)
    if (!info.Ready)
        return "azmp.dll: " . info.Status
    shortHash := SubStr(info.SHA256, 1, 12)
    return "azmp.dll " . info.Version . " | SHA-256 " . shortHash . "... | " . info.Status
}

AzmpAllowsTargetRead() {
    global AzmpExpectedSHA256
    if (Trim(AzmpExpectedSHA256) = "")
        return true
    info := GetAzmpModuleInfo(0)
    return info.Ready && info.Match
}

HasCurrentID() {
    global UserID
    return RegExMatch(UserID . "", "^\d+$") ? true : false
}

IsGameActive() {
    global MockMode
    if (MockMode = "On" || Training_IsActive())
        return true
    return GameLocator_IsActive()
}

EnsureGameActive() {
    global MockMode
    if (MockMode = "On" || Training_IsActive())
        return true
    if IsGameActive()
        return true
    Notify("warn")
    return false
}

GetCrosshairTargetPed(ByRef errorCode := "", ByRef errorDetail := "") {
    global hGTA
    errorCode := ""
    errorDetail := ""
    if (!checkHandles()) {
        errorCode := "HANDLE_CHECK_FAILED"
        errorDetail := MemoryGetStatusText()
        return 0
    }

    ; В GTA SA адрес 0xB6F3B8 используется как Pointer to Target/current entity.
    ; Именно от него +0x79C исторически даёт Targetted CPed и этот путь работал
    ; в Amazing/SA-MP до fixed8. 0xB6F5F0 оставляем только резервным CPlayerPed.
    primaryBase := readDWORD(hGTA, 0xB6F3B8)
    fallbackBase := readDWORD(hGTA, 0xB6F5F0)
    primaryTarget := IsLikelyPointer(primaryBase) ? readDWORD(hGTA, primaryBase + 0x79C) : 0
    fallbackTarget := IsLikelyPointer(fallbackBase) ? readDWORD(hGTA, fallbackBase + 0x79C) : 0

    localPed := 0
    pedPtr1 := 0
    targetSource := ""

    ; Сначала используем старый рабочий источник. Резерв выбирается только если
    ; первый не даёт живой CPed из GTA pool. Так fixed8 больше не подменяет цель
    ; полем из другого объекта, но остаётся запасной путь для обычной GTA SA.
    if (IsLikelyPointer(primaryTarget) && AZMP_IsPedInGtaPool(primaryTarget, primarySlot, 1)) {
        localPed := primaryBase
        pedPtr1 := primaryTarget
        targetSource := "B6F3B8"
    } else if (IsLikelyPointer(fallbackTarget) && AZMP_IsPedInGtaPool(fallbackTarget, fallbackSlot, 1)) {
        localPed := fallbackBase
        pedPtr1 := fallbackTarget
        targetSource := "B6F5F0_FALLBACK"
    }

    if (!localPed) {
        if (!IsLikelyPointer(primaryBase) && !IsLikelyPointer(fallbackBase)) {
            errorCode := "TARGET_MANAGER_INVALID"
            errorDetail := "targetBase=" . primaryBase . ", playerBase=" . fallbackBase
                . ", " . MemoryGetStatusText()
            return 0
        }
        if (!IsLikelyPointer(primaryTarget) && !IsLikelyPointer(fallbackTarget)) {
            errorCode := "NO_CROSSHAIR_PED"
            errorDetail := "B6F3B8 target=" . primaryTarget . ", B6F5F0 target=" . fallbackTarget
            return 0
        }
        errorCode := "TARGET_PED_OUTSIDE_GTA_POOL"
        errorDetail := "B6F3B8 target=" . Format("0x{:08X}", primaryTarget)
            . ", B6F5F0 target=" . Format("0x{:08X}", fallbackTarget)
            . ", ни один адрес не является занятым CPed GTA pool"
        return 0
    }

    ; Два чтения защищают от смены цели в середине обработки.
    Sleep, 12
    pedPtr2 := readDWORD(hGTA, localPed + 0x79C)
    if (pedPtr2 != pedPtr1) {
        errorCode := "TARGET_PED_UNSTABLE"
        errorDetail := targetSource . ": target changed " . Format("0x{:08X}", pedPtr1)
            . " -> " . Format("0x{:08X}", pedPtr2)
        return 0
    }

    if !AZMP_IsPedInGtaPool(pedPtr1, pedSlot, 1) {
        errorCode := "TARGET_PED_OUTSIDE_GTA_POOL"
        errorDetail := targetSource . ": target=" . Format("0x{:08X}", pedPtr1)
            . ", адрес перестал быть занятым элементом GTA CPed pool"
        return 0
    }

    matrixPtr := readDWORD(hGTA, pedPtr1 + 0x14)
    if (!IsLikelyPointer(matrixPtr) || Mod(matrixPtr, 4) != 0) {
        errorCode := "TARGET_PED_STALE"
        errorDetail := targetSource . ": ped=" . Format("0x{:08X}", pedPtr1) . ", matrix=" . matrixPtr
        return 0
    }
    return pedPtr1
}

GetPedCoordinates(pedPtr) {
    if (!checkReadHandles() || !AZMP_IsValidGamePed(pedPtr))
        return 0
    return AZMP_GetGamePedCoordinates(pedPtr)
}

GetCrosshairTargetDistance(ByRef source := "") {
    global ActiveID, UserID, TargetIsMask
    source := ""
    selfCoords := getPlayerCoordinates()
    if !IsObject(selfCoords)
        return -1

    pedPtr := 0
    if (ActiveID && !TargetIsMask && RegExMatch(UserID . "", "^\d{1,4}$")) {
        pedPtr := getPlayerPedById(UserID + 0)
        if IsLikelyPointer(pedPtr)
            source := "выбранный ID " . UserID
    }

    if !IsLikelyPointer(pedPtr) {
        pedPtr := GetCrosshairTargetPed()
        if IsLikelyPointer(pedPtr)
            source := "персонаж под прицелом"
    }
    if !IsLikelyPointer(pedPtr)
        return -1

    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(targetCoords)
        return -1

    dx := selfCoords[1] - targetCoords[1]
    dy := selfCoords[2] - targetCoords[2]
    dz := selfCoords[3] - targetCoords[3]
    return Sqrt(dx*dx + dy*dy + dz*dz)
}

GetCameraLookAngleToPed(pedPtr) {
    camera := getCameraCoordinates()
    selfCoords := getPlayerCoordinates()
    targetCoords := GetPedCoordinates(pedPtr)
    if !IsObject(camera) || !IsObject(selfCoords) || !IsObject(targetCoords)
        return -1

    vx := selfCoords[1] - camera[1]
    vy := selfCoords[2] - camera[2]
    vz := selfCoords[3] - camera[3]
    tx := targetCoords[1] - camera[1]
    ty := targetCoords[2] - camera[2]
    tz := targetCoords[3] - camera[3]
    viewLen := Sqrt(vx*vx + vy*vy + vz*vz)
    targetLen := Sqrt(tx*tx + ty*ty + tz*tz)
    if (viewLen < 0.2 || targetLen < 0.2)
        return -1
    cosine := (vx*tx + vy*ty + vz*tz) / (viewLen * targetLen)
    if (cosine > 1)
        cosine := 1
    else if (cosine < -1)
        cosine := -1
    return ACos(cosine) * 57.295779513
}

AutoTargetID_SetDiagnostic(code, detail := "") {
    global AutoTargetDiagCode, AutoTargetDiagDetail
    AutoTargetDiagCode := (code = "") ? "UNKNOWN" : code
    AutoTargetDiagDetail := detail
    return AutoTargetDiagCode
}

AutoTargetID_CodeDescription(code) {
    static descriptions := ""
    if !IsObject(descriptions) {
        descriptions := {}
        descriptions["HANDLE_INVALID"] := "потерян дескриптор процесса GTA"
        descriptions["HANDLE_CHECK_FAILED"] := "не удалось подготовить чтение памяти"
        descriptions["PLAYER_POOL_UNAVAILABLE"] := "не найден пул игроков azmp.dll"
        descriptions["POOL_READ_INCOMPLETE"] := "массив игроков прочитан не полностью"
        descriptions["NO_VALID_PLAYER_INFO"] := "в пуле не читаются структуры игроков"
        descriptions["NO_VALID_PEDS"] := "не читаются CPed игроков"
        descriptions["DUPLICATE_TARGET_PED"] := "один CPed связан с несколькими ID"
        descriptions["TARGET_MANAGER_INVALID"] := "сломался указатель менеджера прицела"
        descriptions["TARGET_PED_STALE"] := "указатель цели устарел"
        descriptions["TARGET_POINTER_OFF_AIM"] := "прицел завис на предыдущей цели"
        descriptions["TARGET_IS_LOCAL_PLAYER"] := "игра вернула собственного персонажа"
        descriptions["TARGET_NOT_IN_POOL"] := "цель не найдена в текущем пуле игроков"
        descriptions["TARGET_POOL_LAYOUT_UNRESOLVED"] := "структура PlayerInfo не дала точную связь с выбранным CPed"
        descriptions["TARGET_PED_OUTSIDE_GTA_POOL"] := "игра вернула адрес вне активного GTA CPed pool"
        descriptions["TARGET_PED_UNSTABLE"] := "цель изменилась во время чтения"
        descriptions["TARGET_POOL_DESYNC"] := "прицел GTA и пул игроков AZMP рассинхронизированы"
        descriptions["TARGET_POOL_DESYNC_REPAIRED"] := "устаревший код резервного поиска; ID не должен приниматься"
        descriptions["TARGET_CHANGED_DURING_AIM_FALLBACK"] := "цель изменилась во время резервной проверки"
        descriptions["TARGET_CHANGED_DURING_SCAN"] := "слот игрока изменился во время чтения"
        descriptions["TARGET_NAME_UNSTABLE"] := "ник изменился во время двух проверок"
        descriptions["MASK_LINK_PED_MISMATCH"] := "ID маски не соответствует выбранному PED"
        descriptions["NO_CROSSHAIR_PED"] := "под прицелом нет читаемой цели"
        descriptions["NO_EXACT_ID"] := "для CPed не найден точный ID"
        descriptions["AUTO_RECOVERY"] := "выполнено восстановление чтения памяти"
        descriptions["AUTO_RECOVERY_REOPEN_FAILED"] := "после сброса не удалось повторно открыть память игры"
    }
    return descriptions.HasKey(code) ? descriptions[code] : "неизвестная ошибка Auto ID"
}

AutoTargetID_ClearFailure() {
    global AutoTargetDiagFailStreak, AutoTargetDiagFirstFailTick
    AutoTargetDiagFailStreak := 0
    AutoTargetDiagFirstFailTick := 0
    return true
}

AutoTargetID_ResetDiagnosticState() {
    global AutoTargetDiagCode, AutoTargetDiagDetail
    AutoTargetDiagCode := "INIT"
    AutoTargetDiagDetail := ""
    return true
}

AutoTargetID_IsHardRecoveryCode(code) {
    return (code = "HANDLE_INVALID" || code = "HANDLE_CHECK_FAILED"
        || code = "PLAYER_POOL_UNAVAILABLE" || code = "POOL_READ_INCOMPLETE"
        || code = "NO_VALID_PLAYER_INFO" || code = "NO_VALID_PEDS"
        || code = "TARGET_MANAGER_INVALID")
}

AutoTargetID_WriteDiagnostic(code, detail, targetPed := 0, repaired := "") {
    global AutoTargetDiagFile
    FileCreateDir, % AppHost_DataDir() . "\logs"
    if IsFunc("AZMP_TargetDiagnosticSnapshot")
        snapshot := AZMP_TargetDiagnosticSnapshot(targetPed)
    else
        snapshot := MemoryGetStatusText()
    line := "[" . A_Now . "] code=" . code . "; detail=" . detail
        . "; repaired=" . repaired . "; " . snapshot . "`r`n"
    try FileAppend, %line%, %AutoTargetDiagFile%, CP1251
    LogError("AutoID-DIAG", code . ": " . detail . " | repaired=" . repaired . " | " . snapshot, "WARN")
    return snapshot
}

AutoTargetID_HardReset(reason := "") {
    global AutoTargetLastScanTick, AutoTargetOfferedKey

    AutoTargetLastScanTick := 0
    AutoTargetOfferedKey := ""
    AutoTargetID_ResetCandidate()
    AutoTargetID_ClearFailure()
    AutoTargetID_ResetDiagnosticState()
    if IsFunc("AZMP_ResetAutoIDRuntime")
        AZMP_ResetAutoIDRuntime(reason != "" ? reason : "Auto ID hard reset")
    else {
        AZMP_ResetTargetCache(reason != "" ? reason : "Auto ID hard reset")
        if IsFunc("AZMP_ResetGtaPedPoolCache")
            AZMP_ResetGtaPedPoolCache()
    }
    return true
}

AutoTargetID_DiagnoseAndRecover(showNotice := 1, attemptRepair := 1, knownTargetPed := 0) {
    global AutoTargetDiagCode, AutoTargetDiagDetail, AutoTargetDiagLastRunTick
    global AutoTargetDiagLastNoticeTick, hGTA, dwGTAPID

    if (!knownTargetPed) {
        knownTargetPed := GetCrosshairTargetPed(crossCode, crossDetail)
    } else {
        crossCode := ""
        crossDetail := ""
    }

    code := AutoTargetDiagCode
    detail := AutoTargetDiagDetail
    if (crossCode != "") {
        code := crossCode
        detail := crossDetail
    } else if IsFunc("AZMP_TargetDiagGetCode") {
        lowCode := AZMP_TargetDiagGetCode()
        lowDetail := AZMP_TargetDiagGetDetail()
        lowIsCurrent := !knownTargetPed || !IsFunc("AZMP_TargetDiagIsCurrent")
            || AZMP_TargetDiagIsCurrent(knownTargetPed, 750)
        if (lowIsCurrent && lowCode != "" && lowCode != "TARGET_OK" && lowCode != "INIT") {
            code := lowCode
            detail := lowDetail
        }
    }
    if (code = "" || code = "INIT") {
        code := knownTargetPed ? "NO_EXACT_ID" : "NO_CROSSHAIR_PED"
        detail := knownTargetPed ? "CPed цели есть, но ID не сопоставлен" : "под прицелом нет валидного CPed"
    }

    recoverable := AutoTargetID_IsHardRecoveryCode(code)
    softResettable := (code = "TARGET_PED_STALE" || code = "TARGET_PED_OUTSIDE_GTA_POOL"
        || code = "TARGET_PED_UNSTABLE" || code = "TARGET_POOL_LAYOUT_UNRESOLVED"
        || code = "TARGET_POOL_DESYNC" || code = "NO_EXACT_ID"
        || code = "DUPLICATE_TARGET_PED" || code = "TARGET_CHANGED_DURING_SCAN"
        || code = "TARGET_CHANGED_DURING_AIM_FALLBACK")
    repaired := "нет"
    if (attemptRepair && recoverable) {
        ; Все автоматические переоткрытия проходят через один координатор UDF.
        ; Его общий cooldown исключает двойной reset из UDF и main подряд.
        if IsFunc("AZMP_TargetDiagMaybeRecover") {
            if IsFunc("AZMP_TargetDiagSetContext")
                AZMP_TargetDiagSetContext(knownTargetPed, 0)
            if IsFunc("AZMP_TargetDiagSet")
                AZMP_TargetDiagSet(code, detail, 1, 0)
            recovered := AZMP_TargetDiagMaybeRecover(code, detail, 1)
            recoveryStatus := IsFunc("AZMP_TargetDiagGetRecoveryStatus")
                ? AZMP_TargetDiagGetRecoveryStatus() : ""
            repaired := recovered ? recoveryStatus
                : ((recoveryStatus != "") ? recoveryStatus : "восстановление не запущено")
        } else {
            recoveryStarted := IsFunc("MemoryInvalidateGameHandle")
                ? MemoryInvalidateGameHandle("Auto ID diagnostic: " . code) : false
            if (recoveryStarted) {
                Sleep, 30
                handleOk := checkHandles()
                poolOk := handleOk && IsFunc("AZMP_GetGtaPedPoolInfo")
                    && AZMP_GetGtaPedPoolInfo(recoverPool, recoverObjects, recoverFlags, recoverSize, 1)
                repaired := handleOk ? (poolOk ? "полностью переоткрыты память и CPed pool"
                    : "память переоткрыта; CPed pool будет перечитан") : "переоткрытие не удалось"
            } else {
                repaired := "восстановление отложено: память занята"
            }
        }
    } else if (attemptRepair && code = "TARGET_NOT_IN_POOL") {
        ; Сохраняем привязанную к CPed серию: после четырёх свежих отказов UDF
        ; сам обновит модуль и оба пула. Полный runtime reset здесь мешал этому
        ; порогу и создавал бесконечный цикл частичных сбросов.
        AutoTargetID_ResetCandidate()
        AZMP_ResetTargetCache("diagnostic TARGET_NOT_IN_POOL")
        if IsFunc("AZMP_ResetGtaPedPoolCache")
            AZMP_ResetGtaPedPoolCache()
        repaired := "обновлены кэши цели и GTA CPed pool; дескриптор игры не закрывался"
    } else if (attemptRepair && softResettable) {
        AutoTargetID_HardReset("diagnostic stale CPed/layout mapping: " . code)
        repaired := "полностью сброшены состояние Auto ID и кэш GTA CPed pool"
    }

    AutoTargetDiagLastRunTick := A_TickCount
    snapshot := AutoTargetID_WriteDiagnostic(code, detail, knownTargetPed, repaired)
    if (showNotice) {
        shortDetail := detail
        if (StrLen(shortDetail) > 90)
            shortDetail := SubStr(shortDetail, 1, 87) . "..."
        humanError := AutoTargetID_CodeDescription(code)
        GameNotify("Auto ID: " . humanError . " [" . code . "]. " . shortDetail
            . ". Лог: logs\\autoid_diagnostics.log", recoverable ? "ERROR" : "WARN")
        AutoTargetDiagLastNoticeTick := A_TickCount
    }
    return code
}

AutoTargetID_RecordFailure(code, detail := "", targetPed := 0) {
    global AutoTargetDiagFailStreak, AutoTargetDiagFirstFailTick, AutoTargetDiagLastRunTick
    global AutoTargetDiagLastNoticeTick
    AutoTargetID_SetDiagnostic(code, detail)
    meaningful := AutoTargetID_IsHardRecoveryCode(code)
    if (!meaningful) {
        AutoTargetID_ClearFailure()
        return false
    }
    if (AutoTargetDiagFailStreak = 0)
        AutoTargetDiagFirstFailTick := A_TickCount
    AutoTargetDiagFailStreak += 1

    ; Диагностика запускается только при устойчивом отказе, чтобы обычное
    ; отсутствие цели под прицелом не создавало шум и не переоткрывало процесс.
    if (meaningful && AutoTargetDiagFailStreak >= 8
        && AZMP_TickElapsed(AutoTargetDiagFirstFailTick) >= 1200
        && (AutoTargetDiagLastRunTick = 0 || AZMP_TickElapsed(AutoTargetDiagLastRunTick) >= 6000))
    {
        showAutoNotice := (AutoTargetDiagLastNoticeTick = 0
            || AZMP_TickElapsed(AutoTargetDiagLastNoticeTick) >= 15000)
        AutoTargetID_DiagnoseAndRecover(showAutoNotice, 1, targetPed)
    }
    return false
}

AutoTargetID_ResetCandidate() {
    global AutoTargetCandidateID, AutoTargetCandidateReads
    global AutoTargetCandidatePed, AutoTargetCandidateMatchType
    AutoTargetCandidateID := -1
    AutoTargetCandidateReads := 0
    AutoTargetCandidatePed := 0
    AutoTargetCandidateMatchType := 0
}

AutoTargetID_ReadAimedID(ByRef targetPed := 0, ByRef angle := -1, ByRef targetName := "", ByRef isMask := 0, ByRef matchType := 0) {
    global hGTA
    targetName := ""
    isMask := 0
    matchType := 0
    angle := -1
    targetPed := GetCrosshairTargetPed(targetError, targetDetail)
    if !IsLikelyPointer(targetPed) {
        AutoTargetID_SetDiagnostic(targetError, targetDetail)
        return -1
    }

    localPed := readDWORD(hGTA, 0xB6F5F0)
    if (IsLikelyPointer(localPed) && targetPed = localPed) {
        AutoTargetID_SetDiagnostic("TARGET_IS_LOCAL_PLAYER", "targetPed совпал с локальным CPed " . localPed)
        return -1
    }

    ; m_pPlayerTargettedPed уже является выбранным игрой CPed. Дополнительный
    ; выбор по псевдоуглу камера->локальный игрок был неточным и удалён.
    playerMatch := getPlayerDataByPed(targetPed, aimedId, targetName, 0)
    if (playerMatch = 1 && aimedId >= 0) {
        matchType := 1
        if AZMP_IsMaskDisplayName(targetName)
            targetName := ""
        AutoTargetID_SetDiagnostic("TARGET_OK", "ID " . aimedId . ", ped=" . Format("0x{:08X}", targetPed))
        return aimedId
    }

    ; Полный обход player pool неатомарен. Если за это время прицел перешёл
    ; на другой CPed, ошибка предыдущей цели не должна попадать в recovery.
    targetAfterScan := GetCrosshairTargetPed(postScanCode, postScanDetail)
    if (targetAfterScan != targetPed) {
        changedDetail := "target changed during player-pool scan "
            . Format("0x{:08X}", targetPed) . " -> "
            . (targetAfterScan ? Format("0x{:08X}", targetAfterScan) : "none")
        if (postScanCode != "")
            changedDetail .= "; " . postScanCode . ": " . postScanDetail
        if IsFunc("AZMP_TargetDiagSetContext")
            AZMP_TargetDiagSetContext(targetAfterScan, 0)
        if IsFunc("AZMP_TargetDiagSet")
            AZMP_TargetDiagSet("TARGET_CHANGED_DURING_SCAN", changedDetail)
        AutoTargetID_SetDiagnostic("TARGET_CHANGED_DURING_SCAN", changedDetail)
        return -1
    }

    lowCode := IsFunc("AZMP_TargetDiagGetCode") ? AZMP_TargetDiagGetCode() : "NO_EXACT_ID"
    lowDetail := IsFunc("AZMP_TargetDiagGetDetail") ? AZMP_TargetDiagGetDetail() : ""

    ; ID по направлению прицела больше не угадывается. При ошибке структуры
    ; безопаснее вернуть диагностику, чем назначить чужой ник.
    ; TARGET_NOT_IN_POOL сохраняется отдельным transient-кодом: NPC и короткий
    ; stream-in/out не должны переоткрывать весь дескриптор игры.

    maskResult := getMaskDataByPed(targetPed, maskNumber, linkedPlayerId, 1.15, 3.0)
    if (maskResult > 0) {
        matchType := (linkedPlayerId >= 0) ? 3 : 4
        if (linkedPlayerId >= 0) {
            linkedInfo := AZMP_GetPlayerInfo(linkedPlayerId, 0, 0)
            if (!IsLikelyPointer(linkedInfo) || !AZMP_PlayerInfoMatchesPed(linkedInfo, targetPed, maskLayout)) {
                AutoTargetID_SetDiagnostic("MASK_LINK_PED_MISMATCH", "маска привязана к ID " . linkedPlayerId . ", но CPed не совпал")
                return -1
            }
            targetName := getPlayerNameById(linkedPlayerId)
            if AZMP_IsMaskDisplayName(targetName)
                targetName := ""
            AutoTargetID_SetDiagnostic("TARGET_MASK_LINKED", "ID " . linkedPlayerId . ", layout " . maskLayout)
            return linkedPlayerId
        }
        if (maskNumber != "") {
            isMask := 1
            targetName := ""
            AutoTargetID_SetDiagnostic("TARGET_MASK_ONLY", "маска " . maskNumber)
            return maskNumber
        }
    }

    AutoTargetID_SetDiagnostic(lowCode, lowDetail)
    return -1
}

AutoTargetID_RequestConfirmation(aimedValue, targetPed := 0, angle := -1, source := "RMB", targetName := "", isMask := 0, inputEpoch := 0) {
    global AutoTargetPendingKey, AutoTargetOfferedKey, ContextAssistantMode, ContextAssistantAction
    global ContextAssistantInput, ContextAssistantTargetName, ContextAssistantStatus
    global ContextNotificationMode, ContextNotificationTimeoutSec, hContextAssistantWnd
    if ("V" . aimedValue = "V-1" || "V" . aimedValue = "V")
        return false
    previousCritical := A_IsCritical
    Critical, On
    try {
        if (IsObject(IDCaptureState) || PhysicalInputBusy || (inputEpoch && inputEpoch != AutomationEpoch))
            return false
        ownsConfirmation := AutoTargetPendingKey != "" && ContextAssistantMode = "confirm" && ContextAssistantAction = "EnterID"
        if (ContextAssistantMode != "" && !ownsConfirmation)
            return false
        key := AutoTargetID_TargetKey(aimedValue, targetPed, isMask)
        if (key = AutoTargetOfferedKey)
            return false
        requestValue := isMask ? ("__MASK__:" . aimedValue) : aimedValue
        if (ownsConfirmation) {
            ; Меняем текст существующей плашки без пересоздания и захвата фокуса.
            ContextAssistantInput := requestValue
            ContextAssistantTargetName := targetName
            prompt := ContextAssistant_GetConfirmationPrompt("EnterID", requestValue, "", targetName)
            if (hContextAssistantWnd) {
                GuiControl, 42:, AutoTargetConfirmationPrompt, %prompt%
                WinSet, Redraw,, ahk_id %hContextAssistantWnd%
            } else
                GameNotify(prompt . "  [" . ContextAssistantStatus . "]", "INFO")
            timeoutMs := -Abs(ContextNotificationTimeoutSec * 1000)
            SetTimer, ContextAssistantTimeoutLabel, %timeoutMs%
        } else if !ContextAssistant_Request("EnterID", requestValue, "", targetName)
            return false
        AutoTargetPendingKey := key
        AutoTargetOfferedKey := key
        angleText := (angle >= 0) ? " | угол " . Round(angle, 1) . "°" : ""
        valueText := isMask ? ("Маска " . aimedValue) : ("ID " . aimedValue)
        nameText := (!isMask && targetName != "") ? (" | ник " . targetName) : ""
        LogError("AutoTargetID", source . ": " . valueText . nameText . ", ped " . targetPed . angleText, "INFO")
        return true
    } finally {
        Critical, %previousCritical%
    }
}

AutoTargetID_TargetKey(value, ped, isMask) {
    return "T|" . value . "|" . ped . "|" . isMask
}

AutoTargetID_CaptureNow(showFailure := 1) {
    global AutoTargetIDEnabled, AutoTargetDiagCode, AutoTargetDiagDetail
    if (AutoTargetIDEnabled != "On") {
        if (showFailure)
            GameNotify("Автозахват ID отключён в профиле.", "WARN")
        return false
    }
    if !AzmpAllowsTargetRead() {
        if (showFailure)
            GameNotify("Захват ID заблокирован: SHA-256 azmp.dll не совпадает.", "ERROR")
        return false
    }
    aimedValue := AutoTargetID_ReadAimedID(targetPed, angle, targetName, isMask, matchType)
    if ("V" . aimedValue = "V-1" || "V" . aimedValue = "V") {
        AutoTargetID_RecordFailure(AutoTargetDiagCode, AutoTargetDiagDetail, targetPed)
        if (showFailure)
            AutoTargetID_DiagnoseAndRecover(1, 1, targetPed)
        return false
    }
    AutoTargetID_ClearFailure()
    return AutoTargetID_RequestConfirmation(aimedValue, targetPed, angle, "Ручной захват", targetName, isMask)
}

AutoTargetID_Poll() {
    global AutoTargetIDEnabled, MockMode, AutoTargetCandidateID, AutoTargetCandidateReads
    global AutoTargetCandidatePed, AutoTargetCandidateMatchType, AutoTargetLastScanTick
    global AutoTargetOfferedKey, AutoTargetPendingKey, ContextAssistantMode, ContextAssistantAction
    global UserID, ActiveID, TargetIsMask, AutoTargetDiagCode, AutoTargetDiagDetail

    if (!GetKeyState("RButton", "P")) {
        AutoTargetOfferedKey := ""
        AutoTargetLastScanTick := 0
        AutoTargetID_ResetCandidate()
        AutoTargetID_ClearFailure()
        return
    }
    if (AutoTargetIDEnabled != "On" || MockMode = "On" || Training_IsActive() || IsObject(IDCaptureState) || PhysicalInputBusy)
        return
    ownsConfirmation := AutoTargetPendingKey != "" && ContextAssistantMode = "confirm" && ContextAssistantAction = "EnterID"
    if (ContextAssistantMode != "" && !ownsConfirmation)
        return
    if !GameLocator_IsActive()
        return
    chatState := isInChat()
    if (chatState != 0) {
        AutoTargetID_ResetCandidate()
        return
    }
    if (AutoTargetLastScanTick != 0 && AZMP_TickElapsed(AutoTargetLastScanTick) < 30)
        return
    AutoTargetLastScanTick := A_TickCount
    inputEpoch := AutomationEpoch
    aimedValue := AutoTargetID_ReadAimedID(targetPed, angle, targetName, isMask, matchType)
    if ("V" . aimedValue = "V-1" || "V" . aimedValue = "V") {
        AutoTargetID_RecordFailure(AutoTargetDiagCode, AutoTargetDiagDetail, targetPed)
        AutoTargetID_ResetCandidate()
        return
    }
    AutoTargetID_ClearFailure()
    key := AutoTargetID_TargetKey(aimedValue, targetPed, isMask)
    if (key = AutoTargetOfferedKey)
        return
    if (key = AutoTargetCandidateID)
        AutoTargetCandidateReads += 1
    else {
        AutoTargetCandidateID := key
        AutoTargetCandidateReads := 1
        AutoTargetCandidatePed := targetPed
        AutoTargetCandidateMatchType := matchType
    }
    ; Точный CPed проверяем дважды сразу; запасному поиску даём ещё один такт.
    if ((isMask || matchType != 1) && AutoTargetCandidateReads < 2)
        return
    verifyValue := AutoTargetID_ReadAimedID(verifyPed, verifyAngle, verifyName, verifyIsMask, verifyMatch)
    if ("V" . verifyValue != "V" . aimedValue || verifyPed != targetPed || verifyIsMask != isMask || verifyMatch != matchType) {
        AutoTargetID_ResetCandidate()
        return
    }
    if (inputEpoch != AutomationEpoch || !GameLocator_IsActive() || isInChat() != 0)
        return
    if (ActiveID && TargetIsMask = isMask && "V" . UserID = "V" . aimedValue) {
        if (AutoTargetPendingKey != "" && ContextAssistantAction = "EnterID")
            ContextAssistant_Close()
        AutoTargetOfferedKey := key
    } else
        AutoTargetID_RequestConfirmation(aimedValue, targetPed, verifyAngle, "Автозахват ПКМ", verifyName, isMask, inputEpoch)
    AutoTargetID_ResetCandidate()
}
