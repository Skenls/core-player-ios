import SwiftUI

struct BrowseView: View {
    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var vm = BrowseViewModel()
    @State private var tab: BrowseTab = .albums

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                SegmentedPicker(items: BrowseTab.allCases, title: { $0.rawValue }, selection: $tab)
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
        .refreshable { await vm.load(api: api, force: true) }
        .task { await vm.load(api: api) }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Все треки")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Альбомы, исполнители и вся медиатека")
                .font(.system(size: 13))
                .foregroundColor(CoreColors.textSecondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.albums.isEmpty && vm.tracks.isEmpty {
            LoadingView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = vm.errorMessage, vm.albums.isEmpty, vm.tracks.isEmpty {
            ErrorStateView(message: error) {
                Task { await vm.load(api: api, force: true) }
            }
            .padding(.top, 30)
        } else {
            switch tab {
            case .albums:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 16) {
                    ForEach(vm.albums) { album in
                        NavigationLink(
                            destination: AlbumDetailView(albumID: album.id, initialTitle: album.name)
                        ) {
                            AlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .artists:
                LazyVStack(spacing: 2) {
                    ForEach(vm.artists) { artist in
                        NavigationLink(
                            destination: ArtistDetailView(artistID: artist.id, initialTitle: artist.name)
                        ) {
                            HStack(spacing: 12) {
                                CoverView(coverID: artist.effectiveCover, size: 54, cornerRadius: 27)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(artist.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(Formatters.albumCount(artist.albumCount))
                                        .font(.system(size: 12))
                                        .foregroundColor(CoreColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(CoreColors.textSecondary)
                            }
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .tracks:
                LazyVStack(spacing: 0) {
                    ForEach(vm.tracks) { track in
                        TrackRow(track: track) {
                            player.play(track: track, in: vm.tracks, source: "Все треки")
                        }
                        Divider().background(CoreColors.divider)
                    }
                }
            }
        }
    }
}
