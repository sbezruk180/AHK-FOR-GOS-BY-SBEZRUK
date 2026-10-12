; Hidden native-window integration tests; no game or display-capture success is assumed.
RunNativeDialogRegressionTests() {
    global CaptureDialogHook, CaptureDialogCallbackAddress, CaptureDialogHookThread
    global CaptureDialogHookBusy, CaptureDialogHookError, CaptureWindowStates, CaptureStatus
    originalHook := CaptureDialogHook, originalCallback := CaptureDialogCallbackAddress
    originalStatus := CaptureStatus, originalHookError := CaptureDialogHookError
    originalError := ErrorLevel, originalCritical := A_IsCritical
    native := 0, childNative := 0, genericWindow := 0, parentHwnd := 0
    try {
        ErrorLevel := "native-hook-test"
        installed := Capture_InstallDialogHook()
        AuditAssert("Native dialogs: local hook installs without changing ErrorLevel", installed && ErrorLevel = "native-hook-test")
        AuditAssert("Native dialogs: hook is limited to this GUI thread", CaptureDialogHookThread = DllCall("GetCurrentThreadId", "UInt"))
        installedHook := CaptureDialogHook, installedCallback := CaptureDialogCallbackAddress
        AuditAssert("Native dialogs: repeated install reuses hook allocation", Capture_InstallDialogHook() && CaptureDialogHook = installedHook && CaptureDialogCallbackAddress = installedCallback)
        Gui, CaptureAuditNativeParent:New, +HwndparentHwnd
        Gui, CaptureAuditNativeParent:Add, Text, HwndchildControl, Hidden capture regression parent
        AuditAssert("Native dialogs: existing AHK top-level GUI remains eligible", parentHwnd && Capture_IsOwnGui(parentHwnd))
        AuditAssert("Native dialogs: child controls remain ineligible", childControl && !Capture_IsOwnGui(childControl))
        instance := DllCall("GetModuleHandleA", "Ptr", 0, "Ptr")
        native := DllCall("CreateWindowExA", "UInt", 0, "AStr", "#32770", "AStr", "Hidden native capture regression", "UInt", 0
            , "Int", 0, "Int", 0, "Int", 100, "Int", 50, "Ptr", 0, "Ptr", 0, "Ptr", instance, "Ptr", 0, "Ptr")
        AuditAssert("Native dialogs: own hidden native top-level is eligible", native && Capture_IsOwnGui(native) && !DllCall("IsWindowVisible", "Ptr", native, "Int"))
        AuditAssert("Native dialogs: CBT attempts affinity during hidden creation", native && CaptureWindowStates.HasKey(native))
        childNative := DllCall("CreateWindowExA", "UInt", 0, "AStr", "#32770", "AStr", "Child native capture regression", "UInt", 0x40000000
            , "Int", 0, "Int", 0, "Int", 50, "Int", 25, "Ptr", parentHwnd, "Ptr", 0, "Ptr", instance, "Ptr", 0, "Ptr")
        AuditAssert("Native dialogs: native child is excluded by root-window guard", childNative && !Capture_IsOwnGui(childNative))
        genericWindow := DllCall("CreateWindowExA", "UInt", 0, "AStr", "STATIC", "AStr", "Generic capture regression", "UInt", 0
            , "Int", 0, "Int", 0, "Int", 50, "Int", 25, "Ptr", 0, "Ptr", 0, "Ptr", instance, "Ptr", 0, "Ptr")
        AuditAssert("Native dialogs: unrelated own top-level classes remain excluded", genericWindow && !Capture_IsOwnGui(genericWindow))
        Critical, 17
        ErrorLevel := "native-callback-test"
        Capture_DialogHookProc(-1, native, 0)
        AuditAssert("Native dialogs: pass-through callback preserves ErrorLevel and Critical", ErrorLevel = "native-callback-test" && A_IsCritical = 17 && !CaptureDialogHookBusy)
        Critical, %originalCritical%
    } finally {
        for _, hwnd in [childNative, native, genericWindow] {
            if (hwnd)
                DllCall("DestroyWindow", "Ptr", hwnd)
            if (hwnd && CaptureWindowStates.HasKey(hwnd))
                CaptureWindowStates.Delete(hwnd)
        }
        Gui, CaptureAuditNativeParent:Destroy
        if (!originalHook) {
            removed := Capture_ShutdownDialogHook()
            AuditAssert("Native dialogs: temporary hook and callback allocation are released", removed && !CaptureDialogHook && !CaptureDialogCallbackAddress && !CaptureDialogHookThread)
        } else
            AuditAssert("Native dialogs: existing application hook is retained", CaptureDialogHook = originalHook && CaptureDialogCallbackAddress = originalCallback)
        CaptureStatus := originalStatus, CaptureDialogHookError := originalHookError
        Critical, %originalCritical%
        ErrorLevel := originalError
    }
}
