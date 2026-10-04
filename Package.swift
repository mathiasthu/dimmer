// swift-tools-version:5.10
import PackageDescription

// Dimmer: menu bar agent, plain AppKit (no SwiftUI). Built into an .app by
// scripts/build-app.sh; the bare executable works but shows a Dock icon.
let package = Package(
    name: "dimmer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Dimmer", targets: ["Dimmer"])],
    targets: [.executableTarget(name: "Dimmer")]
)
