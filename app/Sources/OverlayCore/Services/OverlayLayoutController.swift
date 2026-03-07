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
        let screenHeight = NSScreen.main?.frame.height ?? bounds.height
        let targetFrame = OverlayGeometry.cocoaFrame(fromCGWindowBounds: bounds, screenHeight: screenHeight)
        window.setFrame(targetFrame, display: true)
    }
}
