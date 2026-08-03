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
A_TrayMenu.Add("Settings", ShowSettingsGui)
A_TrayMenu.Default := "Settings"
A_TrayMenu.ClickCount := 1
A_TrayMenu.Add("Restart", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())

if !FileExist(IniPath) {
    readme := "; ============================================================================== `n"
    readme .= "; WELCOME TO ABSURDIAN FOCUS FRAME! (USER MANUAL)`n"
    readme .= "; ============================================================================== `n"
    readme .= "; This program changes the appearance of the native dotted selection border`n"
    readme .= "; on the desktop to a modern highlight.`n"
    readme .= ";`n"
    readme .= "; SETTINGS:`n"
    readme .= "; BorderThickness - Thickness of the highlight in pixels (e.g., 2, 3, 5).`n"
    readme .= "; Transparency    - Visibility of the border (from 0.0 to 1.0). 1.0 is solid color,`n"
    readme .= ";                   and 0.5 is semi-transparent.`n"
    readme .= "; BorderColor     - Color in HEX format (leave empty for auto-theme).`n"
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
    readme .= "[Settings]`nBorderThickness=2`nTransparency=0.5`nBorderColor=`nAutostart=0`n"
    FileAppend(readme, IniPath, "UTF-8")
}

global BorderThickness := Integer(IniRead(IniPath, "Settings", "BorderThickness", 2))
global Transparency := Float(IniRead(IniPath, "Settings", "Transparency", 0.5))
myGetThemeColor() {
    local isLight := 0
    try isLight := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    return isLight ? "000000" : "ffffff"
}

myChooseColor(initHex, hwndOwner := 0) {
    if initHex == ""
        initHex := "000000"
    try {
        initBgr := (Integer("0x" initHex) & 0xFF0000) >> 16 | (Integer("0x" initHex) & 0x00FF00) | (Integer("0x" initHex) & 0x0000FF) << 16
    } catch {
        initBgr := 0
    }
    CC := Buffer(A_PtrSize == 8 ? 72 : 36, 0)
    NumPut("UInt", CC.Size, CC, 0)
    NumPut("Ptr", hwndOwner, CC, 8)
    NumPut("UInt", initBgr, CC, A_PtrSize == 8 ? 24 : 12)
    static CustColors := Buffer(64, 0)
    NumPut("Ptr", CustColors.Ptr, CC, A_PtrSize == 8 ? 32 : 16)
    NumPut("UInt", 0x103, CC, A_PtrSize == 8 ? 40 : 20) ; CC_RGBINIT=1 | CC_FULLOPEN=2 | CC_ANYCOLOR=0x100

    if DllCall("comdlg32\ChooseColorW", "Ptr", CC.Ptr) {
        bgr := NumGet(CC, A_PtrSize == 8 ? 24 : 12, "UInt")
        rgb := (bgr & 0xFF0000) >> 16 | (bgr & 0x00FF00) | (bgr & 0x0000FF) << 16
        return Format("{:06x}", rgb)
    }
    return ""
}

myPickColorFromScreen() {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    KeyWait("LButton", "U")
    ToolTip("Click anywhere to pick a color.`nPress ESC or Right-Click to cancel.")

    Hotkey("*LButton", (*) => "", "On")
    Hotkey("*RButton", (*) => "", "On")
    CrossCursor := DllCall("LoadCursor", "Ptr", 0, "Int", 32515, "Ptr")
    CrossCursorCopy := DllCall("CopyImage", "Ptr", CrossCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
    DllCall("SetSystemCursor", "Ptr", CrossCursorCopy, "Int", 32512)

    lastC := ""
    chosenC := ""
    while true {
        MouseGetPos(&mX, &mY)
        c := PixelGetColor(mX, mY)
        hexC := StrReplace(c, "0x", "")
        if (hexC != lastC) {
            lastC := hexC
            try FocusGui.BackColor := hexC
        }
        if GetKeyState("LButton", "P") {
            ToolTip()
            KeyWait("LButton", "U")
            chosenC := hexC
            break
        }
        if GetKeyState("Escape", "P") || GetKeyState("RButton", "P") {
            ToolTip()
            if GetKeyState("RButton", "P")
                KeyWait("RButton", "U")
            break
        }
        Sleep(10)
    }

    Hotkey("*LButton", "Off")
    Hotkey("*RButton", "Off")
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)

    return chosenC
}

