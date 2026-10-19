import AppKit
import Foundation
import DispatchCore
import DispatchServices

enum CommandCatalog {
    static func rootCommands() -> [CommandItem] {
        [
            command(
                "builtin.ai",
                "Ask AI & Coding Agents",
                "Run prompts through auto-detected local CLIs (Claude, Codex, OpenCode, Cursor, Grok)",
                icon: .symbol("sparkles"),
                keywords: ["ai", "ask", "agent", "claude", "codex", "opencode", "cursor", "grok", "chat"],
                mode: .ai
            ),
            command(
                "builtin.connectors",
                "Composio App Connectors",
                "Connect GitHub, Linear, Notion, Slack, Gmail, Calendar, Jira, and more",
                icon: .symbol("link.circle.fill"),
                keywords: ["composio", "connect", "connector", "integration", "oauth", "github", "linear", "notion", "slack"],
                mode: .connectors
            ),
            command(
                "builtin.floatingNotes",
                "Floating Notes",
                "Open the persistent floating scratchpad window",
                icon: .symbol("note.text"),
                keywords: ["note", "notes", "floating", "scratchpad", "memo"],
                action: .showFloatingNote
            ),
            command(
                "builtin.confetti",
                "Confetti",
                "Celebrate with full-screen confetti",
                icon: .symbol("party.popper.fill"),
                keywords: ["confetti", "celebrate", "party"],
                action: .triggerConfetti
            ),
            command(
                "builtin.clipboard",
                "Clipboard History",
                "Browse and paste recent clipboard items",
                icon: .symbol("doc.on.clipboard.fill"),
                keywords: ["clipboard", "copy", "paste", "history"],
                mode: .clipboard
            ),
            command(
                "builtin.files",
                "Search Files",
                "Find files and folders with Spotlight",
                icon: .symbol("magnifyingglass.circle.fill"),
                keywords: ["file", "folder", "find", "spotlight", "document"],
                mode: .files
            ),
            command(
                "builtin.applications",
                "Search Applications",
                "Launch any installed app",
                icon: .symbol("square.grid.2x2.fill"),
                keywords: ["app", "application", "launch", "open", "program"],
                mode: .applications
            ),
            command(
                "builtin.emoji",
                "Search Emoji",
                "Find and copy an emoji",
                icon: .symbol("face.smiling.fill"),
                keywords: ["emoji", "smiley", "symbol", "reaction"],
                mode: .emoji
            ),
            command(
                "builtin.snippets",
                "Snippets",
                "Paste saved text snippets",
                icon: .symbol("text.badge.plus"),
                keywords: ["snippet", "text", "expand", "template"],
                mode: .snippets
            ),
            command(
                "builtin.quicklinks",
                "Quicklinks",
                "Open saved links and searches",
                icon: .quicklink,
                keywords: ["quicklink", "link", "url", "bookmark", "web"],
                mode: .quicklinks
            ),
            command(
                "builtin.newSnippet",
                "Create Snippet",
                "Save reusable text",
                icon: .symbol("plus.square"),
                keywords: ["new", "create", "snippet", "text", "template"],
                action: .newSnippet
            ),
            command(
                "builtin.newQuicklink",
                "Create Quicklink",
                "Save a URL or a search template",
                icon: .symbol("link.badge.plus"),
                keywords: ["new", "create", "quicklink", "url", "search"],
                action: .newQuicklink
            ),
            command(
                "builtin.calculator",
                "Calculator",
                "Evaluate expressions and convert units",
                icon: .symbol("plus.forwardslash.minus"),
                keywords: ["calculator", "math", "convert", "unit", "number"],
                mode: .calculator
            ),
            command(
                "builtin.window",
                "Window Management",
                "Move and resize the frontmost window",
                icon: .symbol("rectangle.lefthalf.inset.filled"),
                keywords: ["window", "resize", "move", "tile", "layout"],
                mode: .window
            ),
            command(
                "builtin.system",
                "System Controls",
                "Lock, sleep, volume, appearance, and more",
                icon: .symbol("gearshape.2.fill"),
                keywords: ["system", "lock", "sleep", "volume", "dark mode", "trash"],
                mode: .system
            ),
            command(
                "builtin.commands",
                "Search Commands",
                "Show every built-in command",
                icon: .symbol("command"),
                keywords: ["command", "all", "commands"],
                mode: .commands
            ),
            command(
                "builtin.settings",
                "Dispatch Settings",
                "Configure the launcher, coding agents, and connectors",
                icon: .symbol("gearshape.fill"),
                keywords: ["settings", "preferences", "config", "dispatch"],
                accessory: "⌘,",
                action: .showSettings
            ),
            command(
                "builtin.reload",
                "Reload Extensions",
                "Rescan script extensions",
                icon: .symbol("puzzlepiece.extension.fill"),
                keywords: ["extension", "reload", "scripts"],
                action: .reloadExtensions
            ),
            command(
                "builtin.updates",
                "Check for Updates…",
                "Check for signed Dispatch updates via Sparkle",
                icon: .symbol("arrow.triangle.2.circlepath.circle.fill"),
                keywords: ["update", "updates", "sparkle", "upgrade", "version"],
                action: .checkForUpdates
            ),
            command(
                "builtin.about",
                "About Dispatch",
                "Version and project information",
                icon: .symbol("info.circle"),
                keywords: ["about", "version", "info"],
                action: .showAbout
            ),
            command(
                "builtin.home",
                "Open Home Folder",
                NSHomeDirectory(),
                icon: .symbol("house"),
                keywords: ["home", "folder", "finder"],
                action: .openPath(path: NSHomeDirectory())
            ),
            command(
                "builtin.applicationsFolder",
                "Open Applications Folder",
                "/Applications",
                icon: .symbol("folder"),
                keywords: ["applications", "folder", "finder"],
                action: .openPath(path: "/Applications")
            ),
            command(
                "builtin.downloads",
                "Open Downloads",
                NSHomeDirectory() + "/Downloads",
                icon: .symbol("arrow.down.circle"),
                keywords: ["downloads", "folder", "finder"],
                action: .openPath(path: NSHomeDirectory() + "/Downloads")
            ),
            command(
                "builtin.quit",
                "Quit Dispatch",
                "Close the launcher and stop background services",
                icon: .symbol("power"),
                keywords: ["quit", "exit", "close"],
                accessory: "⌘Q",
                action: .quit
            ),
        ]
    }

