import XCTest
@testable import MCUDisplayCore

final class MCUDisplayCoreTests: XCTestCase {
    func testPartialDisplayUpdatesAcrossPacketAndChannelBoundaries() {
        var stream = MCUSysExStream()
        var state = MCUDisplayState()

        XCTAssertTrue(stream.consume([0xF0, 0x00, 0x00]).isEmpty)
        let first = stream.consume([0x66, 0x14, 0x12, 0x00] + Array("Audio 1".utf8) + [0xF7])
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(state.apply(first[0]))

        let bottom = [UInt8(0xF0), 0, 0, 0x66, 0x14, 0x12, 56]
            + Array("+0,0dB ".utf8) + [0xF7]
        XCTAssertTrue(state.apply(bottom))
        XCTAssertEqual(state.channels[0].name, "Audio 1")
        XCTAssertEqual(state.channels[0].value, "+0,0dB")

        let crossing = [UInt8(0xF0), 0, 0, 0x66, 0x14, 0x12, 5]
            + Array("1  Green".utf8) + [0xF7]
        XCTAssertTrue(state.apply(crossing))
        XCTAssertEqual(state.channels[0].name, "Audio1")
        XCTAssertEqual(state.channels[1].name, "Green")
    }

    func testCapturedLogicColorMessage() {
        var state = MCUDisplayState()
        XCTAssertTrue(state.apply([0xF0, 0, 0, 0x66, 0x14, 0x72,
                                   0x04, 0x02, 0x05, 0x04, 0x07, 0x07, 0x07, 0x07, 0xF7]))
        XCTAssertEqual(state.channels.map(\.color), [4, 2, 5, 4, 7, 7, 7, 7])
    }

    func testIgnoresOtherMIDIAndMalformedMessages() {
        var stream = MCUSysExStream()
        XCTAssertTrue(stream.consume([0x90, 0x00, 0x7F]).isEmpty)
        XCTAssertEqual(stream.consume([0xF0, 0x00, 0xF8, 0x01, 0xF7]), [[0xF0, 0, 1, 0xF7]])
        var state = MCUDisplayState()
        XCTAssertFalse(state.apply([0xF0, 0, 0, 0x66, 0x15, 0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0xF7]))
    }
}
