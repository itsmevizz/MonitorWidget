import AppKit
import Combine
import DDCKit
import Foundation
import ServiceManagement

/// A named snapshot of picture settings. Keys are VCP codes stored as decimal strings.
struct Preset: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var values: [String: Int]
}

@MainActor
final class MonitorModel: ObservableObject {
    @Published private(set) var displayName = "No external display"
    @Published private(set) var connected = false
    @Published private(set) var refreshing = false

    /// Current value of every continuous control (brightness, contrast, volume, RGB gains).
    @Published private(set) var levels: [UInt8: Double] = [:]
    @Published private(set) var maxValues: [UInt8: Double] = [:]
    @Published private(set) var muted = false
    @Published private(set) var input: UInt8 = 0
    @Published private(set) var colorPreset: UInt8 = 0
    @Published private(set) var colorPresetOptions: [UInt8] = []
    @Published private(set) var pictureMode: UInt8 = 0
    @Published private(set) var pictureModeOptions: [UInt8] = []
    @Published private(set) var powerMode: UInt8 = 0

    @Published private(set) var supported: Set<UInt8> = []
    @Published private(set) var inputOptions: [UInt8] = []
    @Published private(set) var presets: [Preset] = []
    @Published var launchAtLogin = false

    private var monitor: Monitor?
    private let presetsKey = "monitorPresets"

    /// Continuous controls shown as sliders, in display order.
    static let sliderCodes: [UInt8] = [VCP.brightness, VCP.contrast, VCP.volume, VCP.redGain, VCP.greenGain, VCP.blueGain]

    /// Only everyday picture/audio values are saved in presets. Color gains and input are excluded
    /// so applying a preset can never change the color balance or source.
    static let presetCodes: [UInt8] = [VCP.brightness, VCP.contrast, VCP.volume]

    init() {
        presets = loadPresets()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Accessors for the UI

    func level(_ code: UInt8) -> Double { levels[code] ?? 0 }
    func maxValue(_ code: UInt8) -> Double { maxValues[code] ?? 100 }
    func has(_ code: UInt8) -> Bool { supported.contains(code) }

    var brightnessPercent: Int? {
        guard has(VCP.brightness), levels[VCP.brightness] != nil else { return nil }
        let m = maxValue(VCP.brightness)
        return m > 0 ? Int((level(VCP.brightness) / m * 100).rounded()) : nil
    }

    // MARK: - Discovery & refresh

    func discover() {
        Task {
            let found: Monitor? = await Task.detached(priority: .userInitiated) {
                guard let m = Monitor.discover().first else { return nil }
                m.loadCapabilities()
                return m
            }.value

            monitor = found
            connected = found != nil
            displayName = Self.externalScreenName() ?? "External display"
            supported = Set(found?.capabilities.keys.map { $0 } ?? [])
            inputOptions = found?.capabilities[VCP.input] ?? []
            colorPresetOptions = found?.capabilities[VCP.colorPreset] ?? []
            pictureModeOptions = found?.capabilities[VCP.pictureMode] ?? []
            refresh()
        }
    }

    func refresh() {
        guard let monitor else { return }
        let codes = Array(supported)
        refreshing = true
        Task {
            let values: [UInt8: VCPValue] = await Task.detached(priority: .userInitiated) {
                var out: [UInt8: VCPValue] = [:]
                for code in codes {
                    if let v = monitor.get(code) { out[code] = v }
                }
                return out
            }.value
            apply(values)
            refreshing = false
        }
    }

    private func apply(_ values: [UInt8: VCPValue]) {
        var newLevels: [UInt8: Double] = levels
        var newMax: [UInt8: Double] = maxValues
        for code in Self.sliderCodes {
            if let v = values[code] {
                newLevels[code] = Double(v.current)
                newMax[code] = Double(max(v.max, 1))
            }
        }
        levels = newLevels
        maxValues = newMax
        if let v = values[VCP.mute] { muted = v.current == 1 }
        if let v = values[VCP.input] { input = UInt8(truncatingIfNeeded: v.current) }
        if let v = values[VCP.colorPreset] { colorPreset = UInt8(truncatingIfNeeded: v.current) }
        if let v = values[VCP.pictureMode] { pictureMode = UInt8(truncatingIfNeeded: v.current) }
        if let v = values[VCP.powerMode] { powerMode = UInt8(truncatingIfNeeded: v.current) }
    }

    // MARK: - Control

    func setLevel(_ code: UInt8, _ value: Double) {
        levels[code] = value
        monitor?.enqueueSet(code, UInt16(value.rounded()))
    }

    func setColorPreset(_ preset: UInt8) {
        colorPreset = preset
        monitor?.enqueueSet(VCP.colorPreset, UInt16(preset))
    }

    /// Switches the monitor's picture mode. The monitor resets brightness/contrast for the new mode,
    /// so the panel re-reads everything once it has settled.
    func setPictureMode(_ mode: UInt8) {
        pictureMode = mode
        monitor?.enqueueSet(VCP.pictureMode, UInt16(mode))
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            refresh()
        }
    }

    func setMuted(_ on: Bool) {
        muted = on
        // MCCS audio mute: 1 = mute, 2 = unmute.
        monitor?.enqueueSet(VCP.mute, on ? 1 : 2)
    }

    /// Switching input to a source with nothing plugged in blanks the panel and needs the
    /// physical buttons to recover, so the UI asks for confirmation before calling this.
    func setInput(_ source: UInt8) {
        input = source
        monitor?.enqueueSet(VCP.input, UInt16(source))
    }

    /// Puts the Mac's displays to sleep. This uses macOS, not DDC, so the panel wakes on input activity.
    func sleepDisplays() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launch-at-login change failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Presets

    func savePreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        var values: [String: Int] = [:]
        for code in Self.presetCodes where has(code) {
            values[String(code)] = Int(level(code))
        }

        let preset = Preset(name: name, values: values)
        presets.removeAll { $0.name == name }
        presets.append(preset)
        persistPresets()
    }

    func applyPreset(_ preset: Preset) {
        for (key, value) in preset.values {
            guard let code = UInt8(key), Self.presetCodes.contains(code), has(code) else { continue }
            setLevel(code, Double(value))
        }
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0 == preset }
        persistPresets()
    }

    private func loadPresets() -> [Preset] {
        guard let data = UserDefaults.standard.data(forKey: presetsKey) else { return [] }
        return (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    // MARK: - Helpers

    /// Name of the first non-built-in screen, e.g. "KA270 P6".
    static func externalScreenName() -> String? {
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            if CGDisplayIsBuiltin(number) == 0 { return screen.localizedName }
        }
        return nil
    }
}
