#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
SetTitleMatchMode, 3
DetectHiddenWindows, On

; Read-only inspector. Run after opening the settings window.
; No includes, key presses, control changes, or application configuration writes.
; Optional first argument: exact GUI title (default: Настройки профиля).
global GUIAuditControls := []
global GUIAuditLines := []
global GUIAuditFailures := 0
global GUIAuditWarnings := 0
global GUIAuditChecks := 0
global GUIAuditGui := 0
global GUIAuditViewport := ""

auditTitle := A_Args.Length() ? A_Args[1] : "Настройки профиля"
auditReport := A_ScriptDir . "\GUIaudit_report.txt"
oldContext := GUIAudit_PhysicalCoordinates()
try {
    WinGet, auditWindows, List, %auditTitle% ahk_class AutoHotkeyGUI
    if (!auditWindows)
        throw Exception("Окно не найдено: " . auditTitle . ". Откройте настройки и повторите проверку.")
    GUIAuditGui := auditWindows1
    GUIAuditViewport := GUIAudit_ClientScreenRect(GUIAuditGui)
    GUIAuditLines.Push("GUI audit: " . auditTitle)
    GUIAuditLines.Push("Window HWND=" . GUIAuditGui . "; AHK=" . A_AhkVersion . "; PtrSize=" . A_PtrSize . "; ScreenDPI=" . A_ScreenDPI)
    GUIAuditLines.Push("Физическая клиентская область: " . GUIAudit_RectText(GUIAuditViewport))
    GUIAuditLines.Push("Проверяются видимые текстовые подписи, поля ввода и кнопки. Скрытые страницы, фоновые Progress, пустые drag-зоны и внутренние элементы Combo/ListView пропускаются.")
    WinGet, auditChildren, ControlListHwnd, ahk_id %GUIAuditGui%
    Loop, Parse, auditChildren, `n, `r
        GUIAudit_Collect(A_LoopField + 0)
    if (!GUIAuditControls.Length())
        throw Exception("Нет доступных видимых контролов; окно могло закрыться во время проверки.")
    for _, auditControl in GUIAuditControls
        GUIAudit_Measure(auditControl)
    GUIAudit_Overlaps()
} catch auditError {
    GUIAudit_Fail("INSPECTION", auditError.Message)
} finally {
    if (oldContext)
        try DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", oldContext, "Ptr")
}
GUIAuditLines.Push("")
GUIAuditLines.Push("Контролов: " . GUIAuditControls.Length() . "; проверок: " . GUIAuditChecks . "; FAIL: " . GUIAuditFailures . "; WARN: " . GUIAuditWarnings)
GUIAuditLines.Push("Ограничения: Wine может не передавать WM_GETFONT между процессами; в этом случае шрифт пропускается с WARN и не заменяется фиктивным default. Измеряются реальные HWND и их шрифты, а не формулы layout. Это снимок текущей видимой страницы. Повторите проверку на других страницах и при другом DPI. Метрики Win32 не доказывают красоту интерфейса, цветовой контраст или работу OBS. Внутренние отступы кнопок/checkbox оцениваются; тему Windows и прозрачные фоновые артефакты нужно проверить глазами. Ellipsis и штатная прокрутка поля не считаются ошибкой ширины. Частично скрытые viewport контролы допустимы при наличии прокрутки окна.")
auditOutput := ""
for _, auditLine in GUIAuditLines
    auditOutput .= auditLine . "`r`n"
auditFile := FileOpen(auditReport, "w", "UTF-8-RAW")
if (!IsObject(auditFile)) {
    FileAppend, % "Cannot write report: " . auditReport . "`n", *
    ExitApp, 255
}
auditFile.Write(auditOutput)
auditFile.Close()
FileAppend, % "GUI audit: " . GUIAuditFailures . " FAIL, " . GUIAuditWarnings . " WARN; " . auditReport . "`n", *
ExitApp, % Min(255, GUIAuditFailures)

GUIAudit_PhysicalCoordinates() {
    ; A per-monitor aware querying thread avoids DPI virtualisation of HWND rects.
    ; Windows versions without this API retain their normal coordinate context.
    try return DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    catch e
        return 0
}

GUIAudit_Class(hwnd) {
    VarSetCapacity(buffer, 256, 0)
    length := DllCall("User32\GetClassNameW", "Ptr", hwnd, "Ptr", &buffer, "Int", 128, "Int")
    return length > 0 ? StrGet(&buffer, length, "UTF-16") : ""
}

