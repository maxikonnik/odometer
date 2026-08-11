import AppKit
import OdometerCore

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

// Top-level code in an executable's main.swift is not implicitly
// @MainActor-isolated, but this code only ever runs on the process's main
// thread, so it is safe to assume isolation when constructing the
// explicitly @MainActor delegate.
let delegate = MainActor.assumeIsolated { OdometerAppDelegate() }
application.delegate = delegate
application.run()
