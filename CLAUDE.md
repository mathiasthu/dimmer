# CLAUDE.md

Dimmer is a macOS menu bar app (Swift, plain AppKit) that dims everything except the focused window. Read `HANDOFF.md` first for current state, known gaps and next steps.

## Building

- Builds need macOS: `scripts/build-app.sh` (universal binary, ad-hoc signed, writes `dist/Dimmer.app` and `dist/Dimmer.zip`), then `scripts/install.sh` to copy it to `~/Applications`.
- **Cloud and Linux sessions cannot build or run this app.** AppKit, ApplicationServices and CoreGraphics don't exist on Linux, so `swift build` fails there. That's expected, not a bug. In a cloud session, edit the code and commit on a branch, then note in HANDOFF.md that the change still needs a build and a live test on the Mac.
- Verifying a change means running it with Accessibility granted on a real Mac. Reinstalling an ad-hoc-signed build drops the Accessibility grant, so the user has to remove and re-add Dimmer in System Settings › Privacy & Security › Accessibility.

## Code rules

- Plain AppKit only. No SwiftUI: its `@State` macro plugin doesn't compile on the owner's toolchain.
- Event-driven only: AXObserver plus NSWorkspace notifications, coalesced to one update per run-loop turn. No timers, no polling. Low CPU use is the point of the app (idle target 0.0% CPU, about 15 to 25 MB).
- `OverlayWindow` must keep overriding `_canBeSnappingTarget` to return false. Without it, macOS window edge snapping breaks while Dimmer runs.
- Debug logging uses `os.Logger` (subsystem `com.mathiass.dimmer`). Read it with `log stream --level debug --predicate 'subsystem == "com.mathiass.dimmer"'`.

## Releasing

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `scripts/Info.plist`, build on the Mac, push, then run `gh release create vX.Y.Z dist/Dimmer.zip`. Releases can't be built from a cloud session.
