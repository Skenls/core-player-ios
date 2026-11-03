import Combine
import Foundation

@main
struct LyricsFocusTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            print("  ok  \(message)")
        } else {
            failures += 1
            print("  FAIL \(message)")
        }
    }

    static func wait(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    @MainActor
    static func main() {
        print("LyricsFocusModel")

        let noEnded = LyricsFocusModel(restoreDelay: 0.12)
        expect(noEnded.isAutoFocusActive, "starts focused")
        noEnded.userStartedScrolling()
        expect(!noEnded.isAutoFocusActive, "manual scroll suspends focus")
        wait(0.2)
        expect(noEnded.isAutoFocusActive, "restores focus even when onEnded never arrives")

        let refreshed = LyricsFocusModel(restoreDelay: 0.12)
        refreshed.userStartedScrolling()
        wait(0.07)
        refreshed.userStartedScrolling()
        wait(0.08)
        expect(!refreshed.isAutoFocusActive, "continued scrolling refreshes the restore delay")
        wait(0.08)
        expect(refreshed.isAutoFocusActive, "focus returns after scrolling stops")

        let ended = LyricsFocusModel(restoreDelay: 0.05)
        ended.userStartedScrolling()
        ended.userFinishedScrolling()
        wait(0.1)
        expect(ended.isAutoFocusActive, "successful end also restores focus")

        let tapped = LyricsFocusModel(restoreDelay: 10)
        tapped.userStartedScrolling()
        tapped.restoreNow()
        expect(tapped.isAutoFocusActive, "lyric tap restores focus immediately")

        if failures > 0 {
            print("\(failures) lyrics focus test(s) failed")
            exit(1)
        }
        print("All lyrics focus tests passed.")
    }
}
