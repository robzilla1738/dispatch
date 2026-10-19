import AppKit
import Carbon.HIToolbox
import SwiftUI
import DispatchServices

/// A small AppKit control that records a global shortcut. Using an NSView
/// directly gives us reliable key handling inside a SwiftUI settings window.
struct HotkeyRecorder: NSViewRepresentable {
    let keyCode: Int
    let modifiers: Int
    let onChange: (Int, Int) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onChange = onChange
        view.update(keyCode: keyCode, modifiers: modifiers)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onChange = onChange
        if !nsView.isRecording {
            nsView.update(keyCode: keyCode, modifiers: modifiers)
        }
    }
}

final class HotkeyRecorderNSView: NSView {
    var onChange: ((Int, Int) -> Void)?
    private(set) var keyCode: Int = 49
    private(set) var modifiers: Int = 2048
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 156, height: 27) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityRole(.button)
        setAccessibilityLabel("Global hotkey")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        NSColor.labelColor.withAlphaComponent(0.075).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(0.12)).setStroke()
        path.lineWidth = isRecording ? 1.4 : 0.75
        path.stroke()

        let text: String
        if isRecording {
            text = "Press shortcut…"
        } else {
            text = HotKeyManager.displayString(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
        }
        let font = NSFont(name: "Inter-Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.9),
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let point = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2 + 0.5
        )
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            needsDisplay = true
            window?.makeFirstResponder(nil)
            return
        }

        let carbonModifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            NSSound.beep()
            return
        }

        keyCode = Int(event.keyCode)
        modifiers = Int(carbonModifiers)
        isRecording = false
        needsDisplay = true
        onChange?(keyCode, modifiers)
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            needsDisplay = true
        }
        return true
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }
}
