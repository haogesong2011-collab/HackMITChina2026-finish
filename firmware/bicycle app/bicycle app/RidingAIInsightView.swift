//
//  RidingAIInsightView.swift
//  bicycle app
//
//  演示用：AI 骑行习惯分析占位页（无真实模型与上报）。
//

import SwiftUI

struct RidingAIInsightView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    /// 示例柱状图高度 0...1
    private let demoBarHeights: [CGFloat] = [0.45, 0.72, 0.55, 0.88]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroBanner

                habitOverviewCard

                suggestionsCard

                Text(t.aiRidingDisclaimer)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle(t.aiRidingNavTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.9), Color(hex: "7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(t.aiRidingEntryTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(t.aiRidingDemoBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.12), in: Capsule())
                }
                Text(t.aiRidingEntrySubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.cardBg, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }

    private var habitOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t.aiRidingHabitSection)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text(t.aiRidingChartCaption)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(demoBarHeights.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 72 * h)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)
            .padding(.vertical, 4)

            VStack(spacing: 0) {
                aiMetricRow(label: t.aiRidingMetricRidesLabel, value: t.aiRidingMetricRidesValue)
                Divider().padding(.leading, 12)
                aiMetricRow(label: t.aiRidingMetricDurationLabel, value: t.aiRidingMetricDurationValue)
                Divider().padding(.leading, 12)
                aiMetricRow(label: t.aiRidingMetricNightLabel, value: t.aiRidingMetricNightValue)
            }
            .padding(.vertical, 4)
        }
        .padding(16)
        .stravaCard()
    }

    private func aiMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
        }
        .padding(.vertical, 10)
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.aiRidingSuggestionsSection)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            suggestionBullet(t.aiRidingSuggestion1)
            suggestionBullet(t.aiRidingSuggestion2)
            suggestionBullet(t.aiRidingSuggestion3)
        }
        .padding(16)
        .stravaCard()
    }

    private func suggestionBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(AppTheme.warning)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