global BorderColor := IniRead(IniPath, "Settings", "BorderColor", "")
if (BorderColor == "") {
    BorderColor := myGetThemeColor()
}

global IsConfigMode := false

myThemeChangeHook(wParam, lParam, msg, hwnd) {
    local targetParam := ""
    try targetParam := StrGet(lParam)
    if (targetParam = "ImmersiveColorSet") {
        if (IniRead(IniPath, "Settings", "BorderColor", "") == "") {
            global BorderColor := myGetThemeColor()
            try FocusGui.BackColor := BorderColor
        }
    }
}
OnMessage(0x001A, myThemeChangeHook)
global Autostart := Integer(IniRead(IniPath, "Settings", "Autostart", 0))

if A_IsCompiled {
    ShortcutPath := A_Startup "\AbsurdianFocusFrame.lnk"
    if Autostart && !FileExist(ShortcutPath) {
        try FileCreateShortcut(A_ScriptFullPath, ShortcutPath, A_ScriptDir)
    } else if !Autostart && FileExist(ShortcutPath) {
        try FileDelete(ShortcutPath)
    }
}

global CacheReq := UIA.CreateCacheRequest(["ControlType", "BoundingRectangle", "IsOffscreen"])
global FocusGui := Gui("-Caption +ToolWindow +E0x20") ; +E0x20 = Ignores mouse clicks
FocusGui.BackColor := BorderColor
WinSetTransparent(Round(255 * Transparency), FocusGui.Hwnd)

global LastHwnd := 0
; Global system listener hiding native GDI focus borders.
global FocusHook := DllCall("SetWinEventHook", "UInt", 0x8005, "UInt", 0x8005, "Ptr", 0, "Ptr", CallbackCreate(HideNativeBorderEvent, "F", 7), "UInt", 0, "UInt", 0, "UInt", 0)

; Triggered by the system on focus change (kills border visibility).
HideNativeBorderEvent(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if (IsConfigMode)
        return
    if hwnd
        try PostMessage(0x0128, 0x00010001, 0, , "ahk_id " hwnd)

    global LastHwnd := hwnd
    SetTimer(RenderWatchdog, 15) ; Activate Watchdog
}

IsSupportedWindow() => WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman")

global gLastW := 0, gLastH := 0, gLastVX := 0, gLastVY := 0, gLastVW := 0, gLastVH := 0
myApplyBorderRegion(g, w, h, vX, vY, vW, vH) {
    if (w <= 0 || h <= 0 || vW <= 0 || vH <= 0)
        return
    hRgnOuter := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
    hRgnInner := DllCall("CreateRectRgn", "Int", g, "Int", g, "Int", w - g, "Int", h - g, "Ptr")
    DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnInner, "Int", 4)
    hRgnClip := DllCall("CreateRectRgn", "Int", vX, "Int", vY, "Int", vX + vW, "Int", vY + vH, "Ptr")
    DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnClip, "Int", 1)
    DllCall("SetWindowRgn", "Ptr", FocusGui.Hwnd, "Ptr", hRgnOuter, "Int", 1)
    DllCall("DeleteObject", "Ptr", hRgnInner)
    DllCall("DeleteObject", "Ptr", hRgnClip)
}

