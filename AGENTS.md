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
- Apple Charts for planned V2.1 visualizations.
- SwiftData for local snapshot storage.
- Core Location and Core Motion for sensor readings.
- XCTest target: `SensorLogTests`.
- No server, no network client, no third-party SDK.

## Product Scope
- Tabs: Sensors, History, Settings.
- Sensors: live readings, per-group quality, Motion stationary detection, Raw / Smoothed display.
- History: local snapshots, quality detail, delete, clear all, single JSON v2 share.
- Settings: appearance status, language switch, permissions, sensor support, data policy, app info.
- Language options: Follow System, English, Simplified Chinese.
- Appearance follows the system light/dark mode.
- V2 P0 is implemented; next step is real-device validation and threshold tuning.
- V2.1 direction: Readable visual UI using native SwiftUI and Swift Charts.

## V2 P0 Implementation
- Quality thresholds and warning IDs are centralized in `Models/SensorQuality.swift`.
- Motion uses a rolling 3s window; Barometer uses a rolling 10s window.
- Smoothing affects display only; snapshots keep raw readings and optional v2 analysis fields.
- Older snapshots remain readable and show no quality analysis when v2 fields are absent.

## V2.1 Visual UI Direction
- Follow Apple platform style: system fonts, SF Symbols, grouped cards, dynamic type, light/dark support, and clear contrast.
- Use Apple's `Charts` framework; do not add third-party chart libraries.
- Move Sensors toward readable cards with small trend charts, quality badges, and concise processed values.
- Do not expose Noise as a primary user-facing option. Use noise internally for quality; show user conclusions such as Stable, Needs Attention, High, Medium, or Low.
- First visual screens: Sensors overview, Motion detail, and Environment detail for Location plus Barometer.
- Keep V2.1 local-only: no server, cloud sync, maps, recording sessions, HealthKit, or third-party SDK.

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
- Run tests:
  - `xcodebuild -project SensorLog.xcodeproj -scheme SensorLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' test`
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
