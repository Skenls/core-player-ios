import Foundation

enum AudioCodec: String, CaseIterable, Identifiable, Hashable {
    case auto
    case mp3
    case aac
    case flac
    case alac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Авто"
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .flac: return "FLAC"
        case .alac: return "ALAC"
        }
    }

    var detail: String {
        switch self {
        case .auto: return "Исходный формат сервера"
        case .mp3: return "320 kbps CBR"
        case .aac: return "AAC-LC · 192–320 kbps"
        case .flac: return "Без потерь"
        case .alac: return "Apple Lossless"
        }
    }

    var queryValue: String? {
        self == .auto ? nil : rawValue
    }
}
