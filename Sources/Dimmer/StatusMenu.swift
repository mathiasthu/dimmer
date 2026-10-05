import AppKit
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
    private let grantItem = NSMenuItem(title: "Grant Accessibility access…", action: #selector(openAccessibility), keyEquivalent: "")
    private let slider = NSSlider(value: 0.35, minValue: Settings.minIntensity, maxValue: Settings.maxIntensity,
                                  target: nil, action: nil)
    private let onToggle: () -> Void
    private let onIntensity: () -> Void
    private let onDisplays: () -> Void
    private let displaysMenu = NSMenu()

    init(onToggle: @escaping () -> Void, onIntensity: @escaping () -> Void, onDisplays: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onIntensity = onIntensity
        self.onDisplays = onDisplays
        super.init()

        item.button?.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Dimmer")

        for i in [enabledItem, loginItem, grantItem] { i.target = self }
        menu.delegate = self

        let label = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        label.isEnabled = false

        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        slider.doubleValue = Settings.intensity
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        slider.frame = NSRect(x: 16, y: 4, width: 168, height: 20)
        host.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = host

        menu.addItem(grantItem)
        menu.addItem(enabledItem)
        menu.addItem(.separator())
        menu.addItem(label)
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        let displaysItem = NSMenuItem(title: "Displays", action: nil, keyEquivalent: "")
        displaysItem.submenu = displaysMenu
        menu.addItem(displaysItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        refreshTrust()
        rebuildDisplays()
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildDisplays),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func refreshTrust() { grantItem.isHidden = AXIsProcessTrusted() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshTrust()
        enabledItem.state = Settings.enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        slider.doubleValue = Settings.intensity
        rebuildDisplays()
    }

    /// One checkbox per connected display, then the focused-display-only option.
    @objc private func rebuildDisplays() {
        displaysMenu.removeAllItems()
        let off = Settings.disabledDisplays
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID else { continue }
            let i = NSMenuItem(title: screen.localizedName, action: #selector(toggleDisplay(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = uuid
            i.state = off.contains(uuid) ? .off : .on
            displaysMenu.addItem(i)
        }
        displaysMenu.addItem(.separator())
        let only = NSMenuItem(title: "Only the display with the focused window",
                              action: #selector(toggleOnlyFocused), keyEquivalent: "")
        only.target = self
        only.state = Settings.onlyFocusedDisplay ? .on : .off
        displaysMenu.addItem(only)
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        if Settings.disabledDisplays.contains(uuid) { Settings.disabledDisplays.remove(uuid) }
        else { Settings.disabledDisplays.insert(uuid) }
        sender.state = Settings.disabledDisplays.contains(uuid) ? .off : .on
        onDisplays()
    }

    @objc private func toggleOnlyFocused(_ sender: NSMenuItem) {
        Settings.onlyFocusedDisplay.toggle()
        sender.state = Settings.onlyFocusedDisplay ? .on : .off
        onDisplays()
    }

    @objc private func toggleEnabled() {
        Settings.enabled.toggle()
        onToggle()
    }

    @objc private func sliderChanged() {
        Settings.intensity = slider.doubleValue
        onIntensity()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Dimmer: launch-at-login change failed: \(error)")
        }
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
