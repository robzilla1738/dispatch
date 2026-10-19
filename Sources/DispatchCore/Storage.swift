import Foundation

public enum ClipboardKind: String, Codable, Sendable {
    case text
    case image
    case file
}

public struct ClipboardRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var date: Date
    public var sourceApp: String
    public var sourcePath: String?
    public var kind: ClipboardKind
    public var imagePath: String?
    public var pinned: Bool

    public init(
        id: String = UUID().uuidString,
        text: String,
        date: Date = Date(),
        sourceApp: String = "",
        sourcePath: String? = nil,
        kind: ClipboardKind = .text,
        imagePath: String? = nil,
        pinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.sourceApp = sourceApp
        self.sourcePath = sourcePath
        self.kind = kind
        self.imagePath = imagePath
        self.pinned = pinned
    }
}

public struct Snippet: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var text: String
    public var keyword: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        text: String,
        keyword: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.keyword = keyword
        self.createdAt = createdAt
    }
}

public struct Quicklink: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var urlTemplate: String
    public var keyword: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        urlTemplate: String,
        keyword: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlTemplate = urlTemplate
        self.keyword = keyword
        self.createdAt = createdAt
    }
}

public struct UsageRecord: Codable, Equatable, Sendable {
    public var count: Int
    public var lastUsed: Date

    public init(count: Int = 0, lastUsed: Date = .distantPast) {
        self.count = count
        self.lastUsed = lastUsed
    }
}

public struct CustomComposioConnector: Codable, Identifiable, Equatable, Sendable {
    public var id: String { slug }
    public var slug: String
    public var name: String
    public var category: String
    public var description: String
    public var webURL: String
    public var sampleActions: [String]

    public init(
        slug: String,
        name: String,
        category: String = "Custom Connector",
        description: String = "Composio connected integration",
        webURL: String = "https://platform.composio.dev",
        sampleActions: [String] = ["Open Dashboard", "Run Action"]
    ) {
        self.slug = slug
        self.name = name
        self.category = category
        self.description = description
        self.webURL = webURL
        self.sampleActions = sampleActions
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var clipboardHistoryLimit: Int
    public var hotkeyKeyCode: Int
    public var hotkeyModifiers: Int
    public var launchAtLogin: Bool
    public var theme: String
    public var fileSearchEnabled: Bool
    public var autoPaste: Bool
    public var showRecentApplications: Bool
    public var maxFileResults: Int
    public var snippetExpansionEnabled: Bool
    public var activeCodingDriver: String
    public var enabledCodingDrivers: [String]
    public var composioApiKey: String
    public var composioUserId: String
    public var connectedComposioToolkits: [String]
    public var customComposioConnectors: [CustomComposioConnector]
    public var floatingNoteText: String
    public var selectedCodingModels: [String: String]
    public var selectedReasoningEffort: String

    public init(
        clipboardHistoryLimit: Int = 500,
        hotkeyKeyCode: Int = 49,
        hotkeyModifiers: Int = 2048,
        launchAtLogin: Bool = false,
        theme: String = "system",
        fileSearchEnabled: Bool = true,
        autoPaste: Bool = true,
        showRecentApplications: Bool = true,
        maxFileResults: Int = 20,
        snippetExpansionEnabled: Bool = true,
        activeCodingDriver: String = "claude",
        enabledCodingDrivers: [String] = ["claude", "codex", "opencode", "cursor", "grok", "pi"],
        composioApiKey: String = "",
        composioUserId: String = "dispatch-default-user",
        connectedComposioToolkits: [String] = [],
        customComposioConnectors: [CustomComposioConnector] = [],
        floatingNoteText: String = "Quick scratchpad note — type anything here…",
        selectedCodingModels: [String: String] = [:],
        selectedReasoningEffort: String = "medium"
    ) {
        self.clipboardHistoryLimit = clipboardHistoryLimit
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.launchAtLogin = launchAtLogin
        self.theme = theme
        self.fileSearchEnabled = fileSearchEnabled
        self.autoPaste = autoPaste
        self.showRecentApplications = showRecentApplications
        self.maxFileResults = maxFileResults
        self.snippetExpansionEnabled = snippetExpansionEnabled
        self.activeCodingDriver = activeCodingDriver
        self.enabledCodingDrivers = enabledCodingDrivers
        self.composioApiKey = composioApiKey
        self.composioUserId = composioUserId
        self.connectedComposioToolkits = connectedComposioToolkits
        self.customComposioConnectors = customComposioConnectors
        self.floatingNoteText = floatingNoteText
        self.selectedCodingModels = selectedCodingModels
        self.selectedReasoningEffort = selectedReasoningEffort
    }

    private enum CodingKeys: String, CodingKey {
        case clipboardHistoryLimit
        case hotkeyKeyCode
        case hotkeyModifiers
        case launchAtLogin
        case theme
        case fileSearchEnabled
        case autoPaste
        case showRecentApplications
        case maxFileResults
        case snippetExpansionEnabled
        case activeCodingDriver
        case enabledCodingDrivers
        case composioApiKey
        case composioUserId
        case connectedComposioToolkits
        case customComposioConnectors
        case floatingNoteText
        case selectedCodingModels
        case selectedReasoningEffort
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        clipboardHistoryLimit = try container.decodeIfPresent(Int.self, forKey: .clipboardHistoryLimit) ?? defaults.clipboardHistoryLimit
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode) ?? defaults.hotkeyKeyCode
        hotkeyModifiers = try container.decodeIfPresent(Int.self, forKey: .hotkeyModifiers) ?? defaults.hotkeyModifiers
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? defaults.theme
        fileSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .fileSearchEnabled) ?? defaults.fileSearchEnabled
        autoPaste = try container.decodeIfPresent(Bool.self, forKey: .autoPaste) ?? defaults.autoPaste
        showRecentApplications = try container.decodeIfPresent(Bool.self, forKey: .showRecentApplications) ?? defaults.showRecentApplications
        maxFileResults = try container.decodeIfPresent(Int.self, forKey: .maxFileResults) ?? defaults.maxFileResults
        snippetExpansionEnabled = try container.decodeIfPresent(Bool.self, forKey: .snippetExpansionEnabled) ?? defaults.snippetExpansionEnabled
        activeCodingDriver = try container.decodeIfPresent(String.self, forKey: .activeCodingDriver) ?? defaults.activeCodingDriver
        enabledCodingDrivers = try container.decodeIfPresent([String].self, forKey: .enabledCodingDrivers) ?? defaults.enabledCodingDrivers
        composioApiKey = try container.decodeIfPresent(String.self, forKey: .composioApiKey) ?? defaults.composioApiKey
        composioUserId = try container.decodeIfPresent(String.self, forKey: .composioUserId) ?? defaults.composioUserId
        connectedComposioToolkits = try container.decodeIfPresent([String].self, forKey: .connectedComposioToolkits) ?? defaults.connectedComposioToolkits
        customComposioConnectors = try container.decodeIfPresent([CustomComposioConnector].self, forKey: .customComposioConnectors) ?? defaults.customComposioConnectors
        floatingNoteText = try container.decodeIfPresent(String.self, forKey: .floatingNoteText) ?? defaults.floatingNoteText
        selectedCodingModels = try container.decodeIfPresent([String: String].self, forKey: .selectedCodingModels) ?? defaults.selectedCodingModels
        selectedReasoningEffort = try container.decodeIfPresent(String.self, forKey: .selectedReasoningEffort) ?? defaults.selectedReasoningEffort
    }
}

