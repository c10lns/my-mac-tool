# Application Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an application-switching floating window to the existing CropAndLock macOS utility while keeping screenshot pinning in the same app.

**Architecture:** Extend the AppKit menu-bar app with multiple global hotkeys. `command+control+a` keeps triggering screenshot pinning, and `command+control+space` opens a centered floating switcher that lists running regular applications and activates the selected app.

**Tech Stack:** Swift 5.10, Swift Package Manager, AppKit, Carbon hotkeys, XCTest where the local toolchain supports it.

---

### Task 1: Multiple Hotkeys

**Files:**
- Modify: `Sources/CropAndLock/HotKeyController.swift`
- Modify: `Sources/CropAndLock/AppSettings.swift`

- [ ] Replace the single-action hotkey controller with an id-based registry.
- [ ] Register capture and app-switcher hotkeys independently.

### Task 2: Application Switcher Model And Provider

**Files:**
- Create: `Sources/CropAndLock/ApplicationSwitchItem.swift`
- Create: `Sources/CropAndLock/RunningApplicationProvider.swift`
- Create: `Tests/CropAndLockTests/ApplicationSwitchItemTests.swift`

- [ ] Add a lightweight switch item model with stable display data.
- [ ] Enumerate regular running applications through `NSWorkspace`.
- [ ] Filter out the utility app itself.

### Task 3: Floating Switcher Window

**Files:**
- Create: `Sources/CropAndLock/ApplicationSwitcherWindowController.swift`
- Modify: `Sources/CropAndLock/AppDelegate.swift`

- [ ] Show a centered floating window with app icons and names.
- [ ] Support arrow keys, Tab, Enter, Escape, and mouse click.
- [ ] Activate the selected app and close the switcher.

### Task 4: Documentation And Verification

**Files:**
- Modify: `README.md`

- [ ] Document both features in the same application.
- [ ] Run `swift build`.
- [ ] Run `./scripts/build-app.sh`.
- [ ] Run a short launch/stop smoke test.
