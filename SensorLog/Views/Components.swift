import Charts
import SwiftUI
import UIKit

enum SensorFormatting {
    static func number(_ value: Double?, digits: Int = 2, unit: String = "") -> String? {
        guard let value else { return nil }
        let formatted = value.formatted(.number.precision(.fractionLength(digits)))
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
    }

    static func integer(_ value: Int?, unit: String = "") -> String? {
        guard let value else { return nil }
        return unit.isEmpty ? "\(value)" : "\(value) \(unit)"
    }

    static func percent(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    static func elapsed(since date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        return number(max(0, now.timeIntervalSince(date)), digits: 1, unit: "s")
    }

    static func range(_ statistics: SampleWindowStatistics?, digits: Int, unit: String) -> String? {
        guard let minimum = statistics?.min, let maximum = statistics?.max else { return nil }
        return number(maximum - minimum, digits: digits, unit: unit)
    }
}

struct SensorCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
    }
}

struct SensorCardTitle: View {
    let titleKey: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        Label {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SensorMetric: View {
    let titleKey: String
    let value: String?
    let fallbackStatus: ReadingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let value {
                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                StatusInlineText(status: missingValueStatus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var missingValueStatus: ReadingStatus {
        fallbackStatus == .available ? .unavailable : fallbackStatus
    }
}

struct LocalizedSensorMetric: View {
    let titleKey: String
    let valueKey: String?
    let fallbackStatus: ReadingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            } else {
                StatusInlineText(status: missingValueStatus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var missingValueStatus: ReadingStatus {
        fallbackStatus == .available ? .unavailable : fallbackStatus
    }
}

struct SensorTrendChart: View {
    let samples: [SensorTrendSample]
    let mode: SmoothingMode
    let tint: Color
    let accessibilityLabelKey: String
    let unit: String
    var minimumVisibleRange: Double = 0
    var height: CGFloat = 72

    var body: some View {
        Group {
            if samples.count > 1 {
                Chart(samples) { sample in
                    if sample.id == samples.first?.id {
                        RuleMark(y: .value("", sample.value(for: mode)))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.35))
                    }
                    LineMark(
                        x: .value("", sample.timestamp),
                        y: .value("", sample.value(for: mode))
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(tint)
                }
                .chartYScale(domain: yDomain)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(tint.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabelKey)))
                .accessibilityValue(accessibilitySummaryText)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                    Text(LocalizedStringKey("Collecting Trend"))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: height)
    }

    private var displayedValues: [Double] {
        samples.map { $0.value(for: mode) }
    }

    private var yDomain: ClosedRange<Double> {
        guard let minimum = displayedValues.min(),
              let maximum = displayedValues.max() else { return 0...1 }
        let center = (minimum + maximum) / 2
        let visibleRange = max(maximum - minimum, minimumVisibleRange, 0.000_001)
        let padding = visibleRange * 0.1
        var lowerBound = center - visibleRange / 2 - padding
        var upperBound = center + visibleRange / 2 + padding
        if minimum >= 0, lowerBound < 0 {
            upperBound -= lowerBound
            lowerBound = 0
        }
        return lowerBound...upperBound
    }

    private var accessibilitySummaryText: Text {
        guard let latest = displayedValues.last,
              let minimum = displayedValues.min(),
              let maximum = displayedValues.max(),
              let latestText = SensorFormatting.number(latest, digits: 2, unit: unit),
              let minimumText = SensorFormatting.number(minimum, digits: 2, unit: unit),
              let maximumText = SensorFormatting.number(maximum, digits: 2, unit: unit) else {
            return Text(LocalizedStringKey("Collecting Trend"))
        }
        return Text(LocalizedStringKey("Latest")) +
            Text(verbatim: ": \(latestText). ") +
            Text(LocalizedStringKey("Trend Range")) +
            Text(verbatim: ": \(minimumText) – \(maximumText). ") +
            Text(LocalizedStringKey(trendDirectionKey))
    }

    private var trendDirectionKey: String {
        guard let first = displayedValues.first,
              let last = displayedValues.last else { return "Stable" }
        let stableDelta = max(minimumVisibleRange * 0.1, 0.000_001)
        if abs(last - first) <= stableDelta { return "Stable" }
        return last > first ? "Rising" : "Falling"
    }
}

struct SensorErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Sensor Reading Error"))
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LocalizedStringKey("Dismiss")))
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
        }
    }
}

extension QualityLevel {
    var tint: Color {
        switch self {
        case .high:
            .teal
        case .medium:
            .orange
        case .low:
            .red
        }
    }

    var symbolName: String {
        switch self {
        case .high:
            "checkmark.shield.fill"
        case .medium:
            "exclamationmark.shield.fill"
        case .low:
            "xmark.shield.fill"
        }
    }
}

struct QualityRow: View {
    let assessment: QualityAssessment?

