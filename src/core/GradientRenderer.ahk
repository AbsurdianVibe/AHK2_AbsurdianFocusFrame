class myGradientRenderer {
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
                p := i / 0.5,
                { r: Round(255 + (r - 255) * p), g: Round(255 + (g - 255) * p), b: Round(255 + (b - 255) * p) }
            ) : (
                p := (i - 0.5) / 0.5,
                { r: Round(r * (1 - p)), g: Round(g * (1 - p)), b: Round(b * (1 - p)) }
            )
        ))
    }

    myRenderSaturation(w, h, r, g, b) {
        szary := Round((r * 0.299) + (g * 0.587) + (b * 0.114))
        return this.myRenderHorizontalGradient(w, h, (x, width) => (
            i := (x / (width - 1)),
            { r: Round(r + (szary - r) * i), g: Round(g + (szary - g) * i), b: Round(b + (szary - b) * i) }
        ))
    }
}
