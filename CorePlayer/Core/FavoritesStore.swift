import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var trackIDs: Set<String> = []
    @Published private(set) var albumIDs: Set<String> = []

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func isFavorite(_ track: TrackDto) -> Bool {
        trackIDs.contains(track.id) || (track.isFavorite && !trackIDs.contains(track.id))
    }

    func isFavorite(albumID: String) -> Bool {
        albumIDs.contains(albumID)
    }

    func isAlbumFavorite(_ albumID: String) -> Bool {
        albumIDs.contains(albumID)
    }

    func apply(_ ids: FavoritesIdsResponse) {
        trackIDs = Set(ids.trackIDs)
        albumIDs = Set(ids.albumIDs)
    }

    func reload() async {
        do {
            apply(try await api.favoritesIDs())
        } catch {
            // Тихо: избранное не критично для запуска.
        }
    }

    func toggle(track: TrackDto) async {
        let wasFavorite = trackIDs.contains(track.id)
        if wasFavorite {
            trackIDs.remove(track.id)
        } else {
            trackIDs.insert(track.id)
        }

        do {
            let result = try await api.toggleFavorite(id: track.id, type: "track")
            if let result {
                if result {
                    trackIDs.insert(track.id)
                } else {
                    trackIDs.remove(track.id)
                }
            }
        } catch {
            if wasFavorite {
                trackIDs.insert(track.id)
            } else {
                trackIDs.remove(track.id)
            }
        }
    }

    func toggle(albumID: String) async {
        let wasFavorite = albumIDs.contains(albumID)
        if wasFavorite {
            albumIDs.remove(albumID)
        } else {
            albumIDs.insert(albumID)
        }

        do {
            let result = try await api.toggleFavorite(id: albumID, type: "album")
            if let result {
                if result {
                    albumIDs.insert(albumID)
                } else {
                    albumIDs.remove(albumID)
                }
            }
        } catch {
            if wasFavorite {
                albumIDs.insert(albumID)
            } else {
                albumIDs.remove(albumID)
            }
        }
    }

    func clear() {
        trackIDs.removeAll()
        albumIDs.removeAll()
    }
}
