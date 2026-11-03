import Combine
import Foundation

/// Tracks whether lyrics should follow playback. Restoring from drag-idle also
/// covers SwiftUI cancelling a drag before `onEnded` is delivered.
final class LyricsFocusModel: ObservableObject {
    @Published private(set) var isAutoFocusActive = true

    private let restoreDelay: TimeInterval
    private var restoreJob: DispatchWorkItem?

    init(restoreDelay: TimeInterval = 2.5) {
        self.restoreDelay = restoreDelay
    }

    func userStartedScrolling() {
        isAutoFocusActive = false
        scheduleRestore()
    }

    func userFinishedScrolling() {
        scheduleRestore()
    }

    func restoreNow() {
        restoreJob?.cancel()
        isAutoFocusActive = true
    }

    private func scheduleRestore() {
        restoreJob?.cancel()
        let job = DispatchWorkItem { [weak self] in
            self?.isAutoFocusActive = true
        }
        restoreJob = job
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: job)
    }
}
