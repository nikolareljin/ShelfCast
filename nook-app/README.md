# ShelfCast Nook App

Android application for Nook Simple Touch e-reader that displays the ShelfCast dashboard.

## Target Device

- **Device**: Nook Simple Touch (BNRV300)
- **Android Version**: 2.1 (Eclair, API Level 7)
- **Screen**: 800x600 e-ink display (touchscreen)
- **Connection**: USB cable to Raspberry Pi via ADB

## Architecture

The app is a simple WebView-based kiosk application that:
1. Connects to the ShelfCast server running on Raspberry Pi
2. Displays the dashboard in fullscreen mode
3. Handles e-ink refresh optimization
4. Maintains connection over USB (ADB port forwarding)

## Project Structure

```
nook-app/
├── app/
│   └── src/
│       └── main/
│           ├── java/com/shelfcast/nook/
│           │   ├── MainActivity.java      # Main WebView activity
│           │   ├── KioskService.java      # Background service
│           │   └── EinkRefreshHelper.java # E-ink optimization
│           ├── res/
│           │   ├── layout/
│           │   │   └── activity_main.xml
│           │   ├── values/
│           │   │   └── strings.xml
│           │   └── drawable/
│           │       └── ic_launcher.png
│           └── AndroidManifest.xml
├── build.gradle
├── gradle.properties
├── settings.gradle
└── README.md
```

## Build Requirements

See `../docs/dev-prerequisites.md` for complete Ubuntu setup.

### Quick Start (Ubuntu)

```bash
# Install Android SDK (API 7 for Nook)
cd ../dev-setup
./install-android-sdk.sh

# Build the APK
cd ../nook-app
./gradlew assembleRelease

# APK will be at: app/build/outputs/apk/release/app-release.apk
```

Notes:
- The repo includes a Gradle wrapper pinned to a compatible version.
- Use Java 8 for the Android build (Android Gradle Plugin 3.0.1 / Gradle 4.1).

## Deployment

The APK is deployed via ADB from the Raspberry Pi:

```bash
# On Raspberry Pi (after connecting Nook via USB)
adb install -r shelfcast-nook.apk
adb shell am start -n com.shelfcast.nook/.MainActivity
```

## USB Connection Mode

The Nook connects to Raspberry Pi via USB. ADB port forwarding allows the Nook to access the ShelfCast server:

```bash
# On Raspberry Pi - Android 2.1 does not support adb reverse; use host IP instead
# Example: http://<host-ip>:8080
```

The app is configured to connect to `http://<host-ip>:8080`, where `<host-ip>` is the Raspberry Pi's IP address.

## E-ink Optimization

The app includes special handling for e-ink displays:
- Reduced refresh rate to prevent ghosting
- High contrast mode for better readability
- Disabled animations and smooth scrolling
- Manual refresh button for full screen clear

## Development Notes

- Use Android SDK API Level 7 (Android 2.1)
- WebView on Android 2.1 is limited - keep HTML/CSS simple
- Test with Android emulator configured for 800x600 resolution
- The Nook's WebView doesn't support modern JavaScript features
