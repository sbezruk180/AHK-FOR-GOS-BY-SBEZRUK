; The input flag is a Win32 BOOL, not a normalized 0/1 enum.
RunChatStateRegression() {
    for index, rawState in [0, 1, 2, 255, 0xFFFFFFFF]
        AuditAssert("Chat BOOL completed DWORD " . rawState, AZMP_ChatStateFromRead(rawState, false) = (rawState ? 1 : 0))
    for index, rawState in [0, 1, 2, 255, 0xFFFFFFFF]
        AuditAssert("Chat BOOL failed DWORD stays unknown " . rawState, AZMP_ChatStateFromRead(rawState, true) = -1)
    AuditAssert("Chat BOOL memory error code stays unknown", AZMP_ChatStateFromRead(0, 6) = -1)
    for index, rawState in ["", "invalid", -1, 4294967296, 1.5]
        AuditAssert("Chat BOOL rejects malformed raw flag " . index, AZMP_ChatStateFromRead(rawState) = -1)
}
