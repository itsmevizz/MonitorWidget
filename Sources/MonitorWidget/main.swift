import AppKit

// Menu bar only app: no Dock icon, no main window.
// The app object is created on the main actor so AppDelegate's isolation holds.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
