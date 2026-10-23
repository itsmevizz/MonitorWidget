import AppKit
import Combine
import DDCKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = MonitorModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "MonitorWidget")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "MonitorWidget"
        }

        // The SwiftUI view scrolls internally; the popover keeps a fixed size that fits the screen.
        let hosting = NSHostingController(rootView: ContentView(model: model, onQuit: { NSApp.terminate(nil) }))
        hosting.sizingOptions = []
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: ContentView.width, height: 420)

        // Keep the menu bar label in step with the monitor's brightness.
        model.$levels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)
        model.$connected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)

        // Re-discover when displays are plugged in, unplugged, or rearranged.
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.model.discover() }
            .store(in: &cancellables)

        model.discover()

        // Used for README screenshots and troubleshooting: `MonitorWidget --show-panel`.
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.showPanel() }
        }

        // `MonitorWidget --snapshot out.png` renders the panel to a 2x PNG and quits (used for the README).
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.writeSnapshot(to: path)
                NSApp.terminate(nil)
            }
        }
    }

    /// Renders the whole panel (no scrolling) into an offscreen window and writes it as PNG.
    private func writeSnapshot(to path: String) {
        let height: CGFloat = 1000
        let root = ContentView(model: model, onQuit: {})
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark)
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: ContentView.width, height: height),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        hosting.frame = NSRect(x: 0, y: 0, width: ContentView.width, height: height)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            NSLog("MonitorWidget: snapshot failed")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        if let percent = model.brightnessPercent {
            button.title = " \(percent)%"
        } else {
            button.title = ""
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, !popover.isShown else { return }

        // Fit the panel under the menu bar on whichever screen the icon sits on.
        let screenFrame = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let available = (screenFrame?.height ?? 800) - 24
        popover.contentSize = NSSize(width: ContentView.width, height: min(560, available))

        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}
