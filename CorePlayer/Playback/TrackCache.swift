import Foundation

final class TrackCache {
    static let maxBytes: Int64 = 500 * 1024 * 1024

    private let fileManager = FileManager.default
    private let directory: URL
    private let lock = NSLock()
    private var inFlight = Set<String>()

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("CorePlayerTracks", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = directory
        try? url.setResourceValues(values)
    }

    func localURL(trackID: String, codec: AudioCodec) -> URL? {
        let key = cacheKey(trackID: trackID, codec: codec)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        guard let file = files.first(where: { $0.lastPathComponent.hasPrefix(key + ".") }) else {
            return nil
        }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return file
    }

    func prefetch(track: TrackDto, codec: AudioCodec, baseURL: URL, sessionID: String?) {
        let key = cacheKey(trackID: track.id, codec: codec)

        lock.lock()
        if inFlight.contains(key) {
            lock.unlock()
            return
        }
        inFlight.insert(key)
        lock.unlock()

        if localURL(trackID: track.id, codec: codec) != nil {
            lock.lock()
            inFlight.remove(key)
            lock.unlock()
            return
        }

        guard let url = StreamURLBuilder.streamURL(
            baseURL: baseURL,
            trackID: track.id,
            codec: codec,
            sessionID: sessionID
        ) else {
            lock.lock()
            inFlight.remove(key)
            lock.unlock()
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let (temporary, response) = try await URLSession.shared.download(from: url)
                let ext = Self.fileExtension(for: response.mimeType)
                let destination = self.directory.appendingPathComponent("\(key).\(ext)")
                try? self.fileManager.removeItem(at: destination)
                try self.fileManager.moveItem(at: temporary, to: destination)
            } catch {
                // Кэш не критичен: при ошибке просто играем из сети.
            }

            self.lock.lock()
            self.inFlight.remove(key)
            self.lock.unlock()

            self.evictIfNeeded()
        }
    }

    func totalSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return files.reduce(into: Int64(0)) { result, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            result += Int64(size)
        }
    }

    func clear() {
        lock.lock()
        inFlight.removeAll()
        lock.unlock()

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    private func evictIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var entries: [(url: URL, size: Int64, date: Date)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                return nil
            }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }

        var total = entries.reduce(into: Int64(0)) { $0 += $1.size }
        guard total > Self.maxBytes else { return }

        entries.sort { $0.date < $1.date }
        for entry in entries where total > Self.maxBytes {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private func cacheKey(trackID: String, codec: AudioCodec) -> String {
        "\(trackID)-\(codec.rawValue)"
    }

    static func fileExtension(for mimeType: String?) -> String {
        switch mimeType?.lowercased() {
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/mp4", "audio/x-m4a", "audio/m4a": return "m4a"
        case "audio/aac", "audio/aacp": return "aac"
        case "audio/ogg": return "ogg"
        default: return "audio"
        }
    }
}
