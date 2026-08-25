import AppKit

final class ApplicationSwitcherWindowController: NSWindowController {
    private let sectors: [[ApplicationSwitchItem]]
    private let onSelect: (ApplicationSwitchItem) -> Void
    private let onDismiss: () -> Void

    init(
        sectors: [[ApplicationSwitchItem]],
        preferredSelectionBundleIdentifier: String? = nil,
        onSelect: @escaping (ApplicationSwitchItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.sectors = sectors
        self.onSelect = onSelect
        self.onDismiss = onDismiss

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let screenFrame = targetScreen?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let preferredCenter = NSPoint(
            x: mouseLocation.x - screenFrame.minX,
            y: mouseLocation.y - screenFrame.minY
        )
        let window = ApplicationSwitcherOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        super.init(window: window)

        let contentView = ApplicationSwitcherOverlayView(
            frame: screenFrame,
            sectors: sectors,
            preferredCenter: preferredCenter,
            preferredSelectionBundleIdentifier: preferredSelectionBundleIdentifier,
            onSelect: { [weak self] item in
                self?.onSelect(item)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        window.contentView = contentView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window?.contentView)
        (window?.contentView as? ApplicationSwitcherOverlayView)?.animateIn()
    }

    func dismiss() {
        close()
        onDismiss()
    }
}

private final class ApplicationSwitcherOverlayWindow: NSPanel {
    private var dismissDetector = ApplicationSwitcherDismissDetector(initialModifierFlags: NSEvent.modifierFlags)

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        guard let overlayView = contentView as? ApplicationSwitcherOverlayView else {
            return
        }

        if overlayView.handleKeyDown(event) {
            return
        }

        overlayView.dismiss()
    }

    override func flagsChanged(with event: NSEvent) {
        if dismissDetector.modifierFlagsChanged(to: event.modifierFlags) {
            (contentView as? ApplicationSwitcherOverlayView)?.dismiss()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        (contentView as? ApplicationSwitcherOverlayView)?.dismiss()
    }
}

struct ApplicationSwitcherDismissDetector {
    private var suppressCommandDismissUntilCommandReleased: Bool
    private var wasCommandDown: Bool

    init(initialModifierFlags: NSEvent.ModifierFlags) {
        let normalizedFlags = initialModifierFlags.intersection(.deviceIndependentFlagsMask)
        let commandIsDown = normalizedFlags.contains(.command)

        suppressCommandDismissUntilCommandReleased = commandIsDown
        wasCommandDown = commandIsDown
    }

    mutating func modifierFlagsChanged(to flags: NSEvent.ModifierFlags) -> Bool {
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)
        let commandIsDown = normalizedFlags.contains(.command)
        defer {
            wasCommandDown = commandIsDown
        }

        if !commandIsDown {
            suppressCommandDismissUntilCommandReleased = false
            return false
        }

        if suppressCommandDismissUntilCommandReleased {
            return false
        }

        return !wasCommandDown
    }
}

enum ApplicationSwitcherNavigationDirection {
    case up
    case down
    case left
    case right

    func containsCandidate(center candidate: NSPoint, relativeTo current: NSPoint) -> Bool {
        switch self {
        case .up:
            return candidate.y > current.y
        case .down:
            return candidate.y < current.y
        case .left:
            return candidate.x < current.x
        case .right:
            return candidate.x > current.x
        }
    }
}

struct ApplicationSwitcherSelectionEntry {
    let identifier: String
    let displayName: String
    let center: NSPoint
    let lastActivationDate: Date?
}

struct ApplicationSwitcherSelectionModel {
    private(set) var entries: [ApplicationSwitcherSelectionEntry]
    private(set) var selectedIdentifier: String?

    var selectedDisplayName: String? {
        selectedEntry?.displayName
    }

    init(entries: [ApplicationSwitcherSelectionEntry], preferredIdentifier: String? = nil) {
        self.entries = entries
        selectedIdentifier = Self.defaultSelectedIdentifier(in: entries, preferredIdentifier: preferredIdentifier)
    }

    func updatingEntries(_ nextEntries: [ApplicationSwitcherSelectionEntry]) -> ApplicationSwitcherSelectionModel {
        var model = ApplicationSwitcherSelectionModel(entries: nextEntries)
        if let selectedIdentifier, nextEntries.contains(where: { $0.identifier == selectedIdentifier }) {
            model.selectedIdentifier = selectedIdentifier
        }
        return model
    }

