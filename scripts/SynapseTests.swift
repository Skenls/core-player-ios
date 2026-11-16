import Foundation

@main struct SynapseTests {
    static func main() throws {
        let json = Data(#"{"id":"t","title":"Test","duration":100,"bpm":140,"genre":"house","synapse":{"session_id":"s","reason":"Для вас","score":0.5}}"#.utf8)
        let track = try JSONDecoder().decode(TrackDto.self, from: json)
        assert(track.synapse?.session_id == "s")
        assert(track.bpm == 140 && track.genre == "house")
        let restored = try JSONDecoder().decode(TrackDto.self, from: JSONEncoder().encode(track))
        assert(restored == track)
        assert(synapseTempo(bpm: 500, genre: nil) == 180)
        assert(synapseTempo(bpm: .nan, genre: "Ambient") == 80)
        assert(synapseTempo(bpm: nil, genre: "drum and bass") == 170)
        assert(synapseTempo(bpm: nil, genre: nil) == 110)
        var tracker = SynapseListeningTracker()
        var state = SynapsePlaybackSnapshot(track: track, playing: true, duration: 100)
        assert(tracker.sample(state, now: 0).map(\.event_type) == ["start"])
        for n in 1...4 { state.position = Double(n); assert(tracker.sample(state, now: Double(n)).isEmpty) }
        state.position = 80 // seek is not audible listening
        assert(tracker.sample(state, now: 5).isEmpty)
        state.playing = false
        _ = tracker.sample(state, now: 6)
        state.track = nil
        let skip = tracker.sample(state, now: 7)
        assert(skip.count == 1 && skip[0].event_type == "skip")
        assert(skip[0].context["played_seconds"] == 4)
        assert(skip[0].percent == 0.04)
        tracker = SynapseListeningTracker()
        state = SynapsePlaybackSnapshot(track: track, playing: true, duration: 100)
        _ = tracker.sample(state, now: 0)
        for n in 1...80 { state.position = Double(n); _ = tracker.sample(state, now: Double(n)) }
        state.ended = true; state.playing = false
        let complete = tracker.sample(state, now: 80)
        assert(complete.count == 1 && complete[0].event_type == "complete")
        assert(tracker.sample(state, now: 81).isEmpty) // terminal event once
        tracker = SynapseListeningTracker()
        state = SynapsePlaybackSnapshot(track: track, playing: true, duration: 100)
        _ = tracker.sample(state, now: 0)
        state.position = 60
        _ = tracker.sample(state, now: 60) // OS suspension gap
        state.ended = true
        assert(tracker.sample(state, now: 60)[0].context["played_seconds"] == 0)
        state = SynapsePlaybackSnapshot(track: TrackDto(id: "normal", title: "Ordinary"), playing: true)
        tracker = SynapseListeningTracker()
        assert(tracker.sample(state, now: 0).isEmpty)
        state.track = nil
        assert(tracker.sample(state, now: 1).isEmpty)
        tracker = SynapseListeningTracker()
        state = SynapsePlaybackSnapshot(track: track, playing: true, duration: 100)
        _ = tracker.sample(state, now: 0)
        for n in 1...80 {
            _ = tracker.sample(state, now: Double(n) - 0.5) // duplicate timer before engine update
            state.position = Double(n)
            _ = tracker.sample(state, now: Double(n))
        }
        state.ended = true; state.playing = false
        let audible = tracker.sample(state, now: 80)
        assert(audible[0].event_type == "complete")
        assert(audible[0].context["played_seconds"] == 80)
        let batch = SynapseEventBatch(events: skip)
        let encoded = try JSONEncoder().encode(batch)
        let decoded = try JSONDecoder().decode(SynapseEventBatch.self, from: encoded)
        assert(decoded.events == skip)
        print("Synapse contract, tempo, seek/skip/complete/pause/suspension tests passed")
    }
}
