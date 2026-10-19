import AppKit
import SwiftUI
import DispatchCore

@MainActor
final class FloatingNotesWindowController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let store: AppStore

    init(store: AppStore = .shared) {
        self.store = store
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.title = "Floating Notes"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear

        let host = NSHostingView(rootView: FloatingNoteView(store: store))
        panel.contentView = host
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - 420, y: screen.maxY - 380))
        } else {
            panel.center()
        }
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct FloatingNoteView: View {
    let store: AppStore
    @State private var text: String
    @State private var wordCount: Int = 0

    init(store: AppStore) {
        self.store = store
        let initial = store.settings.floatingNoteText
        _text = State(initialValue: initial)
        _wordCount = State(initialValue: initial.split(whereSeparator: \.isWhitespace).count)
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow)
            Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.84)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text("Floating Notes")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Text("Copy")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 72)
                .padding(.trailing, 14)
                .frame(height: 36)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)

                TextEditor(text: $text)
                    .font(.system(size: 13.5, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .onChange(of: text) { newValue in
                        var s = store.settings
                        s.floatingNoteText = newValue
                        store.settings = s
                        wordCount = newValue.split(whereSeparator: \.isWhitespace).count
                    }

                HStack {
                    Text("\(wordCount) words · \(text.count) chars")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.48))
                    Spacer()
                    Button("Clear") {
                        text = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .frame(height: 26)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
        )
    }
}

@MainActor
enum ConfettiOverlay {
    private static var overlayWindow: NSWindow?

    static func celebrate() {
        guard let screen = NSScreen.main else { return }
        overlayWindow?.orderOut(nil)

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = NSHostingView(rootView: ConfettiParticleView(size: screen.frame.size))
        window.contentView = view
        window.orderFrontRegardless()
        overlayWindow = window

        NSSound(named: "Glass")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            window.orderOut(nil)
            if overlayWindow === window {
                overlayWindow = nil
            }
        }
    }
}

private struct ConfettiParticleView: View {
    let size: CGSize
    @State private var fall = false

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink,
    ]

    var body: some View {
        ZStack {
            ForEach(0..<90, id: \.self) { index in
                let startX = CGFloat((index * 73) % Int(max(size.width, 400)))
                let driftX = CGFloat(((index * 29) % 180) - 90)
                let delay = Double(index % 15) * 0.04
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: 9, height: 14)
                    .rotationEffect(.degrees(fall ? Double(index * 55 + 360) : Double(index * 20)))
                    .position(
                        x: fall ? startX + driftX : startX,
                        y: fall ? size.height + 60 : -30
                    )
                    .animation(
                        .easeIn(duration: 1.8 + Double(index % 7) * 0.12).delay(delay),
                        value: fall
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            fall = true
        }
    }
}
