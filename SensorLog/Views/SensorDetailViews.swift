import SwiftUI
import UIKit

struct MotionDetailView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let smoothingMode: SmoothingMode

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                summaryCard
                trendCard
                accelerationCard
                gravityCard
                rotationCard
                attitudeCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("Motion Detail"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        let quality = sensorManager.liveState.motionQuality
        let statistics = sensorManager.liveState.motionWindowStatistics

        return SensorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SensorCardTitle(titleKey: "Motion", systemImage: "gyroscope", tint: quality.level.tint)
                    Spacer(minLength: 8)
                    QualityBadge(level: quality.level)
                }

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                    summaryMetrics(statistics: statistics)
                }

                QualityWarningsView(warnings: quality.warnings)
            }
        }
    }

    private var trendCard: some View {
        let quality = sensorManager.liveState.motionQuality

        return SensorCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SensorCardTitle(titleKey: "Acceleration Magnitude", systemImage: "waveform.path", tint: quality.level.tint)
                    Spacer(minLength: 12)
                    if let formattedMagnitude {
                        Text(formattedMagnitude)
                            .font(.headline.monospacedDigit())
                    }
                }
                Text(LocalizedStringKey("Recent 60 Seconds"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SensorTrendChart(
                    samples: sensorManager.trendState.motionAcceleration,
                    mode: smoothingMode,
                    tint: quality.level.tint,
                    accessibilityLabelKey: "Acceleration Magnitude",
                    unit: "g",
                    minimumVisibleRange: 0.03,
                    height: 190
                )
            }
        }
    }

    private var accelerationCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                SensorCardTitle(titleKey: "User Acceleration", systemImage: "move.3d", tint: .orange)
                ReadingRow("User Acceleration X", value: SensorFormatting.number(displayedMotion?.userAccelerationX, digits: 3, unit: "g"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("User Acceleration Y", value: SensorFormatting.number(displayedMotion?.userAccelerationY, digits: 3, unit: "g"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("User Acceleration Z", value: SensorFormatting.number(displayedMotion?.userAccelerationZ, digits: 3, unit: "g"), fallbackStatus: motionStatus)
            }
        }
    }

    private var gravityCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                SensorCardTitle(titleKey: "Gravity", systemImage: "arrow.down.to.line", tint: .blue)
                ReadingRow("Gravity X", value: SensorFormatting.number(displayedMotion?.gravityX, digits: 3, unit: "g"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Gravity Y", value: SensorFormatting.number(displayedMotion?.gravityY, digits: 3, unit: "g"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Gravity Z", value: SensorFormatting.number(displayedMotion?.gravityZ, digits: 3, unit: "g"), fallbackStatus: motionStatus)
            }
        }
    }

    private var rotationCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                SensorCardTitle(titleKey: "Rotation Rate", systemImage: "rotate.3d", tint: .purple)
                ReadingRow("Rotation Rate X", value: SensorFormatting.number(displayedMotion?.rotationRateX, digits: 3, unit: "rad/s"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Rotation Rate Y", value: SensorFormatting.number(displayedMotion?.rotationRateY, digits: 3, unit: "rad/s"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Rotation Rate Z", value: SensorFormatting.number(displayedMotion?.rotationRateZ, digits: 3, unit: "rad/s"), fallbackStatus: motionStatus)
            }
        }
    }

    private var attitudeCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                SensorCardTitle(titleKey: "Attitude", systemImage: "view.3d", tint: .teal)
                ReadingRow("Roll", value: SensorFormatting.number(displayedMotion?.roll, digits: 3, unit: "rad"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Pitch", value: SensorFormatting.number(displayedMotion?.pitch, digits: 3, unit: "rad"), fallbackStatus: motionStatus)
                Divider()
                ReadingRow("Yaw", value: SensorFormatting.number(displayedMotion?.yaw, digits: 3, unit: "rad"), fallbackStatus: motionStatus)
            }
        }
    }

    @ViewBuilder
    private func summaryMetrics(statistics: MotionWindowStatistics?) -> some View {
        LocalizedSensorMetric(titleKey: "Motion State", valueKey: motionStateKey, fallbackStatus: analysisStatus)
        LocalizedSensorMetric(titleKey: "Sampling Stability", valueKey: samplingStabilityKey, fallbackStatus: analysisStatus)
        SensorMetric(
            titleKey: "Sample Count",
            value: SensorFormatting.integer(statistics?.userAccelerationMagnitude.sampleCount),
            fallbackStatus: analysisStatus
        )
        SensorMetric(
            titleKey: "Sample Rate",
            value: SensorFormatting.number(statistics?.userAccelerationMagnitude.actualSampleRate, digits: 1, unit: "Hz"),
            fallbackStatus: analysisStatus
        )
    }

    private var displayedMotion: MotionReading? {
        switch smoothingMode {
        case .raw:
            sensorManager.liveState.motion
        case .smoothed:
            (sensorManager.liveState.smoothedMotion ?? sensorManager.liveState.motion)?.applyingDisplayDeadband()
        }
    }

    private var motionStatus: ReadingStatus {
        sensorManager.liveState.motionStatus
    }

    private var analysisStatus: ReadingStatus {
        motionStatus == .available ? .waiting : motionStatus
    }

    private var motionStateKey: String? {
        guard let isMotionStationary = sensorManager.liveState.isMotionStationary else { return nil }
        return isMotionStationary ? "Stationary" : "Moving"
    }

    private var samplingStabilityKey: String? {
        guard let statistics = sensorManager.liveState.motionWindowStatistics else { return nil }
        return statistics.isSampleTimingStable ? "Stable" : "Needs Attention"
    }

    private var formattedMagnitude: String? {
        SensorFormatting.number(displayedMotion?.userAccelerationMagnitude, digits: 3, unit: "g")
    }

    private var summaryColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }
}

