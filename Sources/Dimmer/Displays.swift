import AppKit

/// Display identity and window-to-display geometry.
extension NSScreen {
    /// Stable per-display UUID (survives replugging and reboots), unlike CGDirectDisplayID.
    var displayUUID: String? {
        guard let num = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cf = CGDisplayCreateUUIDFromDisplayID(num.uint32Value)?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, cf) else { return nil }
        return str as String
    }

    /// Frame in CG coordinates (origin top-left of the primary display, y down).
    /// NSScreen frames are bottom-left based; the primary display is `screens[0]`.
    var cgFrame: CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}

enum Displays {
    /// UUID of the display holding the largest part of a CG-coordinate rect.
    static func uuid(containing cgRect: CGRect) -> String? {
        var best: (area: CGFloat, uuid: String?) = (0, nil)
        for screen in NSScreen.screens {
            let r = screen.cgFrame.intersection(cgRect)
            let area = r.isNull ? 0 : r.width * r.height
            if area > best.area { best = (area, screen.displayUUID) }
        }
        return best.uuid
    }

    /// Display of a single window, from its on-screen bounds.
    static func uuid(ofWindow id: CGWindowID) -> String? {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?.first,
              let b = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { return nil }
        return uuid(containing: rect)
    }
}
