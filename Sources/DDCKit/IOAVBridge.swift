import Foundation
import IOKit

// Private IOKit entry points exported by IOKit.framework on Apple Silicon.
// They are the same calls used by m1ddc and MonitorControl to reach a display's DDC/CI channel.
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> UnsafeMutableRawPointer?

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: UnsafeMutableRawPointer, _ chipAddress: UInt32, _ offset: UInt32,
                        _ buffer: UnsafeMutableRawPointer, _ length: UInt32) -> Int32

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: UnsafeMutableRawPointer, _ chipAddress: UInt32, _ offset: UInt32,
                         _ buffer: UnsafeRawPointer, _ length: UInt32) -> Int32

/// Returns AV services for every *external* display (the built-in panel is "Embedded").
func externalAVServices() -> [UnsafeMutableRawPointer] {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else {
        return []
    }
    defer { IOObjectRelease(iterator) }

    var result: [UnsafeMutableRawPointer] = []
    while true {
        let service = IOIteratorNext(iterator)
        if service == 0 { break }
        defer { IOObjectRelease(service) }

        let location = IORegistryEntryCreateCFProperty(service, "Location" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        if location == "External", let av = IOAVServiceCreateWithService(kCFAllocatorDefault, service) {
            result.append(av)
        }
    }
    return result
}
