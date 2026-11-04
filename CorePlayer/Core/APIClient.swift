import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case server(Int, String?)
    case decoding(String)
    case network(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес сервера"
        case .unauthorized:
            return "Сессия истекла. Войдите снова"
        case .server(let code, let detail):
            if let detail, !detail.isEmpty { return detail }
            return "Ошибка сервера (\(code))"
        case .decoding:
            return "Сервер вернул неожиданный ответ"
        case .network:
            return "Не удалось подключиться к серверу. Проверьте адрес и сеть"
        case .unknown:
            return "Неизвестная ошибка"
        }
    }
}

private struct ErrorDetail: Decodable {
    let detail: String?
}

final class APIClient {
    private(set) var baseURL: URL
    private(set) var sessionID: String?

    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    func configure(baseURL: URL, sessionID: String?) {
        self.baseURL = baseURL
        self.sessionID = sessionID
    }

    // MARK: - Auth

    func login(serverURL: URL, username: String, password: String) async throws -> UserDto {
        configure(baseURL: serverURL, sessionID: nil)
        let body = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        let (data, response) = try await send(
            path: "api/auth/login",
            method: "POST",
            body: body,
            authenticated: false
        )
        guard let sid = Self.extractSessionID(from: response) else {
            throw APIError.unauthorized
        }
        sessionID = sid
        return try decode(UserDto.self, from: data)
    }

    func me() async throws -> UserDto {
        let (data, _) = try await send(path: "api/auth/me")
        return try decode(UserDto.self, from: data)
    }

    func logout() async {
        _ = try? await send(path: "api/auth/logout", method: "POST")
        sessionID = nil
    }

    // MARK: - Library

    func artists() async throws -> [ArtistDto] {
        let (data, _) = try await send(path: "api/library/artists")
        return try decode(FlexibleList<ArtistDto>.self, from: data).items
    }

