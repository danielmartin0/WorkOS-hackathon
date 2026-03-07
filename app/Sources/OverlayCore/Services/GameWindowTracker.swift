import Foundation
import CoreGraphics

@MainActor
public final class GameWindowTracker: ObservableObject {
    @Published public private(set) var windows: [TargetWindowInfo] = []
    @Published public var selectedWindowID: UInt32?

    private var trackingTimer: Timer?
    private var lastTrackedBounds: CGRect?

    public init() {}

    public func refreshWindowList(excludingOwnerName ownerName: String = "OverlayApp") {
        let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        guard let infoList = rawList as? [[String: Any]] else {
            windows = []
            return
        }

        let mapped: [TargetWindowInfo] = infoList.compactMap { item in
            guard
                let number = item[kCGWindowNumber as String] as? UInt32,
                let layer = item[kCGWindowLayer as String] as? Int,
                layer == 0,
                let owner = item[kCGWindowOwnerName as String] as? String,
                owner != ownerName,
                let boundsDict = item[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                bounds.width > 80,
                bounds.height > 80
            else {
                return nil
            }

            let title = (item[kCGWindowName as String] as? String) ?? ""
            return TargetWindowInfo(id: number, ownerName: owner, title: title, bounds: bounds)
        }

        windows = mapped.sorted { lhs, rhs in
            lhs.ownerName.localizedCaseInsensitiveCompare(rhs.ownerName) == .orderedAscending
        }

        if let selectedWindowID, windows.contains(where: { $0.id == selectedWindowID }) == false {
            self.selectedWindowID = nil
            stopTracking()
        }
    }

    public func frame(for windowID: UInt32) -> CGRect? {
        let rawList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID)
        guard
            let infoList = rawList as? [[String: Any]],
            let info = infoList.first,
            let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else {
            return nil
        }
        return bounds
    }

    public func startTracking(windowID: UInt32, frameDidChange: @escaping @MainActor (CGRect) -> Void) {
        selectedWindowID = windowID
        lastTrackedBounds = nil
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let bounds = self.frame(for: windowID) else { return }
                if self.isMeaningfullyDifferent(bounds, self.lastTrackedBounds) == false {
                    return
                }
                self.lastTrackedBounds = bounds
                frameDidChange(bounds)
            }
        }
    }

    public func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        lastTrackedBounds = nil
    }

    private func isMeaningfullyDifferent(_ lhs: CGRect, _ rhs: CGRect?) -> Bool {
        guard let rhs else { return true }
        let epsilon: CGFloat = 1.0
        return abs(lhs.origin.x - rhs.origin.x) > epsilon
            || abs(lhs.origin.y - rhs.origin.y) > epsilon
            || abs(lhs.width - rhs.width) > epsilon
            || abs(lhs.height - rhs.height) > epsilon
    }
}
