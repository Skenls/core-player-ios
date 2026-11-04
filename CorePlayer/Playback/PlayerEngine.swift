import AVFoundation

final class PlayerEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemLikelyObserver: NSKeyValueObservation?
    private var itemBufferEmptyObserver: NSKeyValueObservation?
    private var stallObserver: NSObjectProtocol?
    private var userWantsPlayback = false
    private var playbackOffset = 0.0
    private var didNotifyPlaybackHealthy = false
    var onTime: ((Double, Double) -> Void)?
    var onEnded: (() -> Void)?
    var onError: ((Error?) -> Void)?
    var onReady: ((Double) -> Void)?
    var onPlaybackLikelyToKeepUp: (() -> Void)?

    init() {
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let position = time.seconds.isFinite ? max(0, time.seconds) : 0
            let itemDuration = self.player.currentItem?.duration.seconds ?? 0
            let duration = itemDuration.isFinite ? max(0, itemDuration) : 0
            self.onTime?(position + self.playbackOffset, duration)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem else { return }

            let currentTime = self.player.currentTime().seconds
            let duration = item.duration.seconds
            // Guard against premature lock-screen cutoff caused by network chunk starvation
            if duration.isFinite && duration > 2.0 && (duration - currentTime) > 2.0 {
                if self.userWantsPlayback && self.player.rate == 0 {
                    self.player.play()
                }
                return
            }
            self.onEnded?()
        }

        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem else { return }
            // Playback stalled: re-check and auto-resume once data is buffered, ONLY if user wanted playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.userWantsPlayback && self.player.rate == 0 && self.player.error == nil {
                    self.player.play()
                }
            }
        }
    }

    func load(url: URL, autoPlay: Bool = true, startOffset: Double = 0) {
        userWantsPlayback = autoPlay
        playbackOffset = max(0, startOffset)
        cleanupItemObservers()

        let item = AVPlayerItem(url: url)
        // AVPlayer chooses the buffer size; reserving 30s up front delayed startup on transcoded streams.
        item.preferredForwardBufferDuration = 0
        didNotifyPlaybackHealthy = false
        // Directly replace current item without clearing to nil, preventing iOS from killing background audio session
        player.replaceCurrentItem(with: item)

        itemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    self?.onReady?(seconds.isFinite ? max(0, seconds) : 0)
                    self?.notifyPlaybackHealthyIfNeeded(item)
                    if self?.userWantsPlayback == true && self?.player.rate == 0 {
                        self?.player.play()
                    }
                case .failed:
                    self?.onError?(item.error)
                default:
                    break
                }
            }
        }

        itemLikelyObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notifyPlaybackHealthyIfNeeded(item)
                if self.userWantsPlayback && item.isPlaybackLikelyToKeepUp && self.player.rate == 0 && self.player.error == nil {
                    self.player.play()
                }
            }
        }

        itemBufferEmptyObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.userWantsPlayback && !item.isPlaybackBufferEmpty && self.player.rate == 0 && self.player.error == nil {
                    self.player.play()
                }
            }
        }
    }

    private func cleanupItemObservers() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemLikelyObserver?.invalidate()
        itemLikelyObserver = nil
        itemBufferEmptyObserver?.invalidate()
        itemBufferEmptyObserver = nil
    }

    func play() {
        userWantsPlayback = true
        player.play()
    }

    func pause() {
        userWantsPlayback = false
        player.pause()
    }

    private func notifyPlaybackHealthyIfNeeded(_ item: AVPlayerItem) {
        guard !didNotifyPlaybackHealthy,
              item === player.currentItem,
              item.status == .readyToPlay,
              item.isPlaybackLikelyToKeepUp else { return }
        didNotifyPlaybackHealthy = true
        onPlaybackLikelyToKeepUp?()
    }

    func seek(to time: Double, completion: ((Double) -> Void)? = nil) {
        let relative = max(0, time - playbackOffset)
        let target = CMTime(seconds: relative, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    completion?(time)
                    return
                }
                if self.userWantsPlayback && self.player.rate == 0 && self.player.error == nil {
                    self.player.play()
                }
                let actual = self.player.currentTime().seconds
                completion?(actual.isFinite ? actual + self.playbackOffset : time)
            }
        }
    }

    func stop() {
        userWantsPlayback = false
        playbackOffset = 0
        player.pause()
        cleanupItemObservers()
        player.replaceCurrentItem(with: nil)
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) + playbackOffset : playbackOffset
    }

    var duration: Double {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isFinite ? max(0, seconds) : 0
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
        }
        cleanupItemObservers()
    }
}