    static func windowCommands() -> [CommandItem] {
        WindowCommand.allCases.map { command in
            CommandItem(
                id: "window.\(command.rawValue)",
                title: command.title,
                subtitle: "Move the frontmost window",
                kind: .command,
                keywords: command.keywords,
                icon: .symbol(command.symbol),
                action: .window(command)
            )
        }
    }

    static func systemCommands() -> [CommandItem] {
        SystemCommand.allCases.map { command in
            CommandItem(
                id: "system.\(command.rawValue)",
                title: command.title,
                subtitle: "System control",
                kind: .command,
                keywords: command.keywords,
                icon: command.icon,
                action: .system(command)
            )
        }
    }

    static func extensionCommands(_ commands: [ScriptCommand]) -> [CommandItem] {
        commands.map { command in
            CommandItem(
                id: command.id,
                title: command.title,
                subtitle: command.subtitle,
                kind: .script,
                keywords: command.keywords + [command.extensionName],
                icon: command.icon.map { IconSpec.symbol($0) } ?? .symbol("puzzlepiece.extension.fill"),
                action: command.url.map { CommandAction.openURL($0) }
                    ?? .runScript(name: command.title, script: command.script ?? ""),
                source: command.extensionName
            )
        }
    }

    static func applications(_ entries: [ApplicationEntry]) -> [CommandItem] {
        entries.map { entry in
            let displayName = entry.name.hasSuffix(".app") ? entry.name : "\(entry.name).app"
            return CommandItem(
                id: "app.\(entry.path)",
                title: displayName,
                subtitle: "",
                kind: .application,
                keywords: ["app", "application", entry.name, displayName],
                icon: .application(path: entry.path),
                action: .openApplication(path: entry.path)
            )
        }
    }

