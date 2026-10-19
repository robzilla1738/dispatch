import AppKit
import Foundation
import DispatchCore

let arguments = CommandLine.arguments

if arguments.contains("--version") {
    print("Dispatch 1.0.0")
    exit(0)
}

if arguments.contains("--self-test") {
    exit(SelfTest.run() ? 0 : 1)
}

if arguments.contains("--seed-demo") {
    DemoSeeder.seed()
    if arguments.contains("--seed-only") {
        print("Seeded demo data at \(AppPaths.supportDirectory.path)")
        exit(0)
    }
}

let application = NSApplication.shared
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
