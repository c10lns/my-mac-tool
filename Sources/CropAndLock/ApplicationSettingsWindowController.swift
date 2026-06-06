import AppKit

private extension NSPasteboard.PasteboardType {
    static let applicationBundleIdentifier = NSPasteboard.PasteboardType("local.cropandlock.application-bundle-identifier")
}

final class ApplicationSettingsWindowController: NSWindowController {
    private let installedProvider: InstalledApplicationProvider
    private let runningProvider: RunningApplicationProvider
    private let configurationStore: SwitcherConfigurationStore
    private var configuration: SwitcherConfiguration
    private var installedApplications: [ApplicationDescriptor] = []
    private var filteredApplications: [ApplicationDescriptor] = []
    private var runningBundleIdentifiers = Set<String>()

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let filterLabel = NSTextField(labelWithString: "")
    private let sectorCountLabel = NSTextField(labelWithString: "")
    private let ringView = SectorRingSettingsView()

    init(
        installedProvider: InstalledApplicationProvider,
        runningProvider: RunningApplicationProvider,
        configurationStore: SwitcherConfigurationStore
    ) {
        self.installedProvider = installedProvider
        self.runningProvider = runningProvider
        self.configurationStore = configurationStore
        configuration = configurationStore.load()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CropAndLock Settings"
        window.minSize = NSSize(width: 780, height: 520)

        super.init(window: window)
        buildContent()
        reloadData()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        reloadData()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let title = NSTextField(labelWithString: "应用切换悬浮窗")
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let subtitle = NSTextField(labelWithString: "从本机可切换应用中筛选并拖入扇区；圆盘运行时只显示正在运行的已配置应用。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 13)

        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading

        let closeButton = NSButton(title: "完成", target: self, action: #selector(closeSettings))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"

        let header = NSStackView(views: [titleStack, closeButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .gravityAreas
        header.spacing = 16

        let leftPanel = buildApplicationListPanel()
        let rightPanel = buildSectorPanel()
        let body = NSStackView(views: [leftPanel, rightPanel])
        body.orientation = .horizontal
        body.spacing = 16
        body.distribution = .fill

        let root = NSStackView(views: [header, body])
        root.orientation = .vertical
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22),
            leftPanel.widthAnchor.constraint(equalToConstant: 330)
        ])
    }

    private func buildApplicationListPanel() -> NSView {
        let title = NSTextField(labelWithString: "本机可切换的应用")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        searchField.placeholderString = "筛选应用"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true

        filterLabel.textColor = .secondaryLabelColor
        filterLabel.font = .systemFont(ofSize: 12)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("application"))
        column.title = "Application"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 54
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([.applicationBundleIdentifier])

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.borderType = .lineBorder

        let stack = NSStackView(views: [title, searchField, filterLabel, scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        filterLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            filterLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 390)
        ])

