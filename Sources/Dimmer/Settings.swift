import Foundation

/// Persisted user settings (UserDefaults).
enum Settings {
    static let minIntensity = 0.10
    static let maxIntensity = 0.80
    private static let d = UserDefaults.standard

    static var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }

    /// Overlay alpha, clamped to the slider range.
    static var intensity: Double {
        get {
            let v = d.object(forKey: "intensity") as? Double ?? 0.35
            return min(max(v, minIntensity), maxIntensity)
        }
        set { d.set(min(max(newValue, minIntensity), maxIntensity), forKey: "intensity") }
    }

    /// UUIDs of displays the user switched off. Unknown displays dim by default.
    static var disabledDisplays: Set<String> {
        get { Set(d.stringArray(forKey: "disabledDisplays") ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: "disabledDisplays") }
    }

    /// Dim only the display that holds the focused window.
    static var onlyFocusedDisplay: Bool {
        get { d.bool(forKey: "onlyFocusedDisplay") }
        set { d.set(newValue, forKey: "onlyFocusedDisplay") }
    }
}
