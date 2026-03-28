//
//  MainTabView.swift
//  bicycle app
//

import SwiftUI

struct MainTabView: View {
    @Bindable var auth: AuthService
    @State private var ble = BLEManager()
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        TabView {
            MapsView(ble: ble)
                .tabItem {
                    Label(t.tabMap, systemImage: "map.fill")
                }

            SafetyView(ble: ble)
                .tabItem {
                    Label(t.tabSafety, systemImage: "shield.lefthalf.filled")
                }

            DeviceView(ble: ble)
                .tabItem {
                    Label(t.tabDevice, systemImage: "antenna.radiowaves.left.and.right")
                }

            RelatedPeopleView(auth: auth)
                .tabItem {
                    Label(t.tabPeople, systemImage: "person.2.fill")
                }

            YouView(auth: auth)
                .tabItem {
                    Label(t.tabYou, systemImage: "person.fill")
                }
        }
        .tint(AppTheme.accent)
        .background(AppTheme.bg)
    }
}
