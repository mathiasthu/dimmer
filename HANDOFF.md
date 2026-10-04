# Dimmer HANDOFF

## State (2026-10-04)
v1 written and built. Menu bar agent (LSUIElement, `com.mathiass.dimmer`), one black overlay window per screen ordered directly beneath the focused window via `order(.below, relativeTo:)`. Focus tracked by NSWorkspace notifications plus one AXObserver on the frontmost app; updates coalesced to one per runloop turn; fades via NSAnimationContext (0.15s). Settings in UserDefaults: enabled, intensity (0.10-0.80, default 0.35). Launch at login via SMAppService, default off.

Files: `Sources/Dimmer/{main,AppDelegate,OverlayController,FocusTracker,StatusMenu,Settings}.swift`, `scripts/{build-app,install}.sh`, `scripts/Info.plist`.

## Verified
- `swift build -c release` succeeds. Only warnings are two linker "search path not found" lines from the local CommandLineTools toolchain.
- build-app.sh produces an ad-hoc signed bundle (`codesign -dv` ok).
- Idle, without Accessibility permission (no overlay shown): CPU 0.0% for 60s, idle wakeups 0, `top` MEM 15M; `ps` RSS about 49 MB (counts shared system frameworks).

- 2026-10-04 live test with Accessibility granted: Mathias confirmed dimming works and is smoother than HazeOver. First 30s sample while running: CPU 0.0% most samples, spikes 2-17% on switches, `top` MEM 24M, energy 0.0.

## NOT verified
- Multi-display and the bounds fallback were not tested specifically. No long (1h) CPU comparison against HazeOver yet.
- No launchd plist; launch at login is the in-app SMAppService toggle.

## Known gaps
- Stage Manager: grouped windows are not special-cased.
- Full-screen Spaces: overlay uses `.fullScreenAuxiliary`/`.canJoinAllSpaces`, untested there.
- Ad-hoc signing changes the code identity each build, so macOS may drop the Accessibility grant after a rebuild. v2 fix: create a self-signed code-signing cert and sign with it (not done; no keychain changes were made).
- Uses private `_AXUIElementGetWindow`; fallback matches pid + bounds.
- Apps without AX support (some Electron/Java) report no focused window, so the screen is undimmed.

## Next
- v2: per-app rules, global hotkey.
- v3: focusbox timer + schedule hooks.

## Public release (2026-10-04)
- Repo is public at github.com/mathiasthu/dimmer, MIT licensed (Momentum Minds LLC). README links to Luxvps.
- `scripts/build-app.sh` now builds a universal (arm64 + x86_64) binary and writes `dist/Dimmer.zip` (~66 KB) for GitHub Releases. Release: `gh release create vX.Y.Z dist/Dimmer.zip`.
- Not notarized (no Apple Developer ID). README tells users to use Open Anyway or `xattr -dr com.apple.quarantine`. Notarization would need a paid developer account.
- Reinstalling the ad-hoc build over ~/Applications/Dimmer.app may drop the Accessibility grant.
