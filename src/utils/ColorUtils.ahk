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
 * Opens color selection dialog.
 * @param {String} initHex - Initial hex color.
 * @param {Integer} [hwndOwner=0] - Window owner handle.
 * @returns {String} Selected hex color.
 */
myChooseColor(initHex, hwndOwner := 0) {
    if initHex == ""
        initHex := "000000"
    try {
        initBgr := (Integer("0x" initHex) & 0xFF0000) >> 16 | (Integer("0x" initHex) & 0x00FF00) | (Integer("0x" initHex) & 0x0000FF) << 16
    } catch {
        initBgr := 0
    }
    CC := Buffer(A_PtrSize == 8 ? 72 : 36, 0)
    NumPut("UInt", CC.Size, CC, 0)
    NumPut("Ptr", hwndOwner, CC, 8)
    NumPut("UInt", initBgr, CC, A_PtrSize == 8 ? 24 : 12)
    static CustColors := Buffer(64, 0)
    NumPut("Ptr", CustColors.Ptr, CC, A_PtrSize == 8 ? 32 : 16)
    NumPut("UInt", 0x103, CC, A_PtrSize == 8 ? 40 : 20)

    if DllCall("comdlg32\ChooseColorW", "Ptr", CC.Ptr) {
        bgr := NumGet(CC, A_PtrSize == 8 ? 24 : 12, "UInt")
        rgb := (bgr & 0xFF0000) >> 16 | (bgr & 0x00FF00) | (bgr & 0x0000FF) << 16
        return Format("{:06x}", rgb)
    }
    return ""
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
