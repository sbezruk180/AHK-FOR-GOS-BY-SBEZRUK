; Actual storage, identity, corruption, keyboard-safe GUI and bounded chat tests.
IncidentCard_RunRegression(scratch := "") {
    global IncidentCardChatTail, IncidentCardWriteBusy
    root := (scratch != "" ? scratch : AppHost_DataDir()) . "\incident-regression-" . DllCall("GetCurrentProcessId")
    FileCreateDir, %root%
    savedTail := IncidentCardChatTail, savedBusy := IncidentCardWriteBusy
    try {
        t0 := IncidentCard_NormalizeTarget("0", "Zero_Player", 0, "Основной")
        AuditAssert("Incident: player ID zero remains valid", IsObject(t0) && "ID:" . t0.ID = "ID:0")
        t := IncidentCard_NormalizeTarget("007", "Иван_Иванов", 0, "Основной")
        AuditAssert("Incident: ordinary ID canonicalizes without numeric mask conversion", t.ID = "7" && t.Nickname = "Иван_Иванов")
        mask := IncidentCard_NormalizeTarget("00123456789012345678", "Ignored_Name", 1, "Основной")
        AuditAssert("Incident: long mask stays an exact string with hidden nickname", mask.ID = "00123456789012345678" && mask.Nickname = "")
        AuditAssert("Incident: rejects invalid IDs and path-looking targets", !IsObject(IncidentCard_NormalizeTarget("../7")) && !IsObject(IncidentCard_NormalizeTarget("1000000")) && !IsObject(IncidentCard_NormalizeTarget("12", "", 1)))
        card := IncidentCard_CreateRecord(t, "20261026153000")
        second := IncidentCard_CreateRecord(t, "20261026153000")
        AuditAssert("Incident: same-second cases have distinct safe filenames", card.RecordID != second.RecordID && IncidentCard_ValidRecordID(card.RecordID))
        card.Notes := "Первая строка`r`nВторая = [данные] {NL} «цитата»"
        item := {DocCode: "UK", DocName: "Уголовный кодекс", ItemId: "5.1", Title: "Статья 5.1", Text: "Текст нормы с кириллицей", Article: "5.1", Chapter: "", ChapterTitle: "", ArticleTitle: "", Part: "", PartTitle: "", Point: "", PointTitle: "", SubPoint: "", SubPointTitle: ""}
        AuditAssert("Incident: legal result captured as a snapshot", IncidentCard_AddLaw(card, item) && card.Laws.Length() = 1 && card.Laws[1].Text = item.Text)
        AuditAssert("Incident: same legal result cannot silently duplicate", !IncidentCard_AddLaw(card, item) && card.Laws.Length() = 1)
        text := IncidentCard_EncodeRecord(card), restored := IncidentCard_DecodeRecord(text, card.RecordID)
        AuditAssert("Incident: CP1251 notes and literal markers round-trip", IsObject(restored) && restored.Notes = card.Notes && restored.Nickname = card.Nickname && restored.Laws[1].Text = item.Text)
        AuditAssert("Incident: duplicate metadata rejected", !IsObject(IncidentCard_DecodeRecord(text . "ID=" . EncodeIniText("8") . "`r`n", card.RecordID)))
        AuditAssert("Incident: incorrect length and NUL payload rejected", !IncidentCard_IsEncodedText("H1:1:4142") && !IncidentCard_IsEncodedText("H1:2:4100"))
        AuditAssert("Incident: wrong record identity rejected", !IsObject(IncidentCard_DecodeRecord(text, second.RecordID)))
        AuditAssert("Incident: storage traversal rejected", !IsObject(IncidentCard_LoadRecord("..\profiles", root)))
        AuditAssert("Incident: dedicated record writes to disk", IncidentCard_SaveRecord(card, root))
        read := IncidentCard_LoadRecord(card.RecordID, root)
        AuditAssert("Incident: actual file reads all fields", IsObject(read) && read.Notes = card.Notes && read.Laws[1].Key = "UK|5.1")
        prior := IncidentCard_EncodeRecord(read), card.Notes := ""
        Loop, 16001
            card.Notes .= "А"
        AuditAssert("Incident: oversized notes never replace saved source", !IncidentCard_SaveRecord(card, root) && IncidentCard_EncodeRecord(IncidentCard_LoadRecord(card.RecordID, root)) = prior)
        card := read
        un := IncidentCard_CreateRecord(IncidentCard_NormalizeTarget("7", "", 0, "Основной"))
        IncidentCard_SaveRecord(un, root)
        entries := [IncidentCard_RecordEntry(un)]
        un.Nickname := "Player_Alpha"
        IncidentCard_SaveRecord(un, root)
        different := IncidentCard_NormalizeTarget("7", "Player_Beta", 0, "Основной")
        AuditAssert("Incident: stale unnamed index never merges reused IDs", !IsObject(IncidentCard_FindRecord(different, entries, root)))
        old := IncidentCard_FindRecord(IncidentCard_NormalizeTarget("7", "Player_Alpha", 0, "Основной"), entries, root)
        AuditAssert("Incident: original player retains their saved record", IsObject(old) && old.RecordID = un.RecordID)
        AuditAssert("Incident: target identity includes profile and mask kind", !IncidentCard_TargetMatches(card, IncidentCard_NormalizeTarget("7", "Иван_Иванов", 0, "Другой")))
        AuditAssert("Incident: nickname boundaries prevent similar player matches", IncidentCard_LineMatches("Иван_Иванов: здравствуйте", card) && !IncidentCard_LineMatches("Иван_Иванович: текст", card))
        AuditAssert("Incident: ID boundaries prevent suffix and unrelated numeric matches", IncidentCard_LineMatches("Игрок[7]: сообщение", card) && IncidentCard_LineMatches("ID: 7", card) && !IncidentCard_LineMatches("Игрок[77]: текст", card) && !IncidentCard_LineMatches("Номер дома 7", card))
        AuditAssert("Incident: unknown mask never associates arbitrary numeric chat", !IncidentCard_LineMatches("Игрок[00123456789012345678]: текст", IncidentCard_CreateRecord(mask)))
        IncidentCardChatTail := []
        Loop, 100
            IncidentCard_OnChatLine("Строка " . A_Index, true)
        AuditAssert("Incident: incoming chat history is bounded at 80", IncidentCardChatTail.Length() = 80 && IncidentCardChatTail[1] = "Строка 21")
        card.Chat := []
        lines := ["Иван_Иванов: строка", "Игрок[7]: действие", "Другой_Игрок: не относится"]
        AuditAssert("Incident: chat collects only relevant nonduplicate lines", IncidentCard_CollectChat(card, lines) = 2 && IncidentCard_CollectChat(card, lines) = 0 && card.Chat.Length() = 2)
        Loop, 30
            lines.Push("Игрок[7]: событие " . A_Index)
        IncidentCard_CollectChat(card, lines)
        AuditAssert("Incident: saved chat capped at 24 complete lines", card.Chat.Length() = 24 && InStr(card.Chat[24], "событие 30"))
        export := IncidentCard_Export(card, root)
        file := FileOpen(export, "r", "UTF-8"), output := IsObject(file) ? file.Read() : ""
        if IsObject(file)
            file.Close()
        AuditAssert("Incident: actual readable UTF8 export preserves notes", export != "" && InStr(output, card.Notes) && InStr(output, "Статья 5.1") && InStr(output, "UTC"))
        other := IncidentCard_CreateRecord(IncidentCard_NormalizeTarget("8", "Другой_Игрок", 0, "Основной"))
        IncidentCard_SaveRecord(other, root)
        all := IncidentCard_LoadEntries(root)
        AuditAssert("Incident: separate targets remain separate persisted cases", all.Length() = 3 && IsObject(IncidentCard_LoadRecord(card.RecordID, root)) && IsObject(IncidentCard_LoadRecord(other.RecordID, root)))
        IncidentCardWriteBusy := 1
        AuditAssert("Incident: reentrant writer refuses without changing a saved file", !IncidentCard_SaveRecord(card, root))
        IncidentCardWriteBusy := 0
        AuditAssert("Incident: entry metadata never retains note or law buffers", !IncidentCard_RecordEntry(card).HasKey("Notes") && !IncidentCard_RecordEntry(card).HasKey("Laws"))
        return true
    } finally {
        IncidentCardChatTail := savedTail, IncidentCardWriteBusy := savedBusy
        FileRemoveDir, %root%, 1
    }
}

