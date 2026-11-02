import SwiftUI

struct AlbumDetailView: View {
    let albumID: String
    let initialTitle: String

    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var album: AlbumWithSongsDto?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var tracks: [TrackDto] { album?.tracks ?? [] }

    var body: some View {
        ScrollView {
            if let album {
                VStack(spacing: 0) {
                    header(album)
                    trackList(album)
                }
            } else if isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                ErrorStateView(
                    title: "Не удалось загрузить альбом",
                    message: errorMessage ?? "Проверьте подключение к серверу",
                    retry: { Task { await load() } }
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
        .background(settings.amoled ? Color.black : CoreColors.background)
        .navigationTitle(album?.name ?? initialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .refreshable { await load() }
        .task { await load() }
    }

    private func header(_ album: AlbumWithSongsDto) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                CoverView(coverID: album.coverArt, size: 150, cornerRadius: 16, pixelSize: 600)
                    .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("АЛЬБОМ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(CoreColors.accent)

                    Text(album.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)

                    Text(album.artist?.isEmpty == false ? album.artist! : "Неизвестный исполнитель")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CoreColors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let year = album.year, year > 0 {
                            Text(String(year))
                        }
                        Text("•")
                        Text(Formatters.trackCount(tracks.count))
                        if !totalDuration.isEmpty {
                            Text("•")
                            Text(totalDuration)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(CoreColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button { playAll() } label: {
                    Label("Слушать", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(CoreGradients.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(tracks.isEmpty)

                Button { playAll(shuffled: true) } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(CoreColors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(tracks.isEmpty)

                Button {
                    Task { await favorites.toggle(albumID: album.id) }
                } label: {
                    Image(systemName: favorites.isAlbumFavorite(album.id) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(favorites.isAlbumFavorite(album.id) ? CoreColors.accent : .white)
                        .frame(width: 48, height: 48)
                        .background(CoreColors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(
            BlurredCoverBackground(coverID: album.coverArt)
                .frame(height: 330)
                .clipped()
        )
    }

    private func trackList(_ album: AlbumWithSongsDto) -> some View {
        VStack(spacing: 0) {
            if tracks.isEmpty {
                EmptyStateView(
                    icon: "music.note",
                    title: "В альбоме нет треков",
                    subtitle: "Попробуйте обновить страницу"
                )
                .padding(.top, 40)
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        number: index + 1,
                        showCover: false,
                        onPlay: { play(track) }
                    )
                    .padding(.horizontal, 16)
                    .background(Color.clear)

                    if index < tracks.count - 1 {
                        Divider()
                            .background(CoreColors.divider)
                            .padding(.leading, 56)
                            .padding(.trailing, 16)
                    }
                }
            }
        }
        .padding(.bottom, 24)
        .background(settings.amoled ? Color.black : CoreColors.background)
    }

    private var totalDuration: String {
        let total = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
        return Formatters.totalDuration(total)
    }

    private func play(_ track: TrackDto) {
        player.play(track: track, in: tracks, source: album?.name)
    }

    private func playAll(shuffled: Bool = false) {
        guard let album else { return }
        player.playAll(tracks, source: album.name, shuffled: shuffled)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            album = try await api.albumDetail(id: albumID)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
