; Policy and actual owned-process memory tests. No GTA/SAMP process or function runs.
RunMemoryCompatRegression() {
    local
    sha := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    AuditAssert("Memory legacy: blank SHA permits validated layout", MemoryBuildPolicy("", true))
    AuditAssert("Memory legacy: whitespace SHA keeps default compatibility", MemoryBuildPolicy("  ", true))
    AuditAssert("Memory legacy: unreadable/unsupported layout blocks blank SHA", !MemoryBuildPolicy("", false))
    AuditAssert("Memory legacy: explicit matching SHA needs layout", MemoryBuildPolicy(sha, true, true) && !MemoryBuildPolicy(sha, false, true))
    AuditAssert("Memory legacy: explicit mismatching SHA blocks", !MemoryBuildPolicy(sha, true, false))
    AuditAssert("Memory legacy: malformed nonempty SHA blocks", !MemoryBuildPolicy("BAD", true, true))
    AuditAssert("Memory legacy: case-insensitive explicit SHA", MemoryBuildPolicy("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", true, true))
    AuditAssert("Memory attempt: completed launch succeeds", MemoryAttemptResult(1, 12, 13) = 1)
    AuditAssert("Memory attempt: prelaunch failure permits safe fallback", MemoryAttemptResult(-1, 12, 12) = -1)
    AuditAssert("Memory attempt: unsuccessful launched call forbids fallback/retry", MemoryAttemptResult(-1, 12, 13) = -2)
    AuditAssert("Memory attempt: pending result stays uncertain", MemoryAttemptResult(-2, 12, 12) = -2)
    AuditAssert("Memory attempt: zero result after launch stays uncertain", MemoryAttemptResult(0, 12, 13) = -2)
    AuditAssert("Memory attempt: success without new launch stays successful", MemoryAttemptResult(1, 12, 12) = 1)
    Audit_MemoryExecutableRegion()
    Audit_MemoryCompatNative()
}

Audit_MemoryExecutableRegion() {
    local
    local info := ""
    infoSize := A_PtrSize = 8 ? 48 : 28
    stateOffset := A_PtrSize = 8 ? 32 : 16
    sizeOffset := A_PtrSize = 8 ? 24 : 12
    VarSetCapacity(info, infoSize, 0)
    NumPut(0x20000000, info, 0, "UPtr")
    NumPut(0x20000000, info, A_PtrSize, "UPtr")
    NumPut(0x1000, info, sizeOffset, "UPtr")
    NumPut(0x1000, info, stateOffset, "UInt")
    for index, protection in [0x10, 0x20, 0x40, 0x80] {
        NumPut(protection, info, stateOffset + 4, "UInt")
        AuditAssert("Memory page: executable protection " . protection, MemoryExecutableRegionAllows(info, infoSize, 0x20000100, 16, 0x20000000))
    }
    for index, protection in [1, 2, 4, 8, 0x120] {
        NumPut(protection, info, stateOffset + 4, "UInt")
        AuditAssert("Memory page: nonexecutable/guard protection " . protection, !MemoryExecutableRegionAllows(info, infoSize, 0x20000100, 16))
    }
    NumPut(0x20, info, stateOffset + 4, "UInt")
    AuditAssert("Memory page: truncated query rejected", !MemoryExecutableRegionAllows(info, infoSize - 1, 0x20000100, 16))
    AuditAssert("Memory page: beginning before region rejected", !MemoryExecutableRegionAllows(info, infoSize, 0x1FFFFFFF, 16))
    AuditAssert("Memory page: read beyond executable region rejected", !MemoryExecutableRegionAllows(info, infoSize, 0x20000FF8, 16))
    AuditAssert("Memory page: foreign allocation rejected", !MemoryExecutableRegionAllows(info, infoSize, 0x20000100, 16, 0x30000000))
    NumPut(0x2000, info, stateOffset, "UInt")
    AuditAssert("Memory page: reserved uncommitted region rejected", !MemoryExecutableRegionAllows(info, infoSize, 0x20000100, 16))
}

