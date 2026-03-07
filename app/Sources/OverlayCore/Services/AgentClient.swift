import Foundation

public actor AgentClient {
    private let endpoint: URL

    public init(endpoint: URL = URL(string: "http://127.0.0.1:5051/agent/query")!) {
        self.endpoint = endpoint
    }

    public func query(prompt: String, sessionId: String?, screenshotPath: String?) async throws -> AgentQueryResponse {
        let payload = AgentQueryRequest(prompt: prompt, sessionId: sessionId, screenshotPath: screenshotPath)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "AgentClient", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        return try JSONDecoder().decode(AgentQueryResponse.self, from: data)
    }
}
