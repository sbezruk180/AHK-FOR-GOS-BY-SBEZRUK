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
    global UIStyleWindows, CustomBindListColor, StopTimerBgColor, StopTimerTextColor
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd))
        return false
    UIStyle_Install()
    UIStyle_Prune()
    GetThemeColors(bg, panel, fg, accent, muted)
    ; Explicit per-window colors remain functional after applying shared chrome.
    if (guiName = "13" && CustomBindListColor != "")
        panel := CustomBindListColor
    if (guiName = "15" || guiName = "ActionTimers") {
        if (StopTimerBgColor != "")
            panel := StopTimerBgColor
        if (StopTimerTextColor != "")
            fg := StopTimerTextColor
    }
    fg := EnsureTextContrast(fg, [panel], 4.5)
    muted := EnsureTextContrast(muted, [panel], 4.5)
    GetControlSurfaceColors(surface, inputFg, card, edge, panel, fg, accent)
    ; Settings has a separate canvas/sidebar/card hierarchy. Floating windows
    ; use the panel surface. Role colors are computed once, outside painting.
    base := guiName = "2" ? bg : panel
    palette := {Name: guiName, BG: bg, Panel: panel, Text: fg, Accent: accent
        , Muted: muted, Surface: surface, InputText: inputFg, Edge: edge
        , Background: base, PrimaryText: EnsureTextContrast("FFFFFF", [accent], 4.5)
        , PrimaryDown: ShiftHexColor(accent, -14), PrimaryHot: ShiftHexColor(accent, 10)
        , SurfaceDown: ShiftHexColor(surface, -5), SurfaceHot: ShiftHexColor(surface, 7)
        , NavActive: UIStyle_BlendColors(accent, panel, 0.19)
        , Success: EnsureTextContrast("65D7B3", [panel, surface], 4.5)
        , Warning: EnsureTextContrast("F0C67D", [panel, surface], 4.5)
        , Danger: EnsureTextContrast("F4829B", [panel, surface], 4.5)}
    palette.PrimaryText := EnsureTextContrast("FFFFFF", [accent, palette.PrimaryDown, palette.PrimaryHot], 4.5)
    palette.NavText := EnsureTextContrast(fg, [palette.NavActive], 4.5)
    palette.BrushColors := [base, panel, surface, edge, accent, palette.PrimaryDown
        , palette.PrimaryHot, palette.SurfaceDown, palette.SurfaceHot, palette.NavActive]
    palette.Surfaces := []
    UIStyleWindows[hwnd] := palette
    Gui, %guiName%:Color, %base%, %surface%
    oldHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    try {
        WinGet, children, ControlListHwnd, ahk_id %hwnd%
        Loop, Parse, children, `n, `r
        {
            child := A_LoopField + 0
            WinGetClass, className, ahk_id %child%
            if (className = "msctls_progress32") {
                ; Preserve each card's real fill. Surface discovery is done once;
                ; its live bounds/visibility are checked when a label repaints.
                VarSetCapacity(bounds, 16, 0)
                if DllCall("GetWindowRect", "Ptr", child, "Ptr", &bounds) {
                    width := NumGet(bounds, 8, "Int") - NumGet(bounds, 0, "Int")
                    height := NumGet(bounds, 12, "Int") - NumGet(bounds, 4, "Int")
                    if (width > 8 && height > 8) {
                        bgr := DllCall("SendMessage", "Ptr", child, "UInt", 0x40F, "Ptr", 0, "Ptr", 0, "UInt")
                        if (bgr != 0xFFFFFFFF) {
                            fill := Format("{:02X}{:02X}{:02X}", bgr & 255, (bgr >> 8) & 255, (bgr >> 16) & 255)
                            palette.Surfaces.Push({Hwnd: child, Parent: DllCall("GetParent", "Ptr", child, "Ptr"), Color: fill})
                            palette.BrushColors.Push(fill)
                        }
                    }
                }
            } else if (className = "Button") {
                style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "UInt")
                kind := style & 0xF
                ; Checkbox/radio/groupbox semantics remain native. Pushbuttons
                ; retain their HWND, action, tab order and keyboard handling.
                if (kind = 0 || kind = 1) {
                    DllCall("SetProp", "Ptr", child, "Str", "AHK.UI.Default", "Ptr", kind + 1)
                    DllCall("SetWindowLong", "Ptr", child, "Int", -16, "UInt", (style & ~0xF) | 0xB)
                    DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
                }
            } else if (className = "SysListView32") {
                ApplyListViewColors(child, surface, inputFg)
                UIStyle_FlattenControl(child)
                DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
            } else if (className = "Edit" || className = "ListBox" || className = "msctls_hotkey32" || className = "ComboBox") {
                if (className != "ComboBox")
                    UIStyle_FlattenControl(child)
                DllCall("uxtheme\SetWindowTheme", "Ptr", child, "WStr", " ", "WStr", " ")
            }
        }
        ; The titlebar follows the same dark/light selection on Windows 10/11.
        dark := ColorBrightness(panel) < 140 ? 1 : 0
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Int*", dark, "UInt", 4)
        ; Windows 11 can tint the retained native resize frame. Older systems
        ; reject this optional attribute while keeping their normal frame.
        borderColor := HexToBGR(edge)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 34, "UInt*", borderColor, "UInt", 4)
        DllCall("SetProp", "Ptr", hwnd, "Str", "AHK.UI.Styled", "Ptr", 1)
        DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x85)
    } finally {
        DetectHiddenWindows, %oldHidden%
    }
    return true
}