IncidentCard_RunDesktopChecks() {
    global IncidentCardCurrent, IncidentCardHwnd, IncidentCardNotesHwnd, UserID, ActiveID, TargetNickname, TargetIsMask
    global IncidentCardEnabled, IncidentCardEntries
    priorID := UserID, priorActive := ActiveID, priorNick := TargetNickname, priorMask := TargetIsMask
    priorCurrent := IncidentCardCurrent, priorEnabled := IncidentCardEnabled, priorEntries := IncidentCardEntries
    try {
        UserID := "7", ActiveID := 1, TargetNickname := "Test_Player", TargetIsMask := 0
        IncidentCardCurrent := "", IncidentCardEnabled := 0, IncidentCardEntries := []
        DesktopSmoke_Assert("incident journal opens real native window", IncidentCard_Open() && DllCall("IsWindow", "Ptr", IncidentCardHwnd))
        GuiControl, IncidentJournal:, IC_Notes, Заметка первой цели
        firstID := IncidentCardCurrent.RecordID
        UserID := "8", TargetNickname := "Second_Player"
        DesktopSmoke_Assert("incident target hook persists a different card", IncidentCard_OnTargetChanged(true) && IncidentCardCurrent.RecordID != firstID && IncidentCardCurrent.ID = "8")
        first := IncidentCard_LoadRecord(firstID)
        DesktopSmoke_Assert("incident switching target preserves unsaved native notes", IsObject(first) && first.Notes = "Заметка первой цели")
        GuiControl, IncidentJournal:, IC_Notes, Вторая карточка
        DesktopSmoke_Assert("incident Save persists native Edit contents", IncidentCard_SaveButton() && IncidentCard_LoadRecord(IncidentCardCurrent.RecordID).Notes = "Вторая карточка")
        DesktopSmoke_Assert("incident export writes actual readable record", IncidentCard_ExportButton())
        IncidentCard_Close()
        DesktopSmoke_Assert("incident close releases native window", !IncidentCardHwnd)
    } finally {
        IncidentCard_Close()
        UserID := priorID, ActiveID := priorActive, TargetNickname := priorNick, TargetIsMask := priorMask
        IncidentCardCurrent := priorCurrent, IncidentCardEnabled := priorEnabled, IncidentCardEntries := priorEntries
    }
}
