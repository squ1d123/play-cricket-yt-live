# Play Cricket Live - Agent Instructions

## Project Overview

A Flutter app that live streams to YouTube with dynamic graphic overlays sourced from web data (e.g. cricket scores).

## Architecture

```
Website (scores) → HTTP scrape/parse → Data model → Flutter overlay widget
                                                          ↓
Camera/Mic → Composite (RepaintBoundary) → ffmpeg RTMP pipe → YouTube Live
```

## Core Components

### 1. YouTube Stream Service
- OAuth 2.0 sign-in via `google_sign_in`
- Create broadcast + stream via YouTube Data API v3
- Bind stream to broadcast with `enableAutoStart: true`
- Return RTMP ingest URL

### 2. Web Data Scraper
- Fetch HTML from target URL using `http` package
- Parse with `html` package using CSS selectors
- Return structured `Map<String, String>` of extracted data
- Auto-refresh on configurable interval (default 30s)

### 3. Graphic Overlay
- Flutter widget rendered via `Stack` over camera preview
- Styled broadcast-quality scoreboard/stats bar
- Positioned at bottom of frame
- Updates reactively when scraped data changes

### 4. Stream Compositor
- `RepaintBoundary` captures composited frames (camera + overlay)
- Frames piped to ffmpeg at 30fps as raw RGBA
- ffmpeg encodes H.264 + AAC and outputs FLV to RTMP URL

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `google_sign_in` | Google OAuth |
| `googleapis` | YouTube Data API v3 |
| `http` | Web requests |
| `html` | HTML parsing |
| `camera` | Camera preview |
| `ffmpeg_kit_flutter` | RTMP encoding/streaming |

## Platform Notes

- **Android**: Camera source `-f android_camera -i 0`
- **iOS**: Camera source `-f avfoundation -i "0:0"`
- Both platforms require camera + microphone permissions
- YouTube API OAuth requires test users during development; full audit for production

## Data Flow for Overlays

1. Define target URL and CSS selectors for desired data points
2. `WebScraper.fetchData()` returns key-value map
3. `ScoreOverlay` widget renders the map as a styled bar
4. `Timer.periodic` triggers re-fetch every N seconds
5. `setState` rebuilds overlay with fresh data

## Future Considerations

- Support multiple overlay layouts (scoreboard, lower-third, full-screen graphic)
- Add manual data entry fallback when scraping fails
- Support multiple data sources simultaneously
- Add stream health monitoring (bitrate, dropped frames)
- Pre-stream preview mode before going live
