import Foundation
import Combine

/// One instance for the application, independent of Home visibility.
@MainActor final class SynapseStore: ObservableObject {
    @Published private(set) var filters = SynapseFilters()
    @Published private(set) var mix: SynapseMix?
    @Published private(set) var loading = false
    @Published private(set) var resetting = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    @Published var continuePlayback = true { didSet { persist(continuePlayback, "continue") } }
    @Published var burstAnimation = true { didSet { persist(burstAnimation, "burst") } }
    @Published var whiteParticles = true { didSet { persist(whiteParticles, "white") } }

    private let sharedAPI: APIClient
    private let player: PlayerStore
    private let auth: AuthStore
    private let defaults: UserDefaults
    private var client: APIClient?
    private var binding: String?
    private var prefix: String { "synapse:\(binding ?? ""):" }
    private var epoch = 0
    private var requestID = 0
    private var sessions = Set<String>()
    private var outbox: [SynapseEvent] = []
    private var tracker = SynapseListeningTracker()
    private var mixTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var continuationTask: Task<Void, Never>?
    private var attemptedQueue: Int?
    private var timer: AnyCancellable?
    private var authObserver: AnyCancellable?
    private var tick = 0

    init(api: APIClient, player: PlayerStore, auth: AuthStore, defaults: UserDefaults = .standard) {
        sharedAPI = api; self.player = player; self.auth = auth; self.defaults = defaults
        authObserver = auth.$user.sink { [weak self] user in
            // @Published sends before assignment; user is the new identity.
            self?.bind(user)
        }
        player.onSynapseSample = { [weak self] in self?.sample() }
        timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.sample()
            self.tick += 1
            if self.tick % 30 == 0 { self.flush() }
        }
    }

    private func bind(_ user: UserDto?) {
        let key = user.map { sharedAPI.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + ":" + $0.id }
        guard key != binding else { return }
        epoch += 1; requestID += 1
        mixTask?.cancel(); continuationTask?.cancel()
        // An in-flight request uses its immutable old client; it can never send as the next account.
        binding = key; client = nil
        sessions.removeAll(); outbox.removeAll(); tracker = SynapseListeningTracker(); attemptedQueue = nil
        mix = nil; error = nil; notice = nil; loading = false; resetting = false
        guard key != nil else { return }
        let api = sharedAPI.snapshot()
        client = api
        filters = decode(SynapseFilters.self, "filters") ?? SynapseFilters()
        outbox = decode(SynapseEventBatch.self, "outbox")?.events ?? []
        continuePlayback = defaults.object(forKey: prefix + "continue") as? Bool ?? true
        burstAnimation = defaults.object(forKey: prefix + "burst") as? Bool ?? true
        whiteParticles = defaults.object(forKey: prefix + "white") as? Bool ?? true
        refresh(); flush()
    }

    func owns(_ session: String?) -> Bool {
        guard binding != nil, !resetting, let session else { return false }
        return sessions.contains(session)
    }

    func setFilters(_ value: SynapseFilters) {
        guard binding != nil, !resetting else { return }
        filters = value; save(value, "filters"); notice = nil; refresh()
    }

    func refresh(switchTrack: Bool = false) {
        guard let api = client, !resetting else { return }
        requestID += 1
        let request = requestID, generation = epoch, selected = filters, queueVersion = player.queueVersion
        mixTask?.cancel(); mix = nil; error = nil
        guard !selected.familiarity.isEmpty else { loading = false; return }
        loading = true
        mixTask = Task { [weak self] in
            var applied = false
            do {
                while !Task.isCancelled {
                    let result = try await api.synapseMix(SynapseMixRequest(familiarity: selected.familiarity, mood: selected.mood))
                    guard let self, self.epoch == generation, self.requestID == request, !Task.isCancelled else { return }
                    self.register(result); self.mix = result; self.loading = false
                    if switchTrack, !applied, let first = result.tracks.first {
                        applied = true
                        if self.player.queueVersion == queueVersion {
                            self.player.play(track: first, in: result.tracks, source: "Synapse", startPlaying: self.player.isPlaying)
                        }
                    }
                    // Status is best-effort; it must not discard a valid mix.
                    _ = try? await api.synapseStatus()
                    guard result.status == "syncing" else { return }
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            } catch {
                guard let self, self.epoch == generation, self.requestID == request, !Task.isCancelled else { return }
                self.loading = false; self.error = self.message(error)
            }
        }
    }

    private func register(_ result: SynapseMix) {
        sessions.insert(result.mix_id)
        sessions.formUnion(result.tracks.compactMap { $0.synapse?.session_id })
    }

    func sample() {
        var state = player.synapseSnapshot
        if !owns(state.track?.synapse?.session_id) { state.track?.synapse = nil }
        enqueue(tracker.sample(state, now: ProcessInfo.processInfo.systemUptime))
        guard player.queueEnded, continuePlayback, player.repeatMode == .off, client != nil,
              !resetting, !filters.familiarity.isEmpty, attemptedQueue != player.queueVersion,
              continuationTask == nil else { return }
        let version = player.queueVersion, generation = epoch, selected = filters
        let excluded = Array(Set(player.queuedTracks.map(\.id))).prefix(100000)
        attemptedQueue = version
        guard let api = client else { return }
        continuationTask = Task { [weak self] in
            defer { if self?.epoch == generation { self?.continuationTask = nil } }
            do {
                let result = try await api.synapseMix(SynapseMixRequest(familiarity: selected.familiarity, mood: selected.mood, limit: 15, exclude_track_ids: Array(excluded)))
                guard let self, !Task.isCancelled, self.epoch == generation, self.filters == selected,
                      self.continuePlayback, !self.resetting else { return }
                self.register(result)
                if self.player.appendSynapse(result.tracks, version: version) {
                    self.notice = "Synapse продолжает воспроизведение"
                }
            } catch { /* A failed refill leaves the exhausted queue paused. */ }
        }
    }

    func favorite(_ track: TrackDto) {
        let exposure = ([player.currentTrack].compactMap { $0 } + (mix?.tracks ?? []) + player.queuedTracks)
            .first { $0.id == track.id && owns($0.synapse?.session_id) }
        guard let exposure else { return }
        var state = player.synapseSnapshot
        if state.track?.id == exposure.id {
            state.track = exposure
            if let event = tracker.event(state, type: "favorite") { enqueue([event]) }
        } else {
            state = SynapsePlaybackSnapshot(track: exposure, duration: exposure.durationSeconds)
            if let event = SynapseListeningTracker().event(state, type: "favorite") { enqueue([event]) }
        }
    }

    private func enqueue(_ events: [SynapseEvent]) {
        let valid = events.filter { owns($0.session_id) }
        guard !valid.isEmpty else { return }
        outbox += valid; save(SynapseEventBatch(events: outbox), "outbox"); flush()
    }

    func flush() {
        guard flushTask == nil, let api = client, !resetting, !outbox.isEmpty else { return }
        let generation = epoch
        flushTask = Task { [weak self] in
            defer {
                self?.flushTask = nil
                // An account switch can occur while the previous account's batch is finishing.
                if let self, self.epoch != generation { self.flush() }
            }
            while let self, self.epoch == generation, !self.resetting, !self.outbox.isEmpty {
                let batch = Array(self.outbox.prefix(100))
                do {
                    try await api.synapseEvents(batch)
                    guard self.epoch == generation else { return }
                    self.removeEvents(batch)
                } catch {
                    guard self.epoch == generation else { return }
                    guard Self.stale(error) else { return }
                    for event in batch {
                        guard self.epoch == generation, !self.resetting else { return }
                        do { try await api.synapseEvents([event]) }
                        catch { if !Self.stale(error) { return } }
                        guard self.epoch == generation else { return }
                        self.removeEvents([event])
                    }
                }
            }
        }
    }

    private static func stale(_ error: Error) -> Bool {
        if case APIError.server(let code, _) = error { return [400, 404, 422].contains(code) }
        return false
    }

    private func removeEvents(_ events: [SynapseEvent]) {
        let ids = Set(events.map(\.id)); outbox.removeAll { ids.contains($0.id) }
        save(SynapseEventBatch(events: outbox), "outbox")
    }

    /// App-owned task survives closing Settings; reset waits for in-flight feedback.
    func resetProfile() {
        guard let api = client, !resetting else { return }
        epoch += 1; requestID += 1
        let generation = epoch, pending = flushTask
        mixTask?.cancel(); continuationTask?.cancel(); continuationTask = nil
        tracker = SynapseListeningTracker(); attemptedQueue = nil
        resetting = true; loading = false; error = nil; notice = nil
        resetTask = Task { [weak self] in
            await pending?.value
            guard let self, self.epoch == generation else { return }
            do {
                try await api.resetSynapse()
                guard self.epoch == generation else { return }
                self.sessions.removeAll(); self.outbox.removeAll()
                self.save(SynapseEventBatch(events: []), "outbox")
                self.resetting = false; self.mix = nil
                self.notice = "Профиль Synapse сброшен. Избранное сохранено."
                self.refresh()
            } catch {
                guard self.epoch == generation else { return }
                self.resetting = false; self.error = self.message(error)
            }
        }
    }

    private func message(_ error: Error) -> String {
        if case APIError.server(404, _) = error { return "Synapse недоступен на этом сервере. Обновите сервер Core Player." }
        return (error as? LocalizedError)?.errorDescription ?? "Не удалось подключиться к Synapse. Повторите попытку."
    }

    private func persist(_ value: Bool, _ key: String) {
        guard binding != nil else { return }; defaults.set(value, forKey: prefix + key)
    }
    private func save<T: Encodable>(_ value: T, _ key: String) {
        guard binding != nil, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: prefix + key)
    }
    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: prefix + key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
