# Audio Codecs Streaming Specification: AAC-LC & ALAC

This document outlines the technical architecture, API integration, and playback capabilities (playback, seeking, caching, performance) for **AAC-LC** and **ALAC** streams in the Core Player ecosystem.

---

## 1. Overview & Codec Characteristics

| Metric / Parameter | **AAC-LC** (Advanced Audio Coding - Low Complexity) | **ALAC** (Apple Lossless Audio Codec) |
| :--- | :--- | :--- |
| **API Parameter** | `format=aac` | `format=alac` |
| **MIME Type** | `audio/aac` | `audio/mp4` |
| **Container** | ADTS (`Audio Data Transport Stream`) | Fragmented MP4 (`fMP4` / ISO BMFF) |
| **Compression** | Lossy (Perceptual acoustic model) | Lossless (Exact bit-for-bit reproduction) |
| **Typical Bitrate** | 192 kbps – 320 kbps | 600 kbps – 1400+ kbps (dynamic based on track) |
| **Transcoding CPU Overhead** | Low (~0.05 – 0.1 CPU core per stream) | Ultra-low (Lossless encoding is faster than lossy) |
| **Target Clients** | Mobile (`core-player-android`), Cellular data | Hi-Fi / Audiophile clients, High-bandwidth WiFi |

---

## 2. API Endpoints

### 2.1 Audio Stream (`GET`)

```http
GET /api/stream/{track_id}?format={codec}&estimateContentLength=true
```

#### Query Parameters:
- `track_id` (path, required): Unique identifier of the track in Navidrome.
- `format` (query, optional): Target audio encoding.
  - `aac`: Stream transcode/raw to AAC-LC.
  - `alac`: Stream transcode/raw to ALAC.
  - `opus`: Opus audio.
  - `mp3`: MP3 audio.
  - `flac`: FLAC lossless.
  - `raw`: Original uncompressed/untranscoded file.
- `estimateContentLength` (query, optional, default `true`): Allows the server to approximate content length for seek bar calculations when transcoding.

#### Request Headers:
- `Cookie: access_token=...` or `Authorization: Bearer <token>`: User authentication session.
- `Range: bytes={start}-{end}` (optional): HTTP range request for seeking/scrubbing.

#### Response Headers:
- `HTTP/1.1 200 OK` (full stream) or `HTTP/1.1 206 Partial Content` (range response).
- `Content-Type`: `audio/aac` for AAC, `audio/mp4` for ALAC.
- `Accept-Ranges: bytes`: Indicates partial request support.
- `Content-Range: bytes start-end/total` (when `Range` header was sent).
- `X-Content-Duration: {seconds}`: Total duration of the track in seconds.

---

### 2.2 Metadata Probing (`HEAD`)

```http
HEAD /api/stream/{track_id}?format={codec}
```

The Core Player API supports HTTP `HEAD` method. This allows media players (such as Android ExoPlayer / Media3) to probe headers, verify `Content-Type`, validate authentication, and inspect `Accept-Ranges` without downloading audio payload.

---

## 3. Playback Capabilities

### 3.1 Seamless Playback & Zero-Copy Proxying
When deployed with Nginx (production / Docker), Core Player utilizes `X-Accel-Redirect`:
1. The client requests `/api/stream/{track_id}?format=alac`.
2. Core Player backend authenticates the user, resolves track credentials, and issues an internal redirect to Nginx.
3. Nginx directly streams the audio pipeline from Navidrome via kernel space zero-copy buffers (`sendfile`), resulting in minimal Python process memory footprint.

### 3.2 Seeking and Scrubbing
Fast, responsive seeking is essential for mobile and desktop clients:
- **Range Requests (`bytes=...`)**:
  - Both AAC and ALAC endpoints fully support `Range` headers.
  - When the user scrubs the progress bar in the player, the client emits an HTTP request with `Range: bytes={byte_offset}-`.
  - The server answers with `HTTP 206 Partial Content` containing only the requested audio segment.
