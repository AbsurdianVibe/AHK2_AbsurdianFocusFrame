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

global MainConfig := myConfigManager(A_ScriptDir "\AbsurdianFocusFrame.ini")
MainConfig.mySetupAutostart()

global MainRenderer := myRenderEngine(MainConfig)
global MainHooks := myHookManager(MainRenderer, MainConfig) ; any garbage collector for class myHookManager
global MainGuiInstance := mySettingsGui(MainConfig, MainRenderer)

A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", (*) => MainGuiInstance.myShow())
A_TrayMenu.Default := "Settings"
A_TrayMenu.ClickCount := 1
A_TrayMenu.Add("Restart", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())

class myConfigManager {
    __New(iniPath) {
        this.IniPath := iniPath
        if !FileExist(this.IniPath) {
            IniWrite(2, this.IniPath, "Settings", "BorderThickness")
            IniWrite(0.5, this.IniPath, "Settings", "Transparency")
            IniWrite("", this.IniPath, "Settings", "BorderColor")
            IniWrite(0, this.IniPath, "Settings", "Autostart")
        }
        this.BorderThickness := Integer(IniRead(this.IniPath, "Settings", "BorderThickness", 2))
        this.Transparency := Float(IniRead(this.IniPath, "Settings", "Transparency", 0.5))
        this.BorderColor := IniRead(this.IniPath, "Settings", "BorderColor", "")
        this.Autostart := Integer(IniRead(this.IniPath, "Settings", "Autostart", 0))

        if (this.BorderColor == "")
            this.BorderColor := myGetThemeColor()
    }

    mySaveData(thick, trans, color, auto) {
        IniWrite(thick, this.IniPath, "Settings", "BorderThickness")
        IniWrite(trans, this.IniPath, "Settings", "Transparency")
        IniWrite(color, this.IniPath, "Settings", "BorderColor")
        IniWrite(auto, this.IniPath, "Settings", "Autostart")
        this.BorderThickness := thick
        this.Transparency := trans
        this.BorderColor := color
        this.Autostart := auto
    }

    mySetupAutostart() {
        if A_IsCompiled {
            ShortcutPath := A_Startup "\AbsurdianFocusFrame.lnk"
            if this.Autostart && !FileExist(ShortcutPath) {
                try FileCreateShortcut(A_ScriptFullPath, ShortcutPath, A_ScriptDir)
            } else if !this.Autostart && FileExist(ShortcutPath) {
                try FileDelete(ShortcutPath)
            }
        }
    }
}

class myRenderEngine {
    __New(configManager) {
        this.Config := configManager
        this.CacheReq := UIA.CreateCacheRequest(["ControlType", "BoundingRectangle", "IsOffscreen"])
        this.FocusGui := Gui("-Caption +ToolWindow +E0x20")
        this.FocusGui.BackColor := this.Config.BorderColor
        WinSetTransparent(Round(255 * this.Config.Transparency), this.FocusGui.Hwnd)

        this.LastHwnd := 0
        this.gLastW := 0
        this.gLastH := 0
        this.gLastVX := 0
        this.gLastVY := 0
        this.gLastVW := 0
        this.gLastVH := 0
        this.IsConfigMode := false

        this.WatchdogBound := ObjBindMethod(this, "RenderWatchdog")
    }

    myUpdateAppearance() {
        this.FocusGui.BackColor := this.Config.BorderColor
        WinSetTransparent(Round(255 * this.Config.Transparency), this.FocusGui.Hwnd)
        this.myApplyBorderRegion(this.Config.BorderThickness, this.gLastW, this.gLastH, this.gLastVX, this.gLastVY, this.gLastVW, this.gLastVH)
    }

    myStartWatchdog(hwnd) {
        this.LastHwnd := hwnd
        SetTimer(this.WatchdogBound, 15)
    }

    myStopWatchdog() {
        SetTimer(this.WatchdogBound, 0)
    }

