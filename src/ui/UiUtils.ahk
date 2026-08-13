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