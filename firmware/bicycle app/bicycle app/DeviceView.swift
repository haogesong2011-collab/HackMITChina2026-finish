//
//  DeviceView.swift
//  bicycle app
//

import SwiftUI

struct DeviceView: View {
    var ble: BLEManager
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    connectionCard
                    deviceListSection
                    if ble.connectionState == .connected {
                        deviceInfoSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(t.deviceNavTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()

                if ble.connectionState == .connected {
                    rssiBarsView
                }
            }

            connectionButton
        }
        .padding(16)
        .stravaCard()
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch ble.connectionState {
        case .connected:
            Button { ble.disconnect() } label: {
                Text(t.deviceDisconnect)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.secondaryText.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(AppTheme.text)
            }
            .buttonStyle(.plain)
        case .scanning:
            Button { ble.stopScan() } label: {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t.deviceStopScan)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(AppTheme.warning)
            }
            .buttonStyle(.plain)
        case .connecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(t.deviceConnectingEllipsis)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        default:
            Button { ble.startScan() } label: {
                Text(t.deviceSearchDevices)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(ble.connectionState == .bluetoothOff || ble.connectionState == .unauthorized)
        }
    }

    private var statusIcon: String {
        switch ble.connectionState {
        case .connected: "antenna.radiowaves.left.and.right"
        case .scanning, .connecting: "dot.radiowaves.left.and.right"
        case .bluetoothOff: "bolt.slash.fill"
        case .unauthorized: "lock.fill"
        case .disconnected: "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var statusColor: Color {
        switch ble.connectionState {
        case .connected: AppTheme.success
        case .scanning, .connecting: AppTheme.warning
        default: AppTheme.secondaryText
        }
    }

    private var statusTitle: String {
        switch ble.connectionState {
        case .connected:
            return ble.connectedDeviceName ?? t.deviceConnectedFallbackName
        case .scanning:
            return t.deviceStatusSearching
        case .connecting:
            let name = ble.connectedDeviceName ?? t.deviceGenericName
            return t.deviceStatusConnecting(to: name)
        case .bluetoothOff:
            return t.deviceBluetoothOffTitle
        case .unauthorized:
            return t.deviceBluetoothUnauthorizedTitle
        case .disconnected:
            return t.deviceDisconnectedTitle
        }
    }

    private var statusSubtitle: String {
        switch ble.connectionState {
        case .connected:
            return t.deviceSubtitleConnected(rssi: ble.rssi)
        case .scanning:
            return t.deviceSubtitleScanning
        case .connecting:
            return t.deviceSubtitleEstablishing
        case .bluetoothOff:
            return t.deviceSubtitleBluetoothOff
        case .unauthorized:
            return t.deviceSubtitleUnauthorized
        case .disconnected:
            return t.deviceSubtitleDisconnected
        }
    }

    private var rssiBarsView: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < rssiBarCount ? AppTheme.accent : AppTheme.secondaryText.opacity(0.2))
                    .frame(width: 5, height: CGFloat(8 + i * 4))
            }
        }
    }

    private var rssiBarCount: Int {
        let r = ble.rssi
        if r == 0 { return 0 }
        if r >= -55 { return 4 }
        if r >= -65 { return 3 }
        if r >= -75 { return 2 }
        if r >= -85 { return 1 }
        return 0
    }

    // MARK: - Device List

    @ViewBuilder
    private var deviceListSection: some View {
        if ble.isScanning || (!ble.discoveredDevices.isEmpty && ble.connectionState != .connected) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t.deviceDiscoveredSectionTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    if ble.isScanning {
                        ProgressView().scaleEffect(0.8)
                    }
                }

                if ble.discoveredDevices.isEmpty {
                    Text(t.deviceSearchingNearby)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .stravaCard()
                } else {
                    ForEach(ble.discoveredDevices) { device in
                        deviceRow(device)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        Button {
            ble.connectDevice(device.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.text)
                    Text(t.deviceSignalLabel(rssi: device.rssi))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text(t.deviceConnect)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(AppTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(ble.connectionState == .connecting)
    }

    // MARK: - Device Info

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.deviceInfoSectionTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            VStack(spacing: 0) {
                infoRow(label: t.deviceInfoName, value: ble.connectedDeviceName ?? "-")
                Divider().padding(.leading, 16)
                infoRow(label: t.deviceInfoRSSI, value: "\(ble.rssi) dBm")
                Divider().padding(.leading, 16)
                infoRow(label: t.deviceInfoFrames, value: t.deviceInfoFramesValue(ble.totalReceived))
                Divider().padding(.leading, 16)
                infoRow(label: t.deviceInfoParseErrors, value: "\(ble.parseErrors)")
            }
            .stravaCard()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
