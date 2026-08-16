class mySettingsGui {
    __New() {
        this.baseCW := 0
        this.baseCH := 0

        this.OnCloseRequest := ""
        this.OnUndoThickRequest := ""
        this.OnUndoTransRequest := ""
        this.OnUndoColorRequest := ""
        this.OnUndoAutostartRequest := ""
        this.OnUndoRoundedRequest := ""
        this.OnSaveRequest := ""
        this.OnCancelRequest := ""
        this.OnThickChangeRequest := ""
        this.OnTransChangeRequest := ""
        this.OnColorChangeRequest := ""
        this.OnColorDropRequest := ""
        this.OnRoundedChangeRequest := ""
        this.OnMouseWheelRequest := ""
        this.OnAutostartChangeRequest := ""
    }

    myBuild(origThick, origTrans, origColor, origAutostart, origRounded, gradientEngine) {
        this.Gui := Gui("-MinimizeBox -MaximizeBox", "Absurdian Focus Frame")
        this.Gui.MarginX := 15
        this.Ygap := 6
        this.Gui.MarginY := this.Ygap

        this.Gui.OnEvent("Close", (*) => this.myTrigger(this.OnCloseRequest))

        myBtnInfo := this.Gui.Add("Button", "xm y" this.Ygap, "ℹ️ About program")
        myBtnInfo.OnEvent("Click", (*) => this.ShowInfoDialog())

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+" this.Ygap, "Border Thickness (px):")
        this.myThickEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w80 vBorderThickness", origThick)
        this.myThickUD := this.Gui.Add("UpDown", "Range1-4", origThick)
        this.myThickUD.OnEvent("Change", (ctrl, *) => this.myTrigger(this.OnThickChangeRequest, ctrl.Value))

        this.myBtnUndoThick := mySmallButton(this.Gui, "↩", "Undo thickness changes")
        this.myBtnUndoThick.OnEvent("Click", (*) => this.myTrigger(this.OnUndoThickRequest))

        this.myAddSeparator()

        this.myCbRounded := this.Gui.Add("CheckBox", "xm y+" this.Ygap " h22 vUseRoundedCorners", "Rounded Corners")
        this.myCbRounded.Value := origRounded
        this.myCbRounded.OnEvent("Click", (ctrl, *) => this.myTrigger(this.OnRoundedChangeRequest, ctrl.Value))
        this.myBtnUndoRounded := mySmallButton(this.Gui, "↩", "Undo rounded changes")
        this.myBtnUndoRounded.OnEvent("Click", (*) => this.myTrigger(this.OnUndoRoundedRequest))

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+5", "Transparency (0.0 - 1.0):")
        this.myTransEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w60 vTransparency", Format("{:.2f}", origTrans))
        this.myTransUD := this.Gui.Add("UpDown", "-2 Range0-20", Round(origTrans / 0.05))
        this.myTransUD.OnEvent("Change", (ctrl, *) => this.myTrigger(this.OnTransChangeRequest, ctrl.Value))

        this.myBtnUndoTrans := mySmallButton(this.Gui, "↩", "Undo transparency changes")
        this.myBtnUndoTrans.OnEvent("Click", (*) => this.myTrigger(this.OnUndoTransRequest))

        this.WheelBound := (wParam, _1, _2, hwnd, *) => this.myHandleMouseWheel(wParam, hwnd)
        OnMessage(0x020A, this.WheelBound)

        this.myAddSeparator()

        this.Gui.Add("Text", "xm y+" this.Ygap, "Border Color:")
        this.myColorEdit := this.Gui.Add("Edit", "xm y+" this.Ygap " w60 vBorderColor", origColor)
        this.myColorEdit.LastGood := origColor
        this.myColorEdit.myCustomTooltip := "HEX value or empty for auto-theme."
        this.myColorEdit.OnEvent("Change", (ctrl, *) => this.myTrigger(this.OnColorChangeRequest, ctrl.Value))

        myBtnPicker := mySmallButton(this.Gui, "🎨", "Manual color selection")
        myBtnPicker.OnEvent("Click", (*) => this.myTogglePicker())

        myBtnDrop := mySmallButton(this.Gui, "💉", "Screen color sampler")
        myBtnDrop.OnEvent("Click", (*) => this.myTrigger(this.OnColorDropRequest))

        this.myBtnUndoColor := mySmallButton(this.Gui, "↩", "Undo color changes")
        this.myBtnUndoColor.OnEvent("Click", (*) => this.myTrigger(this.OnUndoColorRequest))

        this.myAddSeparator()

        this.myCbAutostart := this.Gui.Add("CheckBox", "xm y+" this.Ygap " h22 vAutostart", "Enable Autostart")
        this.myCbAutostart.Value := origAutostart
        this.myCbAutostart.OnEvent("Click", (ctrl, *) => this.myTrigger(this.OnAutostartChangeRequest))
        this.myBtnUndoAutostart := mySmallButton(this.Gui, "↩", "Undo autostart changes")
        this.myBtnUndoAutostart.OnEvent("Click", (*) => this.myTrigger(this.OnUndoAutostartRequest))

        this.myAddSeparator()

        btnSave := this.Gui.Add("Button", "xm y+" this.Ygap " w60 Default", "Save")
        btnSave.OnEvent("Click", (*) => this.myTrigger(this.OnSaveRequest))
        btnCancel := this.Gui.Add("Button", "x+10 yp w60", "Cancel")
        btnCancel.OnEvent("Click", (*) => this.myTrigger(this.OnCancelRequest))

        this.Gui.Show("AutoSize Hide")
        this.Gui.GetClientPos(&_x, &_y, &baseCW, &baseCH)
        this.baseCW := baseCW, this.baseCH := baseCH

        this.ColorPicker := myColorPickerWidget(this.Gui, gradientEngine, "d3d3d3", 300, 40, 10, 54, 5, 3)
        origHex := myResolveColor(origColor)
        this.ColorPicker.mySyncSlidersFromHex(origHex)

        this.Gui.Show("w" this.baseCW " h" this.baseCH)
    }

    myTrigger(callback, args*) {
        if (callback != "") {
            cb := callback
            cb(args*)
        }
    }

    myHandleMouseWheel(wParam, hwnd) {
        dir := (wParam << 32 >> 48) > 0 ? 1 : -1
        if (hwnd == this.myTransEdit.Hwnd || hwnd == this.myTransUD.Hwnd) {
            this.myTrigger(this.OnMouseWheelRequest, hwnd, dir)
            return 1
        }
        if (this.ColorPicker.PickerVisible) {
            if (this.ColorPicker.HandleMouseWheel(hwnd, dir))
                return 1
        }
    }

    myTogglePicker() {
        this.ColorPicker.mySetVisibility(!this.ColorPicker.PickerVisible)
        if (this.ColorPicker.PickerVisible) {
            this.Gui.Show("AutoSize")
        } else {
            this.Gui.Show("w" this.baseCW " h" this.baseCH)
        }
    }

    myAddSeparator() {
        this.Gui.Add("Text", "xm-5 ym y+" this.Ygap " h1 w140 Backgroundd3d3d3")
    }

    myCleanup() {
        OnMessage(0x020A, this.WheelBound, 0)
        this.ColorPicker.myCleanup()
        this.Gui.Destroy()
    }

    ShowInfoDialog(*) {
        infoGui := Gui("+Owner" this.Gui.Hwnd " -MinimizeBox -MaximizeBox", "Absurdian Focus Frame - Info")
        this.Gui.Opt("+Disabled")

        infoClose := (*) => (this.Gui.Opt("-Disabled"), infoGui.Destroy())
        infoGui.OnEvent("Close", infoClose)

        infoGui.MarginX := 20
        infoGui.MarginY := 20
        infoGui.Add("Text", "w280", "WELCOME TO ABSURDIAN FOCUS FRAME!`n`nThis program changes the appearance of the native dotted selection border on the desktop to a modern highlight.`n`nThis project wouldn't be possible without the AutoHotkey community.`nSpecial thanks to: Descolada - for the amazing UIA.ahk library.")
        infoGui.Add("Link", "xm y+10", "my GitHub: <a href=`"https://github.com/AbsurdianVibe`">AbsurdianVibe</a>")
        infoGui.Add("Text", "xm y+10", "Happy clicking!")
        btnOk := infoGui.Add("Button", "w80 x120 y+20 Default", "OK")
        btnOk.OnEvent("Click", infoClose)
        infoGui.Show()
    }
}