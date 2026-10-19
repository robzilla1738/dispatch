import AppKit
import SwiftUI
import DispatchCore
import DispatchServices

struct LauncherView: View {
    @ObservedObject var model: LauncherViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFocused: Bool

    private var hasSideDrawer: Bool {
        model.actionMode
            || model.activeAgentResponse != nil
            || (model.mode == .clipboard && model.selectedClipboardRecord != nil)
    }

    var body: some View {
        let theme = Theme(scheme: colorScheme)
        ZStack(alignment: .bottom) {
            VStack(spacing: 14) {
                searchCapsule(theme: theme)
                    .frame(width: hasSideDrawer ? 860 : 592)

                resultsCard(theme: theme)
                    .frame(width: hasSideDrawer ? 860 : 592)
            }
            .padding(.top, 28)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let status = model.statusMessage {
                statusToast(status, theme: theme)
                    .padding(.bottom, 58)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 920, height: 610, alignment: .top)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: model.focusRequest) { _ in
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: hasSideDrawer)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: model.actionMode)
        .animation(.easeInOut(duration: 0.16), value: model.statusMessage)
    }

    private var preferredScheme: ColorScheme? {
        switch model.store.settings.theme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    // MARK: - Top Search Capsule

    @ViewBuilder
    private func searchCapsule(theme: Theme) -> some View {
        ZStack {
            VisualEffectView(material: .hudWindow)
            LinearGradient(
                colors: theme.isDark
                    ? [
                        Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.92),
                        Color(red: 0.18, green: 0.18, blue: 0.20).opacity(0.76),
                    ]
                    : [
                        Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88),
                        Color(red: 0.28, green: 0.28, blue: 0.30).opacity(0.72),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if model.query.isEmpty {
                        Text(model.placeholder)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    } else if let completion = model.inlineCompletionRemainder {
                        HStack(spacing: 0) {
                            Text(model.query)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(Color.clear)
                            Text(completion)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.84))
                                .padding(.leading, 1)
                                .padding(.trailing, 7)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                        }
                        .lineLimit(1)
                        .allowsHitTesting(false)
                    }

                    TextField("", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .focused($searchFocused)
                        .tint(Color.white)
                        .onSubmit {
                            model.executeSelected()
                        }
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if model.mode == .ai {
                    aiModelSelectorPill()
                }

                if model.mode != .root {
                    modeBadge(theme: theme)
                }

                if let selected = model.selectedResult {
                    IconView(spec: selected.item.icon, theme: theme, size: 36, forceLightSymbol: true)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 38, height: 38)
                }
            }
            .padding(.leading, 26)
            .padding(.trailing, 20)
        }
        .frame(height: 68)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.18),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.85
                )
        )
        .shadow(color: Color.black.opacity(0.36), radius: 24, y: 12)
    }

    private func aiModelSelectorPill() -> some View {
        Menu {
            ForEach(model.codingTools.tools.filter(\.installed)) { tool in
                Menu(tool.kind.displayName) {
                    ForEach(tool.models) { opt in
                        Button {
                            model.setActiveDriverAndModel(driver: tool.kind, modelSlug: opt.slug)
                        } label: {
                            HStack {
                                Text(opt.label)
                                if model.activeCodingDriverKind == tool.kind && model.activeCodingModelSlug == opt.slug {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            Menu("Reasoning Effort") {
                ForEach(["low", "medium", "high"], id: \.self) { effort in
                    Button {
                        model.setReasoningEffort(effort)
                    } label: {
                        Text(effort.capitalized)
                    }
                }
            }
        } label: {
            Text(model.activeCodingModelLabel)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.90))
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        .fixedSize()
    }

    private func modeBadge(theme: Theme) -> some View {
        Button {
            model.resetToRoot()
        } label: {
            HStack(spacing: 5) {
                Text(model.mode.title)
                    .font(.system(size: 11.5, weight: .medium))
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
            }
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.16))
            )
        }
        .buttonStyle(.plain)
        .help("Return to root search")
    }

    // MARK: - Unified Results + Aside Card

    @ViewBuilder
    private func resultsCard(theme: Theme) -> some View {
        ZStack {
            VisualEffectView(material: .popover)
            LinearGradient(
                colors: theme.isDark
                    ? [
                        Color(red: 0.44, green: 0.44, blue: 0.45).opacity(0.76),
                        Color(red: 0.50, green: 0.50, blue: 0.51).opacity(0.72),
                    ]
                    : [
                        Color(red: 0.56, green: 0.56, blue: 0.57).opacity(0.78),
                        Color(red: 0.62, green: 0.62, blue: 0.63).opacity(0.74),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 4) {
                VStack(spacing: 0) {
                    scopeBar(theme: theme)
                    resultsList(theme: theme)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if hasSideDrawer {
                    asideDrawerCard(theme: theme)
                        .frame(width: 268)
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.36),
                            Color.white.opacity(0.18),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.85
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 28, y: 16)
    }

    // MARK: - Smooth Rounded Aside Drawer Inside Same Window

    @ViewBuilder
    private func asideDrawerCard(theme: Theme) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88),
                    Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if model.actionMode {
                asideActionsContent(theme: theme)
            } else if let answer = model.activeAgentResponse {
                asideAgentChatContent(answer: answer, theme: theme)
            } else if let record = model.selectedClipboardRecord {
                asideClipboardContent(record: record, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.65)
        )
    }

    private func asideActionsContent(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top header bar (Aside style)
            HStack(spacing: 6) {
                Text("Actions")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                Button {
                    model.exitActionMode()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Context pill card for the selected item (Aside bottom/top card style)
            if let selected = model.selectedResult {
                HStack(spacing: 10) {
                    IconView(spec: selected.item.icon, theme: theme, size: 28, forceLightSymbol: true)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(selected.item.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)
                        Text(selected.item.subtitle.isEmpty ? selected.item.kind.displayName : selected.item.subtitle)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.52))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 3) {
                    ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                        ActionRow(
                            action: action,
                            isSelected: model.selectedActionIndex == index,
                            theme: theme
                        )
                        .onTapGesture {
                            model.selectedActionIndex = index
                        }
                        .onTapGesture(count: 2) {
                            model.executeAction(action)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }

            Spacer(minLength: 0)

            asideBottomBar(theme: theme)
        }
    }

    private func asideAgentChatContent(answer: String, theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: "New chat v" ... copy + close (matches Aside screenshot)
            HStack(spacing: 6) {
                Menu {
                    ForEach(model.codingTools.tools.filter(\.installed)) { tool in
                        Button {
                            model.setActiveDriverAndModel(driver: tool.kind)
                        } label: {
                            Text(tool.kind.displayName)
                        }
                    }
                } label: {
                    Text(model.activeCodingDriverKind.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(answer, forType: .string)
                    model.showStatus("Copied response")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Copy response")

                Button {
                    model.clearAgentResponse()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Close chat")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.activeAgentPrompt.isEmpty {
                        Text(model.activeAgentPrompt)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.11))
                            )
                    }

                    HStack(spacing: 6) {
                        if model.isRunningAgent {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.68)
                        }
                        Text(model.activeAgentTitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }

                    Text(answer)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            Spacer(minLength: 6)

            // Bottom composer card (Aside style)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    IconView(spec: model.activeCodingDriverKind.iconSpec, theme: theme, size: 20, forceLightSymbol: true)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.activeCodingDriverKind.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(1)
                        Text(model.activeCodingModelLabel)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )

                HStack(spacing: 6) {
                    TextField("Reply, @ for context", text: $model.agentFollowUpInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .onSubmit {
                            model.submitFollowUpAgentPrompt()
                        }

                    Button {
                        model.submitFollowUpAgentPrompt()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            asideBottomBar(theme: theme)
        }
    }

    private func asideClipboardContent(record: ClipboardRecord, theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Clipboard Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text(record.kind.rawValue.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if record.kind == .image,
               let path = record.imagePath,
               let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(record.text)
                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 6) {
                clipboardMetaRow(label: "Source", value: record.sourceApp.isEmpty ? "System" : record.sourceApp)
                clipboardMetaRow(label: "Copied", value: RelativeTime.string(from: record.date))
                if record.kind == .text {
                    let words = record.text.split(whereSeparator: \.isWhitespace).count
                    clipboardMetaRow(label: "Size", value: "\(words) words · \(record.text.count) chars")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }

    private func asideBottomBar(theme: Theme) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(model.codingTools.tools.filter(\.installed)) { tool in
                    Button {
                        model.setActiveDriverAndModel(driver: tool.kind)
                    } label: {
                        Text(tool.kind.displayName)
                    }
                }
            } label: {
                IconView(spec: model.activeCodingDriverKind.iconSpec, theme: theme, size: 15, forceLightSymbol: true)
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Menu {
                ForEach(model.activeCodingDriverModels) { opt in
                    Button {
                        model.setActiveDriverAndModel(driver: model.activeCodingDriverKind, modelSlug: opt.slug)
                    } label: {
                        Text(opt.label)
                    }
                }
                Divider()
                ForEach(["low", "medium", "high"], id: \.self) { effort in
                    Button("Effort: \(effort.capitalized)") {
                        model.setReasoningEffort(effort)
                    }
                }
            } label: {
                Text("\(model.activeCodingModelLabel) \(model.store.settings.selectedReasoningEffort.capitalized)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }

    private func clipboardMetaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.52))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
        }
    }

    private func scopeBar(theme: Theme) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.scopeChips, id: \.self) { chip in
                    let isSelected = model.selectedScopeChip == chip
                    Button {
                        model.selectScopeChip(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(isSelected ? 0.34 : 0.16))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                Color.white.opacity(isSelected ? 0.28 : 0.08),
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    @ViewBuilder
    private func resultsList(theme: Theme) -> some View {
        if model.flatResults.isEmpty {
            emptyState(theme: theme)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.flatResults.enumerated()), id: \.element.id) { index, result in
                            ResultRow(
                                result: result,
                                isSelected: model.selectedIndex == index,
                                theme: theme
                            )
                            .id(result.id)
                            .onTapGesture(count: 2) {
                                model.execute(result: result)
                            }
                            .onTapGesture {
                                model.select(index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 14)
                }
                .onChange(of: model.selectedIndex) { newIndex in
                    guard model.flatResults.indices.contains(newIndex) else { return }
                    let id = model.flatResults[newIndex].id
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func emptyState(theme: Theme) -> some View {
        VStack(spacing: 12) {
            if let mark = ResourceLoader.image(named: "dispatch-mark-128") {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.white.opacity(0.65))
            } else {
                Image(nsImage: ResourceLoader.appIcon ?? NSImage())
                    .resizable()
                    .frame(width: 46, height: 46)
            }

            Text(model.emptyTitle)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.94))
                .multilineTextAlignment(.center)

            Text(model.emptySubtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if model.mode == .calculator && model.query.isEmpty {
                HStack(spacing: 6) {
                    ForEach(["2 + 2", "sqrt(81)", "10 km in mi", "15% of 80"], id: \.self) { example in
                        Button(example) {
                            model.query = example
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.black.opacity(0.18))
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 20)
    }

    private func statusToast(_ text: String, theme: Theme) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.72))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
            )
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let theme: Theme

    var body: some View {
        HStack(spacing: 12) {
            IconView(spec: result.item.icon, theme: theme, size: 32, forceLightSymbol: true)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !result.item.subtitle.isEmpty {
                    subtitleView
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                HStack(spacing: 6) {
                    Text(trailingActionPrompt)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text("tab")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .fill(Color.white.opacity(0.22))
                        )
                }
            } else if let accessory = result.item.accessory {
                Text(accessory)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.6)
                )
        )
        .contentShape(Rectangle())
    }

    private var trailingActionPrompt: String {
        switch result.item.kind {
        case .application:
            return "Search \(result.item.title)"
        case .aiAgent:
            return "Models & Actions"
        default:
            return "Actions"
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        if result.item.kind == .file, result.item.subtitle.contains(" · ") {
            let parts = result.item.subtitle.components(separatedBy: " · ")
            if parts.count == 2 {
                HStack(spacing: 4) {
                    Text("\(parts[0]) ·")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.62))
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.62))
                    Text(parts[1])
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            } else {
                Text(result.item.subtitle)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        } else {
            Text(result.item.subtitle)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }
}

private struct ActionRow: View {
    let action: ActionDescriptor
    let isSelected: Bool
    let theme: Theme

    var body: some View {
        HStack(spacing: 9) {
            IconView(spec: action.icon, theme: theme, size: 20, forceLightSymbol: true)
                .frame(width: 22, height: 22)

            Text(action.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)

            Spacer(minLength: 4)

            if let shortcut = action.shortcut {
                Text(shortcut)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                    )
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.16) : Color.clear, lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
    }
}

struct IconView: View {
    let spec: IconSpec
    let theme: Theme
    var size: CGFloat = 20
    var forceLightSymbol: Bool = false

    var body: some View {
        Group {
            switch spec {
            case .asset(let name):
                if let image = ResourceLoader.image(named: name) {
                    let isBrand = name.hasPrefix("brand-")
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: isBrand ? size : size * 0.78, height: isBrand ? size : size * 0.78)
                        .clipShape(RoundedRectangle(cornerRadius: isBrand ? size * 0.22 : 0, style: .continuous))
                } else if name.hasPrefix("brand-") {
                    let slug = String(name.dropFirst("brand-".count))
                    let letter = String((slug.first ?? "?")).uppercased()
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.38, blue: 0.62),
                                    Color(red: 0.20, green: 0.26, blue: 0.46),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: size)
                        .overlay(
                            Text(letter)
                                .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        )
                } else {
                    fallback
                }
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.65, weight: .medium))
                    .foregroundStyle(forceLightSymbol ? Color.white.opacity(0.92) : theme.textPrimary)
                    .frame(width: size, height: size)
            case .application(let path), .file(let path):
                Image(nsImage: ResourceLoader.systemIcon(for: path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            case .emoji(let character):
                Text(character)
                    .font(.system(size: size * 0.85))
                    .frame(width: size, height: size)
            case .quicklink:
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.32, blue: 0.34))
                    .frame(width: size * 0.82, height: size * 0.82)
                    .overlay(
                        Image(systemName: "link")
                            .font(.system(size: size * 0.44, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    private var fallback: some View {
        Image(systemName: "square.fill")
            .font(.system(size: size * 0.7))
            .foregroundStyle(forceLightSymbol ? Color.white.opacity(0.75) : theme.textSecondary)
    }
}
