# AAC offset seeking and v0.0.3-b

> **For agentic workers:** implement with TDD in the current workspace. The user explicitly requested commits and tags on `main`; do not create a worktree or PR.

**Goal:** When AAC is selected and the current track is remote, every seek restarts the stream through `timeOffset`, while the UI timeline remains absolute. Remove ALAC. Release v0.0.3-b.

## Global constraints
- No ALAC in the enum, settings, URLs, tests, or docs.
- `timeOffset` is an integer number of seconds; offset relaunches omit `estimateContentLength`.
- Local cached tracks keep fast local seeking even when AAC is selected.
- Preserve the known track duration when an offset stream starts at zero.
- Existing non-AAC seeking behavior must not change.

### Task 1: URL builder and codec surface
- [ ] Add failing tests for AAC `timeOffset`, omitted estimate on offset, and ALAC absence.
- [ ] Add `timeOffset` through `StreamURLBuilder` and `APIClient`.
- [ ] Remove `.alac` from `AudioCodec` and its user-visible cases.
- [ ] Run `./scripts/run-logic-tests.sh`.

### Task 2: Absolute timeline for offset streams
- [ ] Add a failing engine test that `load(startOffset:)` reports offset-based time.
- [ ] Add `startOffset` to `PlayerEngine.load`; add it to time reports and seek completions.
- [ ] Keep item duration raw; PlayerStore owns the known total.
- [ ] Run engine tests.

### Task 3: AAC seek routing and duration
- [ ] Add failing tests for the AAC seek policy.
- [ ] Route remote AAC seeks to an offset stream relaunch; local tracks use `AVPlayer.seek`.
- [ ] Suppress duration replacement while an offset stream is active.
- [ ] Complete pending seek callbacks on ready/error and preserve absolute position.
- [ ] Run all tests.

### Task 4: Docs and version
- [ ] Remove ALAC references; document AAC `timeOffset` seeking.
- [ ] Set `CFBundleShortVersionString` to `0.0.3-b` and `CFBundleVersion` to `3`.
- [ ] Validate docs/code consistency.

### Task 5: Release
- [ ] Run full tests, Swift parse, XcodeGen, diff check.
- [ ] Commit and push `main`.
- [ ] Tag `v0.0.3-b` and push the tag.
- [ ] Wait for tag CI/release, download IPA to `build/CorePlayer.ipa`, verify metadata and SHA-256.