    func albums(all: Bool = true, type: String? = nil, size: Int = 100, offset: Int = 0) async throws -> [AlbumDto] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "all", value: all ? "true" : "false"),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let type { query.append(URLQueryItem(name: "type", value: type)) }
        let (data, _) = try await send(path: "api/library/albums", query: query)
        return try decode(FlexibleList<AlbumDto>.self, from: data).items
    }

    func tracks(all: Bool = true, size: Int = 2000, offset: Int = 0) async throws -> [TrackDto] {
        let query = [
            URLQueryItem(name: "all", value: all ? "true" : "false"),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        let (data, _) = try await send(path: "api/library/tracks", query: query)
        return try decode(FlexibleList<TrackDto>.self, from: data).items
    }

    func albumDetail(id: String) async throws -> AlbumWithSongsDto {
        let (data, _) = try await send(path: "api/library/albums/\(id)")
        return try decode(AlbumDetailResponse.self, from: data).album
    }

    func artistDetail(id: String) async throws -> ArtistWithAlbumsDto {
        let (data, _) = try await send(path: "api/library/artists/\(id)")
        return try decode(ArtistDetailResponse.self, from: data).artist
    }

    func playlists() async throws -> [PlaylistDto] {
        let (data, _) = try await send(path: "api/library/playlists")
        return try decode(FlexibleList<PlaylistDto>.self, from: data).items
    }

    func playlistDetail(id: String) async throws -> PlaylistWithSongsDto {
        let (data, _) = try await send(path: "api/library/playlists/\(id)")
        return try decode(PlaylistDetailResponse.self, from: data).playlist
    }

    @discardableResult
    func createPlaylist(name: String) async throws -> CreatePlaylistResponse {
        let body = try JSONEncoder().encode(CreatePlaylistRequest(name: name))
        let (data, _) = try await send(path: "api/library/playlists", method: "POST", body: body)
        return try decode(CreatePlaylistResponse.self, from: data)
    }

    func deletePlaylist(id: String) async throws {
        _ = try await send(path: "api/library/playlists/\(id)", method: "DELETE")
    }

    func addTrack(playlistID: String, trackID: String) async throws {
        let body = try JSONEncoder().encode(AddTrackRequest(trackId: trackID))
        _ = try await send(path: "api/library/playlists/\(playlistID)/tracks", method: "POST", body: body)
    }

    func removeTrack(playlistID: String, trackID: String) async throws {
        _ = try await send(path: "api/library/playlists/\(playlistID)/tracks/\(trackID)", method: "DELETE")
    }

    func reorderPlaylist(id: String, trackIDs: [String]) async throws {
        let body = try JSONEncoder().encode(ReorderPlaylistRequest(trackIds: trackIDs))
        _ = try await send(path: "api/library/playlists/\(id)/reorder", method: "PUT", body: body)
    }

    func favoritesIDs() async throws -> FavoritesIdsResponse {
        let (data, _) = try await send(path: "api/library/favorites/ids")
        return try decode(FavoritesIdsResponse.self, from: data)
    }

    @discardableResult
    func toggleFavorite(id: String, type: String) async throws -> Bool? {
        let body = try JSONEncoder().encode(FavoriteToggleRequest(id: id, type: type))
        let (data, _) = try await send(path: "api/library/favorites/toggle", method: "POST", body: body)
        return try? decode(FavoriteToggleResponse.self, from: data).starred
    }

    func favoriteTracks() async throws -> [TrackDto] {
        let (data, _) = try await send(path: "api/library/favorites/tracks")
        return try decode(FlexibleList<TrackDto>.self, from: data).items
    }

    func randomTracks(size: Int = 20) async throws -> [TrackDto] {
        let query = [URLQueryItem(name: "size", value: String(size))]
        let (data, _) = try await send(path: "api/library/random", query: query)
        return try decode(FlexibleList<TrackDto>.self, from: data).items
    }

    func search(query: String) async throws -> SearchResponse {
        let (data, _) = try await send(
            path: "api/library/search",
            query: [URLQueryItem(name: "query", value: query)]
        )
        return try decode(SearchResponse.self, from: data)
    }

    func lyrics(track: TrackDto) async throws -> LyricsResponse {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "artist", value: track.displayArtist),
            URLQueryItem(name: "title", value: track.title)
        ]
        if let album = track.album, !album.isEmpty {
            query.append(URLQueryItem(name: "album", value: album))
        }
        if let duration = track.duration, duration > 0 {
            query.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        let (data, _) = try await send(path: "api/lyrics/\(track.id)", query: query)
        return try decode(LyricsResponse.self, from: data)
    }

    // MARK: - URLs

    func streamURL(trackID: String, codec: AudioCodec, timeOffset: Int? = nil) -> URL? {
        StreamURLBuilder.streamURL(
            baseURL: baseURL,
            trackID: trackID,
            codec: codec,
            sessionID: sessionID,
            timeOffset: timeOffset
        )
    }

    func coverURL(coverID: String?, size: Int) -> URL? {
        guard let coverID, !coverID.isEmpty else { return nil }
        return StreamURLBuilder.coverURL(
            baseURL: baseURL,
            coverID: coverID,
            size: size,
            sessionID: sessionID
        )
    }

    // MARK: - Transport

    private func send(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil,
        authenticated: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let sessionID {
            request.setValue("session_id=\(sessionID)", forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
            if http.statusCode == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(http.statusCode) else {
                let detail = try? JSONDecoder().decode(ErrorDetail.self, from: data).detail
                throw APIError.server(http.statusCode, detail)
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private static func extractSessionID(from response: HTTPURLResponse) -> String? {
        if let header = response.value(forHTTPHeaderField: "Set-Cookie") {
            for part in header.components(separatedBy: ";") {
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if item.hasPrefix("session_id=") {
                    return String(item.dropFirst("session_id=".count))
                }
            }
        }
        if let url = response.url,
           let cookie = HTTPCookieStorage.shared.cookies(for: url)?.first(where: { $0.name == "session_id" }) {
            return cookie.value
        }
        return nil
    }

    static func normalizeServerURL(_ input: String) -> URL? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "http://" + value
        }
        guard var components = URLComponents(string: value), components.host != nil else {
            return nil
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return components.url
    }
}
