# SensorLog Project Notes

## Project
- Native iOS app: `SensorLog`.
- Xcode project: `SensorLog.xcodeproj`.
- Bundle ID: `com.zhongbintao.SensorLog`.
- Minimum iOS: `17.0`.
- Version: `1.0 (1)`.
- Main branch: `main`.

## Stack
- SwiftUI for UI.
- SwiftData for local snapshot storage.
- Core Location and Core Motion for sensor readings.
- No server, no network client, no third-party SDK.

## Product Scope
- Tabs: Sensors, History, Settings.
- Sensors: Location, Motion, Barometer, Pedometer, Activity, Device state.
- History: local snapshots, detail view, delete, clear all, single JSON share.
- Settings: appearance status, language switch, permissions, sensor support, data policy, app info.
- Language options: Follow System, English, Simplified Chinese.
- Appearance follows the system light/dark mode.

## Privacy And Permissions
- Only request:
  - `NSLocationWhenInUseUsageDescription`
  - `NSMotionUsageDescription`
- Do not add background location, HealthKit, Bluetooth, NFC, Camera, Microphone, Contacts, Photos, accounts, API keys, or remote config.
- All app data stays on device.

## Copy Rules
- Keep UI text concise, production-facing, and localized in `Localizable.xcstrings`.
- Do not show simulator/self-test wording in the app UI.
- Permission prompt text is localized in `en.lproj/InfoPlist.strings` and `zh-Hans.lproj/InfoPlist.strings`.

## Build And Verify
- Build/run simulator:
  - `xcodebuild -project SensorLog.xcodeproj -scheme SensorLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Prefer Xcode for signing and real-device install.
- Before committing, run:
  - `git diff --check`
  - `rg -n "Simulator|simulator|模拟器|Self-Test|self-test|自测" SensorLog`

## Git
- Keep commits small and descriptive.
- Current important commits:
  - `00ef558` Initial SensorLog iOS app
  - `d9b5c23` Add system appearance status
  - `04c2f2c` Refine localization and release copy
