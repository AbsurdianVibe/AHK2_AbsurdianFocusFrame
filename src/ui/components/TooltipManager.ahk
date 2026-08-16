class myTooltipManager {
    __New() {
        this.CurrentTip := ""
        this.HoverTipBound := () => myShowCenteredTooltip(this.CurrentTip)
        this.MoveBound := (_1, _2, _3, hwnd, *) => this.HandleMouseMove(hwnd)
    }

    myEnable() {
        OnMessage(0x0200, this.MoveBound)
    }

    myDisable() {
        try OnMessage(0x0200, this.MoveBound, 0)
        SetTimer(this.HoverTipBound, 0)
        ToolTip()
    }

    myStopTimer() {
        SetTimer(this.HoverTipBound, 0)
        ToolTip()
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

        if (tipText != "") {
            this.CurrentTip := tipText
            SetTimer(this.HoverTipBound, -400)
        }
    }
}

/**
 * Shows a centered tooltip using Double-Render technique.
 * It forces the system to calculate geometry and applies the offset.
 * It handles DPI scaling automatically.
 * 
 * @param {String} tipText - Tooltip text. If empty, hides the tooltip.
 * @param {String|Number} [targetX=""] - X axis. Empty = mouse X position.
 * @param {String|Number} [targetY=""] - Y axis. Empty = mouse Y position.
 * @param {Number} [offsetY=20] - Vertical offset to avoid cursor overlap.
 */
myShowCenteredTooltip(tipText, targetX := "", targetY := "", offsetY := 20) {
    if (tipText == "") {
        ToolTip()
        return
    }

    if (targetX == "" || targetY == "") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mX, &mY)
        targetX := (targetX == "") ? mX : targetX
        targetY := (targetY == "") ? mY : targetY
    }

    dpiScale := A_ScreenDPI / 96
    finalY := targetY + (offsetY * dpiScale)

    CoordMode("ToolTip", "Screen")
    ToolTip(tipText, -9999, -9999)

    try {
        WinGetPos(, , &ttW, , "ahk_class tooltips_class32")
        ToolTip(tipText, targetX - (ttW / 2), finalY)
    } catch {
        ToolTip(tipText, targetX, finalY)
    }
}