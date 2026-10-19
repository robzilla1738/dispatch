import Foundation
import DispatchCore

enum DemoSeeder {
    static func seed() {
        let store = AppStore.shared
        let items: [(String, String)] = [
            ("Welcome to Dispatch — a native macOS command palette, coding agent hub, and app dispatcher.", "Dispatch"),
            ("https://github.com/trending", "Safari"),
            ("func greet(name: String) -> String { \"Hello, \\(name)!\" }", "Xcode"),
            ("git status --short && git log --oneline -5", "Terminal"),
            ("The quick brown fox jumps over the lazy dog.", "Notes"),
        ]
        for (text, source) in items {
            store.addClipboard(text: text, sourceApp: source)
        }
        store.recordUsage(id: "builtin.clipboard")
        store.recordUsage(id: "builtin.clipboard")
        store.recordUsage(id: "builtin.calculator")
        store.recordUsage(id: "builtin.applications")
    }
}