    static func clipboard(_ records: [ClipboardRecord]) -> [CommandItem] {
        records.map { record in
            let preview = record.text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = preview.count > 110 ? String(preview.prefix(110)) + "…" : preview
            let icon: IconSpec
            switch record.kind {
            case .text:
                if let sourcePath = record.sourcePath, FileManager.default.fileExists(atPath: sourcePath) {
                    icon = .application(path: sourcePath)
                } else {
                    icon = .symbol("doc.on.clipboard")
                }
            case .image: icon = record.imagePath.map { .file(path: $0) } ?? .symbol("photo")
            case .file: icon = .symbol("folder")
            }
            return CommandItem(
                id: "clipboard.\(record.id)",
                title: title.isEmpty ? "Image" : title,
                subtitle: "\(record.sourceApp.isEmpty ? "Clipboard" : record.sourceApp) · \(RelativeTime.string(from: record.date))",
                kind: .clipboard,
                keywords: ["clipboard", "copy", "paste", record.sourceApp],
                icon: icon,
                accessory: record.pinned ? "Pinned" : nil,
                action: .pasteClipboard(id: record.id)
            )
        }
    }

    static func snippets(_ snippets: [Snippet], includeCreate: Bool = false) -> [CommandItem] {
        var items: [CommandItem] = []
        if includeCreate {
            items.append(CommandItem(
                id: "builtin.newSnippet.inline",
                title: "Create Snippet",
                subtitle: "Save reusable text",
                kind: .snippet,
                keywords: ["new", "create", "snippet"],
                icon: .symbol("plus.square"),
                action: .newSnippet
            ))
        }
        items += snippets.map { snippet in
            CommandItem(
                id: "snippet.\(snippet.id)",
                title: snippet.title,
                subtitle: snippet.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(100)
                    .description,
                kind: .snippet,
                keywords: ["snippet", snippet.keyword, snippet.text],
                icon: .symbol("doc.text.fill"),
                action: .pasteText(snippet.text)
            )
        }
        return items
    }

    static func quicklinks(_ links: [Quicklink], includeCreate: Bool = false) -> [CommandItem] {
        var items: [CommandItem] = []
        if includeCreate {
            items.append(CommandItem(
                id: "builtin.newQuicklink.inline",
                title: "Create Quicklink",
                subtitle: "Save a URL or a search template",
                kind: .quicklink,
                keywords: ["new", "create", "quicklink"],
                icon: .symbol("link.badge.plus"),
                action: .newQuicklink
            ))
        }
        items += links.map { link in
            let hasArgument = link.urlTemplate.contains("{query}")
            let action: CommandAction
            if hasArgument && !link.keyword.isEmpty {
                action = .beginQuicklink(keyword: link.keyword)
            } else {
                action = .openURL(link.urlTemplate.replacingOccurrences(of: "{query}", with: ""))
            }
            return CommandItem(
                id: "quicklink.\(link.id)",
                title: link.title,
                subtitle: hasArgument ? "Type \(link.keyword) <query> to search" : link.urlTemplate,
                kind: .quicklink,
                keywords: ["quicklink", "link", "url", link.keyword],
                icon: .quicklink,
                action: action
            )
        }
        return items
    }

    static func emoji(_ entries: [EmojiEntry]) -> [CommandItem] {
        entries.map { entry in
            CommandItem(
                id: "emoji.\(entry.id)",
                title: entry.name.capitalized,
                subtitle: EmojiCatalog.categoryTitle(entry.category),
                kind: .emoji,
                keywords: entry.keywords + entry.aliases,
                icon: .emoji(entry.character),
                action: .copyText(entry.character)
            )
        }
    }

    static func files(_ entries: [FileEntry]) -> [CommandItem] {
        entries.map { entry in
            CommandItem(
                id: "file.\(entry.path)",
                title: entry.name,
                subtitle: fileSubtitle(for: entry),
                kind: .file,
                keywords: ["file", "folder", entry.name],
                icon: .file(path: entry.path),
                action: .openPath(path: entry.path)
            )
        }
    }

