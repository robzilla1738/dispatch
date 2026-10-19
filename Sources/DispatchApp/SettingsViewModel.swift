import AppKit
import Combine
import Foundation
import DispatchCore
import DispatchServices

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var section: SettingsSection = .general
    @Published var settings: AppSettings {
        didSet {
            store.settings = settings
            onSettingsChanged?(settings)
        }
    }
    @Published var accessibilityTrusted: Bool = false
    @Published var launchAtLoginStatus: String = ""
    @Published var statusMessage: String?
    @Published var extensionCommands: [ScriptCommand] = []
    @Published var extensionErrors: [String] = []
    @Published var clipboardCount: Int = 0
    @Published var snippetCount: Int = 0
    @Published var quicklinkCount: Int = 0
    @Published var isRequestingAccessibility = false
    @Published var detectedTools: [DetectedCodingTool] = []
    @Published var detectedSkills: [LocalSkillEntry] = []
    @Published var detectedMcpServers: [LocalMcpServerEntry] = []
    @Published var isScanningTools = false
    @Published var composioCatalog: [ComposioToolkit] = []
    @Published var isSyncingComposio = false
    @Published var connectorFilterQuery: String = ""
    @Published var newConnectorName: String = ""
    @Published var newConnectorSlug: String = ""
    @Published var newConnectorCategory: String = ""

    let store: AppStore
    let extensions: ExtensionStore
    let clipboard: ClipboardService
    let codingTools: CodingToolsService
    let composio: ComposioService

    var onSettingsChanged: ((AppSettings) -> Void)?
    var onExtensionsReloaded: (() -> Void)?

    private var statusWorkItem: DispatchWorkItem?

    init(
        store: AppStore,
        extensions: ExtensionStore,
        clipboard: ClipboardService,
        codingTools: CodingToolsService = CodingToolsService(),
        composio: ComposioService = ComposioService()
    ) {
        self.store = store
        self.extensions = extensions
        self.clipboard = clipboard
        self.codingTools = codingTools
        self.composio = composio
        self.settings = store.settings
        if Bundle.main.bundleURL.pathExtension == "app" {
            self.settings.launchAtLogin = LaunchAtLogin.isEnabled
        }
        self.launchAtLoginStatus = LaunchAtLogin.statusDescription
        refresh()
    }

    func refresh() {
        accessibilityTrusted = WindowManager.isAccessibilityTrusted()
        launchAtLoginStatus = LaunchAtLogin.statusDescription
        extensionCommands = extensions.commands
        extensionErrors = extensions.loadErrors
        clipboardCount = clipboard.items.count
        snippetCount = store.snippets().count
        quicklinkCount = store.quicklinks().count
        detectedTools = codingTools.tools
        detectedSkills = codingTools.skills
        detectedMcpServers = codingTools.mcpServers
        composioCatalog = composio.catalog
        if detectedTools.isEmpty && !isScanningTools {
            rescanCodingTools()
        }
    }

    func rescanCodingTools() {
        guard !isScanningTools else { return }
        isScanningTools = true
        let service = codingTools
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            service.scanAll()
            DispatchQueue.main.async {
                guard let self else { return }
                self.detectedTools = service.tools
                self.detectedSkills = service.skills
                self.detectedMcpServers = service.mcpServers
                self.isScanningTools = false
                let installedCount = service.tools.filter(\.installed).count
                self.showStatus("Scanned \(installedCount) installed coding CLIs, \(service.skills.count) skills, \(service.mcpServers.count) MCPs")
            }
        }
    }

    func testCodingTool(_ kind: CodingDriverKind) {
        let service = codingTools
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let res = service.testHarness(kind)
            DispatchQueue.main.async {
                guard let self else { return }
                self.detectedTools = service.tools
                if res.installed {
                    self.showStatus("Verified \(kind.displayName): \(res.version ?? "OK") (\(res.latencyMs ?? 0)ms)")
                } else {
                    self.showStatus("\(kind.displayName) not found on PATH")
                }
            }
        }
    }

    func toggleCodingDriverEnabled(_ id: String, enabled: Bool) {
        if enabled {
            if !settings.enabledCodingDrivers.contains(id) {
                settings.enabledCodingDrivers.append(id)
            }
        } else {
            settings.enabledCodingDrivers.removeAll { $0 == id }
        }
    }

    func toggleComposioToolkit(_ slug: String) {
        composio.toggleConnection(slug: slug) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.settings = self.store.settings
                self.composioCatalog = self.composio.catalog
                if case .success(let msg) = result {
                    self.showStatus(msg)
                }
            }
        }
    }

    func syncComposio() {
        guard !isSyncingComposio else { return }
        isSyncingComposio = true
        composio.syncConnectedAccounts { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSyncingComposio = false
                self.settings = self.store.settings
                self.composioCatalog = self.composio.catalog
                switch result {
                case .success(let count):
                    self.showStatus("Synced \(count) connected Composio accounts")
                case .failure(let error):
                    self.showStatus("Composio sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func addCustomComposioConnector() {
        let slug = newConnectorSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else {
            showStatus("Enter a Composio app slug (e.g. airtable, posthog, attio)")
            return
        }
        let name = newConnectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? slug.capitalized
            : newConnectorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = newConnectorCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Custom Connector"
            : newConnectorCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        composio.addCustomConnector(name: name, slug: slug, category: cat)
        settings = store.settings
        composioCatalog = composio.catalog
        newConnectorName = ""
        newConnectorSlug = ""
        newConnectorCategory = ""
        showStatus("Added & connected \(name) (\(slug.lowercased()))")
    }

    func removeCustomComposioConnector(slug: String) {
        composio.removeCustomConnector(slug: slug)
        settings = store.settings
        composioCatalog = composio.catalog
        showStatus("Removed custom connector \(slug)")
    }

    var filteredComposioCatalog: [ComposioToolkit] {
        let q = connectorFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return composioCatalog }
        return composioCatalog.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.slug.localizedCaseInsensitiveContains(q)
                || $0.category.localizedCaseInsensitiveContains(q)
                || $0.description.localizedCaseInsensitiveContains(q)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let succeeded = LaunchAtLogin.setEnabled(enabled)
        settings.launchAtLogin = succeeded ? LaunchAtLogin.isEnabled : enabled
        launchAtLoginStatus = LaunchAtLogin.statusDescription
        if !succeeded {
            showStatus("macOS could not update the login item. Move the app to /Applications and try again.")
        }
        refresh()
    }

    func requestAccessibility() {
        isRequestingAccessibility = true
        WindowManager.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.accessibilityTrusted = WindowManager.isAccessibilityTrusted()
            self?.isRequestingAccessibility = false
        }
    }

    func reloadExtensions() {
        extensions.reload()
        refresh()
        onExtensionsReloaded?()
        showStatus("Extensions reloaded — \(extensions.commands.count) commands")
    }

    func revealExtensions() {
        try? FileManager.default.createDirectory(
            at: AppPaths.extensionsDirectory,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.extensionsDirectory])
    }

    func clearClipboard() {
        clipboard.clear(keepPinned: true)
        refresh()
        showStatus("Clipboard history cleared (pinned items kept)")
    }

    func resetUsage() {
        store.resetUsage()
        showStatus("Search ranking reset")
    }

    func revealDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.supportDirectory])
    }

    func showStatus(_ message: String) {
        statusWorkItem?.cancel()
        statusMessage = message
        let workItem = DispatchWorkItem { [weak self] in
            self?.statusMessage = nil
        }
        statusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    var hotkeyDisplay: String {
        HotKeyManager.displayString(
            keyCode: UInt32(settings.hotkeyKeyCode),
            modifiers: UInt32(settings.hotkeyModifiers)
        )
    }
}
