import AppKit
import Foundation

@MainActor
public final class OverlayViewModel: ObservableObject {
    @Published public var availableWindows: [TargetWindowInfo] = []
    @Published public var selectedWindowID: UInt32?
    @Published public var promptText: String = ""
    @Published public var chatLines: [String] = []
    @Published public var statusLine: String = "AdaL idle"

    private let tracker = GameWindowTracker()
    private let layoutController = OverlayLayoutController()
    private let adalBridge: AdalTerminalBridge

    public init() {
        adalBridge = AdalTerminalBridge()

        adalBridge.onOutput = { [weak self] text, isError in
            DispatchQueue.main.async {
                self?.appendTerminalOutput(text: text, isError: isError)
            }
        }

        adalBridge.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.applyState(state)
            }
        }
    }

    public func attachOverlayWindow(_ window: NSWindow) {
        layoutController.bind(window: window)
    }

    public func bootstrap() {
        refreshWindows()
        startAdal()
    }

    public func refreshWindows() {
        tracker.refreshWindowList()
        availableWindows = tracker.windows

        if let selectedWindowID, availableWindows.contains(where: { $0.id == selectedWindowID }) == false {
            self.selectedWindowID = nil
        }
    }

    public func chooseWindow(windowID: UInt32) {
        selectedWindowID = windowID
        tracker.startTracking(windowID: windowID) { [weak self] bounds in
            self?.layoutController.updateOverlayFrame(usingCGWindowBounds: bounds)
        }
    }

    public func startAdal() {
        adalBridge.startIfNeeded()
    }

    public func restartAdal() {
        adalBridge.restart()
    }

    public func stopAdal() {
        adalBridge.stop()
    }

    public func sendPrompt() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        chatLines.append("You: \(trimmed)")
        promptText = ""
        adalBridge.sendMessage(trimmed)
    }

    private func appendTerminalOutput(text: String, isError: Bool) {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            chatLines.append("\(isError ? "AdaL !" : "AdaL"): \(line)")
        }

        if chatLines.count > 400 {
            chatLines.removeFirst(chatLines.count - 400)
        }
    }

    private func applyState(_ state: AdalTerminalBridge.State) {
        switch state {
        case .idle:
            statusLine = "AdaL idle"
        case .starting:
            statusLine = "Starting AdaL..."
        case .running(let pid):
            statusLine = "AdaL running (pid: \(pid))"
        case .stopped(let code):
            statusLine = "AdaL stopped (exit: \(code))"
        case .failed(let message):
            statusLine = message
            chatLines.append("AdaL !: \(message)")
        }
    }
}
