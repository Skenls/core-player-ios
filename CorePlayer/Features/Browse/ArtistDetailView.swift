import SwiftUI

struct ArtistDetailView: View {
    let artistID: String
    let initialTitle: String

    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var artist: ArtistWithAlbumsDto?
    @State private var isLoading = true
    @State private var isStartingPlayback = false
    @State private var errorMessage: String?

    private var albums: [AlbumDto] { artist?.albums ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let artist {
                    header(artist)
                    if albums.isEmpty {
                        EmptyStateView(icon: "square.stack", title: "Нет альбомов", subtitle: "У этого исполнителя пока нет альбомов в медиатеке.")
                            .padding(.top, 30)
                    } else {
                        Text("Альбомы")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(
                                    destination: AlbumDetailView(albumID: album.id, initialTitle: album.name)
                                ) {
                                    AlbumCard(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if isLoading {
                    LoadingView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
        .navigationTitle(artist?.name ?? initialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .refreshable { await load() }
        .task { await load() }
    }

    private func header(_ artist: ArtistWithAlbumsDto) -> some View {
        VStack(spacing: 14) {
            CoverView(coverID: artist.effectiveCover, size: 150, cornerRadius: 75, pixelSize: 600)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
            VStack(spacing: 4) {
                Text(artist.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(Formatters.albumCount(artist.albumCount))
                    .font(.system(size: 13))
                    .foregroundColor(CoreColors.textSecondary)
            }
            HStack(spacing: 12) {
                Button {
                    startPlayback(shuffled: false)
                } label: {
                    HStack(spacing: 7) {
                        if isStartingPlayback {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Слушать")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    startPlayback(shuffled: true)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(CoreColors.surfaceVariant)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            artist = try await api.artistDetail(id: artistID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startPlayback(shuffled: Bool) {
        guard let first = albums.first, !isStartingPlayback else { return }
        isStartingPlayback = true
        Task {
            defer { isStartingPlayback = false }
            do {
                let detail = try await api.albumDetail(id: first.id)
                guard !detail.tracks.isEmpty else { return }
                player.playAll(detail.tracks, source: artist?.name ?? initialTitle, shuffled: shuffled)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
