import AppKit
import Foundation

@MainActor
public final class OverlayViewModel: ObservableObject {
    @Published public var availableWindows: [TargetWindowInfo] = []
    @Published public var selectedWindowID: UInt32?

    @Published public var adalSessions: [AdalSession] = []
    @Published public var selectedAdalSessionID: String?

    @Published public var promptText: String = ""
    @Published public var chatLines: [String] = []
    @Published public var statusLine: String = "No AdaL terminal attached"

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
        refreshAdalSessions()
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

    public func refreshAdalSessions() {
        do {
            let sessions = try adalBridge.listSessions()
            adalSessions = sessions

            if let selectedAdalSessionID,
               adalSessions.contains(where: { $0.id == selectedAdalSessionID }) {
                return
            }

            selectedAdalSessionID = adalSessions.first?.id
        } catch {
            statusLine = "Failed to list adal terminals"
            chatLines.append("AdaL !: Failed to list terminals: \(error.localizedDescription)")
        }
    }

    public func selectAdalSession(id: String) {
        selectedAdalSessionID = id
        if id.isEmpty == false {
            attachSelectedSession()
        }
    }

    public func attachSelectedSession() {
        guard let selectedAdalSessionID,
              let session = adalSessions.first(where: { $0.id == selectedAdalSessionID }) else {
            statusLine = "Select an AdaL session"
            return
        }

        adalBridge.attach(to: session)
    }

    public func detachSession() {
        adalBridge.detach()
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

        if chatLines.count > 500 {
            chatLines.removeFirst(chatLines.count - 500)
        }
    }

    private func applyState(_ state: AdalTerminalBridge.State) {
        switch state {
        case .idle:
            statusLine = "No AdaL terminal attached"
        case .attached(let sessionID):
            let title = adalSessions.first(where: { $0.id == sessionID })?.title ?? sessionID
            statusLine = "Attached: \(title)"
        case .detached:
            statusLine = "Detached"
        case .failed(let message):
            statusLine = message
            chatLines.append("AdaL !: \(message)")
        }
    }
}