UIStyle_FlattenControl(hwnd) {
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    extended := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
    ; Keep control dimensions, scrolling, selection and keyboard behavior.
    ; Removing the classic raised edge only changes non-client decoration.
    if (style & 0x800000)
        DllCall("SetWindowLong", "Ptr", hwnd, "Int", -16, "UInt", style & ~0x800000)
    if (extended & 0x200)
        DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "UInt", extended & ~0x200)
    if ((style & 0x800000) || (extended & 0x200))
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)
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

UIStyle_ControlBackground(palette, child) {
    if (!child || !IsObject(palette.Surfaces))
        return palette.Background
    parent := DllCall("GetParent", "Ptr", child, "Ptr")
    VarSetCapacity(bounds, 16, 0)
    if !DllCall("GetWindowRect", "Ptr", child, "Ptr", &bounds)
        return palette.Background
    left := NumGet(bounds, 0, "Int"), top := NumGet(bounds, 4, "Int")
    right := NumGet(bounds, 8, "Int"), bottom := NumGet(bounds, 12, "Int")
    bestArea := 0, color := palette.Background
    for _, surface in palette.Surfaces {
        if (surface.Parent != parent || surface.Hwnd = child)
            continue
        ; Test the child's own visible flag rather than IsWindowVisible: the
        ; containing top-level window can still be hidden during first paint.
        style := DllCall("GetWindowLong", "Ptr", surface.Hwnd, "Int", -16, "UInt")
        if !(style & 0x10000000)
            continue
        VarSetCapacity(card, 16, 0)
        if !DllCall("GetWindowRect", "Ptr", surface.Hwnd, "Ptr", &card)
            continue
        l := NumGet(card, 0, "Int"), t := NumGet(card, 4, "Int")
        r := NumGet(card, 8, "Int"), b := NumGet(card, 12, "Int")
        if (left < l || top < t || right > r || bottom > b)
            continue
        area := (r - l) * (b - t)
        if (!bestArea || area < bestArea)
            bestArea := area, color := surface.Color
    }
    return color
}

