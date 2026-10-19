import AppKit
import ApplicationServices
import Foundation
import DispatchCore

/// Global keyboard monitor that auto-expands snippet keywords typed in other
/// applications (e.g. typing `;sig` or `!sig ` expands to the snippet body).
/// Requires Accessibility permission so global keyDown events are delivered and
/// synthetic backspaces + paste can be sent.
@MainActor
public final class SnippetExpansionService {
    private let store: AppStore
    private var globalMonitor: Any?
    private var typedBuffer = ""
    private var isExpanding = false

    public init(store: AppStore = .shared) {
        self.store = store
    }

    public func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event: event)
            }
        }
    }

    public func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        typedBuffer = ""
    }

    private func handle(event: NSEvent) {
        guard !isExpanding, store.settings.snippetExpansionEnabled else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            typedBuffer = ""
            return
        }

        // Backspace trims buffer
        if event.keyCode == 51 {
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
            return
        }

        // Escape, arrows, return reset buffer
        if [53, 36, 76, 123, 124, 125, 126].contains(event.keyCode) {
            typedBuffer = ""
            return
        }

        guard let chars = event.characters, !chars.isEmpty else { return }
        typedBuffer.append(chars)
        if typedBuffer.count > 48 {
            typedBuffer = String(typedBuffer.suffix(48))
        }

        checkExpansion()
    }

    private func checkExpansion() {
        let snippets = store.snippets().filter { !$0.keyword.isEmpty }
        guard !snippets.isEmpty else { return }

        for snippet in snippets {
            let keyword = snippet.keyword
            // Support direct `;keyword` / `!keyword` triggers or `keyword ` followed by space
            let triggers: [(suffix: String, deleteCount: Int)] = [
                (";\(keyword)", keyword.count + 1),
                ("!\(keyword)", keyword.count + 1),
                (":\(keyword):", keyword.count + 2),
            ]
            for trigger in triggers where typedBuffer.lowercased().hasSuffix(trigger.suffix.lowercased()) {
                typedBuffer = ""
                expand(snippet: snippet, backspaces: trigger.deleteCount)
                return
            }
        }
    }

    private func expand(snippet: Snippet, backspaces: Int) {
        guard WindowManager.isAccessibilityTrusted() else { return }
        isExpanding = true
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<backspaces {
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            PasteService.paste(snippet.text, autoPaste: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.isExpanding = false
            }
        }
    }
}
