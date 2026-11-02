import Foundation

enum BrowseTab: String, CaseIterable, Identifiable, Hashable {
    case albums = "Альбомы"
    case artists = "Исполнители"
    case tracks = "Треки"

    var id: String { rawValue }
}

@MainActor
final class BrowseViewModel: ObservableObject {
    @Published private(set) var albums: [AlbumDto] = []
    @Published private(set) var artists: [ArtistDto] = []
    @Published private(set) var tracks: [TrackDto] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(api: APIClient, force: Bool = false) async {
        if isLoading { return }
        if !force && !albums.isEmpty && !artists.isEmpty && !tracks.isEmpty { return }
        isLoading = true
        errorMessage = nil
        var firstError: Error?
        do { albums = try await api.albums() } catch { firstError = error }
        do { artists = try await api.artists() } catch { firstError = firstError ?? error }
        do { tracks = try await api.tracks() } catch { firstError = firstError ?? error }
        if albums.isEmpty && artists.isEmpty && tracks.isEmpty {
            errorMessage = firstError?.localizedDescription ?? "Не удалось загрузить библиотеку"
        }
        isLoading = false
    }
}
