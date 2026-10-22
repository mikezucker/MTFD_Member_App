import SwiftUI
import WatchConnectivity
import Combine

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

            Section("Devices") {
                NavigationLink {
                    AppleWatchSettingsView()
                } label: {
                    Label("Apple Watch", systemImage: "applewatch")
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

            Section("Siri") {
                NavigationLink {
                    SiriShortcutsView()
                } label: {
                    Label("Siri Shortcuts", systemImage: "sparkles")
                        .foregroundStyle(.blue)
                }
            }

            Section("Privacy & Support") {
                Link(destination: URL(string: "https://new-mtfd-site.vercel.app/app-privacy")!) {
                    Label("App Privacy & Support", systemImage: "hand.raised.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented:$showPasswordRecovery) { ForgotPasswordView(initialEmail:accountEmail) }
    }


}

#if targetEnvironment(simulator)
#Preview {
    NavigationStack {
        SettingsView()
    }
}
#endif
//
//  SettingsView.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 4/27/26.
//


@MainActor
final class WatchSettingsController: ObservableObject {
    static let shared = WatchSettingsController()
    @Published private(set) var connection = "Checking…"
    @Published private(set) var canTest = false
    @Published var status: String?
    @Published private(set) var isTesting = false
    private var testTimeout: Task<Void, Never>?
    private var testID: UUID?

    func refreshConnection() {
        guard WCSession.isSupported() else {
            connection = "Not supported"
            canTest = false
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            connection = "Connecting…"
            canTest = false
            return
        }
        canTest = session.activationState == .activated && session.isPaired
            && session.isWatchAppInstalled && session.isReachable
        if !session.isPaired { connection = "No Watch paired" }
        else if !session.isWatchAppInstalled { connection = "Install MTFD on your Watch" }
        else if canTest { connection = "Connected" }
        else { connection = "Installed · not currently reachable" }
    }

    private var settingsMessage: [String: Any] {
        ["action": "watch_settings",
         "hapticsEnabled": UserDefaults.standard.object(forKey: "watch_dispatch_haptics_enabled") as? Bool ?? true,
         "hapticStyle": UserDefaults.standard.string(forKey: "watch_dispatch_haptic_style") ?? "followPhone",
         "phoneHapticStyle": UserDefaults.standard.string(forKey: "notification_haptic_alert_style") ?? "normal"]
    }

    func sync() {
        refreshConnection()
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else {
            status = connection
            return
        }
        let message = settingsMessage
        do {
            try WCSession.default.updateApplicationContext(message)
            status = "Settings queued for your Watch."
        } catch { status = "Could not sync: \(error.localizedDescription)" }
        if canTest {
            WCSession.default.sendMessage(message, replyHandler: { reply in
                Task { @MainActor in
                    self.status = reply["applied"] as? Bool == true
                        ? "Settings applied on your Watch." : "Watch did not confirm settings."
                }
            }, errorHandler: { error in
                Task { @MainActor in self.status = "Sync pending: \(error.localizedDescription)" }
            })
        }
    }

    func test() {
        refreshConnection()
        guard canTest, !isTesting else { return }
        var message = settingsMessage
        message["action"] = "test_dispatch_haptic"
        isTesting = true
        status = "Waiting for your Watch…"
        let id = UUID()
        testID = id
        testTimeout = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
            finishTest(id, status: "No reply. Open MTFD on your Watch and try again.")
        }
        WCSession.default.sendMessage(message, replyHandler: { reply in
            Task { @MainActor in
                self.finishTest(id, status: reply["played"] as? Bool == true
                    ? "Watch started the test pattern. Confirm you felt it."
                    : "Open MTFD on your Watch and enable Watch haptics, then try again.")
            }
        }, errorHandler: { error in
            Task { @MainActor in self.finishTest(id, status: "Test failed: \(error.localizedDescription)") }
        })
    }

    private func finishTest(_ id: UUID, status: String) {
        guard testID == id else { return }
        testTimeout?.cancel()
        testTimeout = nil
        testID = nil
        isTesting = false
        self.status = status
    }
}

struct AppleWatchSettingsView: View {
    @StateObject private var controller = WatchSettingsController.shared
    @AppStorage("watch_dispatch_haptics_enabled") private var hapticsEnabled = true
    @AppStorage("watch_dispatch_haptic_style") private var hapticStyle = "followPhone"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("MTFD on Apple Watch", value: controller.connection)
                Button("Refresh Connection & Sync") { controller.sync() }
            }
            Section {
                Toggle("Extra Dispatch Haptics", isOn: $hapticsEnabled)
                Picker("Haptic Pattern", selection: $hapticStyle) {
                    Text("Follow iPhone App").tag("followPhone")
                    Text("Normal").tag("normal")
                    Text("Strong").tag("strong")
                    Text("Pager Style").tag("pagerStyle")
                }
                .disabled(!hapticsEnabled)
                Button(controller.isTesting ? "Testing…" : "Test Watch Haptics") { controller.test() }
                    .disabled(!controller.canTest || !hapticsEnabled || controller.isTesting)
                if let status = controller.status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("While MTFD Is Open on Watch") }
              footer: { Text("Open MTFD on your Watch for the test. These settings control extra in-app taps and do not change system notification vibrations.") }
            Section("Background Dispatch Alerts") {
                Text("On Apple Watch, open Settings → Sounds & Haptics and choose Prominent for more noticeable system alerts.")
                Text("On iPhone, open the Watch app → Notifications and allow MTFD alerts. Focus, wrist detection, and Apple’s notification routing determine where alerts appear.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Apple Watch")
        .task { controller.sync() }
        .onChange(of: hapticsEnabled) { _, _ in controller.sync() }
        .onChange(of: hapticStyle) { _, _ in controller.sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.refreshConnection() }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            controller.refreshConnection()
        }
    }
}
