import AppKit
import Darwin
import Foundation
import DispatchCore

public enum SystemActionResult: Equatable {
    case success
    case failed(String)
}

public final class SystemActions {
    public init() {}

    @discardableResult
    public func perform(_ command: SystemCommand) -> SystemActionResult {
        switch command {
        case .lockScreen:
            return lockScreen()
        case .sleep:
            return run("/usr/bin/pmset", ["sleepnow"])
        case .restart:
            return runAppleScript("tell application \"System Events\" to restart")
        case .shutDown:
            return runAppleScript("tell application \"System Events\" to shut down")
        case .emptyTrash:
            return runAppleScript("tell application \"Finder\" to empty trash")
        case .toggleDarkMode:
            return runAppleScript(
                "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
            )
        case .takeScreenshot:
            return takeScreenshot()
        case .volumeUp:
            return adjustVolume(by: 10)
        case .volumeDown:
            return adjustVolume(by: -10)
        case .toggleMute:
            return toggleMute()
        case .showDesktop:
            return showDesktop()
        case .screenSaver:
            let path = "/System/Library/CoreServices/ScreenSaverEngine.app"
            if FileManager.default.fileExists(atPath: path) {
                return run("/usr/bin/open", ["-a", path])
            }
            return .failed("Screen Saver is not available on this system.")
        case .logOut:
            return runAppleScript("tell application \"System Events\" to log out")
        }
    }

    private func lockScreen() -> SystemActionResult {
        // login.framework exposes the system lock entry point on current
        // macOS versions. It is private API, so always keep public fallbacks.
        if let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/login",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFunction = @convention(c) () -> Void
            unsafeBitCast(symbol, to: LockFunction.self)()
            return .success
        }

        let cgSession = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.fileExists(atPath: cgSession) {
            return run(cgSession, ["-suspend"])
        }
        return run("/usr/bin/pmset", ["displaysleepnow"])
    }

    private func takeScreenshot() -> SystemActionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]
        do {
            try process.run()
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func adjustVolume(by delta: Int) -> SystemActionResult {
        let script = """
        set currentVolume to output volume of (get volume settings)
        set newVolume to currentVolume + \(delta)
        if newVolume > 100 then set newVolume to 100
        if newVolume < 0 then set newVolume to 0
        set volume output volume newVolume
        """
        return runAppleScript(script)
    }

    private func toggleMute() -> SystemActionResult {
        let script = """
        set settings to get volume settings
        if output muted of settings then
            set volume without output muted
        else
            set volume with output muted
        end if
        """
        return runAppleScript(script)
    }

    private func showDesktop() -> SystemActionResult {
        // F11 / Show Desktop. Posting synthetic keys requires Accessibility.
        guard WindowManager.isAccessibilityTrusted() else {
            return .failed("Show Desktop needs Accessibility permission. Enable Dispatch in System Settings → Privacy & Security → Accessibility.")
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failed("Could not create an event source.")
        }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: false)
        keyDown?.flags = .maskSecondaryFn
        keyUp?.flags = .maskSecondaryFn
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return .success
    }

    private func run(_ executable: String, _ arguments: [String]) -> SystemActionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success
            }
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(detail.flatMap { $0.isEmpty ? nil : $0 } ?? "Command exited with status \(process.terminationStatus).")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func runAppleScript(_ source: String) -> SystemActionResult {
        guard let script = NSAppleScript(source: source) else {
            return .failed("Could not create AppleScript.")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String)
                ?? (error[NSAppleScript.errorBriefMessage] as? String)
                ?? "AppleScript failed."
            return .failed(message)
        }
        return .success
    }
}
