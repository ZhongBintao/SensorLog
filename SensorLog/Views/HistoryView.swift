import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SensorSnapshot.createdAt, order: .reverse)])
    private var snapshots: [SensorSnapshot]

    @State private var isConfirmingClear = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if snapshots.isEmpty {
                ContentUnavailableView(
                    "No Snapshots",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Save a snapshot from the Sensors tab to see it here.")
                )
            } else {
                ForEach(snapshots) { snapshot in
                    NavigationLink {
                        SnapshotDetailView(snapshot: snapshot)
                    } label: {
                        SnapshotRow(snapshot: snapshot)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !snapshots.isEmpty {
                    Button(role: .destructive) {
                        isConfirmingClear = true
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Clear All Snapshots?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) {
                clearAll()
            }
        } message: {
            Text("This removes all local snapshots from this device.")
        }
        .alert("History Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(snapshots[index])
        }
        saveChanges()
    }

    private func clearAll() {
        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct SnapshotRow: View {
    let snapshot: SensorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(SensorFormatting.dateTime(snapshot.createdAt))
                    .font(.headline)
                Spacer()
                if let batteryLevel = SensorFormatting.percent(snapshot.batteryLevel) {
                    Label(batteryLevel, systemImage: "battery.75percent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SnapshotAvailabilitySummary(snapshot: snapshot)

            HStack(spacing: 8) {
                if let activityKey = activityTitleKey {
                    Label(LocalizedStringKey(activityKey), systemImage: "figure.walk")
                }
                if let batteryStateKey = batteryStateTitleKey {
                    Label(LocalizedStringKey(batteryStateKey), systemImage: "bolt")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var activityTitleKey: String? {
        guard let rawValue = snapshot.activityType else { return nil }
        return ActivityType(rawValue: rawValue)?.titleKey
    }

    private var batteryStateTitleKey: String? {
        guard let rawValue = snapshot.batteryState else { return nil }
        return BatteryChargeState(rawValue: rawValue)?.titleKey
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .modelContainer(for: SensorSnapshot.self, inMemory: true)
    }
}
