import Foundation

enum PlaybackSeekRoute: Equatable {
    case avPlayer(Double)
    case offsetStream(Int)
}

enum PlaybackDurationPolicy {
    static func resolve(metadata: Double, engine: Double) -> Double {
        metadata > 0 ? metadata : max(0, engine)
    }
}

enum PlaybackPrefetchPolicy {
    static func allows(currentIsRawFlac: Bool, nextIsRawFlac: Bool) -> Bool {
        !currentIsRawFlac && !nextIsRawFlac
    }
}

enum PlaybackSeekRouter {
    static func route(time: Double, isLocal: Bool) -> PlaybackSeekRoute {
        guard !isLocal else { return .avPlayer(time) }
        return .offsetStream(max(0, Int(time)))
    }

    /// A direct-play stream ignores timeOffset, including when the requested
    /// format equals the source, so choose a format that forces transcoding.
    static func offsetCodec(requested: AudioCodec, sourceSuffix: String?) -> AudioCodec {
        let suffix = sourceSuffix?.lowercased()
        let codec: AudioCodec
        if requested == .auto {
            codec = matchesSource(.aac, suffix: suffix) ? .mp3 : .aac
        } else {
            codec = requested
        }
        guard matchesSource(codec, suffix: suffix) else { return codec }
        return codec == .aac ? .mp3 : .aac
    }

    private static func matchesSource(_ codec: AudioCodec, suffix: String?) -> Bool {
        switch codec {
        case .aac: return ["aac", "m4a", "mp4"].contains(suffix)
        case .mp3: return suffix == "mp3"
        case .flac: return suffix == "flac"
        case .auto: return false
        }
    }
}
