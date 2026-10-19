import AppKit
import Combine
import Foundation
import DispatchCore

@MainActor
public final class ClipboardService: ObservableObject {
    @Published public private(set) var items: [ClipboardRecord] = []

    public var onChange: (() -> Void)?

    private let store: AppStore
    private var timer: Timer?
    private var lastChangeCount: Int
    private var isPaused = false

    public init(store: AppStore = .shared) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
        reload()
    }

    deinit {
        timer?.invalidate()
    }

    public func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureIfNeeded()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func reload() {
        items = store.clipboardItems()
    }

    public func captureIfNeeded() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let frontmost = NSWorkspace.shared.frontmostApplication
        let source = frontmost?.localizedName ?? "Unknown"
        let sourcePath = frontmost?.bundleURL?.path

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty,
           urls.allSatisfy(\.isFileURL) {
            let text = urls.map(\.path).joined(separator: "\n")
            if store.addClipboard(text: text, sourceApp: source, sourcePath: sourcePath, kind: .file) {
                reload()
                onChange?()
            }
            return
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let capped = String(string.prefix(500_000))
            if store.addClipboard(text: capped, sourceApp: source, sourcePath: sourcePath, kind: .text) {
                reload()
                onChange?()
            }
            return
        }

        if let imagePath = saveImage(from: pasteboard) {
            let text = "Image copied from \(source)"
            if store.addClipboard(text: text, sourceApp: source, sourcePath: sourcePath, kind: .image, imagePath: imagePath) {
                reload()
                onChange?()
            }
        }
    }

    public func copy(_ record: ClipboardRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch record.kind {
        case .image:
            if let path = record.imagePath, let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setString(record.text, forType: .string)
            }
        case .file:
            let urls = record.text
                .split(separator: "\n")
                .map { URL(fileURLWithPath: String($0)) }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            } else {
                pasteboard.setString(record.text, forType: .string)
            }
        case .text:
            pasteboard.setString(record.text, forType: .string)
        }

        lastChangeCount = pasteboard.changeCount
    }

    public func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    public func remove(_ record: ClipboardRecord) {
        store.removeClipboard(id: record.id)
        reload()
    }

    public func togglePin(_ record: ClipboardRecord) {
        store.toggleClipboardPin(id: record.id)
        reload()
    }

    public func clear(keepPinned: Bool = true) {
        store.clearClipboard(keepPinned: keepPinned)
        reload()
    }

    private func saveImage(from pasteboard: NSPasteboard) -> String? {
        let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        guard let data, let representation = NSBitmapImageRep(data: data),
              let png = representation.representation(using: .png, properties: [:]) else {
            return nil
        }

        let directory = AppPaths.clipboardDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try png.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }
}
