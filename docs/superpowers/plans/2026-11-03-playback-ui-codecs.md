# Playback, Lyrics, Mini-player, and Codec Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the reported lyrics, bottom-overlap, playback-stalling, and scrubbing regressions and add AAC-LC/ALAC support.

**Architecture:** Keep the existing SwiftUI/AVPlayer structure. Remove duplicate current-track traffic, prefetch the next track only after AVPlayer reports healthy buffering, reserve the mini-player through the existing safe-area layout, and drive lyrics/scrubbing from actual gesture and seek state rather than arbitrary delays.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Foundation CLI assertion tests, XcodeGen/GitHub Actions for device builds.

**Spec:** `AUDIO_CODECS_SPECIFICATION.md`; user-approved direction in the 2026-11-03 conversation.

## Global Constraints

- iOS 15+, iPhone, no new dependencies, no Opus or crossfade.
- AAC uses `format=aac`; ALAC uses `format=alac`; both include `estimateContentLength=true`.
- Keep the existing Russian UI and Android-style bottom layout.
- Do not modify or commit the user's untracked specification beyond using it as input.
- Local device UI/runtime verification is unavailable without Xcode.app; run CLI tests, Swift parsing, and CI.

## Review Focus

- A cancelled lyrics drag must still restore focus and blur after 2.5 seconds of inactivity.
- Long album, artist, playlist, and tab lists must scroll clear of the mini-player without per-screen magic padding.
- Starting a track must not simultaneously download that same track again for cache.
- A seek must keep the selected UI position until AVPlayer finishes or interrupts that seek.
- AAC ADTS and ALAC MP4 cache files must use extensions AVPlayer can open locally.

---

### Task 1: AAC-LC and ALAC codec support

**Files:**
- Modify: `CorePlayer/Core/AudioCodec.swift`
- Modify: `CorePlayer/Playback/TrackCache.swift`
- Modify: `CorePlayer/Features/Settings/SettingsView.swift` only if automatic enumeration is insufficient
- Test: `scripts/LogicTests.swift`, `scripts/run-logic-tests.sh`

- [ ] Add failing assertions for `.aac`/`.alac` query values, titles, stream URLs, and `audio/aac` → `aac` / `audio/mp4` → `m4a` cache extensions.
- [ ] Run `./scripts/run-logic-tests.sh`; confirm the new cases fail because the cases/API are absent or AAC currently maps to `m4a`.
- [ ] Add `aac` and `alac` enum cases and the minimal MIME-extension correction; the existing settings `ForEach(AudioCodec.allCases)` should expose them automatically.
- [ ] Re-run the full CLI suite and confirm all tests pass.

### Task 2: Lyrics focus restoration

**Files:**
- Create: `CorePlayer/Features/NowPlaying/LyricsFocusModel.swift`
- Modify: `CorePlayer/Features/NowPlaying/SyncedLyricsView.swift`
- Create: `scripts/LyricsFocusTests.swift`
- Modify: `scripts/run-logic-tests.sh`

**Interfaces:**
- Produces: `@MainActor final class LyricsFocusModel: ObservableObject` with `@Published private(set) var isAutoFocusActive`, `userStartedScrolling()`, `userFinishedScrolling()`, and `restoreNow()`.

- [ ] Write a failing timing test where scrolling starts but no successful `onEnded` arrives; focus must nevertheless return after the restore delay.
- [ ] Run the test and confirm it fails against the missing/incorrect behavior.
- [ ] Implement one cancellable 2.5-second restore job refreshed by scroll activity, with `restoreNow()` for lyric taps.
- [ ] Connect focus restoration to an immediate scroll-to-active-line and rerun the timing test plus full suite.

### Task 3: Scrubber completion state

**Files:**
- Modify: `CorePlayer/Playback/PlayerEngine.swift`
- Modify: `CorePlayer/Playback/PlayerStore.swift`
- Modify: `CorePlayer/Features/NowPlaying/NowPlayingProgress.swift`

**Interfaces:**
- `PlayerEngine.seek(to:completion:)` invokes completion on the main queue for both finished and interrupted seeks.
- `PlayerStore.seek(_:completion:)` preserves all existing callers through a default `nil` completion.

- [ ] Add a failing AVFoundation test proving the seek completion is called and reports the resulting engine time.
- [ ] Replace the fixed 0.15-second UI release with the actual seek completion callback, keeping the selected position visible throughout the seek.
- [ ] Run playback tests, logic tests, and Swift parsing.

### Task 4: Playback buffering and prefetch regression

**Files:**
- Modify: `CorePlayer/Playback/PlayerEngine.swift`
- Modify: `CorePlayer/Playback/PlayerStore.swift`

**Interfaces:**
- Produces: `PlayerEngine.onPlaybackLikelyToKeepUp: (() -> Void)?` for the current item's healthy-buffer transition.

- [ ] Add a failing source-level regression check or focused test proving `loadCurrent` does not prefetch its current track and next prefetch is not launched inline during startup.
- [ ] Remove current-track prefetch; restore automatic forward buffering (`preferredForwardBufferDuration = 0`); prefetch only the next track once the current item is likely to keep up, once per track.
- [ ] Run all local tests and parse all Swift sources.

### Task 5: Mini-player layout and documentation

**Files:**
- Modify: `CorePlayer/App/MainView.swift`
- Modify screens containing manual `.padding(.bottom, 120)` compensation
- Modify: `DOCS.md` and this plan's checkboxes

- [ ] Add a failing structural check that the mini-player is in `safeAreaInset`, not an overlay, and no screen carries the obsolete 120-point compensation.
- [ ] Put the mini-player and tab bar in the bottom safe-area inset, remove obsolete per-screen padding, and verify all scroll screens inherit the inset.
- [ ] Update codec, buffering, seek, lyrics, and layout documentation.
- [ ] Run the complete verification suite, review the diff, and report device-only checks separately.
