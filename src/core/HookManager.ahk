class myHookManager {
    /** @type {myRenderEngine} */
    Renderer := ""
    /** @type {myConfigManager} */
    Config := ""

    /**
     * @param {myRenderEngine} renderEngine
     * @param {myConfigManager} configManager
     */
    __New(renderEngine, configManager) {
        this.Renderer := renderEngine
        this.Config := configManager

        this.ThemeChangeBound := (_1, lParam, *) => this.myThemeChangeHook(lParam)
        OnMessage(0x001A, this.ThemeChangeBound)

        this.HideBorderBound := (_1, _2, hwnd, *) => this.HideNativeBorderEvent(hwnd)
        this.FocusHook := DllCall("SetWinEventHook", "UInt", 0x8005, "UInt", 0x8009, "Ptr", 0, "Ptr", CallbackCreate(this.HideBorderBound, "F", 7), "UInt", 0, "UInt", 0, "UInt", 0)
    }

    myThemeChangeHook(lParam) {
        local targetParam := ""
        try targetParam := StrGet(lParam)
        if (targetParam = "ImmersiveColorSet") {
            if (IniRead(this.Config.IniPath, "Settings", "BorderColor", "") == "") {
                this.Config.BorderColor := myGetThemeColor()
                this.Renderer.myUpdateAppearance()
            }
        }
    }

    HideNativeBorderEvent(hwnd) {
        if hwnd
            try PostMessage(0x0128, 0x00010001, 0, , "ahk_id " hwnd)
        this.Renderer.myStartWatchdog(hwnd)
    }
}
