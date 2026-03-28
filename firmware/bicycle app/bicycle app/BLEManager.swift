//
//  BLEManager.swift
//  bicycle app
//

import Foundation
import CoreMotion
import CoreLocation
@preconcurrency import CoreBluetooth

/// 使用 `nonisolated` 计算属性，避免 `-default-isolation=MainActor` 下 BLE 委托无法引用 UUID 的问题。
private enum BLEUUID {
    nonisolated static var service: CBUUID { CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B") }
    nonisolated static var radarNotify: CBUUID { CBUUID(string: "BEB5483E-36E1-4688-B7F5-EA07361B26A8") }
    nonisolated static var phoneWrite: CBUUID { CBUUID(string: "D2A8A310-53A0-4E9B-9DAB-7069B0D9F31A") }
}

struct DangerRecord: Identifiable, Sendable {
    let id = UUID()
    let recordedAt = Date()
    let dangerScore: Int
    let targetId: Int
    let angle: Int
    let distance: Int
    let speed: Int
    let direction: String

    var sideDescription: String {
        if angle < -2 { return "左侧" }
        if angle > 2 { return "右侧" }
        return "后方"
    }
}

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let name: String
    var rssi: Int
    var lastSeen: Date
}

@Observable
final class BLEManager: NSObject {
    enum ConnectionState: String {
        case disconnected = "已断开"
        case scanning = "扫描中"
        case connecting = "连接中"
        case connected = "已连接"
        case bluetoothOff = "蓝牙已关闭"
        case unauthorized = "未授权"
    }

    var connectionState: ConnectionState = .disconnected
    var latestFrame: RadarFrame?
    var recentFrames: [RadarFrame] = []
    var parseErrors = 0
    var totalReceived = 0
    var rssi = 0
    var latestDangerScore = 0
    var dangerRecords: [DangerRecord] = []
    var discoveredDevices: [DiscoveredDevice] = []
    var isScanning = false
    var connectedDeviceName: String?

    // Glasses connection
    var glassesState: ConnectionState = .disconnected
    var glassesName: String?
    var glassesScanResults: [DiscoveredDevice] = []
    var isScanningGlasses = false
    var glassesRssi = 0

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var radarNotifyCharacteristic: CBCharacteristic?
    private var phoneWriteCharacteristic: CBCharacteristic?
    private var dataBuffer = Data()
    private var shouldReconnect = false
    private var peripheralMap: [UUID: CBPeripheral] = [:]
    private var autoReconnectTargetId: UUID?
    private var lastConnectedDeviceId: UUID?
    private let maxRecentFrames = 100
    private let maxDangerRecords = 100
    private let api = RadarAPIService()
    private var dangerRefreshTask: Task<Void, Never>?
    private let dangerRecordThreshold = 70
    private var hasRecordedCurrentDangerWindow = false

    private var glassesPeripheral: CBPeripheral?
    private var glassesWriteChar: CBCharacteristic?
    private var glassesPeriMap: [UUID: CBPeripheral] = [:]
    private enum ScanPurpose { case radar, glasses }
    private var scanPurpose: ScanPurpose = .radar

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let brakeLocationManager = CLLocationManager()

    private var latestUserAccelMagnitude: Double = 0
    private var filteredSpeed: Double = 0
    private var hasFilteredSpeed = false
    private var lastRawSpeed: Double = 0
    private var hasLastRawSpeed = false
    private var lastSpeedTimestamp: Date?
    private var recentPeakSpeed: Double = 0
    private var recentPeakTimestamp: Date?
    private var lastMotionTimestamp: TimeInterval?
    private var prevMotionAccMag: Double = 0
    private var pseudoVelX: Double = 0
    private var pseudoVelY: Double = 0
    private var pseudoVelZ: Double = 0
    private var decelHoldSeconds: TimeInterval = 0
    private var releaseHoldSeconds: TimeInterval = 0
    private var isDecelActive = false
    private var autoBrakeOffWorkItem: DispatchWorkItem?

