class myColorPickerWidget {
    __New(parentGui, gradientEngine, grayColor, picW, picH, indW, indH, indCutHeight, gdiScale) {
        this.parentGui := parentGui
        this.GradientEngine := gradientEngine
        this.picW := picW, this.picH := picH
        this.indW := indW, this.indH := indH
        this.gdiScale := gdiScale
        this.grayColor := grayColor
        this.indCutHeight := indCutHeight

        this.HueRatio := 0.0
        this.SatRatio := 1.0
        this.LumRatio := 0.5
        this.HueBaseR := 255
        this.HueBaseG := 0
        this.HueBaseB := 0
        this.lastHue := -1
        this.lastSat := -1
        this.lastHueLum := -1
        this.lastLumForSat := -1
        this.PickerVisible := false

        this.OnColorChange := ""

        bgW := this.picW + 2
        bgH := this.picH + 2

        this.lblSpec := this.parentGui.Add("Text", "ym Section Hidden", "Spectrum:")
        this.FrameSpec := this.parentGui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picSpec := this.parentGui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSpec := this.parentGui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSpec.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSpec))

        this.lblSat := this.parentGui.Add("Text", "xs y+10 Hidden", "Saturation:")
        this.FrameSat := this.parentGui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picSat := this.parentGui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indSat := this.parentGui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picSat.OnEvent("Click", (*) => this.myOnSliderInteract(this.picSat))

        this.lblLum := this.parentGui.Add("Text", "xs y+10 h22 +0x0200 Hidden", "Luminance:")
        this.btnLumR := mySmallButton(this.parentGui, "M", "Reset luminance")
        this.btnLumR.OnEvent("Click", (*) => this.myResetLuminance())
        this.FrameLum := this.parentGui.Add("Text", "xs y+8 w" bgW " h" bgH " +Background" . this.grayColor . " +0x04000000 Hidden")
        this.picLum := this.parentGui.Add("Picture", "xp+1 yp+1 w" this.picW " h" this.picH " +0x0100 +0xE +0x0040 +0x04000000 Hidden")
        this.indLum := this.parentGui.Add("Picture", "xp-1 yp-1 w" this.indW " h" this.indH " +0x04000000 Hidden +0xE +BackgroundTrans")
        this.picLum.OnEvent("Click", (*) => this.myOnSliderInteract(this.picLum))

        myApplyRoundedRegion(this.FrameSpec, bgW, bgH, true)
        myApplyRoundedRegion(this.picSpec, this.picW, this.picH)
        myApplyRoundedRegion(this.FrameSat, bgW, bgH, true)
        myApplyRoundedRegion(this.picSat, this.picW, this.picH)
        myApplyRoundedRegion(this.FrameLum, bgW, bgH, true)
        myApplyRoundedRegion(this.picLum, this.picW, this.picH)

        myApplyIndicatorRegion(this.indSpec, this.indW, this.indH, this.indCutHeight)
        myApplyIndicatorRegion(this.indSat, this.indW, this.indH, this.indCutHeight)
        myApplyIndicatorRegion(this.indLum, this.indW, this.indH, this.indCutHeight)
    }

    mySetVisibility(visible) {
        this.PickerVisible := visible
        this.lblSpec.Visible := visible, this.FrameSpec.Visible := visible, this.picSpec.Visible := visible, this.indSpec.Visible := visible
        this.lblSat.Visible := visible, this.FrameSat.Visible := visible, this.picSat.Visible := visible, this.indSat.Visible := visible
        this.lblLum.Visible := visible, this.FrameLum.Visible := visible, this.picLum.Visible := visible, this.indLum.Visible := visible, this.btnLumR.Visible := visible
        if (visible)
            this.myUpdateColorSpace(true)
    }

    myResetLuminance(*) {
        this.LumRatio := 0.5
        this.myUpdateColorSpace()
    }

    HandleMouseWheel(hwnd, dir) {
        if (!this.PickerVisible)
            return false
        if (hwnd == this.picSpec.Hwnd) {
            this.myOnSliderInteract(this.picSpec, dir)
            return true
        }
        if (hwnd == this.picSat.Hwnd) {
            this.myOnSliderInteract(this.picSat, dir)
            return true
        }
        if (hwnd == this.picLum.Hwnd) {
            this.myOnSliderInteract(this.picLum, dir)
            return true
        }
        return false
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

        szary := myRgbToGrayscale(this.HueBaseR, this.HueBaseG, this.HueBaseB)
        sr := Round(szary + (this.HueBaseR - szary) * this.SatRatio)
        sg := Round(szary + (this.HueBaseG - szary) * this.SatRatio)
        sb := Round(szary + (this.HueBaseB - szary) * this.SatRatio)

        if (!fastTrack) {
            if (firstRender || this.lastHue != hue || this.lastLumForSat != this.LumRatio) {
                mix := myMixLuminance(this.HueBaseR, this.HueBaseG, this.HueBaseB, this.LumRatio)
                hBM2 := this.GradientEngine.myRenderSaturation(bufferW, this.picH, mix.r, mix.g, mix.b)
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

        mixFinal := myMixLuminance(sr, sg, sb, this.LumRatio)
        hex := Format("{:02x}{:02x}{:02x}", mixFinal.r, mixFinal.g, mixFinal.b)
        if (!firstRender && this.OnColorChange != "") {
            cb := this.OnColorChange
            cb(hex)
        }
    }

    mySyncSlidersFromHex(hexStr) {
        hsl := myHexToHsl(hexStr)
        this.HueRatio := hsl.h
        this.SatRatio := hsl.s
        this.LumRatio := hsl.l
        if (this.PickerVisible)
            this.myUpdateColorSpace(true)
    }

    myCleanup() {
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
    }
}


/**
 * Applies a rounded rectangular region to a control.
 * 
 * @param {Object} ctrl - Gui control object.
 * @param {Number} logicalW - Logical width of the region.
 * @param {Number} logicalH - Logical height of the region.
 * @param {Boolean} [toBottom=false] - Whether to push the control to the bottom of the Z-order.
 * @param {Number} [radius=6] - Radius of the corners.
 */
myApplyRoundedRegion(ctrl, logicalW, logicalH, toBottom := false, radius := 6) {
    dpiScale := A_ScreenDPI / 96
    w := Round(logicalW * dpiScale)
    h := Round(logicalH * dpiScale)
    scaledRadius := Round(radius * dpiScale)
    hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", scaledRadius, "Int", scaledRadius, "Ptr")
    if (!DllCall("SetWindowRgn", "Ptr", ctrl.Hwnd, "Ptr", hRgn, "Int", 1))
        DllCall("DeleteObject", "Ptr", hRgn)
    if (toBottom)
        DllCall("SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003) ; HWND_BOTTOM = 1
}

/**
 * Applies an indicator region (cut arrows at top and bottom) to a control.
 * 
 * @param {Object} ctrl - Gui control object.
 * @param {Number} indW - Indicator logical width.
 * @param {Number} indH - Indicator logical height.
 * @param {Number} indCutHeight - Height of the cut for the arrow.
 */
myApplyIndicatorRegion(ctrl, indW, indH, indCutHeight) {
    dpiScale := A_ScreenDPI / 96
    w := Round(indW * dpiScale)
    h := Round(indH * dpiScale)
    arrowH := Round(indCutHeight * dpiScale)
    hRgnTop := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", arrowH, "Ptr")
    hRgnBottom := DllCall("CreateRectRgn", "Int", 0, "Int", h - arrowH, "Int", w, "Int", h, "Ptr")
    DllCall("CombineRgn", "Ptr", hRgnTop, "Ptr", hRgnTop, "Ptr", hRgnBottom, "Int", 2)
    if (!DllCall("SetWindowRgn", "Ptr", ctrl.Hwnd, "Ptr", hRgnTop, "Int", 1))
        DllCall("DeleteObject", "Ptr", hRgnTop)
    DllCall("DeleteObject", "Ptr", hRgnBottom)
    DllCall("SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003) ; HWND_TOP
}