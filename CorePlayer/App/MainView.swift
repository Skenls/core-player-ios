import SwiftUI
import Combine

struct MainView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var recent: RecentStore

    @State private var selected: AppTab = .home
    @State private var showNowPlaying = false

    var body: some View {
        ZStack {
            tab(.home) { HomeView() }
            tab(.search) { SearchView() }
            tab(.browse) { BrowseView() }
            tab(.library) { LibraryView() }
        }
        .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
        // Reserve layout space so every scroll view can reach its last row above the player.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                MiniPlayerView(openPlayer: { showNowPlaying = true })
                CoreTabBar(selection: $selected)
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
        .onAppear {
            Task { await favorites.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .corePlayerDidLogin)) { _ in
            Task { await favorites.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .corePlayerDidLogout)) { _ in
            showNowPlaying = false
            selected = .home
            favorites.clear()
            recent.clear()
        }
    }

    @ViewBuilder
    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationView {
            content()
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .opacity(selected == tab ? 1 : 0)
        .allowsHitTesting(selected == tab)
        .zIndex(selected == tab ? 1 : 0)
    }
}
