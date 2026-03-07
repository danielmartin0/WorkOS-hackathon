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
        let gameFrame = OverlayGeometry.cocoaFrame(fromCGWindowBounds: bounds, screenHeight: desktopTop)
        let panelSize = window.frame.size
        let inset: CGFloat = 20

        var targetX = gameFrame.minX + inset
        var targetY = gameFrame.maxY - panelSize.height - inset

        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(gameFrame) }) {
            let visible = screen.visibleFrame
            targetX = max(visible.minX, min(targetX, visible.maxX - panelSize.width))
            targetY = max(visible.minY, min(targetY, visible.maxY - panelSize.height))
        }

        let panelFrame = CGRect(
            x: targetX,
            y: targetY,
            width: panelSize.width,
            height: panelSize.height
        )

        window.setFrame(panelFrame, display: true)
    }
}
