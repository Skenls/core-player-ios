import SwiftUI

extension NowPlayingView {
    var progress: some View {
        VStack(spacing: 3) {
            Slider(
                value: Binding(
                    get: { player.position },
                    set: { player.seek($0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .accentColor(CoreColors.accent)
            HStack {
                Text(Formatters.duration(player.position))
                Spacer()
                Text("-" + Formatters.duration(max(0, player.duration - player.position)))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(CoreColors.textSecondary)
        }
    }

    var controls: some View {
        HStack(spacing: 20) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.isShuffled ? CoreColors.accent : CoreColors.textSecondary)
                    .frame(width: 38, height: 38)
            }
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 48, height: 48)
            }
            Button { player.togglePlayPause() } label: { playButton }
            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 48, height: 48)
            }
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.repeatMode == .off ? CoreColors.textSecondary : CoreColors.accent)
                    .frame(width: 38, height: 38)
            }
        }
        .buttonStyle(.plain)
    }
    private var playButton: some View {
        ZStack {
            Circle().fill(CoreGradients.accent)
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .offset(x: player.isPlaying ? 0 : 2)
        }
        .frame(width: 72, height: 72)
        .shadow(color: CoreColors.accent.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}
