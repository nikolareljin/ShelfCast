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

# Ensure Java 11 is installed (Gradle 6.7.1 requires it)
sudo apt-get install -y openjdk-11-jdk

# Build the APK (debug by default for device installs)
cd ../nook-app
../scripts/build-android.sh

# For release builds:
# BUILD_VARIANT=release ../scripts/build-android.sh

# APK will be at: app/build/outputs/apk/release/app-release.apk
```

Notes:
- The repo includes a Gradle wrapper pinned to a compatible version.
- Use Java 8-11 for the Android build (Android Gradle Plugin 4.2.2 does not support newer JDKs).

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
# On Raspberry Pi - forward port so Nook can reach localhost:8080
adb reverse tcp:8080 tcp:8080
```

The app then connects to `http://localhost:8080` which routes to the Pi's server.

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
