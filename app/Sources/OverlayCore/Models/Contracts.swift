import Foundation
import CoreGraphics

public struct TargetWindowInfo: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let ownerName: String
    public let title: String
    public let bounds: CGRect

    public init(id: UInt32, ownerName: String, title: String, bounds: CGRect) {
        self.id = id
        self.ownerName = ownerName
        self.title = title
        self.bounds = bounds
    }

    public var displayName: String {
        if title.isEmpty {
            return "\(ownerName) (\(id))"
        }
        return "\(ownerName) - \(title)"
    }
}

public struct AgentQueryRequest: Codable, Sendable {
    public let prompt: String
    public let sessionId: String?
    public let screenshotPath: String?

    public init(prompt: String, sessionId: String?, screenshotPath: String?) {
        self.prompt = prompt
        self.sessionId = sessionId
        self.screenshotPath = screenshotPath
    }
}

public struct AgentQueryResponse: Codable, Sendable {
    public let text: String
    public let sessionId: String

    public init(text: String, sessionId: String) {
        self.text = text
        self.sessionId = sessionId
    }
}

public enum VoiceClientEvent: Codable, Sendable {
    case sessionStart(sessionId: String?)
    case audioChunk(base64Pcm16: String)
    case sessionStop
}

public enum VoiceServerEvent: Codable, Sendable {
    case transcriptPartial(String)
    case transcriptFinal(String)
    case agentText(String)
    case audioChunk(base64Audio: String)
    case error(message: String)
}

public struct VoiceEnvelope: Codable, Sendable {
    public let type: String
    public let sessionId: String?
    public let text: String?
    public let audioBase64: String?
    public let error: String?

    public init(type: String, sessionId: String? = nil, text: String? = nil, audioBase64: String? = nil, error: String? = nil) {
        self.type = type
        self.sessionId = sessionId
        self.text = text
        self.audioBase64 = audioBase64
        self.error = error
    }
}
