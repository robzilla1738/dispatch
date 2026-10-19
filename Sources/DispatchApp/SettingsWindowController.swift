import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let model: SettingsViewModel

    init(model: SettingsViewModel) {
        self.model = model
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "Dispatch Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.delegate = self

        let hosting = NSHostingView(rootView: SettingsView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hosting
        window.center()
    }

    func show() {
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    var isVisible: Bool {
        window.isVisible
    }

    @discardableResult
    func captureWindow(to path: String) -> Bool {
        guard let view = window.contentView else { return false }
        view.layoutSubtreeIfNeeded()
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return false
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
