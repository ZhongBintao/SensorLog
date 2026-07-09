import SwiftUI

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
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
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
                StatusInlineText(status: fallbackStatus)
            }
        }
        .accessibilityElement(children: .combine)
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
            .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
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
