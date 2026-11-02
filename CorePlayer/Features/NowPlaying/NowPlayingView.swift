import SwiftUI

// Full-screen Now Playing, matching the Android NowPlayingBottomSheet layout:
// blurred cover background, artwork <-> lyrics crossfade, info + scrubber + controls.

struct NowPlayingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.api) var api
    @EnvironmentObject var player: PlayerStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var favorites: FavoritesStore

    @State var showLyrics = false
    @State var lyrics: LyricsResponse?
    @State var lines: [LyricLine] = []
    @State var lyricsLoading = false
    @State var lyricsError: String?
    @State var showAddToPlaylist = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                background
                if wide { wideLayout(geo) } else { portraitLayout(geo) }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadLyrics() }
        .onChange(of: player.currentTrack?.id) { _ in
            showLyrics = false
            loadLyrics()
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let track = player.currentTrack {
                AddToPlaylistSheet(track: track)
            }
        }
    }

    var background: some View {
        ZStack {
            if settings.amoled {
                Color.black.ignoresSafeArea()
            } else if settings.background == .cover, let cover = player.currentTrack?.coverArt {
                BlurredCoverBackground(coverID: cover).ignoresSafeArea()
                (settings.amoled ? Color.black : CoreColors.background)
                    .opacity(0.82)
                    .ignoresSafeArea()
            } else {
                (settings.amoled ? Color.black : CoreColors.background)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Top bar

    var topBar: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(CoreColors.textPrimary)
            }
            .buttonStyle(.plain)
            .frame(width: 44)

            Spacer()

            VStack(spacing: 2) {
                Text("ИГРАЕТ ИЗ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundColor(CoreColors.textSecondary)
                Text(sourceLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) { showLyrics.toggle() }
            } label: {
                Image(systemName: showLyrics ? "text.alignleft" : "text.alignleft")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(showLyrics ? .white : CoreColors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
    }

    private var sourceLabel: String {
        if let album = player.currentTrack?.displayAlbum, !album.isEmpty {
            return "Альбом «\(album)»"
        }
        return "Медиатека"
    }

    // MARK: - Cover / lyrics area

    var coverArea: some View {
        GeometryReader { geo in
            let side = max(120, min(geo.size.width * 0.85, geo.size.height * 0.86))
            ZStack {
                if showLyrics {
                    SyncedLyricsView(
                        lines: lines,
                        position: player.position,
                        onSeek: { player.seek($0) },
                        isLoading: lyricsLoading,
                        errorMessage: lyricsError ?? (lyrics == nil ? nil : "Текст песни недоступен"),
                        onRetry: { loadLyrics() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    cover(side: side)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showLyrics)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cover(side: CGFloat) -> some View {
        CoverView(
            coverID: player.currentTrack?.coverArt,
            size: side,
            cornerRadius: 24,
            pixelSize: 1200
        )
        .background(CoreColors.surfaceVariant)
        .shadow(color: Color.black.opacity(0.8), radius: 22, x: 0, y: 12)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) { showLyrics = true }
        }
    }

    // MARK: - Track info

    var titles: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "Нет активного трека")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(player.currentTrack?.displayArtist ?? "Неизвестный исполнитель")
                    .font(.system(size: 16))
                    .foregroundColor(CoreColors.textSecondary)
                    .lineLimit(1)
                if let error = player.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let track = player.currentTrack {
                    Task { await favorites.toggle(track: track) }
                }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(favorite ? CoreColors.favorite : .white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    var favorite: Bool {
        guard let track = player.currentTrack else { return false }
        return favorites.isFavorite(track)
    }

    // MARK: - Layouts

    func portraitLayout(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar
            coverArea
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Spacer(minLength: 16)
                .frame(maxHeight: 24)

            VStack(spacing: 14) {
                titles
                NowPlayingScrubber()
                NowPlayingControls()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func wideLayout(_ geo: GeometryProxy) -> some View {
        HStack(spacing: 26) {
            coverArea
                .padding(.horizontal, 24)

            VStack(spacing: 18) {
                topBar
                titles
                NowPlayingScrubber()
                NowPlayingControls()
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width * 0.46)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
