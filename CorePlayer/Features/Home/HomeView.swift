import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var randomTracks: [TrackDto] = []
    @Published private(set) var favoriteTracks: [TrackDto] = []
    @Published private(set) var playlists: [PlaylistDto] = []
    @Published private(set) var artists: [ArtistDto] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(api: APIClient, force: Bool = false) async {
        if isLoading { return }
        if !force && !randomTracks.isEmpty { return }
        isLoading = true
        errorMessage = nil
        var firstError: String?

        do {
            randomTracks = try await api.randomTracks(size: 20)
        } catch {
            firstError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        do {
            favoriteTracks = try await api.favoriteTracks()
        } catch {
            if firstError == nil { firstError = (error as? LocalizedError)?.errorDescription }
        }

        do {
            playlists = try await api.playlists()
        } catch {
            if firstError == nil { firstError = (error as? LocalizedError)?.errorDescription }
        }

        do {
            artists = try await api.artists()
        } catch {
            if firstError == nil { firstError = (error as? LocalizedError)?.errorDescription }
        }

        if randomTracks.isEmpty && favoriteTracks.isEmpty && playlists.isEmpty && artists.isEmpty {
            errorMessage = firstError ?? "Не удалось загрузить библиотеку"
        }
        isLoading = false
    }
}

struct HomeView: View {
    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var recent: RecentStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: SettingsStore

    @StateObject private var vm = HomeViewModel()
    @State private var showSettings = false

    private var recentTracks: [TrackDto] {
        recent.tracks.isEmpty ? vm.randomTracks : recent.tracks
    }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .padding(.top, 8)

                    if vm.isLoading && recentTracks.isEmpty && vm.playlists.isEmpty {
                        LoadingView()
                            .padding(.top, 80)
                    } else if let error = vm.errorMessage, recentTracks.isEmpty, vm.playlists.isEmpty {
                        ErrorStateView(message: error) {
                            Task { await vm.load(api: api, force: true) }
                        }
                        .padding(.top, 60)
                    } else {
                        recentSection
                        favoritesBanner
                        playlistsSection
                        artistsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .refreshable {
                await vm.load(api: api, force: true)
                await favorites.reload()
            }
        }
        .navigationBarHidden(true)
        .task {
            await vm.load(api: api)
            await favorites.reload()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var background: some View {
        (settings.amoled ? Color.black : CoreColors.background)
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    Text("core")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .offset(y: 8)
                }
                Text("ТВОЙ МУЗЫКАЛЬНЫЙ СЕРВЕР")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.2)
                    .foregroundColor(CoreColors.textSecondary)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(CoreColors.textSecondary)
                    .frame(width: 42, height: 42)
                    .background(CoreColors.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CoreColors.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Недавние")

            if recentTracks.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "Пока тихо",
                    subtitle: "Запустите первый трек — он появится здесь."
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(recentTracks.prefix(8)) { track in
                        RecentCard(track: track) {
                            player.play(
                                track: track,
                                in: Array(recentTracks.prefix(8)),
                                source: "Недавние"
                            )
                        }
                    }
                }
            }
        }
    }

    private var favoritesBanner: some View {
        FavoriteBanner(
            count: vm.favoriteTracks.count,
            coverArt: vm.favoriteTracks.first?.coverArt,
            onPlay: {
                guard !vm.favoriteTracks.isEmpty else { return }
                player.playAll(vm.favoriteTracks, source: "Избранное")
            }
        )
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Плейлисты")

            if vm.playlists.isEmpty {
                Text("Плейлистов пока нет")
                    .font(.system(size: 13))
                    .foregroundColor(CoreColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(vm.playlists) { playlist in
                            NavigationLink(
                                destination: PlaylistDetailView(
                                    playlistID: playlist.id,
                                    initialTitle: playlist.name
                                )
                            ) {
                                PlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Исполнители")

            if vm.artists.isEmpty {
                Text("Исполнители не найдены")
                    .font(.system(size: 13))
                    .foregroundColor(CoreColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(vm.artists) { artist in
                            NavigationLink(
                                destination: ArtistDetailView(
                                    artistID: artist.id,
                                    initialTitle: artist.name
                                )
                            ) {
                                ArtistCard(artist: artist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