; Polling watchdog clipping the border to the view (Clipping)
RenderWatchdog() {
    if (IsConfigMode)
        return
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

        if (el.CachedIsOffscreen || w <= 0 || h <= 0 || ix1 >= ix2 || iy1 >= iy2) {
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

            global gLastW := w, gLastH := h, gLastVX := vX, gLastVY := vY, gLastVW := vW, gLastVH := vH
            myApplyBorderRegion(BorderThickness, w, h, vX, vY, vW, vH)

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

ShowSettingsGui(*) {
    try {
        if hwnd := WinExist("ahk_class WorkerW") || WinExist("ahk_class Progman")
            WinActivate("ahk_id " hwnd)
        Sleep(100)
    }
    global IsConfigMode := true

    myGui := Gui("-MinimizeBox -MaximizeBox", "Absurdian Focus Frame - Settings")

    CleanupAndDestroy(*) {
        global IsConfigMode := false
        OnMessage(0x020A, HandleMouseWheel, 0)
        FocusGui.BackColor := (BorderColor == "" ? myGetThemeColor() : BorderColor)
        WinSetTransparent(Round(255 * Transparency), FocusGui.Hwnd)
        myApplyBorderRegion(BorderThickness, gLastW, gLastH, gLastVX, gLastVY, gLastVW, gLastVH)
        myGui.Destroy()
    }
    myGui.OnEvent("Close", CleanupAndDestroy)

    myGui.Add("Text", "x15 y15 w200", "Border Thickness (px):")
    myGui.Add("Edit", "x15 y30 w100 vBorderThickness", BorderThickness)
    myThickUD := myGui.Add("UpDown", "Range1-20", BorderThickness)
    myThickUD.OnEvent("Change", (ctrl, *) => myApplyBorderRegion(ctrl.Value, gLastW, gLastH, gLastVX, gLastVY, gLastVW, gLastVH))

    myGui.Add("Text", "x15 y65 w200", "Transparency (0.0 - 1.0):")
    myTransEdit := myGui.Add("Edit", "x15 y80 w80 vTransparency", Format("{:.2f}", Transparency))
    myTransUD := myGui.Add("UpDown", "x95 y80 w20 h22 -16 Range0-20", Round(Transparency / 0.05))
    myTransUD.OnEvent("Change", (ctrl, *) => (
        myTransEdit.Value := Format("{:.2f}", ctrl.Value * 0.05),
        WinSetTransparent(Round(255 * (ctrl.Value * 0.05)), FocusGui.Hwnd)
    ))

    HandleMouseWheel(wParam, lParam, msg, hwnd) {
        if (hwnd == myTransEdit.Hwnd || hwnd == myTransUD.Hwnd) {
            dir := (wParam << 32 >> 48) > 0 ? 1 : -1
            myTransUD.Value += dir
            myTransEdit.Value := Format("{:.2f}", myTransUD.Value * 0.05)
            WinSetTransparent(Round(255 * (myTransUD.Value * 0.05)), FocusGui.Hwnd)
            return 1
        }
    }
    OnMessage(0x020A, HandleMouseWheel)

    myGui.Add("Text", "x15 y115 w200", "Border Color (HEX, empty for auto):")
    myColorEdit := myGui.Add("Edit", "x15 y130 w60 vBorderColor", IniRead(IniPath, "Settings", "BorderColor", ""))
    myColorEdit.OnEvent("Change", (ctrl, *) => (FocusGui.BackColor := (ctrl.Value != "" ? ctrl.Value : myGetThemeColor())))
    myBtnPicker := myGui.Add("Button", "x80 y129 w24 h24", "🎨")
    myBtnPicker.OnEvent("Click", (*) => (
        (res := myChooseColor(myColorEdit.Value != "" ? myColorEdit.Value : myGetThemeColor(), myGui.Hwnd)) != ""
            ? (myColorEdit.Value := res, FocusGui.BackColor := res)
        : ""
    ))
    myBtnDropper := myGui.Add("Button", "x106 y129 w24 h24", "💉")
    myBtnDropper.OnEvent("Click", (*) => (
        (res := myPickColorFromScreen()) != ""
            ? (myColorEdit.Value := res, FocusGui.BackColor := res)
        : (FocusGui.BackColor := (myColorEdit.Value != "" ? myColorEdit.Value : myGetThemeColor()))
    ))

    myGui.Add("Checkbox", "x15 y170 w200 vAutostart Checked" Autostart, "Run at system startup")

    myBtnSave := myGui.Add("Button", "x15 y210 w80 Default", "Save")
    myBtnSave.OnEvent("Click", mySaveSettings)

    myBtnCancel := myGui.Add("Button", "x105 y210 w80", "Cancel")
    myBtnCancel.OnEvent("Click", CleanupAndDestroy)

    myGui.Show("w240 h250")

    mySaveSettings(*) {
        mySaved := myGui.Submit()
        IniWrite(mySaved.BorderThickness, IniPath, "Settings", "BorderThickness")
        IniWrite(mySaved.Transparency, IniPath, "Settings", "Transparency")
        IniWrite(mySaved.BorderColor, IniPath, "Settings", "BorderColor")
        IniWrite(mySaved.Autostart, IniPath, "Settings", "Autostart")

        Reload()
    }
}