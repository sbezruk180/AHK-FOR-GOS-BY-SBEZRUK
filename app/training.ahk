; Offline training is an in-process simulator. It never opens a game handle.
global TrainingSession := ""
global TrainingHwnd := 0
global TrainingRenderTimer := ""
global TrainingHotkeyContext := Func("Training_HotkeysAllowed")
global TrainingChatInput := ""
global TrainingTargetInput := "27"
global TrainingNicknameInput := "Training_Player"
global TrainingGpsNumberInput := "155"
global TrainingPromptValue := ""
global TrainingLedger := ""
global TrainingGPSStatus := ""
global TrainingTargetStatus := ""
global TrainingContextChat := 0
global TrainingContextVehicle := 1
global TrainingContextDistance := 2

Training_IsActive() {
    global TrainingSession
    return IsObject(TrainingSession) && TrainingSession.Active
}

Training_PersistedMockMode() {
    global TrainingSession, MockMode
    return Training_IsActive() ? TrainingSession.Saved.MockMode : MockMode
}

Training_NewModel() {
    return {Ledger: [], LedgerChars: 0, Pending: "", Accepted: "", Rejected: ""
        , Context: {ChatOpen: 0, InVehicle: 1, Distance: 2}
        , GPS: {Stage: "closed", Selected: 0, Digits: "", Result: "", Error: ""}}
}

Training_ModelAppend(model, text) {
    if (!IsObject(model) || !IsObject(model.Ledger))
        return false
    text := SubStr(text . "", 1, 4096)
    FormatTime, stamp,, HH:mm:ss
    row := "[" . stamp . "] " . text
    model.Ledger.Push(row), model.LedgerChars += StrLen(row)
    while (model.Ledger.Length() > 240 || model.LedgerChars > 98304) {
        removed := model.Ledger.RemoveAt(1)
        model.LedgerChars -= StrLen(removed)
    }
    return true
}

Training_ModelKeys(model, keys) {
    if (!IsObject(model) || !IsObject(model.GPS))
        return false
    gps := model.GPS
    if (gps.Stage = "closed" || gps.Stage = "complete")
        return true
    if (InStr(keys, "^a"))
        gps.Digits := ""
    position := 1
    while (position := RegExMatch(keys, "\{([^}]+)\}|([0-9])", token, position)) {
        position += StrLen(token)
        key := token1 != "" ? token1 : token2
        StringLower, key, key
        if (key = "escape" || key = "esc") {
            gps.Stage := "closed", gps.Error := ""
            break
        }
        if (gps.Stage = "list") {
            if (key = "home")
                gps.Selected := 0
            else if (key = "down")
                gps.Selected := Min(1000, gps.Selected + 1)
            else if (key = "up")
                gps.Selected := Max(0, gps.Selected - 1)
            else if (key = "enter")
                gps.Stage := "number", gps.Digits := "", gps.Error := ""
        } else if (gps.Stage = "number") {
            if RegExMatch(key, "^[0-9]$") {
                if (StrLen(gps.Digits) < 5)
                    gps.Digits .= key
                else
                    gps.Error := "Максимум 5 цифр."
            } else if (key = "backspace")
                gps.Digits := SubStr(gps.Digits, 1, Max(0, StrLen(gps.Digits) - 1)), gps.Error := ""
            else if (key = "enter") {
                if (RegExMatch(gps.Digits, "^[0-9]{1,5}$") && gps.Digits + 0 > 0 && gps.Digits + 0 <= 10000) {
                    gps.Stage := "complete"
                    gps.Result := "Метка " . gps.Digits . "; пункт после " . gps.Selected . " нажатий Down."
                    gps.Error := ""
                } else
                    gps.Error := "Нужен номер от 1 до 10000."
            }
        }
    }
    return true
}

