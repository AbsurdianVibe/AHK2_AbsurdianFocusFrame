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
        this.lastHue := -1
        this.lastSat := -1
        this.lastHueLum := -1
        this.picW := 300
        this.picH := 40
        this.indW := 10
        this.indH := 52
        this.gdiScale := 3
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

        this.Gui.OnEvent("Close", (*) => this.myCleanupAndDestroy())

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

        myBtnDrop := this.Gui.Add("Button", "x+2 yp w22 h22", "💉")
        myBtnDrop.OnEvent("Click", (*) => this.OnColorDrop())
        this.myBtnUndoColor := this.Gui.Add("Button", "x+2 yp w22 h22 Disabled", "↩")
        this.myBtnUndoColor.OnEvent("Click", (*) => this.OnUndoColor())

        this.Gui.Add("Text", "xm y+15", "Launch with Windows:")
        this.myCbAutostart := this.Gui.Add("CheckBox", "xm y+5 vAutostart", "Enable Autostart")
        this.myCbAutostart.Value := this.origAutostart
        this.myCbAutostart.OnEvent("Click", (ctrl, *) => this.CheckUndoStates())
        this.myBtnUndoAutostart := this.Gui.Add("Button", "x+10 yp w22 h22 Disabled", "↩")
        this.myBtnUndoAutostart.OnEvent("Click", (*) => this.OnUndoAutostart())

        btnSave := this.Gui.Add("Button", "xm y+20 w100 Default", "Save")
        btnSave.OnEvent("Click", (*) => this.mySaveSettings())
        btnCancel := this.Gui.Add("Button", "x+10 yp w100", "Cancel")
        btnCancel.OnEvent("Click", (*) => this.myCleanupAndDestroy())

        this.CheckUndoStates()

        this.Gui.Show("AutoSize Hide")
        this.Gui.GetClientPos(&_x, &_y, &baseCW, &baseCH)
        this.baseCW := baseCW, this.baseCH := baseCH

        ; --- SEKCYJNY COLOR PICKER GDI ---
        this.lblSpec := this.Gui.Add("Text", "ym Section Hidden", "Spectrum:")
        this.picSpec := this.Gui.Add("Picture", "xs y+7 w" this.picW " h" this.picH " +Border +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSpec := this.Gui.Add("Picture", "xp yp w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSpec.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSpec))

        this.lblSat := this.Gui.Add("Text", "xs y+10 Hidden", "Saturation:")
        this.picSat := this.Gui.Add("Picture", "xs y+7 w" this.picW " h" this.picH " +Border +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSat := this.Gui.Add("Picture", "xp yp w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSat.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSat))

        this.lblLum := this.Gui.Add("Text", "xs y+10 h22 +0x0200 Hidden", "Luminance:")
        this.btnLumR := this.Gui.Add("Button", "x+5 yp w22 h22 Hidden", "M")
        this.btnLumR.OnEvent("Click", (*) => this.myResetLuminance())
        this.picLum := this.Gui.Add("Picture", "xs y+7 w" this.picW " h" this.picH " +Border +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indLum := this.Gui.Add("Picture", "xp yp w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
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
            this.lblSpec.Visible := true, this.picSpec.Visible := true, this.indSpec.Visible := true
            this.lblSat.Visible := true, this.picSat.Visible := true, this.indSat.Visible := true
            this.lblLum.Visible := true, this.picLum.Visible := true, this.indLum.Visible := true, this.btnLumR.Visible := true
            this.Gui.Show("AutoSize")
        } else {
            this.lblSpec.Visible := false, this.picSpec.Visible := false, this.indSpec.Visible := false
            this.lblSat.Visible := false, this.picSat.Visible := false, this.indSat.Visible := false
            this.lblLum.Visible := false, this.picLum.Visible := false, this.indLum.Visible := false, this.btnLumR.Visible := false
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
            step := 0.005
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

            changed := false
            if (ctrlObj == this.picSpec) {
                ratio := Mod(ratio, 1.0)
                if (ratio < 0)
                    ratio += 1.0
                if (ratio != this.HueRatio) {
                    this.HueRatio := ratio
                    changed := true
                }
            } else {
                ratio := Max(0.0, Min(1.0, ratio))
                if (ctrlObj == this.picSat && ratio != this.SatRatio) {
                    this.SatRatio := ratio
                    changed := true
                } else if (ctrlObj == this.picLum && ratio != this.LumRatio) {
                    this.LumRatio := ratio
                    changed := true
                }
            }

            if (changed)
                this.myUpdateColorSpace(false, true) ; FastTrack

            if !GetKeyState("LButton", "P")
                break
            Sleep(15)
        }
        this.myUpdateColorSpace()
    }

    myUpdateColorSpace(firstRender := false, fastTrack := false) {
        hue := this.HueRatio * 359
        baseRgb := myHsvToRgb(hue, 1, 1)
        this.HueBaseR := baseRgb.r, this.HueBaseG := baseRgb.g, this.HueBaseB := baseRgb.b
        bufferW := this.picW * this.gdiScale

        if (firstRender) {
            hBM1 := this.GradientEngine.myRenderSpectrum(bufferW, this.picH)
            this.GradientEngine.myApplyBitmap(this.picSpec.Hwnd, hBM1)

            dpiScale := A_ScreenDPI / 96
            hArr1 := this.GradientEngine.myRenderIndicatorArrows(this.indW, this.indH, dpiScale)
            this.GradientEngine.myApplyBitmap(this.indSpec.Hwnd, hArr1)
            hArr2 := this.GradientEngine.myRenderIndicatorArrows(this.indW, this.indH, dpiScale)
            this.GradientEngine.myApplyBitmap(this.indSat.Hwnd, hArr2)
            hArr3 := this.GradientEngine.myRenderIndicatorArrows(this.indW, this.indH, dpiScale)
            this.GradientEngine.myApplyBitmap(this.indLum.Hwnd, hArr3)
        }

        szary := Round((this.HueBaseR * 0.299) + (this.HueBaseG * 0.587) + (this.HueBaseB * 0.114))
        sr := Round(this.HueBaseR + (szary - this.HueBaseR) * this.SatRatio)
        sg := Round(this.HueBaseG + (szary - this.HueBaseG) * this.SatRatio)
        sb := Round(this.HueBaseB + (szary - this.HueBaseB) * this.SatRatio)

        if (!fastTrack) {
            if (firstRender || this.lastHue != hue) {
                hBM2 := this.GradientEngine.myRenderSaturation(bufferW, this.picH, this.HueBaseR, this.HueBaseG, this.HueBaseB)
                this.GradientEngine.myApplyBitmap(this.picSat.Hwnd, hBM2)
                this.lastHue := hue
            }
            if (firstRender || this.lastSat != this.SatRatio || this.lastHueLum != hue) {
                hBM3 := this.GradientEngine.myRenderLuminance(bufferW, this.picH, sr, sg, sb)
                this.GradientEngine.myApplyBitmap(this.picLum.Hwnd, hBM3)
                this.lastSat := this.SatRatio
                this.lastHueLum := hue
            }
        }

        if (this.PickerVisible) {
            this.picSpec.GetPos(&x1, &y1, &w1, &h1)
            this.indSpec.GetPos(&ix1, &iy1, &iw1, &ih1)
            this.indSpec.Move(x1 + Round(this.HueRatio * (w1 - 1)) - (iw1 // 2), y1 + ((h1 - ih1) // 2), iw1, ih1)

            this.picSat.GetPos(&x2, &y2, &w2, &h2)
            this.indSat.GetPos(&ix2, &iy2, &iw2, &ih2)
            this.indSat.Move(x2 + Round(this.SatRatio * (w2 - 1)) - (iw2 // 2), y2 + ((h2 - ih2) // 2), iw2, ih2)

            this.picLum.GetPos(&x3, &y3, &w3, &h3)
            this.indLum.GetPos(&ix3, &iy3, &iw3, &ih3)
            this.indLum.Move(x3 + Round(this.LumRatio * (w3 - 1)) - (iw3 // 2), y3 + ((h3 - ih3) // 2), iw3, ih3)
        }

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
        if (!firstRender) {
            this.myColorEdit.Value := hex
            this.Renderer.FocusGui.BackColor := hex
        }
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

    myCleanupAndDestroy(*) {
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