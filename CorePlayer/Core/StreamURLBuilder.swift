import Foundation

enum StreamURLBuilder {
    static func streamURL(
        baseURL: URL,
        trackID: String,
        codec: AudioCodec,
        sessionID: String?,
        timeOffset: Int? = nil
    ) -> URL? {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("stream")
            .appendingPathComponent(trackID)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []

        // Android parity: "auto" streams the raw file with no extra params.
        if let format = codec.queryValue {
            items.append(URLQueryItem(name: "format", value: format))
            // Estimated length makes transcoded durations unreliable; the bridge leaves it off for offset streams.
            if timeOffset == nil, codec != .aac {
                items.append(URLQueryItem(name: "estimateContentLength", value: "true"))
            }
        }
        if let timeOffset {
            items.append(URLQueryItem(name: "timeOffset", value: String(timeOffset)))
        }
        if let sessionID = sessionID, !sessionID.isEmpty {
            items.append(URLQueryItem(name: "session_id", value: sessionID))
        }

        components?.queryItems = items
        return components?.url
    }

    static func coverURL(
        baseURL: URL,
        coverID: String,
        size: Int,
        sessionID: String?
    ) -> URL? {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("stream")
            .appendingPathComponent("cover")
            .appendingPathComponent(coverID)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "size", value: String(size))]
        if let sessionID = sessionID, !sessionID.isEmpty {
            items.append(URLQueryItem(name: "session_id", value: sessionID))
        }
        components?.queryItems = items
        return components?.url
    }
}
