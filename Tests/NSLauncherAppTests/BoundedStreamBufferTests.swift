import XCTest
@testable import NSLauncherApp

final class BoundedStreamBufferTests: XCTestCase {
    func testKeepsEverythingBelowTheCap() {
        var buffer = BoundedStreamBuffer()
        buffer.append(Data("start\n".utf8))
        buffer.append(Data("end\n".utf8))

        XCTAssertEqual(buffer.text, "start\nend\n")
    }

    /// A game session streams for hours, so the buffer must keep the launch-time signals used for
    /// failure classification and the last thing the process said, not everything in between.
    func testKeepsHeadAndTailOnceTheStreamOutgrowsTheCap() {
        var buffer = BoundedStreamBuffer()
        let head = "DXMT startup signal\n"
        buffer.append(Data(head.utf8))
        buffer.append(Data(String(repeating: "f", count: 4 * 1024 * 1024).utf8))
        let tail = "\nprocess exited\n"
        buffer.append(Data(tail.utf8))

        let text = buffer.text
        XCTAssertTrue(text.hasPrefix(head))
        XCTAssertTrue(text.hasSuffix(tail))
        XCTAssertTrue(text.contains("middle of output omitted"))
        XCTAssertLessThan(text.utf8.count, 2 * 1024 * 1024)
    }

    func testDropsTheMiddleEvenWhenWrittenInManySmallChunks() {
        var buffer = BoundedStreamBuffer()
        buffer.append(Data("first\n".utf8))
        for _ in 0..<20_000 {
            buffer.append(Data(String(repeating: "x", count: 128).utf8))
        }
        buffer.append(Data("\nlast\n".utf8))

        XCTAssertTrue(buffer.text.hasPrefix("first\n"))
        XCTAssertTrue(buffer.text.hasSuffix("\nlast\n"))
        XCTAssertLessThan(buffer.text.utf8.count, 2 * 1024 * 1024)
    }
}
