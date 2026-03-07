import Foundation

@MainActor
public final class SidecarManager {
    private var agentProcess: Process?
    private let appRoot: URL
    private let workspaceRoot: URL

    public init(appRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.appRoot = appRoot
        if appRoot.lastPathComponent == "app" {
            self.workspaceRoot = appRoot.deletingLastPathComponent()
        } else {
            self.workspaceRoot = appRoot
        }
    }

    public func startAll() {
        startAgentSidecar()
    }

    public func stopAll() {
        [agentProcess].forEach { process in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
    }

    private func startAgentSidecar() {
        guard agentProcess == nil || agentProcess?.isRunning == false else { return }

        let process = Process()
        process.currentDirectoryURL = workspaceRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let distFile = appRoot
            .appendingPathComponent("agent-sidecar")
            .appendingPathComponent("dist")
            .appendingPathComponent("index.js")

        if FileManager.default.fileExists(atPath: distFile.path) {
            process.arguments = ["node", distFile.path]
        } else {
            process.arguments = ["npm", "--prefix", "app/agent-sidecar", "run", "dev"]
        }

        var env = ProcessInfo.processInfo.environment
        env["AGENT_WORKDIR"] = workspaceRoot.path
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
}
