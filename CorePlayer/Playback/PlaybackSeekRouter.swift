import Foundation

enum PlaybackSeekRoute: Equatable {
    case avPlayer(Double)
    case offsetStream(Int)
}

enum PlaybackSeekRouter {
    static func route(time: Double, codec: AudioCodec, isLocal: Bool) -> PlaybackSeekRoute {
        guard codec.usesOffsetStreamSeeking, !isLocal else {
            return .avPlayer(time)
        }
        return .offsetStream(max(0, Int(time)))
    }
}
