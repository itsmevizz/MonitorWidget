import Foundation
import DDCKit

// monitorctl — inspect and control external displays over DDC/CI.
//
//   monitorctl list                 show detected external displays
//   monitorctl scan                 dump capability string + every supported feature's value
//   monitorctl get <feature>        read one feature (brightness, contrast, volume, red, ... or 0x10)
//   monitorctl set <feature> <n>    write one feature (n = raw VCP value)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func usage() -> Never {
    print("""
    usage:
      monitorctl list
      monitorctl scan
      monitorctl get <feature>
      monitorctl set <feature> <value>
    features: brightness contrast preset red green blue input volume mute power sharpness saturation or 0xNN
    """)
    exit(0)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage() }

let monitors = Monitor.discover()
if monitors.isEmpty { fail("No external display with a DDC/CI channel found.") }

let monitor = monitors[0]
_ = monitor.loadCapabilities()

func describe(_ code: UInt8, _ value: VCPValue) -> String {
    "current=\(value.current) max=\(value.max)"
}

switch command {
case "list":
    for m in monitors {
        print("[\(m.index)] external display, capabilities: \(m.capabilities.isEmpty ? "unavailable" : "\(m.capabilities.count) features")")
    }

case "scan":
    print("MCCS capability string:")
    print(monitor.capabilityString.isEmpty ? "(not readable)" : monitor.capabilityString)
    print("")
    print("Supported features (code, name, current/max, allowed values):")
    for code in monitor.capabilities.keys.sorted() {
        let allowed = monitor.capabilities[code] ?? []
        let valueText = monitor.get(code).map { describe(code, $0) } ?? "read failed"
        var extra = ""
        if !allowed.isEmpty {
            let names: [String] = allowed.map { v in
                switch code {
                case VCP.input: return VCP.inputNames[v] ?? String(format: "0x%02X", v)
                case VCP.colorPreset: return VCP.colorPresetNames[v] ?? String(format: "0x%02X", v)
                case VCP.powerMode: return VCP.powerNames[v] ?? String(format: "0x%02X", v)
                default: return String(format: "0x%02X", v)
                }
            }
            extra = "  allowed: " + names.joined(separator: ", ")
        }
        print(String(format: "  0x%02X  %-32@ %@%@", code, VCP.name(for: code) as NSString, valueText as NSString, extra as NSString))
    }

case "get":
    guard args.count >= 2, let code = VCP.code(from: args[1]) else { usage() }
    if let v = monitor.get(code) {
        print("\(v.current)")
    } else {
        fail("read failed for 0x\(String(format: "%02X", code))")
    }

case "set":
    guard args.count >= 3, let code = VCP.code(from: args[1]), let value = UInt16(args[2]) else { usage() }
    if monitor.set(code, value) {
        print("ok")
    } else {
        fail("write failed for 0x\(String(format: "%02X", code))")
    }

default:
    usage()
}