Training_ModelRecord(model, text) {
    if !Training_ModelAppend(model, text)
        return false
    if RegExMatch(text . "", "^\[INPUT [^\]]+\] (.*)$", input)
        return Training_ModelKeys(model, input1)
    if RegExMatch(Trim(text . ""), "i)^/gps(?:\s|$)")
        model.GPS := {Stage: "list", Selected: 0, Digits: "", Result: "", Error: ""}
    return true
}

Training_ModelOffer(model, target, nickname := "") {
    target := Trim(target . "")
    if (!IsObject(model) || !RegExMatch(target, "^[0-9]{1,4}$") || target + 0 > 1003)
        return false
    model.Pending := {ID: target + 0, Nickname: SubStr(Trim(nickname), 1, 32)}
    Training_ModelAppend(model, "[AUTO ID] Новая цель " . model.Pending.ID . "; F1 — принять, F2 — отказаться.")
    return true
}

Training_ModelResolveTarget(model, accept) {
    if (!IsObject(model) || !IsObject(model.Pending))
        return false
    target := model.Pending, model.Pending := ""
    if (accept)
        model.Accepted := target
    else
        model.Rejected := target
    Training_ModelAppend(model, "[AUTO ID] " . (accept ? "Принят ID " : "Отклонён ID ") . target.ID)
    return target
}

Training_Open(params*) {
    return Training_Start()
}

Training_Shutdown(params*) {
    return Training_Stop()
}

Training_Start(params*) {
    global TrainingSession, TrainingHwnd, MockMode, UserID, ActiveID, TargetNickname, TargetIsMask
    global g_RemoteOperation, PhysicalInputBusy, LastActionTick
    if Training_IsActive() {
        if (TrainingHwnd)
            Gui, Training:Show
        return true
    }
    if IsObject(g_RemoteOperation) {
        ServiceUI_Notify("Дождитесь завершения операции памяти перед учебным режимом.", 4000, "WARN")
        return false
    }
    CancelAllAutomation(0)
    if (PhysicalInputBusy) {
        ServiceUI_Notify("Ввод ещё завершается. Повторите запуск учебного режима.", 3000, "WARN")
        return false
    }
    saved := {MockMode: MockMode, UserID: UserID, ActiveID: ActiveID, Nickname: TargetNickname, IsMask: TargetIsMask, LastActionTick: LastActionTick}
    TrainingSession := {Active: 1, Saved: saved, Model: Training_NewModel(), Prompt: ""}
    MockMode := "On", LastActionTick := 0
    UserID := "", ActiveID := 0, TargetNickname := "", TargetIsMask := 0
    Training_ModelAppend(TrainingSession.Model, "Учебный режим: команды остаются внутри программы, GTA не требуется.")
    try {
        Training_CreateWindow()
        Training_SetHotkeys(true)
        Training_Render()
        UpdateHUD()
        return true
    } catch error {
        Training_Stop()
        ServiceUI_Notify("Не удалось открыть учебный режим: " . error.Message, 4500, "ERROR")
        return false
    }
}

Training_Stop(params*) {
    global TrainingSession, TrainingHwnd, TrainingRenderTimer, MockMode, UserID, ActiveID, TargetNickname, TargetIsMask, LastActionTick
    if !Training_IsActive()
        return false
    session := TrainingSession
    CancelAllAutomation(0)
    Training_SetHotkeys(false)
    if IsObject(TrainingRenderTimer) {
        callback := TrainingRenderTimer
        SetTimer, %callback%, Delete
        TrainingRenderTimer := ""
    }
    Gui, TrainingPrompt:Destroy
    Gui, Training:Destroy
    TrainingHwnd := 0
    session.Active := 0
    MockMode := session.Saved.MockMode, LastActionTick := session.Saved.LastActionTick
    UserID := session.Saved.UserID, ActiveID := session.Saved.ActiveID
    TargetNickname := session.Saved.Nickname, TargetIsMask := session.Saved.IsMask
    TrainingSession := ""
    if IsFunc("IncidentCard_OnTargetChanged")
        Func("IncidentCard_OnTargetChanged").Call()
    UpdateHUD()
    UpdateIDOverlay()
    return true
}

