#Include "components\GDI_Render.ahk"
#Include "components\UiUtils.ahk"
#Include "components\TooltipManager.ahk"
#Include "components\ColorPickerWidget.ahk"
#Include "components\SettingsGui.ahk"

class mySettingsController {
    __New(configManager, renderEngine) {
        this.Config := configManager
        this.Renderer := renderEngine

        this.origThick := this.Config.BorderThickness
        this.origTrans := Format("{:.2f}", this.Config.Transparency)
        this.origColor := IniRead(this.Config.IniPath, "Settings", "BorderColor", "")
        this.origAutostart := this.Config.Autostart
        this.origRounded := this.Config.UseRoundedCorners

        this.GradientEngine := myGDI_Render()
        this.TooltipManager := myTooltipManager()

        this.View := mySettingsGui()

        this.Renderer.IsConfigMode := true
        this.TooltipManager.myEnable()

        this.View.myBuild(this.origThick, this.origTrans, this.origColor, this.origAutostart, this.origRounded, this.GradientEngine)

        this.WireEvents()
        this.EvaluateUndoStates()
    }

    WireEvents() {
        this.View.OnCloseRequest := (*) => this.OnCancel()
        this.View.OnCancelRequest := (*) => this.OnCancel()
        this.View.OnSaveRequest := (*) => this.OnSave()

        this.View.OnThickChangeRequest := (val) => this.OnThickChange(val)
        this.View.OnTransChangeRequest := (val) => this.OnTransChange(val)
        this.View.OnColorChangeRequest := (val) => this.OnColorChange(val)
        this.View.OnRoundedChangeRequest := (val) => this.OnRoundedChange(val)
        this.View.OnColorDropRequest := (*) => this.OnColorDrop()

        this.View.OnUndoThickRequest := (*) => this.OnUndoThick()
        this.View.OnUndoTransRequest := (*) => this.OnUndoTrans()
        this.View.OnUndoColorRequest := (*) => this.OnUndoColor()
        this.View.OnUndoAutostartRequest := (*) => this.OnUndoAutostart()
        this.View.OnUndoRoundedRequest := (*) => this.OnUndoRounded()

        this.View.OnAutostartChangeRequest := (*) => this.EvaluateUndoStates()

        this.View.OnMouseWheelRequest := (hwnd, dir) => this.OnMouseWheel(hwnd, dir)

        this.View.ColorPicker.OnColorChange := (hexStr) => this.OnColorPickerChange(hexStr)
    }

    EvaluateUndoStates(*) {
        this.View.myBtnUndoThick.Enabled := (this.View.myThickUD.Value != this.origThick)
        this.View.myBtnUndoTrans.Enabled := (this.View.myTransEdit.Value != this.origTrans)
        this.View.myBtnUndoColor.Enabled := (this.View.myColorEdit.Value != this.origColor)
        this.View.myBtnUndoAutostart.Enabled := (this.View.myCbAutostart.Value != this.origAutostart)
        this.View.myBtnUndoRounded.Enabled := (this.View.myCbRounded.Value != this.origRounded)
    }

    OnThickChange(val) {
        this.Renderer.myApplyBorderRegion(val, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.View.myCbRounded.Value)
        this.EvaluateUndoStates()
    }

    OnTransChange(val) {
        this.View.myTransEdit.Value := Format("{:.2f}", val * 0.05)
        WinSetTransparent(Round(255 * (val * 0.05)), this.Renderer.FocusGui.Hwnd)
        this.EvaluateUndoStates()
    }

    OnColorChange(val) {
        try {
            hexStr := myResolveColor(val)
            this.Renderer.FocusGui.BackColor := hexStr
            this.View.ColorPicker.mySyncSlidersFromHex(hexStr)
            this.View.myColorEdit.LastGood := val
            this.EvaluateUndoStates()
        } catch {
            MsgBox("Nieprawidlowy format koloru.", "Blad", 16)
            this.View.myColorEdit.Value := this.View.myColorEdit.HasOwnProp("LastGood") ? this.View.myColorEdit.LastGood : this.origColor
            this.EvaluateUndoStates()
        }
    }

    OnColorPickerChange(hexStr) {
        this.View.myColorEdit.Value := hexStr
        this.Renderer.FocusGui.BackColor := hexStr
        this.View.myColorEdit.LastGood := hexStr
        this.EvaluateUndoStates()
    }

    OnRoundedChange(val) {
        this.Renderer.myApplyBorderRegion(this.View.myThickUD.Value, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, val)
        this.EvaluateUndoStates()
    }

    OnColorDrop() {
        this.TooltipManager.myStopTimer()
        res := myPickColorFromScreen(this.Renderer)
        if (res != "") {
            this.View.myColorEdit.Value := res
            this.Renderer.FocusGui.BackColor := res
            this.View.ColorPicker.mySyncSlidersFromHex(res)
            this.View.myColorEdit.LastGood := res
        } else {
            hexStr := myResolveColor(this.View.myColorEdit.Value)
            this.Renderer.FocusGui.BackColor := hexStr
            this.View.ColorPicker.mySyncSlidersFromHex(hexStr)
        }
        this.EvaluateUndoStates()
    }

    OnMouseWheel(hwnd, dir) {
        this.View.myTransUD.Value += dir
        val := this.View.myTransUD.Value
        this.View.myTransEdit.Value := Format("{:.2f}", val * 0.05)
        WinSetTransparent(Round(255 * (val * 0.05)), this.Renderer.FocusGui.Hwnd)
        this.EvaluateUndoStates()
    }

    OnUndoThick() {
        this.View.myThickUD.Value := this.origThick
        this.OnThickChange(this.origThick)
    }

    OnUndoTrans() {
        this.View.myTransUD.Value := Round(this.origTrans / 0.05)
        this.View.myTransEdit.Value := this.origTrans
        WinSetTransparent(Round(255 * Float(this.origTrans)), this.Renderer.FocusGui.Hwnd)
        this.EvaluateUndoStates()
    }

    OnUndoColor() {
        this.View.myColorEdit.Value := this.origColor
        hexStr := myResolveColor(this.origColor)
        this.Renderer.FocusGui.BackColor := hexStr
        this.View.ColorPicker.mySyncSlidersFromHex(hexStr)
        this.EvaluateUndoStates()
    }

    OnUndoAutostart() {
        this.View.myCbAutostart.Value := this.origAutostart
        this.EvaluateUndoStates()
    }

    OnUndoRounded() {
        this.View.myCbRounded.Value := this.origRounded
        this.OnRoundedChange(this.origRounded)
    }

    OnSave() {
        mySaved := this.View.Gui.Submit()
        this.Config.mySaveData(mySaved.BorderThickness, mySaved.Transparency, mySaved.BorderColor, mySaved.Autostart, mySaved.UseRoundedCorners, this.Config.CornersRadius)
        Reload()
    }

    OnCancel() {
        this.TooltipManager.myDisable()
        this.View.myCleanup()

        this.Renderer.IsConfigMode := false
        this.Renderer.FocusGui.BackColor := myResolveColor(this.Config.BorderColor)
        WinSetTransparent(Round(255 * this.Config.Transparency), this.Renderer.FocusGui.Hwnd)
        this.Renderer.myApplyBorderRegion(this.Config.BorderThickness, this.Renderer.gLastW, this.Renderer.gLastH, this.Renderer.gLastVX, this.Renderer.gLastVY, this.Renderer.gLastVW, this.Renderer.gLastVH, this.Config.UseRoundedCorners)
    }
}