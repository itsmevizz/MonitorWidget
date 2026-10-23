import Foundation

public struct VCPValue: Equatable {
    public let current: UInt16
    public let max: UInt16
    public init(current: UInt16, max: UInt16) {
        self.current = current
        self.max = max
    }
}

/// One external display reachable over DDC/CI.
/// All bus access is serialized with `bus`, because DDC/CI is a slow, single-master channel.
public final class Monitor: @unchecked Sendable {
    public let index: Int
    private let av: UnsafeMutableRawPointer
    private let bus = NSRecursiveLock()

    // Pending writes are coalesced so dragging a slider sends one update per ~60 ms.
    private let pendingLock = NSLock()
    private var pending: [UInt8: UInt16] = [:]
    private var flushScheduled = false

    /// Supported VCP codes and their allowed values (empty list = continuous control).
    public private(set) var capabilities: [UInt8: [UInt8]] = [:]
    public private(set) var capabilityString: String = ""

    // DDC/CI addressing: display sits at I2C 0x37; the host uses source address 0x51.
    private let chipAddress: UInt32 = 0x37
    private let hostAddress: UInt32 = 0x51

    init(index: Int, av: UnsafeMutableRawPointer) {
        self.index = index
        self.av = av
    }

    public static func discover() -> [Monitor] {
        externalAVServices().enumerated().map { Monitor(index: $0.offset + 1, av: $0.element) }
    }

    // MARK: - Public API

    /// Reads the MCCS capability string (VCP feature list) once and caches it.
    @discardableResult
    public func loadCapabilities() -> Bool {
        bus.lock(); defer { bus.unlock() }
        guard let raw = readCapabilityString(), !raw.isEmpty else { return false }
        capabilityString = raw
        capabilities = Monitor.parseVCP(raw)
        return true
    }

    public func supports(_ code: UInt8) -> Bool {
        capabilities[code] != nil
    }

    public func get(_ code: UInt8) -> VCPValue? {
        bus.lock(); defer { bus.unlock() }
        return readVCP(code)
    }

    @discardableResult
    public func set(_ code: UInt8, _ value: UInt16) -> Bool {
        bus.lock(); defer { bus.unlock() }
        return writeVCP(code, value)
    }