- **ALAC Fast Seeking (Fragmented MP4)**:
  - Because ALAC is encapsulated with `-movflags +frag_keyframe+empty_moov+default_base_moof`, the stream contains self-contained movie fragments (`moof` + `mdat`).
  - Media engines (such as Android ExoPlayer) can instantly seek to keyframe fragments without waiting to download the end of the file.
- **AAC-LC Fast Seeking (ADTS)**:
  - ADTS provides sync words (`0xFFF`) at the beginning of each audio frame, enabling media decoders to resume playback at arbitrary offsets.

### 3.3 Dynamic Transcoding vs. Direct Passthrough
- **Direct Passthrough (Zero CPU)**:
  If the source file in your media storage is already in ALAC format (`.m4a`) or AAC (`.aac` / `.m4a`), Navidrome streams the original bits directly without invoking FFmpeg.
- **On-the-fly Transcoding**:
  If the source file is FLAC, WAV, or any other format:
  - **AAC**: Transcoded via Navidrome's built-in pipeline (`-c:a aac -f adts`).
  - **ALAC**: Transcoded via the custom profile (`-c:a alac -f mp4 -movflags +frag_keyframe+empty_moov+default_base_moof`).

---

## 4. Client Integration Guides

### 4.1 Android Integration (`core-player-android` / ExoPlayer / Media3)

In your Android application using AndroidX Media3 (`ExoPlayer`):

```kotlin
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource

// 1. Build HTTP Data Source with user session cookie / bearer token
val dataSourceFactory = DefaultHttpDataSource.Factory()
    .setUserAgent("CorePlayerAndroid/1.0")
    .setDefaultRequestProperties(mapOf(
        "Cookie" to "access_token=$userToken"
    ))

// 2. Select preferred codec based on network conditions
val codecFormat = if (isWifiConnected) "alac" else "aac"
val mimeType = if (codecFormat == "alac") MimeTypes.AUDIO_MP4 else MimeTypes.AUDIO_AAC

// 3. Create MediaItem with explicit MimeType hint
val streamUrl = "https://your-player-domain.com/api/stream/$trackId?format=$codecFormat"

val mediaItem = MediaItem.Builder()
    .setUri(streamUrl)
    .setMimeType(mimeType)
    .build()

val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
    .createMediaSource(mediaItem)

// 4. Set media source to player
player.setMediaSource(mediaSource)
player.prepare()
player.play()
```

### 4.2 cURL CLI Verification Examples

#### Test AAC-LC Stream:
```bash
curl -I -H "Cookie: access_token=YOUR_TOKEN" \
  "http://localhost:3000/api/stream/TRACK_ID?format=aac"
```
*Expected Output:*
```http
HTTP/1.1 200 OK
Content-Type: audio/aac
Accept-Ranges: bytes
```

#### Test ALAC Stream:
```bash
curl -I -H "Cookie: access_token=YOUR_TOKEN" \
  "http://localhost:3000/api/stream/TRACK_ID?format=alac"
```
*Expected Output:*
```http
HTTP/1.1 200 OK
Content-Type: audio/mp4
Accept-Ranges: bytes
```

#### Test Range Request (Seeking from 1MB):
```bash
curl -i -H "Cookie: access_token=YOUR_TOKEN" \
  -H "Range: bytes=1048576-" \
  "http://localhost:3000/api/stream/TRACK_ID?format=alac"
```
*Expected Output:*
```http
HTTP/1.1 206 Partial Content
Content-Type: audio/mp4
Content-Range: bytes 1048576-.../...
```

---

## 5. Server Architecture Requirements

To serve ALAC streams on remote servers, ensure Navidrome has transcoding enabled:
1. `EnableTranscodingConfig = true` in `/etc/navidrome/navidrome.toml` (or `ND_ENABLETRANSCODINGCONFIG=true` in Docker environment).
2. Transcoding Profile registered in Navidrome:
   - **Name**: `alac audio`
   - **Target Format**: `alac`
   - **Command**:
     ```bash
     ffmpeg -ss %t -i %s -map 0:a:0 -map_metadata 0 -map_metadata 0:s:a:0 -v 0 -c:a alac -f mp4 -movflags +frag_keyframe+empty_moov+default_base_moof -
     ```
   - **Default Bit Rate**: `0`
