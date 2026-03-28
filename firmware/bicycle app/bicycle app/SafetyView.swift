//
//  SafetyView.swift
//  bicycle app
//

import SwiftUI

struct SafetyView: View {
    var ble: BLEManager
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dangerGaugeCard
                    if let frame = ble.latestFrame {
                        latestTargetCard(frame)
                    }
                    dangerRecordsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(t.safetyNavTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Danger gauge

    private var dangerGaugeCard: some View {
        VStack(spacing: 12) {
            Text(t.safetyDangerIndexTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            ZStack {
                Circle()
                    .stroke(AppTheme.secondaryText.opacity(0.15), lineWidth: 14)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: CGFloat(ble.latestDangerScore) / 100)
                    .stroke(
                        dangerArcColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(ble.latestDangerScore)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                    Text(dangerLevelText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(dangerLevelColor)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .stravaCard()
    }

    private var dangerArcColor: Color {
        let s = ble.latestDangerScore
        if s < 35 { return AppTheme.success }
        if s < 70 { return AppTheme.warning }
        return AppTheme.danger
    }

    private var dangerLevelText: String {
        let s = ble.latestDangerScore
        if s < 35 { return t.safetyLevelSafe }
        if s < 70 { return t.safetyLevelCaution }
        return t.safetyLevelDanger
    }

    private var dangerLevelColor: Color {
        let s = ble.latestDangerScore
        if s < 35 { return AppTheme.success }
        if s < 70 { return AppTheme.warning }
        return AppTheme.danger
    }

    // MARK: - Latest target

    private func latestTargetCard(_ frame: RadarFrame) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.safetyLatestTargetTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(alignment: .center, spacing: 16) {
                Image(systemName: sideSystemImage(for: frame))
                    .font(.system(size: 40))
                    .foregroundStyle(frame.isApproaching ? AppTheme.danger : AppTheme.accent)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t.localizedSide(frame.sideDescription))
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.text)
                    Text(t.localizedDirection(frame.direction))
                        .font(.subheadline)
                        .foregroundStyle(frame.isApproaching ? AppTheme.danger : AppTheme.secondaryText)
                    HStack(spacing: 16) {
                        Label("\(frame.distance) m", systemImage: "ruler")
                        Label("\(frame.speed) km/h", systemImage: "speedometer")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .stravaCard()
    }

    private func sideSystemImage(for frame: RadarFrame) -> String {
        if frame.angle < -2 { return "arrow.left.circle.fill" }
        if frame.angle > 2 { return "arrow.right.circle.fill" }
        return "arrow.down.circle.fill"
    }

    // MARK: - Danger records

    private var dangerRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.safetyRecordsSectionTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if ble.dangerRecords.isEmpty {
                Text(t.safetyRecordsEmptyHint)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .stravaCard()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(ble.dangerRecords.reversed().prefix(20)) { record in
                        dangerRecordRow(record)
                    }
                }
            }
        }
    }

    private func dangerRecordRow(_ record: DangerRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sideSystemImage(angle: record.angle))
                .font(.title2)
                .foregroundStyle(AppTheme.danger)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(t.peopleRecordLine1(score: record.dangerScore, side: record.sideDescription))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.danger)
                Text(t.safetyRecordLine2(
                    targetId: record.targetId,
                    direction: record.direction,
                    distance: record.distance,
                    speed: record.speed,
                    angle: record.angle
                ))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(Self.timeFormatter.string(from: record.recordedAt))
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
        }
        .padding(14)
        .background(AppTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.danger.opacity(0.35), lineWidth: 1.5)
        }
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 1)
    }

    private func sideSystemImage(angle: Int) -> String {
        if angle < -2 { return "arrow.left.circle.fill" }
        if angle > 2 { return "arrow.right.circle.fill" }
        return "arrow.down.circle.fill"
    }
}