Training_CreateWindow() {
    global TrainingHwnd, TrainingChatInput, TrainingTargetInput, TrainingNicknameInput, TrainingGpsNumberInput
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    Gui, Training:New, +HwndTrainingHwnd +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox
    Gui, Training:Color, %bg%, %surface%
    Gui, Training:Font, s16 Bold c%fg%, Segoe UI
    Gui, Training:Add, Text, x20 y16 w790 h32 BackgroundTrans, Учебная площадка
    Gui, Training:Font, s9 Norm c%muted%, Segoe UI
    Gui, Training:Add, Text, x20 y52 w800 h32 BackgroundTrans, Обычные действия и конструктор работают с симулятором. Закрытие отменит очередь и вернёт прежний ID.
    Gui, Training:Font, s10 Norm c%inputFg%, Consolas
    Gui, Training:Add, Edit, x20 y90 w514 h256 ReadOnly -Wrap vTrainingLedger,
    Gui, Training:Font, s10 Norm c%fg%, Segoe UI
    Gui, Training:Add, Text, x552 y90 w264 h22 BackgroundTrans, GPS: учебное меню
    Gui, Training:Add, Text, x552 y120 w264 h96 BackgroundTrans vTrainingGPSStatus,
    Gui, Training:Add, Button, x552 y222 w78 h32 hwndgpsOpen, /gps
    Gui, Training:Add, Button, x638 y222 w78 h32 hwndgpsUp, Вверх
    Gui, Training:Add, Button, x724 y222 w92 h32 hwndgpsDown, Вниз
    Gui, Training:Add, Edit, x552 y264 w112 h30 vTrainingGpsNumberInput Limit5, %TrainingGpsNumberInput%
    Gui, Training:Add, Button, x672 y264 w144 h30 hwndgpsDigits, Ввести номер
    Gui, Training:Add, Button, x552 y306 w124 h32 hwndgpsEnter, Enter
    Gui, Training:Add, Button, x684 y306 w132 h32 hwndgpsEsc, Esc
    Gui, Training:Add, Edit, x20 y362 w636 h32 vTrainingChatInput Limit512,
    Gui, Training:Add, Button, x668 y362 w148 h32 Default hwndsend, Отправить
    Gui, Training:Font, s9 Norm c%muted%, Segoe UI
    Gui, Training:Add, Text, x20 y400 w796 h22 BackgroundTrans, Ввод: сообщение, /gps или свой !текстовый_бинд. Это не игровой чат.
    Gui, Training:Font, s10 Norm c%fg%, Segoe UI
    Gui, Training:Add, Text, x20 y436 w46 h24 BackgroundTrans, ID
    Gui, Training:Add, Edit, x56 y430 w76 h30 vTrainingTargetInput Limit4, %TrainingTargetInput%
    Gui, Training:Add, Edit, x144 y430 w226 h30 vTrainingNicknameInput Limit32, %TrainingNicknameInput%
    Gui, Training:Add, Button, x382 y430 w154 h32 hwndoffer, Навестись на цель
    Gui, Training:Add, Button, x548 y430 w128 h32 hwndaccept, F1 — принять
    Gui, Training:Add, Button, x688 y430 w128 h32 hwndreject, F2 — отказ
    Gui, Training:Add, Text, x20 y474 w796 h40 BackgroundTrans vTrainingTargetStatus,
    Gui, Training:Font, s9 Norm c%muted%, Segoe UI
    Gui, Training:Add, Checkbox, x20 y520 w148 h24 vTrainingContextChat, Чат открыт
    Gui, Training:Add, Checkbox, x172 y520 w170 h24 Checked vTrainingContextVehicle, В транспорте
    Gui, Training:Add, Text, x352 y522 w126 h22 BackgroundTrans, Расстояние (м)
    Gui, Training:Add, Edit, x484 y518 w90 h28 vTrainingContextDistance Limit6, 2
    Gui, Training:Add, Button, x588 y516 w228 h30 hwndcontext, Применить условия
    Gui, Training:Font, s10 Norm c%fg%, Segoe UI
    Gui, Training:Add, Button, x20 y568 w176 h34 hwndpalette, Палитра команд
    Gui, Training:Add, Button, x208 y568 w176 h34 hwndbuilder, Конструктор
    Gui, Training:Add, Button, x396 y568 w176 h34 hwndreset, Сбросить учебный чат
    Gui, Training:Add, Button, x640 y568 w176 h34 hwndclose, Завершить обучение
    Training_Bind(gpsOpen, "Training_GPSOpen"), Training_Bind(gpsUp, "Training_GPSKey", "Up")
    Training_Bind(gpsDown, "Training_GPSKey", "Down"), Training_Bind(gpsEnter, "Training_GPSKey", "Enter")
    Training_Bind(gpsEsc, "Training_GPSKey", "Escape"), Training_Bind(gpsDigits, "Training_GPSDigits")
    Training_Bind(send, "Training_Send"), Training_Bind(offer, "Training_OfferFromUI")
    Training_Bind(accept, "Training_Accept"), Training_Bind(reject, "Training_Reject")
    Training_Bind(palette, "Training_OpenPalette"), Training_Bind(builder, "Training_OpenBuilder")
    Training_Bind(context, "Training_ApplyContext")
    Training_Bind(reset, "Training_Reset"), Training_Bind(close, "Training_Stop")
    UIStyle_SetButtonRole(send, "primary"), UIStyle_SetButtonRole(palette, "primary")
    Capture_BeforeShow("Training")
    Gui, Training:Show, w836 h622, AHK FOR GOS - учебный режим
}

