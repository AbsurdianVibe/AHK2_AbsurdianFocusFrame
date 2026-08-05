class myConfigManager {
    __New(iniPath) {
        this.IniPath := iniPath
        if !FileExist(this.IniPath) {
            IniWrite(2, this.IniPath, "Settings", "BorderThickness")
            IniWrite(0.5, this.IniPath, "Settings", "Transparency")
            IniWrite("", this.IniPath, "Settings", "BorderColor")
            IniWrite(0, this.IniPath, "Settings", "Autostart")
        }
        this.BorderThickness := Integer(IniRead(this.IniPath, "Settings", "BorderThickness", 2))
        this.Transparency := Float(IniRead(this.IniPath, "Settings", "Transparency", 0.5))
        this.BorderColor := IniRead(this.IniPath, "Settings", "BorderColor", "")
        this.Autostart := Integer(IniRead(this.IniPath, "Settings", "Autostart", 0))

        if (this.BorderColor == "")
            this.BorderColor := myGetThemeColor()
    }

    mySaveData(thick, trans, color, auto) {
        IniWrite(thick, this.IniPath, "Settings", "BorderThickness")
        IniWrite(trans, this.IniPath, "Settings", "Transparency")
        IniWrite(color, this.IniPath, "Settings", "BorderColor")
        IniWrite(auto, this.IniPath, "Settings", "Autostart")
        this.BorderThickness := thick
        this.Transparency := trans
        this.BorderColor := color
        this.Autostart := auto
    }

    mySetupAutostart() {
        if A_IsCompiled {
            ShortcutPath := A_Startup "\AbsurdianFocusFrame.lnk"
            if this.Autostart && !FileExist(ShortcutPath) {
                try FileCreateShortcut(A_ScriptFullPath, ShortcutPath, A_ScriptDir)
            } else if !this.Autostart && FileExist(ShortcutPath) {
                try FileDelete(ShortcutPath)
            }
        }
    }
}
