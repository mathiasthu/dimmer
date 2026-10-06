# Dimmer HANDOFF

## State (2026-10-05, v1.1.0)
Added per-display dimming (see section below). Everything under the 2026-10-04 state still applies.

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
- Fixed in 1.0.1: the overlay used to block window edge snapping (resize/drag no longer stopped at neighbouring windows). OverlayWindow overrides AppKit's private `_canBeSnappingTarget` to false, same as HazeOver's `NoSnapWindow`. Verified by Mathias 2026-10-04.
- Stage Manager: grouped windows are not special-cased.
- Full-screen Spaces: see "Full-screen fix" below (live-tested 2026-10-05, see the Mac test section).
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

## Per-display dimming (2026-10-05, v1.1.0, not yet released or live-tested)
- Status menu has a "Displays" submenu: one checkbox per connected display (`NSScreen.localizedName`, default all on) and "Only the display with the focused window" (default off). Rebuilt on menu open and on `didChangeScreenParametersNotification`; toggles re-run the tracker update, no relaunch.
- Unchecked displays are stored in UserDefaults (`disabledDisplays`) as display UUIDs (`CGDisplayCreateUUIDFromDisplayID`), so new displays dim by default and the choice survives replug and reboot. `onlyFocusedDisplay` is a Bool.
- Screen detection (`Displays.swift`): only when the option is on, `CGWindowListCopyWindowInfo(.optionIncludingWindow, id)` gives the window's bounds in CG coordinates (top-left origin, primary display); each `NSScreen.frame` is flipped with the primary display's height and the screen with the largest intersection wins. If the display can't be resolved, every checked display dims instead of none.
- `OverlayController` now fades each overlay on its own (`Overlay` wrapper with `dimmed` flag) instead of one shared `visible` flag. `rebuild()` path for plug/unplug is unchanged.
- Verified: `scripts/build-app.sh` succeeds with no Swift warnings (only the two known linker search-path warnings). Standalone geometry check with ARZOPA (0,0,2048x1152) and Built-in (158,-1169,1800x1169): built-in's CG frame is y=1152..2321, a window at y=1191 resolves to Built-in, one at y=100 to ARZOPA, a window straddling both goes to the larger overlap.
- NOT verified: the app was not launched or installed (Mathias is using it; reinstalling drops the Accessibility grant). Menu behaviour, per-display fades and unplug/replug are untested live.

## Incident 2026-10-04: dimming stopped (root cause unconfirmed)
Dimming stopped working on Desktop 1 and did not follow focus after minimizing. A window-list probe showed the overlays ordered out and never shown again, although TCC showed Accessibility granted. After Mathias re-granted Accessibility and relaunched (build with debug logging), it worked again. Suspect: a stale Accessibility grant after an ad-hoc-signed reinstall. Not confirmed.
- The os.Logger debug logging (`log` in OverlayController.swift, calls in FocusTracker and OverlayController) is intentional and stays in the release. If it recurs: `log stream --level debug --predicate 'subsystem == "com.mathiass.dimmer"'`.

## Full-screen fix (2026-10-05, not yet built or live-tested)
Bug reported by Mathias: putting a window into full screen made the overlay cover it, so the whole screen went dark, and it behaved erratically.
- Cause: the overlay windows had `.fullScreenAuxiliary`, so they joined full-screen Spaces too, and could end up above the full-screen window during or after the transition.
- Fix 1 (`OverlayController.swift`): removed `.fullScreenAuxiliary`. Overlays keep `.canJoinAllSpaces` for normal desktops but no longer appear on full-screen Spaces, where there is nothing to dim anyway.
- Fix 2 (`FocusTracker.swift`): reads the focused window's `AXFullScreen` attribute. When it's true, that window's display is skipped (`show(..., skipDisplay:)`), so other displays still dim. If the display can't be resolved, every overlay is hidden rather than risk blacking out the full-screen window.
- Trade-off: split-view full screen (two apps tiled) is not dimmed.
- Written in a cloud session; it was not compiled. Next on the Mac: `scripts/build-app.sh`, re-grant Accessibility, then test entering and leaving full screen (green button and ctrl-cmd-F), swiping between a full-screen Space and the desktop, and full screen on one display with a second display attached.

## Mac build and live test of the full-screen branch (2026-10-05)
Built and run on the Mac with ARZOPA (main, 2048x1152) plus the built-in display attached, "Only the display with the focused window" on.
- Build: `scripts/build-app.sh` succeeds with no Swift warnings (only the two known linker search-path lines). The cloud-written code compiled unchanged.
- Verified live by Mathias: normal dimming (app switching incl. cmd-tab, move/resize, minimize, edge snapping); green-button full screen keeps the full-screen window bright; leaving full screen brings dimming back; focus moving between the two displays dims only the focused one.
- Not tested (Mathias stopped testing once it worked): ctrl-cmd-F, swiping between a full-screen Space and the desktop, the per-display checkboxes, and full screen with "only focused display" off. The Displays submenu is still untested live.

Two bugs found and fixed during the test:
1. cmd-tab left the previous app's window bright. The app activates before the window server raises its windows, so `order(.below, relativeTo: focused)` put the overlay under the old front window too (z-order probe: `Terminal > Claude > Dimmer`). Probably present before this branch as well. Fix: `FocusTracker.windowAbove` finds the topmost other-app, layer-0 window still above the focused one (`CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow)`); `OverlayController.show(below:above:)` then orders the overlay above that window, and the pending raise lifts the focused app over it. Logged as `above=<id>`; `above=0` means the normal path.
2. For about 2.7 s after leaving full screen both displays went fully dark, and on entering full screen every overlay was hidden. CG has no entry for the window during the full-screen animation, so its display was unknown and the fallbacks (dim all / hide all) kicked in. Fix: the focused window's display is now resolved on every update and remembered per window (`lastDisplay`); when the lookup fails for the same window, the last known display is used. Logged as `display of <id> unresolved, using last known`. That log line didn't show up in the final run, so the fix is confirmed by Mathias's observation, not by the log.
- Cost: the two window-list calls add about 1 ms per update (0.88 ms + 0.15 ms measured). Still no timers or polling.
- Idle check: memory 23-28 MB. CPU 0.0% in quiet intervals, but both samples overlapped active use (spikes 3-30% on focus changes), so a clean idle CPU run is still open.
- Testing gotchas: in zsh, `log` is a shell builtin, so run `/usr/bin/log stream ...`. The installed app is `~/Applications/Dimmer.app`; launching `dist/Dimmer.app` instead needs its own Accessibility grant.
- Backups from this session: `~/dimmer-backups/` (previous installed app, pre-edit sources, HANDOFF).
- Next: Mathias decides whether to merge PR #1 and release (bump to 1.1.1 or 1.2.0 in `scripts/Info.plist`).
