import AVFoundation

final class PlayerEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?

    var onTime: ((Double, Double) -> Void)?
    var onEnded: (() -> Void)?
    var onError: ((Error?) -> Void)?
    var onReady: ((Double) -> Void)?

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

        let item = AVPlayerItem(url: url)
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
    }
}
