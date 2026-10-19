import Foundation
import DispatchCore

public struct ScriptCommand: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let keywords: [String]
    public let icon: String?
    public let extensionName: String
    public let script: String?
    public let url: String?
    public let manifestPath: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        keywords: [String],
        icon: String?,
        extensionName: String,
        script: String?,
        url: String?,
        manifestPath: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.icon = icon
        self.extensionName = extensionName
        self.script = script
        self.url = url
        self.manifestPath = manifestPath
    }
}

private struct ScriptExtensionManifest: Codable {
    var name: String
    var author: String?
    var description: String?
    var commands: [ScriptCommandSpec]
}

private struct ScriptCommandSpec: Codable {
    var id: String?
    var title: String
    var subtitle: String?
    var description: String?
    var keywords: [String]?
    var icon: String?
    var script: String?
    var url: String?
}

/// A lightweight, permission-free extension format. Each extension is a folder
/// containing `extension.json` with one or more script or URL commands.
public final class ExtensionStore: @unchecked Sendable {
    public private(set) var commands: [ScriptCommand] = []
    public private(set) var loadErrors: [String] = []

    private let directory: URL

    public init(directory: URL = AppPaths.extensionsDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        seedStarterExtensionIfNeeded()
        reload()
    }

    public func reload() {
        loadErrors.removeAll()
        var found: [ScriptCommand] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            commands = []
            return
        }

        for case let url as URL in enumerator {
            guard url.lastPathComponent == "extension.json" || url.lastPathComponent == "manifest.json" else {
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let manifest = try JSONDecoder().decode(ScriptExtensionManifest.self, from: data)
                let folderURL = url.deletingLastPathComponent()
                let folder = folderURL.path
                for (index, spec) in manifest.commands.enumerated() {
                    let identifier = "script:\(manifest.name):\(spec.id ?? "\(index)")"
                    found.append(
                        ScriptCommand(
                            id: identifier,
                            title: spec.title,
                            subtitle: spec.subtitle ?? spec.description ?? manifest.description ?? manifest.name,
                            keywords: spec.keywords ?? [],
                            icon: spec.icon,
                            extensionName: manifest.name,
                            script: spec.script,
                            url: spec.url,
                            manifestPath: folder
                        )
                    )
                }
            } catch {
                loadErrors.append("\(url.path): \(error.localizedDescription)")
            }
        }

        commands = found.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    public func run(_ command: ScriptCommand) -> Result<String, Error> {
        if let urlString = command.url, let url = URL(string: urlString) {
            NSWorkspaceShim.open(url)
            return .success("Opened \(urlString)")
        }
        guard let script = command.script, !script.isEmpty else {
            return .failure(ExtensionError.emptyCommand)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", script]
        process.currentDirectoryURL = URL(
            fileURLWithPath: command.manifestPath,
            isDirectory: true
        )
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return .failure(error)
        }

        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15, execute: watchdog)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus == 0 {
            return .success(output.isEmpty ? "Command completed." : output)
        }
        return .failure(
            ExtensionError.failed(
                output.isEmpty ? "Exited with status \(process.terminationStatus)." : output
            )
        )
    }

    private func seedStarterExtensionIfNeeded() {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        guard contents.isEmpty else { return }

        let folder = directory.appendingPathComponent("Starter", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = """
        {
          "name": "Starter",
          "author": "Dispatch",
          "description": "Two tiny examples of the script extension format.",
          "commands": [
            {
              "id": "github-trending",
              "title": "Open GitHub Trending",
              "subtitle": "Starter extension",
              "keywords": ["github", "trending", "code"],
              "icon": "chevron.left.forwardslash.chevron.right",
              "url": "https://github.com/trending"
            },
            {
              "id": "system-info",
              "title": "System Info",
              "subtitle": "Starter extension",
              "keywords": ["macos", "version", "hardware"],
              "icon": "desktopcomputer",
              "script": "sw_vers && uname -m"
            }
          ]
        }
        """
        try? manifest.write(
            to: folder.appendingPathComponent("extension.json"),
            atomically: true,
            encoding: .utf8
        )
    }
}

public enum ExtensionError: LocalizedError {
    case emptyCommand
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCommand: return "This extension command has no script."
        case .failed(let message): return message
        }
    }
}

private enum NSWorkspaceShim {
    static func open(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
    }
}
