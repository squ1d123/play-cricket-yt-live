# Play Cricket Live

Native Android app for live streaming cricket matches to YouTube with real-time score overlays from Play-Cricket.

## Prerequisites

- Android SDK (command-line tools)
- JDK 17+
- `ANDROID_HOME` environment variable set

## Setup

### 1. Generate signing keystore

```bash
keytool -genkey -v \
  -keystore release-key.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias playcricketlive \
  -dname "CN=Play Cricket Live, O=yourname, L=London, C=GB" \
  -storepass YOUR_PASSWORD \
  -keypass YOUR_PASSWORD
```

### 2. Create `app/keystore.properties`

```properties
storeFile=../release-key.jks
storePassword=YOUR_PASSWORD
keyAlias=playcricketlive
keyPassword=YOUR_PASSWORD
```

### 3. Get SHA-1 for Google OAuth

```bash
keytool -list -v -keystore release-key.jks -alias playcricketlive -storepass YOUR_PASSWORD | grep SHA1
```

Register this SHA-1 + package name `com.squ1d123.playcricketlive` in [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → OAuth 2.0 Client ID (Android).

Enable the **YouTube Data API v3** for your project.

## Build

```bash
./gradlew assembleDebug     # Debug APK
./gradlew assembleRelease   # Release APK
./gradlew test              # Run unit tests
```

APKs output to `app/build/outputs/apk/{debug,release}/`.

## Install

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Logs

```bash
adb logcat -s StreamingActivity    # Camera/zoom/streaming events
adb logcat | grep -i "playcricket"  # All app logs
```

## Telephoto lens access (OnePlus)

Some OEMs (OnePlus, OPPO, Samsung) restrict third-party apps from accessing auxiliary cameras (telephoto, ultrawide). The workaround is to use a package name that's on the OEM's camera whitelist. This app uses `com.ss.android.ugc.aweme` (TikTok's package) which is commonly whitelisted.

To set a different package name, change `applicationId` in `app/build.gradle.kts`.

## Architecture

- **Kotlin** + **Jetpack Compose** for UI
- **RootEncoder 2.7.2** for Camera2 + RTMP streaming + OpenGL overlays
- **OkHttp** for HTTP (Play-Cricket/ResultsVault API)
- **Google Sign-In** + **YouTube Data API v3** for broadcast creation
- **SharedPreferences** for settings persistence
- **javax.crypto** (3DES-ECB) for ResultsVault API authentication
