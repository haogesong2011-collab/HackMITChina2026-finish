//
//  LoginView.swift
//  bicycle app
//

import SwiftUI

struct LoginView: View {
    @Bindable var auth: AuthService
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue
    @State private var username = ""
    @State private var password = ""
    @State private var isRegisterMode = false

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandSection
                    .padding(.top, 48)
                    .padding(.bottom, 40)

                formCard
                    .padding(.horizontal, 20)

                Button {
                    isRegisterMode.toggle()
                    auth.errorMessage = ""
                } label: {
                    Text(isRegisterMode ? t.loginToggleLogin : t.loginToggleRegister)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var brandSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Text("S")
                    .foregroundStyle(AppTheme.accent)
                Text(".")
                    .foregroundStyle(AppTheme.text)
                Text("X")
                    .foregroundStyle(AppTheme.accent)
                Text(".")
                    .foregroundStyle(AppTheme.text)
                Text("L")
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.system(size: 40, weight: .heavy, design: .rounded))

            (
                Text("S").foregroundStyle(AppTheme.accent)
                    + Text("afer ").foregroundStyle(AppTheme.text)
                    + Text(".").foregroundStyle(AppTheme.text)
                    + Text("e").foregroundStyle(AppTheme.text)
                    + Text("X").foregroundStyle(AppTheme.accent)
                    + Text("ploration").foregroundStyle(AppTheme.text)
                    + Text(" . ").foregroundStyle(AppTheme.text)
                    + Text("L").foregroundStyle(AppTheme.accent)
                    + Text("ifestyle").foregroundStyle(AppTheme.text)
            )
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
        }
    }

    private var formCard: some View {
        VStack(spacing: 16) {
            stravaTextField(t.loginUsername, text: $username, isSecure: false)
            stravaTextField(t.loginPassword, text: $password, isSecure: true)

            if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                submit()
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isRegisterMode ? t.registerSubmit : t.loginSubmit)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .disabled(auth.isLoading)
        }
        .padding(20)
        .stravaCard()
    }

    private func stravaTextField(_ placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(AppTheme.inputBg, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(AppTheme.text)
    }

    private func submit() {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty, !p.isEmpty else {
            auth.errorMessage = t.loginEmptyError
            return
        }

        Task {
            if isRegisterMode {
                _ = await auth.register(username: u, password: p)
            } else {
                _ = await auth.login(username: u, password: p)
            }
        }
    }
}
