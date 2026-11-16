import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var trackIDs: Set<String> = []
    @Published private(set) var albumIDs: Set<String> = []

    var onFavoriteAdded: ((TrackDto) -> Void)?
    private var loadedTrackIDs = false
    private var trackOverrides: [String: Bool] = [:]
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func isFavorite(_ track: TrackDto) -> Bool {
        trackOverrides[track.id] ?? (loadedTrackIDs ? trackIDs.contains(track.id) : trackIDs.contains(track.id) || track.isFavorite)
    }

    func isFavorite(albumID: String) -> Bool {
        albumIDs.contains(albumID)
    }

    func isAlbumFavorite(_ albumID: String) -> Bool {
        albumIDs.contains(albumID)
    }

    func apply(_ ids: FavoritesIdsResponse) {
        loadedTrackIDs = true
        trackOverrides.removeAll()
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

    @discardableResult
    func toggle(track: TrackDto) async -> Bool {
        let server = api.baseURL, session = api.sessionID
        let wasFavorite = isFavorite(track)
        trackOverrides[track.id] = !wasFavorite
        if wasFavorite {
            trackIDs.remove(track.id)
        } else {
            trackIDs.insert(track.id)
        }

        do {
            let result = try await api.toggleFavorite(id: track.id, type: "track")
            guard api.baseURL == server, api.sessionID == session else { return false }
            if let result {
                if result {
                    trackIDs.insert(track.id)
                } else {
                    trackIDs.remove(track.id)
                }
            }
            trackOverrides[track.id] = trackIDs.contains(track.id)
            if trackIDs.contains(track.id), !wasFavorite { onFavoriteAdded?(track) }
            return true
        } catch {
            guard api.baseURL == server, api.sessionID == session else { return false }
            trackOverrides[track.id] = wasFavorite
            if wasFavorite {
                trackIDs.insert(track.id)
            } else {
                trackIDs.remove(track.id)
            }
            return false
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
        loadedTrackIDs = false
        trackOverrides.removeAll()
        trackIDs.removeAll()
        albumIDs.removeAll()
    }
}
