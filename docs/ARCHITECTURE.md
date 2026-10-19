# Architecture

Dispatch is a SwiftPM package with three main targets and a
dependency-free test executable. The UI is SwiftUI hosted inside an AppKit
`NSPanel`; system integration lives in a separate module so it can be tested
without launching the app.

```
DispatchCore          Foundation-only models, matching, calculator, persistence
      ▲
      │
DispatchServices      AppKit/Carbon/ApplicationServices/ServiceManagement
      ▲
      │
Dispatch              SwiftUI + AppKit application, command catalog, settings

DispatchTests         CLI test runner depending on Core and Services
```

## Target responsibilities

### `DispatchCore`

| File | Responsibility |
| --- | --- |
| `Models.swift` | `CommandItem`, `SearchResult`, `SearchMode`, `CommandAction`, `IconSpec`, `WindowCommand`, `SystemCommand`, limits and enums |
| `FuzzyMatcher.swift` | Exact/prefix/substring/subsequence scoring, matched ranges, usage boost, result ordering |
| `Calculator.swift` | Recursive-descent expression parser, functions, percentages, factorials, unit conversion |
| `Storage.swift` | `Snippet`, `Quicklink`, `ClipboardRecord`, settings, usage records, thread-safe JSON `AppStore` |
| `Version.swift` | Core version metadata |

`DispatchCore` deliberately has no AppKit dependency. It can run in a command-line
test harness, and the parser never uses `NSExpression`, so expressions cannot
execute code.

### `DispatchServices`

| File | Responsibility |
| --- | --- |
| `HotKeyManager.swift` | Carbon `RegisterEventHotKey` wrapper with a global callback and display formatting |
| `ApplicationIndex.swift` | Background scan of application folders, icon caching, running state |
| `ClipboardService.swift` | 450 ms pasteboard polling, text/file/image capture, deduplication, copy/pin/clear |
| `FileSearchService.swift` | `mdfind` invocation scoped to the home folder, bounded output, metadata filtering |
| `WindowManager.swift` | Accessibility permission checks and focused-window move/resize operations |
| `SystemActions.swift` | Lock/sleep/restart/shutdown/trash/appearance/volume/screenshot/desktop/screen saver/logout |
| `PasteService.swift` | Pasteboard writes and optional synthesized `⌘V` |
| `ExtensionStore.swift` | Manifest discovery, script/URL command model, 15-second script runner |
| `LaunchAtLogin.swift` | `SMAppService.mainApp` registration and status description |

Long-running work (application scan, `mdfind`, extension scripts) runs off the
main thread. User-visible state is updated on the main actor.

### `Dispatch`

| File | Responsibility |
| --- | --- |
| `main.swift` | `NSApplication` entry point |
| `AppDelegate.swift` | Service composition, status item, hotkey registration, settings window, alerts, URL scheme, diagnostics |
| `LauncherController.swift` | Floating `NSPanel`, positioning, show/hide animation, key event monitor, screenshot capture |
| `LauncherViewModel.swift` | Query modes, rebuild/ranking, file-search debounce, selection, actions, execution |
| `LauncherView.swift` | Search bar, sections, result rows, highlight ranges, action panel, footer, toast |
| `CommandCatalog.swift` | Conversion of models and records into searchable `CommandItem`s |
| `SettingsViewModel.swift` | Settings bindings, permissions, extension/clipboard data refresh |
| `SettingsView.swift` | Sidebar and General/Appearance/Extensions/Data/About panes |
| `SettingsWindowController.swift` | Native settings window and capture support |
| `HotkeyRecorder.swift` | AppKit shortcut recorder embedded in SwiftUI |
| `ResourceLoader.swift` | Bundle resources, fonts, app/status icons, theme and typography |
| `EmojiCatalog.swift` | Bundled `emoji.json` decoding and search |
| `SelfTest.swift` | In-process 24-check smoke suite |
| `DemoSeeder.swift` | Optional demo clipboard/snippet/quicklink data for screenshots |

## Launcher lifecycle

1. `AppDelegate` constructs the store, services, view model, panel, settings
   model, status item, and hotkey.
2. The panel starts hidden. A hotkey press, status menu item, reopen event, URL,
   or `--show` calls `LauncherController.show`.
3. `show` captures the previous frontmost application, resets the view model to
   root, positions the panel on the screen containing the pointer, and activates
   the app.
4. The search field owns first responder. A local `NSEvent` monitor handles
   arrows, Return, Tab/⌘K, Escape, ⌘, ⌘W, and ⌘Q. Ordinary text events continue
   to the `TextField`.
5. Closing restores focus to the previous application. This is important for
   paste and window-management actions.

