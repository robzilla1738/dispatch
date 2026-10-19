# Capabilities

Dispatch is a native macOS command palette, coding agent hub, and app connector with Spotlight-native geometry, an Aside-inspired slide-out drawer, local CLI harness auto-discovery, and Composio app connectors.

## Capability Matrix

| Area | Status | Notes |
| --- | --- | --- |
| Native Spotlight + Aside UI | Complete | Floating search capsule with inline completion (`Finder.app — Open`), scope chips, and a unified slide-out Aside drawer inside the same window |
| Global hotkey & menu bar | Complete | Carbon `RegisterEventHotKey` (`⌥Space` / `⌃⌥Space`), vector paper-plane status bar item |
| Local Coding Tools Hub | Complete | Auto-detects 11 CLI harnesses (`claude`, `codex`, `opencode`, `cursor`, `grok`, `pi`, `antigravity`, `muse`, `gemini`, `aider`, `ollama`), local `SKILL.md` skills, and local MCP servers |
| Per-Provider Model & Effort Selection | Complete | Reads live model catalogs from local caches and CLI probes; switch models and reasoning effort (`Low`, `Medium`, `High`) in search bar, Aside drawer, or Settings |
| Composio App Connectors | Complete | 18 pre-bundled SaaS connectors with official brand icons + in-app **Add Custom Connector** for any of 250+ Composio toolkits by slug |
| Application & Spotlight File Search | Complete | Scans `/Applications`, `/System/Applications`, `/System/Library/CoreServices`, and `~/Applications`; prefix-prioritized `mdfind` file search with `<Date> · 📁 <Parent>` subtitles |
| Clipboard History + Preview Pane | Complete | Text, file URLs, and PNG/TIFF images, pinning, search, auto-paste, and Aside preview drawer |
| Snippets + Global Auto-Expansion | Complete | Create/edit/delete snippets plus background keyboard expansion (`;keyword`, `!keyword`, `:keyword:`) in any app |
| Window Management (27 Layouts) | Complete | Halves, quarters, thirds, two-thirds, all six sixths, almost maximize, reasonable size, make larger/smaller, next/previous display |
| Floating Notes & Confetti | Complete | Persistent floating scratchpad panel (`Floating Notes`) and full-screen particle celebration (`Confetti`) |
| Calculator & Unit Conversion | Complete | Recursive-descent evaluator for math expressions, percentages, factorials, and unit/temperature conversions |
| Quicklinks, Emoji, System Controls | Complete | Prefix quicklinks (`g`, `gh`, `wiki`), emoji catalog, 13 AppleScript/system actions, local script/URL extensions |
| Local Persistence | Complete | Atomic JSON in `~/Library/Application Support/Dispatch` |
| URL Scheme | Complete | `dispatch://<mode>?q=<query>` |