    static func calculation(_ result: CalculatorResult) -> CommandItem {
        CommandItem(
            id: "calculation.\(result.expression)",
            title: result.formatted,
            subtitle: result.expression,
            kind: .calculation,
            keywords: ["calculator", "result", "math"],
            icon: .symbol("plus.forwardslash.minus"),
            accessory: "Copy",
            action: .copyText(result.formatted)
        )
    }

    static func codingAgents(
        tools: [DetectedCodingTool],
        skills: [LocalSkillEntry],
        mcpServers: [LocalMcpServerEntry],
        activeDriver: String,
        selectedModels: [String: String],
        enabledDrivers: Set<String>,
        query: String
    ) -> [CommandItem] {
        var items: [CommandItem] = []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let installedTools = tools.filter { $0.installed && enabledDrivers.contains($0.kind.rawValue) }
        if !trimmed.isEmpty {
            let sortedTools = installedTools.sorted { lhs, rhs in
                if (lhs.kind.rawValue == activeDriver) != (rhs.kind.rawValue == activeDriver) {
                    return lhs.kind.rawValue == activeDriver
                }
                return lhs.kind.displayName < rhs.kind.displayName
            }
            for tool in sortedTools {
                let modelSlug = selectedModels[tool.kind.rawValue] ?? "default"
                let modelLabel = tool.models.first(where: { $0.slug == modelSlug })?.label ?? modelSlug
                items.append(CommandItem(
                    id: "ai.ask.\(tool.kind.rawValue).\(trimmed)",
                    title: "Ask \(tool.kind.displayName): “\(trimmed)”",
                    subtitle: "\(modelLabel) · \(tool.kind.roleTitle)",
                    kind: .aiAgent,
                    keywords: ["ai", "ask", tool.kind.rawValue, tool.kind.displayName.lowercased()],
                    icon: tool.kind.iconSpec,
                    accessory: tool.kind.rawValue == activeDriver ? "Default" : "Run",
                    action: .askAgent(driverID: tool.kind.rawValue, prompt: trimmed)
                ))
            }
        }

        for tool in tools {
            let isDefault = tool.kind.rawValue == activeDriver
            let chosenSlug = selectedModels[tool.kind.rawValue]
            let chosenModelLabel = chosenSlug.flatMap { slug in
                tool.models.first(where: { $0.slug == slug })?.label ?? (slug == "default" ? nil : slug)
            } ?? tool.models.dropFirst().first?.label ?? "Default Model"
            let status: String
            if tool.installed {
                status = "Model: \(chosenModelLabel) · \(tool.version ?? "Installed") (\(tool.binaryPath ?? ""))"
            } else {
                status = "Not installed · \(tool.kind.installHint)"
            }
            items.append(CommandItem(
                id: "ai.driver.\(tool.kind.rawValue)",
                title: tool.kind.displayName,
                subtitle: status,
                kind: .aiAgent,
                keywords: ["ai", "agent", "coding", "cli", tool.kind.rawValue, tool.kind.displayName.lowercased()],
                icon: tool.kind.iconSpec,
                accessory: isDefault ? "Active · \(chosenModelLabel)" : (tool.installed ? chosenModelLabel : "Install Hint"),
                action: tool.installed
                    ? .selectActiveAgent(driverID: tool.kind.rawValue)
                    : .copyText(tool.kind.installHint)
            ))
        }

        for skill in skills.prefix(30) {
            items.append(CommandItem(
                id: skill.id,
                title: "Skill: /\(skill.slug)",
                subtitle: "\(skill.description) · \(skill.source)",
                kind: .aiAgent,
                keywords: ["skill", "agent", skill.slug, skill.name],
                icon: .symbol("wand.and.stars"),
                accessory: "Ask AI",
                action: .askAgent(driverID: activeDriver, prompt: "Use skill /\(skill.slug): ")
            ))
        }

        for server in mcpServers {
            items.append(CommandItem(
                id: server.id,
                title: "MCP: \(server.name)",
                subtitle: "\(server.commandOrUrl) · \(server.source)",
                kind: .aiAgent,
                keywords: ["mcp", "server", server.name],
                icon: .symbol("server.rack"),
                accessory: server.source,
                action: .copyText(server.commandOrUrl)
            ))
        }

        return items
    }

