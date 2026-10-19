import Foundation
import DispatchCore

public struct CodingModelOption: Identifiable, Equatable, Sendable {
    public var id: String { slug }
    public let slug: String
    public let label: String

    public init(slug: String, label: String) {
        self.slug = slug
        self.label = label
    }
}

public enum CodingDriverKind: String, Codable, CaseIterable, Sendable {
    case claude
    case codex
    case opencode
    case cursor
    case grok
    case pi
    case antigravity
    case muse
    case gemini
    case aider
    case ollama

    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "OpenAI Codex"
        case .opencode: return "OpenCode"
        case .cursor: return "Cursor Agent"
        case .grok: return "Grok Build"
        case .pi: return "Pi Agent"
        case .antigravity: return "Antigravity"
        case .muse: return "Muse Code"
        case .gemini: return "Gemini CLI"
        case .aider: return "Aider"
        case .ollama: return "Ollama Local"
        }
    }

    public var binaries: [String] {
        switch self {
        case .claude: return ["claude"]
        case .codex: return ["codex"]
        case .opencode: return ["opencode"]
        case .cursor: return ["cursor-agent", "agent"]
        case .grok: return ["grok"]
        case .pi: return ["pi"]
        case .antigravity: return ["antigravity", "agy"]
        case .muse: return ["muse"]
        case .gemini: return ["gemini"]
        case .aider: return ["aider"]
        case .ollama: return ["ollama"]
        }
    }

    public var roleTitle: String {
        switch self {
        case .claude: return "Architecture & Deep Code"
        case .codex: return "Execution & Refactoring"
        case .opencode: return "Full-Stack Harness Agent"
        case .cursor: return "Fast Codebase Edits"
        case .grok: return "Systems & Swarm Engineer"
        case .pi: return "Precision Tool Agent"
        case .antigravity: return "Google Cloud Coding Agent"
        case .muse: return "Meta Muse Coding Agent"
        case .gemini: return "Multimodal & Research"
        case .aider: return "Git Pair Programmer"
        case .ollama: return "Private Local Models"
        }
    }

    public var installHint: String {
        switch self {
        case .claude: return "brew install --cask claude-code"
        case .codex: return "npm i -g @openai/codex"
        case .opencode: return "brew install opencode"
        case .cursor: return "Install via Cursor → Install 'agent' CLI"
        case .grok: return "curl -fsSL https://x.ai/cli | sh"
        case .pi: return "npm i -g @mariozechner/pi-coding-agent"
        case .antigravity: return "Install via Google Antigravity"
        case .muse: return "Install Muse Code CLI"
        case .gemini: return "npm i -g @google/gemini-cli"
        case .aider: return "pipx install aider-chat"
        case .ollama: return "brew install ollama"
        }
    }

    public var iconAssetName: String {
        switch self {
        case .claude: return "brand-claude"
        case .codex: return "brand-codex"
        case .opencode: return "brand-opencode"
        case .cursor: return "brand-cursor"
        case .grok: return "brand-grok"
        case .pi: return "brand-pi"
        case .antigravity: return "brand-antigravity"
        case .muse: return "brand-muse"
        case .gemini: return "brand-gemini"
        case .aider: return "brand-aider"
        case .ollama: return "brand-ollama"
        }
    }

    public var iconSpec: IconSpec {
        .asset(iconAssetName)
    }

    public var defaultModels: [CodingModelOption] {
        switch self {
        case .claude:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "claude-opus-5-5", label: "Claude Opus 5.5"),
                CodingModelOption(slug: "claude-sonnet-5-5", label: "Claude Sonnet 5.5"),
                CodingModelOption(slug: "claude-fable-5-1", label: "Claude Fable 5.1"),
                CodingModelOption(slug: "claude-fable-5", label: "Claude Fable 5"),
                CodingModelOption(slug: "claude-opus-5", label: "Claude Opus 5"),
                CodingModelOption(slug: "claude-opus-4-8", label: "Claude Opus 4.8"),
            ]
        case .codex:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "gpt-6.1-sol", label: "GPT-6.1 Sol"),
                CodingModelOption(slug: "gpt-6-astra", label: "GPT-6 Astra"),
                CodingModelOption(slug: "gpt-6-sol", label: "GPT-6 Sol"),
                CodingModelOption(slug: "gpt-6-luna", label: "GPT-6 Luna"),
                CodingModelOption(slug: "gpt-5.6-sol", label: "GPT-5.6 Sol"),
                CodingModelOption(slug: "gpt-5.6-terra", label: "GPT-5.6 Terra"),
            ]
        case .opencode:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "anthropic/claude-opus-5-5", label: "Claude Opus 5.5"),
                CodingModelOption(slug: "openai/gpt-6.1-sol", label: "GPT-6.1 Sol"),
                CodingModelOption(slug: "xai/grok-4.7", label: "Grok 4.7"),
                CodingModelOption(slug: "vercel/callstack/apex", label: "Apex"),
                CodingModelOption(slug: "vercel/quiverai/arrow-2", label: "Arrow 2"),
            ]
        case .cursor:
            return [
                CodingModelOption(slug: "default", label: "Auto"),
                CodingModelOption(slug: "claude-opus-5-5", label: "Claude Opus 5.5"),
                CodingModelOption(slug: "gpt-6.1-sol", label: "GPT-6.1 Sol"),
                CodingModelOption(slug: "grok-4.7", label: "Grok 4.7"),
                CodingModelOption(slug: "composer-2.5", label: "Composer 2.5"),
            ]
        case .grok:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "grok-4.7", label: "Grok 4.7"),
                CodingModelOption(slug: "grok-4.7-build-fast", label: "Grok 4.7 Fast"),
                CodingModelOption(slug: "grok-4.6", label: "Grok 4.6"),
                CodingModelOption(slug: "grok-build", label: "Grok Build"),
            ]
        case .pi:
            return [
                CodingModelOption(slug: "default", label: "Pi Default"),
                CodingModelOption(slug: "anthropic/claude-opus-5-5", label: "Claude Opus 5.5"),
                CodingModelOption(slug: "openai/gpt-6.1-sol", label: "GPT-6.1 Sol"),
            ]
        case .muse:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "muse-wonder-1.0", label: "Muse Wonder 1.0"),
                CodingModelOption(slug: "muse-wonder-full-1.0", label: "Muse Wonder Full 1.0"),
                CodingModelOption(slug: "muse-spark-1.3", label: "Muse Spark 1.3"),
            ]
        case .gemini, .antigravity:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "gemini-3.0-pro", label: "Gemini 3.0 Pro"),
                CodingModelOption(slug: "gemini-3.0-flash", label: "Gemini 3.0 Flash"),
            ]
        case .aider:
            return [
                CodingModelOption(slug: "default", label: "CLI Default"),
                CodingModelOption(slug: "sonnet", label: "Claude Sonnet"),
                CodingModelOption(slug: "opus", label: "Claude Opus"),
            ]
        case .ollama:
            return [
                CodingModelOption(slug: "llama3.2", label: "Llama 3.2"),
                CodingModelOption(slug: "qwen2.5-coder", label: "Qwen 2.5 Coder"),
                CodingModelOption(slug: "deepseek-r1", label: "DeepSeek R1"),
            ]
        }
    }
}

