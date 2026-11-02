import SwiftUI

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
        .onChange(of: player.currentTrack?.id) { _ in loadLyrics() }
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
                Color.black.opacity(0.38).ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [CoreColors.background, Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    func portraitLayout(_ geo: GeometryProxy) -> some View {
        let cover = max(120, min(geo.size.width - 72, geo.size.height * 0.38))
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                coverView(size: cover).padding(.top, 6)
                titles.padding(.top, 4)
                progress
                controls.padding(.vertical, 4)
                bottomBar
                if showLyrics {
                    lyricsSection(minHeight: 260)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    func wideLayout(_ geo: GeometryProxy) -> some View {
        let cover = max(140, min(geo.size.width * 0.32, geo.size.height * 0.44))
        return HStack(spacing: 26) {
            VStack(spacing: 12) {
                header
                coverView(size: cover)
                titles
                progress
                controls
                bottomBar
            }
            .frame(width: geo.size.width * 0.44)

            lyricsSection(minHeight: geo.size.height - 80)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
    }

    var header: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(CoreColors.surface.opacity(0.65))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("ИГРАЕТ ИЗ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(CoreColors.textSecondary)
                Text(player.sourceTitle ?? "Core Player")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if let track = player.currentTrack {
                    Task { await favorites.toggle(track: track) }
                }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(favorite ? CoreColors.accent : .white)
                    .frame(width: 40, height: 40)
                    .background(CoreColors.surface.opacity(0.65))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    var favorite: Bool {
        guard let track = player.currentTrack else { return false }
        return favorites.isFavorite(track)
    }

    func coverView(size: CGFloat) -> some View {
        CoverView(
            coverID: player.currentTrack?.coverArt,
            size: size,
            cornerRadius: 20,
            pixelSize: 1200
        )
        .shadow(color: Color.black.opacity(0.55), radius: 26, x: 0, y: 16)
    }

    var titles: some View {
        VStack(spacing: 5) {
            Text(player.currentTrack?.title ?? "Ничего не играет")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(player.currentTrack?.displayArtist ?? " ")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(CoreColors.textSecondary)
                .lineLimit(1)
            if let album = player.currentTrack?.displayAlbum, !album.isEmpty {
                Text(album)
                    .font(.system(size: 12))
                    .foregroundColor(CoreColors.textSecondary.opacity(0.75))
                    .lineLimit(1)
            }
            if let error = player.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