    myApplyBorderRegion(g, w, h, vX, vY, vW, vH) {
        if (w <= 0 || h <= 0 || vW <= 0 || vH <= 0)
            return
        hRgnOuter := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
        hRgnInner := DllCall("CreateRectRgn", "Int", g, "Int", g, "Int", w - g, "Int", h - g, "Ptr")
        DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnInner, "Int", 4)
        hRgnClip := DllCall("CreateRectRgn", "Int", vX, "Int", vY, "Int", vX + vW, "Int", vY + vH, "Ptr")
        DllCall("CombineRgn", "Ptr", hRgnOuter, "Ptr", hRgnOuter, "Ptr", hRgnClip, "Int", 1)
        DllCall("SetWindowRgn", "Ptr", this.FocusGui.Hwnd, "Ptr", hRgnOuter, "Int", 1)
        DllCall("DeleteObject", "Ptr", hRgnInner)
        DllCall("DeleteObject", "Ptr", hRgnClip)
    }

    IsSupportedWindow() => WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman")

    RenderWatchdog() {
        if (this.IsConfigMode && !this.IsSupportedWindow())
            return
        static lastState := ""
        static lastHwndAbove := -1
        try {
            if (!this.IsSupportedWindow() || !WinExist("ahk_id " this.LastHwnd))
                throw Error()

            el := UIA.GetFocusedElement(this.CacheReq)
            if (el.CachedControlType != 50007)
                throw Error()

            rect := el.CachedBoundingRectangle
            w := rect.r - rect.l, h := rect.b - rect.t

            WinGetPos(&oX, &oY, &oW, &oH, "ahk_id " this.LastHwnd)
            ix1 := Max(rect.l, oX), iy1 := Max(rect.t, oY)
            ix2 := Min(rect.r, oX + oW), iy2 := Min(rect.b, oY + oH)

            if (el.CachedIsOffscreen || w <= 0 || h <= 0 || ix1 >= ix2 || iy1 >= iy2) {
                this.FocusGui.Hide()
                lastState := ""
                lastHwndAbove := -1
                return
            }

            vX := ix1 - rect.l, vY := iy1 - rect.t
            vW := ix2 - ix1, vH := iy2 - iy1

            state := rect.l "|" rect.t "|" w "|" h "|" vX "|" vY "|" vW "|" vH
            stateChange := (state != lastState)

            if (stateChange) {
                lastState := state
                this.gLastW := w, this.gLastH := h, this.gLastVX := vX, this.gLastVY := vY, this.gLastVW := vW, this.gLastVH := vH
                this.myApplyBorderRegion(this.Config.BorderThickness, w, h, vX, vY, vW, vH)
                this.FocusGui.Show("NA x" rect.l " y" rect.t " w" w " h" h)
            }

            topHwnd := DllCall("GetAncestor", "Ptr", this.LastHwnd, "UInt", 2, "Ptr")
            hwndAbove := DllCall("GetWindow", "Ptr", topHwnd, "UInt", 3, "Ptr")
            if (hwndAbove != lastHwndAbove || stateChange) {
                lastHwndAbove := hwndAbove
                DllCall("SetWindowPos", "Ptr", this.FocusGui.Hwnd, "Ptr", hwndAbove ? hwndAbove : 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
            }
        } catch {
            this.FocusGui.Hide()
            lastState := ""
            lastHwndAbove := -1
            this.myStopWatchdog()
        }
    }
}

class myHookManager {
    __New(renderEngine, configManager) {
        this.Renderer := renderEngine
        this.Config := configManager

        this.ThemeChangeBound := ObjBindMethod(this, "myThemeChangeHook")
        OnMessage(0x001A, this.ThemeChangeBound)

        this.HideBorderBound := ObjBindMethod(this, "HideNativeBorderEvent")
        this.FocusHook := DllCall("SetWinEventHook", "UInt", 0x8005, "UInt", 0x8005, "Ptr", 0, "Ptr", CallbackCreate(this.HideBorderBound, "F", 7), "UInt", 0, "UInt", 0, "UInt", 0)
    }

