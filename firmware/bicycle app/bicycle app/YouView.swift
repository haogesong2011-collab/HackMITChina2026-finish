//
//  YouView.swift
//  bicycle app
//

import SwiftUI
import UIKit

struct YouView: View {
    @Bindable var auth: AuthService
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    aiRidingEntryCard
                    statsRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(t.youNavTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(auth: auth)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Text(initialLetter)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text(auth.currentUser?.username ?? "—")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.text)

                roleBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .stravaCard()
    }

    private var initialLetter: String {
        let name = auth.currentUser?.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private var aiRidingEntryCard: some View {
        NavigationLink {
            RidingAIInsightView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t.aiRidingEntryTitle)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(t.aiRidingDemoBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                    Text(t.aiRidingEntrySubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.6))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .stravaCard()
    }

    private var roleBadge: some View {
        Text(t.settingsGuardianEnabled)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(AppTheme.accent.opacity(0.12), in: Capsule())
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.settingsStatsTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            HStack(spacing: 0) {
                statCell(title: t.settingsStatDistance, value: "—")
                Divider().frame(height: 48)
                statCell(title: t.settingsStatRides, value: "—")
                Divider().frame(height: 48)
                statCell(title: t.settingsStatSpeed, value: "—")
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .stravaCard()
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsView: View {
    @Bindable var auth: AuthService
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue
    @State private var copiedInvite = false
    @State private var inviteInput = ""
    @State private var bindMessage = ""

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    private var inviteCode: String {
        auth.currentUser?.inviteCode ?? ""
    }

    private var inviteText: String {
        let user = auth.currentUser?.username ?? (lang == .chinese ? "我" : "me")
        return t.inviteShareBody(username: user, code: inviteCode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                languageSection
                inviteGuardianSection
                accountSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle(t.settingsTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.settingsLanguage)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Picker("", selection: $languageCode) {
                ForEach(AppLanguage.allCases) { code in
                    Text(code.pickerTitle).tag(code.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .stravaCard()
    }

    private var inviteGuardianSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.settingsInviteTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text(t.settingsInviteHint)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            Text(watchListStatusText)
                .font(.caption)
                .foregroundStyle(watchListStatusColor)

            HStack {
                Text(inviteCode.isEmpty ? t.settingsNoCode : inviteCode)
                    .font(.title3.monospaced().weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Image(systemName: copiedInvite ? "checkmark.circle.fill" : "number.square")
                    .foregroundStyle(copiedInvite ? AppTheme.success : AppTheme.secondaryText)
            }
            .padding(14)
            .background(AppTheme.inputBg, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    guard !inviteCode.isEmpty else { return }
                    UIPasteboard.general.string = inviteCode
                    copiedInvite = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedInvite = false
                    }
                } label: {
                    Label(copiedInvite ? t.settingsCopied : t.settingsCopyCode, systemImage: copiedInvite ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inviteCode.isEmpty)

                ShareLink(item: inviteText) {
                    Label(t.settingsShareInvite, systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(inviteCode.isEmpty)
            }

            Divider()
                .padding(.vertical, 4)

            Text(t.settingsAddGuardianTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)

            TextField(t.settingsInvitePlaceholder, text: $inviteInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(AppTheme.inputBg, in: RoundedRectangle(cornerRadius: 10))

            Button {
                addWatch()
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(t.settingsAddButton, systemImage: "person.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(auth.isLoading || inviteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !bindMessage.isEmpty {
                Text(bindMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            } else if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .stravaCard()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.settingsAccount)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Button(t.settingsLogout, role: .destructive) {
                auth.logout()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .stravaCard()
    }

    private func addWatch() {
        let code = inviteInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        bindMessage = ""
        auth.errorMessage = ""
        Task {
            let ok = await auth.addToWatchList(code)
            await MainActor.run {
                if ok {
                    bindMessage = t.settingsAddSuccess
                    inviteInput = ""
                } else {
                    bindMessage = ""
                }
            }
        }
    }

    private var watchListStatusText: String {
        let count = auth.currentUser?.watchList?.count ?? 0
        return t.watchListStatus(count: count)
    }

    private var watchListStatusColor: Color {
        let count = auth.currentUser?.watchList?.count ?? 0
        return count > 0 ? AppTheme.success : AppTheme.warning
    }
}