    static func composioConnectors(_ toolkits: [ComposioToolkit], includeAddAction: Bool = false) -> [CommandItem] {
        var items: [CommandItem] = []
        if includeAddAction {
            items.append(CommandItem(
                id: "composio.add.custom",
                title: "Add Custom Composio Connector…",
                subtitle: "Connect any of 250+ Composio apps by slug (e.g. airtable, posthog,attio)",
                kind: .connector,
                keywords: ["add", "new", "custom", "composio", "connector", "integration"],
                icon: .symbol("plus.circle.fill"),
                accessory: "Add",
                action: .addCustomComposioToolkit
            ))
        }
        for toolkit in toolkits {
            items.append(CommandItem(
                id: "composio.toolkit.\(toolkit.slug)",
                title: "\(toolkit.name)",
                subtitle: "\(toolkit.category) · \(toolkit.description)",
                kind: .connector,
                keywords: ["composio", "connector", toolkit.slug, toolkit.name.lowercased(), toolkit.category.lowercased()],
                icon: toolkit.iconSpec,
                accessory: toolkit.isConnected ? "Connected" : "Connect",
                action: .connectComposioToolkit(slug: toolkit.slug)
            ))
            if toolkit.isConnected {
                for actionName in toolkit.sampleActions {
                    items.append(CommandItem(
                        id: "composio.action.\(toolkit.slug).\(actionName)",
                        title: "\(toolkit.name): \(actionName)",
                        subtitle: "Composio Connected Action · \(toolkit.category)",
                        kind: .connector,
                        keywords: ["composio", toolkit.slug, toolkit.name.lowercased(), actionName.lowercased()],
                        icon: toolkit.iconSpec,
                        accessory: "Run",
                        action: .triggerComposioAction(slug: toolkit.slug, actionName: actionName)
                    ))
                }
            }
        }
        return items
    }

    static func quicklinkSearch(_ link: Quicklink, query: String) -> CommandItem? {
        let argument = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !argument.isEmpty else { return nil }
        let encoded = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? argument
        let url = link.urlTemplate.replacingOccurrences(of: "{query}", with: encoded)
        return CommandItem(
            id: "quicklink.search.\(link.id).\(argument)",
            title: "\(link.title): \(argument)",
            subtitle: url,
            kind: .quicklink,
            keywords: ["quicklink", link.keyword, argument],
            icon: .quicklink,
            action: .openURL(url)
        )
    }

    private static func command(
        _ id: String,
        _ title: String,
        _ subtitle: String,
        icon: IconSpec,
        keywords: [String],
        accessory: String? = nil,
        mode: SearchMode
    ) -> CommandItem {
        CommandItem(
            id: id,
            title: title,
            subtitle: subtitle,
            kind: .command,
            keywords: keywords,
            icon: icon,
            accessory: accessory,
            action: .setSearchMode(mode)
        )
    }

    private static func command(
        _ id: String,
        _ title: String,
        _ subtitle: String,
        icon: IconSpec,
        keywords: [String],
        accessory: String? = nil,
        action: CommandAction
    ) -> CommandItem {
        CommandItem(
            id: id,
            title: title,
            subtitle: subtitle,
            kind: .command,
            keywords: keywords,
            icon: icon,
            accessory: accessory,
            action: action
        )
    }

    private static func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private static func fileSubtitle(for entry: FileEntry) -> String {
        let parentURL = URL(fileURLWithPath: entry.path).deletingLastPathComponent()
        let parentName = parentURL.lastPathComponent.isEmpty ? "/" : parentURL.lastPathComponent
        guard let modified = entry.modified else {
            return "📁 \(parentName)"
        }
        return "\(SpotlightDateFormatter.string(from: modified)) · \(parentName)"
    }
}

enum SpotlightDateFormatter {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    static func string(from date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday, \(timeFormatter.string(from: date))"
        }
        return shortDateFormatter.string(from: date)
    }
}

enum RelativeTime {
    static func string(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 10 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3_600))h ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