Audit_MemoryCompatNative() {
    local
    local header := ""
    global hGTA, dwGTAPID, dwSAMP, pMemory, AzmpExpectedSHA256, GAME_MP_ModulePath
    global g_CompatibilityCache, g_CompatibilityLayoutCache, g_RemoteLaunchSerial
    global g_MemoryStage, g_MemoryStageCode, g_MemoryStageDetail, g_MemoryStageTick
    saved := {Handle: hGTA, PID: dwGTAPID, Base: dwSAMP, Memory: pMemory
        , Expected: AzmpExpectedSHA256, Path: GAME_MP_ModulePath
        , HashCache: g_CompatibilityCache, LayoutCache: g_CompatibilityLayoutCache
        , Stage: g_MemoryStage, Code: g_MemoryStageCode, Detail: g_MemoryStageDetail, Tick: g_MemoryStageTick}
    process := 0, base := 0, thread := 0, keepAllocation := false
    fixturePath := A_Temp . "\AHK_memory_compat_" . DllCall("GetCurrentProcessId", "UInt") . ".tmp"
    try {
        pid := DllCall("GetCurrentProcessId", "UInt")
        process := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", false, "UInt", pid, "Ptr")
        Loop, 16 {
            hint := 0x20000000 + (A_Index - 1) * 0x1000000
            base := DllCall("VirtualAlloc", "Ptr", hint, "UPtr", 0x280000, "UInt", 0x3000, "UInt", 4, "Ptr")
            if (base && IsLikelyPointer(base))
                break
            if (base)
                DllCall("VirtualFree", "Ptr", base, "UPtr", 0, "UInt", 0x8000)
            base := 0
        }
        AuditAssert("Memory native: own process and low fixture allocation available", process && base)
        if (!process || !base)
            return
        VarSetCapacity(header, 4096, 0)
        NumPut(0x5A4D, header, 0, "UShort")
        NumPut(0x80, header, 0x3C, "UInt")
        NumPut(0x4550, header, 0x80, "UInt")
        NumPut(0x14C, header, 0x84, "UShort")
        NumPut(0xE0, header, 0x94, "UShort")
        NumPut(0x2102, header, 0x96, "UShort")
        NumPut(0x10B, header, 0x98, "UShort")
        NumPut(0x280000, header, 0xD0, "UInt")
        NumPut(0x1000, header, 0xD4, "UInt")
        DllCall("RtlMoveMemory", "Ptr", base, "Ptr", &header, "UPtr", 4096)
        AuditAssert("Memory native: completed RPM accepts fake PE32 header", MemoryReadModuleIsX86(process, base))
        AuditAssert("Memory native: readable PE32 with writable code is refused", !MemoryLegacyLayoutCompatible(process, base))
        protected := true
        for index, offset in [0x5820, 0x69190, 0x67970, 0x6F8C0] {
            NumPut(0xC3, base + offset, 0, "UChar")
            protected := DllCall("VirtualProtect", "Ptr", base + offset, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection) && protected
        }
        AuditAssert("Memory native: fixture API pages protected executable/readable", protected)
        AuditAssert("Memory native: compatible executable PE32 layout accepted", MemoryLegacyLayoutCompatible(process, base))
        Audit_MemoryCompatGlobalBufferIsolation(process, base)
        for index, offset in [0x5820, 0x69190, 0x67970, 0x6F8C0]
            AuditAssert("Memory native: actual executable API page " . offset, MemoryCodeIsExecutable(process, base + offset, base))
        AuditAssert("Memory native: module ownership mismatch refused", !MemoryCodeIsExecutable(process, base + 0x5820, base + 0x1000000))
        AuditAssert("Memory native: missing handle/address refused", !MemoryCodeIsExecutable(0, base + 0x5820) && !MemoryCodeIsExecutable(process, 0))
        AuditAssert("Memory native: oversized executable read refused", !MemoryCodeIsExecutable(process, base + 0x5820, base, 4097))
        DllCall("VirtualProtect", "Ptr", base + 0x69190, "UPtr", 16, "UInt", 0x120, "UInt*", oldProtection)
        AuditAssert("Memory native: actual guard page refused before RPM", !MemoryCodeIsExecutable(process, base + 0x69190, base))
        DllCall("VirtualProtect", "Ptr", base + 0x69190, "UPtr", 16, "UInt", 4, "UInt*", oldProtection)
        AuditAssert("Memory native: one nonexecutable chat target blocks layout", !MemoryLegacyLayoutCompatible(process, base))
        DllCall("VirtualProtect", "Ptr", base + 0x69190, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection)
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 4, "UInt*", oldProtection)
        DllCall("RtlFillMemory", "Ptr", base + 0x5820, "UPtr", 16, "UChar", 0)
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection)
        AuditAssert("Memory native: zero executable padding refused", !MemoryCodeIsExecutable(process, base + 0x5820, base))
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 4, "UInt*", oldProtection)
        DllCall("RtlFillMemory", "Ptr", base + 0x5820, "UPtr", 16, "UChar", 0xFF)
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection)
        AuditAssert("Memory native: FF executable padding refused", !MemoryCodeIsExecutable(process, base + 0x5820, base))
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 4, "UInt*", oldProtection)
        DllCall("RtlFillMemory", "Ptr", base + 0x5820, "UPtr", 16, "UChar", 0)
        NumPut(0xC3, base + 0x5820, 0, "UChar")
        DllCall("VirtualProtect", "Ptr", base + 0x5820, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection)
        NumPut(0x8664, base + 0x84, 0, "UShort")
        AuditAssert("Memory native: PE x64 machine refused", !MemoryLegacyLayoutCompatible(process, base))
        NumPut(0x14C, base + 0x84, 0, "UShort")
        NumPut(0x70000, base + 0xD0, 0, "UInt")
        AuditAssert("Memory native: image smaller than data offsets refused", !MemoryLegacyLayoutCompatible(process, base))
        NumPut(0x280000, base + 0xD0, 0, "UInt")
        hGTA := process, dwGTAPID := pid, dwSAMP := base, pMemory := 0x12345000
        AzmpExpectedSHA256 := "", GAME_MP_ModulePath := ""
        g_CompatibilityCache := "", g_CompatibilityLayoutCache := ""
        AuditAssert("Memory native: default blank SHA permits validated compatibility", MemoryBuildCompatible())
        AuditAssert("Memory native: build validation never allocates injection buffers", pMemory = 0x12345000)
        AzmpExpectedSHA256 := "BAD"
        AuditAssert("Memory native: malformed explicit SHA remains blocked", !MemoryBuildCompatible() && g_MemoryStage = "BUILD_INVALID")
        AzmpExpectedSHA256 := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        AuditAssert("Memory native: unavailable explicit build file remains blocked", !MemoryBuildCompatible() && g_MemoryStage = "BUILD_UNVERIFIED")
        if FileExist(fixturePath)
            FileDelete, %fixturePath%
        FileAppend, compat-fixture, %fixturePath%
        GAME_MP_ModulePath := fixturePath
        fixtureHash := FileSHA256(fixturePath)
        AuditAssert("Memory native: actual SHA256 fixture available", RegExMatch(fixtureHash, "^[A-F0-9]{64}$"))
        AzmpExpectedSHA256 := fixtureHash
        g_CompatibilityCache := "", g_CompatibilityLayoutCache := ""
        AuditAssert("Memory native: explicit matching SHA plus layout accepted", MemoryBuildCompatible())
        AzmpExpectedSHA256 := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        AuditAssert("Memory native: actual explicit hash mismatch blocked", !MemoryBuildCompatible() && g_MemoryStage = "BUILD_MISMATCH")
        AuditAssert("Memory native: read-only hash helper also rejects mismatch", !MemoryExpectedBuildMatches(AzmpExpectedSHA256))
        AzmpExpectedSHA256 := fixtureHash
        AuditAssert("Memory native: read-only explicit matching hash accepted", MemoryExpectedBuildMatches(fixtureHash))
        beforeSerial := g_RemoteLaunchSerial
        AuditAssert("Memory launch: failed creation leaves serial unchanged", !createRemoteThread(0, 0, 0, base, 0, 0, 0) && g_RemoteLaunchSerial = beforeSerial)
        ; The only launched fixture code is a no-op in this test's own process.
        ; The fixture never launches azmp.dll/GTA code, regardless of host bitness.
        codeAddress := base + 0x71000
        NumPut(0x31, codeAddress + 0, 0, "UChar"), NumPut(0xC0, codeAddress + 0, 1, "UChar")
        if (A_PtrSize = 8)
            NumPut(0xC3, codeAddress + 0, 2, "UChar")
        else {
            NumPut(0xC2, codeAddress + 0, 2, "UChar")
            NumPut(4, codeAddress + 0, 3, "UShort")
        }
        DllCall("VirtualProtect", "Ptr", codeAddress + 0, "UPtr", 16, "UInt", 0x20, "UInt*", oldProtection)
        DllCall("FlushInstructionCache", "Ptr", process, "Ptr", codeAddress + 0, "UPtr", 16)
        thread := createRemoteThread(process, 0, 0, codeAddress + 0, 0, 0, 0)
        AuditAssert("Memory launch: successful own-process no-op increments serial once", thread && g_RemoteLaunchSerial = beforeSerial + 1)
        if (thread) {
            waitResult := DllCall("WaitForSingleObject", "Ptr", thread, "UInt", 1000, "UInt")
            AuditAssert("Memory launch: owned no-op completes within bounded wait", waitResult = 0)
            if (waitResult != 0)
                keepAllocation := true
            else {
                exitCode := -1
                gotExit := DllCall("GetExitCodeThread", "Ptr", thread, "UInt*", exitCode)
                AuditAssert("Memory launch: owned no-op returns zero", gotExit && exitCode = 0)
            }
            closeProcess(thread)
            thread := 0
        }
        AuditAssert("Memory launch: failure after cleaned launch is uncertain", MemoryAttemptResult(-1, beforeSerial) = -2)
        AuditAssert("Memory launch: explicit zero serial is not an omitted argument", MemoryAttemptResult(-1, 0, 0) = -1)
    } finally {
        if (thread)
            DllCall("CloseHandle", "Ptr", thread)
        if (base && !keepAllocation)
            DllCall("VirtualFree", "Ptr", base, "UPtr", 0, "UInt", 0x8000)
        if (process)
            DllCall("CloseHandle", "Ptr", process)
        if FileExist(fixturePath)
            FileDelete, %fixturePath%
        hGTA := saved.Handle, dwGTAPID := saved.PID, dwSAMP := saved.Base, pMemory := saved.Memory
        AzmpExpectedSHA256 := saved.Expected, GAME_MP_ModulePath := saved.Path
        g_CompatibilityCache := saved.HashCache, g_CompatibilityLayoutCache := saved.LayoutCache
        g_MemoryStage := saved.Stage, g_MemoryStageCode := saved.Code
        g_MemoryStageDetail := saved.Detail, g_MemoryStageTick := saved.Tick
        ; g_RemoteLaunchSerial is intentionally monotonic and is never restored.
    }
}

