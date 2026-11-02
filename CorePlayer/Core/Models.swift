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
    let suffix: String?
    let contentType: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, starred
        case artistId, albumId, coverArt, trackNumber, discNumber
        case track
        case isFavoriteFlag = "is_favorite"
        case suffix, contentType
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
        isFavoriteFlag: Bool? = nil,
        suffix: String? = nil,
        contentType: String? = nil
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
        self.suffix = suffix
        self.contentType = contentType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = try? c.decode(String.self, forKey: .artist)
        artistId = try? c.decode(String.self, forKey: .artistId)
        album = try? c.decode(String.self, forKey: .album)
        albumId = try? c.decode(String.self, forKey: .albumId)
        coverArt = try? c.decode(String.self, forKey: .coverArt)
        duration = try? c.decode(Int.self, forKey: .duration)
        trackNumber = (try? c.decode(Int.self, forKey: .trackNumber))
            ?? (try? c.decode(Int.self, forKey: .track))
        discNumber = try? c.decode(Int.self, forKey: .discNumber)
        if let s = try? c.decode(String.self, forKey: .starred) {
            starred = s
        } else if let b = try? c.decode(Bool.self, forKey: .starred) {
            starred = b ? "true" : nil
        } else {
            starred = nil
        }
        isFavoriteFlag = try? c.decode(Bool.self, forKey: .isFavoriteFlag)
        suffix = try? c.decode(String.self, forKey: .suffix)
        contentType = try? c.decode(String.self, forKey: .contentType)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(artist, forKey: .artist)
        try c.encodeIfPresent(artistId, forKey: .artistId)
        try c.encodeIfPresent(album, forKey: .album)
        try c.encodeIfPresent(albumId, forKey: .albumId)
        try c.encodeIfPresent(coverArt, forKey: .coverArt)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(trackNumber, forKey: .trackNumber)
        try c.encodeIfPresent(discNumber, forKey: .discNumber)
        try c.encodeIfPresent(starred, forKey: .starred)
        try c.encodeIfPresent(isFavoriteFlag, forKey: .isFavoriteFlag)
        try c.encodeIfPresent(suffix, forKey: .suffix)
        try c.encodeIfPresent(contentType, forKey: .contentType)
    }

    var isFavorite: Bool {
        isFavoriteFlag == true || (starred != nil && starred != "false")
    }

    var displayArtist: String {
        let cleaned = cleanArtistName(artist)
        return cleaned.isEmpty ? "Неизвестный исполнитель" : cleaned
    }

    var displayAlbum: String {
        guard let album = album, !album.isEmpty else { return "" }
        return album
    }

    var durationSeconds: Double {
        Double(duration ?? 0)
    }

    var isLossy: Bool {
        guard let s = suffix?.lowercased() else { return false }
        return s == "mp3" || s == "aac" || s == "m4a" || s == "ogg" || s == "opus"
    }

    var isFlac: Bool {
        suffix?.lowercased() == "flac" || contentType?.lowercased() == "audio/flac"
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

    private enum CodingKeys: String, CodingKey {
        case id, name, albumCount, coverArt, artistImageUrl, albums, album
    }

    init(id: String, name: String, albumCount: Int? = nil, coverArt: String? = nil, artistImageUrl: String? = nil, albums: [AlbumDto]? = nil) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.coverArt = coverArt
        self.artistImageUrl = artistImageUrl
        self.albums = albums
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        albumCount = try? c.decode(Int.self, forKey: .albumCount)
        coverArt = try? c.decode(String.self, forKey: .coverArt)
        artistImageUrl = try? c.decode(String.self, forKey: .artistImageUrl)
        albums = (try? c.decode([AlbumDto].self, forKey: .album)) ?? (try? c.decode([AlbumDto].self, forKey: .albums))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(albumCount, forKey: .albumCount)
        try c.encodeIfPresent(coverArt, forKey: .coverArt)
        try c.encodeIfPresent(artistImageUrl, forKey: .artistImageUrl)
        try c.encodeIfPresent(albums, forKey: .albums)
    }

    var effectiveCover: String? { coverArt ?? artistImageUrl ?? id }
}

struct PlaylistWithSongsDto: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let songCount: Int?
    let coverArt: String?
    let created: String?
    let entry: [TrackDto]?

    private enum CodingKeys: String, CodingKey {
        case id, name, songCount, coverArt, created, entry, tracks, song, songs
    }

    init(id: String, name: String, songCount: Int? = nil, coverArt: String? = nil, created: String? = nil, entry: [TrackDto]? = nil) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.coverArt = coverArt
        self.created = created
        self.entry = entry
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        songCount = try? c.decode(Int.self, forKey: .songCount)
        coverArt = try? c.decode(String.self, forKey: .coverArt)
        created = try? c.decode(String.self, forKey: .created)
        entry = (try? c.decode([TrackDto].self, forKey: .entry))
            ?? (try? c.decode([TrackDto].self, forKey: .tracks))
            ?? (try? c.decode([TrackDto].self, forKey: .song))
            ?? (try? c.decode([TrackDto].self, forKey: .songs))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(songCount, forKey: .songCount)
        try c.encodeIfPresent(coverArt, forKey: .coverArt)
        try c.encodeIfPresent(created, forKey: .created)
        try c.encodeIfPresent(entry, forKey: .entry)
    }

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
        case tracks, songs, song, track
        case albums, album
        case artists, artist
        case results
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
            c = root
        }
        tracks = (try? c.decode([TrackDto].self, forKey: .tracks))
            ?? (try? c.decode([TrackDto].self, forKey: .songs))
            ?? (try? c.decode([TrackDto].self, forKey: .song))
            ?? (try? c.decode([TrackDto].self, forKey: .track))
            ?? []
        albums = (try? c.decode([AlbumDto].self, forKey: .albums))
            ?? (try? c.decode([AlbumDto].self, forKey: .album))
            ?? []
        artists = (try? c.decode([ArtistDto].self, forKey: .artists))
            ?? (try? c.decode([ArtistDto].self, forKey: .artist))
            ?? []
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
