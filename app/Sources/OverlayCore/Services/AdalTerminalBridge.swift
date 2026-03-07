import Foundation

public final class AdalTerminalBridge: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case starting
        case running(pid: Int32)
        case stopped(exitCode: Int32)
        case failed(message: String)
    }

    public var onOutput: (@Sendable (String, Bool) -> Void)?
    public var onStateChange: (@Sendable (State) -> Void)?

    private let command: String
    private let workingDirectory: URL

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    public init(
        command: String = ProcessInfo.processInfo.environment["ADAL_COMMAND"] ?? "adal",
        workingDirectory: URL? = nil
    ) {
        self.command = command
        self.workingDirectory = workingDirectory ?? AdalTerminalBridge.defaultWorkingDirectory()
        self.onStateChange?(.idle)
    }

    public func startIfNeeded() {
        if let process, process.isRunning {
            return
        }
        start()
    }

    public func restart() {
        stop()
        start()
    }

    public func sendMessage(_ message: String) {
        startIfNeeded()
        guard let stdinPipe else {
            onStateChange?(.failed(message: "AdaL stdin unavailable"))
            return
        }

        guard let payload = (message + "\n").data(using: .utf8) else {
            return
        }

        stdinPipe.fileHandleForWriting.write(payload)
    }

    public func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if let process, process.isRunning {
            process.terminate()
        }

        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        onStateChange?(.idle)
    }

    private func start() {
        onStateChange?(.starting)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = workingDirectory

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputCallback = self.onOutput
        let outputHandler: (FileHandle, Bool) -> Void = { handle, isError in
            handle.readabilityHandler = { source in
                let data = source.availableData
                guard data.isEmpty == false,
                      let text = String(data: data, encoding: .utf8),
                      text.isEmpty == false
                else {
                    return
                }
                outputCallback?(text, isError)
            }
        }

        outputHandler(stdoutPipe.fileHandleForReading, false)
        outputHandler(stderrPipe.fileHandleForReading, true)

        process.terminationHandler = { [weak self] proc in
            self?.onStateChange?(.stopped(exitCode: proc.terminationStatus))
            self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
            self?.process = nil
            self?.stdinPipe = nil
            self?.stdoutPipe = nil
            self?.stderrPipe = nil
        }

        do {
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            onStateChange?(.running(pid: process.processIdentifier))
            onOutput?("[adal] started in \(workingDirectory.path)", false)
        } catch {
            onStateChange?(.failed(message: "Failed to launch adal: \(error.localizedDescription)"))
        }
    }

    private static func defaultWorkingDirectory() -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let workspaceRoot = cwd.lastPathComponent == "app" ? cwd.deletingLastPathComponent() : cwd
        return workspaceRoot.appendingPathComponent("mod")
    }
}
