import AppKit
import ApplicationServices

// Private but long-stable HIServices call mapping an AX window to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

private let axCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue().scheduleUpdate()
}

/// Event-driven focus tracking: workspace notifications + one AXObserver on the
/// frontmost app. No timers, no polling.
final class FocusTracker {
    private let overlay: OverlayController
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var pending = false
    private(set) var isRunning = false

    private static let axNotes: [String] = [
        kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
        kAXWindowMovedNotification, kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification, kAXUIElementDestroyedNotification,
    ]

    init(overlay: OverlayController) { self.overlay = overlay }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appActivated),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(scheduleUpdate),
                       name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        attach(to: NSWorkspace.shared.frontmostApplication)
        scheduleUpdate()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        detach()
    }

    func refresh() { if isRunning { scheduleUpdate() } }

    @objc private func appActivated(_ n: Notification) {
        let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        attach(to: app ?? NSWorkspace.shared.frontmostApplication)
        scheduleUpdate()
    }

    // MARK: AX observer

    private func detach() {
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        observer = nil
        observedPID = 0
    }

    private func attach(to app: NSRunningApplication?) {
        guard let app, app.processIdentifier != getpid() else { return }
        let pid = app.processIdentifier
        if pid == observedPID, observer != nil { return }
        detach()
        var obs: AXObserver?
        guard AXObserverCreate(pid, axCallback, &obs) == .success, let obs else { return }
        let appEl = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for note in Self.axNotes {
            _ = AXObserverAddNotification(obs, appEl, note as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observer = obs
        observedPID = pid
    }

    // MARK: Coalesced update

    /// At most one reorder per runloop turn.
    @objc func scheduleUpdate() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending = false
            self.update()
        }
    }

    private func update() {
        guard isRunning else { return }
        let front = NSWorkspace.shared.frontmostApplication
        log.debug("update front=\(front?.localizedName ?? "-", privacy: .public) pid=\(front?.processIdentifier ?? 0, privacy: .public) observed=\(self.observedPID, privacy: .public)")
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid(),
              let win = focusedWindow(pid: app.processIdentifier),
              !overlay.windowNumbers.contains(Int(win.id)) else {
            overlay.hide()
            return
        }
        // Only look up the window's display when it's needed: "focused display
        // only" is on, or the window is full screen and its display must stay clear.
        let display = (Settings.onlyFocusedDisplay || win.fullScreen) ? Displays.uuid(ofWindow: win.id) : nil
        if win.fullScreen && display == nil {
            // Can't tell which display is full screen; never risk blacking it out.
            log.debug("full-screen window \(win.id, privacy: .public) on unknown display")
            overlay.hide()
            return
        }
        overlay.show(below: win.id, focusedDisplay: Settings.onlyFocusedDisplay ? display : nil,
                     skipDisplay: win.fullScreen ? display : nil)
    }

    private func focusedWindow(pid: pid_t) -> (id: CGWindowID, fullScreen: Bool)? {
        guard let win = focusedWindowElement(pid: pid) else { return nil }
        // "AXFullScreen" has no public constant but is set on full-screen windows.
        var fs: CFTypeRef?
        let fullScreen = AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fs) == .success
            && (fs as? Bool) == true

        var wid: CGWindowID = 0
        if _AXUIElementGetWindow(win, &wid) == .success, wid != 0 { return (wid, fullScreen) }
        return fallbackWindowID(pid: pid, element: win).map { ($0, fullScreen) }
    }

    private func focusedWindowElement(pid: pid_t) -> AXUIElement? {
        let appEl = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &value)
        guard err == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            log.debug("no focused window pid=\(pid, privacy: .public) err=\(err.rawValue, privacy: .public)")
            return nil
        }
        let win = value as! AXUIElement

        // Minimized windows are not on screen; nothing to preserve.
        var min: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &min) == .success,
           (min as? Bool) == true { return nil }
        return win
    }

    /// Match by owner pid + bounds when the private call fails.
    private func fallbackWindowID(pid: pid_t, element: AXUIElement) -> CGWindowID? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef,
              AXValueGetValue(posRef as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        let target = CGRect(origin: pos, size: size)
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let b = info[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary),
                  abs(r.minX - target.minX) < 2, abs(r.minY - target.minY) < 2,
                  abs(r.width - target.width) < 2, abs(r.height - target.height) < 2,
                  let n = info[kCGWindowNumber as String] as? Int else { continue }
            return CGWindowID(n)
        }
        return nil
    }
}
