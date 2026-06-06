import AppKit

final class PinnedImageWindowController: NSWindowController {
    private let capturedImage: NSImage
    private let aspectRatio: CGFloat
    var onClose: (() -> Void)?

    init(image: NSImage) {
        self.capturedImage = image
        let imageSize = Self.pixelSize(for: image)
        self.aspectRatio = imageSize.width / imageSize.height

        let frame = Self.initialFrame(for: image)
        let window = AspectLockedWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            aspectRatio: imageSize.width / imageSize.height
        )

        super.init(window: window)

        configureWindow(window)
        configureContent(in: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func close() {
        super.close()
        onClose?()
    }

    private func configureWindow(_ window: NSWindow) {
        window.title = AppSettings.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = Self.minimumWindowSize(aspectRatio: aspectRatio)
    }

    private func configureContent(in window: NSWindow) {
        let contentView = DraggableImageContentView(image: capturedImage)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        window.contentView = contentView
    }

    private static func initialFrame(for image: NSImage) -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxWidth = min(visibleFrame.width * 0.8, 900)
        let maxHeight = min(visibleFrame.height * 0.8, 700)
        let displaySize = displaySize(for: image)
        let scale = min(maxWidth / displaySize.width, maxHeight / displaySize.height, 1.0)
        let width = displaySize.width * scale
        let height = displaySize.height * scale
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.midY - height / 2

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func minimumWindowSize(aspectRatio: CGFloat) -> NSSize {
        let minimumLongSide: CGFloat = 48
        let minimumShortSide: CGFloat = 24

        if aspectRatio >= 1 {
            return NSSize(width: minimumLongSide, height: max(minimumLongSide / aspectRatio, minimumShortSide))
        } else {
            return NSSize(width: max(minimumLongSide * aspectRatio, minimumShortSide), height: minimumLongSide)
        }
    }

    private static func displaySize(for image: NSImage) -> NSSize {
        let pixelSize = pixelSize(for: image)
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        return NSSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    private static func pixelSize(for image: NSImage) -> NSSize {
        let representation = image.representations.max { lhs, rhs in
            (lhs.pixelsWide * lhs.pixelsHigh) < (rhs.pixelsWide * rhs.pixelsHigh)
        }

        if let representation, representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }

        return NSSize(width: 480, height: 320)
    }
}

private final class DraggableImageContentView: NSView {
    private let image: NSImage

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 1 else {
            super.mouseDown(with: event)
            return
        }

        window?.performDrag(with: event)
    }
}

private final class AspectLockedWindow: NSWindow {
    private let lockedAspectRatio: CGFloat

    init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        aspectRatio: CGFloat
    ) {
        lockedAspectRatio = aspectRatio
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(Self.frameMaintainingAspectRatio(frameRect, aspectRatio: lockedAspectRatio), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(Self.frameMaintainingAspectRatio(frameRect, aspectRatio: lockedAspectRatio), display: flag, animate: animateFlag)
    }

    private static func frameMaintainingAspectRatio(_ frame: NSRect, aspectRatio: CGFloat) -> NSRect {
        guard aspectRatio > 0 else {
            return frame
        }

        var nextFrame = frame
        nextFrame.size.height = nextFrame.size.width / aspectRatio
        return nextFrame
    }
}
