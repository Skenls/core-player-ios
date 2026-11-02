import AVFoundation

final class PlayerEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemStallObserver: NSKeyValueObservation?

    var onTime: ((Double, Double) -> Void)?
    var onEnded: (() -> Void)?
    var onError: ((Error?) -> Void)?
    var onReady: ((Double) -> Void)?

    private static let stallKickDelay: Double = 8

    private var stallKickWork: DispatchWorkItem?

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
            self.onTime?(position, duration)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem else { return }
            self.onEnded?()
        }
    }

    func load(url: URL) {
        player.pause()
        itemStatusObserver?.invalidate()
        itemStallObserver?.invalidate()
        cancelStallKick()

        let item = AVPlayerItem(url: url)
        // Buffer well ahead so short server hiccups do not interrupt playback.
        item.preferredForwardBufferDuration = 30
        player.replaceCurrentItem(with: item)

        itemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    self?.onReady?(seconds.isFinite ? max(0, seconds) : 0)
                case .failed:
                    self?.onError?(item.error)
                default:
                    break
                }
            }
        }

        // Network-hiccup watchdog: if AVPlayer stays in "waiting to play at
        // specified rate" for 8s (minimize stalling), nudge it back to life.
        itemStallObserver = item.observe(\.timeControlStatus, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleTimeControl(item.timeControlStatus)
            }
        }
    }

    private func handleTimeControl(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .waitingToPlayAtSpecifiedRate:
            scheduleStallKick()
        case .playing, .paused:
            cancelStallKick()
        @unknown default:
            break
        }
    }

    private func scheduleStallKick() {
        guard stallKickWork == nil, player.currentItem != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
               self.player.currentItem?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                self.player.pause()
                self.player.play()
                // Second strike: schedule one more kick in case the first didn't help.
                self.stallKickWork = nil
                self.scheduleStallKick()
            }
        }
        stallKickWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stallKickDelay, execute: work)
    }

    private func cancelStallKick() {
        stallKickWork?.cancel()
        stallKickWork = nil
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to time: Double) {
        let target = CMTime(seconds: max(0, time), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        player.pause()
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemStallObserver?.invalidate()
        itemStallObserver = nil
        cancelStallKick()
        player.replaceCurrentItem(with: nil)
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
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
        itemStatusObserver?.invalidate()
        itemStallObserver?.invalidate()
        cancelStallKick()
    }
}
