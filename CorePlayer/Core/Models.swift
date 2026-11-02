import Foundation

// MARK: - Auth

struct UserDto: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let role: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

// MARK: - Library

struct TrackDto: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String?
    let artistId: String?
    let album: String?
    let albumId: String?
    let coverArt: String?
    let duration: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let starred: String?
    let isFavoriteFlag: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, starred
        case artistId, albumId, coverArt, trackNumber, discNumber
        case isFavoriteFlag = "is_favorite"
    }

    init(
        id: String,
        title: String,
        artist: String? = nil,
        artistId: String? = nil,
        album: String? = nil,
        albumId: String? = nil,
        coverArt: String? = nil,
        duration: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        starred: String? = nil,
        isFavoriteFlag: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.album = album
        self.albumId = albumId
        self.coverArt = coverArt
        self.duration = duration
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.starred = starred
        self.isFavoriteFlag = isFavoriteFlag
    }

    var isFavorite: Bool {
        isFavoriteFlag ?? (starred != nil)
    }

    var displayArtist: String {
        guard let artist = artist, !artist.isEmpty else { return "Неизвестный исполнитель" }
        return artist
    }

    var displayAlbum: String {
        guard let album = album, !album.isEmpty else { return "" }
        return album
    }

    var durationSeconds: Double {
        Double(duration ?? 0)
    }
}

struct AlbumDto: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let created: String?
}

struct ArtistDto: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let albumCount: Int?
    let coverArt: String?
    let artistImageUrl: String?

    /// Navidrome accepts the artist id as a cover-art id (`ar-...`).
    var effectiveCover: String? {
        coverArt ?? artistImageUrl ?? id
    }
}

struct PlaylistDto: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let songCount: Int?
    let coverArt: String?
    let created: String?
}

struct AlbumWithSongsDto: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let song: [TrackDto]?

    var tracks: [TrackDto] { song ?? [] }
}

struct ArtistWithAlbumsDto: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let albumCount: Int?
    let coverArt: String?
    let artistImageUrl: String?
    let albums: [AlbumDto]?

    var effectiveCover: String? { coverArt ?? artistImageUrl ?? id }
}

struct PlaylistWithSongsDto: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let songCount: Int?
    let coverArt: String?
    let created: String?
    let entry: [TrackDto]?

    var tracks: [TrackDto] { entry ?? [] }
}

// MARK: - Detail responses (tolerate both wrapped and raw shapes)

struct AlbumDetailResponse: Decodable {
    let album: AlbumWithSongsDto

    private enum CodingKeys: String, CodingKey { case album }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let album = try? container.decode(AlbumWithSongsDto.self, forKey: .album) {
            self.album = album
            return
        }
        self.album = try AlbumWithSongsDto(from: decoder)
    }
}

struct ArtistDetailResponse: Decodable {
    let artist: ArtistWithAlbumsDto

    private enum CodingKeys: String, CodingKey { case artist }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let artist = try? container.decode(ArtistWithAlbumsDto.self, forKey: .artist) {
            self.artist = artist
            return
        }
        self.artist = try ArtistWithAlbumsDto(from: decoder)
    }
}

struct PlaylistDetailResponse: Decodable {
    let playlist: PlaylistWithSongsDto

    private enum CodingKeys: String, CodingKey { case playlist }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let playlist = try? container.decode(PlaylistWithSongsDto.self, forKey: .playlist) {
            self.playlist = playlist
            return
        }
        self.playlist = try PlaylistWithSongsDto(from: decoder)
    }
}

// MARK: - Favorites

struct FavoritesIdsResponse: Decodable, Equatable {
    let trackIDs: [String]
    let albumIDs: [String]
    let artistIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case trackIDs = "track_ids"
        case tracks
        case trackIds
        case albumIDs = "album_ids"
        case albums
        case albumIds
        case artistIDs = "artist_ids"
        case artists
        case artistIds
    }

    init(trackIDs: [String] = [], albumIDs: [String] = [], artistIDs: [String] = []) {
        self.trackIDs = trackIDs
        self.albumIDs = albumIDs
        self.artistIDs = artistIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trackIDs = (try? c.decode([String].self, forKey: .trackIDs))
            ?? (try? c.decode([String].self, forKey: .tracks))
            ?? (try? c.decode([String].self, forKey: .trackIds))
            ?? []
        albumIDs = (try? c.decode([String].self, forKey: .albumIDs))
            ?? (try? c.decode([String].self, forKey: .albums))
            ?? (try? c.decode([String].self, forKey: .albumIds))
            ?? []
        artistIDs = (try? c.decode([String].self, forKey: .artistIDs))
            ?? (try? c.decode([String].self, forKey: .artists))
            ?? (try? c.decode([String].self, forKey: .artistIds))
            ?? []
    }
}

struct FavoriteToggleRequest: Codable {
    let id: String
    let type: String
}

struct FavoriteToggleResponse: Decodable {
    let starred: Bool?
    let id: String?
    let type: String?
}

// MARK: - Search

struct SearchResponse: Decodable, Equatable {
    let tracks: [TrackDto]
    let albums: [AlbumDto]
    let artists: [ArtistDto]

    private enum CodingKeys: String, CodingKey {
        case tracks, songs, albums, artists, results
    }

    init(tracks: [TrackDto] = [], albums: [AlbumDto] = [], artists: [ArtistDto] = []) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        let c: KeyedDecodingContainer<CodingKeys>
        if let nested = try? root.nestedContainer(keyedBy: CodingKeys.self, forKey: .results) {
            c = nested
        } else {
            c = try decoder.container(keyedBy: CodingKeys.self)
        }
        tracks = (try? c.decode([TrackDto].self, forKey: .tracks))
            ?? (try? c.decode([TrackDto].self, forKey: .songs))
            ?? []
        albums = (try? c.decode([AlbumDto].self, forKey: .albums)) ?? []
        artists = (try? c.decode([ArtistDto].self, forKey: .artists)) ?? []
    }

    var isEmpty: Bool { tracks.isEmpty && albums.isEmpty && artists.isEmpty }

    static let empty = SearchResponse()
}

// MARK: - Lyrics

struct LyricLineDto: Codable, Equatable {
    let time: Double?
    let text: String?
}

struct LyricsResponse: Decodable, Equatable {
    let synced: Bool?
    let text: String?
    let lines: [LyricLineDto]?
}

// MARK: - Playlists

struct CreatePlaylistRequest: Codable {
    let name: String
}

struct CreatePlaylistResponse: Decodable {
    let id: String?
    let name: String?
}

struct AddTrackRequest: Codable {
    let trackId: String

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
    }
}

struct ReorderPlaylistRequest: Codable {
    let trackIds: [String]

    enum CodingKeys: String, CodingKey {
        case trackIds = "track_ids"
    }
}

struct GenericMessageResponse: Decodable {
    let message: String?
    let detail: String?
}

// MARK: - Flexible lists
//
// The backend sometimes returns a bare array and sometimes an object such as
// `{ "albums": [...] }`. Both shapes are accepted.

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct FlexibleList<Element: Decodable>: Decodable {
    let items: [Element]

    init(items: [Element] = []) {
        self.items = items
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let array = try? single.decode([Element].self) {
            items = array
            return
        }

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let keys = [
            "albums", "album",
            "artists", "artist",
            "tracks", "track",
            "songs", "song",
            "playlists", "playlist",
            "items", "data", "results"
        ]
        for key in keys {
            if let codingKey = AnyCodingKey(stringValue: key),
               let array = try? container.decode([Element].self, forKey: codingKey) {
                items = array
                return
            }
        }

        items = []
    }
}
