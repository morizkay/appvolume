# AppVolume

AppVolume is a native macOS menu bar application that discovers applications with active Core Audio output sessions and exposes the system output controls in a compact SwiftUI UI.

## Requirements

- macOS 14+
- Xcode with the macOS 14 SDK or newer
- Swift 5.10+
- Apple Silicon or Intel Mac

The repository contains an Xcode application project (`AppVolume.xcodeproj`) and does not use Swift Package Manager dependencies.

## Technical reality and MVP scope

macOS does **not** publish a general writable per-application gain or output-routing property in its public Core Audio HAL API. The public process objects expose metadata such as PID, bundle identifier, output devices, and whether output I/O is running, but they do not provide a per-process volume setter.

Therefore this MVP deliberately does not claim that its per-app controls work:

- **Implemented:** active application-audio discovery on macOS 14.2+ using the public Core Audio process-object list.
- **Implemented:** current output-device discovery.
- **Implemented:** system/master output volume and mute when the selected hardware exposes writable Core Audio controls.
- **Displayed but disabled:** per-app volume, mute, and output routing. The capability state and explanation are visible in the UI and Diagnostics page.
- **Implemented locally:** saved per-bundle preferences, including values that can be restored when a future capable backend is supplied.
- **Not installed:** no virtual audio driver, AudioServerPlugIn, DriverKit extension, private API, helper, or administrator operation.

The process list reports active audio I/O, which is the closest public signal available; it is not a guarantee that a stream is currently audible at every instant. macOS 14.0 and 14.1 can still use the system-volume portion, but application discovery reports that process objects require macOS 14.2 or newer.

## Why there is no fake per-app implementation

`kAudioDevicePropertyVolumeScalar` and `kAudioDevicePropertyMute` are device/control properties. They are not per-application gain controls. `kAudioDevicePropertyProcessMute` applies to the calling process's audio on a physical device and is not a safe way to mute an arbitrary target application. AppVolume never writes those properties on behalf of a target app and never falls back to changing the master volume when a per-app action is requested.

A future interception backend could evaluate the public Core Audio process-tap API available from macOS 14.2. A viable design would need to capture each process, mute its original path, apply realtime gain, render it to a selected output device, handle clock/sample-rate conversion, and recover from process/device lifecycle changes. That is a substantially larger realtime-audio system than a slider or a simple HAL property write. A virtual device or AudioServerPlugIn may be useful for a different routing design, but it would require explicit installation, signing, lifecycle handling, and user consent. This project leaves that work behind `AudioRoutingService` rather than installing a driver silently.

## Open, build, and run

1. Open `AppVolume.xcodeproj` in Xcode.
2. Select the `AppVolume` scheme.
3. Choose a Mac destination.
4. Build and run.

The app is configured with `LSUIElement`, so it starts without a Dock icon and places an icon in the menu bar. Click the icon for the popover. The popover includes **Open Main Window**, **Settings**, and **Quit**.

No permission is requested by the MVP. Core Audio metadata and system output controls use public APIs. Microphone, Accessibility, system-extension, and system-audio-capture status are shown in Diagnostics only; they are not required by the current implementation.

## Tests

The Xcode test target is `AppVolumeTests`. It covers:

- process-session filtering and bundle-ID deduplication;
- UserDefaults persistence, restore, and reset;
- restoration of saved app values;
- removal or retention of exited applications;
- system-volume isolation from per-app state;
- invalid output-device handling.

Run with **Product → Test** in Xcode, or with:

```sh
xcodebuild test -project AppVolume.xcodeproj -scheme AppVolume -destination 'platform=macOS'
```

## Diagnostics and Core Audio debugging

AppVolume uses `os.Logger` with subsystem `com.morizkay.AppVolume`. Useful commands while debugging a signed or locally built app:

```sh
log stream --style compact --predicate 'subsystem == "com.morizkay.AppVolume"'
```

Use **Audio MIDI Setup** to inspect available hardware, aggregate devices, and virtual devices. The app only reads devices and process metadata; it does not create or modify aggregate devices.

## Signed builds

Configure the `com.morizkay.AppVolume` bundle identifier and development team in Xcode, then archive using the normal Xcode Organizer flow. A command-line archive can be started with:

```sh
xcodebuild archive \
  -project AppVolume.xcodeproj \
  -scheme AppVolume \
  -configuration Release \
  -archivePath build/AppVolume.xcarchive
```

For distribution, use a Developer ID application certificate and notarize the exported app according to Apple's current signing and notarization requirements. Launch-at-login registration is performed through `SMAppService.mainApp`; it is not implemented with a custom privileged helper.

## Architecture

The project uses a small MVVM layout:

- `CoreAudioService` reads public HAL devices and process objects.
- `SystemVolumeService` owns master output controls.
- `AudioRoutingService` is the explicit seam for a future routing backend and currently returns an unsupported-capability error.
- `AudioApplicationScanner` filters active sessions and deduplicates by bundle identifier.
- `PersistenceService` stores only local settings and per-bundle values in UserDefaults.
- `MainViewModel` owns refresh, inactive-session retention, and UI state.
- `MockAudioService` supplies previews and deterministic unit-test data.

## Known issues and roadmap

- App names, icons, and process output-device associations depend on what Core Audio reports for the current process object.
- Some HDMI or aggregate devices do not expose a writable scalar volume or mute control; the system controls are disabled instead of changing another device.
- Per-app gain/mute/routing require a separately designed and tested realtime interception backend.
- Future work: process-tap prototype behind a feature flag, realtime render path tests, device/process lifecycle stress tests, and a separately signed/installed virtual-device option only if direct process-tap rendering is insufficient.
