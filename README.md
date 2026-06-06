# CropAndLock

CropAndLock is a local macOS menu-bar utility with two tools in one app:

- pin a selected screenshot above other windows
- switch between configured running apps from a radial floating menu

## Run

```bash
./scripts/run.sh
```

You can also run it directly:

```bash
swift run CropAndLock
```

## Build A Local App

```bash
./scripts/build-app.sh
open build/CropAndLock.app
```

## Use

1. Start the app.
2. Use `command+control+a`, or choose `Capture Now` from the `C&L` menu bar item.
3. Select a screen region in the macOS screenshot UI.
4. The captured image appears in a floating window above normal windows.
5. Drag or resize the window as needed.
6. Click the `x` button in the pinned image window to close it.

## App Switcher

- Double-tap `Command` to open the radial app switcher.
- Click an app icon to activate that app and close the switcher.
- Click outside the radial menu, or press any key, to close it.
- Use `C&L > Preview App Switcher` to open it from the menu bar.
- Use `C&L > Settings...` to configure sectors.

In Settings, the left list shows installed applications and supports search. Drag an application into a sector on the right. A configured application can belong to only one sector; dragging it to another sector moves it. The runtime switcher only shows configured applications that are currently running.

macOS may ask for Screen Recording permission the first time the screenshot tool runs, and Accessibility permission for the double-Command global trigger.
