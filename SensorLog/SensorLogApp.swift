import SwiftData
import SwiftUI

@main
struct SensorLogApp: App {
    @State private var sensorManager = SensorManager()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(sensorManager)
        }
        .modelContainer(for: SensorSnapshot.self)
    }
}
