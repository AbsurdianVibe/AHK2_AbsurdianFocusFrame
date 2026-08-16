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
 * Resolves the provided hex string. Returns the system theme color if empty.
 * @param {String} hex - Optional hex color string (e.g. "FF0000").
 * @returns {String} Resolved hex color string.
 */
myResolveColor(hex) {
    return (hex != "") ? hex : myGetThemeColor()
}

/**
 * Converts RGB components to perceived grayscale (Luma).
 * @param {Number} r - Red channel (0-255).
 * @param {Number} g - Green channel (0-255).
 * @param {Number} b - Blue channel (0-255).
 * @returns {Number} Grayscale value (0-255).
 */
myRgbToGrayscale(r, g, b) {
    return Round((r * 0.299) + (g * 0.587) + (b * 0.114))
}

/**
 * Lightens or darkens the given color based on the luminance ratio.
 * @param {Number} r - Red channel.
 * @param {Number} g - Green channel.
 * @param {Number} b - Blue channel.
 * @param {Number} ratio - Luminance ratio (0.0 = Black, 0.5 = Original, 1.0 = White).
 * @returns {Map} Map with r, g, b keys (0-255).
 */
myMixLuminance(r, g, b, ratio) {
    if (ratio < 0.5) {
        p := ratio / 0.5
        return { r: Round(r * p), g: Round(g * p), b: Round(b * p) }
    } else {
        p := (ratio - 0.5) / 0.5
        return { r: Round(r + (255 - r) * p), g: Round(g + (255 - g) * p), b: Round(b + (255 - b) * p) }
    }
}


/**
 * Converts HSV color model to RGB.
 * @param {Number} h - Hue (0-359).
 * @param {Number} s - Saturation (0.0-1.0).
 * @param {Number} v - Value/Brightness (0.0-1.0).
 * @returns {Map} Map with r, g, b keys (0-255).
 */
myHsvToRgb(h, s, v) {
    i := Floor(h / 60)
    f := h / 60 - i
    p := v * (1 - s)
    q := v * (1 - f * s)
    t := v * (1 - (1 - f) * s)

    switch Mod(i, 6) {
        case 0: r := v, g := t, b := p
        case 1: r := q, g := v, b := p
        case 2: r := p, g := v, b := t
        case 3: r := p, g := q, b := v
        case 4: r := t, g := p, b := v
        case 5: r := v, g := p, b := q
    }

    return { r: Round(r * 255), g: Round(g * 255), b: Round(b * 255) }
}

/**
 * Converts a HEX string to an RGB map.
 * @param {String} hex - Hex color string (e.g. "FF0000").
 * @returns {Map} Map with r, g, b keys (0-255).
 */
myHexToRgb(hex) {
    return {
        r: Integer("0x" . SubStr(hex, 1, 2)),
        g: Integer("0x" . SubStr(hex, 3, 2)),
        b: Integer("0x" . SubStr(hex, 5, 2))
    }
}

/**
 * Converts a HEX string to an HSL map for slider synchronization.
 * @param {String} hexColor - Hex color string.
 * @returns {Map} Map with h, s, l keys.
 */
myHexToHsl(hexColor) {
    hexColor := StrReplace(hexColor, "#")
    if (StrLen(hexColor) != 6)
        return { h: 0, s: 1, l: 0.5 }
    r := Integer("0x" SubStr(hexColor, 1, 2)) / 255
    g := Integer("0x" SubStr(hexColor, 3, 2)) / 255
    b := Integer("0x" SubStr(hexColor, 5, 2)) / 255

    maxC := Max(r, g, b)
    minC := Min(r, g, b)
    l := (maxC + minC) / 2

    if (maxC == minC) {
        h := 0
        s := 0
    } else {
        d := maxC - minC
        s := (l > 0.5) ? d / (2 - maxC - minC) : d / (maxC + minC)
        if (maxC == r)
            h := (g - b) / d + (g < b ? 6 : 0)
        else if (maxC == g)
            h := (b - r) / d + 2
        else
            h := (r - g) / d + 4
        h /= 6
    }
    return { h: h, s: s, l: l }
}

/**
 * Starts screen color picking mode.
 * @param {Object} [renderEngine=""] - Optional RenderEngine reference to update live preview.
 * @returns {String} Picked hex color.
 */
myPickColorFromScreen(renderEngine := "") {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")

    KeyWait("LButton", "U")

    Hotkey("*LButton", (*) => "", "On")
    Hotkey("*RButton", (*) => "", "On")

    myScreenX := SysGet(76)
    myScreenY := SysGet(77)
    myScreenW := SysGet(78)
    myScreenH := SysGet(79)
    ShieldGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    ShieldGui.BackColor := "Black"
    ShieldGui.Show("NoActivate x" myScreenX " y" myScreenY " w" myScreenW " h" myScreenH)
    WinSetTransparent(1, ShieldGui.Hwnd)

    CrossCursor := DllCall("LoadCursor", "Ptr", 0, "Int", 32515, "Ptr")
    CrossCursorCopy := DllCall("CopyImage", "Ptr", CrossCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
    DllCall("SetSystemCursor", "Ptr", CrossCursorCopy, "Int", 32512)


    SetTimer(() => myShowCenteredTooltip("Click anywhere to pick a color.`nPress ESC or Right-Click to cancel."), -100)
    lastC := ""
    chosenC := ""
    while true {
        MouseGetPos(&mX, &mY)
        c := PixelGetColor(mX, mY)
        hexC := StrReplace(c, "0x", "")
        if (hexC != lastC) {
            lastC := hexC
            if (renderEngine)
                try renderEngine.FocusGui.BackColor := hexC
        }

        if GetKeyState("LButton", "P") {
            ToolTip()
            ShieldGui.Hide()
            Sleep(50)
            MouseGetPos(&mX, &mY)
            c := PixelGetColor(mX, mY)
            chosenC := StrReplace(c, "0x", "")
            KeyWait("LButton", "U")
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
    ShieldGui.Destroy()
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)

    return chosenC
}