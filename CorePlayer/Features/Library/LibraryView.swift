import SwiftUI

struct LibraryView: View {
    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var vm = LibraryViewModel()
    @State private var tab: LibraryTab = .favorites
    @State private var showCreate = false
    var body: some View {
        VStack(spacing: 10) {
            Text("Медиатека").font(.system(size: 28, weight: .bold))
            SegmentedPicker(items: LibraryTab.allCases, title: { $0.rawValue }, selection: $tab)
            if let error = vm.errorMessage, vm.favoriteTracks.isEmpty, vm.playlists.isEmpty {
                ErrorStateView(message: error) {
                    Task { await vm.load(api: api, force: true) }
                }
            } else {
                ScrollView {
                    if tab == .favorites { favoriteList } else { playlistList }
                }
            }
        }
        .padding(.horizontal, 12)
        .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await vm.load(api: api) }
        .refreshable { await vm.load(api: api, force: true) }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await vm.load(api: api, force: true) } }) {
            CreatePlaylistSheet()
        }
    }
    @ViewBuilder private var favoriteList: some View {
        if vm.favoriteTracks.isEmpty {
            Text("Нет избранных треков").foregroundColor(CoreColors.textSecondary).padding(30)
        } else {
            HStack {
                Text(Formatters.trackCount(vm.favoriteTracks.count))
                    .font(.system(size: 12))
                    .foregroundColor(CoreColors.textSecondary)
                Spacer()
                Button { player.playAll(vm.favoriteTracks, source: "Избранное") } label: {
                    Image(systemName: "play.fill")
                }
                Button { player.playAll(vm.favoriteTracks, source: "Избранное", shuffled: true) } label: {
                    Image(systemName: "shuffle")
                }
            }
            .padding(.vertical, 4)
            ForEach(vm.favoriteTracks) { track in
                TrackRow(track: track) {
                    player.play(track: track, in: vm.favoriteTracks, source: "Избранное")
                }
            }
        }
    }
    @ViewBuilder private var playlistList: some View {
        Button("Создать плейлист") { showCreate = true }
            .padding(.vertical, 8)
        ForEach(vm.playlists) { playlist in
            NavigationLink(destination: PlaylistDetailView(playlistID: playlist.id, initialTitle: playlist.name)) {
                HStack {
                    CoverView(coverID: playlist.coverArt, size: 48, cornerRadius: 8)
                    VStack(alignment: .leading) {
                        Text(playlist.name)
                        Text(Formatters.trackCount(playlist.songCount)).font(.caption).foregroundColor(CoreColors.textSecondary)
                    }
                    Spacer()
                }.padding(.vertical, 4)
            }.buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    Task { await vm.deletePlaylist(id: playlist.id, api: api) }
                } label: { Label("Удалить", systemImage: "trash") }
            }
        }
    }
}
