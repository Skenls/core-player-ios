import Foundation

@main
struct LayoutTests {
    static var failures = 0

    static func check(_ ok: Bool, _ name: String) {
        print(ok ? "PASS \(name)" : "FAIL \(name)")
        if !ok { failures += 1 }
    }

    static func source(_ root: String, _ path: String) -> String {
        (try? String(contentsOfFile: root + "/" + path, encoding: .utf8)) ?? ""
    }

    static func main() {
        let root = CommandLine.arguments[1]
        let main = source(root, "CorePlayer/App/MainView.swift")
        check(main.contains("safeAreaInset(edge: .bottom") && main.contains("MiniPlayerView"),
              "mini-player participates in bottom layout")
        check(!main.contains(".overlay(alignment: .bottom)"), "mini-player is not an overlay")

        let screens = [
            "CorePlayer/Features/Home/HomeView.swift",
            "CorePlayer/Features/Search/SearchView.swift",
            "CorePlayer/Features/Browse/BrowseView.swift",
            "CorePlayer/Features/Library/LibraryView.swift",
            "CorePlayer/Features/Browse/AlbumDetailView.swift",
            "CorePlayer/Features/Browse/ArtistDetailView.swift",
            "CorePlayer/Features/Library/PlaylistDetailView.swift",
        ]
        for screen in screens {
            check(!source(root, screen).contains("padding(.bottom, 120)"),
                  "no hard-coded player padding in \(screen)")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
