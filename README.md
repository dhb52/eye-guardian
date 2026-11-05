# Eye Guardian

A native macOS break-reminder app built with Swift, SwiftUI and AppKit. It watches mouse, trackpad, keyboard and (optionally) screen activity, raises a fatigue value while you work, and lowers it while you rest. When fatigue reaches 100%, it reminds you to take a break.

Requires macOS 13.0 or later. Universal binary (arm64 + x86_64).

The windows split by release: macOS 26 and later keeps the opaque titled window with the system sidebar fill, because the system already draws that surface; earlier releases draw the sidebar with `NSVisualEffectView(.sidebar)` under a transparent titlebar, since the semantic fill turns grey there.

## Build

No Xcode required; only the Command Line Tools. The package layout is described by `Package.swift`; tests use Swift Testing, since the Command Line Tools ship no XCTest.

```sh
swift build  # compile the current architecture in debug
make         # universal release build, assemble and ad-hoc sign the app
make test    # build and run the Core tests via swift test
make run     # build and open the app
make dmg      # build and package a drag-to-Applications disk image
make clean
```

The result is `build/Eye Guardian.app`.

The Command Line Tools keep Swift Testing's macro plugin and `Testing.framework` outside the search paths SwiftPM passes, so `make test` adds `-plugin-path`, `-F` and an `-rpath` for `<toolchain>/Library/Developer/Frameworks`; a bare `swift test` fails with `no such module 'Testing'`. That framework's Foundation cross-import overlay is only a stub, so the same command turns cross-import overlays off — otherwise importing both `Foundation` and `Testing` fails with `no such module '_Testing_Foundation'`.

## Permissions

- **Accessibility** — needed for global keyboard detection. Grant it from System Settings → Privacy & Security → Accessibility, or from the in-app banner.
- **Screen Recording** — only needed if "Detect screen changes" is enabled; it improves accuracy while watching videos. A purple dot in the menu bar area is normal while the app captures thumbnails.
- **Notifications** — requested on first launch for notification-style reminders.

Builds are signed with a local self-signed identity at `~/Library/Keychains/EyeGuardian.keychain-db`, so Accessibility / Screen Recording grants persist across rebuilds. The build creates the identity on first use and marks its certificate trusted for code signing in your login keychain. Delete that keychain to rotate the identity; re-grant permissions afterward.

## Features

Every feature is available without an account or purchase: notification, mini and full-screen reminder styles, custom work/rest durations, break-skipping rules, time-based break rules, popup customization, the extra screen-time reminder, and all analysis charts.

## Data

All data stays on this Mac in `~/Library/Application Support/EyeGuardian/events.sqlite3`. Use Settings → Data → Export… to export daily aggregates.

## Settings

The settings window has eight sections: General, Status Bar, Reminders, Detection, Appearance, Permissions, Data and About. A live preview pinned at the top of Status Bar and Appearance reflects the real menu bar and Dock icon. Language can follow the system or be forced to English or 简体中文; About has Restore default settings, which keeps the chosen language and all usage data.

## Layout

- `Package.swift` — SwiftPM package: `EyeGuardianKit` library + `EyeGuardian` executable.
- `Sources/EyeGuardian/Core` — settings, fatigue math, scheduling, rules, SQLite store, CSV (Foundation + SQLite only).
- `Sources/EyeGuardian/Platform` — event monitoring, permissions, status bar, Dock icon, windows.
- `Sources/EyeGuardian/UI` — SwiftUI views.
- `Sources/EyeGuardianApp` — the `@main` entry point.
- `Tests` — Swift Testing suite for the Core layer.
- `scripts/build.swift` — SwiftPM universal release build, icon generation, bundle assembly, signing and disk-image packaging (`swift scripts/build.swift build|icons|dmg`).
