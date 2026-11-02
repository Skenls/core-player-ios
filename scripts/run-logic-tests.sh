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
  "$ROOT/CorePlayer/Core/ArtistUtils.swift" \
  "$ROOT/CorePlayer/Core/LRCParser.swift" \
  "$ROOT/CorePlayer/Core/StreamURLBuilder.swift" \
  "$ROOT/CorePlayer/Playback/QueueState.swift" \
  "$ROOT/scripts/LogicTests.swift"

"$OUT"
