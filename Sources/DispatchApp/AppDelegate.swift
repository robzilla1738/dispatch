import AppKit
import Foundation
import DispatchCore
import DispatchServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore.shared
    private let applicationIndex = ApplicationIndex()
    private let fileSearch = FileSearchService()
    private let windowManager = WindowManager()
    private let systemActions = SystemActions()
    private let hotKeyManager = HotKeyManager()
    private let codingTools = CodingToolsService()

    private var clipboard: ClipboardService!
    private var composio: ComposioService!
    private var snippetExpander: SnippetExpansionService!
    private var extensions: ExtensionStore!
    private var emojiCatalog: EmojiCatalog!
    private var launcherModel: LauncherViewModel!
    private var launcher: LauncherController!
    private var settingsModel: SettingsViewModel!
    private var settingsController: SettingsWindowController?
    private var floatingNotesController: FloatingNotesWindowController?
    private var statusItem: NSStatusItem?
    private var registeredHotKey: (keyCode: Int, modifiers: Int)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ResourceLoader.registerFonts()
        NSApp.setActivationPolicy(.accessory)

        clipboard = ClipboardService(store: store)
        composio = ComposioService(store: store)
        snippetExpander = SnippetExpansionService(store: store)
        extensions = ExtensionStore()
        emojiCatalog = EmojiCatalog()

        launcherModel = LauncherViewModel(
            store: store,
            applicationIndex: applicationIndex,
            clipboard: clipboard,
            fileSearch: fileSearch,
            windowManager: windowManager,
            systemActions: systemActions,
            extensions: extensions,
            emojiCatalog: emojiCatalog,
            codingTools: codingTools,
            composio: composio
        )
        launcher = LauncherController(model: launcherModel)

        settingsModel = SettingsViewModel(
            store: store,
            extensions: extensions,
            clipboard: clipboard,
            codingTools: codingTools,
            composio: composio
        )
        settingsModel.onSettingsChanged = { [weak self] settings in
            self?.apply(settings: settings)
        }
        settingsModel.onExtensionsReloaded = { [weak self] in
            self?.launcherModel.reloadExtensions()
        }

        launcher.onSettings = { [weak self] in
            self?.showSettings()
        }
        launcherModel.onAbout = { [weak self] in
            self?.showAbout()
        }
        launcherModel.onError = { [weak self] message in
            self?.showError(message)
        }
        launcherModel.onConfirm = { [weak self] title, message, action in
            self?.confirm(title: title, message: message, action: action)
        }
        launcherModel.onOutput = { [weak self] title, output in
            self?.showOutput(title: title, output: output)
        }
        launcherModel.onCreateSnippet = { [weak self] snippet in
            self?.presentSnippetEditor(snippet)
        }
        launcherModel.onCreateQuicklink = { [weak self] link in
            self?.presentQuicklinkEditor(link)
        }
        launcherModel.onAddCustomConnector = { [weak self] in
            self?.presentCustomConnectorEditor()
        }
        launcherModel.onShowFloatingNotes = { [weak self] in
            self?.toggleFloatingNotes()
        }
        launcherModel.onTriggerConfetti = {
            ConfettiOverlay.celebrate()
        }

        setupMainMenu()
        _ = SparkleUpdaterService.shared
        clipboard.start()
        snippetExpander.start()
        apply(settings: store.settings)
        applyDebugAppearance()
        registerHotKey()
        setupStatusItem()

        if CommandLine.arguments.contains("--diagnostics") {
            let hotkey = registeredHotKey.map {
                HotKeyManager.displayString(
                    keyCode: UInt32($0.keyCode),
                    modifiers: UInt32($0.modifiers)
                )
            } ?? "none"
            print("version=\(appVersion) (\(buildVersion))")
            print("bundle=\(Bundle.main.bundlePath)")
            print("data=\(store.directory.path)")
            print("hotkey=\(hotkey)")
            print("login=\(LaunchAtLogin.statusDescription)")
            if CommandLine.arguments.contains("--enable-login") {
                do {
                    try LaunchAtLogin.setEnabledThrowing(true)
                    print("loginAction=registered")
                } catch {
                    print("loginAction=register-failed: \(error.localizedDescription)")
                }
            } else if CommandLine.arguments.contains("--disable-login") {
                do {
                    try LaunchAtLogin.setEnabledThrowing(false)
                    print("loginAction=unregistered")
                } catch {
                    print("loginAction=unregister-failed: \(error.localizedDescription)")
                }
            }
            print("loginAfter=\(LaunchAtLogin.statusDescription)")
            print("accessibility=\(WindowManager.isAccessibilityTrusted())")
            print("extensions=\(extensions.commands.count)")
            print("clipboard=\(clipboard.items.count)")
            codingTools.scanAll()
            let installedHarnesses = codingTools.tools.filter(\.installed).map(\.kind.rawValue).joined(separator: ",")
            print("codingTools=\(installedHarnesses)")
            print("skills=\(codingTools.skills.count)")
            print("mcpServers=\(codingTools.mcpServers.count)")
            print("composioToolkits=\(composio.catalog.count)")
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        }

        if let settingsScreenshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                if let section = self.settingsSectionArgument {
                    self.settingsModel.section = section
                }
                self.showSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    _ = self.settingsController?.captureWindow(to: settingsScreenshotPath)
                    NSApp.terminate(nil)
                }
            }
        } else if let screenshotPath = screenshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                self.showLauncher(mode: self.requestedMode())
                if let query = self.queryArgument {
                    self.launcherModel.query = query
                }
                if let selection = self.selectionArgument {
                    self.launcherModel.select(index: selection)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    if CommandLine.arguments.contains("--actions") {
                        self.launcherModel.enterActionMode()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        _ = self.launcher.captureWindow(to: screenshotPath)
                        if CommandLine.arguments.contains("--exit-after-screenshot") {
                            NSApp.terminate(nil)
                        }
                    }
                }
            }
        } else if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.showLauncher(mode: self?.requestedMode())
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, NSApp.isActive, !CommandLine.arguments.contains("--background") else { return }
                self.launcher.show()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboard?.stop()
        snippetExpander?.stop()
        hotKeyManager.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme?.lowercased() == "dispatch" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawMode = url.host ?? components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let modeName = rawMode?.lowercased()
        let mode = modeName.flatMap(SearchMode.init(rawValue:))
        showLauncher(mode: mode)
        if let query = components?.queryItems?.first(where: { $0.name == "q" })?.value, !query.isEmpty {
            launcherModel.query = query
        }
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Dispatch")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About Dispatch",
            action: #selector(openAboutFromMenu),
            keyEquivalent: ""
        ).target = self
        appMenu.addItem(
            withTitle: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Dispatch",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        ).target = self

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Launcher

    private func showLauncher(mode: SearchMode? = nil) {
        launcher.show(mode: mode)
    }

    private func requestedMode() -> SearchMode? {
        for argument in CommandLine.arguments {
            if argument.hasPrefix("--mode=") {
                let raw = String(argument.dropFirst("--mode=".count))
                return SearchMode(rawValue: raw)
            }
        }
        return nil
    }

    private var screenshotPath: String? {
        CommandLine.arguments
            .first { $0.hasPrefix("--screenshot=") }
            .map { String($0.dropFirst("--screenshot=".count)) }
    }

    private var settingsScreenshotPath: String? {
        CommandLine.arguments
            .first { $0.hasPrefix("--screenshot-settings=") }
            .map { String($0.dropFirst("--screenshot-settings=".count)) }
    }

    private var queryArgument: String? {
        CommandLine.arguments
            .first { $0.hasPrefix("--query=") }
            .map { String($0.dropFirst("--query=".count)) }
    }

    private var settingsSectionArgument: SettingsSection? {
        CommandLine.arguments
            .first { $0.hasPrefix("--settings-section=") }
            .flatMap { SettingsSection(rawValue: String($0.dropFirst("--settings-section=".count))) }
    }

    private var selectionArgument: Int? {
        CommandLine.arguments
            .first { $0.hasPrefix("--select=") }
            .flatMap { Int($0.dropFirst("--select=".count)) }
    }

    private func apply(settings: AppSettings) {
        switch settings.theme {
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }

        if let registeredHotKey,
           registeredHotKey != (settings.hotkeyKeyCode, settings.hotkeyModifiers) {
            registerHotKey(notifyOnFallback: true)
        }
    }

    private func registerHotKey(notifyOnFallback: Bool = false) {
        let settings = store.settings
        hotKeyManager.onHotKey = { [weak self] in
            Task { @MainActor in
                self?.launcher.toggle()
            }
        }

        let requested = (keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
        let candidates = [
            requested,
            (keyCode: 49, modifiers: 2048),          // ⌥Space
            (keyCode: 49, modifiers: 2048 | 4096),   // ⌃⌥Space
            (keyCode: 49, modifiers: 2048 | 256),    // ⌥⌘Space
            (keyCode: 49, modifiers: 4096),          // ⌃Space
        ]

        var chosen: (keyCode: Int, modifiers: Int)?
        for candidate in candidates {
            if hotKeyManager.register(
                keyCode: UInt32(candidate.keyCode),
                modifiers: UInt32(candidate.modifiers)
            ) {
                chosen = candidate
                break
            }
        }

        guard let chosen else {
            registeredHotKey = nil
            showError("No global hotkey could be registered. Use the status bar menu to open Dispatch.")
            return
        }

        registeredHotKey = chosen
        if chosen != requested {
            var updated = settings
            updated.hotkeyKeyCode = chosen.keyCode
            updated.hotkeyModifiers = chosen.modifiers
            settingsModel.settings = updated
            if notifyOnFallback {
                let description = HotKeyManager.displayString(
                    keyCode: UInt32(chosen.keyCode),
                    modifiers: UInt32(chosen.modifiers)
                )
                showError("That shortcut is already in use. The global hotkey is now \(description).")
            }
        }
    }

    // MARK: - Status Menu

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = ResourceLoader.statusIcon
            button.imagePosition = .imageOnly
            button.toolTip = "Dispatch"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(
            title: "Open Dispatch",
            action: #selector(openLauncherFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let aiItem = NSMenuItem(
            title: "Ask AI & Coding Agents",
            action: #selector(openAIFromMenu),
            keyEquivalent: ""
        )
        aiItem.target = self
        menu.addItem(aiItem)

        let connectorsItem = NSMenuItem(
            title: "Composio App Connectors",
            action: #selector(openConnectorsFromMenu),
            keyEquivalent: ""
        )
        connectorsItem.target = self
        menu.addItem(connectorsItem)

        let notesItem = NSMenuItem(
            title: "Floating Notes",
            action: #selector(openFloatingNotesFromMenu),
            keyEquivalent: ""
        )
        notesItem.target = self
        menu.addItem(notesItem)

        menu.addItem(.separator())

        let clipboardItem = NSMenuItem(
            title: "Clipboard History",
            action: #selector(openClipboardFromMenu),
            keyEquivalent: ""
        )
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        let applicationsItem = NSMenuItem(
            title: "Search Applications",
            action: #selector(openApplicationsFromMenu),
            keyEquivalent: ""
        )
        applicationsItem.target = self
        menu.addItem(applicationsItem)

        let filesItem = NSMenuItem(
            title: "Search Files",
            action: #selector(openFilesFromMenu),
            keyEquivalent: ""
        )
        filesItem.target = self
        menu.addItem(filesItem)

        let extensionsItem = NSMenuItem(
            title: "Reload Extensions",
            action: #selector(reloadExtensionsFromMenu),
            keyEquivalent: ""
        )
        extensionsItem.target = self
        menu.addItem(extensionsItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        )
        updatesItem.target = self
        menu.addItem(updatesItem)

        let aboutItem = NSMenuItem(
            title: "About Dispatch",
            action: #selector(openAboutFromMenu),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Dispatch",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func openLauncherFromMenu() {
        showLauncher()
    }

    @objc private func openAIFromMenu() {
        showLauncher(mode: .ai)
    }

    @objc private func openConnectorsFromMenu() {
        showLauncher(mode: .connectors)
    }

    @objc private func openFloatingNotesFromMenu() {
        toggleFloatingNotes()
    }

    private func toggleFloatingNotes() {
        if floatingNotesController == nil {
            floatingNotesController = FloatingNotesWindowController(store: store)
        }
        floatingNotesController?.toggle()
    }

    @objc private func openClipboardFromMenu() {
        showLauncher(mode: .clipboard)
    }

    @objc private func openApplicationsFromMenu() {
        showLauncher(mode: .applications)
    }

    @objc private func openFilesFromMenu() {
        showLauncher(mode: .files)
    }

    @objc private func reloadExtensionsFromMenu() {
        extensions.reload()
        launcherModel.reloadExtensions()
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func openAboutFromMenu() {
        showAbout()
    }

    @objc private func checkForUpdatesFromMenu() {
        SparkleUpdaterService.shared.checkForUpdates(nil)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    // MARK: - Settings & Alerts

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(model: settingsModel)
        }
        settingsModel.refresh()
        settingsController?.show()
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Dispatch"
        alert.informativeText = """
        Version \(appVersion) (\(buildVersion))

        A native macOS command palette, coding agent hub, and app dispatcher built with SwiftUI, AppKit, Carbon hotkeys, and Spotlight.
        """
        alert.alertStyle = .informational
        alert.icon = ResourceLoader.appIcon
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func confirm(title: String, message: String, action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            action()
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Dispatch"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if message.localizedCaseInsensitiveContains("accessibility") {
            alert.addButton(withTitle: "Open Accessibility Settings")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            WindowManager.requestAccessibilityPermission()
        }
    }

    // MARK: - Snippet / Quicklink Editors

    private func presentSnippetEditor(_ existing: Snippet?) {
        let alert = NSAlert()
        alert.messageText = existing == nil ? "New Snippet" : "Edit Snippet"
        alert.informativeText = "Snippets are stored locally and can be pasted from search."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let width: CGFloat = 440
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 214))

        let titleLabel = editorLabel("Title")
        titleLabel.frame = NSRect(x: 0, y: 194, width: width, height: 16)
        let titleField = NSTextField(frame: NSRect(x: 0, y: 167, width: width, height: 24))
        titleField.placeholderString = "Email Signature"
        titleField.stringValue = existing?.title ?? ""

        let keywordLabel = editorLabel("Keyword")
        keywordLabel.frame = NSRect(x: 0, y: 145, width: width, height: 16)
        let keywordField = NSTextField(frame: NSRect(x: 0, y: 118, width: 190, height: 24))
        keywordField.placeholderString = "sig"
        keywordField.stringValue = existing?.keyword ?? ""

        let hint = editorLabel("Optional shorthand shown while searching.")
        hint.frame = NSRect(x: 202, y: 122, width: width - 202, height: 16)

        let textLabel = editorLabel("Text")
        textLabel.frame = NSRect(x: 0, y: 96, width: width, height: 16)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: 88))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 88))
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 5)
        textView.string = existing?.text ?? ""
        scroll.documentView = textView

        accessory.addSubview(titleLabel)
        accessory.addSubview(titleField)
        accessory.addSubview(keywordLabel)
        accessory.addSubview(keywordField)
        accessory.addSubview(hint)
        accessory.addSubview(textLabel)
        accessory.addSubview(scroll)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = titleField

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            launcher.show(mode: .snippets)
            return
        }

        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            showError("A snippet needs a title.")
            launcher.show(mode: .snippets)
            return
        }
        let keyword = keywordField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let snippet = Snippet(
            id: existing?.id ?? UUID().uuidString,
            title: title,
            text: textView.string,
            keyword: keyword,
            createdAt: existing?.createdAt ?? Date()
        )
        store.upsertSnippet(snippet)
        launcherModel.rebuild()
        launcher.show(mode: .snippets)
    }

    private func presentQuicklinkEditor(_ existing: Quicklink?) {
        let alert = NSAlert()
        alert.messageText = existing == nil ? "New Quicklink" : "Edit Quicklink"
        alert.informativeText = "Use {query} as the placeholder for a search term."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let width: CGFloat = 440
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 186))

        let titleLabel = editorLabel("Title")
        titleLabel.frame = NSRect(x: 0, y: 166, width: width, height: 16)
        let titleField = NSTextField(frame: NSRect(x: 0, y: 139, width: width, height: 24))
        titleField.placeholderString = "GitHub Search"
        titleField.stringValue = existing?.title ?? ""

        let keywordLabel = editorLabel("Keyword")
        keywordLabel.frame = NSRect(x: 0, y: 117, width: width, height: 16)
        let keywordField = NSTextField(frame: NSRect(x: 0, y: 90, width: 190, height: 24))
        keywordField.placeholderString = "gh"
        keywordField.stringValue = existing?.keyword ?? ""

        let hint = editorLabel("Type the keyword and a query from the root search.")
        hint.frame = NSRect(x: 202, y: 94, width: width - 202, height: 16)

        let urlLabel = editorLabel("URL Template")
        urlLabel.frame = NSRect(x: 0, y: 68, width: width, height: 16)
        let urlField = NSTextField(frame: NSRect(x: 0, y: 41, width: width, height: 24))
        urlField.placeholderString = "https://github.com/search?q={query}"
        urlField.stringValue = existing?.urlTemplate ?? ""

        let helper = editorLabel("Example: https://www.google.com/search?q={query}")
        helper.frame = NSRect(x: 0, y: 18, width: width, height: 16)

        accessory.addSubview(titleLabel)
        accessory.addSubview(titleField)
        accessory.addSubview(keywordLabel)
        accessory.addSubview(keywordField)
        accessory.addSubview(hint)
        accessory.addSubview(urlLabel)
        accessory.addSubview(urlField)
        accessory.addSubview(helper)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = titleField

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            launcher.show(mode: .quicklinks)
            return
        }

        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            showError("A quicklink needs a title.")
            launcher.show(mode: .quicklinks)
            return
        }
        var url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            showError("A quicklink needs a URL template.")
            launcher.show(mode: .quicklinks)
            return
        }
        if !url.contains("://") && !url.hasPrefix("mailto:") {
            url = "https://" + url
        }
        let probe = url.replacingOccurrences(of: "{query}", with: "test")
        guard URL(string: probe) != nil else {
            showError("That URL template is not valid.")
            launcher.show(mode: .quicklinks)
            return
        }
        let keyword = keywordField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let link = Quicklink(
            id: existing?.id ?? UUID().uuidString,
            title: title,
            urlTemplate: url,
            keyword: keyword,
            createdAt: existing?.createdAt ?? Date()
        )
        store.upsertQuicklink(link)
        launcherModel.rebuild()
        launcher.show(mode: .quicklinks)
    }

    private func presentCustomConnectorEditor() {
        let alert = NSAlert()
        alert.messageText = "Add Composio Connector"
        alert.informativeText = "Connect any of 250+ Composio apps by entering its name and Composio toolkit slug."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add & Connect")
        alert.addButton(withTitle: "Cancel")

        let width: CGFloat = 420
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 158))

        let nameLabel = editorLabel("App Name")
        nameLabel.frame = NSRect(x: 0, y: 138, width: width, height: 16)
        let nameField = NSTextField(frame: NSRect(x: 0, y: 111, width: width, height: 24))
        nameField.placeholderString = "Airtable"

        let slugLabel = editorLabel("Composio Toolkit Slug")
        slugLabel.frame = NSRect(x: 0, y: 89, width: width, height: 16)
        let slugField = NSTextField(frame: NSRect(x: 0, y: 62, width: 200, height: 24))
        slugField.placeholderString = "airtable"

        let categoryLabel = editorLabel("Category")
        categoryLabel.frame = NSRect(x: 212, y: 89, width: width - 212, height: 16)
        let categoryField = NSTextField(frame: NSRect(x: 212, y: 62, width: width - 212, height: 24))
        categoryField.placeholderString = "Productivity"

        let urlLabel = editorLabel("Dashboard / Web URL (optional)")
        urlLabel.frame = NSRect(x: 0, y: 40, width: width, height: 16)
        let urlField = NSTextField(frame: NSRect(x: 0, y: 13, width: width, height: 24))
        urlField.placeholderString = "https://airtable.com"

        accessory.addSubview(nameLabel)
        accessory.addSubview(nameField)
        accessory.addSubview(slugLabel)
        accessory.addSubview(slugField)
        accessory.addSubview(categoryLabel)
        accessory.addSubview(categoryField)
        accessory.addSubview(urlLabel)
        accessory.addSubview(urlField)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = nameField

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            launcher.show(mode: .connectors)
            return
        }

        let rawSlug = slugField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveSlug = rawSlug.isEmpty ? rawName.lowercased().replacingOccurrences(of: " ", with: "") : rawSlug
        guard !effectiveSlug.isEmpty else {
            showError("A connector needs a name or Composio slug.")
            launcher.show(mode: .connectors)
            return
        }

        composio.addCustomConnector(
            name: rawName.isEmpty ? effectiveSlug.capitalized : rawName,
            slug: effectiveSlug,
            category: categoryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            webURL: urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        settingsModel.refresh()
        launcherModel.rebuild()
        launcher.show(mode: .connectors)
    }

    private func editorLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func showOutput(title: String, output: String) {
        let alert = NSAlert()
        alert.messageText = title
        let trimmed = output.count > 4_000 ? String(output.prefix(4_000)) + "\n…" : output
        alert.informativeText = "Output copied to the clipboard.\n\n\(trimmed)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func applyDebugAppearance() {
        for argument in CommandLine.arguments where argument.hasPrefix("--appearance=") {
            switch argument.dropFirst("--appearance=".count) {
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            default: break
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }

    private var buildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }
}