private struct PersistedState: Codable {
    var version: Int = 1
    var clipboard: [ClipboardRecord] = []
    var snippets: [Snippet] = []
    var quicklinks: [Quicklink] = []
    var usage: [String: UsageRecord] = [:]
    var settings: AppSettings = AppSettings()
}

public enum AppPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Dispatch", isDirectory: true)
    }

    public static var extensionsDirectory: URL {
        supportDirectory.appendingPathComponent("Extensions", isDirectory: true)
    }

    public static var clipboardDirectory: URL {
        supportDirectory.appendingPathComponent("Clipboard", isDirectory: true)
    }

    public static var logDirectory: URL {
        supportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }
}

/// Thread-safe JSON persistence. The store is deliberately dependency-free so
/// the app can be built with only the macOS command line tools.
public final class AppStore {
    public static let shared = AppStore()

    public let directory: URL
    private let stateURL: URL
    private var state: PersistedState
    private let lock = NSLock()

    public init(directory: URL? = nil) {
        let directory = directory ?? AppPaths.supportDirectory
        self.directory = directory
        self.stateURL = directory.appendingPathComponent("state.json")
        self.state = PersistedState()

        let hadState = FileManager.default.fileExists(atPath: stateURL.path)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: AppPaths.clipboardDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: AppPaths.extensionsDirectory, withIntermediateDirectories: true)
        load()
        if !hadState {
            seedIfNeeded()
        }
    }

    // MARK: - Settings

    public var settings: AppSettings {
        get {
            lock.lock()
            defer { lock.unlock() }
            return state.settings
        }
        set {
            lock.lock()
            state.settings = newValue
            saveLocked()
            lock.unlock()
        }
    }

    // MARK: - Clipboard

    @discardableResult
    public func addClipboard(
        text: String,
        sourceApp: String,
        sourcePath: String? = nil,
        kind: ClipboardKind = .text,
        imagePath: String? = nil
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imagePath != nil else { return false }

        lock.lock()
        defer { lock.unlock() }

        if let index = state.clipboard.firstIndex(where: {
            $0.kind == kind && $0.text == trimmed && $0.imagePath == imagePath
        }) {
            state.clipboard[index].date = Date()
            state.clipboard[index].sourceApp = sourceApp
            state.clipboard[index].sourcePath = sourcePath
            let record = state.clipboard.remove(at: index)
            state.clipboard.insert(record, at: 0)
            saveLocked()
            return false
        }

        let record = ClipboardRecord(
            text: trimmed,
            sourceApp: sourceApp,
            sourcePath: sourcePath,
            kind: kind,
            imagePath: imagePath
        )
        state.clipboard.insert(record, at: 0)
        trimClipboardLocked()
        saveLocked()
        return true
    }

    public func clipboardItems() -> [ClipboardRecord] {
        lock.lock()
        defer { lock.unlock() }
        let pinned = state.clipboard.filter(\.pinned)
        let unpinned = state.clipboard.filter { !$0.pinned }.sorted { $0.date > $1.date }
        return pinned.sorted { $0.date > $1.date } + unpinned
    }

    public func toggleClipboardPin(id: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = state.clipboard.firstIndex(where: { $0.id == id }) else { return }
        state.clipboard[index].pinned.toggle()
        saveLocked()
    }

    public func removeClipboard(id: String) {
        lock.lock()
        defer { lock.unlock() }
        state.clipboard.removeAll { $0.id == id }
        saveLocked()
    }

    public func clearClipboard(keepPinned: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        if keepPinned {
            state.clipboard.removeAll { !$0.pinned }
        } else {
            state.clipboard.removeAll()
        }
        saveLocked()
    }

    private func trimClipboardLocked() {
        let limit = max(50, state.settings.clipboardHistoryLimit)
        guard state.clipboard.count > limit else { return }
        var overflow = state.clipboard.count - limit
        var index = state.clipboard.count - 1
        while overflow > 0 && index >= 0 {
            if !state.clipboard[index].pinned {
                state.clipboard.remove(at: index)
                overflow -= 1
            }
            index -= 1
        }
    }

    // MARK: - Snippets

    public func snippets() -> [Snippet] {
        lock.lock()
        defer { lock.unlock() }
        return state.snippets.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func upsertSnippet(_ snippet: Snippet) {
        lock.lock()
        defer { lock.unlock() }
        if let index = state.snippets.firstIndex(where: { $0.id == snippet.id }) {
            state.snippets[index] = snippet
        } else {
            state.snippets.append(snippet)
        }
        saveLocked()
    }

    public func removeSnippet(id: String) {
        lock.lock()
        defer { lock.unlock() }
        state.snippets.removeAll { $0.id == id }
        saveLocked()
    }

    // MARK: - Quicklinks

    public func quicklinks() -> [Quicklink] {
        lock.lock()
        defer { lock.unlock() }
        return state.quicklinks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func upsertQuicklink(_ quicklink: Quicklink) {
        lock.lock()
        defer { lock.unlock() }
        if let index = state.quicklinks.firstIndex(where: { $0.id == quicklink.id }) {
            state.quicklinks[index] = quicklink
        } else {
            state.quicklinks.append(quicklink)
        }
        saveLocked()
    }

    public func removeQuicklink(id: String) {
        lock.lock()
        defer { lock.unlock() }
        state.quicklinks.removeAll { $0.id == id }
        saveLocked()
    }

    // MARK: - Usage

    public func recordUsage(id: String) {
        lock.lock()
        defer { lock.unlock() }
        var record = state.usage[id] ?? UsageRecord()
        record.count += 1
        record.lastUsed = Date()
        state.usage[id] = record
        saveLocked()
    }

    public func usageScores() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        var scores: [String: Double] = [:]
        for (id, record) in state.usage {
            let ageInDays = max(0, now.timeIntervalSince(record.lastUsed) / 86_400)
            let recency = max(0, 14 - ageInDays) * 0.8
            scores[id] = Double(record.count) * 1.5 + recency
        }
        return scores
    }

    public func resetUsage() {
        lock.lock()
        defer { lock.unlock() }
        state.usage.removeAll()
        saveLocked()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: stateURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(PersistedState.self, from: data) {
            state = decoded
        }
    }

    private func seedIfNeeded() {
        guard state.quicklinks.isEmpty, state.snippets.isEmpty else { return }
        state.quicklinks = [
            Quicklink(title: "Google", urlTemplate: "https://www.google.com/search?q={query}", keyword: "g"),
            Quicklink(title: "GitHub", urlTemplate: "https://github.com/search?q={query}", keyword: "gh"),
            Quicklink(title: "Wikipedia", urlTemplate: "https://en.wikipedia.org/w/index.php?search={query}", keyword: "wiki"),
        ]
        state.snippets = [
            Snippet(
                title: "Email Signature",
                text: "Best regards,\nRobert",
                keyword: "sig"
            )
        ]
        saveLocked()
    }

    private func saveLocked() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    /// A stable export used by the self-test command.
    public func debugSummary() -> String {
        lock.lock()
        defer { lock.unlock() }
        return "clipboard=\(state.clipboard.count) snippets=\(state.snippets.count) quicklinks=\(state.quicklinks.count) usage=\(state.usage.count)"
    }
}
