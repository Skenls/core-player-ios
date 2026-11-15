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
        expect(handleTime.contains("PlaybackDurationPolicy.resolve"), "metadata duration is not replaced by AAC transcode duration")
        let handleEnded = body(store, after: "private func handleEnded", until: "\n    private func handleError")
        expect(handleEnded.contains("PlaybackEndPolicy.resolve"), "track end is judged by the trusted duration")
        expect(handleEnded.contains("endResumeCount < 3"), "early endings resume a bounded number of times")
        expect(handleEnded.contains("seek(at)"), "early endings resume through the seek router")
        let expiration = body(store, after: "private func handleTransitionTaskExpiration", until: "\n    // MARK: - Loading")
        expect(expiration.contains("isLoading, isPlaying"), "background task renews only while a track is loading")
        expect(expiration.contains("transitionTaskRenewals < 10"), "background task renewal is bounded")
        expect(engine.contains("playbackOffset,"), "engine reports absolute position to the store")
        expect(engine.contains("let duration = item.duration.seconds"), "engine reports the item duration to the store")
        exit(failures == 0 ? 0 : 1)
    }
}
