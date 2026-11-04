import Foundation

@main
struct PlaybackCacheTests {
    static var failures = 0
    static func expect(_ ok: Bool, _ name: String) {
        print(ok ? "PASS \(name)" : "FAIL \(name)")
        if !ok { failures += 1 }
    }

    static func body(_ source: String, after marker: String, until next: String) -> String {
        guard let start = source.range(of: marker) else { return "" }
        let tail = source[start.upperBound...]
        guard let end = tail.range(of: next) else { return String(tail) }
        return String(tail[..<end.lowerBound])
    }

    static func main() {
        let root = CommandLine.arguments.dropFirst().first ?? "."
        let store = (try? String(contentsOfFile: root + "/CorePlayer/Playback/PlayerStore.swift", encoding: .utf8)) ?? ""
        let engine = (try? String(contentsOfFile: root + "/CorePlayer/Playback/PlayerEngine.swift", encoding: .utf8)) ?? ""
        let load = body(store, after: "private func loadCurrent(isRetry", until: "\n    private func ")
        expect(!load.isEmpty, "loadCurrent found")
        expect(!load.contains("cache.prefetch"), "startup does not prefetch current or next")
        expect(store.contains("engine.onPlaybackLikelyToKeepUp"), "next prefetch waits for healthy buffer")
        let prefetch = body(store, after: "private func prefetchNextTrack", until: "\n    // MARK")
        expect(prefetch.contains("PlaybackPrefetchPolicy.allows"), "prefetch policy skips raw FLAC")
        expect(engine.contains("preferredForwardBufferDuration = 0"), "automatic forward buffering")
        let seek = body(store, after: "func seek(_ time", until: "\n    func toggleShuffle")
        expect(seek.contains("PlaybackSeekRouter.route"), "seek uses the remote offset router")
        let restart = body(store, after: "private func restartOffsetStream", until: "\n    private func finishPendingSeeks")
        expect(restart.contains("timeOffset: timeOffset"), "remote restart requests a server time offset")
        expect(restart.contains("startOffset: Double(offset)"), "remote restart keeps the absolute timeline")
        let handleTime = body(store, after: "private func handleTime", until: "\n    private func ")
        expect(handleTime.contains("streamOffset == 0"), "offset stream does not replace track duration")
        exit(failures == 0 ? 0 : 1)
    }
}
