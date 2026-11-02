import Foundation

enum StreamURLBuilder {
    static func streamURL(
        baseURL: URL,
        trackID: String,
        codec: AudioCodec,
        sessionID: String?
    ) -> URL? {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("stream")
            .appendingPathComponent(trackID)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []

        if let format = codec.queryValue {
            items.append(URLQueryItem(name: "format", value: format))
        }
        items.append(URLQueryItem(name: "estimateContentLength", value: "true"))
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
