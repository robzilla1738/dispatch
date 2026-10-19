import AppKit
import SwiftUI
import DispatchCore

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    private let panel: LauncherPanel
    private let model: LauncherViewModel
    private var keyMonitor: Any?
    private var previousApplication: NSRunningApplication?
    private var isHiding = false

    var onSettings: (() -> Void)?

    init(model: LauncherViewModel) {
        self.model = model
        self.panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 610),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let host = NSHostingView(rootView: LauncherView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host

        model.onDismiss = { [weak self] in
            self?.hide()
        }
        model.onSettings = { [weak self] in
            self?.hide(restoreFocus: false)
            self?.onSettings?()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    @discardableResult
    func captureWindow(to path: String) -> Bool {
        guard let view = panel.contentView else { return false }
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

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show(mode: SearchMode? = nil) {
        guard !panel.isVisible else { return }
        previousApplication = NSWorkspace.shared.frontmostApplication

        model.refreshBeforeShow()
        if let mode {
            model.setMode(mode)
        }

        positionPanel()
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(restoreFocus: Bool = true) {
        guard panel.isVisible, !isHiding else { return }
        isHiding = true
        removeKeyMonitor()
        panel.orderOut(nil)
        isHiding = false

        if restoreFocus,
           let previousApplication,
           previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication.activate(options: [])
        }
        previousApplication = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // Opening a menu or another window intentionally resigns key. Hide so
        // the launcher behaves like a transient command palette.
        guard panel.isVisible, !isHiding else { return }
        hide()
    }

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        let width = panel.frame.width
        let height = panel.frame.height
        let x = visible.midX - width / 2
        let margin = max(78, min(160, visible.height * 0.17))
        let y = visible.maxY - height - margin
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            return self.handle(event: event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handle(event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "k":
                if flags.contains(.shift) { return event }
                model.handleTab()
                return nil
            case ",":
                hide(restoreFocus: false)
                onSettings?()
                return nil
            case "w":
                hide()
                return nil
            case "q":
                NSApp.terminate(nil)
                return nil
            default:
                return event
            }
        }

        switch event.keyCode {
        case 53: // Escape
            if model.activeAgentResponse != nil {
                model.clearAgentResponse()
            } else if model.actionMode {
                model.exitActionMode()
            } else if model.mode != .root {
                model.resetToRoot()
            } else {
                hide()
            }
            return nil
        case 125: // Down
            model.moveSelection(by: 1)
            return nil
        case 126: // Up
            model.moveSelection(by: -1)
            return nil
        case 36, 76: // Return, keypad enter
            model.executeSelected()
            return nil
        case 48: // Tab
            model.handleTab()
            return nil
        default:
            return event
        }
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }
}
