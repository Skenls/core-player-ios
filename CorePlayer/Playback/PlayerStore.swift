import Foundation
import UIKit

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var currentTrack: TrackDto?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var sourceTitle: String?
    @Published private(set) var queueCount = 0

    @Published var repeatMode: RepeatMode = .off {
        didSet { queue.repeatMode = repeatMode }
    }
    @Published var isShuffled: Bool = false {
        didSet { queue.isShuffled = isShuffled }
    }

    private var queue = QueueState()
    private let engine = PlayerEngine()
    private let api: APIClient
    private let settings: SettingsStore
    private let cache: TrackCache
    private let recent: RecentStore
    private let audioSession = AudioSessionManager()
    private let nowPlaying = NowPlayingCenter()

    private var retryWork: DispatchWorkItem?
    private var didRetry = false
    private var wasPlayingBeforeInterruption = false
    private var lastNowPlayingUpdate = Date.distantPast
    private var configured = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentCodec: AudioCodec = .auto
    private var currentIsLocal = false
    private var streamOffset = 0.0
    private var pendingSeekCompletions: [() -> Void] = []
    private var prefetchedNextForTrackID: String?

    init(
        api: APIClient,
        settings: SettingsStore,
        cache: TrackCache,
        recent: RecentStore
    ) {
        self.api = api
        self.settings = settings
        self.cache = cache
        self.recent = recent
        setup()
    }

    private func setup() {
        guard !configured else { return }
        configured = true

        engine.onTime = { [weak self] time, engineDuration in
            self?.handleTime(time, engineDuration: engineDuration)
        }
        engine.onEnded = { [weak self] in
            self?.handleEnded()
        }
        engine.onError = { [weak self] error in
            self?.handleError(error)
        }
        engine.onReady = { [weak self] engineDuration in
            guard let self else { return }
            self.isLoading = false
            if self.streamOffset == 0, engineDuration > 0 {
                self.duration = engineDuration
            }
            self.endTransitionBackgroundTask()
            self.updateNowPlaying(force: true)
            self.finishPendingSeeks()
        }
        engine.onPlaybackLikelyToKeepUp = { [weak self] in
            self?.prefetchNextTrack()
        }

        nowPlaying.setup(
            play: { [weak self] in
                DispatchQueue.main.async { self?.play() }
            },
            pause: { [weak self] in
                DispatchQueue.main.async { self?.pause() }
            },
            toggle: { [weak self] in
                DispatchQueue.main.async { self?.togglePlayPause() }
            },
            next: { [weak self] in
                DispatchQueue.main.async { self?.next() }
            },
            previous: { [weak self] in
                DispatchQueue.main.async { self?.previous() }
            },
            seek: { [weak self] time in
                DispatchQueue.main.async { self?.seek(time) }
            }
        )

        audioSession.onInterruptionBegan = { [weak self] in
            self?.handleInterruptionBegan()
        }
        audioSession.onInterruptionEnded = { [weak self] shouldResume in
            self?.handleInterruptionEnded(shouldResume: shouldResume)
        }
        audioSession.onRouteChangePause = { [weak self] in
            self?.pause()
        }

        NotificationCenter.default.addObserver(
            forName: .corePlayerDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    // MARK: - Public controls

    func play(track: TrackDto, in tracks: [TrackDto]? = nil, source: String? = nil) {
        let list: [TrackDto]
        if let tracks, !tracks.isEmpty {
            list = tracks
        } else if queue.tracks.contains(where: { $0.id == track.id }) {
            list = queue.tracks
        } else {
            list = [track]
        }

        let start = list.firstIndex(where: { $0.id == track.id }) ?? 0
        queue.setQueue(list, startAt: start)
        queueCount = list.count
        sourceTitle = source
        loadCurrent()
    }

    func playAll(_ tracks: [TrackDto], source: String, shuffled: Bool = false) {
        guard !tracks.isEmpty else { return }
        isShuffled = shuffled
        let first = shuffled ? (tracks.randomElement() ?? tracks[0]) : tracks[0]
        play(track: first, in: tracks, source: source)
    }

    func togglePlayPause() {
        guard currentTrack != nil else {
            if let first = recent.tracks.first {
                play(track: first)
            }
            return
        }

        if isPlaying {
            pause()
        } else {
            if duration > 0 && position >= duration - 0.25 {
                seek(0)
            }
            audioSession.activate()
            engine.play()
            isPlaying = true
            updateNowPlaying(force: true)
        }
    }

    func play() {
        guard currentTrack != nil else { return }
        audioSession.activate()
        engine.play()
        isPlaying = true
        updateNowPlaying(force: true)
    }

    func pause() {
        engine.pause()
        isPlaying = false
        updateNowPlaying(force: true)
    }

    func next() {
        guard let index = queue.nextIndex() else {
            seek(0)
            pause()
            return
        }
        queue.setIndex(index)
        loadCurrent()
    }

    func previous() {
        if position > 3 {
            seek(0)
            return
        }

        guard let index = queue.previousIndex() else {
            seek(0)
            return
        }
        queue.setIndex(index)
        loadCurrent()
    }

    func seek(_ time: Double, completion: (() -> Void)? = nil) {
        let upper = duration > 0 ? duration : time
        let clamped = min(max(0, time), upper)
        switch PlaybackSeekRouter.route(time: clamped, isLocal: currentIsLocal) {
        case .avPlayer(let target):
            engine.seek(to: target) { [weak self] actual in
                self?.position = actual
                self?.updateNowPlaying(force: true)
                completion?()
            }
            position = target
        case .offsetStream(let offset):
            restartOffsetStream(at: offset, completion: completion)
            return
        }
        updateNowPlaying(force: true)
    }

    func toggleShuffle() {
        isShuffled.toggle()
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
    }

    func clearError() {
        errorMessage = nil
    }

    func stop() {
        endTransitionBackgroundTask()
        retryWork?.cancel()
        retryWork = nil
        engine.stop()
        prefetchedNextForTrackID = nil
        streamOffset = 0
        currentIsLocal = false
        finishPendingSeeks()
        queue = QueueState()
        queueCount = 0
        currentTrack = nil
        isPlaying = false
        position = 0
        duration = 0
        isLoading = false
        sourceTitle = nil
        errorMessage = nil
        nowPlaying.clear()
        audioSession.deactivate()
    }

    // MARK: - Background Transition Safety

    private func beginTransitionBackgroundTask() {
        endTransitionBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TrackTransition") { [weak self] in
            self?.endTransitionBackgroundTask()
        }
    }

    private func endTransitionBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Loading

    private func loadCurrent(isRetry: Bool = false) {
        guard let track = queue.current else {
            stop()
            return
        }

        beginTransitionBackgroundTask()
        retryWork?.cancel()
        retryWork = nil
        if !isRetry {
            didRetry = false
        }

        currentTrack = track
        position = 0
        streamOffset = 0
        duration = max(0, Double(track.duration ?? 0))
        errorMessage = nil
        isLoading = true

        let codec = resolvedCodec(for: track)
        currentCodec = codec
        prefetchedNextForTrackID = nil

        let url: URL
        if let local = cache.localURL(trackID: track.id, codec: codec) {
            url = local
            currentIsLocal = true
        } else if let remote = api.streamURL(trackID: track.id, codec: codec) {
            url = remote
            currentIsLocal = false
        } else {
            endTransitionBackgroundTask()
            isLoading = false
            errorMessage = "Не удалось построить ссылку на трек"
            return
        }

        audioSession.activate()
        engine.load(url: url, autoPlay: true)
        isPlaying = true

        recent.add(track)
        updateNowPlaying(force: true)
    }

    private func restartOffsetStream(at offset: Int, completion: (() -> Void)?) {
        guard let track = currentTrack else {
            completion?()
            return
        }
        let timeOffset = offset > 0 ? offset : nil
        let codec = PlaybackSeekRouter.offsetCodec(requested: currentCodec, sourceSuffix: track.suffix)
        guard let url = api.streamURL(trackID: track.id, codec: codec, timeOffset: timeOffset) else {
            completion?()
            errorMessage = "Не удалось построить ссылку на трек"
            return
        }

        if let completion {
            pendingSeekCompletions.append(completion)
        }
        retryWork?.cancel()
        retryWork = nil
        beginTransitionBackgroundTask()
        streamOffset = Double(offset)
        position = Double(offset)
        isLoading = true
        errorMessage = nil
        audioSession.activate()
        engine.load(url: url, autoPlay: true, startOffset: Double(offset))
        isPlaying = true
        updateNowPlaying(force: true)
    }

    private func finishPendingSeeks() {
        let pending = pendingSeekCompletions
        pendingSeekCompletions.removeAll()
        pending.forEach { $0() }
    }

    /// FLAC passthrough avoids ffmpeg for native FLAC and impossible lossy-to-FLAC transcodes.
    private func resolvedCodec(for track: TrackDto) -> AudioCodec {
        let codec = settings.codec
        guard codec == .flac, track.isLossy || track.isFlac else { return codec }
        return .auto
    }

    /// Start the next download only after AVPlayer reports enough current buffer.
    // shortcut: prefetch waits for a healthy current buffer; if stalls persist on slow networks,
    // replace this with one AVAssetResourceLoader tee that streams and caches the current track.
    private func prefetchNextTrack() {
        guard let track = currentTrack,
              prefetchedNextForTrackID != track.id,
              let nextTrack = queue.nextTrack,
              nextTrack.id != track.id else { return }
        let nextCodec = resolvedCodec(for: nextTrack)
        guard PlaybackPrefetchPolicy.allows(
            currentIsRawFlac: track.isFlac && currentCodec == .auto,
            nextIsRawFlac: nextTrack.isFlac && nextCodec == .auto
        ) else { return }
        prefetchedNextForTrackID = track.id
        cache.prefetch(
            track: nextTrack,
            codec: nextCodec,
            baseURL: api.baseURL,
            sessionID: api.sessionID
        )
    }

    private func playIndex(_ index: Int) {
        queue.setIndex(index)
        loadCurrent()
    }

    // MARK: - Engine callbacks

    private func handleTime(_ time: Double, engineDuration: Double) {
        position = time
        if streamOffset == 0, engineDuration > 0 {
            duration = engineDuration
        }
        if isLoading {
            isLoading = false
        }

        if Date().timeIntervalSince(lastNowPlayingUpdate) >= 1 {
            updateNowPlaying(force: false)
        }
    }

    private func handleEnded() {
        if repeatMode == .one {
            seek(0)
            engine.play()
            isPlaying = true
            return
        }

        guard let index = queue.nextIndex() else {
            isPlaying = false
            position = duration
            updateNowPlaying(force: true)
            return
        }

        queue.setIndex(index)
        loadCurrent()
    }

    private func handleError(_ error: Error?) {
        // Fallback to original quality (.auto) if transcoding or specific codec failed
        if currentCodec != .auto {
            currentCodec = .auto
            loadCurrent(isRetry: true)
            return
        }

        guard !didRetry else {
            endTransitionBackgroundTask()
            isLoading = false
            isPlaying = false
            errorMessage = "Не удалось воспроизвести трек. Проверьте сервер и сеть."
            finishPendingSeeks()
            return
        }

        didRetry = true
        retryWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.currentTrack != nil else { return }
            self.loadCurrent(isRetry: true)
        }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: - Interruptions

    private func handleInterruptionBegan() {
        wasPlayingBeforeInterruption = isPlaying
        if isPlaying {
            pause()
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        guard shouldResume, wasPlayingBeforeInterruption else { return }
        play()
    }

    // MARK: - Now Playing

    private func updateNowPlaying(force: Bool) {
        guard let track = currentTrack else {
            nowPlaying.clear()
            return
        }

        if !force && Date().timeIntervalSince(lastNowPlayingUpdate) < 1 {
            return
        }
        lastNowPlayingUpdate = Date()

        nowPlaying.update(
            track: track,
            position: position,
            duration: duration,
            isPlaying: isPlaying,
            artworkURL: api.coverURL(coverID: track.coverArt, size: 1200)
        )
    }
}
