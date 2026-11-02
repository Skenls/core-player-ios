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
        // Floating bubble (Telegram-style) above a solid bottom tab bar.
        .overlay(alignment: .bottom) {
            MiniPlayerView(openPlayer: { showNowPlaying = true })
                .padding(.bottom, 4)
                .zIndex(2)
        }
        .safeAreaInset(edge: .bottom) {
            CoreTabBar(selection: $selected)
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
