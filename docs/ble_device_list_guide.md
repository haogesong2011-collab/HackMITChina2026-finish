# BLE 设备列表 — iOS 端实现指引

本文档说明如何在 iPhone App 中实现扫描、列出、连接多个雷达 BLE 设备的功能。  
**后端不需要任何改动**，所有逻辑在 iOS 本地完成。

---

## 1. 前置条件

### Info.plist 权限

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接雷达设备</string>
```

### Background Modes（骑行时锁屏不断开）

在 Xcode → Signing & Capabilities → Background Modes 中勾选：

- Uses Bluetooth LE accessories

---

## 2. 核心类：BLEManager

用 `CBCentralManager` 管理扫描和连接。

```swift
import CoreBluetooth
import Combine

// 替换为你的雷达实际 Service UUID
let RADAR_SERVICE_UUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")

struct RadarDevice: Identifiable {
    let id: UUID           // CBPeripheral.identifier
    let name: String
    var rssi: Int          // 信号强度，越大越近
    let peripheral: CBPeripheral
}

class BLEManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [RadarDevice] = []
    @Published var connectedDevice: RadarDevice?
    @Published var isScanning = false

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices = []
        isScanning = true
        // 按 Service UUID 过滤，只显示雷达设备
        centralManager.scanForPeripherals(
            withServices: [RADAR_SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func connect(_ device: RadarDevice) {
        // 先断开当前连接
        if let current = connectedDevice {
            centralManager.cancelPeripheralConnection(current.peripheral)
        }
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let device = connectedDevice else { return }
        centralManager.cancelPeripheralConnection(device.peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        }
    }

    func centralManager(_ central: CBCentralManager,
                         didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any],
                         rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "未知雷达"

        // 去重：已发现则更新 RSSI
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].rssi = RSSI.intValue
        } else {
            let device = RadarDevice(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                peripheral: peripheral
            )
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager,
                         didConnect peripheral: CBPeripheral) {
        stopScan()
        connectedDevice = discoveredDevices.first { $0.id == peripheral.identifier }
        // 连接成功后发现服务
        peripheral.delegate = self as? CBPeripheralDelegate
        peripheral.discoverServices([RADAR_SERVICE_UUID])
    }

    func centralManager(_ central: CBCentralManager,
                         didDisconnectPeripheral peripheral: CBPeripheral,
                         error: Error?) {
        if connectedDevice?.id == peripheral.identifier {
            connectedDevice = nil
        }
    }
}
```

---

## 3. SwiftUI 设备列表页面

```swift
import SwiftUI

struct BLEDeviceListView: View {
    @StateObject private var bleManager = BLEManager()

    var body: some View {
        NavigationStack {
            List {
                // 已连接设备
                if let connected = bleManager.connectedDevice {
                    Section("已连接") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(connected.name).font(.headline)
                                Text("信号: \(connected.rssi) dBm").font(.caption)
                            }
                            Spacer()
                            Button("断开") {
                                bleManager.disconnect()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                // 附近设备列表
                Section("附近的雷达设备") {
                    if bleManager.discoveredDevices.isEmpty {
                        Text("正在搜索...")
                            .foregroundColor(.secondary)
                    }
                    ForEach(bleManager.discoveredDevices.sorted(by: { $0.rssi > $1.rssi })) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name).font(.headline)
                                Text("信号: \(device.rssi) dBm").font(.caption)
                            }
                            Spacer()
                            Button("连接") {
                                bleManager.connect(device)
                            }
                        }
                        .disabled(bleManager.connectedDevice?.id == device.id)
                    }
                }
            }
            .navigationTitle("雷达设备")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(bleManager.isScanning ? "停止扫描" : "扫描") {
                        bleManager.isScanning ? bleManager.stopScan() : bleManager.startScan()
                    }
                }
            }
        }
    }
}
```

---

## 4. 关键要点

### 如何区分多个雷达？

- **靠设备名（`peripheral.name`）**：建议硬件端给每个雷达设定唯一名称，如 `Radar-001`、`Radar-002`
- **靠信号强度（RSSI）**：列表默认按信号从强到弱排序，最近的排最前

### 同时连多个雷达？

Core Bluetooth 技术上支持同时连接多个 BLE 外设。但对于骑行场景，建议一次只连一个雷达，避免数据混淆。如需多雷达方案，需要在上传时标记数据来源。

### 需要硬件端确认的信息

| 项目 | 说明 |
|------|------|
| Service UUID | 雷达的 BLE Service UUID（代码示例中用的 `0000FFE0-...` 需替换为实际值） |
| Characteristic UUID | 读取雷达数据的 Characteristic UUID |
| 写入 Characteristic UUID | 控制 LED 等功能时需要的可写 Characteristic UUID |
| 广播名格式 | 每个雷达的 `localName` 命名规则 |
