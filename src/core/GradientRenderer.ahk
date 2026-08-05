class myGradientRenderer {
    __New() {
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(16, 0)
        NumPut("UInt", 1, si)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
        this.pToken := token
    }

    __Delete() {
        if this.pToken
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.pToken)
    }

    myInitBitmap(w, h) {
        bmi := Buffer(40, 0)
        NumPut("UInt", 40, bmi, 0), NumPut("Int", w, bmi, 4), NumPut("Int", -h, bmi, 8)
        NumPut("UShort", 1, bmi, 12), NumPut("UShort", 32, bmi, 14)
        pBits := 0
        hBM := DllCall("CreateDIBSection", "Ptr", 0, "Ptr", bmi, "UInt", 0, "Ptr*", &pBits, "Ptr", 0, "UInt", 0, "Ptr")
        return { ptr: pBits, hbm: hBM }
    }

    myApplyBitmap(ctrlHwnd, hBM) {
        hOld := SendMessage(0x172, 0, hBM, ctrlHwnd)
        if (hOld)
            DllCall("DeleteObject", "Ptr", hOld)
    }

    myRenderHorizontalGradient(w, h, colorCallback) {
        dane := this.myInitBitmap(w, h)
        Loop w {
            x := A_Index - 1
            col := colorCallback(x, w)
            Loop h {
                y := A_Index - 1
                offset := (y * w + x) * 4
                NumPut("UChar", col.b, dane.ptr, offset)
                NumPut("UChar", col.g, dane.ptr, offset + 1)
                NumPut("UChar", col.r, dane.ptr, offset + 2)
            }
        }
        return dane.hbm
    }

    myRenderSpectrum(w, h) {
        return this.myRenderHorizontalGradient(w, h, (x, width) => (
            hue := (x / (width - 1)) * 359,
            myHsvToRgb(hue, 1, 1)
        ))
    }

    myRenderLuminance(w, h, r, g, b) {
        return this.myRenderHorizontalGradient(w, h, (x, width) => (
            i := (x / (width - 1)),
            (i < 0.5) ? (
                p := i / 0.5, { r: Round(255 + (r - 255) * p), g: Round(255 + (g - 255) * p), b: Round(255 + (b - 255) * p) }
            ) : (
                p := (i - 0.5) / 0.5, { r: Round(r * (1 - p)), g: Round(g * (1 - p)), b: Round(b * (1 - p)) }
            )
        ))
    }

    myRenderSaturation(w, h, r, g, b) {
        szary := Round((r * 0.299) + (g * 0.587) + (b * 0.114))
        return this.myRenderHorizontalGradient(w, h, (x, width) => (
            i := (x / (width - 1)), { r: Round(r + (szary - r) * i), g: Round(g + (szary - g) * i), b: Round(b + (szary - b) * i) }
        ))
    }

    myRenderIndicatorArrows(w, h, scale := 1.0) {
        realW := Round(w * scale)
        realH := Round(h * scale)

        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", realW, "Int", realH, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)

        pGraphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4) ; AntiAlias

        myColorHex := "#454545"
        myArgbFill := Integer("0xFF" . StrReplace(myColorHex, "#", ""))
        pBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", myArgbFill, "Ptr*", &pBrush)

        cx := realW / 2
        arrowSize := 5 * scale

        cut := 2.0 * scale

        pointsTop := Buffer(40, 0)
        NumPut("Float", cx - arrowSize + cut, pointsTop, 0)
        NumPut("Float", 0, pointsTop, 4)
        NumPut("Float", cx - arrowSize + cut, pointsTop, 8)
        NumPut("Float", cut, pointsTop, 12)
        NumPut("Float", cx, pointsTop, 16)
        NumPut("Float", arrowSize, pointsTop, 20)
        NumPut("Float", cx + arrowSize - cut, pointsTop, 24)
        NumPut("Float", cut, pointsTop, 28)
        NumPut("Float", cx + arrowSize - cut, pointsTop, 32)
        NumPut("Float", 0, pointsTop, 36)
        DllCall("gdiplus\GdipFillPolygon", "Ptr", pGraphics, "Ptr", pBrush, "Ptr", pointsTop, "Int", 5, "Int", 0)

        pointsBot := Buffer(40, 0)
        NumPut("Float", cx - arrowSize + cut, pointsBot, 0)
        NumPut("Float", realH, pointsBot, 4)
        NumPut("Float", cx - arrowSize + cut, pointsBot, 8)
        NumPut("Float", realH - cut, pointsBot, 12)
        NumPut("Float", cx, pointsBot, 16)
        NumPut("Float", realH - arrowSize, pointsBot, 20)
        NumPut("Float", cx + arrowSize - cut, pointsBot, 24)
        NumPut("Float", realH - cut, pointsBot, 28)
        NumPut("Float", cx + arrowSize - cut, pointsBot, 32)
        NumPut("Float", realH, pointsBot, 36)
        DllCall("gdiplus\GdipFillPolygon", "Ptr", pGraphics, "Ptr", pBrush, "Ptr", pointsBot, "Int", 5, "Int", 0)

        hbm := 0
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hbm, "UInt", 0)

        DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

        return hbm
    }
}