public struct DetectedCodingTool: Identifiable, Equatable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: CodingDriverKind
    public let installed: Bool
    public let binaryPath: String?
    public let version: String?
    public let latencyMs: Int?
    public let models: [CodingModelOption]

    public init(
        kind: CodingDriverKind,
        installed: Bool,
        binaryPath: String?,
        version: String?,
        latencyMs: Int? = nil,
        models: [CodingModelOption] = []
    ) {
        self.kind = kind
        self.installed = installed
        self.binaryPath = binaryPath
        self.version = version
        self.latencyMs = latencyMs
        self.models = models.isEmpty ? kind.defaultModels : models
    }
}

public struct LocalSkillEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String
    public let path: String
    public let source: String
}

public struct LocalMcpServerEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let commandOrUrl: String
    public let source: String
}

/// T3 Code / Omni Bot style local coding tool scanner & headless runner.
/// Auto-discovers installed CLIs across login shell PATH + well-known tool
/// directories, probes `--version` and model catalogs in parallel, scans local
/// skills & MCP configs, and streams headless agent answers inside Dispatch.
public final class CodingToolsService: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedTools: [DetectedCodingTool] = []
    private var cachedSkills: [LocalSkillEntry] = []
    private var cachedMcpServers: [LocalMcpServerEntry] = []
    private var activeProcess: Process?

    public init() {}

    public var tools: [DetectedCodingTool] {
        lock.lock()
        defer { lock.unlock() }
        return cachedTools
    }

    public var skills: [LocalSkillEntry] {
        lock.lock()
        defer { lock.unlock() }
        return cachedSkills
    }

    public var mcpServers: [LocalMcpServerEntry] {
        lock.lock()
        defer { lock.unlock() }
        return cachedMcpServers
    }

    public func models(for kind: CodingDriverKind) -> [CodingModelOption] {
        lock.lock()
        defer { lock.unlock() }
        return cachedTools.first(where: { $0.kind == kind })?.models ?? kind.defaultModels
    }

    public func scanAll() {
        let searchDirs = Self.extendedSearchDirectories()
        var discovered: [DetectedCodingTool] = CodingDriverKind.allCases.map { kind in
            let bin = Self.findBinary(candidates: kind.binaries, in: searchDirs)
            let cachedModels = Self.loadT3CachedModels(for: kind)
            return DetectedCodingTool(
                kind: kind,
                installed: bin != nil,
                binaryPath: bin,
                version: nil,
                models: cachedModels
            )
        }

        let group = DispatchGroup()
        let probeLock = NSLock()
        for index in discovered.indices where discovered[index].installed {
            guard let binaryPath = discovered[index].binaryPath else { continue }
            let kind = discovered[index].kind
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let start = Date()
                let version = Self.probeVersion(binaryPath: binaryPath)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                let models = Self.discoverModels(kind: kind, binaryPath: binaryPath)
                probeLock.lock()
                discovered[index] = DetectedCodingTool(
                    kind: kind,
                    installed: true,
                    binaryPath: binaryPath,
                    version: version,
                    latencyMs: ms,
                    models: models
                )
                probeLock.unlock()
                group.leave()
            }
        }
        _ = group.wait(timeout: .now() + 3.5)

        let scannedSkills = Self.scanLocalSkills()
        let scannedMcp = Self.scanLocalMcpServers()

        lock.lock()
        cachedTools = discovered
        cachedSkills = scannedSkills
        cachedMcpServers = scannedMcp
        lock.unlock()
    }

    public func testHarness(_ kind: CodingDriverKind) -> DetectedCodingTool {
        let searchDirs = Self.extendedSearchDirectories()
        guard let bin = Self.findBinary(candidates: kind.binaries, in: searchDirs) else {
            return DetectedCodingTool(kind: kind, installed: false, binaryPath: nil, version: nil)
        }
        let start = Date()
        let version = Self.probeVersion(binaryPath: bin)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let models = Self.discoverModels(kind: kind, binaryPath: bin)
        let updated = DetectedCodingTool(
            kind: kind,
            installed: true,
            binaryPath: bin,
            version: version,
            latencyMs: ms,
            models: models
        )
        lock.lock()
        if let idx = cachedTools.firstIndex(where: { $0.kind == kind }) {
            cachedTools[idx] = updated
        }
        lock.unlock()
        return updated
    }

    public func cancelActiveRun() {
        lock.lock()
        let proc = activeProcess
        activeProcess = nil
        lock.unlock()
        if let proc, proc.isRunning {
            proc.terminate()
        }
    }

    public func runPrompt(
        driver: CodingDriverKind,
        model: String? = nil,
        effort: String? = nil,
        prompt: String,
        cwd: String = NSHomeDirectory(),
        onUpdate: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        cancelActiveRun()
        let searchDirs = Self.extendedSearchDirectories()
        guard let binaryPath = Self.findBinary(candidates: driver.binaries, in: searchDirs) else {
            onComplete(.failure(NSError(
                domain: "CodingToolsService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "\(driver.displayName) CLI (\(driver.binaries[0])) was not found. Install with: \(driver.installHint)"]
            )))
            return
        }

        let explicitModel = model.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty || $0 == "default" ? nil : $0 }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = Self.pathEnvironment(for: binaryPath, searchDirs: searchDirs)
            env["NO_COLOR"] = "1"
            env["TERM"] = "dumb"
            env.removeValue(forKey: "CLAUDECODE")
            env.removeValue(forKey: "CLAUDE_CODE_ENTRYPOINT")
            process.environment = env

            var stdinPrompt: String?
            var args: [String] = []
            switch driver {
            case .claude:
                args = ["-p", "--output-format", "text"]
                if let explicitModel { args += ["--model", explicitModel] }
                if let effort, ["low", "medium", "high"].contains(effort) {
                    args += ["--effort", effort]
                }
                stdinPrompt = prompt
            case .codex:
                args = ["exec", "--skip-git-repo-check"]
                if let explicitModel { args += ["-m", explicitModel] }
                if let effort, ["low", "medium", "high"].contains(effort) {
                    args += ["-c", "model_reasoning_effort=\"\(effort)\""]
                }
                args.append("-")
                stdinPrompt = prompt
            case .opencode:
                args = ["run"]
                if let explicitModel { args += ["-m", explicitModel] }
                args += ["--", prompt]
            case .cursor:
                args = ["-p"]
                if let explicitModel { args += ["--model", explicitModel] }
                args += ["--", prompt]
            case .grok:
                args = ["--single=\(prompt)"]
                if let explicitModel { args += ["-m", explicitModel] }
            case .pi:
                args = ["-p"]
                if let explicitModel { args += ["--model", explicitModel] }
                args += ["--", prompt]
            case .muse:
                args = ["exec", "--disable-request-user-input"]
                if let explicitModel { args += ["--model", explicitModel] }
                if let effort, ["low", "medium", "high"].contains(effort) {
                    args += ["--reasoning-effort", effort]
                }
                args += ["--", prompt]
            case .gemini, .antigravity:
                args = ["--prompt=\(prompt)"]
                if let explicitModel { args += ["--model", explicitModel] }
            case .aider:
                args = ["--no-pretty", "--no-auto-commits", "--message=\(prompt)"]
                if let explicitModel { args += ["--model", explicitModel] }
            case .ollama:
                let chosen = explicitModel ?? "llama3.2"
                args = ["run", chosen, "--", prompt]
            }
            process.arguments = args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let inPipe = Pipe()
            if stdinPrompt != nil {
                process.standardInput = inPipe
            } else {
                process.standardInput = FileHandle.nullDevice
            }

            self?.lock.lock()
            self?.activeProcess = process
            self?.lock.unlock()

            do {
                try process.run()
            } catch {
                onComplete(.failure(error))
                return
            }

            if let stdinPrompt, let data = stdinPrompt.data(using: .utf8) {
                try? inPipe.fileHandleForWriting.write(contentsOf: data)
                try? inPipe.fileHandleForWriting.close()
            }

            var accumulated = ""
            let handle = outPipe.fileHandleForReading
            while true {
                let chunk = handle.readData(ofLength: 4096)
                if chunk.isEmpty { break }
                if let str = String(data: chunk, encoding: .utf8) {
                    accumulated += Self.stripANSI(str)
                    onUpdate(accumulated.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            self?.lock.lock()
            if self?.activeProcess === process {
                self?.activeProcess = nil
            }
            self?.lock.unlock()

            let finalOutput = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalOutput.isEmpty {
                onComplete(.success(finalOutput))
            } else if let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !errStr.isEmpty {
                onComplete(.success(Self.stripANSI(errStr)))
            } else {
                onComplete(.success("Completed with no text output."))
            }
        }
    }

    // MARK: - Model Discovery (T3 Cache + Live CLI Probe)

    private static func discoverModels(kind: CodingDriverKind, binaryPath: String) -> [CodingModelOption] {
        let t3Models = loadT3CachedModels(for: kind)
        if t3Models.count > 1 {
            return t3Models
        }

        if kind == .ollama {
            if let out = runQuickCommand(binaryPath: binaryPath, args: ["list"], timeout: 1.5) {
                var parsed: [CodingModelOption] = []
                for line in out.split(whereSeparator: \.isNewline).dropFirst() {
                    let fields = line.split(whereSeparator: \.isWhitespace)
                    if let name = fields.first {
                        let slug = String(name)
                        parsed.append(CodingModelOption(slug: slug, label: slug))
                    }
                }
                if !parsed.isEmpty { return parsed }
            }
        } else if kind == .grok {
            if let out = runQuickCommand(binaryPath: binaryPath, args: ["models"], timeout: 1.5) {
                var parsed: [CodingModelOption] = [CodingModelOption(slug: "default", label: "CLI Default")]
                for line in out.split(whereSeparator: \.isNewline) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                        let rest = trimmed.dropFirst(2)
                        if let slug = rest.split(whereSeparator: \.isWhitespace).first {
                            let s = String(slug)
                            if !parsed.contains(where: { $0.slug == s }) {
                                parsed.append(CodingModelOption(slug: s, label: s))
                            }
                        }
                    }
                }
                if parsed.count > 1 { return parsed }
            }
        }

        return kind.defaultModels
    }

    public static func loadT3CachedModels(for kind: CodingDriverKind) -> [CodingModelOption] {
        let home = NSHomeDirectory()
        let cacheFile: String
        switch kind {
        case .claude: cacheFile = "claudeAgent.json"
        case .codex: cacheFile = "codex.json"
        case .opencode: cacheFile = "opencode.json"
        case .cursor: cacheFile = "cursor.json"
        case .grok: cacheFile = "grok.json"
        case .pi: cacheFile = "pi.json"
        case .muse: cacheFile = "muse.json"
        case .antigravity: cacheFile = "antigravity.json"
        default: return kind.defaultModels
        }

        let path = "\(home)/.t3/caches/\(cacheFile)"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return kind.defaultModels
        }

        let rawModels = (json["models"] as? [[String: Any]])
            ?? ((json["status"] as? [String: Any])?["models"] as? [[String: Any]])
            ?? []
        guard !rawModels.isEmpty else { return kind.defaultModels }

        var options: [CodingModelOption] = [CodingModelOption(slug: "default", label: "CLI Default")]
        var seen: Set<String> = ["default"]
        for item in rawModels.prefix(18) {
            guard let slug = (item["id"] as? String) ?? (item["slug"] as? String),
                  !slug.isEmpty,
                  !seen.contains(slug) else { continue }
            seen.insert(slug)
            let label = (item["name"] as? String) ?? (item["displayName"] as? String) ?? slug
            options.append(CodingModelOption(slug: slug, label: label))
        }
        return options.count > 1 ? options : kind.defaultModels
    }

    private static func runQuickCommand(binaryPath: String, args: [String], timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.03)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readData(ofLength: 16_384)
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Discovery Helpers

    public static func extendedSearchDirectories() -> [String] {
        let home = NSHomeDirectory()
        var dirs: [String] = []
        func push(_ path: String) {
            if !path.isEmpty && !dirs.contains(path) {
                dirs.append(path)
            }
        }

        for rel in [
            ".local/bin",
            "bin",
            ".grok/bin",
            ".cargo/bin",
            ".bun/bin",
            ".deno/bin",
            ".opencode/bin",
            ".cursor/bin",
            ".npm-global/bin",
            ".volta/bin",
            ".yarn/bin",
            ".local/share/mise/shims",
            ".asdf/shims",
            ".pyenv/shims",
            "Library/pnpm",
            ".t3/tools/codex",
        ] {
            push("\(home)/\(rel)")
        }

        for sys in [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ] {
            push(sys)
        }

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for part in pathEnv.split(separator: ":") {
                push(String(part))
            }
        }
        return dirs
    }

    public static func findBinary(candidates: [String], in searchDirs: [String]) -> String? {
        for candidate in candidates {
            for dir in searchDirs {
                let fullPath = "\(dir)/\(candidate)"
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                   !isDir.boolValue,
                   FileManager.default.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }
        return nil
    }

    private static func pathEnvironment(for binaryPath: String, searchDirs: [String]) -> String {
        let parent = URL(fileURLWithPath: binaryPath).deletingLastPathComponent().path
        var all = [parent]
        for dir in searchDirs where !all.contains(dir) {
            all.append(dir)
        }
        return all.joined(separator: ":")
    }

    private static func probeVersion(binaryPath: String) -> String? {
        guard let output = runQuickCommand(binaryPath: binaryPath, args: ["--version"], timeout: 2.0) else {
            return nil
        }
        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("Warning:") }
    }

    public static func scanLocalSkills() -> [LocalSkillEntry] {
        let home = NSHomeDirectory()
        let roots: [(String, String)] = [
            ("\(home)/.agents/skills", "~/.agents/skills"),
            ("\(home)/.claude/skills", "~/.claude/skills"),
            ("\(home)/.codex/skills", "~/.codex/skills"),
            ("\(home)/.cursor/skills", "~/.cursor/skills"),
        ]
        var skills: [LocalSkillEntry] = []
        var seen = Set<String>()

        for (rootPath, sourceLabel) in roots {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: rootPath) else { continue }
            for slug in items where !slug.hasPrefix(".") && !seen.contains(slug) {
                let skillMD = "\(rootPath)/\(slug)/SKILL.md"
                guard let raw = try? String(contentsOfFile: skillMD, encoding: .utf8) else { continue }
                seen.insert(slug)
                let (name, desc) = parseSkillFrontmatter(raw: raw, fallbackSlug: slug)
                skills.append(LocalSkillEntry(
                    id: "skill.\(slug)",
                    name: name,
                    slug: slug,
                    description: desc,
                    path: skillMD,
                    source: sourceLabel
                ))
            }
        }
        return skills.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func parseSkillFrontmatter(raw: String, fallbackSlug: String) -> (String, String) {
        var name = fallbackSlug
        var desc = "Local agent skill /\(fallbackSlug)"
        let lines = raw.components(separatedBy: .newlines)
        for line in lines.prefix(30) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                let val = trimmed.dropFirst("name:".count).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                if !val.isEmpty { name = val }
            } else if trimmed.hasPrefix("description:") {
                let val = trimmed.dropFirst("description:".count).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                if !val.isEmpty && val != "|" && val != ">" { desc = val }
            }
        }
        return (name, desc)
    }

    public static func scanLocalMcpServers() -> [LocalMcpServerEntry] {
        let home = NSHomeDirectory()
        let candidates: [(String, String)] = [
            ("\(home)/.claude.json", "~/.claude.json"),
            ("\(home)/.cursor/mcp.json", "~/.cursor/mcp.json"),
            ("\(home)/.config/opencode/opencode.json", "~/.config/opencode/opencode.json"),
        ]
        var servers: [LocalMcpServerEntry] = []
        var seen = Set<String>()

        for (path, label) in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for key in ["mcpServers", "mcp"] {
                guard let dict = json[key] as? [String: Any] else { continue }
                for (name, val) in dict {
                    let lower = name.lowercased()
                    guard !seen.contains(lower), let cfg = val as? [String: Any] else { continue }
                    seen.insert(lower)
                    let url = (cfg["url"] as? String) ?? (cfg["serverUrl"] as? String)
                    let cmd = cfg["command"] as? String
                    let summary = url ?? cmd ?? "configured"
                    servers.append(LocalMcpServerEntry(
                        id: "mcp.\(name)",
                        name: name,
                        commandOrUrl: summary,
                        source: label
                    ))
                }
            }
        }
        return servers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func stripANSI(_ input: String) -> String {
        input.replacingOccurrences(
            of: "\\x1B\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
    }
}
