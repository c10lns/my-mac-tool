import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let captureService = ScreenshotCaptureService()
    private let installedApplicationProvider = InstalledApplicationProvider()
    private let runningApplicationProvider = RunningApplicationProvider()
    private let switcherConfigurationStore = SwitcherConfigurationStore()
    private var hotKeyController: HotKeyController?
    private var commandDoubleTapMonitor: CommandDoubleTapMonitor?
    private var statusItem: NSStatusItem?
    private var pinnedWindows: [PinnedImageWindowController] = []
    private var switcherWindowController: ApplicationSwitcherWindowController?
    private var settingsWindowController: ApplicationSettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureHotKey()
        configureCommandDoubleTapMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func captureNow() {
        captureService.capture { [weak self] result in
            switch result {
            case .success(let imageURL):
                self?.showPinnedImage(from: imageURL)
            case .failure(.cancelled):
                break
            case .failure(let error):
                self?.showError(error)
            }
        }
    }

    @objc private func previewApplicationSwitcher() {
        showApplicationSwitcher()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = ApplicationSettingsWindowController(
                installedProvider: installedApplicationProvider,
                runningProvider: runningApplicationProvider,
                configurationStore: switcherConfigurationStore
            )
        }

        settingsWindowController?.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "C&L"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Capture Now (\(AppSettings.defaultHotKeyLabel))",
                action: #selector(captureNow),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Preview App Switcher (\(AppSettings.switcherHotKeyLabel))",
                action: #selector(previewApplicationSwitcher),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Settings...",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func configureHotKey() {
        let controller = HotKeyController { [weak self] in
            self?.captureNow()
        }

        do {
            try controller.register()
            hotKeyController = controller
        } catch {
            showError(error)
        }
    }

    private func configureCommandDoubleTapMonitor() {
        let monitor = CommandDoubleTapMonitor(
            onCommandTap: { [weak self] in
                self?.dismissApplicationSwitcher()
            },
            onDoubleTap: { [weak self] in
                self?.showApplicationSwitcher()
            }
        )
        monitor.start()
        commandDoubleTapMonitor = monitor
    }

    private func showApplicationSwitcher() {
        if switcherWindowController != nil {
            switcherWindowController?.dismiss()
            return
        }

        let runningApplicationsByBundleIdentifier = runningApplicationProvider.runningApplicationsByBundleIdentifier()
        let runningApplications = Array(runningApplicationsByBundleIdentifier.values).sortedForSwitcher()
        guard !runningApplications.isEmpty else {
            showError(NSError(
                domain: AppSettings.appName,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No running applications are available to switch to."]
            ))
            return
        }

        let sectors = switcherSectors(
            runningApplications: runningApplications,
            runningApplicationsByBundleIdentifier: runningApplicationsByBundleIdentifier
        )

        guard sectors.contains(where: { !$0.isEmpty }) else {
            showError(NSError(
                domain: AppSettings.appName,
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No configured applications are currently running. Open Settings to configure sectors."]
            ))
            return
        }

        let controller = ApplicationSwitcherWindowController(
            sectors: sectors,
            onSelect: { [weak self] item in
                self?.activate(item)
            },
            onDismiss: { [weak self] in
                self?.switcherWindowController = nil
            }
        )
        switcherWindowController = controller
        controller.showWindow(nil as Any?)
    }

    private func dismissApplicationSwitcher() {
        switcherWindowController?.dismiss()
    }

    private func switcherSectors(
        runningApplications: [ApplicationSwitchItem],
        runningApplicationsByBundleIdentifier: [String: ApplicationSwitchItem]
    ) -> [[ApplicationSwitchItem]] {
        let configuration = switcherConfigurationStore.load()
        let configuredIdentifiers = configuration.sectorBundleIdentifiers.flatMap { $0 }

        guard !configuredIdentifiers.isEmpty else {
            var sectors = Array(repeating: [ApplicationSwitchItem](), count: configuration.sectorCount)
            for (index, application) in runningApplications.prefix(configuration.sectorCount).enumerated() {
                sectors[index].append(application)
            }
            return sectors
        }

        return configuration.sectorBundleIdentifiers.map { identifiers in
            identifiers.compactMap { runningApplicationsByBundleIdentifier[$0] }
        }
    }

    private func activate(_ item: ApplicationSwitchItem) {
        item.runningApplication?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func showPinnedImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            showError(NSError(
                domain: AppSettings.appName,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not load captured image."]
            ))
            return
        }

        let controller = PinnedImageWindowController(image: image)
        controller.onClose = { [weak self, weak controller] in
            guard let controller else {
                return
            }

            self?.pinnedWindows.removeAll { $0 === controller }
        }
        pinnedWindows.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = AppSettings.appName
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        alert.alertStyle = .warning
        alert.runModal()
    }

}
