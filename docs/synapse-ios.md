# Synapse on iOS (0.1.0-b)

Reference implementation: current `../webplayer-mobile` Android client. Server remains responsible for recommendation ranking and learning; the same server/account shares the learned profile with Android and web. Each generated mix may differ. No backend changes are required.

Home places Synapse below the core header and above existing library sections. “Настроить” opens familiarity (familiar/unfamiliar/favorites) and optional mood (sad/productive/upbeat); “Подборка” opens tracks with reasons, covers and favorites. Refresh selects the returned first track while preserving play/pause, unless another queue was selected meanwhile. Catalog synchronization polls every five seconds. Errors can be retried.

Settings exposes continuation (on by default), profile reset with confirmation, rays/sphere and white/violet. Filter/appearance/continuation settings and pending event UUIDs are scoped to server/user in UserDefaults. Profile reset is server-side and shared with the other clients; it retains favorites. In-flight work uses frozen credentials and generation checks, including during reset/account switches.

Listening feedback includes start, skip, completion and successful favorites for owned exposures. Audible time excludes pauses, buffering, seek jumps and suspension gaps. Events are persisted before sending, in batches of up to 100; transient failures retain UUIDs, stale events are isolated. App-scoped observation continues independently of the visible Home screen. Naturally exhausted queues request 15 new tracks with queue IDs excluded; repeat modes/manual pause/changed queues prevent stale application. Existing engine, stream URLs, codecs, cache and seek routing remain in place; PlayerStore has additive queue identity/observation/refill hooks and a pause-preserving load option.

Animation uses MetalKit: static geometry and GPU vertex math, at most 30 fps; 2,000 sphere particles or up to 480 radial rays (800/180 on <=2GB memory). Count/speed use metadata BPM clamped 60–180 or the Android genre presets (170/135/80; fallback 110), not real-time audio analysis. Rays move outward without rotation. Rendering pauses when paused, hidden, covered, scrolled away, backgrounded, Reduce Motion or Low Power is enabled. Appearance changes still render a still frame.

Additional UI changes: equal tab bubble widths; title tap in Now Playing opens artist/album choices with artwork and detail navigation; centralized FIO cleanup handles Robert Plaudis without hiding legitimate unrelated English performers. Artist/album DTO fallbacks no longer reinsert removed credits.

## Verification

- `zsh scripts/run-logic-tests.sh`: existing parser/queue/stream/codec/playback/layout tests, artist regressions, Synapse contracts/listening and production store/API integration using a deterministic HTTP transport.
- `python3 scripts/check-synapse-renderer.py`: production geometry/BPM, Swift renderer initialization, Metal shader/pipeline compilation and GPU palette/alpha output on a Metal-capable Mac.
- GitHub Actions builds the unsigned iPhone IPA using XcodeGen and Xcode, because the local machine has Command Line Tools only.

Physical iPhone smoothness, background/lock transitions and native sheet layout require device testing; portable tests and GPU checks do not establish those properties. Unsigned IPA installation requires signing, as in previous builds.

Rollback baseline before this task: `5d62788`. Changes are separate commits; revert them through ordinary history without rewriting published commits.