Training_Bind(hwnd, functionName, boundValue := "") {
    callback := Func(functionName)
    if (boundValue != "")
        callback := callback.Bind(boundValue)
    GuiControl, Training:+g, %hwnd%, %callback%
}

Training_HotkeysAllowed(hotkeyName := "") {
    global TrainingHwnd
    return Training_IsActive() && TrainingHwnd && WinActive("ahk_id " . TrainingHwnd) && !ServiceUI_IsInputActive()
}

Training_SetHotkeys(enabled) {
    global TrainingHotkeyContext
    Hotkey, If, %TrainingHotkeyContext%
    try {
        if (enabled) {
            Hotkey, F1, % Func("Training_Accept"), On UseErrorLevel
            Hotkey, F2, % Func("Training_Reject"), On UseErrorLevel
        } else {
            Hotkey, F1, Off, UseErrorLevel
            Hotkey, F2, Off, UseErrorLevel
        }
    } finally {
        Hotkey, If
    }
}

Training_RecordOutput(text) {
    global TrainingSession, TrainingRenderTimer
    if !Training_IsActive()
        return false
    Training_ModelRecord(TrainingSession.Model, text)
    if (!AuditTestMode && TrainingHwnd) {
        if !IsObject(TrainingRenderTimer)
            TrainingRenderTimer := Func("Training_Render")
        callback := TrainingRenderTimer
        SetTimer, %callback%, -30
    }
    return true
}

Training_Render(params*) {
    global TrainingSession, TrainingHwnd
    if (!Training_IsActive() || !TrainingHwnd)
        return false
    model := TrainingSession.Model, transcript := ""
    for _, row in model.Ledger
        transcript .= (transcript = "" ? "" : "`r`n") . row
    GuiControl, Training:, TrainingLedger, %transcript%
    gps := model.GPS
    stageText := gps.Stage = "closed" ? "Закрыт" : (gps.Stage = "list" ? "Выбор пункта" : (gps.Stage = "number" ? "Ввод номера" : "Маршрут построен"))
    gpsText := stageText . "`nНажатий Down: " . gps.Selected . "`nНомер: " . (gps.Digits = "" ? "—" : gps.Digits)
    if (gps.Result != "")
        gpsText .= "`n" . gps.Result
    else if (gps.Error != "")
        gpsText .= "`n" . gps.Error
    GuiControl, Training:, TrainingGPSStatus, %gpsText%
    target := IsObject(model.Pending) ? "Предлагается ID " . model.Pending.ID . " · " . model.Pending.Nickname . ". F1 / F2 действуют в этом окне." : "Наведитесь на учебную цель кнопкой выше. Новая цель заменит предложение сразу."
    if IsObject(model.Accepted)
        target .= "`nПринят ID " . model.Accepted.ID . " · " . model.Accepted.Nickname
    GuiControl, Training:, TrainingTargetStatus, %target%
    return true
}

