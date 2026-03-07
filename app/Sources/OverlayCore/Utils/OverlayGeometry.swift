import Foundation
import CoreGraphics

public enum OverlayGeometry {
    // Converts CoreGraphics top-left origin bounds to AppKit bottom-left origin bounds.
    public static func cocoaFrame(fromCGWindowBounds bounds: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: bounds.origin.x,
            y: screenHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }
}
