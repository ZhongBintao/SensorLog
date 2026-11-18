import CoreLocation
import CoreMotion
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SensorManager {
    var liveState = LiveSensorState()
    var trendState = SensorTrendState()
    var permissions = SensorPermissionState()
    var availability = SensorAvailability()
    var lastErrorMessage: String?

    private let qualityConfiguration: SensorQualityConfiguration = .default
    @ObservationIgnored private var lastErrorSource: SensorErrorSource?

    @ObservationIgnored private lazy var locationDelegate = LocationDelegate(owner: self)
    @ObservationIgnored private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = locationDelegate
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        return manager
    }()

    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let activityManager = CMMotionActivityManager()
    @ObservationIgnored private let sensorQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SensorLog.SensorQueue"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var latestRawMotion: MotionReading?
    @ObservationIgnored private var latestSmoothedMotion: MotionReading?
    @ObservationIgnored private var hasPendingMotionSample = false
    @ObservationIgnored private var motionQualitySamples: [MotionQualitySample] = []
    @ObservationIgnored private var barometerQualitySamples: [BarometerQualitySample] = []
    @ObservationIgnored private var pedometerStartedAt: Date?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var isUpdatingLocation = false
    @ObservationIgnored private var isUpdatingMotion = false
    @ObservationIgnored private var isUpdatingAltimeter = false
    @ObservationIgnored private var isUpdatingPedometer = false
    @ObservationIgnored private var isUpdatingActivity = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshPermissions()
        refreshAvailability()
        refreshDeviceState()
    }

    deinit {
        displayTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
    }

    func start() {
        refreshAvailability()
        refreshPermissions()
        refreshDeviceState()

        guard !hasStarted else {
            startLocationIfAllowed()
            startMotion()
            startAltimeter()
            if permissions.motion == .available {
                startPedometer()
                startActivity()
            }
            return
        }

        hasStarted = true
        startLocationIfAllowed()
        startMotion()
        startAltimeter()
        if permissions.motion == .available {
            startPedometer()
            startActivity()
        }
        startDisplayTimer()
    }

    func requestLocationPermission() {
        _ = locationManager
        locationManager.requestWhenInUseAuthorization()
    }

    func requestMotionPermission() {
        refreshMotionPermission()
        startPedometer()
        startActivity()
    }

    func setSmoothingMode(_ mode: SmoothingMode) {
        liveState.smoothingMode = mode
    }

    func dismissLastError() {
        lastErrorMessage = nil
        lastErrorSource = nil
    }

    func refreshPermissions() {
        permissions.location = mapLocationAuthorization(locationManager.authorizationStatus)
        refreshMotionPermission()
        refreshLocationQuality()
    }

    func refreshAvailability() {
        availability = SensorAvailability(
            deviceMotion: motionManager.isDeviceMotionAvailable,
            gyroscope: motionManager.isGyroAvailable,
            accelerometer: motionManager.isAccelerometerAvailable,
            barometer: CMAltimeter.isRelativeAltitudeAvailable(),
            pedometer: CMPedometer.isStepCountingAvailable(),
            activityRecognition: CMMotionActivityManager.isActivityAvailable()
        )
    }

    private func refreshMotionPermission() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            permissions.motion = .available
        case .denied, .restricted:
            permissions.motion = .deniedRestricted
            clearPedometerData()
            clearActivityData()
            if availability.pedometer {
                liveState.pedometerStatus = .denied
            }
            if availability.activityRecognition {
                liveState.activityStatus = .denied
            }
            isUpdatingPedometer = false
            isUpdatingActivity = false
            pedometer.stopUpdates()
            activityManager.stopActivityUpdates()
        case .notDetermined:
            permissions.motion = .unknown
        @unknown default:
            permissions.motion = .unknown
        }
        refreshPedometerQuality()
        refreshActivityQuality()
    }

    private func startLocationIfAllowed() {
        defer { refreshLocationQuality() }
        let status = locationManager.authorizationStatus
        permissions.location = mapLocationAuthorization(status)

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if liveState.location == nil {
                liveState.locationStatus = .waiting
            }
            guard !isUpdatingLocation else { return }
            isUpdatingLocation = true
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            clearLocationData()
            liveState.locationStatus = .denied
            isUpdatingLocation = false
            locationManager.stopUpdatingLocation()
        case .notDetermined:
            clearLocationData()
            liveState.locationStatus = .waiting
        @unknown default:
            clearLocationData()
            liveState.locationStatus = .error
        }
    }

    private func startMotion() {
        guard !isUpdatingMotion else { return }
        guard motionManager.isDeviceMotionAvailable else {
            clearMotionData()
            liveState.motionStatus = .unavailable
            refreshMotionQuality()
            return
        }

        isUpdatingMotion = true
        liveState.motionStatus = .waiting
        refreshMotionQuality()
        let targetSampleRate = (
            qualityConfiguration.motionHighMinimumSampleRate +
                qualityConfiguration.motionHighMaximumSampleRate
        ) / 2
        motionManager.deviceMotionUpdateInterval = 1.0 / targetSampleRate
        motionManager.startDeviceMotionUpdates(to: sensorQueue) { [weak self] motion, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isUpdatingMotion = false
                    self.motionManager.stopDeviceMotionUpdates()
                    self.clearMotionData()
                    self.liveState.motionStatus = .error
                    self.hasPendingMotionSample = false
                    self.setSensorError(error, source: .motion)
                    self.refreshMotionQuality()
                    return
                }
                guard let motion else { return }
                self.recordMotion(motion)
            }
        }
    }

    private func startAltimeter() {
        guard !isUpdatingAltimeter else { return }
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            clearBarometerData()
            liveState.barometerStatus = .unavailable
            refreshBarometerQuality()
            return
        }

        isUpdatingAltimeter = true
        liveState.barometerStatus = .waiting
        refreshBarometerQuality()
        altimeter.startRelativeAltitudeUpdates(to: sensorQueue) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isUpdatingAltimeter = false
                    self.altimeter.stopRelativeAltitudeUpdates()
                    self.clearBarometerData()
                    self.liveState.barometerStatus = .error
                    self.setSensorError(error, source: .barometer)
                    self.refreshBarometerQuality()
                    return
                }
                guard let data else { return }
                self.recordBarometer(data)
            }
        }
    }

    private func startPedometer() {
        guard !isUpdatingPedometer else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            clearPedometerData()
            liveState.pedometerStatus = .unavailable
            pedometerStartedAt = nil
            refreshPedometerQuality()
            return
        }
        guard permissions.motion != .deniedRestricted else {
            clearPedometerData()
            liveState.pedometerStatus = .denied
            pedometerStartedAt = nil
            refreshPedometerQuality()
            return
        }

        isUpdatingPedometer = true
        liveState.pedometerStatus = .waiting
        pedometerStartedAt = .now
        refreshPedometerQuality()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.handleMotionRelatedError(error, group: .pedometer)
                    return
                }
                guard let data else { return }
                self.liveState.pedometer = PedometerReading(
                    stepCount: data.numberOfSteps.intValue,
                    distance: data.distance?.doubleValue,
                    floorsAscended: data.floorsAscended?.intValue,
                    floorsDescended: data.floorsDescended?.intValue
                )
                self.liveState.pedometerStatus = .available
                self.clearSensorError(source: .pedometer)
                self.refreshMotionPermission()
                self.refreshPedometerQuality()
            }
        }
    }

    private func startActivity() {
        guard !isUpdatingActivity else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            clearActivityData()
            liveState.activityStatus = .unavailable
            refreshActivityQuality()
            return
        }
        guard permissions.motion != .deniedRestricted else {
            clearActivityData()
            liveState.activityStatus = .denied
            refreshActivityQuality()
            return
        }

        isUpdatingActivity = true
        liveState.activityStatus = .waiting
        refreshActivityQuality()
        activityManager.startActivityUpdates(to: sensorQueue) { [weak self] activity in
            Task { @MainActor in
                guard let self else { return }
                guard let activity else { return }
                self.liveState.activity = ActivityReading(
                    type: Self.activityType(from: activity),
                    confidence: Self.activityConfidence(from: activity.confidence)
                )
                self.liveState.activityStatus = .available
                self.clearSensorError(source: .activity)
                self.refreshMotionPermission()
                self.refreshActivityQuality()
            }
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date.now
                let systemUptime = ProcessInfo.processInfo.systemUptime
                self.publishLatestMotion(referenceTimestamp: systemUptime)
                self.trimDisplayTrends(referenceDate: now)
                self.refreshBarometerQuality(referenceTimestamp: systemUptime)
                self.refreshLocationQuality(now: now)
                self.refreshPedometerQuality(now: now)
                self.refreshActivityQuality()
                self.refreshDeviceState()
            }
        }
    }

    private func publishLatestMotion(referenceTimestamp: TimeInterval) {
        if hasPendingMotionSample,
           let latestRawMotion,
           let latestSmoothedMotion {
            liveState.motion = latestRawMotion
            liveState.smoothedMotion = latestSmoothedMotion
            liveState.motionStatus = .available
            clearSensorError(source: .motion)
            recordMotionTrend(
                raw: latestRawMotion,
                smoothed: latestSmoothedMotion,
                timestamp: .now
            )
            hasPendingMotionSample = false
        }
        refreshMotionQuality(referenceTimestamp: referenceTimestamp)
    }

    private func recordMotion(_ motion: CMDeviceMotion) {
        let rawReading = MotionReading(
            userAccelerationX: motion.userAcceleration.x,
            userAccelerationY: motion.userAcceleration.y,
            userAccelerationZ: motion.userAcceleration.z,
            gravityX: motion.gravity.x,
            gravityY: motion.gravity.y,
            gravityZ: motion.gravity.z,
            rotationRateX: motion.rotationRate.x,
            rotationRateY: motion.rotationRate.y,
            rotationRateZ: motion.rotationRate.z,
            roll: motion.attitude.roll,
            pitch: motion.attitude.pitch,
            yaw: motion.attitude.yaw
        )
        latestRawMotion = rawReading
        latestSmoothedMotion = makeSmoothedMotion(
            previous: latestSmoothedMotion,
            current: rawReading
        )
        hasPendingMotionSample = true

        if let latestTimestamp = motionQualitySamples.last?.timestamp,
           motion.timestamp < latestTimestamp {
            motionQualitySamples.removeAll(keepingCapacity: true)
        }
        motionQualitySamples.append(
            MotionQualitySample(
                timestamp: motion.timestamp,
                userAccelerationMagnitude: Self.magnitude(
                    x: motion.userAcceleration.x,
                    y: motion.userAcceleration.y,
                    z: motion.userAcceleration.z
                ),
                rotationRateMagnitude: Self.magnitude(
                    x: motion.rotationRate.x,
                    y: motion.rotationRate.y,
                    z: motion.rotationRate.z
                )
            )
        )
        trimMotionQualitySamples(referenceTimestamp: motion.timestamp)
    }

    private func makeSmoothedMotion(previous: MotionReading?, current: MotionReading) -> MotionReading {
        MotionReading(
            userAccelerationX: smoothed(previous?.userAccelerationX, current: current.userAccelerationX),
            userAccelerationY: smoothed(previous?.userAccelerationY, current: current.userAccelerationY),
            userAccelerationZ: smoothed(previous?.userAccelerationZ, current: current.userAccelerationZ),
            gravityX: smoothed(previous?.gravityX, current: current.gravityX),
            gravityY: smoothed(previous?.gravityY, current: current.gravityY),
            gravityZ: smoothed(previous?.gravityZ, current: current.gravityZ),
            rotationRateX: smoothed(previous?.rotationRateX, current: current.rotationRateX),
            rotationRateY: smoothed(previous?.rotationRateY, current: current.rotationRateY),
            rotationRateZ: smoothed(previous?.rotationRateZ, current: current.rotationRateZ),
            roll: smoothedAngle(previous?.roll, current: current.roll),
            pitch: smoothedAngle(previous?.pitch, current: current.pitch),
            yaw: smoothedAngle(previous?.yaw, current: current.yaw)
        )
    }

    private func recordBarometer(_ data: CMAltitudeData) {
        let rawReading = BarometerReading(
            relativeAltitude: data.relativeAltitude.doubleValue,
            pressure: data.pressure.doubleValue * 10.0
        )
        liveState.barometer = rawReading
        liveState.smoothedBarometer = BarometerReading(
            relativeAltitude: smoothed(
                liveState.smoothedBarometer?.relativeAltitude,
                current: rawReading.relativeAltitude
            ),
            pressure: smoothed(
                liveState.smoothedBarometer?.pressure,
                current: rawReading.pressure
            )
        )
        liveState.barometerStatus = .available
        clearSensorError(source: .barometer)
        recordBarometerTrend(
            raw: rawReading,
            smoothed: liveState.smoothedBarometer,
            timestamp: .now
        )

        if let latestTimestamp = barometerQualitySamples.last?.timestamp,
           data.timestamp < latestTimestamp {
            barometerQualitySamples.removeAll(keepingCapacity: true)
        }
        barometerQualitySamples.append(
            BarometerQualitySample(
                timestamp: data.timestamp,
                pressure: data.pressure.doubleValue * 10.0,
                relativeAltitude: data.relativeAltitude.doubleValue
            )
        )
        refreshBarometerQuality(referenceTimestamp: data.timestamp)
    }

    private func refreshLocationQuality(now: Date = .now) {
        liveState.locationQuality = SensorQualityAnalyzer.assessLocation(
            status: liveState.locationStatus,
            reading: liveState.location,
            now: now,
            isMotionStationary: liveState.isMotionStationary,
            configuration: qualityConfiguration
        )
    }

    private func refreshMotionQuality(
        referenceTimestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        trimMotionQualitySamples(referenceTimestamp: referenceTimestamp)
        let result = SensorQualityAnalyzer.analyzeMotion(
            status: liveState.motionStatus,
            samples: motionQualitySamples,
            referenceTimestamp: referenceTimestamp,
            configuration: qualityConfiguration
        )
        liveState.motionQuality = result.assessment
        liveState.motionWindowStatistics = result.statistics
        liveState.isMotionStationary = result.isStationary
    }

    private func refreshBarometerQuality(
        referenceTimestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        trimBarometerQualitySamples(referenceTimestamp: referenceTimestamp)
        let result = SensorQualityAnalyzer.analyzeBarometer(
            status: liveState.barometerStatus,
            samples: barometerQualitySamples,
            configuration: qualityConfiguration
        )
        liveState.barometerQuality = result.assessment
        liveState.barometerWindowStatistics = result.statistics
    }

    private func refreshPedometerQuality(now: Date = .now) {
        let waitingDuration: TimeInterval? = {
            guard liveState.pedometerStatus == .waiting,
                  let pedometerStartedAt else { return nil }
            return max(0, now.timeIntervalSince(pedometerStartedAt))
        }()
        liveState.pedometerQuality = SensorQualityAnalyzer.assessPedometer(
            status: liveState.pedometerStatus,
            isSupported: availability.pedometer,
            permission: permissions.motion,
            reading: liveState.pedometer,
            waitingDuration: waitingDuration,
            configuration: qualityConfiguration
        )
    }

    private func refreshActivityQuality() {
        if permissions.motion == .deniedRestricted {
            liveState.activityQuality = QualityAssessment(
                level: .low,
                warnings: [.permissionLimited, .unavailableActivity]
            )
            return
        }
        liveState.activityQuality = SensorQualityAnalyzer.assessActivity(
            status: liveState.activityStatus,
            reading: liveState.activity
        )
    }

    private func trimMotionQualitySamples(referenceTimestamp: TimeInterval) {
        let cutoff = referenceTimestamp - qualityConfiguration.motionWindowDuration
        motionQualitySamples.removeAll { $0.timestamp < cutoff }
    }

    private func trimBarometerQualitySamples(referenceTimestamp: TimeInterval) {
        let cutoff = referenceTimestamp - qualityConfiguration.barometerWindowDuration
        barometerQualitySamples.removeAll { $0.timestamp < cutoff }
    }

    private func recordMotionTrend(
        raw: MotionReading,
        smoothed: MotionReading,
        timestamp: Date
    ) {
        guard let rawValue = raw.userAccelerationMagnitude else { return }
        appendTrend(
            SensorTrendSample(
                timestamp: timestamp,
                rawValue: rawValue,
                smoothedValue: smoothed
                    .applyingDisplayDeadband(configuration: qualityConfiguration)
                    .userAccelerationMagnitude
            ),
            to: \.motionAcceleration
        )
    }

    private func recordLocationTrend(_ reading: LocationReading) {
        guard let horizontalAccuracy = reading.horizontalAccuracy else { return }
        appendTrend(
            SensorTrendSample(
                timestamp: .now,
                rawValue: horizontalAccuracy,
                smoothedValue: nil
            ),
            to: \.locationAccuracy
        )
    }

    private func recordBarometerTrend(
        raw: BarometerReading,
        smoothed: BarometerReading?,
        timestamp: Date
    ) {
        if let pressure = raw.pressure {
            appendTrend(
                SensorTrendSample(
                    timestamp: timestamp,
                    rawValue: pressure,
                    smoothedValue: smoothed?.pressure
                ),
                to: \.barometerPressure
            )
        }
        if let relativeAltitude = raw.relativeAltitude {
            appendTrend(
                SensorTrendSample(
                    timestamp: timestamp,
                    rawValue: relativeAltitude,
                    smoothedValue: smoothed?.relativeAltitude
                ),
                to: \.barometerAltitude
            )
        }
    }

    private func appendTrend(
        _ sample: SensorTrendSample,
        to keyPath: WritableKeyPath<SensorTrendState, [SensorTrendSample]>
    ) {
        var updatedState = trendState
        updatedState[keyPath: keyPath] = SensorTrendBuffer.appending(
            sample,
            to: updatedState[keyPath: keyPath]
        )
        trendState = updatedState
    }

    private func trimDisplayTrends(referenceDate: Date) {
        var updatedState = trendState
        updatedState.motionAcceleration = SensorTrendBuffer.trimming(
            updatedState.motionAcceleration,
            referenceDate: referenceDate
        )
        updatedState.locationAccuracy = SensorTrendBuffer.trimming(
            updatedState.locationAccuracy,
            referenceDate: referenceDate
        )
        updatedState.barometerPressure = SensorTrendBuffer.trimming(
            updatedState.barometerPressure,
            referenceDate: referenceDate
        )
        updatedState.barometerAltitude = SensorTrendBuffer.trimming(
            updatedState.barometerAltitude,
            referenceDate: referenceDate
        )
        if updatedState != trendState {
            trendState = updatedState
        }
    }

    private func clearLocationData() {
        liveState.location = nil
        var updatedState = trendState
        updatedState.locationAccuracy.removeAll(keepingCapacity: true)
        trendState = updatedState
    }

    private func clearMotionData() {
        liveState.motion = nil
        liveState.smoothedMotion = nil
        latestRawMotion = nil
        latestSmoothedMotion = nil
        hasPendingMotionSample = false
        motionQualitySamples.removeAll(keepingCapacity: true)
        var updatedState = trendState
        updatedState.motionAcceleration.removeAll(keepingCapacity: true)
        trendState = updatedState
    }

    private func clearBarometerData() {
        liveState.barometer = nil
        liveState.smoothedBarometer = nil
        barometerQualitySamples.removeAll(keepingCapacity: true)
        var updatedState = trendState
        updatedState.barometerPressure.removeAll(keepingCapacity: true)
        updatedState.barometerAltitude.removeAll(keepingCapacity: true)
        trendState = updatedState
    }

    private func clearPedometerData() {
        liveState.pedometer = nil
        pedometerStartedAt = nil
    }

    private func clearActivityData() {
        liveState.activity = nil
    }

    private func smoothed(_ previous: Double?, current: Double?) -> Double? {
        guard let current else { return nil }
        return SensorQualityAnalyzer.exponentialMovingAverage(
            previous: previous,
            current: current,
            alpha: qualityConfiguration.smoothingAlpha
        )
    }

    private func smoothedAngle(_ previous: Double?, current: Double?) -> Double? {
        guard let current else { return nil }
        guard let previous else { return current }
        let delta = atan2(sin(current - previous), cos(current - previous))
        let value = previous + qualityConfiguration.smoothingAlpha * delta
        return atan2(sin(value), cos(value))
    }

    private static func magnitude(x: Double, y: Double, z: Double) -> Double {
        hypot(hypot(x, y), z)
    }

    private func refreshDeviceState() {
        let batteryLevel = UIDevice.current.batteryLevel
        liveState.device = DeviceReading(
            batteryLevel: batteryLevel >= 0 ? Double(batteryLevel) * 100.0 : nil,
            batteryState: Self.batteryState(from: UIDevice.current.batteryState),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: Self.thermalState(from: ProcessInfo.processInfo.thermalState)
        )
        liveState.deviceStatus = .available
    }

    private func handle(location: CLLocation) {
        let reading = LocationReading(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            verticalAccuracy: location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            speedAccuracy: location.speedAccuracy >= 0 ? location.speedAccuracy : nil,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
            course: location.course >= 0 ? location.course : nil,
            courseAccuracy: location.courseAccuracy >= 0 ? location.courseAccuracy : nil,
            lastUpdatedAt: location.timestamp
        )
        liveState.location = reading
        liveState.locationStatus = .available
        clearSensorError(source: .location)
        recordLocationTrend(reading)
        refreshLocationQuality()
    }

    private func handleLocationError(_ error: Error) {
        let clError = error as? CLError
        if clError?.code == .locationUnknown {
            setSensorError(error, source: .location)
            refreshLocationQuality()
            return
        }
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        clearLocationData()
        if clError?.code == .denied {
            liveState.locationStatus = .denied
            permissions.location = .denied
        } else {
            liveState.locationStatus = .error
        }
        setSensorError(error, source: .location)
        refreshLocationQuality()
    }

    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
        permissions.location = mapLocationAuthorization(status)
        startLocationIfAllowed()
    }

    private func handleMotionRelatedError(_ error: Error, group: MotionGroup) {
        refreshMotionPermission()
        let status: ReadingStatus = permissions.motion == .deniedRestricted ? .denied : .error
        switch group {
        case .pedometer:
            isUpdatingPedometer = false
            pedometer.stopUpdates()
            clearPedometerData()
            liveState.pedometerStatus = status
            refreshPedometerQuality()
        case .activity:
            isUpdatingActivity = false
            activityManager.stopActivityUpdates()
            clearActivityData()
            liveState.activityStatus = status
            refreshActivityQuality()
        }
        setSensorError(error, source: group == .pedometer ? .pedometer : .activity)
    }

    private func setSensorError(_ error: Error, source: SensorErrorSource) {
        lastErrorSource = source
        lastErrorMessage = error.localizedDescription
    }

    private func clearSensorError(source: SensorErrorSource) {
        guard lastErrorSource == source else { return }
        lastErrorSource = nil
        lastErrorMessage = nil
    }

    private func mapLocationAuthorization(_ status: CLAuthorizationStatus) -> LocationPermissionStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorizedAlways, .authorizedWhenInUse:
            .authorizedWhenInUse
        @unknown default:
            .notDetermined
        }
    }

    private enum MotionGroup: Equatable {
        case pedometer
        case activity
    }

    private enum SensorErrorSource: Equatable {
        case location
        case motion
        case barometer
        case pedometer
        case activity
    }

    private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
        weak var owner: SensorManager?

        init(owner: SensorManager) {
            self.owner = owner
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            Task { @MainActor [weak owner] in
                owner?.handleLocationAuthorizationChange(manager.authorizationStatus)
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            Task { @MainActor [weak owner] in
                owner?.handle(location: location)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            Task { @MainActor [weak owner] in
                owner?.handleLocationError(error)
            }
        }
    }

    private static func activityType(from activity: CMMotionActivity) -> ActivityType {
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private static func activityConfidence(from confidence: CMMotionActivityConfidence) -> ActivityConfidence {
        switch confidence {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        @unknown default:
            .low
        }
    }

    private static func batteryState(from state: UIDevice.BatteryState) -> BatteryChargeState {
        switch state {
        case .unknown:
            .unknown
        case .unplugged:
            .unplugged
        case .charging:
            .charging
        case .full:
            .full
        @unknown default:
            .unknown
        }
    }

    private static func thermalState(from state: ProcessInfo.ThermalState) -> ThermalStateDisplay {
        switch state {
        case .nominal:
            .nominal
        case .fair:
            .fair
        case .serious:
            .serious
        case .critical:
            .critical
        @unknown default:
            .unknown
        }
    }
}

extension SensorManager {
    static var preview: SensorManager {
        let manager = SensorManager()
        manager.permissions = SensorPermissionState(location: .authorizedWhenInUse, motion: .available)
        manager.availability = SensorAvailability(
            deviceMotion: true,
            gyroscope: true,
            accelerometer: true,
            barometer: true,
            pedometer: true,
            activityRecognition: true
        )
        let accelerationStatistics = SampleWindowStatistics(
            sampleCount: 151,
            actualSampleRate: 50,
            min: 0.002,
            max: 0.025,
            mean: 0.012,
            standardDeviation: 0.003
        )
        let rotationStatistics = SampleWindowStatistics(
            sampleCount: 151,
            actualSampleRate: 50,
            min: 0.003,
            max: 0.035,
            mean: 0.018,
            standardDeviation: 0.006
        )
        let intervalStatistics = SampleWindowStatistics(
            sampleCount: 150,
            actualSampleRate: 50,
            min: 0.019,
            max: 0.021,
            mean: 0.020,
            standardDeviation: 0.0004
        )
        let pressureStatistics = SampleWindowStatistics(
            sampleCount: 11,
            actualSampleRate: 1,
            min: 1012.6,
            max: 1013.0,
            mean: 1012.8,
            standardDeviation: 0.12
        )
        let altitudeStatistics = SampleWindowStatistics(
            sampleCount: 11,
            actualSampleRate: 1,
            min: 1.2,
            max: 1.5,
            mean: 1.4,
            standardDeviation: 0.08
        )
        manager.liveState = LiveSensorState(
            locationStatus: .available,
            motionStatus: .available,
            barometerStatus: .available,
            pedometerStatus: .available,
            activityStatus: .available,
            deviceStatus: .available,
            location: LocationReading(
                latitude: 31.230_416,
                longitude: 121.473_701,
                horizontalAccuracy: 8,
                verticalAccuracy: 12,
                speed: 0.02,
                speedAccuracy: 0.3,
                altitude: 5.2,
                course: 90,
                courseAccuracy: 8,
                lastUpdatedAt: .now
            ),
            motion: MotionReading(
                userAccelerationX: 0.004,
                userAccelerationY: -0.003,
                userAccelerationZ: 0.002,
                gravityX: 0.00,
                gravityY: -0.01,
                gravityZ: -0.99,
                rotationRateX: 0.008,
                rotationRateY: 0.006,
                rotationRateZ: -0.004,
                roll: 0.02,
                pitch: -0.01,
                yaw: 1.18
            ),
            smoothedMotion: MotionReading(
                userAccelerationX: 0.002,
                userAccelerationY: -0.002,
                userAccelerationZ: 0.001,
                gravityX: 0.00,
                gravityY: -0.01,
                gravityZ: -0.99,
                rotationRateX: 0.005,
                rotationRateY: 0.004,
                rotationRateZ: -0.003,
                roll: 0.02,
                pitch: -0.01,
                yaw: 1.18
            ),
            barometer: BarometerReading(relativeAltitude: 1.4, pressure: 1012.8),
            smoothedBarometer: BarometerReading(relativeAltitude: 1.35, pressure: 1012.82),
            pedometer: PedometerReading(
                stepCount: 2_486,
                distance: 1_820,
                floorsAscended: 3,
                floorsDescended: 2
            ),
            activity: ActivityReading(type: .stationary, confidence: .high),
            device: DeviceReading(
                batteryLevel: 86,
                batteryState: .charging,
                isLowPowerModeEnabled: false,
                thermalState: .nominal
            ),
            locationQuality: QualityAssessment(level: .high),
            motionQuality: QualityAssessment(level: .high),
            barometerQuality: QualityAssessment(level: .high),
            pedometerQuality: QualityAssessment(level: .high),
            activityQuality: QualityAssessment(level: .high),
            isMotionStationary: true,
            smoothingMode: .smoothed,
            motionWindowStatistics: MotionWindowStatistics(
                userAccelerationMagnitude: accelerationStatistics,
                rotationRateMagnitude: rotationStatistics,
                sampleInterval: intervalStatistics,
                isSampleTimingStable: true
            ),
            barometerWindowStatistics: BarometerWindowStatistics(
                pressure: pressureStatistics,
                relativeAltitude: altitudeStatistics
            )
        )
        let trendEnd = Date.now
        manager.trendState = SensorTrendState(
            motionAcceleration: (0..<30).map { index in
                let progress = Double(index) / 29
                return SensorTrendSample(
                    timestamp: trendEnd.addingTimeInterval(-58 + Double(index) * 2),
                    rawValue: 0.012 + sin(progress * .pi * 4) * 0.004,
                    smoothedValue: 0.011 + sin(progress * .pi * 4) * 0.002
                )
            },
            locationAccuracy: (0..<12).map { index in
                SensorTrendSample(
                    timestamp: trendEnd.addingTimeInterval(-55 + Double(index) * 5),
                    rawValue: 8 + sin(Double(index) * 0.7) * 1.2,
                    smoothedValue: nil
                )
            },
            barometerPressure: (0..<30).map { index in
                let rawValue = 1_012.8 + sin(Double(index) * 0.35) * 0.15
                return SensorTrendSample(
                    timestamp: trendEnd.addingTimeInterval(-58 + Double(index) * 2),
                    rawValue: rawValue,
                    smoothedValue: 1_012.8 + sin(Double(index) * 0.35) * 0.08
                )
            },
            barometerAltitude: (0..<30).map { index in
                let rawValue = 1.4 + sin(Double(index) * 0.3) * 0.12
                return SensorTrendSample(
                    timestamp: trendEnd.addingTimeInterval(-58 + Double(index) * 2),
                    rawValue: rawValue,
                    smoothedValue: 1.4 + sin(Double(index) * 0.3) * 0.06
                )
            }
        )
        return manager
    }
}