Training_Send(params*) {
    global TrainingSession
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    GuiControlGet, input, Training:, TrainingChatInput
    input := Trim(input)
    if (input = "")
        return false
    GuiControl, Training:, TrainingChatInput,
    if (SubStr(input, 1, 1) = "!") {
        action := PrivateText_Resolve(input)
        if !IsObject(action) {
            Training_RecordOutput("[TXT] Команда не найдена: " . input)
            return false
        }
        return PrivateText_Dispatch(action, AutomationEpoch)
    }
    return SendChat(input, "Training") = 1
}

Training_OfferFromUI(params*) {
    global TrainingSession
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    GuiControlGet, target, Training:, TrainingTargetInput
    GuiControlGet, nickname, Training:, TrainingNicknameInput
    ok := Training_ModelOffer(TrainingSession.Model, target, nickname)
    if (!ok)
        Training_RecordOutput("[AUTO ID] Допустим ID от 0 до 1003.")
    Training_Render()
    return ok
}

Training_Accept(params*) {
    global TrainingSession
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    target := Training_ModelResolveTarget(TrainingSession.Model, true)
    if !IsObject(target)
        return false
    ShowIDGui(target.ID, target.Nickname, 0)
    Training_Render()
    return true
}

Training_Reject(params*) {
    global TrainingSession
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    ok := IsObject(Training_ModelResolveTarget(TrainingSession.Model, false))
    Training_Render()
    return ok
}

Training_GPSOpen(params*) {
    if !Training_IsActive()
        return false
    return SendChat("/gps", "Training GPS") = 1
}

Training_GPSKey(key, params*) {
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    return Training_RecordOutput("[INPUT Event] {" . key . "}")
}

Training_GPSDigits(params*) {
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    GuiControlGet, number, Training:, TrainingGpsNumberInput
    if !RegExMatch(number, "^[0-9]{1,5}$")
        return Training_RecordOutput("[GPS] Введите от 1 до 5 цифр.")
    return Training_RecordOutput("[INPUT Event] ^a{Backspace}" . number)
}

Training_Reset(params*) {
    global TrainingSession, UserID, ActiveID, TargetNickname, TargetIsMask
    if !Training_IsActive()
        return false
    CancelAllAutomation(0)
    TrainingSession.Model := Training_NewModel()
    GuiControl, Training:, TrainingContextChat, 0
    GuiControl, Training:, TrainingContextVehicle, 1
    GuiControl, Training:, TrainingContextDistance, 2
    UserID := "", ActiveID := 0, TargetNickname := "", TargetIsMask := 0
    UpdateHUD(), UpdateIDOverlay()
    Training_RecordOutput("Учебная сессия сброшена. Настройки и профили сохранены.")
    Training_Render()
    return true
}

Training_SetVirtualContext(chatOpen, inVehicle, distance) {
    global TrainingSession
    if (!Training_IsActive() || !RegExMatch(distance . "", "^[0-9]{1,4}(?:[.,][0-9]{1,2})?$"))
        return false
    distance := StrReplace(distance . "", ",", ".") + 0
    if (distance > 1000)
        return false
    TrainingSession.Model.Context := {ChatOpen: !!chatOpen, InVehicle: !!inVehicle, Distance: distance}
    return true
}

