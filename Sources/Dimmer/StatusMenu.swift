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

    init(onToggle: @escaping () -> Void, onIntensity: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onIntensity = onIntensity
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
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        refreshTrust()
    }

    func refreshTrust() { grantItem.isHidden = AXIsProcessTrusted() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshTrust()
        enabledItem.state = Settings.enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        slider.doubleValue = Settings.intensity
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