    myThemeChangeHook(wParam, lParam, msg, hwnd) {
        local targetParam := ""
        try targetParam := StrGet(lParam)
        if (targetParam = "ImmersiveColorSet") {
            if (IniRead(this.Config.IniPath, "Settings", "BorderColor", "") == "") {
                this.Config.BorderColor := myGetThemeColor()
                this.Renderer.myUpdateAppearance()
            }
        }
    }

    HideNativeBorderEvent(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
        if hwnd
            try PostMessage(0x0128, 0x00010001, 0, , "ahk_id " hwnd)
        this.Renderer.myStartWatchdog(hwnd)
    }
}

class mySettingsGui {
    __New(configManager, renderEngine) {
        this.Config := configManager
        this.Renderer := renderEngine
    }

    myShow() {
        if WinExist("Absurdian Focus Frame") {
            WinActivate("Absurdian Focus Frame")
            return
        }
        try {
            if hwnd := WinExist("ahk_class WorkerW") || WinExist("ahk_class Progman")
                WinActivate("ahk_id " hwnd)
            Sleep(100)
        }
        this.Renderer.IsConfigMode := true

        this.Gui := Gui("-MinimizeBox -MaximizeBox", "Absurdian Focus Frame")
        this.Gui.MarginX := 15
        this.Gui.MarginY := 15

        this.origThick := this.Config.BorderThickness
        this.origTrans := Format("{:.2f}", this.Config.Transparency)
        this.origColor := IniRead(this.Config.IniPath, "Settings", "BorderColor", "")
        this.origAutostart := this.Config.Autostart

        this.Gui.OnEvent("Close", ObjBindMethod(this, "CleanupAndDestroy"))

        myBtnInfo := this.Gui.Add("Button", "xm y5", "ℹ️")
        myBtnInfo.OnEvent("Click", ObjBindMethod(this, "ShowInfoDialog"))

        this.Gui.Add("Text", "xm y+5", "Border Thickness (px):")
        this.myThickEdit := this.Gui.Add("Edit", "xm y+5 w80 vBorderThickness", this.Config.BorderThickness)
        this.myThickUD := this.Gui.Add("UpDown", "Range1-4", this.Config.BorderThickness)
        this.myThickUD.OnEvent("Change", ObjBindMethod(this, "OnThickChange"))

        this.myBtnUndoThick := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoThick.OnEvent("Click", ObjBindMethod(this, "OnUndoThick"))

        this.Gui.Add("Text", "xm y+5", "Transparency (0.0 - 1.0):")
        this.myTransEdit := this.Gui.Add("Edit", "xm y+5 w60 vTransparency", Format("{:.2f}", this.Config.Transparency))
        this.myTransUD := this.Gui.Add("UpDown", "-2 Range0-20", Round(this.Config.Transparency / 0.05))
        this.myTransUD.OnEvent("Change", ObjBindMethod(this, "OnTransChange"))

        this.myBtnUndoTrans := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoTrans.OnEvent("Click", ObjBindMethod(this, "OnUndoTrans"))

        this.WheelBound := ObjBindMethod(this, "HandleMouseWheel")
        OnMessage(0x020A, this.WheelBound)

        this.Gui.Add("Text", "xm y+5", "Border Color (HEX, empty for auto):")
        this.myColorEdit := this.Gui.Add("Edit", "xm y+5 w60 vBorderColor", this.origColor)
        this.myColorEdit.LastGood := this.origColor

        this.MoveBound := ObjBindMethod(this, "HandleMouseMove")
        OnMessage(0x0200, this.MoveBound)

        this.myColorEdit.OnEvent("Change", ObjBindMethod(this, "OnColorChange"))

        myBtnPicker := this.Gui.Add("Button", "x+2 yp w22 h22", "🎨")
        myBtnPicker.OnEvent("Click", ObjBindMethod(this, "OnColorPick"))

        myBtnDropper := this.Gui.Add("Button", "x+2 yp w22 h22", "💉")
        myBtnDropper.OnEvent("Click", ObjBindMethod(this, "OnColorDrop"))

        this.myBtnUndoColor := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoColor.OnEvent("Click", ObjBindMethod(this, "OnUndoColor"))

        this.myCbAutostart := this.Gui.Add("Checkbox", "xm y+5 h22 vAutostart Checked" this.Config.Autostart, "Run at system startup")
        this.myCbAutostart.OnEvent("Click", ObjBindMethod(this, "CheckUndoStates"))

        this.myBtnUndoAutostart := this.Gui.Add("Button", "x+0 yp w22 h22 Disabled", "↩")
        this.myBtnUndoAutostart.OnEvent("Click", ObjBindMethod(this, "OnUndoAutostart"))

        myBtnSave := this.Gui.Add("Button", "xm y+5 w80 Default", "Save")
        myBtnSave.OnEvent("Click", ObjBindMethod(this, "mySaveSettings"))

        myBtnCancel := this.Gui.Add("Button", "x+5 yp w80", "Cancel")
        myBtnCancel.OnEvent("Click", ObjBindMethod(this, "CleanupAndDestroy"))

        this.Gui.Show()
    }

