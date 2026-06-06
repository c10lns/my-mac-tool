# Crop And Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS utility that captures a selected screen region with a global hotkey and pins the captured image above other windows.

**Architecture:** Use a Swift Package executable with AppKit. A menu-bar app registers `command+control+a`, launches `/usr/sbin/screencapture -i` into a temporary PNG, then opens a resizable floating image window with an explicit close button.

**Tech Stack:** Swift 5.10, Swift Package Manager, AppKit, Carbon hotkeys, XCTest.

---

### Task 1: Project Skeleton And Testable Settings

**Files:**
- Create: `Package.swift`
- Create: `Sources/CropAndLock/AppSettings.swift`
- Create: `Tests/CropAndLockTests/AppSettingsTests.swift`

- [ ] Write XCTest coverage for the default hotkey label, screenshot output URL generation, and cleanup behavior.
- [ ] Run `swift test` and confirm the tests fail because implementation is missing.
- [ ] Implement the minimal settings and file management code.
- [ ] Run `swift test` and confirm the tests pass.

### Task 2: Native App, Hotkey, And Screenshot Flow

**Files:**
- Create: `Sources/CropAndLock/main.swift`
- Create: `Sources/CropAndLock/HotKeyController.swift`
- Create: `Sources/CropAndLock/ScreenshotCaptureService.swift`

- [ ] Register `command+control+a` with Carbon.
- [ ] Add a menu bar item with Capture Now and Quit actions.
- [ ] Launch interactive macOS screenshot capture and notify the app when the PNG exists.

### Task 3: Pinned Image Window

**Files:**
- Create: `Sources/CropAndLock/PinnedImageWindowController.swift`

- [ ] Create a floating, resizable AppKit window for the captured image.
- [ ] Render the image proportionally.
- [ ] Add an always-visible close button that closes only that pinned image window.

### Task 4: Local Run Script And Verification

**Files:**
- Create: `scripts/run.sh`
- Create: `README.md`

- [ ] Add a run script for local use.
- [ ] Document startup, permissions, and the hotkey.
- [ ] Run `swift test`.
- [ ] Run `swift build`.
