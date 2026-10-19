import AppKit
import SwiftUI
import DispatchCore
import DispatchServices

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case codingTools
    case connectors
    case appearance
    case extensions
    case data
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .codingTools: return "Coding Tools"
        case .connectors: return "Connectors"
        case .appearance: return "Appearance"
        case .extensions: return "Extensions"
        case .data: return "Data"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .codingTools: return "sparkles"
        case .connectors: return "link.circle"
        case .appearance: return "paintpalette"
        case .extensions: return "puzzlepiece.extension"
        case .data: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = Theme(scheme: colorScheme)
        HStack(spacing: 0) {
            sidebar(theme: theme)
                .frame(width: 196)
            Rectangle()
                .fill(theme.separator)
                .frame(width: 0.5)
            content(theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 760, height: 540)
        .background(theme.background)
        .overlay(alignment: .bottomTrailing) {
            if let message = model.statusMessage {
                Text(message)
                    .font(AppFont.medium(10.5))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(theme.background)
                            .overlay(Capsule().strokeBorder(theme.border, lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    )
                    .padding(16)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.statusMessage)
        .onAppear {
            model.refresh()
        }
    }

    // MARK: - Sidebar

    private func sidebar(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let icon = ResourceLoader.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 42, height: 42)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Dispatch")
                        .font(AppFont.semibold(14))
                        .foregroundStyle(theme.textPrimary)
                    Text("Command palette")
                        .font(AppFont.regular(11))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 20)

            ForEach(SettingsSection.allCases) { item in
                Button {
                    model.section = item
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 17)
                        Text(item.title)
                            .font(AppFont.medium(12))
                        Spacer()
                    }
                    .foregroundStyle(model.section == item ? theme.textPrimary : theme.textSecondary)
                    .padding(.horizontal, 9)
                    .frame(height: 31)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(model.section == item ? theme.selection : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text("Version \(appVersion) (\(buildVersion))")
                    .font(AppFont.regular(9.5))
                    .foregroundStyle(theme.textTertiary)
                Text("Native macOS launcher")
                    .font(AppFont.regular(9.5))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(theme.chrome.opacity(0.5))
    }

    // MARK: - Content

    @ViewBuilder
    private func content(theme: Theme) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header(theme: theme)

                switch model.section {
                case .general:
                    generalSection(theme: theme)
                case .codingTools:
                    codingToolsSection(theme: theme)
                case .connectors:
                    connectorsSection(theme: theme)
                case .appearance:
                    appearanceSection(theme: theme)
                case .extensions:
                    extensionsSection(theme: theme)
                case .data:
                    dataSection(theme: theme)
                case .about:
                    aboutSection(theme: theme)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 36)
        }
    }

    private func header(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.section.title)
                .font(AppFont.semibold(23))
                .foregroundStyle(theme.textPrimary)
            Text(sectionSubtitle)
                .font(AppFont.regular(11.5))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var sectionSubtitle: String {
        switch model.section {
        case .general: return "Launcher behavior, hotkey, snippet expansion, and search preferences."
        case .codingTools: return "Auto-detected local CLI coding harnesses, skills, and MCP servers."
        case .connectors: return "Connect GitHub, Linear, Notion, Slack, Gmail, and more via Composio."
        case .appearance: return "Choose how the launcher looks."
        case .extensions: return "Script and URL commands loaded from your Extensions folder."
        case .data: return "Local storage used by clipboard history and search ranking."
        case .about: return "Version and build details."
        }
    }

    // MARK: - General

    @ViewBuilder
    private func generalSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Global Hotkey",
                subtitle: "Open the launcher from anywhere",
                theme: theme
            ) {
                HotkeyRecorder(
                    keyCode: model.settings.hotkeyKeyCode,
                    modifiers: model.settings.hotkeyModifiers,
                    onChange: { keyCode, modifiers in
                        model.settings.hotkeyKeyCode = keyCode
                        model.settings.hotkeyModifiers = modifiers
                        model.showStatus("Hotkey updated to \(HotKeyManager.displayString(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)))")
                    }
                )
                .frame(width: 156, height: 27)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Launch at Login",
                subtitle: model.launchAtLoginStatus,
                theme: theme
            ) {
                Toggle("", isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(theme.accent)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Paste Automatically",
                subtitle: "After choosing a clipboard item or snippet, paste with ⌘V",
                theme: theme
            ) {
                Toggle("", isOn: $model.settings.autoPaste)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(theme.accent)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Search Files with Spotlight",
                subtitle: "Include file results while searching from the root",
                theme: theme
            ) {
                Toggle("", isOn: $model.settings.fileSearchEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(theme.accent)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Clipboard History Limit",
                subtitle: "Pinned items are never removed automatically",
                theme: theme
            ) {
                HStack(spacing: 10) {
                    Text("\(model.settings.clipboardHistoryLimit)")
                        .font(AppFont.medium(11))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 34, alignment: .trailing)
                    Stepper(
                        "",
                        value: $model.settings.clipboardHistoryLimit,
                        in: 50...2000,
                        step: 50
                    )
                    .labelsHidden()
                }
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Show Recent Applications",
                subtitle: "Suggest frequently used applications in the root list",
                theme: theme
            ) {
                Toggle("", isOn: $model.settings.showRecentApplications)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(theme.accent)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Global Snippet Auto-Expansion",
                subtitle: "Expand snippets anywhere by typing ;keyword or !keyword",
                theme: theme
            ) {
                Toggle("", isOn: $model.settings.snippetExpansionEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(theme.accent)
            }
        }

        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Accessibility Permission",
                subtitle: model.accessibilityTrusted
                    ? "Granted — window management and automatic paste are available"
                    : "Required for window management and automatic paste",
                theme: theme
            ) {
                Button(model.accessibilityTrusted ? "Open Settings" : "Grant Access") {
                    model.requestAccessibility()
                }
                .buttonStyle(AccentButtonStyle(theme: theme, prominent: !model.accessibilityTrusted))
            }
        }
    }

    // MARK: - Coding Tools (T3 Code / Omni Bot Style)

    @ViewBuilder
    private func codingToolsSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Local CLI Harnesses",
                subtitle: "\(model.detectedTools.filter(\.installed).count) installed · \(model.detectedSkills.count) local skills · \(model.detectedMcpServers.count) MCP servers",
                theme: theme
            ) {
                Button(model.isScanningTools ? "Scanning…" : "Rescan CLIs") {
                    model.rescanCodingTools()
                }
                .buttonStyle(SecondaryButtonStyle(theme: theme))
                .disabled(model.isScanningTools)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Default Coding Agent",
                subtitle: "Primary CLI harness used for Quick AI & root search queries",
                theme: theme
            ) {
                Picker("", selection: $model.settings.activeCodingDriver) {
                    ForEach(CodingDriverKind.allCases, id: \.rawValue) { kind in
                        Text(kind.displayName).tag(kind.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Reasoning Effort",
                subtitle: "Passed to agents supporting effort control (Claude, Codex, Muse)",
                theme: theme
            ) {
                Picker("", selection: $model.settings.selectedReasoningEffort) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
        }

        SettingsCard(theme: theme) {
            ForEach(Array(model.detectedTools.enumerated()), id: \.element.id) { index, tool in
                let isEnabled = model.settings.enabledCodingDrivers.contains(tool.kind.rawValue)
                let isDefault = model.settings.activeCodingDriver == tool.kind.rawValue
                let selectedModel = model.settings.selectedCodingModels[tool.kind.rawValue] ?? "default"
                HStack(spacing: 12) {
                    IconView(spec: tool.kind.iconSpec, theme: theme, size: 26)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tool.kind.displayName)
                                .font(AppFont.medium(12))
                                .foregroundStyle(theme.textPrimary)
                            if isDefault {
                                Text("DEFAULT")
                                    .font(AppFont.semibold(8.5))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(theme.accent.opacity(0.16)))
                            }
                            if let ms = tool.latencyMs {
                                Text("\(ms)ms")
                                    .font(AppFont.regular(9))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        if tool.installed {
                            Text("\(tool.version ?? "Installed") · \(tool.binaryPath ?? "")")
                                .font(AppFont.regular(9.5))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Not found · \(tool.kind.installHint)")
                                .font(AppFont.regular(9.5))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if tool.installed {
                        Picker("", selection: Binding(
                            get: {
                                tool.models.contains(where: { $0.slug == selectedModel }) ? selectedModel : (tool.models.first?.slug ?? "default")
                            },
                            set: { newSlug in
                                model.settings.selectedCodingModels[tool.kind.rawValue] = newSlug
                            }
                        )) {
                            ForEach(tool.models) { opt in
                                Text(opt.label).tag(opt.slug)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 148)

                        Button("Verify") {
                            model.testCodingTool(tool.kind)
                        }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))

                        Toggle("", isOn: Binding(
                            get: { isEnabled },
                            set: { model.toggleCodingDriverEnabled(tool.kind.rawValue, enabled: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(theme.accent)
                    } else {
                        Button("Copy Install") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(tool.kind.installHint, forType: .string)
                            model.showStatus("Copied: \(tool.kind.installHint)")
                        }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                if index < model.detectedTools.count - 1 {
                    SettingsDivider(theme: theme)
                }
            }
        }

        if !model.detectedMcpServers.isEmpty {
            Text("Auto-Discovered MCP Servers")
                .font(AppFont.medium(11))
                .foregroundStyle(theme.textSecondary)
            SettingsCard(theme: theme) {
                ForEach(Array(model.detectedMcpServers.enumerated()), id: \.element.id) { idx, srv in
                    HStack {
                        Image(systemName: "server.rack")
                            .font(.system(size: 11.5))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(srv.name)
                                .font(AppFont.medium(11.5))
                                .foregroundStyle(theme.textPrimary)
                            Text(srv.commandOrUrl)
                                .font(AppFont.regular(9.5))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(srv.source)
                            .font(AppFont.regular(9))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    if idx < model.detectedMcpServers.count - 1 {
                        SettingsDivider(theme: theme)
                    }
                }
            }
        }
    }

    // MARK: - Composio Connectors

    @ViewBuilder
    private func connectorsSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Composio API Key",
                subtitle: "Optional key for live OAuth account sync (backend.composio.dev)",
                theme: theme
            ) {
                HStack(spacing: 8) {
                    SecureField("comp_...", text: $model.settings.composioApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button(model.isSyncingComposio ? "Syncing…" : "Sync") {
                        model.syncComposio()
                    }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
                    .fixedSize()
                    .disabled(model.isSyncingComposio)
                }
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Entity / User ID",
                subtitle: "Identifier passed when creating Composio connected accounts",
                theme: theme
            ) {
                TextField("dispatch-default-user", text: $model.settings.composioUserId)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Add Any Composio Connector",
                subtitle: "Connect any of 250+ Composio apps by slug (e.g. airtable, posthog, attio)",
                theme: theme
            ) {
                HStack(spacing: 6) {
                    TextField("Name (e.g. Airtable)", text: $model.newConnectorName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 118)
                    TextField("Slug (airtable)", text: $model.newConnectorSlug)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onSubmit {
                            model.addCustomComposioConnector()
                        }
                    Button("Add") {
                        model.addCustomComposioConnector()
                    }
                    .buttonStyle(AccentButtonStyle(theme: theme, prominent: true))
                    .fixedSize()
                }
            }
        }

        HStack {
            Text("\(model.filteredComposioCatalog.count) Connectors Available (\(model.composioCatalog.filter(\.isConnected).count) Connected)")
                .font(AppFont.medium(11))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            TextField("Filter connectors…", text: $model.connectorFilterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
        }

        SettingsCard(theme: theme) {
            ForEach(Array(model.filteredComposioCatalog.enumerated()), id: \.element.id) { index, toolkit in
                let isCustom = model.settings.customComposioConnectors.contains(where: { $0.slug == toolkit.slug })
                HStack(spacing: 12) {
                    IconView(spec: toolkit.iconSpec, theme: theme, size: 26)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(toolkit.name)
                                .font(AppFont.medium(12))
                                .foregroundStyle(theme.textPrimary)
                            Text(toolkit.category)
                                .font(AppFont.regular(9.5))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Text(toolkit.description)
                            .font(AppFont.regular(9.5))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isCustom {
                        Button("Remove") {
                            model.removeCustomComposioConnector(slug: toolkit.slug)
                        }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))
                        .fixedSize()
                    }

                    Button(toolkit.isConnected ? "Connected" : "Connect") {
                        model.toggleComposioToolkit(toolkit.slug)
                    }
                    .buttonStyle(AccentButtonStyle(theme: theme, prominent: !toolkit.isConnected))
                    .fixedSize()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                if index < model.filteredComposioCatalog.count - 1 {
                    SettingsDivider(theme: theme)
                }
            }
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private func appearanceSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Theme",
                subtitle: "The launcher follows macOS by default",
                theme: theme
            ) {
                Picker("", selection: $model.settings.theme) {
                    Text("System").tag("system")
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(AppFont.medium(11))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 12) {
                themePreview(title: "Dark", isDark: true, selected: model.settings.theme == "dark")
                themePreview(title: "Light", isDark: false, selected: model.settings.theme == "light")
            }
        }
    }

    private func themePreview(title: String, isDark: Bool, selected: Bool) -> some View {
        let previewTheme = Theme(scheme: isDark ? .dark : .light)
        return Button {
            model.settings.theme = isDark ? "dark" : "light"
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(previewTheme.textPrimary.opacity(0.85))
                        .frame(width: 5, height: 5)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(previewTheme.textPrimary.opacity(0.35))
                        .frame(width: 56, height: 4)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)

                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(previewTheme.selection)
                                .frame(width: 15, height: 15)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewTheme.textPrimary.opacity(index == 0 ? 0.6 : 0.3))
                                .frame(width: index == 0 ? 84 : 64, height: 4)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Spacer(minLength: 0)
            }
            .frame(width: 196, height: 116)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(previewTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Theme(scheme: .dark).accent : previewTheme.border, lineWidth: selected ? 2 : 0.75)
                    )
            )
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(AppFont.medium(10))
                    .foregroundStyle(previewTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 7)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Extensions

    @ViewBuilder
    private func extensionsSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Script Extensions",
                subtitle: "\(model.extensionCommands.count) commands loaded",
                theme: theme
            ) {
                HStack(spacing: 7) {
                    Button("Reveal Folder") { model.revealExtensions() }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))
                    Button("Reload") { model.reloadExtensions() }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))
                }
            }
            SettingsDivider(theme: theme)
            SettingsRow(
                title: "Extension Folder",
                subtitle: AppPaths.extensionsDirectory.path,
                theme: theme
            ) {
                Button("Open") { model.revealExtensions() }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
            }
        }

        if !model.extensionCommands.isEmpty {
            SettingsCard(theme: theme) {
                ForEach(Array(model.extensionCommands.enumerated()), id: \.element.id) { index, command in
                    HStack(spacing: 9) {
                        Image(systemName: command.icon ?? "puzzlepiece.extension")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(command.title)
                                .font(AppFont.medium(11.5))
                                .foregroundStyle(theme.textPrimary)
                            Text(command.extensionName)
                                .font(AppFont.regular(9.5))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Spacer()
                        Text(command.script != nil ? "SCRIPT" : "URL")
                            .font(AppFont.medium(8.5))
                            .tracking(0.5)
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    if index < model.extensionCommands.count - 1 {
                        SettingsDivider(theme: theme)
                    }
                }
            }
        }

        if !model.extensionErrors.isEmpty {
            SettingsCard(theme: theme) {
                ForEach(model.extensionErrors, id: \.self) { error in
                    Text(error)
                        .font(AppFont.regular(9.5))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        Text("Extensions are local folders with an extension.json manifest. Commands can run a shell script or open a URL locally on your Mac.")
            .font(AppFont.regular(10))
            .foregroundStyle(theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Data

    @ViewBuilder
    private func dataSection(theme: Theme) -> some View {
        SettingsCard(theme: theme) {
            SettingsRow(title: "Clipboard Items", subtitle: "\(model.clipboardCount) stored locally", theme: theme) {
                Button("Clear Unpinned") { model.clearClipboard() }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
            }
            SettingsDivider(theme: theme)
            SettingsRow(title: "Snippets", subtitle: "\(model.snippetCount) saved", theme: theme) {
                EmptyView()
            }
            SettingsDivider(theme: theme)
            SettingsRow(title: "Quicklinks", subtitle: "\(model.quicklinkCount) saved", theme: theme) {
                EmptyView()
            }
            SettingsDivider(theme: theme)
            SettingsRow(title: "Search Ranking", subtitle: "Usage history used to order results", theme: theme) {
                Button("Reset") { model.resetUsage() }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
            }
        }

        SettingsCard(theme: theme) {
            SettingsRow(
                title: "Local Data Folder",
                subtitle: AppPaths.supportDirectory.path,
                theme: theme
            ) {
                Button("Reveal") { model.revealDataFolder() }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
            }
        }

        Text("All data stays on this Mac. Clipboard history and usage are stored as JSON in Application Support.")
            .font(AppFont.regular(10))
            .foregroundStyle(theme.textTertiary)
    }

    // MARK: - About

    @ViewBuilder
    private func aboutSection(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let icon = ResourceLoader.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 64, height: 64)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dispatch")
                        .font(AppFont.semibold(20))
                        .foregroundStyle(theme.textPrimary)
                    Text("Version \(appVersion) · build \(buildVersion)")
                        .font(AppFont.regular(10.5))
                        .foregroundStyle(theme.textSecondary)
                    Text("Native macOS command palette & agent hub")
                        .font(AppFont.regular(10.5))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            SettingsCard(theme: theme) {
                SettingsRow(
                    title: "App Updates",
                    subtitle: "Signed automatic updates powered by Sparkle 2.10",
                    theme: theme
                ) {
                    Button("Check for Updates…") {
                        SparkleUpdaterService.shared.checkForUpdates(nil)
                    }
                    .buttonStyle(AccentButtonStyle(theme: theme, prominent: true))
                }
                SettingsDivider(theme: theme)
                SettingsRow(
                    title: "Local Data Folder",
                    subtitle: AppPaths.supportDirectory.path,
                    theme: theme
                ) {
                    Button("Reveal") { model.revealDataFolder() }
                        .buttonStyle(SecondaryButtonStyle(theme: theme))
                }
                SettingsDivider(theme: theme)
                SettingsRow(
                    title: "Built With",
                    subtitle: "Swift 6 · SwiftUI · AppKit · Carbon hotkeys · Spotlight",
                    theme: theme
                ) {
                    EmptyView()
                }
                SettingsDivider(theme: theme)
                SettingsRow(
                    title: "Bundle",
                    subtitle: "\(appVersion) (\(buildVersion)) · \(architecture)",
                    theme: theme
                ) {
                    EmptyView()
                }
            }

            Text("Dispatch is a fast, local-first macOS launcher, coding agent hub, and app connector released under the MIT License.")
                .font(AppFont.regular(9.5))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    // MARK: - Environment

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }

    private var buildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }

    private var architecture: String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }
}

// MARK: - Components

private struct SettingsCard<Content: View>: View {
    let theme: Theme
    let content: Content

    init(theme: Theme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.chrome)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.separator, lineWidth: 0.5)
                )
        )
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let theme: Theme
    let accessory: Accessory

    init(
        title: String,
        subtitle: String,
        theme: Theme,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(AppFont.medium(11.5))
                    .foregroundStyle(theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.regular(9.5))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 48)
    }
}

private struct SettingsDivider: View {
    let theme: Theme

    var body: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}

private struct AccentButtonStyle: ButtonStyle {
    let theme: Theme
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.medium(10.5))
            .foregroundStyle(prominent ? Color.white : theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(prominent ? theme.accent.opacity(configuration.isPressed ? 0.75 : 1) : theme.shortcutBackground)
            )
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.medium(10.5))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.shortcutBackground.opacity(configuration.isPressed ? 0.7 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.separator, lineWidth: 0.5)
                    )
            )
    }
}
