import SwiftUI

// Android NowPlayingScrubber + NowPlayingControlsRow port:
// thin white bar with drag/tap seek, white circular play button with black glyph.

struct NowPlayingScrubber: View {
    @EnvironmentObject var player: PlayerStore

    @State private var isSeeking = false
    @State private var seekPosition: Double = 0

    private var displayedPosition: Double {
        isSeeking ? seekPosition : player.position
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let fraction = player.duration > 0 ? min(1, max(0, displayedPosition / player.duration)) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * fraction, height: 3)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .offset(x: min(geo.size.width - 10, max(0, geo.size.width * fraction - 5)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard player.duration > 0 else { return }
                            isSeeking = true
                            seekPosition = min(1, max(0, value.location.x / geo.size.width)) * player.duration
                        }
                        .onEnded { _ in
                            player.seek(seekPosition)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 30)

            HStack {
                Text(Formatters.duration(displayedPosition))
                Spacer()
                Text(Formatters.duration(player.duration))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(CoreColors.textSecondary)
        }
    }
}

struct NowPlayingControls: View {
    @EnvironmentObject var player: PlayerStore

    var body: some View {
        HStack {
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(player.isShuffled ? .white : CoreColors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(CoreColors.textPrimary)
            }
            .buttonStyle(.plain)

            Spacer()

            playButton

            Spacer()

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(CoreColors.textPrimary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                player.cycleRepeat()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(player.repeatMode == .off ? CoreColors.textSecondary : .white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    private var playButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
    }
}
