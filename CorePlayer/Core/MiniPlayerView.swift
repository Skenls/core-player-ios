import SwiftUI

// Floating pill mini-player (Android FloatingMiniPlayer port).
// Stadium capsule above the tab bar; play button with progress ring, heart,
// horizontal swipe to skip, tap / swipe-up to open the player.

struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerStore
    @EnvironmentObject var favorites: FavoritesStore
    @Environment(\.api) private var api
    @EnvironmentObject var settings: SettingsStore
    let openPlayer: () -> Void

    @State private var palette = AdaptivePalette.default
    @State private var dragDirection: Direction?
    @State private var totalDragX: CGFloat = 0
    @State private var totalDragY: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    private enum Direction {
        case horizontal, vertical
    }

    var body: some View {
        if let track = player.currentTrack {
            capsule(track)
        }
    }

    private func capsule(_ track: TrackDto) -> some View {
        let adaptive = settings.adaptiveBubble && track.coverArt != nil
        let gradient = adaptive
            ? LinearGradient(
                colors: [coreHex(0x10141D), palette.primary, palette.secondary],
                startPoint: .leading,
                endPoint: .trailing
            )
            : LinearGradient(
                colors: [coreHex(0x161C26), coreHex(0x162334), coreHex(0x152A3F), coreHex(0x12344E)],
                startPoint: .leading,
                endPoint: .trailing
            )

        return HStack(spacing: 14) {
            ringButton
            Spacer(minLength: 2)
            titles(track)
            heartButton(track)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 5)
        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
        .offset(x: offsetX, y: offsetY)
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .gesture(drag)
        .onTapGesture { openPlayer() }
        .task(id: track.id) { await loadPalette(track) }
        .task(id: track.coverArt) { await loadPalette(track) }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private func loadPalette(_ track: TrackDto) async {
        guard settings.adaptiveBubble, let url = api.coverURL(coverID: track.coverArt, size: 200) else {
            palette = .default
            return
        }
        palette = await PaletteExtractor.shared.palette(for: url)
    }

    // MARK: - Buttons

    private var ringButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .stroke(CoreColors.accent.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress())
                    .stroke(CoreColors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .offset(x: player.isPlaying ? 0 : 1)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
    }

    private func progress() -> Double {
        guard player.duration > 0 else { return 0 }
        return min(1, max(0, player.position / player.duration))
    }

    private func titles(_ track: TrackDto) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(CoreColors.textPrimary)
                .lineLimit(1)
            Text(track.displayArtist)
                .font(.system(size: 13))
                .foregroundColor(coreHex(0x9CA3AF))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id("\(track.id)-\(track.title)")
        .transition(.opacity)
    }

    private func heartButton(_ track: TrackDto) -> some View {
        Button {
            Task { await favorites.toggle(track: track) }
        } label: {
            Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                .font(.system(size: 23, weight: .medium))
                .foregroundColor(favorites.isFavorite(track) ? CoreColors.favorite : .white)
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
    }

    // MARK: - Gestures

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if dragDirection == nil {
                    if abs(dx) > 12, abs(dx) > abs(dy) {
                        dragDirection = .horizontal
                    } else if dy < -12, abs(dy) > abs(dx) {
                        dragDirection = .vertical
                    }
                }
                switch dragDirection {
                case .horizontal:
                    offsetX = min(130, max(-130, dx))
                case .vertical:
                    offsetY = min(0, max(-45, dy))
                case nil:
                    break
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                switch dragDirection {
                case .vertical where dy < -20:
                    openPlayer()
                case .horizontal where dx < -40:
                    player.next()
                case .horizontal where dx > 40:
                    player.previous()
                default:
                    break
                }
                withAnimation(.spring(dampingFraction: 0.8)) {
                    offsetX = 0
                    offsetY = 0
                }
                dragDirection = nil
                totalDragX = 0
                totalDragY = 0
            }
    }
}

private func coreHex(_ value: UInt32) -> Color {
    Color(hex: value)
}
