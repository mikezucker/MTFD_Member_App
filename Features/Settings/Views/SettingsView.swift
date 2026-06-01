import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var isSendingResetLink = false
    @State private var resetMessage: String?
    @State private var resetError: String?

    private var accountEmail: String {
        (session.currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section("Account") {
                if !accountEmail.isEmpty {
                    LabeledContent("Email", value: accountEmail)
                }

                Button {
                    Task {
                        await sendPasswordResetLink()
                    }
                } label: {
                    HStack {
                        Label("Send Password Reset Link", systemImage: "key.fill")

                        Spacer()

                        if isSendingResetLink {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSendingResetLink || accountEmail.isEmpty)

                if let resetMessage {
                    Text(resetMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                if let resetError {
                    Text(resetError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Dashboard") {
                NavigationLink {
                    DashboardLayoutView()
                } label: {
                    Label("Dashboard Layout", systemImage: "rectangle.grid.2x2.fill")
                }
            }

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

    @MainActor
    private func sendPasswordResetLink() async {
        let email = accountEmail.lowercased()

        guard !email.isEmpty else {
            resetError = "No account email is available."
            resetMessage = nil
            return
        }

        isSendingResetLink = true
        resetMessage = nil
        resetError = nil

        do {
            let response = try await APIClient.shared.requestPasswordReset(email: email)

            if response.ok {
                resetMessage = "If this email is recognized, a reset link will be sent shortly."
            } else {
                resetError = response.error ?? "Unable to send reset link."
            }
        } catch {
            resetError = error.localizedDescription
        }

        isSendingResetLink = false
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

