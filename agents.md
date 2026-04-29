# Play Cricket Live - Agent Instructions

## Project Overview

A Flutter app that live streams to YouTube with dynamic graphic overlays sourced from web data (e.g. cricket scores).

## Build & Verify

- Always verify changes compile: `flutter build apk`
- Run `flutter pub get` after dependency changes
- Run `flutter analyze` to check for errors (ignore pre-existing plugin example errors)

## Architecture

```
Website (scores) → HTTP scrape/parse → Data model → Flutter overlay widget
                                                          ↓
Camera/Mic → Composite (RepaintBoundary) → ffmpeg RTMP pipe → YouTube Live
```

## Core Components

### 1. YouTube Stream Service (`lib/services/youtube_live_service.dart`)
- OAuth 2.0 sign-in via `google_sign_in`
- Create broadcast + stream via YouTube Data API v3
- Bind stream to broadcast with `enableAutoStart: true`
- Return RTMP ingest URL

### 2. Play-Cricket Scraper (`lib/services/play_cricket_scraper.dart`)
- Fetches match data from play-cricket.com result URLs
- URL format: `https://<club>.play-cricket.com/website/results/<match_id>`
- Parses HTML to extract: team names, scores (runs/wickets), overs
- Uses regex fallback for score patterns like "166 / 4 (16.0)"
- Returns `MatchData` object with home/away team info
- Auto-refresh every 30 seconds via `Timer.periodic` in streaming screen

### 3. Stream Settings (`lib/services/stream_settings_service.dart`)
- Persists RTMP URL, stream key, and scorecard URL via `shared_preferences`
- Settings screen (`lib/screens/stream_settings_screen.dart`) has:
  - Play-Cricket match URL field with "Test URL" button
  - RTMP server URL and stream key fields

### 4. Graphic Overlay (`lib/widgets/cricket_score_overlay.dart`)
- Flutter widget rendered via `Stack` over camera preview
- Shows: batsmen (name, runs, balls), team score/overs, bowler figures
- Positioned at bottom of frame
- Updates reactively when scraped data changes

### 5. Stream Compositor (`lib/screens/streaming_screen.dart`)
- `RepaintBoundary` captures overlay as PNG
- Overlay applied to camera stream via `setFilter`
- Camera streaming via `rtmp_streaming` plugin to RTMP URL

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `google_sign_in` | Google OAuth |
| `googleapis` | YouTube Data API v3 |
| `http` | Web requests |
| `html` | HTML parsing (play-cricket scraping) |
| `rtmp_streaming` | Camera + RTMP streaming (local plugin) |
| `shared_preferences` | Settings persistence |
| `path_provider` | File system paths |

## Platform Notes

- **Android**: Camera source `-f android_camera -i 0`
- **iOS**: Camera source `-f avfoundation -i "0:0"`
- Both platforms require camera + microphone permissions
- YouTube API OAuth requires test users during development; full audit for production

## Data Flow for Overlays

1. User configures play-cricket match URL in settings screen
2. `PlayCricketScraper.fetchMatchData(url)` returns `MatchData`
3. `CricketScoreOverlay` widget renders scores as styled bar
4. `Timer.periodic` (30s) triggers re-fetch in streaming screen
5. `setState` rebuilds overlay; `_updateStreamOverlay()` re-captures PNG for stream

## Future Considerations

- Support multiple overlay layouts (scoreboard, lower-third, full-screen graphic)
- Add manual data entry fallback when scraping fails
- Support multiple data sources simultaneously
- Add stream health monitoring (bitrate, dropped frames)
- Pre-stream preview mode before going live
- Parse detailed scorecard (individual batsman/bowler figures) from play-cricket
