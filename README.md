# Absurdian Focus Frame

![app icon](AbsurdianFocusFrame.png)

Welcome to **Absurdian Focus Frame**! This is my very first programming project.

## About the Project
This lightweight utility changes the appearance of the native dotted keyboard selection border on the Windows Desktop and in Windows Explorer, replacing it with a modern, customizable highlight frame.

## Current Status: Version 1.0.0
This is the initial release (First commit = First release).

* **Desktop:** The application is completely stable and fully functional.
* **Windows Explorer:** The script works, but there are some known visual bugs. While these glitches do not threaten the stability of the application in any way, they definitely do not meet the visual goals I set for this mini-project.

## Future Goals (Roadmap)
* **Bug Fixes:** Eliminate the visual glitches occurring within Windows Explorer folder views.
* **GUI Implementation:** Introduce a Graphical User Interface (GUI) to make adjusting settings (thickness, color, transparency) easier, replacing the current `.ini` file configuration approach.

## Configuration
Upon first launch, the script creates an `AbsurdianFocusFrame.ini` file in its directory. You can edit this file to change the border thickness, transparency, color (HEX), and autostart behavior. Restart the app from the system tray to apply changes(autostart is enabled by default).

## Credits
This project wouldn't be possible without the AutoHotkey community.
Special thanks to **Descolada** for the amazing `UIA.ahk` library, which enables precise communication with the Windows UI.

---

*Happy clicking!*
~ AbsurdianVibe