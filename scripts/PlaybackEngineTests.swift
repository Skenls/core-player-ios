import AVFoundation
import Foundation

@main
struct PlaybackEngineTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            print("PASS \(message)")
        } else {
            failures += 1
            print("FAIL \(message)")
        }
    }

    static func wait(until condition: () -> Bool, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }

    static func makeWAV(seconds: Double, sampleRate: Int = 8000) -> Data {
        let frames = Int(seconds * Double(sampleRate))
        let dataSize = frames * 2
        var data = Data()
        func append(_ text: String) { data.append(contentsOf: text.utf8) }
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        append("RIFF")
        append32(UInt32(36 + dataSize))
        append("WAVEfmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }

    static func main() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("coreplayer-seek-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try makeWAV(seconds: 3).write(to: url)
        } catch {
            print("FAIL fixture: \(error)")
            exit(1)
        }

        let engine = PlayerEngine()
        var ready = false
        var loadedDuration = 0.0
        var healthyCount = 0
        engine.onReady = { duration in
            loadedDuration = duration
            ready = true
        }
        engine.onPlaybackLikelyToKeepUp = {
            healthyCount += 1
        }
        engine.load(url: url, autoPlay: false)
        expect(wait(until: { ready }), "engine becomes ready")
        expect(abs(loadedDuration - 3) < 0.2, "engine reports duration")
        engine.play()
        expect(wait(until: { healthyCount > 0 }), "engine reports a healthy buffer")
        expect(healthyCount == 1, "healthy buffer is reported once per item")

        var seekCompletion: Double?
        engine.seek(to: 1.5) { time in
            seekCompletion = time
        }
        expect(wait(until: { seekCompletion != nil }), "seek completion is delivered")
        if let time = seekCompletion {
            expect(abs(time - 1.5) < 0.2, "seek completion reports resulting time")
        }

        var interruptedCompletions: [Double] = []
        engine.seek(to: 0.5) { time in
            interruptedCompletions.append(time)
        }
        engine.seek(to: 2.2) { time in
            interruptedCompletions.append(time)
        }
        expect(
            wait(until: { interruptedCompletions.count >= 2 }, timeout: 4),
            "interrupted seek also completes"
        )
        expect(abs(engine.currentTime - 2.2) < 0.2, "latest seek wins")
        engine.stop()

        let offsetEngine = PlayerEngine()
        var offsetReady = false
        var offsetTicked = false
        offsetEngine.onReady = { _ in offsetReady = true }
        offsetEngine.onTime = { position, _ in
            if position >= 85.2 { offsetTicked = true }
        }
        offsetEngine.load(url: url, autoPlay: false, startOffset: 85)
        expect(wait(until: { offsetReady }), "offset stream becomes ready")
        expect(abs(offsetEngine.currentTime - 85) < 0.2, "offset starts timeline at target")
        offsetEngine.play()
        expect(wait(until: { offsetTicked }), "offset timeline continues from target")
        offsetEngine.stop()

        if failures > 0 {
            print("\(failures) playback engine test(s) failed")
            exit(1)
        }
        print("All playback engine tests passed")
    }
}
