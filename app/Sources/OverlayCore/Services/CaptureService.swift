import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

public enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case windowNotFound
    case failedToEncodeImage

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required to capture the game window."
        case .windowNotFound:
            return "Could not find the selected game window for capture."
        case .failedToEncodeImage:
            return "Failed to encode screenshot image."
        }
    }
}

public enum ScreenPermissionService {
    public static func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public static func requestScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }
}

@MainActor
public final class CaptureService {
    public init() {}

    public func captureWindow(windowID: UInt32, destinationURL: URL) async throws -> URL {
        guard ScreenPermissionService.requestScreenCapturePermission() else {
            throw CaptureError.permissionDenied
        }

        let image: CGImage

        if #available(macOS 14.0, *) {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let target = content.windows.first(where: { UInt32($0.windowID) == windowID }) else {
                throw CaptureError.windowNotFound
            }

            let filter = SCContentFilter(desktopIndependentWindow: target)
            let config = SCStreamConfiguration()
            config.width = Int(target.frame.width)
            config.height = Int(target.frame.height)

            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } else {
            guard let fallbackImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.bestResolution, .boundsIgnoreFraming]
            ) else {
                throw CaptureError.windowNotFound
            }
            image = fallbackImage
        }

        try writePNG(image: image, to: destinationURL)
        return destinationURL
    }

    private func writePNG(image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.failedToEncodeImage
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
    }
}
