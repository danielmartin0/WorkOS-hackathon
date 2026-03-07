import CoreGraphics
import Foundation
import OverlayCore
import Testing

@Test func convertsCGWindowBoundsToAppKitCoordinates() {
    let cgBounds = CGRect(x: 200, y: 120, width: 500, height: 300)
    let converted = OverlayGeometry.cocoaFrame(fromCGWindowBounds: cgBounds, screenHeight: 1200)

    #expect(converted.origin.x == 200)
    #expect(converted.origin.y == 780)
    #expect(converted.width == 500)
    #expect(converted.height == 300)
}

@Test func agentContractsRoundTrip() throws {
    let request = AgentQueryRequest(prompt: "hello", sessionId: "s1", screenshotPath: "/tmp/p.png")
    let data = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(AgentQueryRequest.self, from: data)

    #expect(decoded.prompt == "hello")
    #expect(decoded.sessionId == "s1")
    #expect(decoded.screenshotPath == "/tmp/p.png")
}
