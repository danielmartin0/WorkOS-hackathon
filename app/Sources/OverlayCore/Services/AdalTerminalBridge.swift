import Foundation

public struct AdalSession: Identifiable, Hashable, Sendable {
    public let pid: Int32
    public let tty: String
    public let command: String

    public init(pid: Int32, tty: String, command: String) {
        self.pid = pid
        self.tty = tty
        self.command = command
    }

    public var id: String {
        "\(pid)-\(tty)"
    }

    public var devicePath: String {
        "/dev/\(tty)"
    }

    public var title: String {
        "pid \(pid) • \(tty)"
    }
}

public final class AdalTerminalBridge: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case attached(sessionID: String)
        case detached
        case failed(message: String)
    }

    public var onOutput: (@Sendable (String, Bool) -> Void)?
    public var onStateChange: (@Sendable (State) -> Void)?

    private var monitorProcess: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var attachedSession: AdalSession?

    public init() {}

    public func listSessions() throws -> [AdalSession] {
        let output = try runCommand(["/bin/zsh", "-lc", "ps -axo pid=,tty=,command="])
        let sessions = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseSessionLine(String($0)) }
            .filter { session in
                session.command.localizedCaseInsensitiveContains("adal")
                    && session.tty != "?"
                    && session.tty != "??"
            }
            .sorted { lhs, rhs in
                lhs.pid > rhs.pid
            }

        return sessions
    }

    public func attach(to session: AdalSession) {
        if attachedSession?.id == session.id, monitorProcess?.isRunning == true {
            return
        }

        detach()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tail", "-n", "0", "-f", session.devicePath]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputCallback = self.onOutput
        let stateCallback = self.onStateChange

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard data.isEmpty == false,
                  let text = String(data: data, encoding: .utf8),
                  text.isEmpty == false
            else {
                return
            }
            outputCallback?(text, false)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard data.isEmpty == false,
                  let text = String(data: data, encoding: .utf8),
                  text.isEmpty == false
            else {
                return
            }
            outputCallback?(text, true)
        }

        process.terminationHandler = { [weak self] _ in
            self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
            self?.monitorProcess = nil
            self?.stdoutPipe = nil
            self?.stderrPipe = nil
        }

        do {
            try process.run()
            self.attachedSession = session
            self.monitorProcess = process
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            stateCallback?(.attached(sessionID: session.id))
            outputCallback?("[adal] attached to \(session.title)", false)
        } catch {
            stateCallback?(.failed(message: "Failed to attach to \(session.devicePath): \(error.localizedDescription)"))
        }
    }

    public func detach() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if let monitorProcess, monitorProcess.isRunning {
            monitorProcess.terminate()
        }

        attachedSession = nil
        monitorProcess = nil
        stdoutPipe = nil
        stderrPipe = nil

        onStateChange?(.detached)
    }

    public func sendMessage(_ message: String) {
        guard let attachedSession else {
            onStateChange?(.failed(message: "No AdaL terminal attached"))
            return
        }

        let payload = message + "\n"
        guard let data = payload.data(using: .utf8) else {
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: attachedSession.devicePath))
            try handle.seekToEnd()
            handle.write(data)
            try handle.close()
        } catch {
            onStateChange?(.failed(message: "Failed writing to \(attachedSession.devicePath): \(error.localizedDescription)"))
        }
    }

    private func runCommand(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseSessionLine(_ line: String) -> AdalSession? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let parts = trimmed.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
        guard parts.count == 3,
              let pid = Int32(parts[0])
        else {
            return nil
        }

        let tty = String(parts[1])
        let command = String(parts[2])

        return AdalSession(pid: pid, tty: tty, command: command)
    }
}
