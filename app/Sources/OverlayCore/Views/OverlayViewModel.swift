import AppKit
import Combine
import Foundation

@MainActor
public final class OverlayViewModel: ObservableObject {
    @Published public var availableWindows: [TargetWindowInfo] = []
    @Published public var selectedWindowID: UInt32?
    @Published public var promptText: String = ""
    @Published public var chatLines: [String] = []
    @Published public var statusLine: String = "Idle"
    @Published public var permissionWarning: String?
    @Published public var periodicCaptureEnabled: Bool = false
    @Published public var periodicCaptureSeconds: Double = 5
    @Published public var lastCapturedPath: String?

    private var periodicTimer: Timer?
    private var sessionId: String?

    private let tracker = GameWindowTracker()
    private let layoutController = OverlayLayoutController()
    private let captureService = CaptureService()
    private let sidecarManager = SidecarManager()
    private let agentClient = AgentClient()
    public init() {}

    public func attachOverlayWindow(_ window: NSWindow) {
        layoutController.bind(window: window)
    }

    public func bootstrap() {
        sidecarManager.startAll()
        refreshWindows()
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

    public func captureNow() {
        guard let selectedWindowID else {
            statusLine = "Select a game window first"
            return
        }

        Task {
            do {
                let timestamp = Int(Date().timeIntervalSince1970)
                let captureRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("captures", isDirectory: true)
                let fileURL = captureRoot
                    .appendingPathComponent("window-\(selectedWindowID)-\(timestamp).png")

                let saved = try await captureService.captureWindow(windowID: selectedWindowID, destinationURL: fileURL)
                lastCapturedPath = saved.path
                statusLine = "Captured screenshot"
            } catch CaptureError.permissionDenied {
                permissionWarning = "Grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording."
                statusLine = "Capture permission denied"
            } catch {
                statusLine = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    public func togglePeriodicCapture() {
        periodicCaptureEnabled.toggle()
        periodicTimer?.invalidate()

        guard periodicCaptureEnabled else {
            statusLine = "Periodic capture disabled"
            return
        }

        periodicTimer = Timer.scheduledTimer(withTimeInterval: periodicCaptureSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureNow()
            }
        }
        statusLine = "Periodic capture enabled"
    }

    public func sendPrompt() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        chatLines.append("You: \(trimmed)")
        promptText = ""
        statusLine = "Querying agent..."

        Task {
            do {
                let response = try await agentClient.query(prompt: trimmed, sessionId: sessionId, screenshotPath: lastCapturedPath)
                sessionId = response.sessionId
                chatLines.append("Agent: \(response.text)")
                statusLine = "Ready"
            } catch {
                chatLines.append("Agent error: \(error.localizedDescription)")
                statusLine = "Agent request failed"
            }
        }
    }
}
