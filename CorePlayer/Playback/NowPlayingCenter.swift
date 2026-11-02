import MediaPlayer
import UIKit

final class NowPlayingCenter {
    private var artworkTask: Task<Void, Never>?
    private var artworkKey: String?
    private var artwork: MPMediaItemArtwork?

    func setup(
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        toggle: @escaping () -> Void,
        next: @escaping () -> Void,
        previous: @escaping () -> Void,
        seek: @escaping (Double) -> Void
    ) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            toggle()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            next()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            previous()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            seek(event.positionTime)
            return .success
        }

        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    func update(
        track: TrackDto?,
        position: Double,
        duration: Double,
        isPlaying: Bool,
        artworkURL: URL?
    ) {
        guard let track else {
            clear()
            return
        }

        loadArtworkIfNeeded(url: artworkURL)

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPMediaItemPropertyAlbumTitle: track.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        artworkTask?.cancel()
        artworkTask = nil
        artworkKey = nil
        artwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func loadArtworkIfNeeded(url: URL?) {
        guard let url else { return }
        let key = url.absoluteString
        guard artworkKey != key else { return }

        artworkKey = key
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            let image = await ImageCache.shared.image(for: url)
            guard !Task.isCancelled, let self, let image else { return }
            let mediaArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                self.artwork = mediaArtwork
                if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                    info[MPMediaItemPropertyArtwork] = mediaArtwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
    }
}