struct EnvironmentDetailView: View {
    @Environment(SensorManager.self) private var sensorManager
    let smoothingMode: SmoothingMode

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                qualityCard
                locationCard
                barometerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("Environment Detail"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var qualityCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 12) {
                SensorCardTitle(titleKey: "Environment", systemImage: "location.viewfinder", tint: .blue)
                qualityRow(titleKey: "Location", assessment: sensorManager.liveState.locationQuality)
                qualityRow(titleKey: "Barometer", assessment: sensorManager.liveState.barometerQuality)
            }
        }
    }

    private var locationCard: some View {
        let status = sensorManager.liveState.locationStatus
        let location = sensorManager.liveState.location
        let quality = sensorManager.liveState.locationQuality

        return SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SensorCardTitle(titleKey: "Location", systemImage: "location", tint: quality.level.tint)
                    Spacer(minLength: 8)
                    QualityBadge(level: quality.level)
                }

                Text(LocalizedStringKey("Location Accuracy Trend"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SensorTrendChart(
                    samples: sensorManager.trendState.locationAccuracy,
                    mode: .raw,
                    tint: quality.level.tint,
                    accessibilityLabelKey: "Location Accuracy Trend",
                    unit: "m",
                    minimumVisibleRange: 25,
                    height: 150
                )

                QualityWarningsView(warnings: quality.warnings)
                Divider()
                ReadingRow("Latitude", value: SensorFormatting.number(location?.latitude, digits: 6, unit: "deg"), fallbackStatus: status)
                Divider()
                ReadingRow("Longitude", value: SensorFormatting.number(location?.longitude, digits: 6, unit: "deg"), fallbackStatus: status)
                Divider()
                ReadingRow("Horizontal Accuracy", value: SensorFormatting.number(location?.horizontalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                Divider()
                ReadingRow("Vertical Accuracy", value: SensorFormatting.number(location?.verticalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                Divider()
                ReadingRow("Last Updated Age", value: SensorFormatting.elapsed(since: location?.lastUpdatedAt), fallbackStatus: status)
                Divider()
                ReadingRow("Speed", value: SensorFormatting.number(location?.speed, digits: 2, unit: "m/s"), fallbackStatus: status)
                Divider()
                LocalizedReadingRow("Speed Credibility", valueKey: speedCredibilityKey, fallbackStatus: status)
                Divider()
                ReadingRow("Altitude", value: SensorFormatting.number(location?.altitude, digits: 1, unit: "m"), fallbackStatus: status)
                Divider()
                ReadingRow("Course", value: SensorFormatting.number(location?.course, digits: 1, unit: "deg"), fallbackStatus: status)
                Divider()
                LocalizedReadingRow("Course Credibility", valueKey: courseCredibilityKey, fallbackStatus: status)
            }
        }
    }

    private var barometerCard: some View {
        let status = sensorManager.liveState.barometerStatus
        let quality = sensorManager.liveState.barometerQuality
        let statistics = sensorManager.liveState.barometerWindowStatistics

        return SensorCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SensorCardTitle(titleKey: "Barometer", systemImage: "barometer", tint: quality.level.tint)
                    Spacer(minLength: 8)
                    QualityBadge(level: quality.level)
                }

                Text(LocalizedStringKey("Pressure Trend"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SensorTrendChart(
                    samples: sensorManager.trendState.barometerPressure,
                    mode: smoothingMode,
                    tint: quality.level.tint,
                    accessibilityLabelKey: "Pressure Trend",
                    unit: "hPa",
                    minimumVisibleRange: 1,
                    height: 150
                )

                QualityWarningsView(warnings: quality.warnings)
                Divider()
                ReadingRow("Pressure", value: SensorFormatting.number(displayedBarometer?.pressure, digits: 1, unit: "hPa"), fallbackStatus: status)
                Divider()
                ReadingRow("Relative Altitude", value: SensorFormatting.number(displayedBarometer?.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: status)
                Divider()
                ReadingRow("Pressure Range", value: SensorFormatting.range(statistics?.pressure, digits: 2, unit: "hPa"), fallbackStatus: analysisStatus(status))
                Divider()
                ReadingRow("Altitude Range", value: SensorFormatting.range(statistics?.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: analysisStatus(status))
            }
        }
    }

    private func qualityRow(titleKey: String, assessment: QualityAssessment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 12)
                QualityBadge(level: assessment.level)
            }
            QualityWarningsView(warnings: assessment.warnings)
        }
    }

    private var displayedBarometer: BarometerReading? {
        switch smoothingMode {
        case .raw:
            sensorManager.liveState.barometer
        case .smoothed:
            sensorManager.liveState.smoothedBarometer ?? sensorManager.liveState.barometer
        }
    }

    private var speedCredibilityKey: String? {
        let warnings = sensorManager.liveState.locationQuality.warnings
        if warnings.contains(.invalidSpeed) { return "Low" }
        guard sensorManager.liveState.location?.speed != nil else { return nil }
        return warnings.contains(.lowSpeedCredibility) ? "Low" : "High"
    }

    private var courseCredibilityKey: String? {
        let warnings = sensorManager.liveState.locationQuality.warnings
        if warnings.contains(.invalidCourse) { return "Low" }
        guard sensorManager.liveState.location?.course != nil else { return nil }
        return "High"
    }

    private func analysisStatus(_ status: ReadingStatus) -> ReadingStatus {
        status == .available ? .waiting : status
    }
}

#Preview("Motion Detail") {
    NavigationStack {
        MotionDetailView(smoothingMode: .smoothed)
            .environment(SensorManager.preview)
    }
}

#Preview("Environment Detail") {
    NavigationStack {
        EnvironmentDetailView(smoothingMode: .smoothed)
            .environment(SensorManager.preview)
    }
}
