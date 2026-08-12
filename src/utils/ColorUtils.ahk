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
 * Konwertuje kolor z modelu HSV na RGB.
 * @param {Number} h - Odcień (Hue) w zakresie 0-359.
 * @param {Number} s - Nasycenie (Saturation) w zakresie 0.0-1.0.
 * @param {Number} v - Wartość/Jasność (Value) w zakresie 0.0-1.0.
 * @returns {Map} - Zwraca mapę z kluczami r, g, b (0-255).
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
 * Konwertuje ciąg HEX na obiekt RGB.
 * @param {String} hex - Ciąg koloru (np. "FF0000").
 * @returns {Map} - Map {r, g, b}.
 */
myHexToRgb(hex) {
    return {
        r: Integer("0x" . SubStr(hex, 1, 2)),
        g: Integer("0x" . SubStr(hex, 3, 2)),
        b: Integer("0x" . SubStr(hex, 5, 2))
    }
}

/**
 * Konwertuje ciąg HEX na obiekt HSL dla synchronizacji suwaków.
 * @param {String} hexColor - Ciąg koloru.
 * @returns {Map} - Zwraca mapę { h, s, l }.
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
    ToolTip("Click anywhere to pick a color.`nPress ESC or Right-Click to cancel.")

    Hotkey("*LButton", (*) => "", "On")
    Hotkey("*RButton", (*) => "", "On")
    CrossCursor := DllCall("LoadCursor", "Ptr", 0, "Int", 32515, "Ptr")
    CrossCursorCopy := DllCall("CopyImage", "Ptr", CrossCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
    DllCall("SetSystemCursor", "Ptr", CrossCursorCopy, "Int", 32512)

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
            KeyWait("LButton", "U")
            chosenC := hexC
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
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)

    return chosenC
}
