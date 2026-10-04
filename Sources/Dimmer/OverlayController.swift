import AppKit

/// One borderless black window per screen. Its alpha is the dim intensity;
/// it is ordered directly beneath the focused window in global z-order.
final class OverlayController {
    private var windows: [NSWindow] = []
    private var visible = false

    var windowNumbers: Set<Int> { Set(windows.map { $0.windowNumber }) }

    func rebuild() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows = NSScreen.screens.map { screen in
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                             backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: false)
            w.backgroundColor = .black
            w.isOpaque = false
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .normal
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            w.alphaValue = 0
            return w
        }
        visible = false
    }

    func setIntensity(_ value: Double) {
        guard visible else { return }
        windows.forEach { $0.alphaValue = value }
    }

    /// Put the sheet directly below `windowID` and fade in if needed.
    func show(below windowID: CGWindowID) {
        for w in windows {
            w.order(.below, relativeTo: Int(windowID))
        }
        guard !visible else { return }
        visible = true
        fade(to: Settings.intensity)
    }

    func hide(animated: Bool = true) {
        guard visible || windows.contains(where: { $0.alphaValue > 0 }) else { return }
        visible = false
        if animated {
            fade(to: 0) { [weak self] in
                guard let self, !self.visible else { return }
                self.windows.forEach { $0.orderOut(nil) }
            }
        } else {
            windows.forEach { $0.alphaValue = 0; $0.orderOut(nil) }
        }
    }

    private func fade(to alpha: Double, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            windows.forEach { $0.animator().alphaValue = alpha }
        }, completionHandler: completion)
    }
}
