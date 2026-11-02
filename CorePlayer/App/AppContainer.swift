import SwiftUI
import UIKit

@MainActor
final class AppContainer: ObservableObject {
    let api: APIClient
    let cache: TrackCache
    let settings: SettingsStore
    let auth: AuthStore
    let favorites: FavoritesStore
    let recent: RecentStore
    let searchHistory: SearchHistoryStore
    let player: PlayerStore

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "coreplayer.images"
        )
        let api = APIClient()
        let cache = TrackCache()
        let settings = SettingsStore()
        let favorites = FavoritesStore(api: api)
        let recent = RecentStore()
        self.api = api
        self.cache = cache
        self.settings = settings
        self.auth = AuthStore(api: api)
        self.favorites = favorites
        self.recent = recent
        self.searchHistory = SearchHistoryStore()
        self.player = PlayerStore(
            api: api,
            settings: settings,
            cache: cache,
            recent: recent
        )
        configureAppearance()
    }

    func start() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(CoreColors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.white
    }
}
