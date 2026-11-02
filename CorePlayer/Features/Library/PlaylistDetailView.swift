import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: String
    let initialTitle: String
    @Environment(\.api) private var api
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var player: PlayerStore
    @State private var playlist: PlaylistWithSongsDto?
    @State private var tracks: [TrackDto] = []
    @State private var error: String?

    var body: some View {
        Group {
            if let playlist = playlist {
                List {
                    ForEach(tracks) { track in
                        Button {
                            player.play(track: track, in: tracks, source: playlist.name)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(track.title)
                                Text(track.displayArtist).font(.caption)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await remove(track) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        tracks.move(fromOffsets: from, toOffset: to)
                        Task { try? await api.reorderPlaylist(id: playlistID, trackIDs: tracks.map(\.id)) }
                    }
                }
            } else if let error = error {
                ErrorStateView(message: error) { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(initialTitle)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        try? await api.deletePlaylist(id: playlistID)
                        presentationMode.wrappedValue.dismiss()
                    }
                } label: {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let detail = try await api.playlistDetail(id: playlistID)
            playlist = detail
            tracks = detail.tracks
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove(_ track: TrackDto) async {
        try? await api.removeTrack(playlistID: playlistID, trackID: track.id)
        await load()
    }
}
