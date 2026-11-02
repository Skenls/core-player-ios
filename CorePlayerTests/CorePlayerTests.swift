import XCTest
@testable import CorePlayer

final class CorePlayerTests: XCTestCase {
    func testLRCParse() {
        let lines = LRCParser.parse("[00:01.00][00:03.00]Hi\n[00:05.50]There")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].time, 1, accuracy: 0.001)
        XCTAssertEqual(lines[1].time, 3, accuracy: 0.001)
    }

    func testStreamURL() {
        let base = URL(string: "http://localhost:3000")!
        let url = StreamURLBuilder.streamURL(
            baseURL: base,
            trackID: "abc",
            codec: .auto,
            sessionID: "sid"
        )!
        XCTAssertTrue(url.absoluteString.contains("session_id=sid"))
        XCTAssertFalse(url.absoluteString.contains("format="))
    }

    func testQueueNext() {
        let tracks = [TrackDto(id: "1", title: "A"), TrackDto(id: "2", title: "B")]
        var queue = QueueState()
        queue.setQueue(tracks, startAt: 0)
        XCTAssertEqual(queue.nextIndex(), 1)
    }
}