Training_ApplyContext(params*) {
    if (!Training_IsActive() || ServiceUI_IsInputActive())
        return false
    GuiControlGet, chatOpen, Training:, TrainingContextChat
    GuiControlGet, inVehicle, Training:, TrainingContextVehicle
    GuiControlGet, distance, Training:, TrainingContextDistance
    if !Training_SetVirtualContext(chatOpen, inVehicle, distance)
        return Training_RecordOutput("[УСЛОВИЯ] Укажите расстояние от 0 до 1000 метров.")
    return Training_RecordOutput("[УСЛОВИЯ] Чат " . (chatOpen ? "открыт" : "закрыт") . "; транспорт: " . (inVehicle ? "да" : "нет") . "; до цели " . distance . " м. Условия моделируются.")
}

Training_CanRunAction(actionName, needsID := false, checkChatClosed := true, requireVehicle := false, requireChatOpen := false, requireCloseRange := false) {
    global TrainingSession, IDCheckEnabled, SafeModeEnabled, SafeBlockWhenChat, SafeVehicleChecks
    global SafeRequireChatForEditable, SafeDistanceChecks, SafeDistanceLimit, ActionCooldownMs, LastActionTick
    if !Training_IsActive()
        return false
    context := TrainingSession.Model.Context
    reason := "", master := SafeModeEnabled = "On"
    if (needsID && IDCheckEnabled && !HasCurrentID())
        reason := "Учебная цель не выбрана: предложите ID и примите F1."
    else if (requireChatOpen && (master || SafeRequireChatForEditable = "On") && !context.ChatOpen)
        reason := "В учебных условиях чат закрыт."
    else if (checkChatClosed && (master || SafeBlockWhenChat = "On") && context.ChatOpen)
        reason := "В учебных условиях чат открыт."
    else if (requireVehicle && (master || SafeVehicleChecks = "On") && !context.InVehicle)
        reason := "В учебных условиях транспорт отсутствует."
    else if ((requireCloseRange || (needsID && SafeDistanceChecks = "On")) && (master || SafeDistanceChecks = "On")
        && context.Distance > Min(50, Max(2, SafeDistanceLimit + 0)))
        reason := "В учебных условиях цель слишком далеко: " . context.Distance . " м."
    else if (ActionCooldownMs > 0 && LastActionTick > 0 && TickNow() - LastActionTick < Min(5000, ActionCooldownMs))
        reason := "Не завершена пауза между учебными действиями."
    if (reason != "") {
        Training_RecordOutput("[ПРОВЕРКА] " . reason)
        if IsFunc("ActionTrace_Rejected")
            Func("ActionTrace_Rejected").Call(actionName, reason)
        return false
    }
    LastActionTick := TickNow()
    return true
}

Training_OpenPalette(params*) {
    if (Training_IsActive() && IsFunc("CommandPalette_Open"))
        return Func("CommandPalette_Open").Call()
    return false
}

Training_OpenBuilder(params*) {
    if Training_IsActive()
        return OpenCustomFunctionBuilder()
    return false
}

