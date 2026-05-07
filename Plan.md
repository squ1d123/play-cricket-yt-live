# Native Android Rewrite — Play Cricket Live

## Overview

Rewrite the Flutter-based cricket live streaming app as a native Android app using Kotlin + Gradle, buildable entirely from the command line. The app streams camera video with a cricket score overlay to YouTube Live, pulling live score data from the Play-Cricket/ResultsVault API.

## Architecture

- **Language:** Kotlin
- **Build:** Gradle (CLI: `./gradlew assembleDebug`)
- **UI:** Jetpack Compose
- **Streaming:** RootEncoder 2.7.2 (Camera2 + RTMP + OpenGL overlays)
- **HTTP:** OkHttp
- **YouTube API:** Google API Client Library for Java
- **Auth:** Google Identity Services (play-services-auth)
- **Persistence:** SharedPreferences
- **Crypto:** javax.crypto (3DES-ECB for ResultsVault token)

## Component Diagram

```
MainActivity (Compose)
├── HomeScreen → Start Streaming / Settings
├── SettingsScreen → StreamSettingsRepository (SharedPreferences)
│   └── YouTubeLiveService (Google Sign-In)
└── StreamingActivity (Landscape, Immersive)
    ├── RtmpCamera2 (RootEncoder) → RTMP to YouTube
    ├── ScoreOverlayRenderer (Canvas → Bitmap → ImageObjectFilterRender)
    ├── PlayCricketScraper (OkHttp + 3DES) → Score data every 30s
    └── YouTubeLiveService → Create broadcast + get RTMP URL
```

## Tasks

- [x] **Task 1:** Project scaffolding and CLI build verification
- [x] **Task 2:** Settings persistence and settings screen
- [x] **Task 3:** Play-Cricket scraper service (Kotlin port)
- [x] **Task 4:** YouTube Live service with Google Sign-In
- [x] **Task 5:** Camera preview and RTMP streaming with RootEncoder
- [x] **Task 6:** Score overlay rendered directly onto video stream
- [x] **Task 7:** Wire everything together and polish

---

## Task 1: Project Scaffolding

**Objective:** Create a native Android project structure, verify it compiles from CLI.

**Deliverables:**
- Fresh Gradle project in project root (replace Flutter structure)
- `build.gradle.kts` with all dependencies declared
- `AndroidManifest.xml` with permissions (CAMERA, RECORD_AUDIO, INTERNET)
- Minimal `MainActivity` with Compose showing home screen
- `./gradlew assembleDebug` produces a valid APK

**Dependencies (build.gradle.kts):**
```kotlin
// RootEncoder
implementation("com.github.pedroSG94.RootEncoder:library:2.7.2")

// Jetpack Compose
implementation(platform("androidx.compose:compose-bom:2024.02.00"))
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.material3:material3")
implementation("androidx.activity:activity-compose:1.8.2")

// Google Sign-In + YouTube API
implementation("com.google.android.gms:play-services-auth:21.0.0")
implementation("com.google.api-client:google-api-client-android:2.2.0")
implementation("com.google.apis:google-api-services-youtube:v3-rev20240514-2.0.0")

// HTTP
implementation("com.squareup.okhttp3:okhttp:4.12.0")

// JSON
implementation("org.json:json:20231013")
```

---

## Task 2: Settings Persistence & Screen

**Objective:** SharedPreferences storage + Compose settings UI.

**Settings stored:**
- `scorecard_url` (String) — Play-Cricket match URL
- `bitrate` (Int) — streaming bitrate in bps
- `resolution` (Int) — index into resolution presets
- `video_encoder` (String) — "h264" / "h265" / "av1"
- `yt_account_email` (String) — signed-in YouTube account

**Presets:**
- Bitrate: 6/8/12/15/20 Mbps
- Resolution: 720p, 1080p, 1440p, 4K
- Encoder: H264 (default), H265, AV1

---

## Task 3: Play-Cricket Scraper

**Objective:** Port ResultsVault API client to Kotlin.

**Key components:**
- 3DES-ECB token generation (shared secret: `5BD4A72CE1934BA5A629CD98`)
- Match ID extraction from URL regex
- External→internal match ID mapping via `/rv/mappings/4/12/{id}/`
- Match data fetch via `/rv/130000/matches/{id}/`
- Ball-by-ball current bowler detection via `action=getballs`
- Smart innings logic (determine who's currently batting)

**Data classes:**
- `MatchData` (teams, scores, overs, batsmen, bowlers, batting/bowling context)
- `BatsmanData` (name, runs, balls, notOut)
- `BowlerData` (bowlerId, name, wickets, runs, overs)

---

## Task 4: YouTube Live Service

**Objective:** Google Sign-In + YouTube broadcast creation.

**Flow:**
1. Google Sign-In → get OAuth token
2. Create LiveBroadcast (autoStart, autoStop, configured privacy)
3. Create LiveStream (configured resolution + 60fps + RTMP)
4. Bind stream to broadcast
5. Return `{ingestionUrl}/{streamName}` as RTMP URL

---

## Task 5: Camera + RTMP Streaming

**Objective:** RootEncoder camera preview + RTMP streaming.

**Implementation:**
- `StreamingActivity` locked to landscape, immersive mode
- `RtmpCamera2` with `OpenGlView` for preview
- Configure: resolution, bitrate, encoder (H264/H265/AV1), 60fps
- Camera switching (front/back picker)
- Zoom control (slider)
- Keep screen on (`FLAG_KEEP_SCREEN_ON`)
- Stream status indicator (LIVE/OFFLINE)

---

## Task 6: Score Overlay

**Objective:** Render scoreboard as Bitmap, apply via OpenGL filter.

**Layout (bottom bar, full width):**
```
[🏏 Batsman1 42(30)] [Batsman2 25(20)]  |  150/3  |  Bowler 2/30 (4)
                                         | 15.2 ov |
```

**Implementation:**
- `ScoreOverlayRenderer` class
- Draw to `Bitmap` using `Canvas` + `TextPaint`
- Apply via `ImageObjectFilterRender` at bottom of stream
- Update bitmap every 30s when score data refreshes
- Toggle visibility on/off

---

## Task 7: Integration & Polish

**Objective:** Wire all components, handle errors, lifecycle.

**Checklist:**
- Navigation: Home → Settings, Home → Streaming
- Score refresh timer (30s periodic)
- Error handling: no internet, API failures, camera permission denied
- Lifecycle: stop stream on back press, release camera on destroy
- Overlay toggle button
- YouTube account display in settings
- Test URL button in settings (fetch + display score)
