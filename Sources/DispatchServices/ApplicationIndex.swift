import AppKit
import Foundation

public struct ApplicationEntry: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public let isRunning: Bool
    public let lastModified: Date?

    public init(
        name: String,
        path: String,
        bundleIdentifier: String?,
        icon: NSImage?,
        isRunning: Bool = false,
        lastModified: Date? = nil
    ) {
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.isRunning = isRunning
        self.lastModified = lastModified
    }

    public static func == (lhs: ApplicationEntry, rhs: ApplicationEntry) -> Bool {
        lhs.path == rhs.path && lhs.isRunning == rhs.isRunning
    }
}

/// Discovers installed applications and caches their icons. Scanning happens
/// off the main thread at launch; individual lookups are cheap after that.
public final class ApplicationIndex: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedEntries: [ApplicationEntry] = []
    private var hasScanned = false

    public init() {}

    public var applications: [ApplicationEntry] {
        lock.lock()
        defer { lock.unlock() }
        return cachedEntries
    }

    public var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hasScanned
    }

    public func refresh() {
        let paths = Self.applicationDirectories()
        var entries: [ApplicationEntry] = []
        var seen = Set<String>()
        let runningIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )

        for directory in paths {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            let isCoreServices = directory == "/System/Library/CoreServices"
            let allowedCoreServices: Set<String> = [
                "Finder.app",
                "Siri.app",
                "Screen Sharing.app",
                "Archive Utility.app",
                "Software Update.app",
                "Ticket Viewer.app",
            ]
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "app" else { continue }
                enumerator.skipDescendants()

                if isCoreServices && !allowedCoreServices.contains(fileURL.lastPathComponent) {
                    continue
                }

                let path = fileURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                let bundle = Bundle(url: fileURL)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? fileURL.deletingPathExtension().lastPathComponent
                let identifier = bundle?.bundleIdentifier
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                entries.append(
                    ApplicationEntry(
                        name: name,
                        path: path,
                        bundleIdentifier: identifier,
                        icon: icon,
                        isRunning: identifier.map { runningIdentifiers.contains($0) } ?? false,
                        lastModified: values?.contentModificationDate
                    )
                )
            }
        }

        let filtered = entries.filter { entry in
            !entry.name.hasPrefix(".") &&
                entry.bundleIdentifier != "com.apple.loginwindow"
        }

        lock.lock()
        cachedEntries = filtered.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        hasScanned = true
        lock.unlock()
    }

    public func entry(forPath path: String) -> ApplicationEntry? {
        applications.first { $0.path == path }
    }

    public func open(_ entry: ApplicationEntry) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: entry.path),
            configuration: configuration,
            completionHandler: nil
        )
    }

    public func open(path: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: configuration,
            completionHandler: nil
        )
    }

    public static func applicationDirectories() -> [String] {
        let home = NSHomeDirectory()
        return [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            "/Applications/Utilities",
            "\(home)/Applications",
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
}