The panel uses `.borderless` plus `.fullSizeContentView`, a transparent
background, `NSVisualEffectView` with `.hudWindow`, a 16-point corner radius,
and a floating window level. It joins all Spaces and acts as a full-screen
auxiliary window.

## Search pipeline

For each query or mode change, `LauncherViewModel.rebuild`:

1. Builds a candidate pool for the active mode.
2. Adds forced results:
   - calculator result for expressions,
   - URL item for a plausible domain,
   - quicklink search for `keyword query`.
3. Removes forced items from the normal pool to avoid duplicates.
4. Applies `SearchRanking.rank`, which combines fuzzy score, a capped usage
   boost, and stable kind/title tie-breaking.
5. Groups results into sections by fixed kind order:
   `calculator → application → command → script → quicklink → snippet →
   clipboard → emoji → file`.
6. Preserves the selected item by stable ID where possible.

Fuzzy scoring order is exact, prefix, word-boundary substring, substring, then
subsequence. Subsequence scoring rewards consecutive characters, word
boundaries, capitalization, and query coverage. This supports initials such as
`gc` → “Google Chrome” without flooding results.

File results are debounced for 230 ms and only run for two or more characters in
root/files mode. The service caps subprocess output, terminates it after 2.5 s,
filters hidden/vendor/library paths, and returns the newest matches.

## Storage

`AppStore` persists a single pretty-printed JSON document:

```
~/Library/Application Support/Dispatch/
├── state.json
├── Clipboard/            copied images
├── Extensions/           user and starter extension folders
└── Logs/                 reserved
```

`state.json` contains clipboard records, snippets, quicklinks, usage records,
and settings. Dates use ISO-8601. Writes are atomic and protected by an
`NSLock`; the store is safe to read from background workers.

On first run, three quicklinks and one snippet are seeded. Removing all user data
does not re-seed because the existing `state.json` is loaded first.

Usage scores combine launch count with a two-week recency window. They affect
only search ordering and can be reset in Settings.

## Permissions

| Capability | Permission | Failure behavior |
| --- | --- | --- |
| Global hotkey | none | tries fallbacks, then reports no hotkey |
| Clipboard history | none | works while the app is running |
| Spotlight file search | none | `mdfind` results only for accessible files |
| Auto-paste | Accessibility | copies but does not synthesize `⌘V` |
| Window management | Accessibility | alert with a button to open settings |
| Show Desktop | Accessibility | explicit error |
| System controls | Automation | AppleScript error shown in an alert |
| Launch at Login | `SMAppService` approval | status shown in Settings |

The app is an `LSUIElement` accessory: it has no Dock icon and is controlled from
the menu bar, global hotkey, URL scheme, or Finder reopen.

## Extension execution

`ExtensionStore` recursively scans for `extension.json` or `manifest.json`,
decodes the manifest, and flattens commands. Script commands run with:

```
/bin/zsh -lc <script>
```

with the extension folder as the working directory, stdin from
`/dev/null`, combined stdout/stderr, and a 15-second watchdog. The output is
trimmed; empty success becomes “Command completed.” Nonzero exit status becomes
an error containing captured output. URL commands are represented as normal URL
actions in the launcher.

This format is intentionally lightweight and provides a safe, auditable local integration point.

## Bundle assembly

`scripts/build-app.sh`:

1. Builds the release `Dispatch` executable.
2. Creates `dist/Dispatch.app/Contents/{MacOS,Resources}`.
3. Copies the executable and SwiftPM resource bundle.
4. Copies `Info.plist`, `PkgInfo`, and `AppIcon.icns`.
5. Ad-hoc signs with `codesign --force --deep --sign -`.
6. Verifies the signature and plist.

`scripts/install.sh` copies the resulting app to `/Applications` when writable,
otherwise `~/Applications`. Launch at Login requires an installed app bundle;
running the raw binary is intended only for development.

## Design trade-offs

- **Native SwiftUI/AppKit over Electron/Web views.** Lower memory overhead, native text input and materials, and zero Node runtime requirement.
- **Local JSON over a database.** Transparent, dependency-free, easy to inspect and back up. The dataset is small enough that atomic whole-file writes are cheap.
- **Carbon hotkeys.** Stable system-wide registration without Accessibility permission. Fallbacks handle shortcut conflicts with other apps.
- **mdfind over a custom index.** No persistent index maintenance and no Full Disk Access requirement; broad queries are bounded.
- **Local manifest extensions.** A small, auditable JSON + script/URL contract for custom commands.
- **Fixed section order.** Predictable grouping keeps commands and apps above filename matches while still ranking inside each section.