    /// Non-blocking set for UI sliders. Only the latest value per code is sent.
    public func enqueueSet(_ code: UInt8, _ value: UInt16) {
        pendingLock.lock()
        pending[code] = value
        let needsFlush = !flushScheduled
        flushScheduled = true
        pendingLock.unlock()

        if needsFlush {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(60)) { [weak self] in
                self?.flushPending()
            }
        }
    }

    private func flushPending() {
        pendingLock.lock()
        let batch = pending
        pending.removeAll()
        flushScheduled = false
        pendingLock.unlock()

        for (code, value) in batch {
            set(code, value)
            usleep(40_000) // DDC/CI needs a short gap between commands
        }
    }

    // MARK: - Low-level DDC/CI packets

    /// Host -> display write: [0x80|len, payload..., checksum]. Checksum = XOR of 0x6E, 0x51 and every byte.
    private func writePacket(_ payload: [UInt8]) -> Bool {
        var packet: [UInt8] = [0x80 | UInt8(payload.count)] + payload
        var checksum: UInt8 = 0x6E ^ UInt8(hostAddress)
        for byte in packet { checksum ^= byte }
        packet.append(checksum)

        let rc = packet.withUnsafeBufferPointer { buf in
            IOAVServiceWriteI2C(av, chipAddress, hostAddress, buf.baseAddress!, UInt32(buf.count))
        }
        return rc == 0
    }

    private func readBytes(_ count: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: count)
        let rc = buffer.withUnsafeMutableBytes { raw in
            IOAVServiceReadI2C(av, chipAddress, 0, raw.baseAddress!, UInt32(count))
        }
        return rc == 0 ? buffer : nil
    }

    /// VCP Get: request [0x01, code]; reply [src, 0x88, 0x02, result, code, type, maxH, maxL, curH, curL, chk].
    private func readVCP(_ code: UInt8) -> VCPValue? {
        for _ in 0..<3 {
            guard writePacket([0x01, code]) else { usleep(20_000); continue }
            usleep(50_000)
            guard let reply = readBytes(12), reply.count >= 10 else { continue }
            // Locate the reply header in case the driver prepends a byte.
            for i in 0...(reply.count - 10) where reply[i + 2] == 0x02 && reply[i + 4] == code {
                guard reply[i + 3] == 0 else { return nil } // 1 = unsupported code
                let max = UInt16(reply[i + 6]) << 8 | UInt16(reply[i + 7])
                let cur = UInt16(reply[i + 8]) << 8 | UInt16(reply[i + 9])
                return VCPValue(current: cur, max: max)
            }
        }
        return nil
    }

    /// VCP Set: payload [0x03, code, valueHigh, valueLow].
    private func writeVCP(_ code: UInt8, _ value: UInt16) -> Bool {
        for _ in 0..<2 {
            if writePacket([0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)]) {
                usleep(40_000)
                return true
            }
            usleep(30_000)
        }
        return false
    }

    /// Capabilities request is chunked: [0xF3, offsetHigh, offsetLow]; reply is [src, 0x80|len, 0xE3, offH, offL, data...].
    private func readCapabilityString() -> String? {
        var offset: UInt16 = 0
        var collected: [UInt8] = []

        while offset < 4096 {
            var chunk: [UInt8] = []
            var ok = false
            for _ in 0..<3 {
                guard writePacket([0xF3, UInt8(offset >> 8), UInt8(offset & 0xFF)]) else { usleep(30_000); continue }
                usleep(60_000)
                guard let reply = readBytes(38) else { continue }
                if let i = reply.firstIndex(of: 0xE3), i >= 1, i + 4 < reply.count {
                    let length = Int(reply[i - 1] & 0x7F)
                    let dataCount = max(0, length - 3)
                    let start = i + 3
                    let end = min(reply.count, start + dataCount)
                    chunk = Array(reply[start..<end])
                    ok = true
                    break
                }
            }
            guard ok else { break }
            if chunk.isEmpty { break }
            collected += chunk
            offset += UInt16(chunk.count)
            if chunk.last == 0 { break }
        }

        // Strip NUL padding and anything after the closing parenthesis of the MCCS string.
        let text = collected.prefix { $0 != 0 }
        return String(bytes: text, encoding: .ascii)
    }

    // MARK: - Capability string parser

    /// Parses "(prot(monitor)type(LCD)vcp(10 12 14(05 08) 60(0F 11) 62 8D)...)" into [code: allowed values].
    public static func parseVCP(_ caps: String) -> [UInt8: [UInt8]] {
        let bytes = Array(caps.utf8)
        guard let marker = caps.range(of: "vcp(") else { return [:] }
        var idx = caps.utf8.distance(from: caps.utf8.startIndex, to: marker.upperBound)

        func isHex(_ b: UInt8) -> Bool {
            (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66)
        }
        func hexToken() -> UInt8? {
            var s = ""
            while idx < bytes.count, isHex(bytes[idx]) {
                s.append(Character(UnicodeScalar(bytes[idx])))
                idx += 1
            }
            return s.isEmpty ? nil : UInt8(s, radix: 16)
        }

        var result: [UInt8: [UInt8]] = [:]
        while idx < bytes.count {
            let b = bytes[idx]
            if b == UInt8(ascii: ")") { break }
            guard let code = hexToken() else { idx += 1; continue }

            var values: [UInt8] = []
            if idx < bytes.count, bytes[idx] == UInt8(ascii: "(") {
                idx += 1
                while idx < bytes.count, bytes[idx] != UInt8(ascii: ")") {
                    if let v = hexToken() { values.append(v) } else { idx += 1 }
                }
                idx += 1 // consume ')'
            }
            result[code] = values
        }
        return result
    }
}
