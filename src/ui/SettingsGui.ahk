class mySettingsGui {
    /** @type {myConfigManager} */
    Config := ""
    /** @type {myRenderEngine} */
    Renderer := ""

    /**
     * @param {myConfigManager} configManager
     * @param {myRenderEngine} renderEngine
     */
    __New(configManager, renderEngine) {
        this.Config := configManager
        this.Renderer := renderEngine
        this.GradientEngine := myGradientRenderer()
        this.HueRatio := 0.0
        this.SatRatio := 1.0
        this.LumRatio := 0.5
        this.PickerVisible := false
        this.HueBaseR := 255
        this.HueBaseG := 0
        this.HueBaseB := 0
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
        this.PickerVisible := false
        this.Gui.MarginX := 15
        this.Gui.MarginY := 15

        this.origThick := this.Config.BorderThickness
        this.origTrans := Format("{:.2f}", this.Config.Transparency)
        this.origColor := IniRead(this.Config.IniPath, "Settings", "BorderColor", "")
        this.origAutostart := this.Config.Autostart

        this.Gui.OnEvent("Close", (*) => this.CleanupAndDestroy())

        myBtnInfo := this.Gui.Add("Button", "xm y5", "ℹ️")
        myBtnInfo.OnEvent("Click", (*) => this.ShowInfoDialog())

        this.Gui.Add("Text", "xm y+5", "Border Thickness (px):")
        this.myThickEdit := this.Gui.Add("Edit", "xm y+5 w80 vBorderThickness", this.Config.BorderThickness)
        this.myThickUD := this.Gui.Add("UpDown", "Range1-4", this.Config.BorderThickness)
        this.myThickUD.OnEvent("Change", (ctrl, *) => this.OnThickChange(ctrl))

        this.myBtnUndoThick := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoThick.OnEvent("Click", (*) => this.OnUndoThick())

        this.Gui.Add("Text", "xm y+5", "Transparency (0.0 - 1.0):")
        this.myTransEdit := this.Gui.Add("Edit", "xm y+5 w60 vTransparency", Format("{:.2f}", this.Config.Transparency))
        this.myTransUD := this.Gui.Add("UpDown", "-2 Range0-20", Round(this.Config.Transparency / 0.05))
        this.myTransUD.OnEvent("Change", (ctrl, *) => this.OnTransChange(ctrl))

        this.myBtnUndoTrans := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoTrans.OnEvent("Click", (*) => this.OnUndoTrans())

        this.WheelBound := (wParam, _1, _2, hwnd, *) => this.HandleMouseWheel(wParam, hwnd)
        OnMessage(0x020A, this.WheelBound)

        this.Gui.Add("Text", "xm y+5", "Border Color (HEX, empty for auto):")
        this.myColorEdit := this.Gui.Add("Edit", "xm y+5 w60 vBorderColor", this.origColor)
        this.myColorEdit.LastGood := this.origColor

        this.MoveBound := (_1, _2, _3, hwnd, *) => this.HandleMouseMove(hwnd)
        OnMessage(0x0200, this.MoveBound)

        this.myColorEdit.OnEvent("Change", (ctrl, *) => this.OnColorChange(ctrl))

        myBtnPicker := this.Gui.Add("Button", "x+2 yp w22 h22", "🎨")
        myBtnPicker.OnEvent("Click", (*) => this.myTogglePicker())

        myBtnDropper := this.Gui.Add("Button", "x+2 yp w22 h22", "💉")
        myBtnDropper.OnEvent("Click", (*) => this.OnColorDrop())

        this.myBtnUndoColor := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoColor.OnEvent("Click", (*) => this.OnUndoColor())

        this.myCbAutostart := this.Gui.Add("Checkbox", "xm y+5 h22 vAutostart Checked" this.Config.Autostart, "Run at system startup")
        this.myCbAutostart.OnEvent("Click", (*) => this.CheckUndoStates())

        this.myBtnUndoAutostart := this.Gui.Add("Button", "x+0 yp w22 h22 Disabled", "↩")
        this.myBtnUndoAutostart.OnEvent("Click", (*) => this.OnUndoAutostart())

        myBtnSave := this.Gui.Add("Button", "xm y+5 w80 Default", "Save")
        myBtnSave.OnEvent("Click", (*) => this.mySaveSettings())

        myBtnCancel := this.Gui.Add("Button", "x+5 yp w80", "Cancel")
        myBtnCancel.OnEvent("Click", (*) => this.CleanupAndDestroy())

        this.Gui.Show("AutoSize Hide")
        this.Gui.GetClientPos(&_x, &_y, &baseCW, &baseCH)
        this.baseCW := baseCW, this.baseCH := baseCH

        ; --- SEKCYJNY COLOR PICKER GDI ---
        this.lblSpec := this.Gui.Add("Text", "ym Section Hidden", "Spectrum:")
        this.picSpec := this.Gui.Add("Picture", "xs y+5 w180 h20 +Border +0x0100 +0xE Hidden")
        this.picSpec.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSpec))

        this.lblSat := this.Gui.Add("Text", "xs y+10 Hidden", "Saturation:")
        this.picSat := this.Gui.Add("Picture", "xs y+5 w180 h20 +Border +0x0100 +0xE Hidden")
        this.picSat.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSat))

        this.lblLum := this.Gui.Add("Text", "xs y+10 h22 +0x0200 Hidden", "Luminance:")
        this.btnLumR := this.Gui.Add("Button", "x+5 yp w22 h22 Hidden", "M")
        this.btnLumR.OnEvent("Click", (*) => this.myResetLuminance())
        this.picLum := this.Gui.Add("Picture", "xs y+5 w180 h20 +Border +0x0100 +0xE Hidden")
        this.picLum.OnEvent("Click", (*) => this.myOnSliderInteract(this.picLum))

        this.mySyncSlidersFromHex(this.origColor != "" ? this.origColor : myGetThemeColor())

        this.Gui.Show("AutoSize Hide")
        this.Gui.Show("w" this.baseCW " h" this.baseCH)
    }

    myTogglePicker() {
        this.PickerVisible := !this.PickerVisible
        w := 180, h := 20
        if (this.PickerVisible) {
            this.myUpdateColorSpace(true)
            this.lblSpec.Visible := true, this.picSpec.Visible := true
            this.lblSat.Visible := true, this.picSat.Visible := true
            this.lblLum.Visible := true, this.picLum.Visible := true, this.btnLumR.Visible := true
            this.Gui.Show("AutoSize")
        } else {
            this.lblSpec.Visible := false, this.picSpec.Visible := false
            this.lblSat.Visible := false, this.picSat.Visible := false
            this.lblLum.Visible := false, this.picLum.Visible := false, this.btnLumR.Visible := false
            this.Gui.Show("w" this.baseCW " h" this.baseCH)
        }
    }

    myResetLuminance(*) {
        this.LumRatio := 0.5
        this.myUpdateColorSpace()
    }

    myOnSliderInteract(ctrlObj, scrollDir := 0) {
        CoordMode("Mouse", "Screen")
        WinGetPos(&cX, &cY, &cW, &cH, ctrlObj.Hwnd)
        limit := cW
        baseCoord := cX

        if (scrollDir != 0) {
            step := 0.05
            ratio := (ctrlObj == this.picSpec) ? this.HueRatio : ((ctrlObj == this.picSat) ? this.SatRatio : this.LumRatio)
            ratio += (scrollDir * step)

            if (ctrlObj == this.picSpec) {
                ratio := Mod(ratio, 1.0)
                if (ratio < 0)
                    ratio += 1.0
                this.HueRatio := ratio
            } else {
                ratio := Max(0.0, Min(1.0, ratio))
                if (ctrlObj == this.picSat)
                    this.SatRatio := ratio
                else
                    this.LumRatio := ratio
            }
            this.myUpdateColorSpace()
            return
        }

        Loop {
            MouseGetPos(&mX, &mY)
            rel := mX - baseCoord
            ratio := rel / (limit - 1)

            if (ctrlObj == this.picSpec) {
                ratio := Mod(ratio, 1.0)
                if (ratio < 0)
                    ratio += 1.0
                if (ratio != this.HueRatio) {
                    this.HueRatio := ratio
                    this.myUpdateColorSpace()
                }
            } else {
                ratio := Max(0.0, Min(1.0, ratio))
                if (ctrlObj == this.picSat && ratio != this.SatRatio) {
                    this.SatRatio := ratio
                    this.myUpdateColorSpace()
                } else if (ctrlObj == this.picLum && ratio != this.LumRatio) {
                    this.LumRatio := ratio
                    this.myUpdateColorSpace()
                }
            }

            if !GetKeyState("LButton", "P")
                break
            Sleep(20)
        }
    }

    myUpdateColorSpace(firstRender := false) {
        hue := this.HueRatio * 359
        baseRgb := myHsvToRgb(hue, 1, 1)
        this.HueBaseR := baseRgb.r, this.HueBaseG := baseRgb.g, this.HueBaseB := baseRgb.b

        hBM1 := this.GradientEngine.myRenderSpectrum(600, 40, this.HueRatio)
        this.GradientEngine.myApplyBitmap(this.picSpec.Hwnd, hBM1)

        hBM2 := this.GradientEngine.myRenderSaturation(600, 40, this.SatRatio, this.HueBaseR, this.HueBaseG, this.HueBaseB)
        this.GradientEngine.myApplyBitmap(this.picSat.Hwnd, hBM2)

        szary := Round((this.HueBaseR * 0.299) + (this.HueBaseG * 0.587) + (this.HueBaseB * 0.114))
        sr := Round(this.HueBaseR + (szary - this.HueBaseR) * this.SatRatio)
        sg := Round(this.HueBaseG + (szary - this.HueBaseG) * this.SatRatio)
        sb := Round(this.HueBaseB + (szary - this.HueBaseB) * this.SatRatio)

        hBM3 := this.GradientEngine.myRenderLuminance(600, 40, this.LumRatio, sr, sg, sb)
        this.GradientEngine.myApplyBitmap(this.picLum.Hwnd, hBM3)

        i := this.LumRatio
        if (i < 0.5) {
            p := i / 0.5
            fr := Round(255 + (sr - 255) * p)
            fg := Round(255 + (sg - 255) * p)
            fb := Round(255 + (sb - 255) * p)
        } else {
            p := (i - 0.5) / 0.5
            fr := Round(sr * (1 - p))
            fg := Round(sg * (1 - p))
            fb := Round(sb * (1 - p))
        }

        hex := Format("{:02x}{:02x}{:02x}", fr, fg, fb)
        this.myColorEdit.Value := hex
        if (!firstRender)
            this.Renderer.FocusGui.BackColor := hex
        this.CheckUndoStates()
    }

    mySyncSlidersFromHex(hexStr) {
        hsl := myHexToHsl(hexStr)
        this.HueRatio := hsl.h
        this.SatRatio := hsl.s
        this.LumRatio := hsl.l
        if (this.PickerVisible)
            this.myUpdateColorSpace(true)
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
            hexStr := (ctrl.Value != "" ? ctrl.Value : myGetThemeColor())
            this.Renderer.FocusGui.BackColor := hexStr
            this.mySyncSlidersFromHex(hexStr)
            ctrl.LastGood := ctrl.Value
            this.CheckUndoStates()
        } catch {
            MsgBox("Nieprawidlowy format koloru.", "Blad", 16)
            ctrl.Value := ctrl.HasOwnProp("LastGood") ? ctrl.LastGood : this.origColor
            this.CheckUndoStates()
        }
    }

    OnColorDrop(*) {
        res := myPickColorFromScreen(this.Renderer)
        if (res != "") {
            this.myColorEdit.Value := res
            this.Renderer.FocusGui.BackColor := res
            this.mySyncSlidersFromHex(res)
        } else {
            hexStr := (this.myColorEdit.Value != "" ? this.myColorEdit.Value : myGetThemeColor())
            this.Renderer.FocusGui.BackColor := hexStr
            this.mySyncSlidersFromHex(hexStr)
        }
        this.CheckUndoStates()
    }

    OnUndoColor(*) {
        this.myColorEdit.Value := this.origColor
        hexStr := (this.origColor != "" ? this.origColor : myGetThemeColor())
        this.Renderer.FocusGui.BackColor := hexStr
        this.mySyncSlidersFromHex(hexStr)
        this.CheckUndoStates()
    }

    OnUndoAutostart(*) {
        this.myCbAutostart.Value := this.origAutostart
        this.CheckUndoStates()
    }

    HandleMouseWheel(wParam, hwnd) {
        dir := (wParam << 32 >> 48) > 0 ? 1 : -1
        if (hwnd == this.myTransEdit.Hwnd || hwnd == this.myTransUD.Hwnd) {
            this.myTransUD.Value += dir
            this.myTransEdit.Value := Format("{:.2f}", this.myTransUD.Value * 0.05)
            WinSetTransparent(Round(255 * (this.myTransUD.Value * 0.05)), this.Renderer.FocusGui.Hwnd)
            this.CheckUndoStates()
            return 1
        }
        if (this.PickerVisible) {
            if (hwnd == this.picSpec.Hwnd) {
                this.myOnSliderInteract(this.picSpec, dir)
                return 1
            }
            if (hwnd == this.picSat.Hwnd) {
                this.myOnSliderInteract(this.picSat, dir)
                return 1
            }
            if (hwnd == this.picLum.Hwnd) {
                this.myOnSliderInteract(this.picLum, dir)
                return 1
            }
        }
    }

    HandleMouseMove(hwnd) {
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