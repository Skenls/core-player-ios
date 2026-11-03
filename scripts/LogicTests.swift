import Foundation

@main
struct LogicTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            print("  ok  \(message)")
        } else {
            failures += 1
            print("  FAIL \(message)")
        }
    }

    static func track(_ id: String) -> TrackDto {
        TrackDto(id: id, title: "Track \(id)", duration: 180)
    }

    static func main() {
        print("LRCParser")
        let lrc = """
        [ar:Artist]
        [ti:Title]
        [00:12.34]Hello
        [00:15.00]World
        [00:20.5]Half
        [00:30:25]Colon
        [00:40.00][00:50.00]Twice
        """
        let lines = LRCParser.parse(lrc)
        expect(lines.count == 6, "parses six timestamped lines")
        expect(abs(lines[0].time - 12.34) < 0.001, "parses centiseconds")
        expect(lines[0].text == "Hello", "extracts text")
        expect(abs(lines[2].time - 20.5) < 0.001, "parses tenths of a second")
        expect(abs(lines[3].time - 30.25) < 0.001, "parses colon fraction")
        expect(lines[4].text == "Twice" && lines[5].text == "Twice", "supports multiple tags")
        expect(LRCParser.currentIndex(lines, at: 0) == nil, "no line before the first timestamp")
        expect(LRCParser.currentIndex(lines, at: 13) == 0, "finds current line")
        expect(LRCParser.currentIndex(lines, at: 49) == 4, "finds line before next timestamp")
        expect(LRCParser.parse("").isEmpty, "empty input")

        print("QueueState")
        var queue = QueueState()
        queue.setQueue([track("a"), track("b"), track("c")], startAt: 0)
        expect(queue.current?.id == "a", "sets current track")
        expect(queue.nextIndex() == 1, "next advances")
        queue.setIndex(2)
        expect(queue.nextIndex() == nil, "stops at the end when repeat is off")
        queue.repeatMode = .all
        expect(queue.nextIndex() == 0, "wraps with repeat all")
        queue.isShuffled = true
        if let random = queue.nextIndex() {
            expect(random != 2 && (0...2).contains(random), "shuffle never picks the current track")
        } else {
            expect(false, "shuffle returns a track")
        }
        queue.isShuffled = false
        queue.repeatMode = .off
        queue.setIndex(2)
        expect(queue.previousIndex() == 1, "previous goes back")
        queue.setIndex(0)
        expect(queue.previousIndex() == nil, "no previous at the start when repeat is off")
        queue.repeatMode = .all
        expect(queue.previousIndex() == 2, "previous wraps with repeat all")
        queue.setQueue([], startAt: 0)
        expect(queue.current == nil && queue.nextIndex() == nil, "empty queue is safe")

        print("StreamURLBuilder")
        let base = URL(string: "http://localhost:3000")!
        let auto = StreamURLBuilder.streamURL(baseURL: base, trackID: "t1", codec: .auto, sessionID: "sid")
        expect(auto?.absoluteString.contains("format=") == false, "auto omits format")
        expect(auto?.absoluteString.contains("estimateContentLength=true") == false, "auto omits estimateContentLength (Android parity)")
        expect(auto?.absoluteString.contains("session_id=sid") == true, "adds session id")
        let mp3 = StreamURLBuilder.streamURL(baseURL: base, trackID: "t1", codec: .mp3, sessionID: nil)
        expect(mp3?.absoluteString.contains("format=mp3") == true, "adds mp3 format")
        expect(mp3?.absoluteString.contains("estimateContentLength=true") == true, "mp3 adds estimateContentLength")
        expect(mp3?.absoluteString.contains("session_id") == false, "omits empty session id")
        let aac = StreamURLBuilder.streamURL(baseURL: base, trackID: "t1", codec: .aac, sessionID: nil)
        expect(aac?.absoluteString.contains("format=aac") == true, "adds AAC format")
        expect(aac?.absoluteString.contains("estimateContentLength=true") == true, "AAC adds estimateContentLength")
        let alac = StreamURLBuilder.streamURL(baseURL: base, trackID: "t1", codec: .alac, sessionID: nil)
        expect(alac?.absoluteString.contains("format=alac") == true, "adds ALAC format")
        expect(alac?.absoluteString.contains("estimateContentLength=true") == true, "ALAC adds estimateContentLength")
        let cover = StreamURLBuilder.coverURL(baseURL: base, coverID: "al-1", size: 600, sessionID: "sid")
        expect(cover?.absoluteString.contains("/api/stream/cover/al-1") == true, "builds cover path")
        expect(cover?.absoluteString.contains("size=600") == true, "adds cover size")

        print("FlexibleList")
        let albumsJSON = #"{"albums":[{"id":"1","name":"A"}],"total":1}"#.data(using: .utf8)!
        let albums = try! JSONDecoder().decode(FlexibleList<AlbumDto>.self, from: albumsJSON)
        expect(albums.items.count == 1 && albums.items[0].name == "A", "decodes wrapped albums")
        let bareJSON = #"[{"id":"1","name":"A"}]"#.data(using: .utf8)!
        let bare = try! JSONDecoder().decode(FlexibleList<AlbumDto>.self, from: bareJSON)
        expect(bare.items.count == 1, "decodes bare array")

        print("Models")
        let trackJSON = #"{"id":"t1","title":"Song","artist":"Artist","duration":200,"is_favorite":true,"suffix":"mp3","contentType":"audio/mpeg"}"#.data(using: .utf8)!
        let decodedTrack = try! JSONDecoder().decode(TrackDto.self, from: trackJSON)
        expect(decodedTrack.isFavorite, "decodes is_favorite")
        expect(decodedTrack.durationSeconds == 200, "duration is seconds")
        expect(decodedTrack.suffix == "mp3", "decodes suffix")
        expect(decodedTrack.isLossy == true, "identifies mp3 as lossy")
        expect(decodedTrack.isFlac == false, "identifies mp3 is not flac")
        let flacTrack = TrackDto(id: "f1", title: "Flac", suffix: "flac")
        expect(flacTrack.isFlac == true, "identifies flac track")
        expect(flacTrack.isLossy == false, "flac is not lossy")
        let starredBoolJSON = #"{"id":"t2","title":"Song2","starred":true}"#.data(using: .utf8)!
        let decodedStarredBool = try! JSONDecoder().decode(TrackDto.self, from: starredBoolJSON)
        expect(decodedStarredBool.isFavorite, "decodes boolean starred")
        let starredStrJSON = #"{"id":"t3","title":"Song3","starred":"2026-10-08T12:00:00Z"}"#.data(using: .utf8)!
        let decodedStarredStr = try! JSONDecoder().decode(TrackDto.self, from: starredStrJSON)
        expect(decodedStarredStr.isFavorite, "decodes string starred")
        let favJSON = #"{"track_ids":["a","b"],"album_ids":["x"]}"#.data(using: .utf8)!
        let favs = try! JSONDecoder().decode(FavoritesIdsResponse.self, from: favJSON)
        expect(favs.trackIDs.count == 2 && favs.albumIDs == ["x"], "decodes favorites ids")
        let searchJSON = #"{"tracks":[{"id":"t","title":"T"}],"albums":[],"artists":[]}"#.data(using: .utf8)!
        let search = try! JSONDecoder().decode(SearchResponse.self, from: searchJSON)
        expect(search.tracks.count == 1, "decodes search response")
        let subsonicSearchJSON = #"{"results":{"song":[{"id":"s1","title":"S"}],"album":[{"id":"a1","name":"A"}],"artist":[{"id":"ar1","name":"Art"}]}}"#.data(using: .utf8)!
        let subsonicSearch = try! JSONDecoder().decode(SearchResponse.self, from: subsonicSearchJSON)
        expect(subsonicSearch.tracks.count == 1 && subsonicSearch.albums.count == 1 && subsonicSearch.artists.count == 1, "decodes Subsonic singular searchResult3")

        print("AudioCodec")
        expect(AudioCodec.auto.queryValue == nil, "auto has no query value")
        expect(AudioCodec.flac.queryValue == "flac", "flac query value")
        expect(AudioCodec.aac.queryValue == "aac", "AAC query value")
        expect(AudioCodec.alac.queryValue == "alac", "ALAC query value")
        expect(AudioCodec.aac.title == "AAC", "AAC title")
        expect(AudioCodec.alac.title == "ALAC", "ALAC title")
        expect(TrackCache.fileExtension(for: "audio/aac") == "aac", "AAC streams cache with an aac extension")
        expect(TrackCache.fileExtension(for: "audio/mp4") == "m4a", "MP4/ALAC streams cache with an m4a extension")

        if failures == 0 {
            print("\nAll logic tests passed.")
        } else {
            print("\n\(failures) test(s) failed.")
            exit(1)
        }
    }
}
