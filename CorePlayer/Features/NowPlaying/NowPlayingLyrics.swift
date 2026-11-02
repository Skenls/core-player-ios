import SwiftUI

extension NowPlayingView {
    // Synchronized lyrics fetching for the current track.
    func loadLyrics() {
        guard let track = player.currentTrack else {
            lyrics = nil; lines = []; lyricsError = nil; lyricsLoading = false
            return
        }
        lyrics = nil; lines = []; lyricsError = nil; lyricsLoading = true
        Task {
            do {
                let response = try await api.lyrics(track: track)
                guard player.currentTrack?.id == track.id else { return }
                lyrics = response
                if let raw = response.text, !raw.isEmpty { lines = LRCParser.parse(raw) }
                lyricsLoading = false
            } catch {
                guard player.currentTrack?.id == track.id else { return }
                lyricsError = error.localizedDescription
                lyricsLoading = false
            }
        }
    }
}
