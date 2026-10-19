# Development Guide

This project is designed to build with only the macOS Command Line Tools. There
is no Xcode project, no external package dependency, and no XCTest requirement.

## Toolchain

```sh
xcode-select -p          # /Library/Developer/CommandLineTools
swift --version
swift build
```

The package targets macOS 13 and is built with Swift 5 language mode on Swift 6
toolchains. SwiftUI macros such as `@State` are intentionally avoided because
the Command Line Tools SDK does not ship the macro plugin used by newer SwiftUI
examples. The app uses `ObservableObject`, `@Published`, `@ObservedObject`, and
`@FocusState` instead.

## Common commands

```sh
# Debug build and launch
swift build
.build/debug/Dispatch --show

# Version, tests, diagnostics
.build/debug/Dispatch --version
swift run DispatchTests
.build/debug/Dispatch --self-test
.build/debug/Dispatch --diagnostics

# Release .app
./scripts/build-app.sh
./scripts/install.sh
open "/Applications/Dispatch.app"
```

`scripts/install.sh` accepts a destination directory:

```sh
./scripts/install.sh "$HOME/Applications"
```

## Test suites

`Sources/DispatchTests/main.swift` is a tiny dependency-free runner. It exits
nonzero on failure and prints one line per check.

```sh
swift run DispatchTests
# 52 passed, 0 failed
```

The app's `--self-test` exercises app-level models, demo data, ranking,
calculator, persistence, extension discovery, and script execution:

```sh
.build/debug/Dispatch --self-test
# {"failed":0,"ok":true,"passed":24}
```

When adding features, add both a unit-level check in `DispatchTests` where
possible and a self-test check for app wiring.

## Screenshot and UI debugging

Screen Recording permission is not required because the app captures its own
window with `cacheDisplay`. These flags are intentionally retained for visual
regression checks.

```sh
# Launcher screenshots
.build/debug/Dispatch --screenshot=/tmp/root.png --exit-after-screenshot
.build/debug/Dispatch --screenshot=/tmp/query.png \
  --query='github' --exit-after-screenshot
.build/debug/Dispatch --screenshot=/tmp/actions.png \
  --mode=clipboard --select=0 --actions --exit-after-screenshot
.build/debug/Dispatch --screenshot=/tmp/light.png \
  --appearance=light --exit-after-screenshot

# Settings screenshots
.build/debug/Dispatch \
  --screenshot-settings=/tmp/settings.png \
  --settings-section=extensions
```

Useful flags:

| Flag | Effect |
| --- | --- |
| `--show` | Show the launcher after launch |
| `--mode=<root|applications|files|clipboard|snippets|quicklinks|emoji|commands|calculator|window|system>` | Initial mode |
| `--query=<text>` | Set the initial query |
| `--select=<n>` | Select the nth flattened result |
| `--actions` | Open the action panel before capture |
| `--screenshot=<path>` | Capture launcher content to PNG |
| `--screenshot-settings=<path>` | Capture settings content to PNG |
| `--settings-section=<general|appearance|extensions|data|about>` | Settings pane |
| `--appearance=dark|light` | Force appearance for the run |
| `--exit-after-screenshot` | Terminate after capture |
| `--background` | Do not auto-show on normal activation |
| `--seed-demo` | Add demo data before launching |
| `--seed-only` | Seed demo data and exit |
| `--diagnostics` | Print version, paths, hotkey, login, permissions, extensions |
| `--enable-login` / `--disable-login` | Register/unregister the login item with diagnostics |
| `--self-test` | Run the in-process checks |
| `--version` | Print the version and exit |

The screenshot captures the SwiftUI content view only; the window shadow and
desktop behind it are not included. This is why documented images have a solid
background even though the live panel uses a HUD material.

## Data reset

Quit the app before editing or deleting local data.

```sh
rm -rf "$HOME/Library/Application Support/Dispatch"
```

The next launch seeds the starter quicklinks/snippets and a starter extension.
Clipboard images are stored in the `Clipboard` subfolder. Use the Settings
**Data** pane to clear clipboard history or reset ranking without deleting
snippets and quicklinks.

## Adding a built-in command

1. Add or reuse a `CommandAction` in `Sources/DispatchCore/Models.swift`.
2. Handle it in `LauncherViewModel.execute(item:)`.
3. Add action-panel entries in `actionsForSelected()` if applicable.
4. Add a `CommandItem` in `CommandCatalog` with a stable ID, keywords, icon,
   subtitle, and action.
5. Add a unit/self-test check if the behavior is nontrivial.
6. Capture a screenshot and check dark/light themes.

Icons can be `.asset("name")` for bundled PNGs,
`.symbol("sf.symbol.name")`, `.application(path:)`, `.file(path:)`, or
`.emoji(character)`.

## Adding a service

Services live in `Sources/DispatchServices`. Keep them independent of
`Dispatch`; expose a small API and document permission requirements. Return
typed errors rather than showing alerts. The app layer owns user-visible
messaging and confirmation prompts.

Long-running work should not block the main actor. The existing patterns are:

- `DispatchQueue.global` + main-queue completion (application scan, extensions),
- `Task` + `withCheckedContinuation` (file search),
- `Timer` on the main run loop (clipboard polling).

## Adding an extension feature

The current contract is `extension.json` with a `commands` array. If expanding
it, keep unknown fields optional so old manifests remain valid. Never execute a
script during manifest discovery. Preserve the 15-second watchdog and return
combined stdout/stderr in failures.

## Release checklist

```sh
swift build
swift run DispatchTests
.build/debug/Dispatch --self-test
./scripts/build-app.sh
./scripts/install.sh

codesign --verify --deep --strict --verbose=2 \
  "/Applications/Dispatch.app"
"/Applications/Dispatch.app/Contents/MacOS/Dispatch" \
  --diagnostics
```

Then verify:

- launcher opens from the status menu and hotkey,
- app icons and extracted assets load from the bundle,
- settings opens and both themes render,
- clipboard capture works,
- window actions prompt for Accessibility when needed,
- Launch at Login registers and unregisters,
- extension reload and script output work,
- `dispatch://clipboard` and `?q=` links open the correct mode.

## Known build warnings

The Command Line Tools linker may print warnings about missing
`/Library/Developer/CommandLineTools/Developer/...` search paths. They come from
the SDK/toolchain configuration, not this package, and do not affect the build.
The release app is ad-hoc signed; replace the signing step in
`scripts/build-app.sh` for Developer ID distribution.

See [ARCHITECTURE.md](ARCHITECTURE.md) and [PARITY.md](PARITY.md) for the current
implementation and scope.
