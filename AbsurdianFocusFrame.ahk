#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetMainIcon AbsurdianFocusFrame.ico
;@Ahk2Exe-SetCompanyName AbsurdianVibe
;@Ahk2Exe-SetDescription Configurable keyboard focus border for Desktop and Windows Explorer
;@Ahk2Exe-SetCopyright Copyright (c) 2026 AbsurdianVibe
;@Ahk2Exe-SetVersion 1.1.0
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
    FileAppend("[Settings]`nBorderThickness=2`nTransparency=0.5`nBorderColor=`nAutostart=0`n", IniPath, "UTF-8")
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
    if (IsConfigMode && !IsSupportedWindow())
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
    if WinExist("Absurdian Focus Frame") { ;
        WinActivate("Absurdian Focus Frame")
        return
    }
    try {
        if hwnd := WinExist("ahk_class WorkerW") || WinExist("ahk_class Progman")
            WinActivate("ahk_id " hwnd)
        Sleep(100)
    }
    global IsConfigMode := true

    myGui := Gui("-MinimizeBox -MaximizeBox", "Absurdian Focus Frame")
    myGui.MarginX := 15
    myGui.MarginY := 15

    origThick := BorderThickness
    origTrans := Format("{:.2f}", Transparency)
    origColor := IniRead(IniPath, "Settings", "BorderColor", "")
    origAutostart := Autostart

    CleanupAndDestroy(*) {
        global IsConfigMode := false
        OnMessage(0x020A, HandleMouseWheel, 0)
        try OnMessage(0x0200, HandleMouseMove, 0)
        ToolTip()
        FocusGui.BackColor := (BorderColor == "" ? myGetThemeColor() : BorderColor)
        WinSetTransparent(Round(255 * Transparency), FocusGui.Hwnd)
        myApplyBorderRegion(BorderThickness, gLastW, gLastH, gLastVX, gLastVY, gLastVW, gLastVH)
        myGui.Destroy()
    }
    myGui.OnEvent("Close", CleanupAndDestroy)

    myBtnInfo := myGui.Add("Button", "xm y5", "ℹ️")
    myBtnInfo.OnEvent("Click", (*) => MsgBox("WELCOME TO ABSURDIAN FOCUS FRAME!`n`nThis program changes the appearance of the native dotted selection border on the desktop to a modern highlight.`n`nThis project wouldn't be possible without the AutoHotkey community.`nSpecial thanks to: Descolada - for the amazing UIA.ahk library, which enables precise communication with the Windows interface.`nmy GitHub: https://github.com/AbsurdianVibe`n`nHappy clicking!`n`n~ AbsurdianVibe", "Absurdian Focus Frame - Info"))

    myGui.Add("Text", "xm y+5", "Border Thickness (px):")
    myThickEdit := myGui.Add("Edit", "xm y+5 w80 vBorderThickness", BorderThickness)
    myThickUD := myGui.Add("UpDown", "Range1-4", BorderThickness)
    myThickUD.OnEvent("Change", (ctrl, *) => (
        myApplyBorderRegion(ctrl.Value, gLastW, gLastH, gLastVX, gLastVY, gLastVW, gLastVH),
        CheckUndoStates()
    ))
    myBtnUndoThick := myGui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
    myBtnUndoThick.OnEvent("Click", (*) => (
        myThickEdit.Value := origThick,
        myApplyBorderRegion(origThick, gLastW, gLastH, gLastVX, gLastVY, gLastVW, gLastVH),
        CheckUndoStates()
    ))

    myGui.Add("Text", "xm y+5", "Transparency (0.0 - 1.0):")
    myTransEdit := myGui.Add("Edit", "xm y+5 w60 vTransparency", Format("{:.2f}", Transparency))
    myTransUD := myGui.Add("UpDown", "-2 Range0-20", Round(Transparency / 0.05))
    myTransUD.OnEvent("Change", (ctrl, *) => (
        myTransEdit.Value := Format("{:.2f}", ctrl.Value * 0.05),
        WinSetTransparent(Round(255 * (ctrl.Value * 0.05)), FocusGui.Hwnd),
        CheckUndoStates()
    ))
    myBtnUndoTrans := myGui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
    myBtnUndoTrans.OnEvent("Click", (*) => (
        myTransUD.Value := Round(origTrans / 0.05),
        myTransEdit.Value := origTrans,
        WinSetTransparent(Round(255 * Float(origTrans)), FocusGui.Hwnd),
        CheckUndoStates()
    ))

    HandleMouseWheel(wParam, lParam, msg, hwnd) {
        if (hwnd == myTransEdit.Hwnd || hwnd == myTransUD.Hwnd) {
            dir := (wParam << 32 >> 48) > 0 ? 1 : -1
            myTransUD.Value += dir
            myTransEdit.Value := Format("{:.2f}", myTransUD.Value * 0.05)
            WinSetTransparent(Round(255 * (myTransUD.Value * 0.05)), FocusGui.Hwnd)
            CheckUndoStates()
            return 1
        }
    }
    OnMessage(0x020A, HandleMouseWheel)

    myGui.Add("Text", "xm y+5", "Border Color (HEX, empty for auto):")
    myColorEdit := myGui.Add("Edit", "xm y+5 w60 vBorderColor", origColor)
    myColorEdit.LastGood := origColor

    HandleMouseMove(wParam, lParam, msg, hwnd) {
        static lastHwnd := 0
        if (hwnd == lastHwnd)
            return
        lastHwnd := hwnd
        if (hwnd == myColorEdit.Hwnd)
            ToolTip("Leave empty for auto-theme.")
        else
            ToolTip()
    }
    OnMessage(0x0200, HandleMouseMove)
    myColorChange(ctrl, *) {
        try {
            FocusGui.BackColor := (ctrl.Value != "" ? ctrl.Value : myGetThemeColor())
            ctrl.LastGood := ctrl.Value
            CheckUndoStates()
        } catch {
            MsgBox("Nieprawidlowy format koloru.", "Blad", 16)
            ctrl.Value := ctrl.HasOwnProp("LastGood") ? ctrl.LastGood : origColor
            CheckUndoStates()
        }
    }
    myColorEdit.OnEvent("Change", myColorChange)
    myBtnPicker := myGui.Add("Button", "x+2 yp w22 h22", "🎨")
    myBtnPicker.OnEvent("Click", (*) => (
        (res := myChooseColor(myColorEdit.Value != "" ? myColorEdit.Value : myGetThemeColor(), myGui.Hwnd)) != ""
            ? (myColorEdit.Value := res, FocusGui.BackColor := res, CheckUndoStates())
        : ""
    ))
    myBtnDropper := myGui.Add("Button", "x+2 yp w22 h22", "💉")
    myBtnDropper.OnEvent("Click", (*) => (
        (res := myPickColorFromScreen()) != ""
            ? (myColorEdit.Value := res, FocusGui.BackColor := res, CheckUndoStates())
        : (FocusGui.BackColor := (myColorEdit.Value != "" ? myColorEdit.Value : myGetThemeColor()), CheckUndoStates())
    ))
    myBtnUndoColor := myGui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
    myBtnUndoColor.OnEvent("Click", (*) => (
        myColorEdit.Value := origColor,
        FocusGui.BackColor := (origColor != "" ? origColor : myGetThemeColor()),
        CheckUndoStates()
    ))

    myCbAutostart := myGui.Add("Checkbox", "xm y+5 h22 vAutostart Checked" Autostart, "Run at system startup")
    myCbAutostart.OnEvent("Click", (*) => CheckUndoStates())
    myBtnUndoAutostart := myGui.Add("Button", "x+0 yp w22 h22 Disabled", "↩")
    myBtnUndoAutostart.OnEvent("Click", (*) => (
        myCbAutostart.Value := origAutostart,
        CheckUndoStates()
    ))

    myBtnSave := myGui.Add("Button", "xm y+5 w80 Default", "Save")
    myBtnSave.OnEvent("Click", mySaveSettings)

    myBtnCancel := myGui.Add("Button", "x+5 yp w80", "Cancel")
    myBtnCancel.OnEvent("Click", CleanupAndDestroy)

    CheckUndoStates(*) {
        myBtnUndoThick.Enabled := (myThickUD.Value != origThick)
        myBtnUndoTrans.Enabled := (myTransEdit.Value != origTrans)
        myBtnUndoColor.Enabled := (myColorEdit.Value != origColor)
        myBtnUndoAutostart.Enabled := (myCbAutostart.Value != origAutostart)
    }

    myGui.Show()

    mySaveSettings(*) {
        mySaved := myGui.Submit()
        IniWrite(mySaved.BorderThickness, IniPath, "Settings", "BorderThickness")
        IniWrite(mySaved.Transparency, IniPath, "Settings", "Transparency")
        IniWrite(mySaved.BorderColor, IniPath, "Settings", "BorderColor")
        IniWrite(mySaved.Autostart, IniPath, "Settings", "Autostart")

        Reload()
    }
}