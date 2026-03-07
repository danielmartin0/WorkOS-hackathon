import AVFoundation
import Foundation

@MainActor
public final class VoiceClient: NSObject {
    public var onEvent: ((VoiceServerEvent) -> Void)?

    private let endpoint: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var player: AVAudioPlayer?
    private var currentSessionId: String?

    public init(endpoint: URL = URL(string: "ws://127.0.0.1:8787/ws/voice")!) {
        self.endpoint = endpoint
    }

    public func connect() {
        guard webSocketTask == nil else { return }
        let task = URLSession.shared.webSocketTask(with: endpoint)
        webSocketTask = task
        task.resume()
        receiveLoop()
    }

    public func disconnect() {
        stopMicrophoneCapture()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    public func startVoiceSession(sessionId: String?) {
        connect()
        currentSessionId = sessionId
        sendEnvelope(VoiceEnvelope(type: "session.start", sessionId: sessionId))
        startMicrophoneCapture()
    }

    public func stopVoiceSession() {
        stopMicrophoneCapture()
        sendEnvelope(VoiceEnvelope(type: "session.stop", sessionId: currentSessionId))
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self.onEvent?(.error(message: error.localizedDescription))
                }
            case .success(let message):
                Task { @MainActor in
                    self.handle(message: message)
                    self.receiveLoop()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let payload):
            text = payload
        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return
        }

        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(VoiceEnvelope.self, from: data) else {
            return
        }

        switch envelope.type {
        case "transcript.partial":
            onEvent?(.transcriptPartial(envelope.text ?? ""))
        case "transcript.final":
            onEvent?(.transcriptFinal(envelope.text ?? ""))
        case "agent.text":
            onEvent?(.agentText(envelope.text ?? ""))
        case "audio.chunk":
            if let b64 = envelope.audioBase64, let data = Data(base64Encoded: b64) {
                playAudio(data: data)
                onEvent?(.audioChunk(base64Audio: b64))
            }
        case "error":
            onEvent?(.error(message: envelope.error ?? "unknown error"))
        default:
            break
        }
    }

    private func sendEnvelope(_ envelope: VoiceEnvelope) {
        guard let payload = try? JSONEncoder().encode(envelope),
              let text = String(data: payload, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(text)) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.onEvent?(.error(message: error.localizedDescription))
                }
            }
        }
    }

    private func startMicrophoneCapture() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self,
                  let pcmData = buffer.toPCM16Data()
            else {
                return
            }
            let envelope = VoiceEnvelope(type: "audio.chunk", sessionId: self.currentSessionId, audioBase64: pcmData.base64EncodedString())
            self.sendEnvelope(envelope)
        }

        do {
            try audioEngine.start()
        } catch {
            onEvent?(.error(message: "Mic start failed: \(error.localizedDescription)"))
        }
    }

    private func stopMicrophoneCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    private func playAudio(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.play()
        } catch {
            onEvent?(.error(message: "Audio playback failed: \(error.localizedDescription)"))
        }
    }
}

private extension AVAudioPCMBuffer {
    func toPCM16Data() -> Data? {
        guard let channelData = floatChannelData else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        let frameCount = Int(frameLength)
        var raw = Data(capacity: frameCount * channelCount * MemoryLayout<Int16>.size)

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let sample = channelData[channel][frame]
                let clamped = max(-1.0, min(1.0, sample))
                var intSample = Int16(clamped * Float(Int16.max))
                withUnsafeBytes(of: &intSample) { bytes in
                    raw.append(contentsOf: bytes)
                }
            }
        }

        return raw
    }
}