    OnThickChange(ctrl, *) {
        this.Renderer.myApplyBorderRegion(ctrl.Value, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH)
        this.CheckUndoStates()
    }

    OnUndoThick(*) {
        this.myThickEdit.Value := this.origThick
        this.Renderer.myApplyBorderRegion(this.origThick, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH)
        this.CheckUndoStates()
    }

    OnTransChange(ctrl, *) {
        this.myTransEdit.Value := Format("{:.2f}", ctrl.Value * 0.05)
        WinSetTransparent(Round(255 * (ctrl.Value * 0.05)), this.Renderer.FocusGui.Hwnd)
        this.CheckUndoStates()
    }

    OnUndoTrans(*) {
        this.myTransUD.Value := Round(this.origTrans / 0.05)
        this.myTransEdit.Value := this.origTrans
        WinSetTransparent(Round(255 * Float(this.origTrans)), this.Renderer.FocusGui.Hwnd)
        this.CheckUndoStates()
    }

    OnColorChange(ctrl, *) {
        try {
            this.Renderer.FocusGui.BackColor := (ctrl.Value != "" ? ctrl.Value : myGetThemeColor())
            ctrl.LastGood := ctrl.Value
            this.CheckUndoStates()
        } catch {
            MsgBox("Nieprawidlowy format koloru.", "Blad", 16)
            ctrl.Value := ctrl.HasOwnProp("LastGood") ? ctrl.LastGood : this.origColor
            this.CheckUndoStates()
        }
    }

    OnColorPick(*) {
        res := myChooseColor(this.myColorEdit.Value != "" ? this.myColorEdit.Value : myGetThemeColor(), this.Gui.Hwnd)
        if (res != "") {
            this.myColorEdit.Value := res
            this.Renderer.FocusGui.BackColor := res
            this.CheckUndoStates()
        }
    }

    OnColorDrop(*) {
        res := myPickColorFromScreen()
        if (res != "") {
            this.myColorEdit.Value := res
            this.Renderer.FocusGui.BackColor := res
        } else {
            this.Renderer.FocusGui.BackColor := (this.myColorEdit.Value != "" ? this.myColorEdit.Value : myGetThemeColor())
        }
        this.CheckUndoStates()
    }

    OnUndoColor(*) {
        this.myColorEdit.Value := this.origColor
        this.Renderer.FocusGui.BackColor := (this.origColor != "" ? this.origColor : myGetThemeColor())
        this.CheckUndoStates()
    }

    OnUndoAutostart(*) {
        this.myCbAutostart.Value := this.origAutostart
        this.CheckUndoStates()
    }

    HandleMouseWheel(wParam, lParam, msg, hwnd) {
        if (hwnd == this.myTransEdit.Hwnd || hwnd == this.myTransUD.Hwnd) {
            dir := (wParam << 32 >> 48) > 0 ? 1 : -1
            this.myTransUD.Value += dir
            this.myTransEdit.Value := Format("{:.2f}", this.myTransUD.Value * 0.05)
            WinSetTransparent(Round(255 * (this.myTransUD.Value * 0.05)), this.Renderer.FocusGui.Hwnd)
            this.CheckUndoStates()
            return 1
        }
    }

