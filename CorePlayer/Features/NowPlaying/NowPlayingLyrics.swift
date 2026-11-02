import SwiftUI

extension NowPlayingView {
    var bottomBar: some View {
        HStack(spacing: 26) {
            Button { showLyrics.toggle() } label: {
                Label("Текст", systemImage: "text.alignleft")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(showLyrics ? CoreColors.accent : CoreColors.textSecondary)
            }
            Button { showAddToPlaylist = true } label: {
                Label("В плейлист", systemImage: "text.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CoreColors.textSecondary)
            }
            Spacer()
        }
        .buttonStyle(.plain)
    }

    func lyricsSection(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ТЕКСТ ПЕСНИ").font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundColor(CoreColors.textSecondary)
                Spacer()
                if lyricsLoading { ProgressView().scaleEffect(0.7) }
            }
            Group {
                if lyricsLoading && lines.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: minHeight)
                } else if !lines.isEmpty {
                    SyncedLyricsView(lines: lines, position: player.position, onSeek: { player.seek($0) })
                        .frame(minHeight: minHeight)
                } else if let text = lyrics?.text, !text.isEmpty {
                    ScrollView { Text(text).font(.system(size: 15)).lineSpacing(6).foregroundColor(.white.opacity(0.85)) }
                        .frame(minHeight: minHeight)
                } else {
                    Text(lyricsError ?? "Текст песни не найден")
                        .font(.system(size: 13))
                        .foregroundColor(CoreColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: minHeight)
                }
            }
        }
        .padding(14)
        .background(CoreColors.surface.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func loadLyrics() {
        guard let track = player.currentTrack else {
            lyrics = nil; lines = []; lyricsError = nil; lyricsLoading = false
            return
        }
        lyrics = nil; lines = []; lyricsError = nil; lyricsLoading = true
        Task {
            do {
                let response = try await api.lyrics(for: track)
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
