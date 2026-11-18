import SwiftData
import XCTest
@testable import SensorLog

final class SensorQualityTests: XCTestCase {
    func testTrendBufferTrimsToSixtySecondsAndResetsForOutOfOrderSamples() {
        let now = Date(timeIntervalSince1970: 1_000)
        let existingSamples = [
            SensorTrendSample(timestamp: now.addingTimeInterval(-61), rawValue: 1, smoothedValue: nil),
            SensorTrendSample(timestamp: now.addingTimeInterval(-60), rawValue: 2, smoothedValue: nil),
            SensorTrendSample(timestamp: now.addingTimeInterval(-30), rawValue: 3, smoothedValue: nil)
        ]

        let trimmed = SensorTrendBuffer.appending(
            SensorTrendSample(timestamp: now, rawValue: 4, smoothedValue: nil),
            to: existingSamples
        )

        XCTAssertEqual(trimmed.map(\.rawValue), [2, 3, 4])
        XCTAssertEqual(trimmed.first?.timestamp, now.addingTimeInterval(-60))

        let replaced = SensorTrendBuffer.appending(
            SensorTrendSample(timestamp: now, rawValue: 6, smoothedValue: nil),
            to: trimmed
        )
        XCTAssertEqual(replaced.map(\.rawValue), [2, 3, 6])

        let expired = SensorTrendBuffer.trimming(
            replaced,
            referenceDate: now.addingTimeInterval(61)
        )
        XCTAssertTrue(expired.isEmpty)

        let manySamples = (0..<10).map { index in
            SensorTrendSample(
                timestamp: now.addingTimeInterval(Double(index)),
                rawValue: Double(index),
                smoothedValue: nil
            )
        }
        let capped = SensorTrendBuffer.trimming(
            manySamples,
            referenceDate: now.addingTimeInterval(9),
            duration: 60,
            maximumCount: 3
        )
        XCTAssertEqual(capped.map(\.rawValue), [7, 8, 9])

        let reset = SensorTrendBuffer.appending(
            SensorTrendSample(timestamp: now.addingTimeInterval(-1), rawValue: 5, smoothedValue: 4.5),
            to: replaced
        )
        XCTAssertEqual(reset.count, 1)
        XCTAssertEqual(reset.first?.rawValue, 5)
    }

    func testTrendSampleSelectsRawSmoothedAndFallsBackToRaw() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let smoothed = SensorTrendSample(timestamp: timestamp, rawValue: 4, smoothedValue: 2)
        let fallback = SensorTrendSample(timestamp: timestamp, rawValue: 4, smoothedValue: nil)

