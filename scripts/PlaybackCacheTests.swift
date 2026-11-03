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
        expect(engine.contains("preferredForwardBufferDuration = 0"), "automatic forward buffering")
        exit(failures == 0 ? 0 : 1)
    }
}
