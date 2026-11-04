# AAC Streaming and Offset Seeking

Applies to Core Player iOS **v0.0.3-b**. ALAC support was removed: `format=alac` is no longer requested and ALAC is absent from Settings.

## Codec

| Parameter | Value |
|---|---|
| API format | `aac` |
| Encoding | AAC-LC, lossy |
| Container | ADTS |
| Typical bitrate | 192–320 kbps |
| Cache extension | `.aac` (`audio/aac`); direct-pass MP4 remains `.m4a` |
| iOS playback | AVPlayer |

## Stream endpoint

```http
GET /api/stream/{track_id}?format=aac&session_id=...
```

For a server-side seek:

```http
GET /api/stream/{track_id}?format=aac&timeOffset=85&session_id=...
```

- `timeOffset` is an integer number of seconds.
- The bridge forwards it to Navidrome, where FFmpeg starts with `-ss <offset>`.
- Offset requests do **not** send `estimateContentLength`: an estimated length makes transcoded duration unreliable.
- Normal AAC requests keep the existing `estimateContentLength=true` behavior.
- The bridge support is in `core-player` commit `2d3cb7a` (`feat(stream): support timeOffset parameter for transcoded audio seeking`).

## iOS seeking behavior

AAC restart applies only when all of these are true:

1. the effective selected codec is AAC;
2. the current item is remote;
3. the user releases the scrubber.

The local cached AAC file uses normal `AVPlayer.seek` and works offline. Other codecs keep normal byte-range seeking.

For a remote AAC seek to `t`:

1. `PlayerStore` requests offset `Int(t)` using `timeOffset`;
2. replaces the current `AVPlayerItem` with a new asset;
3. releases the scrubber only after the new item becomes ready;
4. reports absolute playback position as:

```text
position = streamOffset + AVPlayer.currentTime
```

The original track duration is retained, so the progress bar does not shrink to the remaining offset-stream duration. Seeking again requests a new offset from the absolute target. Reaching the end still triggers repeat/next normally.

## cURL checks

Normal AAC stream:

```bash
curl -I -H "Cookie: session_id=YOUR_SESSION" \
  "http://localhost:3000/api/stream/TRACK_ID?format=aac"
```

AAC stream starting at 1:25:

```bash
curl -I -H "Cookie: session_id=YOUR_SESSION" \
  "http://localhost:3000/api/stream/TRACK_ID?format=aac&timeOffset=85"
```

Expected: `200 OK`, `Content-Type: audio/aac`, and `Accept-Ranges: bytes`. The media payload starts at approximately 85 seconds.

## Tests

- `StreamURLBuilder` includes `format=aac` and integer `timeOffset`.
- Offset URLs omit `estimateContentLength`.
- `PlaybackSeekRouter` sends only remote AAC seeks to offset streams.
- `PlayerEngine` reports `streamOffset + currentTime` and keeps the known total duration.
- Cache-extension tests cover ADTS `audio/aac` and MP4 `audio/mp4`.

## Constraints

- Opus/Ogg is not supported by AVPlayer and is unchanged.
- ALAC was removed in v0.0.3-b; stored old ALAC selections decode to Auto.
- ALAC-specific Navidrome transcoding setup is no longer required by this app.
