// Portable integration harness: production store/API with a deterministic HTTP transport.
import Foundation
import Combine

@MainActor final class AuthStore: ObservableObject {
    @Published var user: UserDto?
}
@MainActor final class PlayerStore {
    var currentTrack: TrackDto?
    var queueVersion = 0
    var isPlaying = false
    var queueEnded = false
    var repeatMode: RepeatMode = .off
    var queuedTracks: [TrackDto] = []
    var onSynapseSample: (() -> Void)?
    var synapseSnapshot: SynapsePlaybackSnapshot {
        SynapsePlaybackSnapshot(track: currentTrack, playing: isPlaying, duration: 100, ended: queueEnded)
    }
    func play(track: TrackDto, in tracks: [TrackDto], source: String, startPlaying: Bool) {
        queueVersion += 1; currentTrack = track; queuedTracks = tracks; isPlaying = startPlaying
    }
    func appendSynapse(_ tracks: [TrackDto], version: Int) -> Bool {
        guard version == queueVersion, queueEnded, repeatMode == .off, !tracks.isEmpty else { return false }
        queueVersion += 1
        queuedTracks += tracks; currentTrack = tracks.first; queueEnded = false; isPlaying = true
        return true
    }
}

final class SynapseHTTP: URLProtocol {
    static let lock = NSLock()
    static var requests: [(String, String, Data?)] = []
    static var failEvents = false
    static var mixDelay = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let cookie = request.value(forHTTPHeaderField: "Cookie") ?? ""
        Self.lock.lock()
        Self.requests.append((path, cookie, request.httpBody))
        let fail = Self.failEvents && path.hasSuffix("events")
        let delay = Self.mixDelay && path.hasSuffix("mix")
        Self.lock.unlock()
        let body: String
        if path.hasSuffix("mix") {
            let id = cookie.contains("beta") ? "beta" : "alpha"
            body = #"{"mix_id":"SESSION","status":"ready","tracks":[{"id":"TRACK","title":"Test","duration":100,"synapse":{"session_id":"SESSION"}}]}"#
                .replacingOccurrences(of: "SESSION", with: "session-" + id).replacingOccurrences(of: "TRACK", with: "track-" + id)
        } else if path.hasSuffix("status") { body = #"{"status":"ready","progress":100}"# }
        else { body = "{}" }
        let send = {
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: fail ? 503 : 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if delay { DispatchQueue.global().asyncAfter(deadline: .now() + 0.15, execute: send) }
        else { send() }
    }
    override func stopLoading() {}
    static func count(_ suffix: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return requests.filter { $0.0.hasSuffix(suffix) }.count
    }
}

@main struct SynapseStoreTests {
    @MainActor static func wait(_ condition: () -> Bool) async {
        for _ in 0..<150 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        fatalError("Timed out waiting for integration assertion")
    }
    @MainActor static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SynapseHTTP.self]
        let api = APIClient(baseURL: URL(string: "https://synapse.invalid")!, configuration: config)
        api.configure(baseURL: api.baseURL, sessionID: "alpha")
        let auth = AuthStore(), player = PlayerStore()
        let suite = "coreplayer.synapse.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SynapseStore(api: api, player: player, auth: auth, defaults: defaults)
        auth.user = UserDto(id: "alpha", username: "a", role: "user")
        await wait { store.mix != nil }
        assert(store.continuePlayback && store.burstAnimation && store.whiteParticles)
        assert(store.owns("session-alpha"))
        let first = store.mix!.tracks[0]
        store.refresh(switchTrack: true)
        await wait { player.currentTrack != nil }
        assert(!player.isPlaying, "refresh must preserve pause")
        player.isPlaying = true
        store.refresh(switchTrack: true)
        let version = player.queueVersion
        await wait { player.queueVersion > version }
        assert(player.isPlaying)
        SynapseHTTP.mixDelay = true
        store.refresh(switchTrack: true)
        player.queueVersion += 1 // user starts another queue while request is pending
        let changed = player.queueVersion
        await wait { !store.loading }
        assert(player.queueVersion == changed)
        SynapseHTTP.mixDelay = false
        SynapseHTTP.failEvents = true
        store.favorite(first)
        await wait { SynapseHTTP.count("events") > 0 }
        try? await Task.sleep(nanoseconds: 30_000_000)
        let pending = defaults.dictionaryRepresentation().filter { $0.key.hasSuffix("outbox") }.values.compactMap { $0 as? Data }
        assert(pending.contains { (try? JSONDecoder().decode(SynapseEventBatch.self, from: $0).events.count) == 1 })
        SynapseHTTP.failEvents = false
        store.flush()
        await wait { SynapseHTTP.count("events") >= 2 }
        store.continuePlayback = false
        api.configure(baseURL: api.baseURL, sessionID: "beta")
        auth.user = UserDto(id: "beta", username: "b", role: "user")
        await wait { store.mix?.mix_id == "session-beta" }
        assert(!store.owns("session-alpha") && store.continuePlayback)
        let before = SynapseHTTP.count("events")
        store.favorite(first) // stale old-account exposure must never train beta
        try? await Task.sleep(nanoseconds: 30_000_000)
        assert(SynapseHTTP.count("events") == before)
        let mixes = SynapseHTTP.count("mix")
        player.queueEnded = true
        store.sample()
        await wait { !player.queueEnded }
        player.queueEnded = true
        store.sample()
        await wait { !player.queueEnded }
        assert(SynapseHTTP.count("mix") >= mixes + 2, "continuation must work for multiple batches")
        store.resetProfile()
        await wait { !store.resetting && SynapseHTTP.count("profile") == 1 && store.mix != nil }
        auth.user = nil
        assert(store.mix == nil && !store.owns("session-beta"))
        print("Synapse store integration passed: credentials, preferences, refresh state/race, retry outbox, reset, stale exposure")
    }
}