; Used by ServiceUI_Request before its scripted MockMode branch. No game focus,
; clipboard, InputHook or memory access is involved in this desktop prompt.
Training_Request(title, prompt, ByRef value, maxLen := 180, timeoutSeconds := 45, seed := "", confirmOnSpace := false) {
    global TrainingSession, ServiceUIInputState, PhysicalInputBusy, TrainingPromptValue
    if (!Training_IsActive() || PhysicalInputBusy || ServiceUI_IsInputActive() || IsObject(IDCaptureState))
        return false
    state := {Epoch: AutomationEpoch, Profile: CurrentProfile, Pending: "", OwnsBusy: 1, GuiHwnd: 0
        , Deadline: TickNow() + Min(180, Max(1, Round(timeoutSeconds))) * 1000, Value: ""}
    maxLen := Min(512, Max(1, Round(maxLen)))
    ServiceUIInputState := state, PhysicalInputBusy := 1
    try {
        GetThemeColors(bg, panel, fg, accent, muted)
        GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
        Gui, TrainingPrompt:New, +HwndpromptHwnd +AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox
        state.GuiHwnd := promptHwnd
        TrainingSession.Prompt := state
        Gui, TrainingPrompt:Color, %panel%, %surface%
        Gui, TrainingPrompt:Font, s12 Bold c%fg%, Segoe UI
        Gui, TrainingPrompt:Add, Text, x20 y16 w500 h28 BackgroundTrans, % SubStr(title . "", 1, 120) . " · обучение"
        Gui, TrainingPrompt:Font, s10 Norm c%fg%, Segoe UI
        Gui, TrainingPrompt:Add, Text, x20 y58 w500 h94 BackgroundTrans, % SubStr(prompt . "", 1, 1500)
        Gui, TrainingPrompt:Add, Edit, x20 y164 w500 h32 vTrainingPromptValue Limit%maxLen%, % SubStr(seed, 1, maxLen)
        Gui, TrainingPrompt:Add, Button, x248 y214 w128 h34 Default hwndaccept, Подтвердить
        Gui, TrainingPrompt:Add, Button, x388 y214 w132 h34 hwndcancel, Отмена
        callback := Func("Training_PromptComplete").Bind(state, true)
        GuiControl, TrainingPrompt:+g, %accept%, %callback%
        callback := Func("Training_PromptComplete").Bind(state, false)
        GuiControl, TrainingPrompt:+g, %cancel%, %callback%
        Capture_BeforeShow("TrainingPrompt")
        Gui, TrainingPrompt:Show, w540 h268, AHK FOR GOS - учебный ввод
        GuiControl, TrainingPrompt:Focus, TrainingPromptValue
        while (state.Pending = "") {
            if (!Training_IsActive() || state.Epoch != AutomationEpoch || state.Profile != CurrentProfile
                || TickNow() >= state.Deadline || !DllCall("IsWindow", "Ptr", promptHwnd)
                || DllCall("GetForegroundWindow", "Ptr") != promptHwnd) {
                state.Pending := "cancel"
                break
            }
            Sleep, 30
        }
        if (state.Pending != "confirm" || !Training_IsActive() || state.Epoch != AutomationEpoch
            || state.Profile != CurrentProfile || StrLen(state.Value) > maxLen)
            return false
        value := state.Value
        return true
    } finally {
        Gui, TrainingPrompt:Destroy
        if (ServiceUIInputState == state)
            ServiceUIInputState := ""
        if (state.OwnsBusy) {
            state.OwnsBusy := 0
            PhysicalInputBusy := 0
        }
        if (Training_IsActive() && TrainingSession.Prompt == state)
            TrainingSession.Prompt := ""
    }
}

Training_PromptComplete(state, confirmed, params*) {
    if (!Training_IsActive() || ServiceUIInputState != state || state.Pending != ""
        || state.Epoch != AutomationEpoch || state.Profile != CurrentProfile
        || TickNow() >= state.Deadline || DllCall("GetForegroundWindow", "Ptr") != state.GuiHwnd)
        return false
    if (confirmed) {
        GuiControlGet, input, TrainingPrompt:, TrainingPromptValue
        state.Value := input
    }
    state.Pending := confirmed ? "confirm" : "cancel"
    return true
}

Training_Confirm(title, text) {
    answer := ""
    return Training_Request(title, text . "`nВведите 1 — Да, 0 — Нет.", answer, 1, 60) && answer = "1"
}

TrainingGuiClose() {
    Training_Stop()
}

TrainingGuiEscape() {
    Training_Stop()
}

TrainingPromptGuiClose() {
    global TrainingSession
    if (Training_IsActive() && IsObject(TrainingSession.Prompt))
        Training_PromptComplete(TrainingSession.Prompt, false)
}

TrainingPromptGuiEscape() {
    TrainingPromptGuiClose()
}
