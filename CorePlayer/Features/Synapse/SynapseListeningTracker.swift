import Foundation

struct SynapsePlaybackSnapshot {
    var track: TrackDto?
    var playbackID: Int = 0
    var playing = false
    var buffering = false
    var position: Double = 0
    var duration: Double = 0
    var ended = false
}

/// Uses monotonic audible time; seeking, pauses and suspension gaps cannot train positive taste.
struct SynapseListeningTracker {
    private var previous: SynapsePlaybackSnapshot?
    private var lastTime: Double = 0
    private var listened: Double = 0
    private var started = false

    mutating func sample(_ state: SynapsePlaybackSnapshot, now: Double) -> [SynapseEvent] {
        var events: [SynapseEvent] = []
        let old = previous
        let same = old?.track?.id == state.track?.id && old?.playbackID == state.playbackID
            && old?.track?.synapse?.session_id == state.track?.synapse?.session_id
        // Timer and engine callbacks can observe the same position between audio updates.
        // Keep the previous timestamp so those duplicate observations don't erase audible time.
        if let old, same, !state.ended, old.position == state.position,
           old.playing == state.playing, old.buffering == state.buffering { return [] }
        if let old, old.playing, !old.buffering {
            let elapsed = max(0, now - lastTime)
            let delta = state.position - old.position
            if elapsed <= 2 && (!same || (delta > 0 && delta <= elapsed + 1.5)) {
                listened += elapsed
            }
        }
        if !same || state.ended {
            if started, let old, let event = event(old, type: old.duration > 0 && listened >= old.duration * 0.8 ? "complete" : "skip") {
                events.append(event)
            }
            listened = 0
            started = false
        }
        if !state.ended, state.track?.synapse != nil, state.playing, !state.buffering, !started {
            started = true
            if let event = event(state, type: "start") { events.append(event) }
        }
        previous = state
        lastTime = now
        return events
    }

    func event(_ state: SynapsePlaybackSnapshot, type: String) -> SynapseEvent? {
        guard let track = state.track, let metadata = track.synapse else { return nil }
        let duration = min(604800, max(0, state.duration))
        return SynapseEvent(id: UUID().uuidString, session_id: metadata.session_id, track_id: track.id,
                            event_type: type, position_seconds: min(604800, max(0, state.position)),
                            duration_seconds: duration, percent: duration > 0 ? min(1, listened / duration) : 0,
                            client_ts: ISO8601DateFormatter().string(from: Date()),
                            context: ["played_seconds": min(604800, listened)])
    }
}