    mutating func select(identifier: String) {
        guard entries.contains(where: { $0.identifier == identifier }) else {
            return
        }

        selectedIdentifier = identifier
    }

    mutating func move(_ direction: ApplicationSwitcherNavigationDirection) {
        guard
            let currentIdentifier = selectedIdentifier,
            let currentEntry = entries.first(where: { $0.identifier == currentIdentifier })
        else {
            selectedIdentifier = Self.defaultSelectedIdentifier(in: entries)
            return
        }

        selectedIdentifier = entries
            .filter { entry in
                entry.identifier != currentIdentifier
                    && direction.containsCandidate(center: entry.center, relativeTo: currentEntry.center)
            }
            .min { lhs, rhs in
                distanceSquared(from: currentEntry.center, to: lhs.center)
                    < distanceSquared(from: currentEntry.center, to: rhs.center)
            }?
            .identifier ?? currentIdentifier
    }

    private static func defaultSelectedIdentifier(
        in entries: [ApplicationSwitcherSelectionEntry],
        preferredIdentifier: String? = nil
    ) -> String? {
        if
            let preferredIdentifier,
            entries.contains(where: { $0.identifier == preferredIdentifier })
        {
            return preferredIdentifier
        }

        return entries.max { lhs, rhs in
            switch (lhs.lastActivationDate, rhs.lastActivationDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            default:
                return false
            }
        }?.identifier
    }

    private func distanceSquared(from lhs: NSPoint, to rhs: NSPoint) -> CGFloat {
        let deltaX = lhs.x - rhs.x
        let deltaY = lhs.y - rhs.y
        return deltaX * deltaX + deltaY * deltaY
    }

    private var selectedEntry: ApplicationSwitcherSelectionEntry? {
        guard let selectedIdentifier else {
            return nil
        }

        return entries.first { $0.identifier == selectedIdentifier }
    }
}

private final class ApplicationSwitcherOverlayView: NSView {
    private let radialView: RadialMenuView
    private let preferredCenter: NSPoint
    private let onDismiss: () -> Void
    private let preferredRadialSize: CGFloat = 560
    private let edgePadding: CGFloat = 20

    init(
        frame: NSRect,
        sectors: [[ApplicationSwitchItem]],
        preferredCenter: NSPoint,
        preferredSelectionBundleIdentifier: String?,
        onSelect: @escaping (ApplicationSwitchItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.preferredCenter = preferredCenter
        self.onDismiss = onDismiss
        radialView = RadialMenuView(
            frame: .zero,
            sectors: sectors,
            preferredSelectionBundleIdentifier: preferredSelectionBundleIdentifier,
            onSelect: onSelect
        )
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        addSubview(radialView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        let radialSize = min(preferredRadialSize, max(360, min(bounds.width, bounds.height) - edgePadding * 2))
        let halfSize = radialSize / 2
        let center = NSPoint(
            x: min(max(preferredCenter.x, halfSize + edgePadding), bounds.width - halfSize - edgePadding),
            y: min(max(preferredCenter.y, halfSize + edgePadding), bounds.height - halfSize - edgePadding)
        )
        radialView.frame = NSRect(
            x: center.x - halfSize,
            y: center.y - halfSize,
            width: radialSize,
            height: radialSize
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard radialView.frame.contains(point) else {
            dismiss()
            return
        }

        let radialPoint = radialView.convert(point, from: self)
        _ = radialView.selectItem(at: radialPoint)
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.specialKey {
        case .leftArrow:
            radialView.moveSelection(.left)
            return true
        case .rightArrow:
            radialView.moveSelection(.right)
            return true
        case .upArrow:
            radialView.moveSelection(.up)
            return true
        case .downArrow:
            radialView.moveSelection(.down)
            return true
        default:
            break
        }

        switch event.keyCode {
        case 36, 76, 49:
            return radialView.activateSelectedItem()
        default:
            return false
        }
    }

    func animateIn() {
        radialView.alphaValue = 0
        radialView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.72, y: 0.72))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            radialView.animator().alphaValue = 1
            radialView.layer?.setAffineTransform(.identity)
        }
    }

