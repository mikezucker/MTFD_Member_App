import SwiftUI

struct LiveActivitiesSettingsView: View {
    @AppStorage("liveActivitiesEnabled")
    private var liveActivitiesEnabled = true

    @AppStorage("liveActivitiesEndWhenDispatchClears")
    private var endWhenDispatchClears = true

    var body: some View {
        Form {
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
        .onChange(of: liveActivitiesEnabled) { _, enabled in
            if !enabled {
                DispatchLiveActivityManager.shared.endAll()
            }
        }
    }
}

#Preview {
    NavigationStack {
        LiveActivitiesSettingsView()
    }
}