; An existing global from an unrelated GUI/audit must never become an RPM buffer.
Audit_MemoryCompatGlobalBufferIsolation(process, base) {
    local
    local savedHeaderBytes := "", savedInfoBytes := ""
    global header, info
    headerObject := IsObject(header), infoObject := IsObject(info)
    headerCap := headerObject ? 0 : VarSetCapacity(header)
    infoCap := infoObject ? 0 : VarSetCapacity(info)
    savedHeaderValue := header, savedInfoValue := info
    if (headerCap) {
        VarSetCapacity(savedHeaderBytes, headerCap, 0)
        DllCall("RtlMoveMemory", "Ptr", &savedHeaderBytes, "Ptr", &header, "UPtr", headerCap)
    }
    if (infoCap) {
        VarSetCapacity(savedInfoBytes, infoCap, 0)
        DllCall("RtlMoveMemory", "Ptr", &savedInfoBytes, "Ptr", &info, "UPtr", infoCap)
    }
    try {
        header := "", info := ""
        VarSetCapacity(header, 0), VarSetCapacity(info, 0)
        VarSetCapacity(header, 128, 0), VarSetCapacity(info, 128, 0)
        NumPut(0x12345678, header, 0, "UInt")
        NumPut(0x76543210, info, 0, "UInt")
        AuditAssert("Memory ownership: actual PE32 RPM ignores a preexisting global header", MemoryReadModuleIsX86(process, base))
        AuditAssert("Memory ownership: PE32 RPM preserves unrelated global header", VarSetCapacity(header) = 128 && NumGet(header, 0, "UInt") = 0x12345678)
        AuditAssert("Memory ownership: actual executable query ignores global info", MemoryCodeIsExecutable(process, base + 0x5820, base))
        AuditAssert("Memory ownership: executable query preserves unrelated global info", VarSetCapacity(info) = 128 && NumGet(info, 0, "UInt") = 0x76543210)
    } finally {
        if (headerObject)
            header := savedHeaderValue
        else if (headerCap) {
            VarSetCapacity(header, 0), VarSetCapacity(header, headerCap, 0)
            DllCall("RtlMoveMemory", "Ptr", &header, "Ptr", &savedHeaderBytes, "UPtr", headerCap)
            VarSetCapacity(header, -1)
        } else {
            VarSetCapacity(header, 0)
            header := savedHeaderValue
        }
        if (infoObject)
            info := savedInfoValue
        else if (infoCap) {
            VarSetCapacity(info, 0), VarSetCapacity(info, infoCap, 0)
            DllCall("RtlMoveMemory", "Ptr", &info, "Ptr", &savedInfoBytes, "UPtr", infoCap)
            VarSetCapacity(info, -1)
        } else {
            VarSetCapacity(info, 0)
            info := savedInfoValue
        }
    }
}