        return panelWrapping(stack)
    }

    private func buildSectorPanel() -> NSView {
        let title = NSTextField(labelWithString: "圆形菜单扇区")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let decreaseButton = NSButton(title: "-", target: self, action: #selector(decreaseSectorCount))
        let increaseButton = NSButton(title: "+", target: self, action: #selector(increaseSectorCount))
        decreaseButton.bezelStyle = .rounded
        increaseButton.bezelStyle = .rounded

        let resetButton = NSButton(title: "重置", target: self, action: #selector(resetConfiguration))
        resetButton.bezelStyle = .rounded

        let controls = NSStackView(views: [decreaseButton, sectorCountLabel, increaseButton, resetButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.onDropBundleIdentifier = { [weak self] bundleIdentifier, sectorIndex in
            self?.place(bundleIdentifier: bundleIdentifier, inSectorAt: sectorIndex)
        }
        ringView.onRemoveBundleIdentifier = { [weak self] bundleIdentifier in
            self?.remove(bundleIdentifier: bundleIdentifier)
        }

        let stack = NSStackView(views: [title, controls, ringView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            ringView.widthAnchor.constraint(greaterThanOrEqualToConstant: 460),
            ringView.heightAnchor.constraint(greaterThanOrEqualToConstant: 460)
        ])

        return panelWrapping(stack)
    }

    private func panelWrapping(_ child: NSView) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.7).cgColor
        panel.layer?.cornerRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false
        child.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(child)

        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            child.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            child.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            child.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14)
        ])

        return panel
    }

    private func reloadData() {
        installedApplications = mergedApplicationDescriptors(
            installed: installedProvider.installedApplications(),
            running: runningProvider.runningApplicationDescriptors()
        )
        runningBundleIdentifiers = Set(runningProvider.runningApplications().map(\.bundleIdentifier))
        configuration = configurationStore.load()
        applyFilter()
        renderConfiguration()
    }

    private func mergedApplicationDescriptors(
        installed: [ApplicationDescriptor],
        running: [ApplicationDescriptor]
    ) -> [ApplicationDescriptor] {
        var descriptorsByBundleIdentifier = Dictionary(
            uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) }
        )

        for descriptor in running {
            descriptorsByBundleIdentifier[descriptor.bundleIdentifier] = descriptor
        }

        return descriptorsByBundleIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredApplications = query.isEmpty
            ? installedApplications
            : installedApplications.filter {
                $0.name.lowercased().contains(query) || $0.bundleIdentifier.lowercased().contains(query)
            }

        filterLabel.stringValue = query.isEmpty
            ? "\(installedApplications.count) 个可切换应用"
            : "匹配 \(filteredApplications.count) / \(installedApplications.count) 个应用"
        tableView.reloadData()
    }

    private func renderConfiguration() {
        sectorCountLabel.stringValue = "\(configuration.sectorCount) 个扇区"
        ringView.render(
            configuration: configuration,
            installedApplications: Dictionary(uniqueKeysWithValues: installedApplications.map { ($0.bundleIdentifier, $0) }),
            runningBundleIdentifiers: runningBundleIdentifiers
        )
    }

    private func saveAndRender() {
        configurationStore.save(configuration)
        applyFilter()
        renderConfiguration()
    }

    private func place(bundleIdentifier: String, inSectorAt sectorIndex: Int) {
        configuration.place(bundleIdentifier: bundleIdentifier, inSectorAt: sectorIndex)
        saveAndRender()
    }

    private func remove(bundleIdentifier: String) {
        configuration.remove(bundleIdentifier: bundleIdentifier)
        saveAndRender()
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    @objc private func decreaseSectorCount() {
        configuration.setSectorCount(configuration.sectorCount - 1)
        saveAndRender()
    }

    @objc private func increaseSectorCount() {
        configuration.setSectorCount(configuration.sectorCount + 1)
        saveAndRender()
    }

    @objc private func resetConfiguration() {
        configuration = SwitcherConfiguration()
        configurationStore.save(configuration)
        renderConfiguration()
    }

    @objc private func closeSettings() {
        close()
    }
}

extension ApplicationSettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredApplications.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard filteredApplications.indices.contains(row) else {
            return nil
        }

        let descriptor = filteredApplications[row]
        let assignedSectorIndex = configuration.sectorBundleIdentifiers.firstIndex { $0.contains(descriptor.bundleIdentifier) }
        let isRunning = runningBundleIdentifiers.contains(descriptor.bundleIdentifier)
        let status: String

        if let assignedSectorIndex {
            status = isRunning
                ? "第 \(assignedSectorIndex + 1) 扇区，运行中会显示"
                : "第 \(assignedSectorIndex + 1) 扇区，未运行时隐藏"
        } else {
            status = isRunning ? "运行中，可拖入扇区" : "未运行，可预先配置"
        }

        return ApplicationTableCellView(descriptor: descriptor, status: status)
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard filteredApplications.indices.contains(row) else {
            return nil
        }

        let item = NSPasteboardItem()
        item.setString(filteredApplications[row].bundleIdentifier, forType: .applicationBundleIdentifier)
        return item
    }
}

private final class ApplicationTableCellView: NSTableCellView {
    init(descriptor: ApplicationDescriptor, status: String) {
        super.init(frame: .zero)

        let iconView = NSImageView()
        iconView.image = NSWorkspace.shared.icon(forFile: descriptor.path)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: descriptor.name)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail

