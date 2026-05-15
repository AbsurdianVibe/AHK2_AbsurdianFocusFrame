#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetMainIcon AbsurdianFocusFrame.ico
;@Ahk2Exe-SetCompanyName AbsurdianVibe
;@Ahk2Exe-SetDescription Configurable keyboard focus border for Desktop and Windows Explorer
;@Ahk2Exe-SetCopyright Copyright (c) 2026 AbsurdianVibe
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetProductName Absurdian Focus Frame
;@Ahk2Exe-SetLanguage 0x0409 ; English (US)
#Include "external_code\UIA.ahk"
Persistent()

global IniPath := A_ScriptDir "\AbsurdianFocusFrame.ini"

A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", (*) => Run(IniPath))
A_TrayMenu.Default := "Settings"
A_TrayMenu.ClickCount := 1
A_TrayMenu.Add("Restart", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())

if !FileExist(IniPath) {
    readme := "; ============================================================================== `n"
    readme .= "; WELCOME TO ABSURDIAN FOCUS FRAME! (USER MANUAL)`n"
    readme .= "; ============================================================================== `n"
    readme .= "; This program changes the appearance of the native dotted selection border`n"
    readme .= "; on the desktop and in Windows Explorer to a modern highlight.`n"
    readme .= ";`n"
    readme .= "; SETTINGS:`n"
    readme .= "; BorderThickness - Thickness of the highlight in pixels (e.g., 2, 3, 5).`n"
    readme .= "; Transparency    - Visibility of the border (from 0.0 to 1.0). 0.0 is solid color,`n"
    readme .= ";                   and 0.5 is semi-transparent.`n"
    readme .= "; BorderColor     - Color in HEX format (e.g., fdb500 is orange).`n"
    readme .= "; Explorer        - Should the program also work in folder windows (1=Yes, 0=No).`n"
    readme .= "; Autostart       - Run the program at system startup (1=Yes, 0=No).`n"
    readme .= ";`n"
    readme .= "; Save this file and restart the program (Restart in menu) to apply changes!`n"
    readme .= ";`n"
    readme .= "; This project wouldn't be possible without the AutoHotkey community.`n"
    readme .= "; Special thanks to: Descolada - for the amazing UIA.ahk library,`n"
    readme .= "; which enables precise communication with the Windows interface.`n"
    readme .= "; my GitHub: https://github.com/AbsurdianVibe`n"
    readme .= "; Happy clicking! ~ AbsurdianVibe`n"
    readme .= "; ============================================================================== `n`n"
    readme .= "[Settings]`nBorderThickness=2`nTransparency=0.5`nBorderColor=fdb500`nExplorer=1`nAutostart=0`n"
    FileAppend(readme, IniPath, "UTF-8")
}

global BorderThickness := Integer(IniRead(IniPath, "Settings", "BorderThickness", 2))
global Transparency := Float(IniRead(IniPath, "Settings", "Transparency", 0.5))
global BorderColor := IniRead(IniPath, "Settings", "BorderColor", "fdb500")
global Explorer := Integer(IniRead(IniPath, "Settings", "Explorer", 1))
global Autostart := Integer(IniRead(IniPath, "Settings", "Autostart", 0))

if A_IsCompiled {
    ShortcutPath := A_Startup "\AbsurdianFocusFrame.lnk"
    if Autostart && !FileExist(ShortcutPath) {
        try FileCreateShortcut(A_ScriptFullPath, ShortcutPath, A_ScriptDir)
    } else if !Autostart && FileExist(ShortcutPath) {
        try FileDelete(ShortcutPath)
    }
}

global CacheReq := UIA.CreateCacheRequest(["ControlType", "BoundingRectangle"])
global FocusGui := Gui("-Caption +ToolWindow +E0x20") ; +E0x20 = Ignores mouse clicks
FocusGui.BackColor := BorderColor
WinSetTransparent(Round(255 * (1.0 - Transparency)), FocusGui.Hwnd)

global LastHwnd := 0
; Global system listener hiding native GDI focus borders.
global FocusHook := DllCall("SetWinEventHook", "UInt", 0x8005, "UInt", 0x8005, "Ptr", 0, "Ptr", CallbackCreate(HideNativeBorderEvent, "F", 7), "UInt", 0, "UInt", 0, "UInt", 0)

; Triggered by the system on focus change (kills border visibility).
HideNativeBorderEvent(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if hwnd
        try PostMessage(0x0128, 0x00010001, 0,, "ahk_id " hwnd)
        
    global LastHwnd := hwnd
    SetTimer(RenderWatchdog, 15) ; Activate Watchdog
}

IsSupportedWindow() => WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman") || (Explorer && WinActive("ahk_class CabinetWClass"))

; Polling watchdog clipping the border to the view (Clipping)
RenderWatchdog() {
    static lastState := ""
    static lastHwndAbove := -1
    try {
        if (!IsSupportedWindow() || !WinExist("ahk_id " LastHwnd))
            throw Error()

        el := UIA.GetFocusedElement(CacheReq)
        if (el.CachedControlType != 50007) ; Only icons
            throw Error()
            
        rect := el.CachedBoundingRectangle
        w := rect.r - rect.l, h := rect.b - rect.t

        WinGetPos(&oX, &oY, &oW, &oH, "ahk_id " LastHwnd)
        
        ix1 := Max(rect.l, oX), iy1 := Max(rect.t, oY)
        ix2 := Min(rect.r, oX + oW), iy2 := Min(rect.b, oY + oH)
        
        if (w <= 0 || h <= 0 || ix1 >= ix2 || iy1 >= iy2) {
            FocusGui.Hide()
            lastState := ""
            lastHwndAbove := -1
            return ; Invisible (off-screen), but we don't kill the timer - waiting for return
        }
            
        vX := ix1 - rect.l, vY := iy1 - rect.t
        vW := ix2 - ix1, vH := iy2 - iy1
        
        state := rect.l "|" rect.t "|" w "|" h "|" vX "|" vY "|" vW "|" vH
        stateChange := (state != lastState)
        
        if (stateChange) {
            lastState := state

            g := BorderThickness
            hRgnOuter := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
            hRgnInner := DllCall("CreateRectRgn", "Int", g, "Int", g, "Int", w-g, "Int", h-g, "Ptr")
            DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnInner, "Int", 4) ; RGN_DIFF
            
            hRgnClip := DllCall("CreateRectRgn", "Int", vX, "Int", vY, "Int", vX+vW, "Int", vY+vH, "Ptr")
            DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnClip, "Int", 1) ; RGN_AND
            
            DllCall("SetWindowRgn", "Ptr", FocusGui.Hwnd, "Ptr", hRgnOuter, "Int", 1)
            DllCall("DeleteObject", "Ptr", hRgnInner)
            DllCall("DeleteObject", "Ptr", hRgnClip)
            
            FocusGui.Show("NA x" rect.l " y" rect.t " w" w " h" h)
        }

        topHwnd := DllCall("GetAncestor", "Ptr", LastHwnd, "UInt", 2, "Ptr") ; Get main window (GA_ROOT)
        hwndAbove := DllCall("GetWindow", "Ptr", topHwnd, "UInt", 3, "Ptr") ; GW_HWNDPREV
        if (hwndAbove != lastHwndAbove || stateChange) {
            lastHwndAbove := hwndAbove
            DllCall("SetWindowPos", "Ptr", FocusGui.Hwnd, "Ptr", hwndAbove ? hwndAbove : 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
        }
    } catch {
        FocusGui.Hide()
        lastState := ""
        lastHwndAbove := -1
        SetTimer(RenderWatchdog, 0)
    }
}