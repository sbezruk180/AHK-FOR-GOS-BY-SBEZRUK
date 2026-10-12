; One palette for every application GUI. Hooks affect registered own windows.
; No control is moved and no activation/capture flags are changed here.
global UIStyleWindows := {}
global UIStyleBrushes := {}
global UIStyleInstalled := 0

UIStyle_Install() {
    global UIStyleInstalled
    if (UIStyleInstalled)
        return
    for _, message in [0x133, 0x134, 0x135, 0x136, 0x138]
        OnMessage(message, "UIStyle_ControlColor")
    OnMessage(0x2B, "UIStyle_DrawButton")
    UIStyleInstalled := 1
}

UIStyle_Brush(hex) {
    global UIStyleBrushes
    if (!UIStyleBrushes.HasKey(hex))
        UIStyleBrushes[hex] := DllCall("CreateSolidBrush", "UInt", HexToBGR(hex), "Ptr")
    return UIStyleBrushes[hex]
}

UIStyle_Apply(guiName, hwnd) {
    global UIStyleWindows
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return false
    UIStyle_Install()
    UIStyle_Prune()
    GetThemeColors(bg, panel, fg, accent, muted)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    palette := {Name: guiName, BG: bg, Panel: panel, Text: fg, Accent: accent
        , Muted: muted, Surface: surface, InputText: inputFg, Edge: edge}
    UIStyleWindows[hwnd] := palette
    ; A floating panel uses the same surface as cards in settings.
    base := panel
    palette.Background := base
    Gui, %guiName%:Color, %base%, %surface%
    oldHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    try {
        WinGet, children, ControlListHwnd, ahk_id %hwnd%
        Loop, Parse, children, `n, `r
        {
            child := A_LoopField + 0
            WinGetClass, className, ahk_id %child%
            if (className = "Button") {
                style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "UInt")
                kind := style & 0xF
                ; Checkbox/radio/groupbox semantics remain native. Pushbuttons
                ; retain their HWND, action, tab order and keyboard handling.
                if (kind = 0 || kind = 1) {
                    DllCall("SetProp", "Ptr", child, "Str", "AHK.UI.Default", "Ptr", kind + 1)
                    DllCall("SetWindowLong", "Ptr", child, "Int", -16, "UInt", (style & ~0xF) | 0xB)
                    DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
                }
            } else if (className = "msctls_progress32") {
                ; Thin decorative rules are part of the shared accent. Filled
                ; cards retain their computed theme surfaces.
                WinGetPos,,, ruleW, ruleH, ahk_id %child%
                if (ruleW <= 4 || ruleH <= 4) {
                    DllCall("SendMessage", "Ptr", child, "UInt", 0x409, "Ptr", 0, "Ptr", HexToBGR(accent))
                    DllCall("SendMessage", "Ptr", child, "UInt", 0x2001, "Ptr", 0, "Ptr", HexToBGR(base))
                }
            } else if (className = "SysListView32") {
                ApplyListViewColors(child, surface, inputFg)
                DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
            } else if (className = "Edit" || className = "ListBox" || className = "ComboBox") {
                DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
            }
        }
        ; The titlebar follows the same dark/light selection on Windows 10/11.
        dark := ColorBrightness(panel) < 140 ? 1 : 0
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Int*", dark, "UInt", 4)
        DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
    } finally {
        DetectHiddenWindows, %oldHidden%
    }
    return true
}

UIStyle_GetPalette(messageHwnd, controlHwnd := 0) {
    global UIStyleWindows
    root := DllCall("GetAncestor", "Ptr", messageHwnd, "UInt", 2, "Ptr")
    if (UIStyleWindows.HasKey(root))
        return UIStyleWindows[root]
    if (controlHwnd) {
        root := DllCall("GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr")
        if (UIStyleWindows.HasKey(root))
            return UIStyleWindows[root]
    }
    return 0
}

