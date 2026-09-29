import Foundation

public struct MCUChannel: Equatable {
    public let name: String
    public let value: String
    public let color: UInt8
}

public struct MCUDisplayState {
    private var display = Array(repeating: UInt8(0x20), count: 112)
    private var colors = Array(repeating: UInt8(0), count: 8)

    public init() {}

    public var channels: [MCUChannel] {
        (0..<8).map { index in
            let top = display[(index * 7)..<(index * 7 + 7)]
            let bottom = display[(56 + index * 7)..<(56 + index * 7 + 7)]
            return MCUChannel(
                name: String(decoding: top, as: UTF8.self).trimmingCharacters(in: .whitespaces),
                value: String(decoding: bottom, as: UTF8.self).trimmingCharacters(in: .whitespaces),
                color: colors[index]
            )
        }
    }

    @discardableResult
    public mutating func apply(_ message: [UInt8]) -> Bool {
        guard message.count >= 8,
              message[0...4].elementsEqual([0xF0, 0x00, 0x00, 0x66, 0x14]),
              message.last == 0xF7 else { return false }

        switch message[5] {
        case 0x12:
            guard message.count >= 9 else { return false }
            let start = Int(message[6])
            guard start < display.count else { return false }
            for (offset, byte) in message[7..<(message.count - 1)].enumerated() {
                let position = start + offset
                if position >= display.count { break }
                display[position] = byte < 0x80 ? byte : 0x20
            }
            return true
        case 0x72:
            guard message.count == 15 else { return false }
            colors = Array(message[6..<14]).map { $0 & 0x07 }
            return true
        default:
            return false
        }
    }
}

public struct MCUSysExStream {
    private var message: [UInt8] = []
    public init() {}

    public mutating func consume(_ bytes: [UInt8]) -> [[UInt8]] {
        var completed: [[UInt8]] = []
        for byte in bytes {
            if byte == 0xF0 {
                message = [byte]
            } else if !message.isEmpty {
                if byte >= 0xF8 { continue }
                if byte == 0xF7 {
                    message.append(byte)
                    completed.append(message)
                    message.removeAll(keepingCapacity: true)
                } else if byte >= 0x80 {
                    message.removeAll(keepingCapacity: true)
                } else if message.count < 1024 {
                    message.append(byte)
                } else {
                    message.removeAll(keepingCapacity: true)
                }
            }
        }
        return completed
    }
}
