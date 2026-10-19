import AppKit
import CoreText
import SwiftUI

enum ResourceLoader {
    private static var imageCache: [String: NSImage] = [:]
    private static var systemIconCache: [String: NSImage] = [:]
    private static let lock = NSLock()

    static func image(named name: String) -> NSImage? {
        lock.lock()
        if let cached = imageCache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let candidates: [String]
        if name.hasSuffix("@2x") {
            candidates = [name]
        } else {
            candidates = [name + "@2x", name]
        }

        for candidate in candidates {
            let url = Bundle.module.url(forResource: candidate, withExtension: "png", subdirectory: "Icons")
                ?? Bundle.module.url(forResource: candidate, withExtension: "png")
            if let url,
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                lock.lock()
                imageCache[name] = image
                lock.unlock()
                return image
            }
            if let url = Bundle.main.url(forResource: candidate, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                lock.lock()
                imageCache[name] = image
                lock.unlock()
                return image
            }
        }
        return nil
    }

    static func systemIcon(for path: String) -> NSImage {
        lock.lock()
        if let cached = systemIconCache[path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 32, height: 32)
        lock.lock()
        systemIconCache[path] = image
        lock.unlock()
        return image
    }

    static func fileURL(_ name: String, extension ext: String, subdirectory: String? = nil) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    static var appIcon: NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.module.url(forResource: "AppIcon-Release", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: NSImage.applicationIconName)
    }

    static var statusIcon: NSImage? {
        if let symbol = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "Dispatch") {
            let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            let configured = symbol.withSymbolConfiguration(config) ?? symbol
            configured.isTemplate = true
            return configured
        }
        if let image = image(named: "dispatch-status-16") {
            image.isTemplate = true
            return image
        }
        return nil
    }

    static func registerFonts() {
        // Uses native macOS SF Pro system fonts via AppFont.
    }
}

enum AppFont {
    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func bold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}

struct Theme {
    let scheme: ColorScheme

    var isDark: Bool { scheme == .dark }

    var background: Color {
        isDark
            ? Color(red: 0.105, green: 0.105, blue: 0.115).opacity(0.94)
            : Color(red: 0.965, green: 0.965, blue: 0.975).opacity(0.96)
    }

    var chrome: Color {
        isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.035)
    }

    var searchBackground: Color {
        isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.045)
    }

    var selection: Color {
        isDark ? Color.white.opacity(0.105) : Color.black.opacity(0.075)
    }

    var selectionBorder: Color {
        isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }

    var separator: Color {
        isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.08)
    }

    var border: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.12)
    }

    var textPrimary: Color {
        isDark ? Color.white.opacity(0.94) : Color.black.opacity(0.87)
    }

    var textSecondary: Color {
        isDark ? Color.white.opacity(0.52) : Color.black.opacity(0.48)
    }

    var textTertiary: Color {
        isDark ? Color.white.opacity(0.32) : Color.black.opacity(0.30)
    }

    var accent: Color {
        Color(red: 0.36, green: 0.62, blue: 1.0)
    }

    var shortcutBackground: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
    }

    var iconBackground: Color {
        isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.055)
    }

    var searchPlaceholder: String {
        "Search for apps, commands, and files…"
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct ShortcutBadge: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = Theme(scheme: colorScheme)
        Text(text)
            .font(AppFont.medium(10.5))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.shortcutBackground)
            )
    }
}
