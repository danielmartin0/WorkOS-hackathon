import AppKit
import OverlayCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: OverlayWindowController?
    private let viewModel = OverlayViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = OverlayRootView(viewModel: viewModel)
        let controller = OverlayWindowController(rootView: rootView)
        windowController = controller

        if let window = controller.window {
            viewModel.attachOverlayWindow(window)
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        viewModel.bootstrap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // No-op for v1. Sidecars are terminated by parent process exit.
    }
}

@main
struct OverlayAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
