class myRenderEngine {
    /** @type {myConfigManager} */
    Config := ""

    /**
     * @param {myConfigManager} configManager
     */
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

        this.WatchdogBound := (*) => this.RenderWatchdog()
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