UIStyle_ControlColor(dc, child, message, hwnd) {
    local
    local fontInfo := ""
    savedError := ErrorLevel, nativeError := A_LastError
    try {
        p := UIStyle_GetPalette(hwnd, child)
        if !IsObject(p)
            return
        input := message = 0x133 || message = 0x134
        if (message = 0x138 && child) {
            WinGetClass, cls, ahk_id %child%
            input := cls = "Edit" || cls = "ListBox" || cls = "ComboBox"
        }
        color := input ? p.InputText : p.Text
        background := input ? p.Surface : p.Background
        ; Fonts/metrics keep their original hierarchy. Small helper labels use
        ; the shared muted color; larger titles use the shared accent.
        if (!input && child) {
            font := DllCall("SendMessage", "Ptr", child, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
            VarSetCapacity(fontInfo, 92, 0)
            if (font && DllCall("GetObjectW", "Ptr", font, "Int", 92, "Ptr", &fontInfo)) {
                pixels := Abs(NumGet(fontInfo, 0, "Int"))
                size := pixels * 72.0 / A_ScreenDPI
                color := size <= 8 ? p.Muted : (size >= 12 ? p.Accent : p.Text)
            }
        }
        DllCall("SetTextColor", "Ptr", dc, "UInt", HexToBGR(color))
        DllCall("SetBkColor", "Ptr", dc, "UInt", HexToBGR(background))
        DllCall("SetBkMode", "Ptr", dc, "Int", input ? 2 : 1)
        return UIStyle_Brush(background)
    } finally {
        DllCall("SetLastError", "UInt", nativeError)
        ErrorLevel := savedError
    }
}

UIStyle_DrawButton(wParam, lParam, message, hwnd) {
    local
    local label := "", textRect := ""
    savedError := ErrorLevel, nativeError := A_LastError
    try {
        if (!lParam || NumGet(lParam + 0, 0, "UInt") != 4)
            return
        itemOffset := A_PtrSize = 8 ? 24 : 20
        child := NumGet(lParam + 0, itemOffset, "Ptr")
        p := UIStyle_GetPalette(hwnd, child)
        if !IsObject(p)
            return
        dc := NumGet(lParam + 0, itemOffset + A_PtrSize, "Ptr")
        rect := lParam + itemOffset + A_PtrSize * 2
        state := NumGet(lParam + 0, 16, "UInt")
        selected := state & 1, disabled := state & 6, focused := state & 0x10
        defaultButton := DllCall("GetProp", "Ptr", child, "Str", "AHK.UI.Default", "Ptr") = 2
        fill := selected ? p.Edge : p.Surface
        outline := (focused || defaultButton) ? p.Accent : p.Edge
        textColor := disabled ? p.Muted : p.InputText
        savedDC := DllCall("SaveDC", "Ptr", dc)
        try {
            DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", UIStyle_Brush(fill))
            DllCall("FrameRect", "Ptr", dc, "Ptr", rect, "Ptr", UIStyle_Brush(outline))
            font := DllCall("SendMessage", "Ptr", child, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
            if (font)
                DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
            DllCall("SetBkMode", "Ptr", dc, "Int", 1)
            DllCall("SetTextColor", "Ptr", dc, "UInt", HexToBGR(textColor))
            length := DllCall("GetWindowTextLengthW", "Ptr", child, "Int")
            VarSetCapacity(label, (length + 1) * 2, 0)
            DllCall("GetWindowTextW", "Ptr", child, "Ptr", &label, "Int", length + 1)
            VarSetCapacity(textRect, 16, 0)
            DllCall("RtlMoveMemory", "Ptr", &textRect, "Ptr", rect, "UPtr", 16)
            NumPut(NumGet(textRect, 0, "Int") + 6 + (selected ? 1 : 0), textRect, 0, "Int")
            NumPut(NumGet(textRect, 8, "Int") - 6, textRect, 8, "Int")
            flags := 0x1 | 0x4 | 0x20 | 0x8000 ; centered, single-line, ellipsis
            if (state & 0x100)
                flags |= 0x100000 ; hide keyboard accelerators until Alt
            DllCall("DrawTextW", "Ptr", dc, "Ptr", &label, "Int", length, "Ptr", &textRect, "UInt", flags)
            if (focused && !(state & 0x200)) {
                NumPut(NumGet(textRect, 4, "Int") + 4, textRect, 4, "Int")
                NumPut(NumGet(textRect, 12, "Int") - 4, textRect, 12, "Int")
                DllCall("DrawFocusRect", "Ptr", dc, "Ptr", &textRect)
            }
        } finally {
            if (savedDC)
                DllCall("RestoreDC", "Ptr", dc, "Int", savedDC)
        }
        return true
    } finally {
        DllCall("SetLastError", "UInt", nativeError)
        ErrorLevel := savedError
    }
}

UIStyle_Prune() {
    global UIStyleWindows, UIStyleBrushes
    dead := []
    for hwnd, p in UIStyleWindows
        if !DllCall("IsWindow", "Ptr", hwnd)
            dead.Push(hwnd)
    for _, hwnd in dead
        UIStyleWindows.Delete(hwnd)
    ; Brushes referenced by any live window remain valid. Retired palettes are
    ; released only outside painting, avoiding a growing GDI cache on rebuilds.
    used := {}
    for _, p in UIStyleWindows
        for _, key in ["Background", "Surface", "Edge", "Accent"]
            used[p[key]] := true
    retired := []
    for hex, brush in UIStyleBrushes
        if !used.HasKey(hex)
            retired.Push(hex)
    for _, hex in retired {
        DllCall("DeleteObject", "Ptr", UIStyleBrushes[hex])
        UIStyleBrushes.Delete(hex)
    }
}

UIStyle_Shutdown() {
    global UIStyleWindows, UIStyleBrushes, UIStyleInstalled
    if (UIStyleInstalled) {
        for _, message in [0x133, 0x134, 0x135, 0x136, 0x138]
            OnMessage(message, "UIStyle_ControlColor", 0)
        OnMessage(0x2B, "UIStyle_DrawButton", 0)
    }
    for _, brush in UIStyleBrushes
        if (brush)
            DllCall("DeleteObject", "Ptr", brush)
    UIStyleBrushes := {}, UIStyleWindows := {}, UIStyleInstalled := 0
}
