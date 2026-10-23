import Foundation

/// MIPI/VESA Monitor Control Command Set (MCCS) feature codes used by this app.
public enum VCP {
    public static let restoreDefaults: UInt8 = 0x04
    public static let brightness: UInt8 = 0x10
    public static let contrast: UInt8 = 0x12
    public static let colorPreset: UInt8 = 0x14
    public static let redGain: UInt8 = 0x16
    public static let greenGain: UInt8 = 0x18
    public static let blueGain: UInt8 = 0x1A
    public static let sharpness: UInt8 = 0x87
    public static let saturation: UInt8 = 0x8A
    public static let input: UInt8 = 0x60
    /// Acer picture mode selector (vendor-specific). Changing it can reset brightness/contrast.
    public static let pictureMode: UInt8 = 0xE2
    public static let volume: UInt8 = 0x62
    public static let mute: UInt8 = 0x8D
    public static let powerMode: UInt8 = 0xD6
    public static let vcpVersion: UInt8 = 0xDF

    public static let names: [UInt8: String] = [
        0x04: "Restore factory defaults",
        0x05: "Restore brightness/contrast",
        0x08: "Restore color defaults",
        0x0B: "Color temperature increment",
        0x0C: "Color temperature request",
        0x10: "Brightness",
        0x12: "Contrast",
        0x14: "Color preset",
        0x16: "Red video gain",
        0x18: "Green video gain",
        0x1A: "Blue video gain",
        0x1E: "Auto setup",
        0x20: "Horizontal position",
        0x30: "Vertical position",
        0x3E: "Clock",
        0x52: "Active control",
        0x60: "Input source",
        0x62: "Speaker volume",
        0x87: "Sharpness",
        0x8A: "Saturation",
        0x8D: "Audio mute",
        0xAC: "Horizontal frequency",
        0xAE: "Vertical frequency",
        0xB2: "Flat panel sub-pixel layout",
        0xB6: "Display technology type",
        0xC0: "Display usage time",
        0xC6: "Application enable key",
        0xC8: "Display controller type",
        0xC9: "Display firmware level",
        0xCA: "OSD / button control",
        0xCC: "OSD language",
        0xD6: "Power mode",
        0xDC: "Display mode (picture mode)",
        0xDF: "VCP version",
    ]

    public static let inputNames: [UInt8: String] = [
        0x0F: "DisplayPort 1", 0x10: "DisplayPort 2",
        0x11: "HDMI 1", 0x12: "HDMI 2",
        0x1B: "USB-C", 0x0D: "DVI 1", 0x0E: "DVI 2", 0x01: "VGA 1",
    ]

    public static let colorPresetNames: [UInt8: String] = [
        0x01: "sRGB", 0x02: "Native", 0x03: "4000 K", 0x04: "5000 K",
        0x05: "6500 K", 0x06: "7500 K", 0x07: "8200 K", 0x08: "9300 K",
        0x09: "10000 K", 0x0A: "11500 K", 0x0B: "User 1", 0x0C: "User 2", 0x0D: "User 3",
    ]

    public static let powerNames: [UInt8: String] = [
        0x01: "On", 0x02: "Standby", 0x03: "Suspend", 0x04: "Off (soft)", 0x05: "Off (hard)",
    ]

    public static func name(for code: UInt8) -> String {
        names[code] ?? String(format: "Vendor/unknown 0x%02X", code)
    }

    /// Resolve "brightness", "0x10", "10", etc. to a feature code.
    public static func code(from token: String) -> UInt8? {
        let t = token.lowercased()
        let aliases: [String: UInt8] = [
            "brightness": brightness, "luminance": brightness, "contrast": contrast,
            "preset": colorPreset, "color-preset": colorPreset,
            "red": redGain, "green": greenGain, "blue": blueGain,
            "input": input, "volume": volume, "mute": mute,
            "power": powerMode, "sharpness": sharpness, "saturation": saturation,
        ]
        if let c = aliases[t] { return c }
        if t.hasPrefix("0x") { return UInt8(t.dropFirst(2), radix: 16) }
        return UInt8(t, radix: 16)
    }
}
