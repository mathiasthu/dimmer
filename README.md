# Dimmer

A small macOS menu bar app that dims everything except the focused window, in the spirit of HazeOver. Plain AppKit, event-driven, no timers.

## Build

    scripts/build-app.sh      # swift build -c release, assembles and ad-hoc signs dist/Dimmer.app

## Install

    scripts/install.sh        # copies dist/Dimmer.app to ~/Applications

Then open the app. It has no Dock icon; look for the half-filled circle in the menu bar.

## Accessibility

Dimmer needs Accessibility access to see which window is focused. Approve the prompt on first launch, or use the menu item "Grant Accessibility access…" (System Settings > Privacy & Security > Accessibility). With an ad-hoc signature the grant may need to be redone after a rebuild.
