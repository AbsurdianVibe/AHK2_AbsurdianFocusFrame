    mySmallButton(Gui, symbol := "↩", customTip := "Undo changes") {
        btn := Gui.Add("Button", "x+2 yp w22 h22", symbol)
        if (customTip != "")
            btn.myCustomTooltip := customTip
        return btn
    }