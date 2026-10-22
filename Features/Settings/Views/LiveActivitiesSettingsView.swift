import SwiftUI
import UIKit

struct LiveActivitiesSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var systemAllowed = false
    @AppStorage("liveActivitiesEnabled")
    private var liveActivitiesEnabled = true

    @AppStorage("liveActivitiesEndWhenDispatchClears")
    private var endWhenDispatchClears = true

    var body: some View {
        Form {
            Section("iPhone Permission") {
                LabeledContent("Live Activities", value: systemAllowed ? "Allowed" : "Off in iPhone Settings")
                Button("Open iPhone App Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
            Section {
                Toggle(isOn: $liveActivitiesEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Show Live Activities")
                                .font(.body.weight(.semibold))

                            Text("Display active dispatches on the Lock Screen and Dynamic Island.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .tint(.blue)
            } header: {
                Text("Dispatch Display")
            } footer: {
                Text("Live Activities are separate from push notifications. Turning this off will not stop dispatch alerts.")
            }

            Section {
                Toggle(isOn: $endWhenDispatchClears) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("End When Dispatch Clears")
                                .font(.body.weight(.semibold))

                            Text("Automatically remove the Live Activity when the dispatch is no longer active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .tint(.blue)
            } header: {
                Text("Behavior")
            }
        }
        .tint(.blue)
        .navigationTitle("Live Activities")
        .task { systemAllowed = DispatchLiveActivityManager.shared.liveActivitiesAvailable }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { systemAllowed = DispatchLiveActivityManager.shared.liveActivitiesAvailable }
        }
        .onChange(of: liveActivitiesEnabled) { _, enabled in
            if !enabled {
                DispatchLiveActivityManager.shared.endAll()
            }
            NotificationCenter.default.post(name: Notification.Name("liveActivityPreferencesDidChange"), object: nil)
        }
        .onChange(of: endWhenDispatchClears) { _, _ in
            NotificationCenter.default.post(name: Notification.Name("liveActivityPreferencesDidChange"), object: nil)
        }
    }
}

#if targetEnvironment(simulator)
#Preview {
    NavigationStack {
        LiveActivitiesSettingsView()
    }
}
#endif
