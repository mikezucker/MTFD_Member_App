import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var showPasswordRecovery = false

    private var accountEmail: String {
        (session.currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section("Account") {
                if !accountEmail.isEmpty {
                    LabeledContent("Email", value: accountEmail)
                }

                Button { showPasswordRecovery = true } label: {
                    Label("Request Password Recovery",systemImage:"key.fill").foregroundStyle(.blue)
                }
            }


            Section("Alerts") {
                NavigationLink {
                    LiveActivitiesSettingsView()
                } label: {
                    Label("Live Activities", systemImage: "rectangle.on.rectangle")
                        .foregroundStyle(.blue)
                }

                NavigationLink {
                    NotificationPreferencesView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                        .foregroundStyle(.blue)
                }
            }

            Section("Dashboard") {
                NavigationLink {
                    DashboardLayoutView()
                } label: {
                    Label("Edit Dashboard", systemImage: "rectangle.grid.2x2")
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented:$showPasswordRecovery) { ForgotPasswordView(initialEmail:accountEmail) }
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
