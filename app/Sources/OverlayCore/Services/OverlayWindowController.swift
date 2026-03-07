import AppKit
import SwiftUI

public final class OverlayWindow: NSWindow {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

public enum OverlayWindowMetrics {
    public static let panelWidth: CGFloat = 560
    public static let panelHeight: CGFloat = 620
}

private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
public final class OverlayWindowController: NSWindowController {
    private weak var hostingView: NSView?
    private var passthroughTimer: Timer?

    public init<Content: View>(rootView: Content) {
        let panelFrame = CGRect(
            x: 120,
            y: 120,
            width: OverlayWindowMetrics.panelWidth,
            height: OverlayWindowMetrics.panelHeight
        )
        let window = OverlayWindow(
            contentRect: panelFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true

        let hostingView = OverlayHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView
        self.hostingView = hostingView

        super.init(window: window)
        startPassthroughMonitor()
        window.makeKeyAndOrderFront(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startPassthroughMonitor() {
        passthroughTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncMousePassthrough()
            }
        }
        passthroughTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func syncMousePassthrough() {
        guard let window, let contentView = window.contentView else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard window.frame.contains(mouseLocation) else {
            window.ignoresMouseEvents = true
            return
        }

        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
        let contentPoint = contentView.convert(windowPoint, from: nil)
        guard contentView.bounds.contains(contentPoint) else {
            window.ignoresMouseEvents = true
            return
        }

        let hitView = contentView.hitTest(contentPoint)
        let shouldHandle = isInteractiveHitView(hitView, contentView: contentView)
        window.ignoresMouseEvents = !shouldHandle
    }

    private func isInteractiveHitView(_ view: NSView?, contentView: NSView) -> Bool {
        guard let view else { return false }
        if view === contentView || view === hostingView { return false }

        var current: NSView? = view
        while let node = current, node !== contentView {
            if node is NSControl || node is NSTextView || node is NSScrollView || node is NSClipView {
                return true
            }

            if node.gestureRecognizers.isEmpty == false {
                return true
            }

            if node === hostingView {
                break
            }

            current = node.superview
        }

        return false
    }
}
