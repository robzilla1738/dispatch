import Foundation
import Darwin
import DispatchCore
import DispatchServices

enum SelfTest {
    private static var passed = 0
    private static var failed = 0

    static func run() -> Bool {
        testFuzzyMatching()
        testCalculator()
        testStorage()
        testRanking()
        testExtensions()
        testCodingAgentsAndComposio()

        let payload: [String: Any] = [
            "ok": failed == 0,
            "passed": passed,
            "failed": failed,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
        return failed == 0
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        if condition() {
            passed += 1
            print("PASS  \(name)")
        } else {
            failed += 1
            print("FAIL  \(name)")
        }
    }

    private static func testFuzzyMatching() {
        check(FuzzyMatcher.match(query: "safari", candidate: "Safari")?.score == 10_000, "fuzzy exact match")
        check(FuzzyMatcher.match(query: "goo", candidate: "Google Chrome") != nil, "fuzzy prefix")
        check(FuzzyMatcher.match(query: "gc", candidate: "Google Chrome") != nil, "fuzzy acronym")
        check(FuzzyMatcher.match(query: "xyz", candidate: "Safari") == nil, "fuzzy rejects non-match")
    }

    private static func testCalculator() {
        check(Calculator.evaluate("2 + 2")?.value == 4, "calculator addition")
        check(Calculator.evaluate("2 + 2 * 3")?.value == 8, "calculator precedence")
        check(Calculator.evaluate("sqrt(81)")?.value == 9, "calculator sqrt")
        check(Calculator.evaluate("5!")?.value == 120, "calculator factorial")
        check(Calculator.evaluate("15% of 80")?.value == 12, "calculator percent-of")
        check(Calculator.evaluate("(2+3)^2")?.value == 25, "calculator power")
        check(Calculator.evaluate("10 / 0") == nil, "calculator division by zero")
        if let conversion = Calculator.evaluate("10 km in mi") {
            check(abs(conversion.value - 6.2137) < 0.001, "calculator unit conversion")
        } else {
            check(false, "calculator unit conversion")
        }
        if let temperature = Calculator.evaluate("100 c to f") {
            check(abs(temperature.value - 212) < 0.01, "calculator temperature conversion")
        } else {
            check(false, "calculator temperature conversion")
        }
    }

    private static func testStorage() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dispatch-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(directory: directory)
        check(store.quicklinks().count >= 3, "storage seed quicklinks")
        check(store.snippets().count >= 1, "storage seed snippets")

        check(store.addClipboard(text: "hello world", sourceApp: "Self Test"), "storage clipboard insert")
        check(!store.addClipboard(text: "hello world", sourceApp: "Self Test"), "storage clipboard dedupe")
        check(store.clipboardItems().count == 1, "storage clipboard count")

        let record = store.clipboardItems()[0]
        store.toggleClipboardPin(id: record.id)
        check(store.clipboardItems().first?.pinned == true, "storage clipboard pin")

        let snippet = Snippet(title: "Test", text: "Test body", keyword: "t")
        store.upsertSnippet(snippet)
        check(store.snippets().contains(where: { $0.id == snippet.id }), "storage snippet insert")

        store.recordUsage(id: "test.item")
        store.recordUsage(id: "test.item")
        check((store.usageScores()["test.item"] ?? 0) > 0, "storage usage scoring")
    }

    private static func testExtensions() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dispatch-extension-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = """
        {
          "name": "Test Extension",
          "commands": [
            { "id": "echo", "title": "Echo", "script": "echo hello" }
          ]
        }
        """
        try? manifest.write(
            to: directory.appendingPathComponent("extension.json"),
            atomically: true,
            encoding: .utf8
        )
        let store = ExtensionStore(directory: directory)
        check(store.commands.count == 1, "extension manifest loads")
        if let command = store.commands.first {
            switch store.run(command) {
            case .success(let output):
                check(output == "hello", "extension script executes")
            case .failure:
                check(false, "extension script executes")
            }
        } else {
            check(false, "extension script executes")
        }
    }

    private static func testRanking() {
        let items = [
            CommandItem(
                id: "chrome",
                title: "Google Chrome",
                subtitle: "Application",
                kind: .application,
                icon: .symbol("globe"),
                action: .openApplication(path: "/Applications/Google Chrome.app")
            ),
            CommandItem(
                id: "calendar",
                title: "Calendar",
                subtitle: "Application",
                kind: .application,
                icon: .symbol("calendar"),
                action: .openApplication(path: "/System/Applications/Calendar.app")
            ),
        ]
        let ranked = SearchRanking.rank(items: items, query: "chr")
        check(ranked.first?.item.id == "chrome", "ranking selects Chrome")
    }

    private static func testCodingAgentsAndComposio() {
        check(CodingDriverKind.allCases.count == 11, "coding tool drivers registered")
        check(!CodingDriverKind.claude.defaultModels.isEmpty, "claude default models available")
        check(WindowCommand.allCases.count == 27, "27 window management commands registered")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dispatch-composio-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let composio = ComposioService(store: store)
        composio.addCustomConnector(name: "PostHog", slug: "posthog")
        check(composio.catalog.contains(where: { $0.slug == "posthog" }), "custom composio connector persisted")
    }
}
