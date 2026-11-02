import SwiftUI

struct TrackRow: View {
    let track: TrackDto
    var number: Int? = nil
    var showCover: Bool = true
    var showDuration: Bool = false
    let onPlay: () -> Void

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var player: PlayerStore
    @State private var showAddToPlaylist = false

    private var isCurrent: Bool {
        player.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isCurrent ? CoreColors.accent : CoreColors.textSecondary)
                    .frame(width: 24, alignment: .trailing)
            }

            if showCover {
                CoverView(
                    coverID: track.coverArt,
                    size: 48,
                    cornerRadius: 9,
                    pixelSize: 300
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrent ? CoreColors.accent : CoreColors.textPrimary)
                    .lineLimit(1)
                Text(track.displayArtist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CoreColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CoreColors.accent)
            } else if showDuration {
                Text(Formatters.duration(track.durationSeconds))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(CoreColors.textSecondary)
            }

            Button {
                Task { await favorites.toggle(track: track) }
            } label: {
                Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(favorites.isFavorite(track) ? CoreColors.accent : CoreColors.textSecondary.opacity(0.8))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onPlay()
                } label: {
                    Label("Играть", systemImage: "play.fill")
                }
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Добавить в плейлист", systemImage: "text.badge.plus")
                }
                Button {
                    Task { await favorites.toggle(track: track) }
                } label: {
                    Label(
                        favorites.isFavorite(track) ? "Убрать из избранного" : "В избранное",
                        systemImage: favorites.isFavorite(track) ? "heart.slash" : "heart"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CoreColors.textSecondary.opacity(0.8))
                    .frame(width: 26, height: 30)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Играть", systemImage: "play.fill")
            }
            Button {
                showAddToPlaylist = true
            } label: {
                Label("Добавить в плейлист", systemImage: "text.badge.plus")
            }
            Button {
                Task { await favorites.toggle(track: track) }
            } label: {
                Label(
                    favorites.isFavorite(track) ? "Убрать из избранного" : "В избранное",
                    systemImage: favorites.isFavorite(track) ? "heart.slash" : "heart"
                )
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: track)
        }
    }
}

struct AddToPlaylistSheet: View {
    let track: TrackDto

    @Environment(\.api) private var api
    @Environment(\.presentationMode) private var presentationMode
    @State private var playlists: [PlaylistDto] = []
    @State private var isLoading = true
    @State private var addingID: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                CoreColors.background.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CoreColors.accent))
                } else if let errorMessage {
                    ErrorStateView(title: "Не удалось загрузить", message: errorMessage) {
                        Task { await load() }
                    }
                } else if playlists.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "Нет плейлистов",
                        subtitle: "Создайте плейлист в разделе «Медиатека»."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(playlists) { playlist in
                                Button {
                                    Task { await add(to: playlist) }
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverView(
                                            coverID: playlist.coverArt ?? playlist.id,
                                            size: 44,
                                            cornerRadius: 8,
                                            pixelSize: 300
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(CoreColors.textPrimary)
                                                .lineLimit(1)
                                            Text(Formatters.trackCount(playlist.songCount ?? 0))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(CoreColors.textSecondary)
                                        }
                                        Spacer()
                                        if addingID == playlist.id {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: CoreColors.accent))
                                        } else {
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(CoreColors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("В плейлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(CoreColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            playlists = try await api.playlists()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func add(to playlist: PlaylistDto) async {
        guard addingID == nil else { return }
        addingID = playlist.id
        do {
            try await api.addTrack(playlistID: playlist.id, trackID: track.id)
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        addingID = nil
    }
}

struct BlurredCoverBackground: View {
    let coverID: String?

    @Environment(\.api) private var api

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let url = api.coverURL(coverID: coverID, size: 600) {
                    RemoteImage(url: url)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 42)
                        .scaleEffect(1.25)
                        .opacity(0.55)
                }
                LinearGradient(
                    colors: [
                        CoreColors.background.opacity(0.35),
                        CoreColors.background.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }
}
