import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerStore
    @EnvironmentObject var settings: SettingsStore
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 10) {
                CoverView(coverID: track.coverArt, size: 42, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(track.displayArtist).font(.system(size: 11)).foregroundColor(CoreColors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold)).frame(width: 34, height: 34)
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold)).frame(width: 30, height: 34)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Group {
                    if settings.adaptiveBubble, track.coverArt != nil {
                        BlurredCoverBackground(coverID: track.coverArt).opacity(0.92)
                    } else {
                        CoreColors.surface
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(Rectangle().frame(height: 2).foregroundColor(CoreColors.accent), alignment: .bottom)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { showNowPlaying = true }
        }
    }
}
