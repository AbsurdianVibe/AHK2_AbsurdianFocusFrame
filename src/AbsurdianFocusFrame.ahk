#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetMainIcon AbsurdianFocusFrame.ico
;@Ahk2Exe-SetCompanyName AbsurdianVibe
;@Ahk2Exe-SetDescription Configurable keyboard focus border for Desktop and Windows Explorer
;@Ahk2Exe-SetCopyright Copyright (c) 2026 AbsurdianVibe
;@Ahk2Exe-SetVersion 1.1.5
;@Ahk2Exe-SetProductName Absurdian Focus Frame
;@Ahk2Exe-SetLanguage 0x0409 ; English (US)

#Include "..\external_code\UIA.ahk"
#Include "config\ConfigManager.ahk"
#Include "core\RenderEngine.ahk"
#Include "core\HookManager.ahk"
#Include "core\GradientRenderer.ahk"
#Include "ui\SettingsGui.ahk"
#Include "utils\ColorUtils.ahk"

Persistent()

global MainConfig := myConfigManager(A_ScriptDir "\AbsurdianFocusFrame.ini")
MainConfig.mySetupAutostart()

global MainRenderer := myRenderEngine(MainConfig)
global MainHooks := myHookManager(MainRenderer, MainConfig)
global MainGuiInstance := mySettingsGui(MainConfig, MainRenderer)

A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", (*) => MainGuiInstance.myShow())
A_TrayMenu.Default := "Settings"
A_TrayMenu.ClickCount := 1
A_TrayMenu.Add("Restart", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())