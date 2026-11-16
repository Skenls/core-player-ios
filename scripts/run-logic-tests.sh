#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/coreplayer-logic-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  -o "$OUT" \
  "$ROOT/CorePlayer/Core/AudioCodec.swift" \
  "$ROOT/CorePlayer/Core/Models.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseModels.swift" \
  "$ROOT/CorePlayer/Core/ArtistUtils.swift" \
  "$ROOT/CorePlayer/Core/LRCParser.swift" \
  "$ROOT/CorePlayer/Core/StreamURLBuilder.swift" \
  "$ROOT/CorePlayer/Playback/QueueState.swift" \
  "$ROOT/CorePlayer/Playback/TrackCache.swift" \
  "$ROOT/CorePlayer/Playback/PlaybackSeekRouter.swift" \
  "$ROOT/scripts/LogicTests.swift"

"$OUT"

FOCUS_OUT="${TMPDIR:-/tmp}/coreplayer-lyrics-focus-tests"
swiftc \
  -swift-version 5 \
  -parse-as-library \
  -o "$FOCUS_OUT" \
  "$ROOT/CorePlayer/Features/NowPlaying/LyricsFocusModel.swift" \
  "$ROOT/scripts/LyricsFocusTests.swift"

"$FOCUS_OUT"

ENGINE_OUT="${TMPDIR:-/tmp}/coreplayer-playback-engine-tests"
swiftc \
  -swift-version 5 \
  -parse-as-library \
  -framework AVFoundation \
  -o "$ENGINE_OUT" \
  "$ROOT/CorePlayer/Playback/PlayerEngine.swift" \
  "$ROOT/scripts/PlaybackEngineTests.swift"
"$ENGINE_OUT"

CACHE_OUT="${TMPDIR:-/tmp}/coreplayer-playback-cache-tests"
swiftc -swift-version 5 -parse-as-library -o "$CACHE_OUT" \
  "$ROOT/scripts/PlaybackCacheTests.swift"
"$CACHE_OUT" "$ROOT"

LAYOUT_OUT="${TMPDIR:-/tmp}/coreplayer-layout-tests"
swiftc -swift-version 5 -parse-as-library -o "$LAYOUT_OUT" \
  "$ROOT/scripts/LayoutTests.swift"
"$LAYOUT_OUT" "$ROOT"

ARTIST_OUT="${TMPDIR:-/tmp}/coreplayer-artist-tests"
swiftc -swift-version 5 -parse-as-library -o "$ARTIST_OUT" \
  "$ROOT/CorePlayer/Core/Models.swift" "$ROOT/CorePlayer/Core/ArtistUtils.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseModels.swift" "$ROOT/scripts/ArtistUtilsTests.swift"
"$ARTIST_OUT"

SYNAPSE_OUT="${TMPDIR:-/tmp}/coreplayer-synapse-tests"
swiftc -swift-version 5 -parse-as-library -o "$SYNAPSE_OUT" \
  "$ROOT/CorePlayer/Core/Models.swift" "$ROOT/CorePlayer/Core/ArtistUtils.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseModels.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseListeningTracker.swift" "$ROOT/scripts/SynapseTests.swift"
"$SYNAPSE_OUT"

STORE_OUT="${TMPDIR:-/tmp}/coreplayer-synapse-store-tests"
swiftc -swift-version 5 -parse-as-library -o "$STORE_OUT" \
  "$ROOT/CorePlayer/Core/APIClient.swift" "$ROOT/CorePlayer/Core/Models.swift" \
  "$ROOT/CorePlayer/Core/ArtistUtils.swift" "$ROOT/CorePlayer/Core/AudioCodec.swift" \
  "$ROOT/CorePlayer/Core/StreamURLBuilder.swift" "$ROOT/CorePlayer/Playback/QueueState.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseModels.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseListeningTracker.swift" \
  "$ROOT/CorePlayer/Features/Synapse/SynapseStore.swift" "$ROOT/scripts/SynapseStoreTests.swift"
"$STORE_OUT"
