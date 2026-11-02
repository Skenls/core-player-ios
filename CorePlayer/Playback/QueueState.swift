import Foundation

enum RepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var isActive: Bool { self != .off }
}

struct QueueState {
    private(set) var tracks: [TrackDto] = []
    private(set) var index: Int = -1
    var repeatMode: RepeatMode = .off
    var isShuffled: Bool = false

    var current: TrackDto? {
        guard tracks.indices.contains(index) else { return nil }
        return tracks[index]
    }

    var nextTrack: TrackDto? {
        guard let next = nextIndex(), tracks.indices.contains(next) else { return nil }
        return tracks[next]
    }

    mutating func setQueue(_ tracks: [TrackDto], startAt: Int) {
        self.tracks = tracks
        guard !tracks.isEmpty else {
            index = -1
            return
        }
        index = min(max(startAt, 0), tracks.count - 1)
    }

    mutating func setIndex(_ newIndex: Int) {
        guard tracks.indices.contains(newIndex) else { return }
        index = newIndex
    }

    /// Next index for manual "next" and automatic advance.
    /// Repeat-one is handled by the player itself (restart the same item).
    func nextIndex() -> Int? {
        guard !tracks.isEmpty else { return nil }
        if isShuffled { return randomIndex(excluding: index) }
        if index + 1 < tracks.count { return index + 1 }
        if repeatMode == .all { return 0 }
        return nil
    }

    func previousIndex() -> Int? {
        guard !tracks.isEmpty else { return nil }
        if isShuffled { return randomIndex(excluding: index) }
        if index - 1 >= 0 { return index - 1 }
        if repeatMode == .all { return tracks.count - 1 }
        return nil
    }

    func randomIndex(excluding excluded: Int) -> Int? {
        guard !tracks.isEmpty else { return nil }
        guard tracks.count > 1 else { return 0 }
        let candidates = tracks.indices.filter { $0 != excluded }
        return candidates.randomElement()
    }
}
