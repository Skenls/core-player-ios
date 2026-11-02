import Foundation

enum AudioCodec: String, CaseIterable, Identifiable, Hashable {
    case auto
    case mp3
    case flac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Авто"
        case .mp3: return "MP3"
        case .flac: return "FLAC"
        }
    }

    var detail: String {
        switch self {
        case .auto: return "Исходный формат сервера"
        case .mp3: return "320 kbps CBR"
        case .flac: return "Без потерь"
        }
    }

    var queryValue: String? {
        self == .auto ? nil : rawValue
    }
}
