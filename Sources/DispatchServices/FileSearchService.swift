import AppKit
import Foundation

public struct FileEntry: Identifiable, Equatable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let modified: Date?

    public init(path: String, name: String, isDirectory: Bool, modified: Date? = nil) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.modified = modified
    }
}

/// Spotlight-backed file search. The result stream is capped and the mdfind
/// process is terminated once enough candidates have arrived, so broad queries
/// cannot flood the UI or run indefinitely.
public final class FileSearchService {
    public init() {}

    public func search(query: String, limit: Int = 20) async -> [FileEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let limit = max(1, min(limit, 80))

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.runMDFind(query: trimmed, limit: limit))
            }
        }
    }

    private static func runMDFind(query: String, limit: Int) -> [FileEntry] {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "")
        let prefixPredicate = "kMDItemFSName == '\(escaped)*'c"
        var allPaths = queryMDFind(predicate: prefixPredicate, maxLines: limit * 2)
        if allPaths.count < limit {
            let containsPredicate = "kMDItemFSName == '*\(escaped)*'c"
            let morePaths = queryMDFind(predicate: containsPredicate, maxLines: limit * 2)
            allPaths.append(contentsOf: morePaths)
        }

        var seen = Set<String>()
        let entries = allPaths
            .filter { path in
                guard !path.isEmpty,
                      !path.contains("/.git/"),
                      !path.contains("/node_modules/"),
                      !path.contains("/Library/"),
                      !path.contains("/.Trash/"),
                      !path.contains("/.build/"),
                      !path.contains("/build/"),
                      !path.contains("/target/"),
                      !path.contains("/out/"),
                      !path.contains(".app/Contents/"),
                      !path.hasSuffix(".o"),
                      !path.hasSuffix(".d"),
                      !path.hasSuffix(".pyc") else {
                    return false
                }
                return seen.insert(path).inserted
            }
            .prefix(limit * 3)
            .compactMap { makeEntry(path: $0) }
            .sorted { lhs, rhs in
                let foldedQ = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let lhsPrefix = lhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).hasPrefix(foldedQ)
                let rhsPrefix = rhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).hasPrefix(foldedQ)
                if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                switch (lhs.modified, rhs.modified) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }

        return Array(entries.prefix(limit))
    }

    private static func queryMDFind(predicate: String, maxLines: Int) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", NSHomeDirectory(), predicate]
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return []
        }

        let watchdog = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: watchdog)

        var data = Data()
        let maximumBytes = 512 * 1024
        while data.count < maximumBytes {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 8_192)
            if chunk.isEmpty { break }
            data.append(chunk)
            if data.reduce(into: 0, { $0 += ($1 == 0x0A ? 1 : 0) }) >= maxLines {
                if process.isRunning { process.terminate() }
                break
            }
        }
        watchdog.cancel()
        try? pipe.fileHandleForReading.close()
        if process.isRunning { process.terminate() }
        process.waitUntilExit()

        return String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .map(String.init) ?? []
    }

    private static func makeEntry(path: String) -> FileEntry? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .nameKey])
        return FileEntry(
            path: path,
            name: values?.name ?? url.lastPathComponent,
            isDirectory: values?.isDirectory ?? false,
            modified: values?.contentModificationDate
        )
    }

    public func open(_ entry: FileEntry) {
        NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
    }

    public func reveal(_ entry: FileEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
    }
}
