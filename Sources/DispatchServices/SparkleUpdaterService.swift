import AppKit
import Foundation
import ObjectiveC.runtime

/// Dynamically loads embedded `Sparkle.framework` (`SPUStandardUpdaterController`)
/// at runtime when running from `Dispatch.app`, so `swift build` and `swift run`
/// continue to work without requiring framework linker flags during development.
@MainActor
public final class SparkleUpdaterService: NSObject {
    public static let shared = SparkleUpdaterService()

    private var updaterController: AnyObject?

    private override init() {
        super.init()
        loadIfNeeded()
    }

    public var isAvailable: Bool {
        updaterController != nil
    }

    private func loadIfNeeded() {
        guard updaterController == nil else { return }
        let candidates: [URL?] = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent("Sparkle.framework"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/Sparkle.framework"),
        ]
        for candidate in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: candidate.path) {
            if let bundle = Bundle(url: candidate), bundle.load() {
                break
            }
        }

        guard let cls = NSClassFromString("SPUStandardUpdaterController") as? NSObject.Type else {
            return
        }

        // Initialize SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        typealias AllocFn = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
        typealias InitFn = @convention(c) (AnyObject, Selector, Bool, AnyObject?, AnyObject?) -> Unmanaged<AnyObject>?

        let allocSel = NSSelectorFromString("alloc")
        let initSel = NSSelectorFromString("initWithStartingUpdater:updaterDelegate:userDriverDelegate:")
        guard cls.responds(to: allocSel),
              let allocImp = class_getMethodImplementation(object_getClass(cls), allocSel) else {
            return
        }
        let allocFn = unsafeBitCast(allocImp, to: AllocFn.self)
        let rawObj = allocFn(cls, allocSel).takeRetainedValue()
        guard rawObj.responds(to: initSel),
              let initImp = class_getMethodImplementation(type(of: rawObj), initSel) else {
            return
        }
        let initFn = unsafeBitCast(initImp, to: InitFn.self)
        if let initialized = initFn(rawObj, initSel, true, nil, nil)?.takeRetainedValue() {
            updaterController = initialized
        }
    }

    @objc public func checkForUpdates(_ sender: Any? = nil) {
        loadIfNeeded()
        guard let controller = updaterController else {
            let alert = NSAlert()
            alert.messageText = "Check for Updates"
            alert.informativeText = "Automatic updates are active in signed release builds of Dispatch.app."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        let sel = NSSelectorFromString("checkForUpdates:")
        if controller.responds(to: sel) {
            _ = controller.perform(sel, with: sender)
        }
    }
}
