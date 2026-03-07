import AppKit

@MainActor
public final class OverlayLayoutController {
    private weak var window: NSWindow?

    public init() {}

    public func bind(window: NSWindow) {
        self.window = window
    }

    public func updateOverlayFrame(usingCGWindowBounds bounds: CGRect) {
        guard let window else { return }
        let desktopTop = NSScreen.screens.map { $0.frame.maxY }.max() ?? bounds.maxY
        let targetFrame = OverlayGeometry.cocoaFrame(fromCGWindowBounds: bounds, screenHeight: desktopTop)
        window.setFrame(targetFrame, display: true)
    }
}