    private let decelThreshold: Double = -0.18
    private let rawDecelThreshold: Double = -0.18
    private let speedDropThreshold: Double = 0.5
    private let peakWindow: TimeInterval = 1.6
    private let minMovingSpeed: Double = 1.0
    private let minMotionMagnitude: Double = 0.01
    private let strongMotionMagnitude: Double = 0.45
    private let decelEnterDuration: TimeInterval = 0.22
    private let decelExitDuration: TimeInterval = 0.5
    private let autoBrakePulseDuration: TimeInterval = 0.35

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        brakeLocationManager.delegate = self
        brakeLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        brakeLocationManager.distanceFilter = kCLDistanceFilterNone
        brakeLocationManager.activityType = .fitness
        brakeLocationManager.pausesLocationUpdatesAutomatically = false
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        scanPurpose = .radar
        autoReconnectTargetId = nil
        isScanning = true
        discoveredDevices = []
        peripheralMap = [:]
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEUUID.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    // MARK: - Glasses scan & connect

    func startGlassesScan() {
        guard centralManager.state == .poweredOn else { return }
        scanPurpose = .glasses
        isScanningGlasses = true
        glassesScanResults = []
        glassesPeriMap = [:]
        glassesState = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEUUID.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopGlassesScan() {
        if isScanningGlasses {
            centralManager.stopScan()
            isScanningGlasses = false
            scanPurpose = .radar
            if glassesState == .scanning {
                glassesState = .disconnected
            }
        }
    }

    func connectGlasses(_ deviceId: UUID) {
        guard let peripheral = glassesPeriMap[deviceId] else { return }
        centralManager.stopScan()
        isScanningGlasses = false
        scanPurpose = .radar
        glassesPeripheral = peripheral
        peripheral.delegate = self
        glassesState = .connecting
        glassesName = peripheral.name ?? "ESP32 Glasses"
        centralManager.connect(peripheral, options: nil)
    }

    func disconnectGlasses() {
        if let p = glassesPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        glassesState = .disconnected
        glassesPeripheral = nil
        glassesWriteChar = nil
        glassesName = nil
    }

    func connectDevice(_ deviceId: UUID) {
        guard let peripheral = peripheralMap[deviceId] else { return }
        centralManager.stopScan()
        isScanning = false
        shouldReconnect = true
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting
        connectedDeviceName = peripheral.name ?? "ESP32 Radar"
        lastConnectedDeviceId = deviceId
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        shouldReconnect = false
        autoReconnectTargetId = nil
        centralManager.stopScan()
        isScanning = false
        stopDangerScoreRefresh()
        stopBrakeDetection()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectionState = .disconnected
        connectedDeviceName = nil
    }

    // MARK: - Navigation commands (sent to glasses)

    private var lastNavCommand: String = "0"

    func sendNavigationCommand(_ command: String) {
        guard command == "L" || command == "R" || command == "0" else { return }
        guard command != lastNavCommand else { return }
        lastNavCommand = command
        sendToGlasses("NAV,\(command)")
    }

    func sendStartSignal() {
        sendToGlasses("NAV,S")
    }

    private func sendToGlasses(_ command: String) {
        let payload = "\(command)\n"
        guard let data = payload.data(using: .utf8) else { return }

        // Prefer direct glasses BLE connection
        if glassesState == .connected,
           let p = glassesPeripheral,
           let char = glassesWriteChar {
            let wt: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse)
                ? .withoutResponse : .withResponse
            p.writeValue(data, for: char, type: wt)
            print("[BLE] Sent \(command) → glasses")
            return
        }

        // Fallback: send to radar for ESP-NOW relay
        if connectionState == .connected,
           let p = connectedPeripheral,
           let char = phoneWriteCharacteristic {
            let wt: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse)
                ? .withoutResponse : .withResponse
            p.writeValue(data, for: char, type: wt)
            print("[BLE] Sent \(command) → radar (relay)")
        }
    }

    func sendBrakeOnForDebug() {
        autoBrakeOffWorkItem?.cancel()
        sendBrakeState(true, source: "DEBUG")
    }

    func sendBrakeOffForDebug() {
        autoBrakeOffWorkItem?.cancel()
        isDecelActive = false
        decelHoldSeconds = 0
        releaseHoldSeconds = 0
        sendBrakeState(false, source: "DEBUG")
    }

    private func processIncomingData(_ data: Data) {
        dataBuffer.append(data)
        while let newlineIndex = dataBuffer.firstIndex(of: 0x0A) {
            let lineData = dataBuffer[dataBuffer.startIndex..<newlineIndex]
            dataBuffer = Data(dataBuffer[dataBuffer.index(after: newlineIndex)...])
            guard !lineData.isEmpty else { continue }

            do {
                let frame = try JSONDecoder().decode(RadarFrame.self, from: Data(lineData))
                totalReceived += 1
                latestFrame = frame
                recentFrames.append(frame)
                if recentFrames.count > maxRecentFrames {
                    recentFrames.removeFirst(recentFrames.count - maxRecentFrames)
                }
                if frame.isApproaching {
                    let speedMs = Double(frame.speed) / 3.6
                    if speedMs < 2.8 {
                        let localScore = max(0, latestDangerScore - 3)
                        applyDangerScore(localScore, sourceFrame: frame)
                    } else {
                        let ttc = Double(frame.distance) / max(0.1, speedMs)
                        let threat = max(0.0, 1.0 - ttc / 8.0)
                        let localScore = min(100, Int(threat * 100))
                        applyDangerScore(localScore, sourceFrame: frame)
                    }
                } else {
                    let localScore = max(0, latestDangerScore - 5)
                    applyDangerScore(localScore, sourceFrame: frame)
                }

                Task {
                    await api.upload(frame: frame, authToken: AuthService.shared.token)
                    if let score = await api.fetchDangerScore(authToken: AuthService.shared.token) {
                        await MainActor.run { self.applyDangerScore(score, sourceFrame: frame) }
                    }
                }
            } catch {
                parseErrors += 1
            }
        }
    }

    private func applyDangerScore(_ score: Int, sourceFrame: RadarFrame?) {
        latestDangerScore = max(0, min(100, score))

        if latestDangerScore > dangerRecordThreshold {
            guard !hasRecordedCurrentDangerWindow else { return }
            guard let frame = sourceFrame ?? latestFrame else { return }
            let record = DangerRecord(
                dangerScore: latestDangerScore,
                targetId: frame.targetId,
                angle: frame.angle,
                distance: frame.distance,
                speed: frame.speed,
                direction: frame.direction
            )
            dangerRecords.append(record)
            if dangerRecords.count > maxDangerRecords {
                dangerRecords.removeFirst(dangerRecords.count - maxDangerRecords)
            }
            hasRecordedCurrentDangerWindow = true
        } else {
            hasRecordedCurrentDangerWindow = false
        }
    }

    private func startDangerScoreRefresh() {
        stopDangerScoreRefresh()
        dangerRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let score = await api.fetchDangerScore(authToken: AuthService.shared.token) {
                    await MainActor.run {
                        self.applyDangerScore(score, sourceFrame: self.latestFrame)
                    }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func stopDangerScoreRefresh() {
        dangerRefreshTask?.cancel()
        dangerRefreshTask = nil
    }

    private func scheduleReconnect() {
        guard shouldReconnect, let lastId = lastConnectedDeviceId else { return }
        autoReconnectTargetId = lastId
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self,
                  self.connectionState == .disconnected,
                  !self.isScanningGlasses else { return }
            self.scanPurpose = .radar
            self.connectionState = .scanning
            self.centralManager.scanForPeripherals(
                withServices: [BLEUUID.service],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    // MARK: - Brake detection

    private func startBrakeDetectionIfPossible() {
        guard connectionState == .connected,
              phoneWriteCharacteristic != nil,
              motionManager.isDeviceMotionAvailable else {
            return
        }
        if !motionManager.isDeviceMotionActive {
            motionQueue.qualityOfService = .userInitiated
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: motionQueue) { [weak self] data, error in
                if let error {
                    print("[Motion] DeviceMotion error: \(error.localizedDescription)")
                    return
                }
                guard let self,
                      let motionData = data else { return }
                let userAcc = motionData.userAcceleration
                let mag = sqrt(userAcc.x * userAcc.x + userAcc.y * userAcc.y + userAcc.z * userAcc.z)
                self.latestUserAccelMagnitude = mag
                let ts = motionData.timestamp
                DispatchQueue.main.async {
                    self.evaluateMotionBraking(userAcc: userAcc, timestamp: ts)
                }
            }
            print("[Motion] DeviceMotion updates started")
        }

        if CLLocationManager.locationServicesEnabled() {
            switch brakeLocationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                brakeLocationManager.startUpdatingLocation()
            case .notDetermined:
                brakeLocationManager.requestWhenInUseAuthorization()
            default:
                print("[Location] Permission denied/restricted")
            }
        }
    }

    private func stopBrakeDetection() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            print("[Motion] DeviceMotion updates stopped")
        }
        brakeLocationManager.stopUpdatingLocation()
        autoBrakeOffWorkItem?.cancel()
        autoBrakeOffWorkItem = nil
        if isDecelActive {
            sendBrakeState(false, source: "SYSTEM")
        }
        resetBrakeState()
    }

    private func resetBrakeState() {
        hasFilteredSpeed = false
        hasLastRawSpeed = false
        lastRawSpeed = 0
        recentPeakSpeed = 0
        recentPeakTimestamp = nil
        lastMotionTimestamp = nil
        prevMotionAccMag = 0
        pseudoVelX = 0
        pseudoVelY = 0
        pseudoVelZ = 0
        filteredSpeed = 0
        lastSpeedTimestamp = nil
        decelHoldSeconds = 0
        releaseHoldSeconds = 0
        isDecelActive = false
        autoBrakeOffWorkItem = nil
        latestUserAccelMagnitude = 0
    }

    private func evaluateBraking(with location: CLLocation) {
        let rawSpeed = location.speed
        guard rawSpeed >= 0 else { return }

        let timestamp = location.timestamp
        if lastSpeedTimestamp == nil {
            lastSpeedTimestamp = timestamp
            filteredSpeed = rawSpeed
            hasFilteredSpeed = true
            lastRawSpeed = rawSpeed
            hasLastRawSpeed = true
            recentPeakSpeed = rawSpeed
            recentPeakTimestamp = timestamp
            return
        }

        let dt = max(0.05, min(1.5, timestamp.timeIntervalSince(lastSpeedTimestamp!)))
        lastSpeedTimestamp = timestamp

        if !hasFilteredSpeed {
            filteredSpeed = rawSpeed
            hasFilteredSpeed = true
            return
        }

        let alpha = 0.35
        let newFilteredSpeed = filteredSpeed + alpha * (rawSpeed - filteredSpeed)
        let dvdt = (newFilteredSpeed - filteredSpeed) / dt
        let rawDvdt = hasLastRawSpeed ? (rawSpeed - lastRawSpeed) / dt : 0
        filteredSpeed = newFilteredSpeed
        lastRawSpeed = rawSpeed
        hasLastRawSpeed = true

        if recentPeakTimestamp == nil || timestamp.timeIntervalSince(recentPeakTimestamp!) > peakWindow {
            recentPeakSpeed = filteredSpeed
            recentPeakTimestamp = timestamp
        }
        if filteredSpeed > recentPeakSpeed {
            recentPeakSpeed = filteredSpeed
            recentPeakTimestamp = timestamp
        }
        let speedDrop = max(0, recentPeakSpeed - filteredSpeed)

        let decelFromSpeed =
            (filteredSpeed > minMovingSpeed) &&
            (
                (dvdt < decelThreshold) ||
                (rawDvdt < rawDecelThreshold) ||
                (speedDrop > speedDropThreshold)
            )
        let decelFromStrongMotion =
            (filteredSpeed > minMovingSpeed) &&
            (latestUserAccelMagnitude > strongMotionMagnitude) &&
            (rawDvdt < 0)
        let decelCondition = decelFromSpeed || decelFromStrongMotion

        if decelCondition && !isDecelActive {
            print("[BrakeDetect] speed=\(String(format: "%.2f", filteredSpeed)) drop=\(String(format: "%.2f", speedDrop)) dvdt=\(String(format: "%.2f", dvdt)) rawDvdt=\(String(format: "%.2f", rawDvdt)) acc=\(String(format: "%.2f", latestUserAccelMagnitude))")
        }

        let releaseCondition =
            (filteredSpeed < 0.8) ||
            ((dvdt > -0.05) && (rawDvdt > -0.05)) ||
            (latestUserAccelMagnitude < minMotionMagnitude)
        updateAutoBrakeState(
            triggerCandidate: decelCondition,
            releaseCandidate: releaseCondition,
            dt: dt,
            debugContext: "speed=\(String(format: "%.2f", filteredSpeed)) drop=\(String(format: "%.2f", speedDrop)) dvdt=\(String(format: "%.2f", dvdt)) rawDvdt=\(String(format: "%.2f", rawDvdt)) acc=\(String(format: "%.2f", latestUserAccelMagnitude))"
        )
    }

    private func evaluateMotionBraking(userAcc: CMAcceleration, timestamp: TimeInterval) {
        let dt = max(0.02, min(0.2, (lastMotionTimestamp == nil ? 0.1 : (timestamp - lastMotionTimestamp!))))
        lastMotionTimestamp = timestamp

        let ax = userAcc.x
        let ay = userAcc.y
        let az = userAcc.z

        let accMag = sqrt(ax * ax + ay * ay + az * az)
        let prevAccMag = prevMotionAccMag
        let jerk = (accMag - prevAccMag) / dt
        prevMotionAccMag = accMag

        let prevVx = pseudoVelX
        let prevVy = pseudoVelY
        let prevVz = pseudoVelZ
        let velLeak = 0.92
        pseudoVelX = pseudoVelX * velLeak + ax * dt
        pseudoVelY = pseudoVelY * velLeak + ay * dt
        pseudoVelZ = pseudoVelZ * velLeak + az * dt

        let velMag = sqrt(prevVx * prevVx + prevVy * prevVy + prevVz * prevVz)
        let dotAV = ax * prevVx + ay * prevVy + az * prevVz

        let vectorDecel = (dotAV < -0.010) && (accMag > 0.08) && (velMag > 0.02)
        let jerkDecel = (jerk < -0.8) && (prevAccMag > 0.15)
        let motionDecel = vectorDecel || jerkDecel
        let motionRelease = (accMag < 0.03) && (velMag < 0.02)

        updateAutoBrakeState(
            triggerCandidate: motionDecel,
            releaseCandidate: motionRelease,
            dt: dt,
            debugContext: "motion acc=\(String(format: "%.2f", accMag)) vel=\(String(format: "%.2f", velMag)) dot=\(String(format: "%.3f", dotAV)) jerk=\(String(format: "%.2f", jerk))"
        )
    }

    private func updateAutoBrakeState(
        triggerCandidate: Bool,
        releaseCandidate: Bool,
        dt: TimeInterval,
        debugContext: String
    ) {
        if triggerCandidate {
            decelHoldSeconds += dt
            releaseHoldSeconds = 0
        } else {
            decelHoldSeconds = 0
            if releaseCandidate {
                releaseHoldSeconds += dt
            } else {
                releaseHoldSeconds = 0
            }
        }

        if !isDecelActive && decelHoldSeconds >= decelEnterDuration {
            triggerAutoBrakePulse(debugContext: debugContext)
        } else if isDecelActive && releaseHoldSeconds >= decelExitDuration {
            isDecelActive = false
            sendBrakeState(false, source: "AUTO")
        }
    }

    private func triggerAutoBrakePulse(debugContext: String) {
        autoBrakeOffWorkItem?.cancel()
        isDecelActive = true
        decelHoldSeconds = 0
        releaseHoldSeconds = 0
        print("[BrakeDetect][AUTO] TRIGGER \(debugContext)")
        sendBrakeState(true, source: "AUTO")

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isDecelActive = false
            self.decelHoldSeconds = 0
            self.releaseHoldSeconds = 0
            self.sendBrakeState(false, source: "AUTO")
        }
        autoBrakeOffWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoBrakePulseDuration, execute: work)
    }

    private func sendBrakeState(_ active: Bool, source: String) {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let char = phoneWriteCharacteristic else { return }

        let payload = active ? "BRAKE,1\n" : "BRAKE,0\n"
        guard let data = payload.data(using: .utf8) else { return }

        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse
        peripheral.writeValue(data, for: char, type: writeType)
        print("[BLE][\(source)] Sent \(active ? "BRAKE,1" : "BRAKE,0")")
    }
}

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if self.shouldReconnect, self.lastConnectedDeviceId != nil {
                    self.scheduleReconnect()
                }
            case .poweredOff:
                self.connectionState = .bluetoothOff
                self.isScanning = false
                self.glassesState = .disconnected
                self.isScanningGlasses = false
            case .unauthorized:
                self.connectionState = .unauthorized
                self.isScanning = false
                self.glassesState = .disconnected
                self.isScanningGlasses = false
            default:
                self.connectionState = .disconnected
                self.isScanning = false
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let deviceId = peripheral.identifier
            let name = peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
                ?? "Unknown"
            let rssiVal = RSSI.intValue

            if self.scanPurpose == .glasses {
                self.glassesPeriMap[deviceId] = peripheral
                if let idx = self.glassesScanResults.firstIndex(where: { $0.id == deviceId }) {
                    self.glassesScanResults[idx].rssi = rssiVal
                    self.glassesScanResults[idx].lastSeen = Date()
                } else {
                    self.glassesScanResults.append(DiscoveredDevice(
                        id: deviceId, name: name, rssi: rssiVal, lastSeen: Date()
                    ))
                }
            } else {
                self.peripheralMap[deviceId] = peripheral
                if let idx = self.discoveredDevices.firstIndex(where: { $0.id == deviceId }) {
                    self.discoveredDevices[idx].rssi = rssiVal
                    self.discoveredDevices[idx].lastSeen = Date()
                } else {
                    self.discoveredDevices.append(DiscoveredDevice(
                        id: deviceId, name: name, rssi: rssiVal, lastSeen: Date()
                    ))
                }
                if let targetId = self.autoReconnectTargetId, deviceId == targetId {
                    self.autoReconnectTargetId = nil
                    self.connectDevice(deviceId)
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            if peripheral.identifier == self.glassesPeripheral?.identifier {
                self.glassesState = .connected
                self.glassesName = peripheral.name ?? "ESP32 Glasses"
                self.isScanningGlasses = false
                peripheral.discoverServices([BLEUUID.service])
            } else {
                self.connectionState = .connected
                self.isScanning = false
                self.connectedDeviceName = peripheral.name ?? "ESP32 Radar"
                self.lastConnectedDeviceId = peripheral.identifier
                self.startDangerScoreRefresh()
                peripheral.discoverServices([BLEUUID.service])
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if peripheral.identifier == self.glassesPeripheral?.identifier {
                self.glassesState = .disconnected
                self.glassesPeripheral = nil
            } else {
                self.connectionState = .disconnected
                self.scheduleReconnect()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if peripheral.identifier == self.glassesPeripheral?.identifier {
                self.glassesState = .disconnected
                self.glassesPeripheral = nil
                self.glassesWriteChar = nil
            } else {
                self.connectionState = .disconnected
                self.connectedPeripheral = nil
                self.radarNotifyCharacteristic = nil
                self.phoneWriteCharacteristic = nil
                self.dataBuffer = Data()
                self.stopDangerScoreRefresh()
                self.stopBrakeDetection()
                self.scheduleReconnect()
            }
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == BLEUUID.service {
            peripheral.discoverCharacteristics(
                [BLEUUID.radarNotify, BLEUUID.phoneWrite],
                for: service
            )
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            guard let characteristics = service.characteristics else { return }
            if peripheral.identifier == self.glassesPeripheral?.identifier {
                for char in characteristics {
                    if char.uuid == BLEUUID.phoneWrite {
                        self.glassesWriteChar = char
                        print("[BLE] Glasses write characteristic ready")
                    }
                }
            } else {
                for char in characteristics {
                    if char.uuid == BLEUUID.radarNotify {
                        self.radarNotifyCharacteristic = char
                        peripheral.setNotifyValue(true, for: char)
                        print("[BLE] Subscribed to radar characteristic")
                    } else if char.uuid == BLEUUID.phoneWrite {
                        self.phoneWriteCharacteristic = char
                        print("[BLE] Phone write characteristic is ready")
                    }
                }
                peripheral.readRSSI()
                self.startBrakeDetectionIfPossible()
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEUUID.radarNotify, let data = characteristic.value else { return }
        Task { @MainActor in
            self.processIncomingData(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        Task { @MainActor in
            if peripheral.identifier == self.glassesPeripheral?.identifier {
                self.glassesRssi = RSSI.intValue
            } else {
                self.rssi = RSSI.intValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard self?.connectionState == .connected else { return }
                    self?.connectedPeripheral?.readRSSI()
                }
            }
        }
    }
}

extension BLEManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedAlways ||
                manager.authorizationStatus == .authorizedWhenInUse {
                if self.connectionState == .connected, self.phoneWriteCharacteristic != nil {
                    manager.startUpdatingLocation()
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.evaluateBraking(with: last)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] update error: \(error.localizedDescription)")
    }
}

actor RadarAPIService {
    func upload(frame: RadarFrame, authToken: String?) async {
        guard let token = authToken else { return }
        guard let url = URL(string: AuthService.baseURL + "/api/radar/scan") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = [
            "targets": [[
                "target_id": frame.targetId,
                "angle": frame.angle,
                "distance": frame.distance,
                "speed": frame.speed,
                "direction": frame.direction
            ]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: request)
    }

    func fetchDangerScore(authToken: String?) async -> Int? {
        guard let token = authToken else { return nil }
        guard let url = URL(string: AuthService.baseURL + "/api/radar/danger") else { return nil }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return nil
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        struct DangerResp: Decodable { let dangerScore: Int }
        return try? JSONDecoder().decode(DangerResp.self, from: data).dangerScore
    }
}
