class myConfigManager {
    __New(iniPath) {
        this.IniPath := iniPath
        if !FileExist(this.IniPath) {
            IniWrite(2, this.IniPath, "Settings", "BorderThickness")
            IniWrite(0.5, this.IniPath, "Settings", "Transparency")
            IniWrite("", this.IniPath, "Settings", "BorderColor")
            IniWrite(1, this.IniPath, "Settings", "UseRoundedCorners")
            IniWrite(3, this.IniPath, "Settings", "CornersRadius")
        }
        this.BorderThickness := Integer(IniRead(this.IniPath, "Settings", "BorderThickness", 2))
        this.Transparency := Float(IniRead(this.IniPath, "Settings", "Transparency", 0.5))
        this.BorderColor := IniRead(this.IniPath, "Settings", "BorderColor", "")
        this.Autostart := FileExist(A_Startup "\AbsurdianFocusFrame.lnk") ? 1 : 0
        this.UseRoundedCorners := Integer(IniRead(this.IniPath, "Settings", "UseRoundedCorners", 1))
        this.CornersRadius := Integer(IniRead(this.IniPath, "Settings", "CornersRadius", 5))

        if (this.BorderColor == "")
            this.BorderColor := myGetThemeColor()
    }

    mySaveData(thick, trans, color, auto, rounded, radius) {
        IniWrite(thick, this.IniPath, "Settings", "BorderThickness")
        IniWrite(trans, this.IniPath, "Settings", "Transparency")
        IniWrite(color, this.IniPath, "Settings", "BorderColor")
        IniWrite(rounded, this.IniPath, "Settings", "UseRoundedCorners")
        IniWrite(radius, this.IniPath, "Settings", "CornersRadius")
        this.BorderThickness := thick
        this.Transparency := trans
        this.BorderColor := color
        this.Autostart := auto
        this.UseRoundedCorners := rounded
        this.CornersRadius := radius
    }

    mySetupAutostart() {
        if A_IsCompiled {
            ShortcutPath := A_Startup "\AbsurdianFocusFrame.lnk"
            if this.Autostart && !FileExist(ShortcutPath) {
                try FileCreateShortcut(A_ScriptFullPath, ShortcutPath, A_ScriptDir, "myAutostart")
            } else if !this.Autostart && FileExist(ShortcutPath) {
                try FileDelete(ShortcutPath)
            }
        }
    }
}