    HandleMouseMove(wParam, lParam, msg, hwnd) {
        static lastHwnd := 0
        if (hwnd == lastHwnd)
            return
        lastHwnd := hwnd
        if (hwnd == this.myColorEdit.Hwnd)
            ToolTip("Leave empty for auto-theme.")
        else
            ToolTip()
    }

    CheckUndoStates(*) {
        this.myBtnUndoThick.Enabled := (this.myThickUD.Value != this.origThick)
        this.myBtnUndoTrans.Enabled := (this.myTransEdit.Value != this.origTrans)
        this.myBtnUndoColor.Enabled := (this.myColorEdit.Value != this.origColor)
        this.myBtnUndoAutostart.Enabled := (this.myCbAutostart.Value != this.origAutostart)
    }

    mySaveSettings(*) {
        mySaved := this.Gui.Submit()
        this.Config.mySaveData(mySaved.BorderThickness, mySaved.Transparency, mySaved.BorderColor, mySaved.Autostart)
        Reload()
    }

    CleanupAndDestroy(*) {
        this.Renderer.IsConfigMode := false
        OnMessage(0x020A, this.WheelBound, 0)
        try OnMessage(0x0200, this.MoveBound, 0)
        ToolTip()

        this.Renderer.FocusGui.BackColor := (this.Config.BorderColor == "" ? myGetThemeColor() : this.Config.BorderColor)
        WinSetTransparent(Round(255 * this.Config.Transparency), this.Renderer.FocusGui.Hwnd)
        this.Renderer.myApplyBorderRegion(this.Config.BorderThickness, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH)

        this.Gui.Destroy()
    }

    ShowInfoDialog(*) {
        infoGui := Gui("+Owner" this.Gui.Hwnd " -MinimizeBox -MaximizeBox", "Absurdian Focus Frame - Info")
        this.Gui.Opt("+Disabled")

        infoClose := (*) => (this.Gui.Opt("-Disabled"), infoGui.Destroy())
        infoGui.OnEvent("Close", infoClose)

        infoGui.MarginX := 20
        infoGui.MarginY := 20
        infoGui.Add("Text", "w280", "WELCOME TO ABSURDIAN FOCUS FRAME!`n`nThis program changes the appearance of the native dotted selection border on the desktop to a modern highlight.`n`nThis project wouldn't be possible without the AutoHotkey community.`nSpecial thanks to: Descolada - for the amazing UIA.ahk library.")
        infoGui.Add("Link", "xm y+10", "my GitHub: <a href=`"https://github.com/AbsurdianVibe`">AbsurdianVibe</a>")
        infoGui.Add("Text", "xm y+10", "Happy clicking!")
        btnOk := infoGui.Add("Button", "w80 x120 y+20 Default", "OK")
        btnOk.OnEvent("Click", infoClose)
        infoGui.Show()
    }
}

/**
 * Retrieves current system theme color.
 * @returns {String} Hex color code.
 */
myGetThemeColor() {
    local isLight := 0
    try isLight := RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    return isLight ? "000000" : "ffffff"
}

/**
 * Opens color selection dialog.
 * @param {String} initHex - Initial hex color.
 * @param {Integer} [hwndOwner=0] - Window owner handle.
 * @returns {String} Selected hex color.
 */
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
    NumPut("UInt", 0x103, CC, A_PtrSize == 8 ? 40 : 20)

    if DllCall("comdlg32\ChooseColorW", "Ptr", CC.Ptr) {
        bgr := NumGet(CC, A_PtrSize == 8 ? 24 : 12, "UInt")
        rgb := (bgr & 0xFF0000) >> 16 | (bgr & 0x00FF00) | (bgr & 0x0000FF) << 16
        return Format("{:06x}", rgb)
    }
    return ""
}

/**
 * Starts screen color picking mode.
 * @returns {String} Picked hex color.
 */
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
            try MainRenderer.FocusGui.BackColor := hexC
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