import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayController()
    private lazy var tracker = FocusTracker(overlay: overlay)
    private var menu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt once at launch; afterwards the menu item guides the user.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        menu = StatusMenu(
            onToggle: { [weak self] in self?.applyEnabled() },
            onIntensity: { [weak self] in self?.overlay.setIntensity(Settings.intensity) }
        )

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Re-check trust whenever any app activates (no polling timer). Tracker
        // also listens to this for AX observer rebuilds.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        overlay.rebuild()
        applyEnabled()
    }

    private func applyEnabled() {
        if Settings.enabled && AXIsProcessTrusted() {
            tracker.start()
        } else {
            tracker.stop()
            overlay.hide(animated: false)
        }
    }

    @objc private func screensChanged() {
        overlay.rebuild()
        tracker.refresh()
    }

    @objc private func appActivated() {
        menu.refreshTrust()
        // If trust was just granted (or revoked), start/stop accordingly.
        if Settings.enabled, AXIsProcessTrusted() != tracker.isRunning { applyEnabled() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
    }
}