    var body: some View {
        HStack {
            Text("Quality")
            Spacer(minLength: 12)
            if let assessment {
                QualityBadge(level: assessment.level)
            } else {
                Text("No Quality Analysis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct QualityBadge: View {
    let level: QualityLevel

    var body: some View {
        Label {
            Text(LocalizedStringKey(level.titleKey))
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: level.symbolName)
                .imageScale(.small)
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(level.tint.opacity(0.12), in: Capsule())
    }
}

struct QualityWarningsView: View {
    let warnings: [QualityWarning]

    var body: some View {
        ForEach(warnings, id: \.rawValue) { warning in
            Label {
                Text(LocalizedStringKey(warning.titleKey))
            } icon: {
                Image(systemName: "exclamationmark.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }
}

extension ReadingStatus {
    var tint: Color {
        switch self {
        case .waiting:
            .orange
        case .available:
            .teal
        case .unavailable:
            .secondary
        case .denied, .error:
            .red
        }
    }

    var symbolName: String {
        switch self {
        case .waiting:
            "hourglass"
        case .available:
            "checkmark.circle.fill"
        case .unavailable:
            "minus.circle"
        case .denied:
            "lock.circle"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }
}

struct StatusBadge: View {
    let titleKey: String
    let status: ReadingStatus

    var body: some View {
        Label {
            Text(LocalizedStringKey(titleKey))
                .font(.caption.weight(.medium))
        } icon: {
            Image(systemName: status.symbolName)
                .imageScale(.small)
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
        .accessibilityValue(Text(LocalizedStringKey(status.titleKey)))
    }
}

struct ReadingRow: View {
    let titleKey: String
    let value: String?
    let fallbackStatus: ReadingStatus

    init(_ titleKey: String, value: String?, fallbackStatus: ReadingStatus) {
        self.titleKey = titleKey
        self.value = value
        self.fallbackStatus = fallbackStatus
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            if let value {
                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                StatusInlineText(status: missingValueStatus)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var missingValueStatus: ReadingStatus {
        fallbackStatus == .available ? .unavailable : fallbackStatus
    }
}

struct LocalizedReadingRow: View {
    let titleKey: String
    let valueKey: String?
    let fallbackStatus: ReadingStatus

    init(_ titleKey: String, valueKey: String?, fallbackStatus: ReadingStatus) {
        self.titleKey = titleKey
        self.valueKey = valueKey
        self.fallbackStatus = fallbackStatus
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                StatusInlineText(status: missingValueStatus)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var missingValueStatus: ReadingStatus {
        fallbackStatus == .available ? .unavailable : fallbackStatus
    }
}

struct StatusInlineText: View {
    let status: ReadingStatus

    var body: some View {
        Label {
            Text(LocalizedStringKey(status.titleKey))
        } icon: {
            Image(systemName: status.symbolName)
        }
        .font(.subheadline)
        .foregroundStyle(status.tint)
        .multilineTextAlignment(.trailing)
    }
}

struct PermissionRow: View {
    let titleKey: String
    let valueKey: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack {
            Label(LocalizedStringKey(titleKey), systemImage: systemImage)
            Spacer(minLength: 12)
            Text(LocalizedStringKey(valueKey))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CapabilityRow: View {
    let titleKey: String
    let isAvailable: Bool

    var body: some View {
        HStack {
            Text(LocalizedStringKey(titleKey))
            Spacer()
            Label {
                Text(LocalizedStringKey(isAvailable ? "Supported" : "Unavailable"))
            } icon: {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "minus.circle")
            }
            .font(.subheadline)
            .foregroundStyle(isAvailable ? .teal : .secondary)
        }
    }
}

struct SnapshotAvailabilitySummary: View {
    let snapshot: SensorSnapshot

    var body: some View {
        HStack(spacing: 8) {
            SummaryIcon(titleKey: "Location", systemImage: "location", isAvailable: snapshot.hasLocationData)
            SummaryIcon(titleKey: "Motion", systemImage: "gyroscope", isAvailable: snapshot.hasMotionData)
            SummaryIcon(titleKey: "Barometer", systemImage: "barometer", isAvailable: snapshot.hasBarometerData)
            SummaryIcon(titleKey: "Pedometer", systemImage: "figure.walk", isAvailable: snapshot.hasPedometerData)
        }
    }
}

private struct SummaryIcon: View {
    let titleKey: String
    let systemImage: String
    let isAvailable: Bool

    var body: some View {
        Image(systemName: systemImage)
            .imageScale(.small)
            .foregroundStyle(isAvailable ? .teal : .secondary)
            .frame(width: 24, height: 24)
            .background((isAvailable ? Color.teal : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
            .accessibilityValue(Text(LocalizedStringKey(isAvailable ? "Available" : "Unavailable")))
    }
}

struct EmptyValueLabel: View {
    let status: ReadingStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.symbolName)
            Text(LocalizedStringKey(status.titleKey))
        }
        .font(.subheadline)
        .foregroundStyle(status.tint)
    }
}
