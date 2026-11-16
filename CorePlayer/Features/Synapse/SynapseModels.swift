import Foundation

struct SynapseMetadata: Codable, Hashable {
    let session_id: String
    let reason: String?
    let channel: String?
    let score: Double?
}

struct SynapseFilters: Codable, Equatable {
    var familiarity = ["familiar", "unfamiliar"]
    var mood: String?
}

struct SynapseMixRequest: Encodable {
    let familiarity: [String]
    let mood: String?
    var limit = 20
    var exclude_track_ids: [String] = []
}

struct SynapseMix: Decodable {
    let mix_id: String
    let status: String
    let tracks: [TrackDto]
    let hint: String?
}

struct SynapseStatus: Decodable {
    let status: String
    let progress: Int?
}

struct SynapseEvent: Codable, Identifiable, Equatable {
    let id: String
    let session_id: String
    let track_id: String
    let event_type: String
    let position_seconds: Double
    let duration_seconds: Double
    let percent: Double
    let client_ts: String
    let context: [String: Double]
}

struct SynapseEventBatch: Codable {
    let events: [SynapseEvent]
}

func synapseTempo(bpm: Double?, genre: String?) -> Float {
    if let bpm, bpm.isFinite, bpm > 0 { return Float(min(180, max(60, bpm))) }
    let genre = (genre ?? "").lowercased()
    if ["drum", "dnb", "jungle"].contains(where: genre.contains) { return 170 }
    if ["techno", "house", "dance", "trance", "metal"].contains(where: genre.contains) { return 135 }
    if ["ambient", "chill", "sleep", "classical", "jazz"].contains(where: genre.contains) { return 80 }
    return 110
}
