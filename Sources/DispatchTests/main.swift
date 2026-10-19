import Foundation
import DispatchCore
import DispatchServices

/// Dependency-free unit test runner. The local Command Line Tools SDK does not
/// ship XCTest, so the project uses this small harness instead of `swift test`.
/// Run with: swift run DispatchTests

private var passed = 0
private var failed = 0

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passed += 1
        print("PASS  \(name)")
    } else {
        failed += 1
        print("FAIL  \(name)")
    }
}

private func checkEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ name: String) {
    check(lhs == rhs, "\(name) (expected \(rhs), got \(lhs))")
}

private func checkClose(
    _ lhs: Double,
    _ rhs: Double,
    accuracy: Double,
    _ name: String
) {
    check(abs(lhs - rhs) <= accuracy, "\(name) (expected \(rhs), got \(lhs))")
}

private func temporaryDirectory(_ label: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("dispatch-unit-\(label)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func commandItem(id: String, title: String) -> CommandItem {
    CommandItem(
        id: id,
        title: title,
        kind: .command,
        icon: .symbol("gear"),
        action: .showSettings
    )
}

// MARK: - Fuzzy matching and ranking

checkEqual(
    FuzzyMatcher.match(query: "Safari", candidate: "Safari")?.score,
    10_000,
    "fuzzy exact match"
)
check(
    (FuzzyMatcher.match(query: "Saf", candidate: "Safari")?.score ?? 0) < 10_000,
    "fuzzy prefix scores below exact"
)
checkEqual(
    FuzzyMatcher.match(query: "chrome", candidate: "Google Chrome")?.ranges,
    [7..<13],
    "fuzzy substring ranges"
)
checkEqual(
    FuzzyMatcher.match(query: "gc", candidate: "Google Chrome")?.ranges,
    [0..<1, 7..<8],
    "fuzzy subsequence ranges"
)
check(FuzzyMatcher.match(query: "xyz", candidate: "Safari") == nil, "fuzzy rejects non-match")
checkEqual(
    FuzzyMatcher.match(query: "cafe", candidate: "Café")?.score,
    10_000,
    "fuzzy diacritic folding"
)

let exactChrome = commandItem(id: "app.chrome", title: "Chrome")
let longChrome = commandItem(id: "app.google-chrome", title: "Google Chrome")
checkEqual(
    SearchRanking.rank(items: [longChrome, exactChrome], query: "chrome").first?.item.id,
    "app.chrome",
    "ranking prefers exact title"
)
let tieA = commandItem(id: "tie.a", title: "Same")
let tieB = commandItem(id: "tie.b", title: "Same")
checkEqual(
    SearchRanking.rank(items: [tieA, tieB], query: "same", usage: ["tie.b": 40]).first?.item.id,
    "tie.b",
    "ranking applies usage boost"
)

// MARK: - Calculator

func calculatorValue(_ expression: String) -> Double? {
    Calculator.evaluate(expression)?.value
}

checkClose(calculatorValue("2 + 3 * 4") ?? .nan, 14, accuracy: 0.000_001, "calculator precedence")
checkClose(calculatorValue("(2 + 3) * 4") ?? .nan, 20, accuracy: 0.000_001, "calculator parentheses")
checkClose(calculatorValue("2^10") ?? .nan, 1024, accuracy: 0.000_001, "calculator power")
checkClose(calculatorValue("5!") ?? .nan, 120, accuracy: 0.000_001, "calculator factorial")
checkClose(
    calculatorValue("sqrt(81) + abs(-4)") ?? .nan,
    13,
    accuracy: 0.000_001,
    "calculator functions"
)
checkClose(calculatorValue("15% of 80") ?? .nan, 12, accuracy: 0.000_001, "calculator percentage")
checkClose(
    calculatorValue("8 × 7 − 6 ÷ 3") ?? .nan,
    54,
    accuracy: 0.000_001,
    "calculator unicode operators"
)
checkClose(calculatorValue("10 km in mi") ?? .nan, 6.2137, accuracy: 0.001, "unit km to mi")
checkClose(calculatorValue("100 f to c") ?? .nan, 37.7778, accuracy: 0.001, "unit fahrenheit to celsius")
checkClose(calculatorValue("1 gb in mb") ?? .nan, 1024, accuracy: 0.01, "unit data conversion")
checkEqual(Calculator.evaluate("1 / 3")?.formatted, "0.3333333333", "calculator formatting")
check(Calculator.evaluate("2 +") == nil, "calculator rejects trailing operator")
check(Calculator.evaluate("1 / 0") == nil, "calculator rejects divide by zero")
check(Calculator.looksLikeExpression("10 km in mi"), "calculator recognizes unit input")
check(!Calculator.looksLikeExpression("safari"), "calculator ignores ordinary words")

// MARK: - Persistence

let storeDirectory = temporaryDirectory("store")
let store = AppStore(directory: storeDirectory)
checkEqual(store.snippets().count, 1, "store seeds starter snippet")
checkEqual(store.quicklinks().count, 3, "store seeds starter quicklinks")

for item in store.snippets() {
    store.removeSnippet(id: item.id)
}
for item in store.quicklinks() {
    store.removeQuicklink(id: item.id)
}
let emptiedStore = AppStore(directory: storeDirectory)
check(emptiedStore.snippets().isEmpty, "removed snippets stay removed after reload")
check(emptiedStore.quicklinks().isEmpty, "removed quicklinks stay removed after reload")

let snippet = Snippet(title: "Address", text: "42 Galaxy Way", keyword: "addr")
store.upsertSnippet(snippet)
let link = Quicklink(
    title: "Docs",
    urlTemplate: "https://example.com/?q={query}",
    keyword: "docs"
)
store.upsertQuicklink(link)
var persistedSettings = store.settings
persistedSettings.theme = "light"
persistedSettings.autoPaste = false
persistedSettings.maxFileResults = 7
store.settings = persistedSettings

let reopened = AppStore(directory: storeDirectory)
let reloadedSnippet = reopened.snippets().first(where: { $0.id == snippet.id })
checkEqual(reloadedSnippet?.title, snippet.title, "snippet title survives reload")
checkEqual(reloadedSnippet?.text, snippet.text, "snippet text survives reload")
checkEqual(reloadedSnippet?.keyword, snippet.keyword, "snippet keyword survives reload")
let reloadedLink = reopened.quicklinks().first(where: { $0.id == link.id })
checkEqual(reloadedLink?.title, link.title, "quicklink title survives reload")
checkEqual(reloadedLink?.urlTemplate, link.urlTemplate, "quicklink URL survives reload")
checkEqual(reloadedLink?.keyword, link.keyword, "quicklink keyword survives reload")
checkEqual(reopened.settings.theme, "light", "settings survive reload")
check(!reopened.settings.autoPaste, "boolean settings survive reload")
checkEqual(reopened.settings.maxFileResults, 7, "numeric settings survive reload")

check(store.addClipboard(text: "hello", sourceApp: "Tests"), "clipboard inserts new item")
check(!store.addClipboard(text: "hello", sourceApp: "Tests"), "clipboard deduplicates")
checkEqual(store.clipboardItems().count, 1, "clipboard keeps one duplicate")
let clipboardItem = store.clipboardItems()[0]
store.toggleClipboardPin(id: clipboardItem.id)
check(store.clipboardItems()[0].pinned, "clipboard pin toggles")
store.addClipboard(text: "second", sourceApp: "Tests")
checkEqual(store.clipboardItems().first?.text, "hello", "pinned clipboard item sorts first")
store.clearClipboard(keepPinned: true)
checkEqual(store.clipboardItems().count, 1, "clipboard clear keeps pinned")

store.recordUsage(id: "builtin.clipboard")
store.recordUsage(id: "builtin.clipboard")
check((store.usageScores()["builtin.clipboard"] ?? 0) > 2, "usage score accumulates")
store.resetUsage()
check(store.usageScores().isEmpty, "usage reset clears scores")

// MARK: - Extensions

let extensionDirectory = temporaryDirectory("extensions")
let emptyExtensions = ExtensionStore(directory: extensionDirectory)
checkEqual(emptyExtensions.commands.count, 2, "extensions seed starter pack")
check(emptyExtensions.loadErrors.isEmpty, "starter extension has no load errors")

let customExtensionDirectory = temporaryDirectory("custom-extension")
let manifestFolder = customExtensionDirectory.appendingPathComponent("Example", isDirectory: true)
try? FileManager.default.createDirectory(at: manifestFolder, withIntermediateDirectories: true)
let manifest = """
{
  "name": "Example",
  "description": "Test extension",
  "commands": [
    {
      "id": "echo",
      "title": "Echo",
      "subtitle": "Prints hello",
      "keywords": ["test"],
      "script": "printf 'hello'"
    }
  ]
}
"""
try? manifest.write(
    to: manifestFolder.appendingPathComponent("extension.json"),
    atomically: true,
    encoding: .utf8
)
let customExtensions = ExtensionStore(directory: customExtensionDirectory)
checkEqual(customExtensions.commands.count, 1, "extension manifest parses")
checkEqual(customExtensions.commands.first?.id, "script:Example:echo", "extension identifier")
checkEqual(customExtensions.commands.first?.subtitle, "Prints hello", "extension subtitle")
if let echo = customExtensions.commands.first {
    switch customExtensions.run(echo) {
    case .success(let output):
        checkEqual(output, "hello", "extension script runs")
    case .failure(let error):
        check(false, "extension script runs (\(error.localizedDescription))")
    }
} else {
    check(false, "extension script runs")
}

let failingDirectory = temporaryDirectory("failing-extension")
let failingFolder = failingDirectory.appendingPathComponent("Broken", isDirectory: true)
try? FileManager.default.createDirectory(at: failingFolder, withIntermediateDirectories: true)
try? "{ not valid json }".write(
    to: failingFolder.appendingPathComponent("extension.json"),
    atomically: true,
    encoding: .utf8
)
let brokenExtensions = ExtensionStore(directory: failingDirectory)
check(brokenExtensions.commands.isEmpty, "invalid extension is ignored")
checkEqual(brokenExtensions.loadErrors.count, 1, "invalid extension reports an error")

// MARK: - Coding Tools, Window Layouts & Composio Connectors

check(WindowCommand.allCases.count >= 22, "window management includes thirds, sixths, and display commands")
check(CodingDriverKind.allCases.count == 11, "coding tool drivers cover T3 Code / Omni Bot harnesses")
let searchDirs = CodingToolsService.extendedSearchDirectories()
check(!searchDirs.isEmpty, "coding tool search directories include extended user/system paths")
let composioCatalog = ComposioService.defaultCatalog()
check(composioCatalog.count >= 18, "composio connector catalog includes 18 core SaaS integrations")
check(composioCatalog.contains(where: { $0.slug == "github" }), "composio catalog contains GitHub")
check(composioCatalog.contains(where: { $0.slug == "linear" }), "composio catalog contains Linear")
check(composioCatalog.contains(where: { $0.slug == "stripe" }), "composio catalog contains Stripe")

let composioTestService = ComposioService(store: store)
composioTestService.addCustomConnector(name: "Airtable", slug: "airtable", category: "Productivity")
check(composioTestService.catalog.contains(where: { $0.slug == "airtable" && $0.isConnected }), "custom composio connector adds and connects")
composioTestService.removeCustomConnector(slug: "airtable")
check(!composioTestService.catalog.contains(where: { $0.slug == "airtable" }), "custom composio connector removes cleanly")

// MARK: - Summary

for directory in [
    storeDirectory,
    extensionDirectory,
    customExtensionDirectory,
    failingDirectory,
] {
    try? FileManager.default.removeItem(at: directory)
}

print("")
print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
