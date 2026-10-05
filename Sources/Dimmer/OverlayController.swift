import AppKit
import os

let log = Logger(subsystem: "com.mathiass.dimmer", category: "dim")

/// The overlay covers every window behind the focused one. As a normal window it
/// would count as a snapping target, so macOS stops snapping dragged or resized
/// windows to the edges of neighbours hidden beneath it. Opting out through
/// AppKit's private hook restores edge snapping (HazeOver does the same).
private final class OverlayWindow: NSWindow {
    @objc(_canBeSnappingTarget) var canBeSnappingTarget: Bool { false }
}

/// One borderless black window per screen. Its alpha is the dim intensity;
/// it is ordered directly beneath the focused window in global z-order.
/// Each overlay fades in and out on its own, so single displays can be skipped.
final class OverlayController {
    private final class Overlay {
        let window: NSWindow
        let displayUUID: String?
        var dimmed = false
        init(window: NSWindow, displayUUID: String?) { self.window = window; self.displayUUID = displayUUID }
    }

    private var overlays: [Overlay] = []

    var windowNumbers: Set<Int> { Set(overlays.map { $0.window.windowNumber }) }

    func rebuild() {
        overlays.forEach { $0.window.orderOut(nil); $0.window.close() }
        overlays = NSScreen.screens.map { screen in
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
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
            return Overlay(window: w, displayUUID: screen.displayUUID)
        }
    }

    func setIntensity(_ value: Double) {
        overlays.filter(\.dimmed).forEach { $0.window.alphaValue = value }
    }

    /// Whether this display should be dimmed right now. `focusedDisplay` is only
    /// supplied when "focused display only" is on; if it couldn't be resolved
    /// (nil), every enabled display dims rather than none.
    private func wantsDim(_ o: Overlay, focusedDisplay: String?) -> Bool {
        guard let uuid = o.displayUUID, !Settings.disabledDisplays.contains(uuid) else { return false }
        if Settings.onlyFocusedDisplay, let focused = focusedDisplay { return uuid == focused }
        return true
    }

    /// Put the sheets directly below `windowID`, fading in or out per display.
    func show(below windowID: CGWindowID, focusedDisplay: String? = nil) {
        for o in overlays {
            if wantsDim(o, focusedDisplay: focusedDisplay) {
                o.window.order(.below, relativeTo: Int(windowID))
                if !o.dimmed {
                    o.dimmed = true
                    fade(o, to: Settings.intensity)
                }
            } else {
                dimOff(o, animated: true)
            }
        }
        log.debug("show below \(windowID, privacy: .public) dimmed=\(self.overlays.map { $0.dimmed }, privacy: .public) onActiveSpace=\(self.overlays.map { $0.window.isOnActiveSpace }, privacy: .public) isVisible=\(self.overlays.map { $0.window.isVisible }, privacy: .public)")
    }

    func hide(animated: Bool = true) {
        log.debug("hide animated=\(animated, privacy: .public)")
        overlays.forEach { dimOff($0, animated: animated) }
    }

    private func dimOff(_ o: Overlay, animated: Bool) {
        guard o.dimmed || o.window.alphaValue > 0 || o.window.isVisible else { return }
        o.dimmed = false
        if animated {
            fade(o, to: 0) { [weak o] in
                guard let o, !o.dimmed else { return }
                o.window.orderOut(nil)
            }
        } else {
            o.window.alphaValue = 0
            o.window.orderOut(nil)
        }
    }

    private func fade(_ o: Overlay, to alpha: Double, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            o.window.animator().alphaValue = alpha
        }, completionHandler: completion)
    }
}
