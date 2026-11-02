import SwiftUI

@main
struct CorePlayerApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.auth)
                .environmentObject(container.settings)
                .environmentObject(container.player)
                .environmentObject(container.favorites)
                .environmentObject(container.recent)
                .environmentObject(container.searchHistory)
                .environment(\.api, container.api)
                .preferredColorScheme(.dark)
                .onAppear { container.start() }
        }
    }
}
