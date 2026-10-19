import AppKit
import Combine
import Foundation
import DispatchCore
import DispatchServices

struct ResultSection: Identifiable, Equatable {
    let kind: ItemKind
    let results: [SearchResult]
    var id: String { kind.rawValue }
}

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            guard oldValue != query else { return }
            queryChanged()
        }
    }
    @Published var mode: SearchMode = .root
    @Published var sections: [ResultSection] = []
    @Published var selectedIndex: Int = 0
    @Published var actionMode = false
    @Published var actions: [ActionDescriptor] = []
    @Published var selectedActionIndex: Int = 0
    @Published var focusRequest = 0
    @Published var isSearchingFiles = false
    @Published var statusMessage: String?
    @Published var isIndexingApplications = false
    @Published var selectedScopeChip: String? = nil
    @Published var isRunningAgent = false
    @Published var activeAgentResponse: String? = nil
    @Published var activeAgentTitle: String = ""
    @Published var activeAgentPrompt: String = ""
    @Published var agentFollowUpInput: String = ""

    let store: AppStore
    let applicationIndex: ApplicationIndex
    let clipboard: ClipboardService
    let fileSearch: FileSearchService
    let windowManager: WindowManager
    let systemActions: SystemActions
    let extensions: ExtensionStore
    let emojiCatalog: EmojiCatalog
    let codingTools: CodingToolsService
    let composio: ComposioService

    var onDismiss: (() -> Void)?
    var onSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConfirm: ((String, String, @escaping () -> Void) -> Void)?
    var onOutput: ((String, String) -> Void)?
    var onCreateSnippet: ((Snippet?) -> Void)?
    var onCreateQuicklink: ((Quicklink?) -> Void)?
    var onAddCustomConnector: (() -> Void)?
    var onShowFloatingNotes: (() -> Void)?
    var onTriggerConfetti: (() -> Void)?

    private var fileResults: [FileEntry] = []
    private var fileSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedApplications = false
    private var lastApplicationScan: Date?
    private var statusWorkItem: DispatchWorkItem?
    private var isResetting = false
    private var hasUserMovedSelection = false

    init(
        store: AppStore = .shared,
        applicationIndex: ApplicationIndex,
        clipboard: ClipboardService,
        fileSearch: FileSearchService,
        windowManager: WindowManager,
        systemActions: SystemActions,
        extensions: ExtensionStore,
        emojiCatalog: EmojiCatalog,
        codingTools: CodingToolsService = CodingToolsService(),
        composio: ComposioService = ComposioService()
    ) {
        self.store = store
        self.applicationIndex = applicationIndex
        self.clipboard = clipboard
        self.fileSearch = fileSearch
        self.windowManager = windowManager
        self.systemActions = systemActions
        self.extensions = extensions
        self.emojiCatalog = emojiCatalog
        self.codingTools = codingTools
        self.composio = composio

        clipboard.$items
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.mode == .clipboard || self.mode == .root else { return }
                self.rebuild()
            }
            .store(in: &cancellables)

        loadApplicationsIfNeeded()
        scanCodingToolsInBackground()
        rebuild()
    }

    func scanCodingToolsInBackground() {
        let service = codingTools
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            service.scanAll()
            DispatchQueue.main.async {
                guard let self else { return }
                var settings = self.store.settings
                if let activeKind = CodingDriverKind(rawValue: settings.activeCodingDriver),
                   service.tools.first(where: { $0.kind == activeKind })?.installed != true,
                   let firstInstalled = service.tools.first(where: \.installed) {
                    settings.activeCodingDriver = firstInstalled.kind.rawValue
                    self.store.settings = settings
                }
                self.rebuild()
            }
        }
    }

    var flatResults: [SearchResult] {
        sections.flatMap(\.results)
    }

    var selectedResult: SearchResult? {
        guard !flatResults.isEmpty, flatResults.indices.contains(selectedIndex) else { return nil }
        return flatResults[selectedIndex]
    }

    var selectedAction: ActionDescriptor? {
        guard actions.indices.contains(selectedActionIndex) else { return nil }
        return actions[selectedActionIndex]
    }

    var primaryActionLabel: String {
        if actionMode { return "Run Action" }
        guard let selectedResult else { return "Open" }
        switch selectedResult.item.action {
        case .copyText, .copyClipboard: return "Copy"
        case .pasteText, .pasteClipboard: return "Paste"
        case .window: return "Move"
        case .system, .runScript: return "Run"
        case .newSnippet, .newQuicklink: return "Create"
        case .beginQuicklink: return "Search"
        case .quit: return "Quit"
        case .showSettings: return "Open"
        case .showAbout: return "Show"
        case .reloadExtensions: return "Reload"
        case .pinClipboard: return "Pin"
        case .removeClipboard: return "Remove"
        case .setSearchMode: return "Open"
        case .askAgent: return "Ask"
        case .selectActiveAgent: return "Select"
        case .connectComposioToolkit: return "Connect"
        case .triggerComposioAction: return "Run"
        case .showFloatingNote: return "Open"
        case .triggerConfetti: return "Celebrate"
        default: return "Open"
        }
    }

    var inlineCompletionRemainder: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let selectedResult else { return nil }
        let title = selectedResult.item.title
        let foldedQuery = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let foldedTitle = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard foldedTitle.hasPrefix(foldedQuery), title.count >= trimmed.count else { return nil }
        let suffixStart = title.index(title.startIndex, offsetBy: trimmed.count)
        let suffix = String(title[suffixStart...])
        return "\(suffix) — \(primaryActionLabel)"
    }

    var scopeChips: [String] {
        var chips: [String] = []
        let usage = store.usageScores()
        let preferredNames = [
            "Obsidian", "Google Chrome", "Safari", "Cursor", "Visual Studio Code",
            "TextEdit", "Microsoft Excel", "Notes", "Terminal", "Finder",
        ]
        let apps = applicationIndex.applications
            .sorted { lhs, rhs in
                let lu = usage["app.\(lhs.path)"] ?? 0
                let ru = usage["app.\(rhs.path)"] ?? 0
                if lu != ru { return lu > ru }
                let lp = preferredNames.firstIndex(of: lhs.name) ?? 999
                let rp = preferredNames.firstIndex(of: rhs.name) ?? 999
                if lp != rp { return lp < rp }
                if lhs.isRunning != rhs.isRunning { return lhs.isRunning && !rhs.isRunning }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .prefix(4)
            .map(\.name)
        chips.append(contentsOf: apps)
        for category in ["AI", "Connectors", "Folders", "Clipboard", "Snippets", "Commands"] where !chips.contains(category) {
            chips.append(category)
        }
        return chips
    }

    func selectScopeChip(_ chip: String) {
        if selectedScopeChip == chip {
            selectedScopeChip = nil
            rebuild()
            return
        }
        switch chip {
        case "AI":
            setMode(.ai)
        case "Connectors":
            setMode(.connectors)
        case "Clipboard":
            setMode(.clipboard)
        case "Snippets":
            setMode(.snippets)
        case "Commands":
            setMode(.commands)
        case "Folders":
            selectedScopeChip = chip
            rebuild()
        default:
            if let app = applicationIndex.applications.first(where: { $0.name == chip }) {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    applicationIndex.open(app)
                    dismiss()
                } else {
                    selectedScopeChip = chip
                    rebuild()
                }
            }
        }
    }

    var placeholder: String {
        switch mode {
        case .root: return "Search for apps, commands, and files…"
        case .applications: return "Search applications…"
        case .files: return "Search files…"
        case .clipboard: return "Search clipboard history…"
        case .snippets: return "Search snippets…"
        case .quicklinks: return "Search quicklinks…"
        case .emoji: return "Search emoji…"
        case .commands: return "Search commands…"
        case .calculator: return "Type an expression, e.g. 2 + 2 or 10 km in mi…"
        case .window: return "Move the frontmost window…"
        case .system: return "Search system controls…"
        case .ai: return "Ask your local coding agent (Claude, Codex, OpenCode, Cursor, Grok)…"
        case .connectors: return "Search Composio app connectors (GitHub, Linear, Notion, Slack)…"
        }
    }

    var emptyTitle: String {
        if isSearchingFiles { return "Searching…" }
        switch mode {
        case .root: return "No results for “\(query)”"
        case .files: return query.isEmpty ? "Type to search your files" : "No files found for “\(query)”"
        case .calculator: return query.isEmpty ? "Type an expression to calculate" : "Not a valid expression"
        case .emoji: return "No emoji found for “\(query)”"
        default: return "No results for “\(query)”"
        }
    }

    var emptySubtitle: String {
        switch mode {
        case .root:
            return "Try a different search, or use ⌘K on a result for more actions."
        case .files:
            return "File search uses Spotlight and is limited to your home folder."
        case .calculator:
            return "Examples: 15% of 80 · sqrt(81) · 10 km in mi · 5!"
        case .emoji:
            return "Search by name, feeling, or object."
        default:
            return "Press esc to return to search."
        }
    }

    // MARK: - Lifecycle

    func refreshBeforeShow() {
        isResetting = true
        hasUserMovedSelection = false
        clearAgentResponse()
        mode = .root
        query = ""
        selectedScopeChip = nil
        isResetting = false
        actionMode = false
        actions = []
        selectedIndex = 0
        selectedActionIndex = 0
        fileResults = []
        clipboard.reload()
        loadApplicationsIfNeeded()
        rebuild()
        focusRequest += 1
    }

    func loadApplicationsIfNeeded(force: Bool = false) {
        guard !isIndexingApplications else { return }
        if !force,
           hasLoadedApplications,
           let lastApplicationScan,
           Date().timeIntervalSince(lastApplicationScan) < 120 {
            return
        }
        isIndexingApplications = true
        let index = applicationIndex
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            index.refresh()
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasLoadedApplications = true
                self.lastApplicationScan = Date()
                self.isIndexingApplications = false
                self.rebuild()
            }
        }
    }

    func resetToRoot() {
        isResetting = true
        hasUserMovedSelection = false
        clearAgentResponse()
        mode = .root
        query = ""
        selectedScopeChip = nil
        isResetting = false
        actionMode = false
        actions = []
        fileResults = []
        rebuild()
    }

    // MARK: - Search

    private func queryChanged() {
        selectedIndex = 0
        hasUserMovedSelection = false
        selectedScopeChip = nil
        actionMode = false
        actions = []
        selectedActionIndex = 0
        fileResults = []
        rebuild()
        scheduleFileSearch()
    }

    private func scheduleFileSearch() {
        fileSearchTask?.cancel()
        let settings = store.settings
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.fileSearchEnabled,
              (mode == .root || mode == .files),
              trimmed.count >= 2,
              !Calculator.looksLikeExpression(trimmed) else {
            isSearchingFiles = false
            return
        }

        isSearchingFiles = true
        let currentQuery = trimmed
        let limit = settings.maxFileResults
        fileSearchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            let entries = await self.fileSearch.search(query: currentQuery, limit: limit)
            guard !Task.isCancelled, self.query.trimmingCharacters(in: .whitespacesAndNewlines) == currentQuery else {
                return
            }
            self.fileResults = entries
            self.isSearchingFiles = false
            self.rebuild()
        }
    }

    func rebuild() {
        let settings = store.settings
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var pool: [CommandItem] = []
        var forcedItems: [CommandItem] = []
        var preserveOrder = false

        switch mode {
        case .root:
            pool = CommandCatalog.rootCommands()
                + CommandCatalog.extensionCommands(extensions.commands)
            if trimmed.isEmpty {
                pool += recentApplicationItems(limit: settings.showRecentApplications ? 6 : 0)
                preserveOrder = true
            } else {
                pool += CommandCatalog.applications(applicationIndex.applications)
                pool += CommandCatalog.snippets(store.snippets())
                pool += CommandCatalog.quicklinks(store.quicklinks())
                pool += CommandCatalog.files(fileResults)
                pool += CommandCatalog.composioConnectors(composio.catalog)

                let activeDriver = settings.activeCodingDriver
                if let tool = codingTools.tools.first(where: { $0.kind.rawValue == activeDriver && $0.installed }) {
                    pool.append(CommandItem(
                        id: "ai.root.ask.\(tool.kind.rawValue)",
                        title: "Ask \(tool.kind.displayName): “\(trimmed)”",
                        subtitle: "\(tool.kind.roleTitle) · Local CLI Agent",
                        kind: .aiAgent,
                        keywords: ["ai", "ask", "agent", tool.kind.rawValue, trimmed],
                        icon: tool.kind.iconSpec,
                        accessory: "Ask AI",
                        action: .askAgent(driverID: tool.kind.rawValue, prompt: trimmed)
                    ))
                }

                if let quicklink = quicklinkForPrefix(trimmed) {
                    forcedItems.append(quicklink)
                }
                if let urlItem = urlItem(for: trimmed) {
                    forcedItems.append(urlItem)
                }
                if Calculator.looksLikeExpression(trimmed),
                   let result = Calculator.evaluate(trimmed) {
                    forcedItems.insert(CommandCatalog.calculation(result), at: 0)
                }
            }

        case .applications:
            pool = CommandCatalog.applications(applicationIndex.applications)
            preserveOrder = trimmed.isEmpty
        case .files:
            pool = CommandCatalog.files(fileResults)
            if let urlItem = urlItem(for: trimmed) {
                forcedItems.append(urlItem)
            }
            preserveOrder = trimmed.isEmpty
        case .clipboard:
            pool = CommandCatalog.clipboard(clipboard.items)
            preserveOrder = trimmed.isEmpty
        case .snippets:
            pool = CommandCatalog.snippets(store.snippets(), includeCreate: true)
            preserveOrder = trimmed.isEmpty
        case .quicklinks:
            pool = CommandCatalog.quicklinks(store.quicklinks(), includeCreate: true)
            preserveOrder = trimmed.isEmpty
        case .emoji:
            pool = CommandCatalog.emoji(
                emojiCatalog.search(trimmed, limit: trimmed.isEmpty ? 120 : 160)
            )
            preserveOrder = trimmed.isEmpty
        case .commands:
            pool = CommandCatalog.rootCommands()
                + CommandCatalog.windowCommands()
                + CommandCatalog.systemCommands()
                + CommandCatalog.extensionCommands(extensions.commands)
            preserveOrder = trimmed.isEmpty
        case .calculator:
            if let result = Calculator.evaluate(trimmed) {
                forcedItems = [CommandCatalog.calculation(result)]
            }
        case .window:
            pool = CommandCatalog.windowCommands()
            preserveOrder = trimmed.isEmpty
        case .system:
            pool = CommandCatalog.systemCommands()
            preserveOrder = trimmed.isEmpty
        case .ai:
            let enabledSet = Set(settings.enabledCodingDrivers)
            let items = CommandCatalog.codingAgents(
                tools: codingTools.tools,
                skills: codingTools.skills,
                mcpServers: codingTools.mcpServers,
                activeDriver: settings.activeCodingDriver,
                selectedModels: settings.selectedCodingModels,
                enabledDrivers: enabledSet,
                query: trimmed
            )
            if !trimmed.isEmpty {
                let askItems = items.filter { $0.id.hasPrefix("ai.ask.") }
                forcedItems.append(contentsOf: askItems)
                pool = items.filter { !$0.id.hasPrefix("ai.ask.") }
            } else {
                pool = items
                preserveOrder = true
            }
        case .connectors:
            pool = CommandCatalog.composioConnectors(composio.catalog, includeAddAction: true)
            preserveOrder = trimmed.isEmpty
        }

        let forcedIDs = Set(forcedItems.map(\.id))
        let filteredPool = pool.filter { !forcedIDs.contains($0.id) }

        var ranked: [SearchResult]
        if trimmed.isEmpty && preserveOrder {
            ranked = filteredPool.map { SearchResult(item: $0, score: 0, matchedRanges: []) }
        } else {
            ranked = SearchRanking.rank(
                items: filteredPool,
                query: trimmed,
                usage: store.usageScores(),
                limit: 120
            )
        }

        if !forcedItems.isEmpty {
            ranked = forcedItems.map {
                SearchResult(item: $0, score: 100_000, matchedRanges: [])
            } + ranked
        }

        if !trimmed.isEmpty && mode == .root {
            let foldedQ = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            ranked.sort { lhs, rhs in
                let lhsPrefix = lhs.item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).hasPrefix(foldedQ)
                let rhsPrefix = rhs.item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).hasPrefix(foldedQ)
                if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
                if lhsPrefix && rhsPrefix && lhs.item.kind.sortOrder != rhs.item.kind.sortOrder {
                    return lhs.item.kind.sortOrder < rhs.item.kind.sortOrder
                }
                if abs(lhs.score - rhs.score) > 0.001 { return lhs.score > rhs.score }
                return lhs.item.kind.sortOrder < rhs.item.kind.sortOrder
            }
        }

        if mode == .calculator, trimmed.isEmpty {
            ranked = []
        }

        if let chip = selectedScopeChip {
            if chip == "Folders" {
                ranked = ranked.filter { result in
                    if case .openPath(let path) = result.item.action {
                        var isDir: ObjCBool = false
                        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
                    }
                    return false
                }
            } else {
                ranked = ranked.filter { result in
                    result.item.title.localizedCaseInsensitiveContains(chip)
                        || result.item.subtitle.localizedCaseInsensitiveContains(chip)
                        || result.item.kind == .file
                }
            }
        }

        let newSections: [ResultSection]
        if !trimmed.isEmpty && mode == .root {
            newSections = [ResultSection(kind: .application, results: ranked)]
        } else {
            let presentKinds = Set(ranked.map(\.item.kind))
            let order = ItemKind.allCases
                .filter { presentKinds.contains($0) }
                .sorted { $0.sortOrder < $1.sortOrder }
            newSections = order.map { kind in
                ResultSection(kind: kind, results: ranked.filter { $0.item.kind == kind })
            }
        }

        let previousID = selectedResult?.id
        sections = newSections
        if !hasUserMovedSelection || isResetting {
            selectedIndex = 0
        } else if let previousID, let index = flatResults.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = min(selectedIndex, max(flatResults.count - 1, 0))
        }
        if selectedIndex < 0 { selectedIndex = 0 }

        if actionMode {
            actions = actionsForSelected()
            selectedActionIndex = min(selectedActionIndex, max(actions.count - 1, 0))
        }
    }

    private func recentApplicationItems(limit: Int) -> [CommandItem] {
        guard limit > 0 else { return [] }
        let usage = store.usageScores()
        let items = CommandCatalog.applications(applicationIndex.applications)
            .filter { (usage[$0.id] ?? 0) > 0 || isRunningApplication(item: $0) }
            .sorted { (usage[$0.id] ?? 0) > (usage[$1.id] ?? 0) }
        return Array(items.prefix(limit))
    }

    private func isRunningApplication(item: CommandItem) -> Bool {
        guard case .openApplication(let path) = item.action else { return false }
        return applicationIndex.entry(forPath: path)?.isRunning == true
    }

    private func quicklinkForPrefix(_ query: String) -> CommandItem? {
        let parts = query.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let token = String(parts[0]).lowercased()
        let argument = String(parts[1])
        guard let link = store.quicklinks().first(where: {
            !$0.keyword.isEmpty && $0.keyword.lowercased() == token
        }) else { return nil }
        return CommandCatalog.quicklinkSearch(link, query: argument)
    }

    private func urlItem(for text: String) -> CommandItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        let hasScheme = trimmed.contains("://")
        var candidate = trimmed
        if !hasScheme {
            guard trimmed.contains(".") else { return nil }
            candidate = "https://" + trimmed
        }
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host else {
            return nil
        }

        if !hasScheme {
            // Avoid treating filenames such as "state.json" or "report.pdf" as
            // web addresses. A domain needs a plausible alphabetic TLD and must
            // not end in a common local file extension.
            let labels = host.split(separator: ".")
            guard labels.count >= 2,
                  let tld = labels.last,
                  tld.count >= 2,
                  tld.allSatisfy({ $0.isLetter }) else {
                return nil
            }
            let fileExtensions: Set<String> = [
                "json", "txt", "md", "png", "jpg", "jpeg", "gif", "pdf", "swift",
                "js", "ts", "html", "css", "zip", "tar", "gz", "mp4", "mov", "mp3",
                "wav", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "csv",
                "xml", "yml", "yaml", "sh", "py", "rb", "go", "rs", "c", "h", "cpp",
                "lock", "plist", "icns", "dmg", "pkg", "log", "dat", "bin", "sql",
                "db", "svg",
            ]
            guard !fileExtensions.contains(tld.lowercased()) else { return nil }
        }
        return CommandItem(
            id: "url.\(candidate)",
            title: "Open \(trimmed)",
            subtitle: "Open URL in the default browser",
            kind: .quicklink,
            keywords: ["url", "open", "web"],
            icon: .symbol("globe"),
            action: .openURL(candidate)
        )
    }

    // MARK: - Navigation

    func moveSelection(by delta: Int) {
        if actionMode {
            guard !actions.isEmpty else { return }
            selectedActionIndex = max(0, min(actions.count - 1, selectedActionIndex + delta))
        } else {
            guard !flatResults.isEmpty else { return }
            hasUserMovedSelection = true
            selectedIndex = max(0, min(flatResults.count - 1, selectedIndex + delta))
        }
    }

    func select(index: Int) {
        guard flatResults.indices.contains(index) else { return }
        hasUserMovedSelection = true
        selectedIndex = index
        if actionMode {
            actions = actionsForSelected()
            selectedActionIndex = 0
        }
    }

    func handleTab() {
        if actionMode {
            exitActionMode()
        } else {
            enterActionMode()
        }
    }

    func enterActionMode() {
        guard selectedResult != nil else { return }
        actions = actionsForSelected()
        selectedActionIndex = 0
        actionMode = true
    }

    func exitActionMode() {
        actionMode = false
        actions = []
        selectedActionIndex = 0
        focusRequest += 1
    }

    func setMode(_ newMode: SearchMode) {
        mode = newMode
        isResetting = true
        query = ""
        isResetting = false
        selectedIndex = 0
        actionMode = false
        actions = []
        fileResults = []
        rebuild()
        focusRequest += 1
    }

    // MARK: - Actions

    func executeSelected() {
        if actionMode {
            executeAction(selectedAction)
        } else if let selectedResult {
            execute(result: selectedResult)
        }
    }

    func execute(result: SearchResult) {
        store.recordUsage(id: result.item.id)
        execute(item: result.item)
    }

    func executeAction(_ descriptor: ActionDescriptor?) {
        guard let descriptor else { return }
        execute(item: CommandItem(
            id: descriptor.id,
            title: descriptor.title,
            subtitle: descriptor.subtitle,
            kind: .command,
            icon: descriptor.icon,
            action: descriptor.action
        ))
    }

    private func execute(item: CommandItem) {
        switch item.action {
        case .openApplication(let path):
            applicationIndex.open(path: path)
            dismiss()

        case .openPath(let path):
            if path.hasSuffix(".app") {
                applicationIndex.open(path: path)
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
            dismiss()

        case .revealPath(let path):
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            dismiss()

        case .openURL(let string):
            guard let url = URL(string: string) else {
                showError("The URL “\(string)” is not valid.")
                return
            }
            NSWorkspace.shared.open(url)
            dismiss()

        case .beginQuicklink(let keyword):
            mode = .root
            actionMode = false
            actions = []
            query = keyword + " "
            selectedIndex = 0
            focusRequest += 1

        case .copyText(let text):
            PasteService.copy(text)
            dismiss()

        case .pasteText(let text):
            dismiss()
            PasteService.paste(text, autoPaste: store.settings.autoPaste)

        case .copyClipboard(let id):
            guard let record = clipboard.items.first(where: { $0.id == id }) else { return }
            clipboard.copy(record)
            dismiss()

        case .pasteClipboard(let id):
            guard let record = clipboard.items.first(where: { $0.id == id }) else { return }
            clipboard.copy(record)
            dismiss()
            if store.settings.autoPaste {
                PasteService.simulatePaste()
            }

        case .pinClipboard(let id):
            guard let record = clipboard.items.first(where: { $0.id == id }) else { return }
            clipboard.togglePin(record)
            rebuild()
            actions = actionsForSelected()
            showStatus(record.pinned ? "Unpinned" : "Pinned")

        case .removeClipboard(let id):
            guard let record = clipboard.items.first(where: { $0.id == id }) else { return }
            clipboard.remove(record)
            actionMode = false
            rebuild()
            showStatus("Removed from clipboard history")

        case .window(let command):
            dismiss()
            // Give the previous app a moment to become active again so the
            // Accessibility call targets the window the user actually saw.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                do {
                    try self?.windowManager.perform(command)
                } catch {
                    self?.showError(error.localizedDescription)
                }
            }

        case .system(let command):
            if command.requiresConfirmation {
                let action = { [weak self] in
                    guard let self else { return }
                    self.dismiss()
                    if case .failed(let message) = self.systemActions.perform(command) {
                        self.showError(message)
                    }
                }
                dismiss()
                onConfirm?(command.title, "Are you sure you want to \(command.title.lowercased())?", action)
            } else {
                dismiss()
                if case .failed(let message) = systemActions.perform(command) {
                    showError(message)
                }
            }

        case .setSearchMode(let newMode):
            setMode(newMode)

        case .showSettings:
            dismiss()
            onSettings?()

        case .showAbout:
            dismiss()
            onAbout?()

        case .checkForUpdates:
            dismiss()
            SparkleUpdaterService.shared.checkForUpdates(nil)

        case .quit:
            NSApp.terminate(nil)

        case .runScript(let name, let script):
            guard !script.isEmpty else {
                showError("This extension command has no script.")
                return
            }
            guard let command = extensions.commands.first(where: { $0.title == name && $0.script == script }) else {
                showError("The extension command could not be found. Try reloading extensions.")
                return
            }
            dismiss()
            let extensionStore = extensions
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = extensionStore.run(command)
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let output):
                        PasteService.copy(output)
                        self.onOutput?(command.title, output)
                    case .failure(let error):
                        self.showError(error.localizedDescription)
                    }
                }
            }

        case .reloadExtensions:
            extensions.reload()
            rebuild()
            showStatus("Extensions reloaded (\(extensions.commands.count) commands)")

        case .newSnippet:
            dismiss()
            onCreateSnippet?(nil)

        case .editSnippet(let id):
            guard let snippet = store.snippets().first(where: { $0.id == id }) else { return }
            dismiss()
            onCreateSnippet?(snippet)

        case .deleteSnippet(let id):
            store.removeSnippet(id: id)
            actionMode = false
            rebuild()
            showStatus("Snippet deleted")

        case .newQuicklink:
            dismiss()
            onCreateQuicklink?(nil)

        case .editQuicklink(let id):
            guard let link = store.quicklinks().first(where: { $0.id == id }) else { return }
            dismiss()
            onCreateQuicklink?(link)

        case .deleteQuicklink(let id):
            store.removeQuicklink(id: id)
            actionMode = false
            rebuild()
            showStatus("Quicklink deleted")

        case .askAgent(let driverID, let prompt):
            guard let kind = CodingDriverKind(rawValue: driverID) else { return }
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                setMode(.ai)
                return
            }
            sendAgentPrompt(driver: kind, prompt: trimmed)

        case .selectActiveAgent(let driverID):
            var s = store.settings
            s.activeCodingDriver = driverID
            if !s.enabledCodingDrivers.contains(driverID) {
                s.enabledCodingDrivers.append(driverID)
            }
            store.settings = s
            rebuild()
            if let kind = CodingDriverKind(rawValue: driverID) {
                showStatus("\(kind.displayName) set as default coding agent")
            }

        case .selectAgentModel(let driverID, let modelID):
            var s = store.settings
            s.selectedCodingModels[driverID] = modelID
            s.activeCodingDriver = driverID
            store.settings = s
            actionMode = false
            rebuild()
            if let kind = CodingDriverKind(rawValue: driverID) {
                let label = codingTools.models(for: kind).first(where: { $0.slug == modelID })?.label ?? modelID
                showStatus("\(kind.displayName) model set to \(label)")
            }

        case .connectComposioToolkit(let slug):
            composio.toggleConnection(slug: slug) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.rebuild()
                    if case .success(let message) = result {
                        self.showStatus(message)
                    }
                }
            }

        case .addCustomComposioToolkit:
            dismiss()
            onAddCustomConnector?()

        case .removeCustomComposioToolkit(let slug):
            composio.removeCustomConnector(slug: slug)
            actionMode = false
            rebuild()
            showStatus("Removed custom connector \(slug)")

        case .triggerComposioAction(let slug, let actionName):
            if let toolkit = composio.catalog.first(where: { $0.slug == slug }),
               let url = URL(string: toolkit.webURL) {
                NSWorkspace.shared.open(url)
            }
            showStatus("Triggered \(actionName) via Composio (\(slug.capitalized))")
            dismiss()

        case .showFloatingNote:
            dismiss()
            onShowFloatingNotes?()

        case .triggerConfetti:
            dismiss()
            onTriggerConfetti?()
        }
    }

    func actionsForSelected() -> [ActionDescriptor] {
        guard let result = selectedResult else { return [] }
        let item = result.item
        var actions: [ActionDescriptor] = []

        switch item.action {
        case .openApplication(let path):
            actions.append(action("open", "Open Application", icon: .symbol("arrow.up.forward.app"), shortcut: "↵", action: .openApplication(path: path)))
            actions.append(action("reveal", "Show in Finder", icon: .symbol("folder"), action: .revealPath(path: path)))
            actions.append(action("copy", "Copy Name", icon: .symbol("doc.on.doc"), action: .copyText(item.title)))

        case .openPath(let path):
            actions.append(action("open", "Open", icon: .symbol("arrow.up.forward.app"), shortcut: "↵", action: .openPath(path: path)))
            actions.append(action("reveal", "Show in Finder", icon: .symbol("folder"), action: .revealPath(path: path)))
            actions.append(action("copy", "Copy Path", icon: .symbol("doc.on.doc"), action: .copyText(path)))

        case .openURL(let string):
            actions.append(action("open", "Open in Browser", icon: .symbol("safari"), shortcut: "↵", action: .openURL(string)))
            actions.append(action("copy", "Copy URL", icon: .symbol("doc.on.doc"), action: .copyText(string)))
            if item.id.hasPrefix("quicklink."), let link = quicklink(for: item.id) {
                actions.append(action("edit", "Edit Quicklink", icon: .symbol("pencil"), action: .editQuicklink(id: link.id)))
                actions.append(action("delete", "Delete Quicklink", icon: .symbol("trash"), action: .deleteQuicklink(id: link.id)))
            }

        case .beginQuicklink(let keyword):
            actions.append(action("search", "Search with Quicklink", icon: .symbol("link"), shortcut: "↵", action: .beginQuicklink(keyword: keyword)))
            if let link = store.quicklinks().first(where: { $0.keyword.lowercased() == keyword.lowercased() }) {
                actions.append(action("copy", "Copy URL", icon: .symbol("doc.on.doc"), action: .copyText(link.urlTemplate)))
                actions.append(action("edit", "Edit Quicklink", icon: .symbol("pencil"), action: .editQuicklink(id: link.id)))
                actions.append(action("delete", "Delete Quicklink", icon: .symbol("trash"), action: .deleteQuicklink(id: link.id)))
            }

        case .pasteClipboard(let id):
            actions.append(action("paste", "Paste", icon: .symbol("doc.on.clipboard"), shortcut: "↵", action: .pasteClipboard(id: id)))
            actions.append(action("copy", "Copy", icon: .symbol("doc.on.doc"), action: .copyClipboard(id: id)))
            if let record = clipboard.items.first(where: { $0.id == id }) {
                actions.append(action(
                    "pin",
                    record.pinned ? "Unpin" : "Pin",
                    icon: .symbol(record.pinned ? "pin.slash" : "pin"),
                    action: .pinClipboard(id: id)
                ))
                actions.append(action("remove", "Remove from History", icon: .symbol("trash"), action: .removeClipboard(id: id)))
            }

        case .pasteText(let text):
            actions.append(action("paste", "Paste", icon: .symbol("doc.on.clipboard"), shortcut: "↵", action: .pasteText(text)))
            actions.append(action("copy", "Copy", icon: .symbol("doc.on.doc"), action: .copyText(text)))
            if item.id.hasPrefix("snippet.") {
                let snippetID = String(item.id.dropFirst("snippet.".count))
                if let snippet = store.snippets().first(where: { $0.id == snippetID }) {
                    actions.append(action("edit", "Edit Snippet", icon: .symbol("pencil"), action: .editSnippet(id: snippet.id)))
                    actions.append(action("delete", "Delete Snippet", icon: .symbol("trash"), action: .deleteSnippet(id: snippet.id)))
                }
            }

        case .copyText(let text):
            actions.append(action("copy", "Copy", icon: .symbol("doc.on.doc"), shortcut: "↵", action: .copyText(text)))

        case .window(let command):
            actions.append(action("run", "Move Window", icon: .symbol(command.symbol), shortcut: "↵", action: .window(command)))

        case .system(let command):
            actions.append(action("run", "Run", icon: command.icon, shortcut: "↵", action: .system(command)))

        case .setSearchMode(let mode):
            actions.append(action("open", "Open", icon: item.icon, shortcut: "↵", action: .setSearchMode(mode)))

        case .runScript(_, _):
            if let command = extensions.commands.first(where: { $0.title == item.title }) {
                actions.append(action(
                    "run",
                    "Run Script",
                    icon: item.icon,
                    shortcut: "↵",
                    action: .runScript(name: command.title, script: command.script ?? "")
                ))
                actions.append(action(
                    "reveal",
                    "Show Extension Folder",
                    icon: .symbol("folder"),
                    action: .revealPath(path: AppPaths.extensionsDirectory.path)
                ))
            }

        case .showSettings:
            actions.append(action("open", "Open Settings", icon: item.icon, shortcut: "↵", action: .showSettings))
        case .showAbout:
            actions.append(action("open", "Show About", icon: item.icon, shortcut: "↵", action: .showAbout))
        case .checkForUpdates:
            actions.append(action("updates", "Check for Updates…", icon: item.icon, shortcut: "↵", action: .checkForUpdates))
        case .quit:
            actions.append(action("quit", "Quit", icon: item.icon, shortcut: "↵", action: .quit))
        case .reloadExtensions:
            actions.append(action("reload", "Reload", icon: item.icon, shortcut: "↵", action: .reloadExtensions))
        case .revealPath(let path):
            actions.append(action("reveal", "Show in Finder", icon: item.icon, shortcut: "↵", action: .revealPath(path: path)))
        case .copyClipboard(let id):
            actions.append(action("copy", "Copy", icon: .symbol("doc.on.doc"), shortcut: "↵", action: .copyClipboard(id: id)))
        case .newSnippet:
            actions.append(action("new", "New Snippet", icon: item.icon, shortcut: "↵", action: .newSnippet))
        case .newQuicklink:
            actions.append(action("new", "New Quicklink", icon: item.icon, shortcut: "↵", action: .newQuicklink))
        case .editSnippet(let id):
            actions.append(action("edit", "Edit Snippet", icon: item.icon, shortcut: "↵", action: .editSnippet(id: id)))
        case .deleteSnippet(let id):
            actions.append(action("delete", "Delete Snippet", icon: item.icon, shortcut: "↵", action: .deleteSnippet(id: id)))
        case .editQuicklink(let id):
            actions.append(action("edit", "Edit Quicklink", icon: item.icon, shortcut: "↵", action: .editQuicklink(id: id)))
        case .deleteQuicklink(let id):
            actions.append(action("delete", "Delete Quicklink", icon: item.icon, shortcut: "↵", action: .deleteQuicklink(id: id)))
        case .askAgent(let driverID, let prompt):
            actions.append(action("ask", "Ask Agent", icon: item.icon, shortcut: "↵", action: .askAgent(driverID: driverID, prompt: prompt)))
            actions.append(action("default", "Set as Default Driver", icon: .symbol("star"), action: .selectActiveAgent(driverID: driverID)))
            if let kind = CodingDriverKind(rawValue: driverID) {
                for modelOpt in codingTools.models(for: kind).prefix(10) {
                    actions.append(action(
                        "model.\(modelOpt.slug)",
                        "Use Model: \(modelOpt.label)",
                        icon: item.icon,
                        action: .selectAgentModel(driverID: driverID, modelID: modelOpt.slug)
                    ))
                }
            }
        case .selectActiveAgent(let driverID):
            actions.append(action("select", "Set as Active Driver", icon: item.icon, shortcut: "↵", action: .selectActiveAgent(driverID: driverID)))
            if let kind = CodingDriverKind(rawValue: driverID) {
                for modelOpt in codingTools.models(for: kind).prefix(12) {
                    actions.append(action(
                        "model.\(modelOpt.slug)",
                        "Model: \(modelOpt.label)",
                        icon: item.icon,
                        action: .selectAgentModel(driverID: driverID, modelID: modelOpt.slug)
                    ))
                }
            }
        case .selectAgentModel(let driverID, let modelID):
            actions.append(action("setmodel", "Use Model \(modelID)", icon: item.icon, shortcut: "↵", action: .selectAgentModel(driverID: driverID, modelID: modelID)))
        case .connectComposioToolkit(let slug):
            actions.append(action("connect", "Toggle Composio Connection", icon: item.icon, shortcut: "↵", action: .connectComposioToolkit(slug: slug)))
            if let tk = composio.catalog.first(where: { $0.slug == slug }) {
                actions.append(action("open", "Open \(tk.name) Web App", icon: .symbol("safari"), action: .openURL(tk.webURL)))
                actions.append(action("marketplace", "View in Composio Marketplace", icon: .symbol("link"), action: .openURL("https://platform.composio.dev/marketplace/\(slug)")))
            }
            if store.settings.customComposioConnectors.contains(where: { $0.slug == slug }) {
                actions.append(action("remove", "Remove Custom Connector", icon: .symbol("trash"), action: .removeCustomComposioToolkit(slug: slug)))
            }
        case .addCustomComposioToolkit:
            actions.append(action("add", "Add Custom Connector", icon: item.icon, shortcut: "↵", action: .addCustomComposioToolkit))
        case .removeCustomComposioToolkit(let slug):
            actions.append(action("remove", "Remove Custom Connector", icon: item.icon, shortcut: "↵", action: .removeCustomComposioToolkit(slug: slug)))
        case .triggerComposioAction(let slug, let actionName):
            actions.append(action("run", "Run \(actionName)", icon: item.icon, shortcut: "↵", action: .triggerComposioAction(slug: slug, actionName: actionName)))
        case .showFloatingNote:
            actions.append(action("note", "Open Floating Notes", icon: item.icon, shortcut: "↵", action: .showFloatingNote))
        case .triggerConfetti:
            actions.append(action("confetti", "Celebrate!", icon: item.icon, shortcut: "↵", action: .triggerConfetti))
        case .pinClipboard, .removeClipboard:
            break
        }

        return actions
    }

    private func quicklink(for itemID: String) -> Quicklink? {
        let identifier = String(itemID.dropFirst("quicklink.".count))
        return store.quicklinks().first { $0.id == identifier }
    }

    private func action(
        _ id: String,
        _ title: String,
        subtitle: String = "",
        icon: IconSpec,
        shortcut: String? = nil,
        action: CommandAction
    ) -> ActionDescriptor {
        ActionDescriptor(
            id: "action.\(id).\(selectedResult?.id ?? "")",
            title: title,
            subtitle: subtitle,
            icon: icon,
            shortcut: shortcut,
            action: action
        )
    }

    // MARK: - Helpers

    func dismiss() {
        onDismiss?()
    }

    func showStatus(_ message: String) {
        statusWorkItem?.cancel()
        statusMessage = message
        let workItem = DispatchWorkItem { [weak self] in
            self?.statusMessage = nil
        }
        statusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
    }

    func showError(_ message: String) {
        onError?(message)
    }

    func sendAgentPrompt(driver: CodingDriverKind? = nil, prompt: String) {
        let chosen = driver ?? CodingDriverKind(rawValue: store.settings.activeCodingDriver) ?? .claude
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let selectedModel = store.settings.selectedCodingModels[chosen.rawValue]
        let effort = store.settings.selectedReasoningEffort
        let modelLabel = selectedModel.flatMap { slug in
            codingTools.models(for: chosen).first(where: { $0.slug == slug })?.label ?? (slug == "default" ? nil : slug)
        } ?? chosen.defaultModels.dropFirst().first?.label ?? "Default"
        actionMode = false
        isRunningAgent = true
        activeAgentTitle = "\(chosen.displayName) · \(modelLabel)"
        activeAgentPrompt = trimmed
        activeAgentResponse = "Thinking with \(chosen.displayName) (\(modelLabel))…"
        codingTools.runPrompt(
            driver: chosen,
            model: selectedModel,
            effort: effort,
            prompt: trimmed
        ) { [weak self] partial in
            DispatchQueue.main.async {
                self?.activeAgentResponse = partial
            }
        } onComplete: { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRunningAgent = false
                switch result {
                case .success(let output):
                    self.activeAgentResponse = output
                case .failure(let error):
                    self.activeAgentResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    func submitFollowUpAgentPrompt() {
        let text = agentFollowUpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        agentFollowUpInput = ""
        sendAgentPrompt(prompt: text)
    }

    func clearAgentResponse() {
        codingTools.cancelActiveRun()
        isRunningAgent = false
        activeAgentResponse = nil
        activeAgentTitle = ""
        activeAgentPrompt = ""
        agentFollowUpInput = ""
    }

    var selectedClipboardRecord: ClipboardRecord? {
        guard mode == .clipboard, let selected = selectedResult else { return nil }
        guard case .pasteClipboard(let id) = selected.item.action else { return nil }
        return clipboard.items.first { $0.id == id }
    }

    var activeCodingDriverKind: CodingDriverKind {
        CodingDriverKind(rawValue: store.settings.activeCodingDriver) ?? .claude
    }

    var activeCodingDriverModels: [CodingModelOption] {
        codingTools.models(for: activeCodingDriverKind)
    }

    var activeCodingModelSlug: String {
        store.settings.selectedCodingModels[activeCodingDriverKind.rawValue] ?? "default"
    }

    var activeCodingModelLabel: String {
        let slug = activeCodingModelSlug
        if let found = activeCodingDriverModels.first(where: { $0.slug == slug }), slug != "default" {
            return found.label
        }
        return activeCodingDriverModels.dropFirst().first?.label ?? "Default"
    }

    func setActiveDriverAndModel(driver: CodingDriverKind, modelSlug: String? = nil) {
        var s = store.settings
        s.activeCodingDriver = driver.rawValue
        if let modelSlug {
            s.selectedCodingModels[driver.rawValue] = modelSlug
        }
        store.settings = s
        rebuild()
    }

    func setReasoningEffort(_ effort: String) {
        var s = store.settings
        s.selectedReasoningEffort = effort
        store.settings = s
    }

    func reloadExtensions() {
        extensions.reload()
        rebuild()
    }
}