GUIAudit_Message(hwnd, message, wParam, lParam, ByRef result) {
    result := 0
    return DllCall("User32\SendMessageTimeoutW", "Ptr", hwnd, "UInt", message, "UPtr", wParam, "Ptr", lParam, "UInt", 2, "UInt", 250, "UPtrP", result, "UPtr") != 0
}

GUIAudit_Text(hwnd) {
    if !GUIAudit_Message(hwnd, 0xE, 0, 0, length)
        return ""
    length := Min(length, 65535)
    if (length <= 0)
        return ""
    VarSetCapacity(buffer, (length + 1) * 2, 0)
    if !GUIAudit_Message(hwnd, 0xD, length + 1, &buffer, copied)
        return ""
    return StrGet(&buffer, Min(copied, length), "UTF-16")
}

GUIAudit_Rect(hwnd) {
    VarSetCapacity(rect, 16, 0)
    if !DllCall("User32\GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
        return ""
    return {L: NumGet(rect, 0, "Int"), T: NumGet(rect, 4, "Int"), R: NumGet(rect, 8, "Int"), B: NumGet(rect, 12, "Int")}
}

GUIAudit_ClientScreenRect(hwnd) {
    VarSetCapacity(rect, 16, 0)
    if !DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", &rect)
        return ""
    DllCall("User32\MapWindowPoints", "Ptr", hwnd, "Ptr", 0, "Ptr", &rect, "UInt", 2)
    return {L: NumGet(rect, 0, "Int"), T: NumGet(rect, 4, "Int"), R: NumGet(rect, 8, "Int"), B: NumGet(rect, 12, "Int")}
}

GUIAudit_Intersection(a, b) {
    if (!IsObject(a) || !IsObject(b))
        return ""
    l := Max(a.L, b.L), t := Max(a.T, b.T)
    r := Min(a.R, b.R), bottom := Min(a.B, b.B)
    return r > l && bottom > t ? {L: l, T: t, R: r, B: bottom} : ""
}

GUIAudit_RectText(rect) {
    return IsObject(rect) ? "x=" . rect.L . " y=" . rect.T . " w=" . (rect.R - rect.L) . " h=" . (rect.B - rect.T) : "unavailable"
}

GUIAudit_IsLogicalControl(hwnd) {
    global GUIAuditGui
    ancestor := DllCall("User32\GetParent", "Ptr", hwnd, "Ptr")
    Loop, 20 {
        if (ancestor = GUIAuditGui)
            return true
        if (!ancestor)
            return false
        class := GUIAudit_Class(ancestor)
        if (class = "ComboBox" || class = "ComboBoxEx32" || class = "SysListView32" || class = "ListBox" || class = "msctls_hotkey32")
            return false
        ancestor := DllCall("User32\GetParent", "Ptr", ancestor, "Ptr")
    }
    return false
}

GUIAudit_Collect(hwnd) {
    global GUIAuditControls, GUIAuditLines, GUIAuditViewport
    if (!hwnd || !DllCall("User32\IsWindowVisible", "Ptr", hwnd) || !GUIAudit_IsLogicalControl(hwnd))
        return
    class := GUIAudit_Class(hwnd)
    kind := ""
    style := DllCall("User32\GetWindowLongW", "Ptr", hwnd, "Int", -16, "UInt")
    if (class = "Static") {
        type := style & 0x1F
        if (type != 0 && type != 1 && type != 2 && type != 11 && type != 12)
            return
        kind := "Text"
    } else if (class = "Button") {
        if ((style & 0xF) = 7) ; group boxes are decorative panel boundaries.
            return
        kind := "Button"
    } else if (class = "Edit" || class = "ComboBox" || class = "ComboBoxEx32" || class = "msctls_hotkey32")
        kind := "Input"
    else if (class = "SysListView32" || class = "ListBox")
        kind := "List"
    if (kind = "")
        return
    rect := GUIAudit_Rect(hwnd)
    visibleRect := GUIAudit_Intersection(rect, GUIAuditViewport)
    if (!IsObject(visibleRect))
        return
    if (kind = "List" && (visibleRect.R - visibleRect.L) >= (GUIAuditViewport.R - GUIAuditViewport.L) * 0.95 && (visibleRect.B - visibleRect.T) >= (GUIAuditViewport.B - GUIAuditViewport.T) * 0.95) {
        GUIAuditLines.Push("SKIP: fullscreen list/popup HWND=" . hwnd)
        return
    }
    caption := GUIAudit_Text(hwnd)
    if (kind = "Text" && Trim(caption) = "")
        return
    id := GUIAuditControls.Length() + 1
    item := {Id: id, Hwnd: hwnd, Class: class, Kind: kind, Style: style, Text: caption, Rect: rect, VisibleRect: visibleRect}
    GUIAuditControls.Push(item)
    brief := GUIAudit_Brief(caption)
    GUIAuditLines.Push("CONTROL #" . id . " " . class . " HWND=" . hwnd . " " . GUIAudit_RectText(rect) . " text=[" . brief . "]")
    if (visibleRect.L != rect.L || visibleRect.T != rect.T || visibleRect.R != rect.R || visibleRect.B != rect.B)
        GUIAuditLines.Push("INFO: #" . id . " частично скрыт за viewport; собственный размер контрола сохранён для измерения шрифта.")
}

GUIAudit_Brief(value) {
    value := StrReplace(StrReplace(value, "`r", ""), "`n", "\n")
    return StrLen(value) > 140 ? SubStr(value, 1, 137) . "..." : value
}

GUIAudit_Measure(item) {
    global GUIAuditLines, GUIAuditChecks
    if (item.Kind = "List") {
        GUIAuditLines.Push("SKIP: #" . item.Id . " внутреннее содержимое ListView/ListBox.")
        return
    }
    hwnd := item.Hwnd
    if !GUIAudit_Message(hwnd, 0x31, 0, 0, font) {
        GUIAudit_Warn("FONT", "#" . item.Id . " WM_GETFONT недоступен (timeout или ограничение marshalling/GDI).")
        return
    }
    if (!font)
        font := DllCall("Gdi32\GetStockObject", "Int", 17, "Ptr")
    ; Copy LOGFONT into an owned font: a foreign process HFONT may not be
    ; selectable. Failed reads never fall back to fabricated default metrics.
    VarSetCapacity(logfont, 92, 0)
    if (DllCall("Gdi32\GetObjectW", "Ptr", font, "Int", 92, "Ptr", &logfont, "Int") != 92) {
        GUIAudit_Warn("FONT", "#" . item.Id . " LOGFONT недоступен.")
        return
    }
    ownedFont := DllCall("Gdi32\CreateFontIndirectW", "Ptr", &logfont, "Ptr")
    if (!ownedFont) {
        GUIAudit_Warn("FONT", "#" . item.Id . " CreateFontIndirect failed.")
        return
    }
    dc := DllCall("User32\GetDC", "Ptr", hwnd, "Ptr")
    if (!dc) {
        DllCall("Gdi32\DeleteObject", "Ptr", ownedFont)
        GUIAudit_Warn("FONT", "#" . item.Id . " GetDC failed.")
        return
    }
    previousFont := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", ownedFont, "Ptr")
    try {
        if (!previousFont || previousFont = -1)
            throw Exception("SelectObject failed.")
        VarSetCapacity(metrics, 64, 0)
        if !DllCall("Gdi32\GetTextMetricsW", "Ptr", dc, "Ptr", &metrics)
            throw Exception("GetTextMetrics failed.")
        lineHeight := NumGet(metrics, 0, "Int")
        VarSetCapacity(faceBuffer, 128, 0)
        faceLength := DllCall("Gdi32\GetTextFaceW", "Ptr", dc, "Int", 64, "Ptr", &faceBuffer, "Int")
        face := faceLength > 0 ? StrGet(&faceBuffer, "UTF-16") : "unknown"
        weight := NumGet(logfont, 16, "Int")
        VarSetCapacity(client, 16, 0)
        DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", &client)
        availableW := NumGet(client, 8, "Int"), availableH := NumGet(client, 12, "Int")
        if (item.Class = "Edit") {
            VarSetCapacity(editRect, 16, 0)
            if GUIAudit_Message(hwnd, 0xB2, 0, &editRect, unused) {
                ew := NumGet(editRect, 8, "Int") - NumGet(editRect, 0, "Int")
                eh := NumGet(editRect, 12, "Int") - NumGet(editRect, 4, "Int")
                if (ew > 0 && eh > 0)
                    availableW := ew, availableH := eh
            }
        } else if (item.Class = "ComboBox" || item.Class = "ComboBoxEx32") {
            availableW := Max(1, availableW - 24)
            availableH := Max(1, availableH - 4)
        } else if (item.Kind = "Button") {
            buttonType := item.Style & 0xF
            availableW := Max(1, availableW - (buttonType = 2 || buttonType = 3 || buttonType = 4 || buttonType = 5 || buttonType = 6 || buttonType = 9 ? 22 : 12))
            availableH := Max(1, availableH - 4)
        }
        GUIAuditLines.Push("FONT #" . item.Id . " face=" . face . " weight=" . weight . " lineHeight=" . lineHeight . " available=" . availableW . "x" . availableH)
        GUIAuditChecks++
        if (lineHeight > availableH + 1)
            GUIAudit_Fail("FONT_HEIGHT", "#" . item.Id . " высота строки " . lineHeight . " больше доступной " . availableH . ".")
        if (item.Kind = "Input" || item.Text = "") {
            GUIAuditLines.Push("INFO: #" . item.Id . " ширина текста поля не проверяется: ввод может штатно прокручиваться.")
            return
        }
        wrap := false
        ellipsis := false
        single := !InStr(item.Text, "`n")
        flags := 0x400 ; DT_CALCRECT.
        if (item.Kind = "Text") {
            type := item.Style & 0x1F
            ellipsis := (item.Style & 0xC000) != 0
            wrap := type != 11 && type != 12 && !(item.Style & 0x200) && !ellipsis
            if (item.Style & 0x80)
                flags |= 0x800 ; DT_NOPREFIX.
        } else
            wrap := (item.Style & 0x2000) != 0 ; BS_MULTILINE.
        if (wrap)
            flags |= 0x10 ; DT_WORDBREAK.
        else if (single)
            flags |= 0x20 ; DT_SINGLELINE.
        VarSetCapacity(drawRect, 16, 0)
        NumPut(availableW, drawRect, 8, "Int")
        NumPut(availableH, drawRect, 12, "Int")
        units := StrPut(item.Text, "UTF-16") - 1
        VarSetCapacity(textBuffer, (units + 1) * 2, 0)
        StrPut(item.Text, &textBuffer, units + 1, "UTF-16")
        if !DllCall("User32\DrawTextW", "Ptr", dc, "Ptr", &textBuffer, "Int", units, "Ptr", &drawRect, "UInt", flags)
            throw Exception("DrawText CALCRECT failed.")
        neededW := NumGet(drawRect, 8, "Int") - NumGet(drawRect, 0, "Int")
        neededH := NumGet(drawRect, 12, "Int") - NumGet(drawRect, 4, "Int")
        VarSetCapacity(extent, 8, 0)
        DllCall("Gdi32\GetTextExtentPoint32W", "Ptr", dc, "Ptr", &textBuffer, "Int", units, "Ptr", &extent)
        GUIAuditLines.Push("TEXT #" . item.Id . " CALCRECT=" . neededW . "x" . neededH . "; single-run extent=" . NumGet(extent, 0, "Int") . "x" . NumGet(extent, 4, "Int") . "; ellipsis=" . ellipsis)
        GUIAuditChecks++
        if (neededH > availableH + 1)
            GUIAudit_Fail("TEXT_HEIGHT", "#" . item.Id . " тексту требуется " . neededH . " px, доступно " . availableH . ".")
        if (!ellipsis && neededW > availableW + 1)
            GUIAudit_Fail("TEXT_WIDTH", "#" . item.Id . " тексту требуется " . neededW . " px, доступно " . availableW . ".")
    } catch e {
        GUIAudit_Warn("MEASURE", "#" . item.Id . " " . e.Message)
    } finally {
        if (previousFont && previousFont != -1)
            DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", previousFont, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", ownedFont)
        DllCall("User32\ReleaseDC", "Ptr", hwnd, "Ptr", dc)
    }
}

GUIAudit_Overlaps() {
    global GUIAuditControls, GUIAuditChecks
    count := GUIAuditControls.Length()
    for index, a in GUIAuditControls {
        next := index + 1
        while (next <= count) {
            b := GUIAuditControls[next++]
            overlap := GUIAudit_Intersection(a.VisibleRect, b.VisibleRect)
            GUIAuditChecks++
            if IsObject(overlap)
                GUIAudit_Fail("OVERLAP", "#" . a.Id . " " . a.Kind . " [" . GUIAudit_Brief(a.Text) . "] с #" . b.Id . " " . b.Kind . " [" . GUIAudit_Brief(b.Text) . "]; " . GUIAudit_RectText(overlap))
        }
    }
}

GUIAudit_Fail(type, message) {
    global GUIAuditLines, GUIAuditFailures
    GUIAuditFailures++
    GUIAuditLines.Push("FAIL " . type . ": " . message)
}

GUIAudit_Warn(type, message) {
    global GUIAuditLines, GUIAuditWarnings
    GUIAuditWarnings++
    GUIAuditLines.Push("WARN " . type . ": " . message)
}
