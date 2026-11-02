import Foundation

@MainActor
final class RecentStore: ObservableObject {
    @Published private(set) var tracks: [TrackDto] = []

    private let defaults: UserDefaults
    private let key = "coreplayer.recentTracks"
    private let limit = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TrackDto].self, from: data) {
            tracks = decoded
        }
    }

    func add(_ track: TrackDto) {
        tracks.removeAll { $0.id == track.id }
        tracks.insert(track, at: 0)
        if tracks.count > limit {
            tracks = Array(tracks.prefix(limit))
        }
        save()
    }

    func clear() {
        tracks = []
        defaults.removeObject(forKey: key)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tracks) {
            defaults.set(data, forKey: key)
        }
    }
}

@MainActor
final class SearchHistoryStore: ObservableObject {
    @Published private(set) var queries: [String] = []

    private let defaults: UserDefaults
    private let key = "coreplayer.searchHistory"
    private let limit = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        queries = defaults.stringArray(forKey: key) ?? []
    }

    func add(_ query: String) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        queries.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        queries.insert(value, at: 0)
        if queries.count > limit {
            queries = Array(queries.prefix(limit))
        }
        defaults.set(queries, forKey: key)
    }

    func clear() {
        queries = []
        defaults.removeObject(forKey: key)
    }
}
