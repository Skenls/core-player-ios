# iOS Synapse implementation plan

**Goal:** Port the current Android Synapse to iOS, preserving the audio engine, and implement the requested navigation/credit fixes.
**Architecture:** App-scoped Synapse store with authenticated server API, account-scoped settings/outbox and listening coordinator. Native SwiftUI sheets and Metal GPU visualizer (30 fps, paused offscreen/in background).
**Reference:** ../webplayer-mobile SynapseRepository, ListeningTracker, SynapseCoordinator, SynapseSection and SynapseSphere.
**Constraints:** iOS 15; no dependencies; retain stream/seek/cache/codec logic; main branch authorized by conversation; no unrequested publishing.

- [x] Contract and store: add DTOs/API, filters, polling, persisted UUID outbox, server/user ownership, reset guards. Verify JSON and listening policy with portable Swift tests.
- [x] Playback integration: additive identity/queue/end hooks, pause-preserving refresh and guarded natural continuation; no engine/transport changes. Verify existing playback tests.
- [x] Metal renderer: static GPU geometry, outward rays + sphere, white/violet, metadata BPM/genre, pause/visibility/power controls. Review shader/Swift layout and parse source; CI compiles iOS target.
- [x] Home/settings: hero above library, primary wave button and white settings/list buttons, filter/list sheets, favorites/reasons and reset/appearance settings.
- [x] Ancillary UI: equal tab bubbles, safe FIO credit cleanup, title opens artist/album sheet with artwork and working detail links. Regression tests for credit filtering.
- [x] Verification: portable tests and syntax parsing locally; GitHub workflow iOS build where authorized/available; document limits honestly, commit all task changes.

Review focus: account switches during requests/reset; paused/buffering refresh; seeking excluded from listened time; stale refill after user changes queue; renderer stops when hidden.

Implementation and local checks complete. iOS SDK build tracked in GitHub Actions; results and physical-device limits are documented in docs/synapse-ios.md.
