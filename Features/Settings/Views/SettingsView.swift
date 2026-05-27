import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Alerts") {
                NavigationLink {
                    NotificationPreferencesView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
//
//  SettingsView.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 4/27/26.
//