        let subtitle = NSTextField(labelWithString: status)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private final class SectorRingSettingsView: NSView {
    var onDropBundleIdentifier: ((String, Int) -> Void)?
    var onRemoveBundleIdentifier: ((String) -> Void)?

    private var configuration = SwitcherConfiguration()
    private var installedApplications: [String: ApplicationDescriptor] = [:]
    private var runningBundleIdentifiers = Set<String>()
    private var slotViews: [SectorSlotView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(
        configuration: SwitcherConfiguration,
        installedApplications: [String: ApplicationDescriptor],
        runningBundleIdentifiers: Set<String>
    ) {
        self.configuration = configuration
        self.installedApplications = installedApplications
        self.runningBundleIdentifiers = runningBundleIdentifiers

        subviews.forEach { $0.removeFromSuperview() }
        slotViews = []

        let centerLabel = NSTextField(labelWithString: "圆形菜单\n扇区顺序")
        centerLabel.alignment = .center
        centerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        centerLabel.textColor = .secondaryLabelColor
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerLabel)

        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        for index in 0..<configuration.sectorCount {
            let identifiers = configuration.sectorBundleIdentifiers.indices.contains(index)
                ? configuration.sectorBundleIdentifiers[index]
                : []
            let descriptors = identifiers.compactMap { installedApplications[$0] }
            let slotView = SectorSlotView(
                index: index,
                applications: descriptors,
                runningBundleIdentifiers: runningBundleIdentifiers
            )
            slotView.onDropBundleIdentifier = { [weak self] bundleIdentifier in
                self?.onDropBundleIdentifier?(bundleIdentifier, index)
            }
            slotView.onRemoveBundleIdentifier = { [weak self] bundleIdentifier in
                self?.onRemoveBundleIdentifier?(bundleIdentifier)
            }
            addSubview(slotView)
            slotViews.append(slotView)
        }

        needsLayout = true
    }

    override func layout() {
        super.layout()

        let radius = min(bounds.width, bounds.height) * 0.34
        let sectorCount = max(slotViews.count, 1)

        for (index, slotView) in slotViews.enumerated() {
            let angle = (-90 + CGFloat(index) * (360 / CGFloat(sectorCount))) * CGFloat.pi / 180
            let size = slotView.preferredSize
            let x = bounds.midX + cos(angle) * radius - size.width / 2
            let y = bounds.midY + sin(angle) * radius - size.height / 2
            slotView.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.42
        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        ring.lineWidth = 1
        ring.stroke()
    }
}

private final class SectorSlotView: NSView {
    let preferredSize = NSSize(width: 154, height: 132)
    var onDropBundleIdentifier: ((String) -> Void)?
    var onRemoveBundleIdentifier: ((String) -> Void)?

    private let index: Int
    private let applications: [ApplicationDescriptor]
    private let runningBundleIdentifiers: Set<String>
    private var isDragOver = false {
        didSet {
            needsDisplay = true
        }
    }

    init(index: Int, applications: [ApplicationDescriptor], runningBundleIdentifiers: Set<String>) {
        self.index = index
        self.applications = applications
        self.runningBundleIdentifiers = runningBundleIdentifiers
        super.init(frame: .zero)
        registerForDraggedTypes([.applicationBundleIdentifier])
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        (isDragOver ? NSColor.controlAccentColor.withAlphaComponent(0.22) : NSColor.textBackgroundColor.withAlphaComponent(0.78)).setFill()
        path.fill()
        (isDragOver ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragOver = true
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragOver = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragOver = false
        guard let identifier = sender.draggingPasteboard.string(forType: .applicationBundleIdentifier) else {
            return false
        }

        onDropBundleIdentifier?(identifier)
        return true
    }

    private func buildContent() {
        let title = NSTextField(labelWithString: "\(index + 1)")
        title.font = .systemFont(ofSize: 15, weight: .bold)
        title.textColor = .secondaryLabelColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(title)

        if applications.isEmpty {
            let empty = NSTextField(labelWithString: "空扇区")
            empty.textColor = .tertiaryLabelColor
            empty.font = .systemFont(ofSize: 12)
            stack.addArrangedSubview(empty)
        } else {
            stack.addArrangedSubview(scrollableApplicationList())
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])
    }

    private func slotApplicationView(for application: ApplicationDescriptor) -> NSView {
        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: application.path)
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: application.name)
        name.font = .systemFont(ofSize: 11)
        name.textColor = runningBundleIdentifiers.contains(application.bundleIdentifier) ? .labelColor : .secondaryLabelColor
        name.lineBreakMode = .byTruncatingTail

        let remove = NSButton(title: "x", target: self, action: #selector(removeClicked(_:)))
        remove.bezelStyle = .inline
        remove.isBordered = false
        remove.font = .systemFont(ofSize: 10, weight: .bold)
        remove.contentTintColor = .secondaryLabelColor
        remove.identifier = NSUserInterfaceItemIdentifier(application.bundleIdentifier)

        let row = NSStackView(views: [icon, name, remove])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 5
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            name.widthAnchor.constraint(lessThanOrEqualToConstant: 78)
        ])

        return row
    }

    private func scrollableApplicationList() -> NSView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = applications.count > 3
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        let appStack = NSStackView()
        appStack.orientation = .vertical
        appStack.alignment = .leading
        appStack.spacing = 4
        appStack.translatesAutoresizingMaskIntoConstraints = false

        for application in applications {
            appStack.addArrangedSubview(slotApplicationView(for: application))
        }

        documentView.addSubview(appStack)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 132),
            scrollView.heightAnchor.constraint(equalToConstant: 82),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            appStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            appStack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor),
            appStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            appStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        return scrollView
    }

    @objc private func removeClicked(_ sender: NSButton) {
        guard let bundleIdentifier = sender.identifier?.rawValue else {
            return
        }

        onRemoveBundleIdentifier?(bundleIdentifier)
    }
}