        XCTAssertEqual(smoothed.value(for: .raw), 4)
        XCTAssertEqual(smoothed.value(for: .smoothed), 2)
        XCTAssertEqual(fallback.value(for: .smoothed), 4)
    }

    func testLocationThresholdBoundaries() {
        let now = Date(timeIntervalSince1970: 1_000)
        let high = locationReading(age: 5, horizontalAccuracy: 25, verticalAccuracy: 30, now: now)
        let medium = locationReading(age: 15, horizontalAccuracy: 100, verticalAccuracy: 150, now: now)
        let low = locationReading(age: 15.01, horizontalAccuracy: 100, verticalAccuracy: 150, now: now)

        XCTAssertEqual(SensorQualityAnalyzer.assessLocation(status: .available, reading: high, now: now, isMotionStationary: false).level, .high)
        let mediumAssessment = SensorQualityAnalyzer.assessLocation(status: .available, reading: medium, now: now, isMotionStationary: false)
        XCTAssertEqual(mediumAssessment.level, .medium)
        XCTAssertTrue(mediumAssessment.warnings.contains(.staleLocation))
        XCTAssertEqual(SensorQualityAnalyzer.assessLocation(status: .available, reading: low, now: now, isMotionStationary: false).level, .low)
    }

    func testLocationWarningsExplainInvalidValuesAndDrift() {
        let now = Date(timeIntervalSince1970: 1_000)
        var reading = locationReading(age: 16, horizontalAccuracy: 101, verticalAccuracy: 151, now: now)
        reading.speed = nil
        reading.speedAccuracy = nil
        reading.course = nil
        reading.courseAccuracy = nil

        let invalid = SensorQualityAnalyzer.assessLocation(
            status: .available,
            reading: reading,
            now: now,
            isMotionStationary: false
        )
        XCTAssertTrue(invalid.warnings.contains(.poorHorizontalAccuracy))
        XCTAssertTrue(invalid.warnings.contains(.poorVerticalAccuracy))
        XCTAssertTrue(invalid.warnings.contains(.staleLocation))
        XCTAssertTrue(invalid.warnings.contains(.invalidSpeed))
        XCTAssertTrue(invalid.warnings.contains(.invalidCourse))

        reading = locationReading(age: 1, horizontalAccuracy: 5, verticalAccuracy: 5, now: now)
        reading.speed = 0.6
        let drift = SensorQualityAnalyzer.assessLocation(
            status: .available,
            reading: reading,
            now: now,
            isMotionStationary: true
        )
        XCTAssertEqual(drift.level, .medium)
        XCTAssertTrue(drift.warnings.contains(.lowSpeedCredibility))
    }

    func testMotionAtFiftyHertzIsHighAndStationary() {
        let result = SensorQualityAnalyzer.analyzeMotion(
            status: .available,
            samples: motionSamples(rate: 50, duration: 3, acceleration: 0.01, rotation: 0.02)
        )

        XCTAssertEqual(result.assessment.level, .high)
        XCTAssertEqual(result.isStationary, true)
        XCTAssertEqual(result.statistics?.userAccelerationMagnitude.actualSampleRate ?? -1, 50, accuracy: 0.001)
        XCTAssertEqual(result.statistics?.sampleInterval.actualSampleRate ?? -1, 50, accuracy: 0.001)
        XCTAssertEqual(result.statistics?.userAccelerationMagnitude.sampleCount, 151)
        XCTAssertEqual(result.statistics?.isSampleTimingStable, true)
    }

    func testMotionLowRateAndUnstableTimingAreLow() {
        let lowRate = SensorQualityAnalyzer.analyzeMotion(
            status: .available,
            samples: motionSamples(rate: 10, duration: 3, acceleration: 0.01, rotation: 0.02)
        )
        XCTAssertEqual(lowRate.assessment.level, .low)
        XCTAssertTrue(lowRate.assessment.warnings.contains(.unstableSampleRate))

        var timestamp = 0.0
        let unstable = (0..<151).map { index -> MotionQualitySample in
            if index > 0 {
                timestamp += index.isMultiple(of: 2) ? 0.005 : 0.035
            }
            return MotionQualitySample(timestamp: timestamp, userAccelerationMagnitude: 0.01, rotationRateMagnitude: 0.02)
        }
        let unstableResult = SensorQualityAnalyzer.analyzeMotion(status: .available, samples: unstable)
        XCTAssertEqual(unstableResult.assessment.level, .low)
        XCTAssertTrue(unstableResult.assessment.warnings.contains(.unstableSampleTiming))
    }

    func testMotionNoiseProducesMediumQualityAndNotStationary() {
        let samples = (0...150).map { index in
            MotionQualitySample(
                timestamp: Double(index) / 50,
                userAccelerationMagnitude: index.isMultiple(of: 2) ? 0 : 0.12,
                rotationRateMagnitude: index.isMultiple(of: 2) ? 0 : 0.24
            )
        }
        let result = SensorQualityAnalyzer.analyzeMotion(status: .available, samples: samples)
        XCTAssertEqual(result.assessment.level, .medium)
        XCTAssertEqual(result.isStationary, false)
        XCTAssertTrue(result.assessment.warnings.contains(.highAccelerationNoise))
        XCTAssertTrue(result.assessment.warnings.contains(.highGyroNoise))
    }

    func testMotionNeedsEnoughWindowData() {
        let result = SensorQualityAnalyzer.analyzeMotion(
            status: .available,
            samples: motionSamples(rate: 50, duration: 0.2, acceleration: 0.01, rotation: 0.02)
        )
        XCTAssertEqual(result.assessment.level, .low)
        XCTAssertNil(result.statistics)
        XCTAssertNil(result.isStationary)
        XCTAssertEqual(result.assessment.warnings, [.insufficientSamples])
    }

    func testMotionStopsBeingCredibleWhenRecentSamplesStop() {
        let result = SensorQualityAnalyzer.analyzeMotion(
            status: .available,
            samples: motionSamples(rate: 50, duration: 1, acceleration: 0.01, rotation: 0.02),
            referenceTimestamp: 3
        )
        XCTAssertEqual(result.assessment.level, .low)
        XCTAssertTrue(result.assessment.warnings.contains(.unstableSampleTiming))
        XCTAssertNil(result.isStationary)
    }

    func testBarometerQualityBoundaries() {
        let high = SensorQualityAnalyzer.analyzeBarometer(
            status: .available,
            samples: barometerSamples(pressureRange: 1, altitudeRange: 1.5)
        )
        let medium = SensorQualityAnalyzer.analyzeBarometer(
            status: .available,
            samples: barometerSamples(pressureRange: 3, altitudeRange: 5)
        )
        let low = SensorQualityAnalyzer.analyzeBarometer(
            status: .available,
            samples: barometerSamples(pressureRange: 3.01, altitudeRange: 5.01)
        )

        XCTAssertEqual(high.assessment.level, .high)
        XCTAssertEqual(medium.assessment.level, .medium)
        XCTAssertTrue(medium.assessment.warnings.contains(.pressureFluctuation))
        XCTAssertTrue(medium.assessment.warnings.contains(.altitudeDrift))
        XCTAssertEqual(low.assessment.level, .low)
    }

    func testPedometerQualityMapping() {
        let complete = PedometerReading(stepCount: 10, distance: 7, floorsAscended: 1, floorsDescended: 1)
        let partial = PedometerReading(stepCount: 10, distance: nil, floorsAscended: nil, floorsDescended: nil)

        XCTAssertEqual(
            SensorQualityAnalyzer.assessPedometer(status: .available, isSupported: true, permission: .available, reading: complete, waitingDuration: nil).level,
            .high
        )
        let medium = SensorQualityAnalyzer.assessPedometer(status: .available, isSupported: true, permission: .available, reading: partial, waitingDuration: nil)
        XCTAssertEqual(medium.level, .medium)
        XCTAssertEqual(medium.warnings, [.missingPedometerOptionalFields])
        XCTAssertEqual(
            SensorQualityAnalyzer.assessPedometer(status: .unavailable, isSupported: false, permission: .unknown, reading: nil, waitingDuration: nil).level,
            .low
        )
        let timedOut = SensorQualityAnalyzer.assessPedometer(
            status: .waiting,
            isSupported: true,
            permission: .available,
            reading: nil,
            waitingDuration: SensorQualityConfiguration.default.pedometerWaitingTimeout
        )
        XCTAssertEqual(timedOut.warnings, [.unavailablePedometer])
        let denied = SensorQualityAnalyzer.assessPedometer(
            status: .waiting,
            isSupported: true,
            permission: .deniedRestricted,
            reading: nil,
            waitingDuration: 0
        )
        XCTAssertTrue(denied.warnings.contains(.permissionLimited))
    }

    func testActivityConfidenceMapsDirectly() {
        XCTAssertEqual(activityAssessment(.high).level, .high)
        XCTAssertEqual(activityAssessment(.medium).level, .medium)
        let low = activityAssessment(.low)
        XCTAssertEqual(low.level, .low)
        XCTAssertEqual(low.warnings, [.lowActivityConfidence])
    }

    func testStatisticsUsePopulationStandardDeviationAndElapsedRate() {
        let statistics = SensorQualityAnalyzer.makeStatistics(values: [1, 2, 3], timestamps: [0, 0.5, 1])
        XCTAssertEqual(statistics?.sampleCount, 3)
        XCTAssertEqual(statistics?.actualSampleRate ?? -1, 2, accuracy: 0.0001)
        XCTAssertEqual(statistics?.min, 1)
        XCTAssertEqual(statistics?.max, 3)
        XCTAssertEqual(statistics?.mean ?? -1, 2, accuracy: 0.0001)
        XCTAssertEqual(statistics?.standardDeviation ?? -1, sqrt(2.0 / 3.0), accuracy: 0.0001)
    }

    func testEMAAndDisplayDeadbandDoNotMutateRawValue() {
        let raw = 0.004
        let smoothed = SensorQualityAnalyzer.exponentialMovingAverage(previous: 0, current: raw, alpha: 0.25)
        XCTAssertEqual(raw, 0.004)
        XCTAssertEqual(smoothed, 0.001, accuracy: 0.0001)
        XCTAssertEqual(SensorQualityAnalyzer.displayValue(smoothed, zeroThreshold: 0.005), 0)
        XCTAssertEqual(SensorQualityAnalyzer.displayValue(0.01, zeroThreshold: 0.005), 0.01)

        let reading = motionReading(accelerationX: 0.004)
        var completeReading = reading
        completeReading.userAccelerationY = -0.003
        completeReading.userAccelerationZ = 0.002
        XCTAssertEqual(completeReading.applyingDisplayDeadband().userAccelerationMagnitude, 0)
        XCTAssertEqual(completeReading.userAccelerationX, 0.004)
    }

    func testSnapshotKeepsRawMotionAndExportsV2Analysis() throws {
        var state = LiveSensorState()
        state.motionStatus = .available
        state.motion = motionReading(accelerationX: 1)
        state.smoothedMotion = motionReading(accelerationX: 0.25)
        state.motionQuality = QualityAssessment(level: .medium, warnings: [.highAccelerationNoise])
        state.smoothingMode = .smoothed
        state.isMotionStationary = false
        let magnitude = SampleWindowStatistics(
            sampleCount: 151,
            actualSampleRate: 50,
            min: 0,
            max: 1,
            mean: 0.25,
            standardDeviation: 0.1
        )
        let intervals = SampleWindowStatistics(
            sampleCount: 150,
            actualSampleRate: nil,
            min: 0.02,
            max: 0.02,
            mean: 0.02,
            standardDeviation: 0
        )
        state.motionWindowStatistics = MotionWindowStatistics(
            userAccelerationMagnitude: magnitude,
            rotationRateMagnitude: magnitude,
            sampleInterval: intervals,
            isSampleTimingStable: true
        )

        let snapshot = SensorSnapshot(createdAt: Date(timeIntervalSince1970: 1_000), liveState: state)
        XCTAssertEqual(snapshot.userAccelerationX, 1)
        XCTAssertEqual(snapshot.savedSmoothingMode, .smoothed)
        XCTAssertEqual(snapshot.savedMotionQuality?.level, .medium)

        let data = try XCTUnwrap(try snapshot.exportJSONString().data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["schemaVersion"] as? Int, 2)
        XCTAssertEqual(payload["smoothingMode"] as? String, "smoothed")
        let readings = try XCTUnwrap(payload["readings"] as? [String: Any])
        let motion = try XCTUnwrap(readings["motion"] as? [String: Any])
        XCTAssertEqual(motion["userAccelerationX"] as? Double, 1)
        let quality = try XCTUnwrap(payload["quality"] as? [String: Any])
        let motionQuality = try XCTUnwrap(quality["motion"] as? [String: Any])
        XCTAssertEqual(motionQuality["level"] as? String, "medium")
        XCTAssertEqual(payload["warnings"] as? [String], ["high_acceleration_noise", "waiting_for_data"])
        XCTAssertNotNil(payload["sampleWindowStatistics"])
    }

    func testLegacySnapshotWithoutV2FieldsStillExports() throws {
        let snapshot = SensorSnapshot(liveState: LiveSensorState())
        snapshot.qualitySchemaVersion = nil
        snapshot.locationQualityJSON = nil
        snapshot.motionQualityJSON = nil
        snapshot.barometerQualityJSON = nil
        snapshot.pedometerQualityJSON = nil
        snapshot.activityQualityJSON = nil
        snapshot.isMotionStationary = nil
        snapshot.smoothingModeRawValue = nil
        snapshot.motionWindowStatisticsJSON = nil
        snapshot.barometerWindowStatisticsJSON = nil

        XCTAssertFalse(snapshot.hasQualityAnalysis)
        let data = try XCTUnwrap(try snapshot.exportJSONString().data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["schemaVersion"] as? Int, 2)
        XCTAssertNil(payload["quality"])
        XCTAssertNil(payload["smoothingMode"])
        XCTAssertNotNil(payload["readings"])
    }

    func testSnapshotOmitsStaleReadingsWhenGroupsAreNotAvailable() {
        let now = Date(timeIntervalSince1970: 1_000)
        var state = LiveSensorState()
        state.locationStatus = .denied
        state.location = locationReading(
            age: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            now: now
        )
        state.motionStatus = .error
        state.motion = motionReading(accelerationX: 1)
        state.barometerStatus = .unavailable
        state.barometer = BarometerReading(relativeAltitude: 2, pressure: 1_013)
        state.pedometerStatus = .waiting
        state.pedometer = PedometerReading(
            stepCount: 100,
            distance: 80,
            floorsAscended: 1,
            floorsDescended: 1
        )
        state.activityStatus = .denied
        state.activity = ActivityReading(type: .walking, confidence: .high)
        state.deviceStatus = .error
        state.device = DeviceReading(
            batteryLevel: 80,
            batteryState: .charging,
            isLowPowerModeEnabled: true,
            thermalState: .serious
        )

        let snapshot = SensorSnapshot(createdAt: now, liveState: state)

        XCTAssertFalse(snapshot.hasLocationData)
        XCTAssertFalse(snapshot.hasMotionData)
        XCTAssertFalse(snapshot.hasBarometerData)
        XCTAssertFalse(snapshot.hasPedometerData)
        XCTAssertFalse(snapshot.hasActivityData)
        XCTAssertFalse(snapshot.hasDeviceData)
    }

    @MainActor
    func testSnapshotRetentionKeepsLatestFiveHundred() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SensorSnapshot.self,
            configurations: configuration
        )
        let modelContext = ModelContext(container)
        let baseDate = Date(timeIntervalSince1970: 1_000)

        for offset in 0..<503 {
            modelContext.insert(
                SensorSnapshot(
                    createdAt: baseDate.addingTimeInterval(Double(offset)),
                    liveState: LiveSensorState()
                )
            )
        }
        try modelContext.save()

        try SnapshotRetentionPolicy.pruneOldestSnapshots(in: modelContext)

        let descriptor = FetchDescriptor<SensorSnapshot>(
            sortBy: [SortDescriptor(\SensorSnapshot.createdAt, order: .forward)]
        )
        let remainingSnapshots = try modelContext.fetch(descriptor)
        XCTAssertEqual(remainingSnapshots.count, SnapshotRetentionPolicy.limit)
        XCTAssertEqual(remainingSnapshots.first?.createdAt, baseDate.addingTimeInterval(3))
        XCTAssertEqual(remainingSnapshots.last?.createdAt, baseDate.addingTimeInterval(502))
    }

    private func activityAssessment(_ confidence: ActivityConfidence) -> QualityAssessment {
        SensorQualityAnalyzer.assessActivity(
            status: .available,
            reading: ActivityReading(type: .stationary, confidence: confidence)
        )
    }

    private func locationReading(
        age: TimeInterval,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        now: Date
    ) -> LocationReading {
        LocationReading(
            latitude: 31.2,
            longitude: 121.5,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            speed: 0,
            speedAccuracy: 0.5,
            altitude: 10,
            course: 90,
            courseAccuracy: 5,
            lastUpdatedAt: now.addingTimeInterval(-age)
        )
    }

    private func motionSamples(
        rate: Double,
        duration: TimeInterval,
        acceleration: Double,
        rotation: Double
    ) -> [MotionQualitySample] {
        let count = Int(rate * duration)
        return (0...count).map { index in
            MotionQualitySample(
                timestamp: Double(index) / rate,
                userAccelerationMagnitude: acceleration,
                rotationRateMagnitude: rotation
            )
        }
    }

    private func barometerSamples(pressureRange: Double, altitudeRange: Double) -> [BarometerQualitySample] {
        (0...10).map { index in
            let progress = Double(index) / 10
            return BarometerQualitySample(
                timestamp: Double(index),
                pressure: 1_000 + pressureRange * progress,
                relativeAltitude: altitudeRange * progress
            )
        }
    }

    private func motionReading(accelerationX: Double) -> MotionReading {
        MotionReading(
            userAccelerationX: accelerationX,
            userAccelerationY: nil,
            userAccelerationZ: nil,
            gravityX: nil,
            gravityY: nil,
            gravityZ: nil,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil,
            roll: nil,
            pitch: nil,
            yaw: nil
        )
    }
}