UIStyle_ControlColor(dc, child, message, hwnd) {
    local
    local fontInfo := ""
    savedError := ErrorLevel, nativeError := A_LastError
    try {
        p := UIStyle_GetPalette(hwnd, child)
        if !IsObject(p)
            return
        cls := ""
        if (child)
            WinGetClass, cls, ahk_id %child%
        input := message = 0x133 || message = 0x134
        if (message = 0x138)
            input := cls = "Edit" || cls = "ListBox" || cls = "ComboBox" || cls = "msctls_hotkey32"
        enabled := !child || DllCall("IsWindowEnabled", "Ptr", child)
        color := input ? (enabled ? p.InputText : p.Muted) : p.Text
        background := input ? p.Surface : UIStyle_ControlBackground(p, child)
        ; Explicit roles keep validation/status colors independent of type size.
        ; Small untagged labels are secondary copy; headings share the accent.
        if (!input && child) {
            role := DllCall("GetProp", "Ptr", child, "Str", "AHK.UI.TextRole", "Ptr")
            if (role) {
                key := ["Text", "Muted", "Accent", "Success", "Warning", "Danger"][role]
                color := p[key]
            } else {
                font := DllCall("SendMessage", "Ptr", child, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
                VarSetCapacity(fontInfo, 92, 0)
                if (font && DllCall("GetObjectW", "Ptr", font, "Int", 92, "Ptr", &fontInfo)) {
                    pixels := Abs(NumGet(fontInfo, 0, "Int"))
                    size := pixels * 72.0 / A_ScreenDPI
                    color := size <= 8 ? p.Muted : (size >= 12 ? p.Accent : p.Text)
                }
            }
            if (!enabled)
                color := p.Muted
        }
        DllCall("SetTextColor", "Ptr", dc, "UInt", HexToBGR(color))
        DllCall("SetBkColor", "Ptr", dc, "UInt", HexToBGR(background))
        DllCall("SetBkMode", "Ptr", dc, "Int", input ? 2 : 1)
        ; A solid brush matching the containing card clears old glyphs when
        ; dynamic captions shorten, without erasing the card's surface.
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
        targetDC := NumGet(lParam + 0, itemOffset + A_PtrSize, "Ptr")
        dc := targetDC
        rect := lParam + itemOffset + A_PtrSize * 2
        state := NumGet(lParam + 0, 16, "UInt")
        selected := state & 1, disabled := state & 6, focused := state & 0x10
        hot := state & 0x40
        defaultButton := DllCall("GetProp", "Ptr", child, "Str", "AHK.UI.Default", "Ptr") = 2
        role := DllCall("GetProp", "Ptr", child, "Str", "AHK.UI.ButtonRole", "Ptr")
        if (!role)
            role := defaultButton ? 1 : 2
        navigation := role = 4 || role = 5
        primary := role = 1
        if (navigation) {
            fill := role = 5 ? p.NavActive : p.Panel
            if (selected || hot)
                fill := p.NavActive
            outline := focused ? p.Accent : fill
            textColor := role = 5 ? p.NavText : p.Muted
            if (selected || hot)
                textColor := p.NavText
        } else if (primary && !disabled) {
            fill := selected ? p.PrimaryDown : (hot ? p.PrimaryHot : p.Accent)
            outline := fill
            textColor := p.PrimaryText
        } else {
            fill := selected ? p.SurfaceDown : (hot ? p.SurfaceHot : p.Surface)
            outline := focused ? p.Accent : p.Edge
            textColor := role = 3 ? p.Danger : p.InputText
        }
        if (disabled)
            fill := navigation ? p.Panel : p.Surface, outline := fill, textColor := p.Muted
        ; Paint the complete button off-screen; do not expose background erase
        ; and intermediate glyph/frame draws during focus and tab changes.
        width := NumGet(rect + 0, 8, "Int") - NumGet(rect + 0, 0, "Int")
        height := NumGet(rect + 0, 12, "Int") - NumGet(rect + 0, 4, "Int")
        memoryDC := DllCall("CreateCompatibleDC", "Ptr", targetDC, "Ptr")
        bitmap := memoryDC ? DllCall("CreateCompatibleBitmap", "Ptr", targetDC, "Int", width, "Int", height, "Ptr") : 0
        oldBitmap := 0
        if (memoryDC && bitmap) {
            oldBitmap := DllCall("SelectObject", "Ptr", memoryDC, "Ptr", bitmap, "Ptr")
            dc := memoryDC
        }
        savedDC := DllCall("SaveDC", "Ptr", dc)
        try {
            ; Stock DC_PEN + cached brushes avoid per-paint GDI allocations.
            DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", UIStyle_Brush(UIStyle_ControlBackground(p, child)))
            DllCall("SelectObject", "Ptr", dc, "Ptr", DllCall("GetStockObject", "Int", 19, "Ptr"), "Ptr")
            DllCall("SetDCPenColor", "Ptr", dc, "UInt", HexToBGR(outline))
            DllCall("SelectObject", "Ptr", dc, "Ptr", UIStyle_Brush(fill), "Ptr")
            left := NumGet(rect + 0, 0, "Int"), top := NumGet(rect + 0, 4, "Int")
            right := NumGet(rect + 0, 8, "Int"), bottom := NumGet(rect + 0, 12, "Int")
            radius := Min(Round(8 * A_ScreenDPI / 96), (bottom - top) // 2)
            DllCall("RoundRect", "Ptr", dc, "Int", left, "Int", top, "Int", right, "Int", bottom, "Int", radius * 2, "Int", radius * 2)
            if (role = 5 && !disabled) {
                ; A small active marker distinguishes selection without a meter.
                DllCall("SelectObject", "Ptr", dc, "Ptr", UIStyle_Brush(p.Accent), "Ptr")
                DllCall("SetDCPenColor", "Ptr", dc, "UInt", HexToBGR(p.Accent))
                markerW := Max(2, Round(3 * A_ScreenDPI / 96))
                inset := Max(6, Round(8 * A_ScreenDPI / 96))
                DllCall("RoundRect", "Ptr", dc, "Int", left + 1, "Int", top + inset, "Int", left + markerW + 1, "Int", bottom - inset, "Int", markerW, "Int", markerW)
            }
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
            padding := navigation ? Round(16 * A_ScreenDPI / 96) : Round(6 * A_ScreenDPI / 96)
            NumPut(left + padding + (selected ? 1 : 0), textRect, 0, "Int")
            NumPut(right - padding, textRect, 8, "Int")
            flags := 0x4 | 0x20 | 0x8000 ; vertical center, single line, ellipsis
            if (!navigation)
                flags |= 0x1 ; ordinary actions are centered
            if (state & 0x100)
                flags |= 0x100000 ; hide keyboard accelerators until Alt
            DllCall("DrawTextW", "Ptr", dc, "Ptr", &label, "Int", length, "Ptr", &textRect, "UInt", flags)
            if (focused && !(state & 0x200)) {
                NumPut(top + 5, textRect, 4, "Int")
                NumPut(bottom - 5, textRect, 12, "Int")
                DllCall("DrawFocusRect", "Ptr", dc, "Ptr", &textRect)
            }
        } finally {
            if (savedDC)
                DllCall("RestoreDC", "Ptr", dc, "Int", savedDC)
            if (dc != targetDC) {
                DllCall("BitBlt", "Ptr", targetDC, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", dc, "Int", 0, "Int", 0, "UInt", 0xCC0020)
                DllCall("SelectObject", "Ptr", dc, "Ptr", oldBitmap)
            }
            if (bitmap)
                DllCall("DeleteObject", "Ptr", bitmap)
            if (memoryDC)
                DllCall("DeleteDC", "Ptr", memoryDC)
        }
        return true
    } finally {
        DllCall("SetLastError", "UInt", nativeError)
        ErrorLevel := savedError
    }
}

UIStyle_SetButtonRole(hwnd, role := "secondary") {
    return UIStyle_SetRole(hwnd, "AHK.UI.ButtonRole", role
        , {primary: 1, secondary: 2, danger: 3, nav: 4, "nav-active": 5})
}

UIStyle_SetTextRole(hwnd, role := "text") {
    return UIStyle_SetRole(hwnd, "AHK.UI.TextRole", role
        , {text: 1, muted: 2, accent: 3, success: 4, warning: 5, danger: 6})
}

UIStyle_SetRole(hwnd, propertyName, role, roles) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd) || !roles.HasKey(role))
        return false
    if (DllCall("GetProp", "Ptr", hwnd, "Str", propertyName, "Ptr") = roles[role])
        return false
    if !DllCall("SetProp", "Ptr", hwnd, "Str", propertyName, "Ptr", roles[role])
        return false
    DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", false)
    return true
}

UIStyle_BlendColors(foreground, background, weight) {
    result := ""
    Loop, 3 {
        a := HexToDec(SubStr(foreground, A_Index * 2 - 1, 2))
        b := HexToDec(SubStr(background, A_Index * 2 - 1, 2))
        result .= Format("{:02X}", Round(a * weight + b * (1 - weight)))
    }
    return result
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
        for _, hex in p.BrushColors
            used[hex] := true
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

UIStyle_SetTextIfChanged(guiName, controlName, text) {
    GuiControlGet, previous, %guiName%:, %controlName%
    if (previous == text)
        return false
    GuiControl, %guiName%:, %controlName%, %text%
    return true
}
