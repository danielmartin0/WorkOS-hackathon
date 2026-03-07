import Foundation

@MainActor
public final class SidecarManager {
    private var agentProcess: Process?
    private var voiceProcess: Process?
    private let appRoot: URL

    public init(appRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.appRoot = appRoot
    }

    public func startAll() {
        startAgentSidecar()
        startVoiceSidecar()
    }

    public func stopAll() {
        [agentProcess, voiceProcess].forEach { process in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
    }

    private func startAgentSidecar() {
        guard agentProcess == nil || agentProcess?.isRunning == false else { return }

        let process = Process()
        process.currentDirectoryURL = appRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let distFile = appRoot
            .appendingPathComponent("agent-sidecar")
            .appendingPathComponent("dist")
            .appendingPathComponent("index.js")

        if FileManager.default.fileExists(atPath: distFile.path) {
            process.arguments = ["node", distFile.path]
        } else {
            process.arguments = ["npm", "--prefix", "agent-sidecar", "run", "dev"]
        }

        var env = ProcessInfo.processInfo.environment
        env["AGENT_WORKDIR"] = appRoot.path
        process.environment = env
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            agentProcess = process
        } catch {
            print("Failed to start agent sidecar: \(error.localizedDescription)")
        }
    }

    private func startVoiceSidecar() {
        guard voiceProcess == nil || voiceProcess?.isRunning == false else { return }

        let process = Process()
        process.currentDirectoryURL = appRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "voice-sidecar/main.py"]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            voiceProcess = process
        } catch {
            print("Failed to start voice sidecar: \(error.localizedDescription)")
        }
    }
}
