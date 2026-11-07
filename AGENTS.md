# Agent guide

## Project

Browserino is a small macOS browser picker built with SwiftUI and AppKit. This fork
uses bundle ID `com.i0ntempest.Browserino` and targets macOS 14.4 or later.

- `Browserino/main.swift` runs preference migration before creating the app/delegate.
- `BrowserinoApp.swift` and `BrowserinoWindow.swift` manage URL handling and windows.
- `Views/Prompt/` contains the picker; `Views/Preferences/` contains settings.
- `Models/BrowserUtil.swift` routes browser launches; `SafariPrivateBrowser.swift`
  handles Safari private browsing; `PreferencesMigration.swift` imports old settings.
- `Extensions/` and `Modifiers/` hold shared SwiftUI helpers. `Tests/` contains
  standalone Swift checks, not an XCTest target.

## Code style and behavior

- Match nearby Swift: four-space indentation, `UpperCamelCase` types and
  `lowerCamelCase` members. Wrap arguments and modifier chains consistently with
  surrounding code; avoid unrelated reformatting, especially in the Xcode project.
- Prefer small views and shared modifiers. Use `private` for implementation state,
  `guard` for early exits and optional binding instead of adding force unwraps.
- Keep AppKit UI work on the main queue and slow Accessibility operations on the
  existing serial queue. Preserve event-monitor cleanup and window resizing.
- Keep preference keys and serialized values compatible. Migration must preserve
  existing new-domain values, leave the legacy domain intact and run only once.
- Safari private requests must retain failed links for retry/copy, identify the
  newly created window and avoid a normal-window fallback. Request Accessibility
  only for this path; do not close unrelated browser windows.
- Guard newer APIs for both SDK availability and runtime availability as needed.
  Add new Swift files to the Xcode project's file references and Sources phase.

## Build and validation

Run from the repository root with Xcode selected. Use ad-hoc signing for local
checks; keep code signing enabled:

```sh
xcodebuild -project Browserino.xcodeproj -scheme Browserino -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- build
```

Run the relevant standalone checks when changing launch or preference behavior:

```sh
mkdir -p DerivedData/AgentChecks
for name in SafariPrivateBrowser PreferencesMigration; do
  xcrun --sdk macosx swiftc -swift-version 5 \
    -target "$(uname -m)-apple-macos14.4" \
    "Browserino/Models/$name.swift" "Tests/${name}Tests.swift" \
    -o "DerivedData/AgentChecks/$name" && "DerivedData/AgentChecks/$name" || exit 1
done
```

For picker changes, check normal/Shift states, keyboard shortcuts and long-hostname
resizing. Report which checks actually ran; distinguish compile checks from live
Safari tests. Keep generated builds, caches and archives out of commits, and clean
up temporary validation artifacts when finished. Preserve configured Release signing.

## Changes and commits

Keep changes focused and preserve unrelated user edits. Follow existing commit
subjects: `feat:`, `fix:`, `docs:` or `chore:` followed by a concise lowercase,
imperative description (for example, `fix: align shortcut badges`). Use separate
commits for separate logical changes. Explain behavior changes and validation in
handoffs; write release notes for users rather than describing implementation.
Do not push, create tags or publish releases unless requested.

`CLAUDE.md` is a relative symlink to this file; edit guidance here only.