    func dismiss() {
        onDismiss()
    }
}

private final class RadialMenuView: NSView {
    private let sectors: [[ApplicationSwitchItem]]
    private let preferredSelectionBundleIdentifier: String?
    private let onSelect: (ApplicationSwitchItem) -> Void
    private var appButtons: [RadialAppButton] = []
    private var buttonPlacements: [(button: RadialAppButton, sectorIndex: Int, appIndex: Int, appCount: Int)] = []
    private var selectionModel: ApplicationSwitcherSelectionModel?
    private var trackingArea: NSTrackingArea?
    private weak var hoveredButton: RadialAppButton?
    private let centerTitleLabel = NSTextField(labelWithString: "")
    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.06, green: 0.48, blue: 0.42, alpha: 0.78),
        NSColor(calibratedRed: 0.18, green: 0.45, blue: 0.85, alpha: 0.78),
        NSColor(calibratedRed: 0.82, green: 0.30, blue: 0.44, alpha: 0.78),
        NSColor(calibratedRed: 0.72, green: 0.47, blue: 0.09, alpha: 0.78),
        NSColor(calibratedRed: 0.48, green: 0.35, blue: 0.78, alpha: 0.78),
        NSColor(calibratedRed: 0.16, green: 0.54, blue: 0.33, alpha: 0.78),
        NSColor(calibratedRed: 0.22, green: 0.43, blue: 0.53, alpha: 0.78),
        NSColor(calibratedRed: 0.51, green: 0.33, blue: 0.22, alpha: 0.78)
    ]

    init(
        frame: NSRect,
        sectors: [[ApplicationSwitchItem]],
        preferredSelectionBundleIdentifier: String?,
        onSelect: @escaping (ApplicationSwitchItem) -> Void
    ) {
        self.sectors = sectors
        self.preferredSelectionBundleIdentifier = preferredSelectionBundleIdentifier
        self.onSelect = onSelect
        super.init(frame: frame)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 30
        layer?.shadowOffset = NSSize(width: 0, height: -10)
        buildAppButtons()
        buildCenterTitleLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredButton(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        updateHoveredButton(at: nil)
    }

    override func mouseDown(with event: NSEvent) {
        _ = selectItem(at: convert(event.locationInWindow, from: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8
        let sectorCount = max(sectors.count, 1)
        let step = 360.0 / CGFloat(sectorCount)

        for index in 0..<sectorCount {
            let path = NSBezierPath()
            let start = 90 - (CGFloat(index) * step) - step / 2
            let end = start - step
            path.move(to: center)
            path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            path.close()

            colors[index % colors.count].setFill()
            path.fill()

            NSColor.white.withAlphaComponent(0.28).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let centerRadius: CGFloat = 56
        let centerPath = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - centerRadius,
                y: center.y - centerRadius,
                width: centerRadius * 2,
                height: centerRadius * 2
            )
        )
        NSColor.white.withAlphaComponent(0.92).setFill()
        centerPath.fill()
    }

    override func layout() {
        super.layout()
        layoutCenterTitleLabel()
        layoutAppButtons()
    }

    func selectItem(at point: NSPoint) -> Bool {
        for button in appButtons.reversed() where button.containsIconPoint(convert(point, to: button)) {
            selectButton(button)
            button.selectItem()
            return true
        }

        return false
    }

    func moveSelection(_ direction: ApplicationSwitcherNavigationDirection) {
        refreshSelectionModel()
        selectionModel?.move(direction)
        applySelectedState()
    }

    func activateSelectedItem() -> Bool {
        refreshSelectionModel()

        guard let selectedButton else {
            return false
        }

        selectedButton.selectItem()
        return true
    }

    private func updateHoveredButton(at point: NSPoint?) {
        let nextButton = point.flatMap { button(at: $0) }
        guard hoveredButton !== nextButton else {
            return
        }

        hoveredButton?.setHoverState(false)
        nextButton?.setHoverState(true)
        hoveredButton = nextButton
        updateCenterTitle()
    }

    private func button(at point: NSPoint) -> RadialAppButton? {
        appButtons
            .filter { $0.containsIconPoint(convert(point, to: $0)) }
            .min {
                $0.iconDistanceSquared(from: convert(point, to: $0)) <
                    $1.iconDistanceSquared(from: convert(point, to: $1))
            }
    }

    private func buildAppButtons() {
        appButtons.forEach { $0.removeFromSuperview() }
        appButtons = []
        buttonPlacements = []

        for (index, apps) in sectors.enumerated() where !apps.isEmpty {
            for (appIndex, app) in apps.enumerated() {
                let button = RadialAppButton(item: app, onSelect: onSelect)
                addSubview(button)
                appButtons.append(button)
                buttonPlacements.append((button, index, appIndex, apps.count))
            }
        }

        bringCenterTitleLabelToFront()
    }

    private func buildCenterTitleLabel() {
        let centeredCell = CenteredTextFieldCell(textCell: "")
        centeredCell.alignment = .center
        centeredCell.lineBreakMode = .byTruncatingTail
        centerTitleLabel.cell = centeredCell
        centerTitleLabel.isBezeled = false
        centerTitleLabel.drawsBackground = false
        centerTitleLabel.isEditable = false
        centerTitleLabel.isSelectable = false
        centerTitleLabel.alignment = .center
        centerTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        centerTitleLabel.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        centerTitleLabel.lineBreakMode = .byTruncatingTail
        centerTitleLabel.maximumNumberOfLines = 2
        centerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerTitleLabel, positioned: .above, relativeTo: nil)
    }

    private func layoutCenterTitleLabel() {
        centerTitleLabel.frame = NSRect(
            x: bounds.midX - 50,
            y: bounds.midY - 23,
            width: 100,
            height: 46
        )
    }

    private func layoutAppButtons() {
        let menuSize = min(bounds.width, bounds.height)
        let baseRadius = menuSize * 0.34
        let minimumRadius = menuSize * 0.21
        let maximumRadius = menuSize * 0.44
        let sectorCount = max(sectors.count, 1)
        let step = 360.0 / CGFloat(sectorCount)

        for placement in buttonPlacements {
            let columns = columnCount(for: placement.appCount)
            let rows = Int(ceil(Double(placement.appCount) / Double(columns)))
            let column = placement.appIndex % columns
            let row = placement.appIndex / columns
            let angleOffset = angleOffset(
                column: column,
                columns: columns,
                appCount: placement.appCount,
                sectorStep: step
            )

            let rowCenter = CGFloat(rows - 1) / 2
            let radiusStep = min(menuSize * 0.105, 64)
            let radiusOffset = (CGFloat(row) - rowCenter) * radiusStep
            let radius = min(max(baseRadius + radiusOffset, minimumRadius), maximumRadius)
            let angle = (-90 + CGFloat(placement.sectorIndex) * step + angleOffset) * CGFloat.pi / 180
            let size = placement.button.preferredSize
            let frame = NSRect(
                x: bounds.midX + cos(angle) * radius - size.width / 2,
                y: bounds.midY + sin(angle) * radius - size.height / 2,
                width: size.width,
                height: size.height
            )

            placement.button.frame = frame
        }

        refreshSelectionModel()
        applySelectedState()
    }

    private func refreshSelectionModel() {
        let entries = appButtons.map { $0.selectionEntry }
        selectionModel = selectionModel?.updatingEntries(entries)
            ?? ApplicationSwitcherSelectionModel(
                entries: entries,
                preferredIdentifier: preferredSelectionBundleIdentifier
            )
    }

    private var selectedButton: RadialAppButton? {
        guard let selectedIdentifier = selectionModel?.selectedIdentifier else {
            return nil
        }

        return appButtons.first { $0.selectionIdentifier == selectedIdentifier }
    }

    private func selectButton(_ button: RadialAppButton) {
        refreshSelectionModel()
        selectionModel?.select(identifier: button.selectionIdentifier)
        applySelectedState()
    }

    private func applySelectedState() {
        let selectedIdentifier = selectionModel?.selectedIdentifier
        for button in appButtons {
            button.setSelectedState(button.selectionIdentifier == selectedIdentifier)
        }
        updateCenterTitle()
    }

    private func updateCenterTitle() {
        centerTitleLabel.stringValue = hoveredButton?.displayName
            ?? selectionModel?.selectedDisplayName
            ?? ""
    }

    private func bringCenterTitleLabelToFront() {
        guard centerTitleLabel.superview === self else {
            return
        }

        addSubview(centerTitleLabel, positioned: .above, relativeTo: nil)
    }

    private func columnCount(for appCount: Int) -> Int {
        switch appCount {
        case ...1:
            return 1
        case 2...4:
            return 2
        default:
            return 3
        }
    }

    private func angleOffset(column: Int, columns: Int, appCount: Int, sectorStep: CGFloat) -> CGFloat {
        guard columns > 1 else {
            return 0
        }

        let sectorPadding = min(max(sectorStep * 0.14, 8), 14)
        let usableAngle = max(0, sectorStep - sectorPadding * 2)
        let normalizedColumn = CGFloat(column) / CGFloat(columns - 1)
        let centeredColumn = normalizedColumn - 0.5
        let countScale = appCount <= 4 ? 0.62 : 0.86

        return centeredColumn * usableAngle * countScale
    }
}

