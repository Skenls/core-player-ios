import Foundation

enum LibraryTab: String, CaseIterable, Identifiable, Hashable {
    case favorites = "Мои треки"
    case playlists = "Плейлисты"

    var id: String { rawValue }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var favoriteTracks: [TrackDto] = []
    @Published private(set) var playlists: [PlaylistDto] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(api: APIClient, force: Bool = false) async {
        if isLoading { return }
        if !force && !favoriteTracks.isEmpty && !playlists.isEmpty { return }
        isLoading = true
        errorMessage = nil
        do { favoriteTracks = try await api.favoriteTracks() } catch { errorMessage = error.localizedDescription }
        do { playlists = try await api.playlists() } catch { errorMessage = errorMessage ?? error.localizedDescription }
        isLoading = false
    }

    func deletePlaylist(id: String, api: APIClient) async {
        do {
            try await api.deletePlaylist(id: id)
            playlists.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
