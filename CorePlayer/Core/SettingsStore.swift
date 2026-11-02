import Foundation

enum PlayerBackground: String, CaseIterable, Identifiable, Hashable {
    case cover
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cover: return "Под обложку"
        case .dark: return "Тёмный"
        }
    }

    var detail: String {
        switch self {
        case .cover: return "Размытая обложка"
        case .dark: return "Обычный фон"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var codec: AudioCodec {
        didSet { defaults.set(codec.rawValue, forKey: Keys.codec) }
    }

    @Published var background: PlayerBackground {
        didSet { defaults.set(background.rawValue, forKey: Keys.background) }
    }

    @Published var adaptiveBubble: Bool {
        didSet { defaults.set(adaptiveBubble, forKey: Keys.adaptiveBubble) }
    }

    @Published var amoled: Bool {
        didSet { defaults.set(amoled, forKey: Keys.amoled) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let codec = "coreplayer.codec"
        static let background = "coreplayer.background"
        static let adaptiveBubble = "coreplayer.adaptiveBubble"
        static let amoled = "coreplayer.amoled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.codec = AudioCodec(rawValue: defaults.string(forKey: Keys.codec) ?? "") ?? .auto
        self.background = PlayerBackground(rawValue: defaults.string(forKey: Keys.background) ?? "") ?? .cover
        self.adaptiveBubble = defaults.object(forKey: Keys.adaptiveBubble) as? Bool ?? true
        self.amoled = defaults.object(forKey: Keys.amoled) as? Bool ?? false
    }
}
