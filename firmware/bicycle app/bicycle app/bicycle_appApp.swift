//
//  bicycle_appApp.swift
//  bicycle app
//
//  Created by Haoge on 2026/3/27.
//

import SwiftUI

@main
struct bicycle_appApp: App {
    @State private var auth = AuthService.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            withAnimation(.easeOut(duration: 0.25)) {
                                showSplash = false
                            }
                        }
                } else {
                    Group {
                        if auth.isLoggedIn {
                            MainTabView(auth: auth)
                        } else {
                            LoginView(auth: auth)
                        }
                    }
                }
            }
            .tint(AppTheme.accent)
        }
    }
}

private struct SplashScreenView: View {
    var body: some View {
        Image("SplashScreen")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}
