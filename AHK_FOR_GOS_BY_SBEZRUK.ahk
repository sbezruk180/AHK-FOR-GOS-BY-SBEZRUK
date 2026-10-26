#NoEnv
#SingleInstance Off
#Persistent
#MaxThreadsPerHotkey 1
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2
ListLines, Off
SetBatchLines, -1
SetWinDelay, -1
SetControlDelay, -1
SetMouseDelay, -1
CoordMode, ToolTip, Screen
CoordMode, Mouse, Screen

if (A_PtrSize != 4 || A_IsUnicode)
{
    MsgBox, 16, Ошибка, Этот скрипт нужно запускать только через AutoHotkey 1.1 ANSI 32-bit.
    ExitApp, 2
}

#Include %A_ScriptDir%
#Include %A_ScriptDir%\app\host.ahk
AppHost_Init()
#Include %A_ScriptDir%\UDF.ahk
#Include %A_ScriptDir%\runtime_support.ahk
#Include %A_ScriptDir%\chat_typing.ahk
#Include %A_ScriptDir%\id_capture.ahk
#Include %A_ScriptDir%\service_ui.ahk
#Include %A_ScriptDir%\app\game_input.ahk
#Include %A_ScriptDir%\app\text_commands.ahk
#Include %A_ScriptDir%\app\private_text.ahk
#Include %A_ScriptDir%\app\command_palette.ahk
#Include %A_ScriptDir%\app\gps_calibration.ahk
#Include %A_ScriptDir%\app\action_trace.ahk
#Include %A_ScriptDir%\app\incident_card.ahk
#Include %A_ScriptDir%\app\training.ahk
#Include %A_ScriptDir%\app\reference_guides.ahk
#Include %A_ScriptDir%\ui_style.ahk
#Include %A_ScriptDir%\tests\chat_typing_regression.ahk
#Include %A_ScriptDir%\tests\chat_state_regression.ahk
#Include %A_ScriptDir%\tests\autoid_source_regression.ahk
#Include %A_ScriptDir%\tests\id_capture_regression.ahk
#Include %A_ScriptDir%\tests\service_ui_regression.ahk
#Include %A_ScriptDir%\tests\service_flows_regression.ahk
#Include %A_ScriptDir%\tests\memory_compat_regression.ahk
#Include %A_ScriptDir%\tests\native_dialog_regression.ahk
#Include %A_ScriptDir%\tests\desktop_host_regression.ahk
#Include %A_ScriptDir%\tests\desktop_smoke.ahk
#Include %A_ScriptDir%\tests\logic_audit_regression.ahk
#Include %A_ScriptDir%\tests\reference_guides_regression.ahk
#Include %A_ScriptDir%\tests\text_commands_regression.ahk
#Include %A_ScriptDir%\tests\custom_builder_regression.ahk
#Include %A_ScriptDir%\tests\command_palette_regression.ahk
#Include %A_ScriptDir%\tests\gps_calibration_regression.ahk
#Include %A_ScriptDir%\tests\action_trace_regression.ahk
#Include %A_ScriptDir%\tests\incident_card_regression.ahk
#Include %A_ScriptDir%\tests\training_regression.ahk
#Include %A_ScriptDir%\tests\block_builder_regression.ahk
#Include %A_ScriptDir%\tests\audit_regression.ahk
; Canonical helper is included once; no embedded duplicate.
#Include %A_ScriptDir%\helper.ahk
#Include %A_ScriptDir%\app\cli.ahk
#Include %A_ScriptDir%\app\state.ahk
#Include %A_ScriptDir%\app\bootstrap.ahk

#Include %A_ScriptDir%\app\core.ahk
#Include %A_ScriptDir%\app\diagnostics.ahk
#Include %A_ScriptDir%\app\profiles.ahk
#Include %A_ScriptDir%\app\ui_settings.ahk
#Include %A_ScriptDir%\app\ui_overlays.ahk
#Include %A_ScriptDir%\app\game.ahk
#Include %A_ScriptDir%\app\chatlog.ahk
#Include %A_ScriptDir%\app\actions.ahk
#Include %A_ScriptDir%\app\bindings.ahk
#Include %A_ScriptDir%\app\automation.ahk
#Include %A_ScriptDir%\app\ui_documents.ahk
#Include %A_ScriptDir%\app\chat.ahk
#Include %A_ScriptDir%\app\custom_functions.ahk
#Include %A_ScriptDir%\app\events.ahk
