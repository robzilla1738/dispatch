import AppKit
import Foundation

@MainActor
public enum PasteService {
    public static var canSimulatePaste: Bool {
        WindowManager.isAccessibilityTrusted()
    }

    public static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copy text, then (if enabled and permitted) synthesize ⌘V in the app that
    /// regains focus after the launcher closes.
    public static func paste(_ text: String, autoPaste: Bool) {
        copy(text)
        guard autoPaste, canSimulatePaste else { return }
        simulatePaste()
    }

    public static func simulatePaste() {
        guard canSimulatePaste else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                return
            }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
