# Streaming and Server-Side Seeking

Applies to Core Player iOS **v0.0.4-b**. ALAC support was removed: `format=alac` is no longer requested and ALAC is absent from Settings.

AAC is the default lossy transcode used for FLAC/auto seeks. The same `timeOffset` mechanism is used for remote MP3 and FLAC sources because direct-play FLAC ignores the offset and MP3 transcodes can seek only inside the downloaded buffer.

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
- The bridge support is in `core-player` commit `2d3cb7a`; integer forwarding is fixed in `b721fc1`. The deployed bridge must be updated and restarted.

## iOS seeking behavior

Server-offset restart applies when the current item is remote and the user releases the scrubber. Locally cached files use normal `AVPlayer.seek` and work offline.

The seek relaunch must request a transcoded format different from the source suffix. Otherwise Navidrome can choose direct play and ignore `timeOffset`.

| Source suffix | Selected codec | Seek stream |
|---|---|---|
| flac | auto / flac | AAC |
| flac | aac | AAC |
| flac | mp3 | MP3 |
| mp3 | auto / mp3 | AAC |
| mp3 | aac | AAC |
| aac / m4a | auto / aac | MP3 |
| unknown | auto | AAC |

For a remote seek to `t`:

1. `PlaybackSeekRouter` chooses the seek codec and integer offset `Int(t)`;
2. `PlayerStore` pauses the old item and replaces it with a new offset stream;
3. the scrubber is released only after the new item becomes ready;
4. absolute playback position is reported as:

```text
position = streamOffset + AVPlayer.currentTime
```

The original track duration is retained, so the progress bar does not shrink to the remaining offset-stream duration. Seeking again requests a new offset from the absolute target. Reaching the end still triggers repeat/next normally.

### Bridge requirement

The bridge must forward an **integer** string. FastAPI's `float | int` query type produces `"85.0"`, which Navidrome's integer parser ignores:

```python
params["timeOffset"] = str(int(timeOffset))
```

Without this cast, every remote seek silently starts at zero even though the app requested an offset.

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

Verify the bridge log contains `timeOffset: '85'`, not `'85.0'`.

Expected: `200 OK`, `Content-Type: audio/aac`, and `Accept-Ranges: bytes`. The media payload starts at approximately 85 seconds.

## Tests

- `StreamURLBuilder` includes `format=aac` and integer `timeOffset`.
- Offset URLs omit `estimateContentLength`.
- `PlaybackSeekRouter` sends every remote seek to an offset stream and never picks the source codec for that transcode.
- `PlayerEngine` reports `streamOffset + currentTime` and keeps the known total duration.
- Cache-extension tests cover ADTS `audio/aac` and MP4 `audio/mp4`.

## Constraints

- Opus/Ogg is not supported by AVPlayer and is unchanged.
- ALAC was removed in v0.0.3-b; stored old ALAC selections decode to Auto.
- ALAC-specific Navidrome transcoding setup is no longer required by this app.
