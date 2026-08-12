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
        this.lastLumForSat := -1
        this.picW := 300
        this.picH := 40
        this.indW := 10
        this.indH := 54
        this.indCutHeight := 5
        this.gdiScale := 3
        this.grayColor := "d3d3d3"
        this.HoverTipBound := this.ShowHoverTip.Bind(this)
        this.CurrentTip := ""
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
        this.Ygap := 6
        this.Gui.MarginY := this.Ygap

        this.origThick := this.Config.BorderThickness
        this.origTrans := Format("{:.2f}", this.Config.Transparency)
        this.origColor := IniRead(this.Config.IniPath, "Settings", "BorderColor", "")
        this.origAutostart := this.Config.Autostart
        this.origRounded := this.Config.UseRoundedCorners

        this.Gui.OnEvent("Close", (*) => this.myCleanupAndDestroy())

        myBtnInfo := this.Gui.Add("Button", "xm y" this.Ygap, "ℹ️ About program")
        myBtnInfo.OnEvent("Click", (*) => this.ShowInfoDialog())

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+" this.Ygap, "Border Thickness (px):")
        this.myThickEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w80 vBorderThickness", this.Config.BorderThickness)
        this.myThickUD := this.Gui.Add("UpDown", "Range1-4", this.Config.BorderThickness)
        this.myThickUD.OnEvent("Change", (ctrl, *) => this.OnThickChange(ctrl))

        this.myBtnUndoThick := this.mySmallButton()
        this.myBtnUndoThick.OnEvent("Click", (*) => this.OnUndoThick())

        this.myAddSeparator()

        this.myCbRounded := this.Gui.Add("CheckBox", "xm y+" this.Ygap " h22 vUseRoundedCorners", "Rounded Corners")
        this.myCbRounded.Value := this.origRounded
        this.myCbRounded.OnEvent("Click", (ctrl, *) => this.OnRoundedChange())
        this.myBtnUndoRounded := this.mySmallButton()
        this.myBtnUndoRounded.OnEvent("Click", (*) => this.OnUndoRounded())

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+5", "Transparency (0.0 - 1.0):")
        this.myTransEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w60 vTransparency", Format("{:.2f}", this.Config.Transparency))
        this.myTransUD := this.Gui.Add("UpDown", "-2 Range0-20", Round(this.Config.Transparency / 0.05))
        this.myTransUD.OnEvent("Change", (ctrl, *) => this.OnTransChange(ctrl))

        this.myBtnUndoTrans := this.mySmallButton()
        this.myBtnUndoTrans.OnEvent("Click", (*) => this.OnUndoTrans())

        this.WheelBound := (wParam, _1, _2, hwnd, *) => this.HandleMouseWheel(wParam, hwnd)
        OnMessage(0x020A, this.WheelBound)

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+" this.Ygap, "Border Color:")
        this.myColorEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w60 vBorderColor", this.origColor)
        this.myColorEdit.LastGood := this.origColor

        this.MoveBound := (_1, _2, _3, hwnd, *) => this.HandleMouseMove(hwnd)
        OnMessage(0x0200, this.MoveBound)

        this.myColorEdit.OnEvent("Change", (ctrl, *) => this.OnColorChange(ctrl))

        myBtnPicker := this.mySmallButton("🎨", "Manual color selection")
        myBtnPicker.OnEvent("Click", (*) => this.myTogglePicker())

        myBtnDrop := this.mySmallButton("💉", "Screen color sampler")
        myBtnDrop.OnEvent("Click", (*) => this.OnColorDrop())
        this.myBtnUndoColor := this.mySmallButton()
        this.myBtnUndoColor.OnEvent("Click", (*) => this.OnUndoColor())

        this.myAddSeparator()

        this.myCbAutostart := this.Gui.Add("CheckBox", "xm y+" this.Ygap " h22 vAutostart", "Enable Autostart")
        this.myCbAutostart.Value := this.origAutostart
        this.myCbAutostart.OnEvent("Click", (ctrl, *) => this.CheckUndoStates())
        this.myBtnUndoAutostart := this.mySmallButton()
        this.myBtnUndoAutostart.OnEvent("Click", (*) => this.OnUndoAutostart())

        this.myAddSeparator()

        btnSave := this.Gui.Add("Button", "xm y+" this.Ygap " w60 Default", "Save")
        btnSave.OnEvent("Click", (*) => this.mySaveSettings())
        btnCancel := this.Gui.Add("Button", "x+10 yp w60", "Cancel")
        btnCancel.OnEvent("Click", (*) => this.myCleanupAndDestroy())

        this.CheckUndoStates()

        this.Gui.Show("AutoSize Hide")
        this.Gui.GetClientPos(&_x, &_y, &baseCW, &baseCH)
        this.baseCW := baseCW, this.baseCH := baseCH

        bgW := this.picW + 2
        bgH := this.picH + 2


        ; --- SEKCYJNY COLOR PICKER GDI ---
        this.lblSpec := this.Gui.Add("Text", "ym Section Hidden", "Spectrum:")
        this.FrameSpec := this.Gui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picSpec := this.Gui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSpec := this.Gui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSpec.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSpec))

        this.lblSat := this.Gui.Add("Text", "xs y+10 Hidden", "Saturation:")
        this.FrameSat := this.Gui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picSat := this.Gui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSat := this.Gui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSat.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSat))

        this.lblLum := this.Gui.Add("Text", "xs y+10 h22 +0x0200 Hidden", "Luminance:")
        this.btnLumR := this.mySmallButton("M", "Reset luminance")
        this.btnLumR.OnEvent("Click", (*) => this.myResetLuminance())
        this.FrameLum := this.Gui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picLum := this.Gui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indLum := this.Gui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picLum.OnEvent("Click", (*) => this.myOnSliderInteract(this.picLum))

        this.myApplyRoundedRegion(this.FrameSpec, bgW, bgH, true)
        this.myApplyRoundedRegion(this.picSpec, this.picW, this.picH)
        this.myApplyRoundedRegion(this.FrameSat, bgW, bgH, true)
        this.myApplyRoundedRegion(this.picSat, this.picW, this.picH)
        this.myApplyRoundedRegion(this.FrameLum, bgW, bgH, true)
        this.myApplyRoundedRegion(this.picLum, this.picW, this.picH)

        this.mySyncSlidersFromHex(this.origColor != "" ? this.origColor : myGetThemeColor())

        this.myApplyIndicatorRegion(this.indSpec)
        this.myApplyIndicatorRegion(this.indSat)
        this.myApplyIndicatorRegion(this.indLum)
        this.Gui.Show("AutoSize Hide")
        this.Gui.Show("w" this.baseCW " h" this.baseCH)
    }

    myApplyRoundedRegion(ctrl, logicalW, logicalH, toBottom := false) {
        dpiScale := A_ScreenDPI / 96
        w := Round(logicalW * dpiScale)
        h := Round(logicalH * dpiScale)
        radius := Round(6 * dpiScale)
        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", radius, "Int", radius, "Ptr")
        if (!DllCall("SetWindowRgn", "Ptr", ctrl.Hwnd, "Ptr", hRgn, "Int", 1))
            DllCall("DeleteObject", "Ptr", hRgn)
        if (toBottom)
            DllCall("SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003) ; HWND_BOTTOM = 1
    }

    mySmallButton(symbol := "↩", customTip := "Undo changes") {
        btn := this.Gui.Add("Button", "x+2 yp w22 h22", symbol)
        if (customTip != "")
            btn.myCustomTooltip := customTip
        return btn
    }

    myAddSeparator() {
        this.Gui.Add("Text", "xm-5 ym y+" this.Ygap " h1 w140 Background" . this.grayColor)
    }

    myApplyIndicatorRegion(ctrl) {
        dpiScale := A_ScreenDPI / 96
        w := Round(this.indW * dpiScale)
        h := Round(this.indH * dpiScale)
        arrowH := Round(this.indCutHeight * dpiScale)
        hRgnTop := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", arrowH, "Ptr")
        hRgnBottom := DllCall("CreateRectRgn", "Int", 0, "Int", h - arrowH, "Int", w, "Int", h, "Ptr")
        DllCall("CombineRgn", "Ptr", hRgnTop, "Ptr", hRgnTop, "Ptr", hRgnBottom, "Int", 2)
        if (!DllCall("SetWindowRgn", "Ptr", ctrl.Hwnd, "Ptr", hRgnTop, "Int", 1))
            DllCall("DeleteObject", "Ptr", hRgnTop)
        DllCall("DeleteObject", "Ptr", hRgnBottom)
        DllCall("SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003) ; HWND_TOP
    }

    myTogglePicker() {
        this.PickerVisible := !this.PickerVisible
        w := 180, h := 20
        if (this.PickerVisible) {
            this.myUpdateColorSpace(true)
            this.lblSpec.Visible := true, this.FrameSpec.Visible := true, this.picSpec.Visible := true, this.indSpec.Visible := true
            this.lblSat.Visible := true, this.FrameSat.Visible := true, this.picSat.Visible := true, this.indSat.Visible := true
            this.lblLum.Visible := true, this.FrameLum.Visible := true, this.picLum.Visible := true, this.indLum.Visible := true, this.btnLumR.Visible := true
            this.Gui.Show("AutoSize")
        } else {
            this.lblSpec.Visible := false, this.FrameSpec.Visible := false, this.picSpec.Visible := false, this.indSpec.Visible := false
            this.lblSat.Visible := false, this.FrameSat.Visible := false, this.picSat.Visible := false, this.indSat.Visible := false
            this.lblLum.Visible := false, this.FrameLum.Visible := false, this.picLum.Visible := false, this.indLum.Visible := false, this.btnLumR.Visible := false
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
                this.myUpdateColorSpace()

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
        sr := Round(szary + (this.HueBaseR - szary) * this.SatRatio)
        sg := Round(szary + (this.HueBaseG - szary) * this.SatRatio)
        sb := Round(szary + (this.HueBaseB - szary) * this.SatRatio)

        if (!fastTrack) {
            if (firstRender || this.lastHue != hue || this.lastLumForSat != this.LumRatio) {
                lumR := (this.LumRatio < 0.5) ? Round(this.HueBaseR * (this.LumRatio / 0.5)) : Round(this.HueBaseR + (255 - this.HueBaseR) * ((this.LumRatio - 0.5) / 0.5))
                lumG := (this.LumRatio < 0.5) ? Round(this.HueBaseG * (this.LumRatio / 0.5)) : Round(this.HueBaseG + (255 - this.HueBaseG) * ((this.LumRatio - 0.5) / 0.5))
                lumB := (this.LumRatio < 0.5) ? Round(this.HueBaseB * (this.LumRatio / 0.5)) : Round(this.HueBaseB + (255 - this.HueBaseB) * ((this.LumRatio - 0.5) / 0.5))
                hBM2 := this.GradientEngine.myRenderSaturation(bufferW, this.picH, lumR, lumG, lumB)
                this.GradientEngine.myApplyBitmap(this.picSat.Hwnd, hBM2)
                this.lastHue := hue
                this.lastLumForSat := this.LumRatio
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
            fr := Round(sr * p)
            fg := Round(sg * p)
            fb := Round(sb * p)
        } else {
            p := (i - 0.5) / 0.5
            fr := Round(sr + (255 - sr) * p)
            fg := Round(sg + (255 - sg) * p)
            fb := Round(sb + (255 - sb) * p)
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
        this.Renderer.myApplyBorderRegion(ctrl.Value, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.myCbRounded.Value)
        this.CheckUndoStates()
    }

    OnUndoThick(*) {
        this.myThickEdit.Value := this.origThick
        this.Renderer.myApplyBorderRegion(this.origThick, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.myCbRounded.Value)
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

    OnRoundedChange(*) {
        this.Renderer.myApplyBorderRegion(this.myThickUD.Value, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.myCbRounded.Value)
        this.CheckUndoStates()
    }

    OnUndoRounded(*) {
        this.myCbRounded.Value := this.origRounded
        this.Renderer.myApplyBorderRegion(this.myThickUD.Value, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.myCbRounded.Value)
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

        SetTimer(this.HoverTipBound, 0)
        ToolTip()

        tryCtrl := ""
        try tryCtrl := GuiCtrlFromHwnd(hwnd)

        tipText := ""
        if (tryCtrl && tryCtrl.HasOwnProp("myCustomTooltip"))
            tipText := tryCtrl.myCustomTooltip
        else if (hwnd == this.myColorEdit.Hwnd)
            tipText := "HEX value or empty for auto-theme."

        if (tipText != "") {
            this.CurrentTip := tipText
            SetTimer(this.HoverTipBound, -400)
        }
    }

    ShowHoverTip() {
        ToolTip(this.CurrentTip)
    }

    CheckUndoStates(*) {
        this.myBtnUndoThick.Enabled := (this.myThickUD.Value != this.origThick)
        this.myBtnUndoTrans.Enabled := (this.myTransEdit.Value != this.origTrans)
        this.myBtnUndoColor.Enabled := (this.myColorEdit.Value != this.origColor)
        this.myBtnUndoAutostart.Enabled := (this.myCbAutostart.Value != this.origAutostart)
        this.myBtnUndoRounded.Enabled := (this.myCbRounded.Value != this.origRounded)
    }

    mySaveSettings(*) {
        mySaved := this.Gui.Submit()
        this.Config.mySaveData(mySaved.BorderThickness, mySaved.Transparency, mySaved.BorderColor, mySaved.Autostart, mySaved.UseRoundedCorners, this.Config.CornersRadius)
        Reload()
    }

    myCleanupAndDestroy(*) {
        this.Renderer.IsConfigMode := false
        OnMessage(0x020A, this.WheelBound, 0)
        try OnMessage(0x0200, this.MoveBound, 0)
        ToolTip()

        this.GradientEngine.myApplyBitmap(this.picSpec.Hwnd, 0)
        this.GradientEngine.myApplyBitmap(this.picSat.Hwnd, 0)
        this.GradientEngine.myApplyBitmap(this.picLum.Hwnd, 0)
        this.GradientEngine.myApplyBitmap(this.indSpec.Hwnd, 0)
        this.GradientEngine.myApplyBitmap(this.indSat.Hwnd, 0)
        this.GradientEngine.myApplyBitmap(this.indLum.Hwnd, 0)

        DllCall("SetWindowRgn", "Ptr", this.FrameSpec.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.picSpec.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.FrameSat.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.picSat.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.FrameLum.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.picLum.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.indSpec.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.indSat.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("SetWindowRgn", "Ptr", this.indLum.Hwnd, "Ptr", 0, "Int", 0)

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