private final class CenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var drawingRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        let heightOffset = max(0, (drawingRect.height - textHeight) / 2)

        drawingRect.origin.y += heightOffset
        drawingRect.size.height -= heightOffset * 2

        return drawingRect
    }
}

private final class RadialAppGroupView: NSView {
    let preferredSize: NSSize
    private let stackView = NSStackView()

    init(apps: [ApplicationSwitchItem], onSelect: @escaping (ApplicationSwitchItem) -> Void) {
        let rowHeight: CGFloat = 98
        preferredSize = NSSize(width: 122, height: max(rowHeight, CGFloat(apps.count) * rowHeight))
        super.init(frame: NSRect(origin: .zero, size: preferredSize))

        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for app in apps {
            stackView.addArrangedSubview(RadialAppButton(item: app, onSelect: onSelect))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class RadialAppButton: NSControl {
    let preferredSize = NSSize(width: 72, height: 72)
    private let item: ApplicationSwitchItem
    private let select: (ApplicationSwitchItem) -> Void
    private let iconBackgroundView = NSView()
    private let iconHitPadding: CGFloat = 4
    private var isHovered = false
    private var isSelected = false

    init(item: ApplicationSwitchItem, onSelect: @escaping (ApplicationSwitchItem) -> Void) {
        self.item = item
        select = onSelect
        super.init(frame: .zero)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        containsIconPoint(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if containsIconPoint(point) {
            selectItem()
        }
    }

    var selectionIdentifier: String {
        item.bundleIdentifier
    }

    var displayName: String {
        item.name
    }

    var selectionEntry: ApplicationSwitcherSelectionEntry {
        ApplicationSwitcherSelectionEntry(
            identifier: selectionIdentifier,
            displayName: item.name,
            center: frame.center,
            lastActivationDate: item.lastActivationDate
        )
    }

    private func buildContent() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        iconBackgroundView.wantsLayer = true
        iconBackgroundView.layer?.cornerRadius = 34
        iconBackgroundView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0).cgColor
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: item.icon ?? NSImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        iconBackgroundView.addSubview(iconView)
        addSubview(iconBackgroundView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 72),
            heightAnchor.constraint(equalToConstant: 72),

            iconBackgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 68),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 68),

            iconView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 58),
            iconView.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    func setHoverState(_ isHovered: Bool) {
        self.isHovered = isHovered
        updateSelectionBackground(animated: isHovered)
    }

    func setSelectedState(_ isSelected: Bool) {
        guard self.isSelected != isSelected else {
            return
        }

        self.isSelected = isSelected
        updateSelectionBackground(animated: true)
    }

    private func updateSelectionBackground(animated: Bool) {
        let alpha: CGFloat
        if isSelected {
            alpha = 0.38
        } else if isHovered {
            alpha = 0.24
        } else {
            alpha = 0
        }
        let targetColor = NSColor.white.withAlphaComponent(alpha).cgColor

        guard animated else {
            iconBackgroundView.layer?.backgroundColor = targetColor
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iconBackgroundView.animator().layer?.backgroundColor = targetColor
        }
    }

    func selectItem() {
        select(item)
    }

    func containsIconPoint(_ point: NSPoint) -> Bool {
        iconDistanceSquared(from: point) <= pow(iconRadius + iconHitPadding, 2)
    }

    func iconDistanceSquared(from point: NSPoint) -> CGFloat {
        let center = convert(iconBackgroundView.bounds.center, from: iconBackgroundView)
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y

        return deltaX * deltaX + deltaY * deltaY
    }

    private var iconRadius: CGFloat {
        iconBackgroundView.bounds.width / 2
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
