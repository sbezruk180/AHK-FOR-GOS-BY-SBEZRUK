; Build-time only. Runs in official AutoHotkey Unicode 32/64, never in the app.
#NoEnv
#SingleInstance Off
SetBatchLines, -1
if (A_Args.Length() != 2)
    ExitApp, 2
output := A_Args[1], manifest := A_Args[2]
handle := DllCall("BeginUpdateResourceW", "WStr", output, "Int", 0, "Ptr")
if (!handle)
    ExitApp, 3
ok := true
FileRead, list, %manifest%
Loop, Parse, list, `n, `r
{
    if (A_LoopField = "")
        continue
    fields := StrSplit(A_LoopField, "`t")
    if (fields.Length() != 3) {
        ok := false
        break
    }
    file := FileOpen(fields[3], "r")
    if !IsObject(file) {
        ok := false
        break
    }
    size := file.Length
    VarSetCapacity(data, size, 0)
    read := file.RawRead(data, size)
    file.Close()
    if (read != size) {
        ok := false
        break
    }
    resourceType := fields[1] + 0
    if RegExMatch(fields[2], "^#[0-9]+$")
        success := DllCall("UpdateResourceW", "Ptr", handle, "Ptr", resourceType, "Ptr", SubStr(fields[2], 2) + 0, "UShort", 1033, "Ptr", &data, "UInt", size)
    else
        success := DllCall("UpdateResourceW", "Ptr", handle, "Ptr", resourceType, "WStr", fields[2], "UShort", 1033, "Ptr", &data, "UInt", size)
    if (!success) {
        ok := false
        break
    }
}
committed := DllCall("EndUpdateResourceW", "Ptr", handle, "Int", !ok)
ExitApp, % ok && committed ? 0 : 4
