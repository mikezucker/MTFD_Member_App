import SwiftUI

struct NotificationPreferencesView: View {
    @StateObject private var vm = NotificationPreferencesViewModel()
    @StateObject private var unitCatalog = UnitCatalog()

    private var allUnitsBinding: Binding<Bool> {
        Binding(
            get: { vm.preferences.allUnits },
            set: { isOn in
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.preferences.allUnits = isOn
                    if isOn { vm.preferences.units.removeAll() }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
    }

    var body: some View {
        Form {

            // MARK: - Master
            Section {
                Toggle("Enable Notifications", isOn: $vm.preferences.isEnabled)
            }

            // MARK: - Dispatch
            Section {
                Toggle("Dispatch Alerts", isOn: $vm.preferences.dispatchAlertsEnabled)

                Toggle("Critical Dispatch Alerts", isOn: $vm.preferences.criticalDispatchAlerts)

                Toggle("Working Fires Only", isOn: $vm.preferences.workingOnly)

                Toggle("All Apparatus", isOn: allUnitsBinding)

                if !vm.preferences.allUnits {
                    unitListView
                }

            } header: {
                Text("Dispatch")
            } footer: {
                Text("Critical alerts may bypass silent mode and Focus. Use only if required for emergency response.")
            }

            // MARK: - Messages
            Section {
                Toggle("Department Messages", isOn: $vm.preferences.departmentMessagesEnabled)
                Toggle("Station Messages", isOn: $vm.preferences.stationMessagesEnabled)
                Toggle("Message Center", isOn: $vm.preferences.messageCenterEnabled)
            } header: {
                Text("Messages")
            }

            // MARK: - Training & Documents
            Section {
                Toggle("Training Assignments", isOn: $vm.preferences.trainingAssignmentsEnabled)
                Toggle("Document / SOP Assignments", isOn: $vm.preferences.documentAssignmentsEnabled)
            } header: {
                Text("Training & Documents")
            }

            // MARK: - Quiet Hours
            Section {
                Toggle("Quiet Hours", isOn: $vm.preferences.quietHoursEnabled)

                if vm.preferences.quietHoursEnabled {
                    DatePicker("Start", selection: $vm.preferences.quietStart, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $vm.preferences.quietEnd, displayedComponents: .hourAndMinute)
                }
            }

            // MARK: - Behavior
            Section {
                Toggle("Respect Focus / Do Not Disturb", isOn: $vm.preferences.respectDoNotDisturb)
            }

        }
        .navigationTitle("Notifications")
        .listStyle(.insetGrouped)
        .tint(.blue)
        .task {
            await unitCatalog.loadUnits()
        }
        .onDisappear {
            vm.save()
        }
    }

    @ViewBuilder
    private var unitListView: some View {
        if unitCatalog.isLoading {
            ProgressView("Loading apparatus...")
        } else if let errorMessage = unitCatalog.errorMessage {
            Text(errorMessage).foregroundColor(.red)
        } else {
            ForEach(unitCatalog.units) { unit in
                Toggle(unit.name, isOn: unitBinding(unit.id))
            }
        }
    }

    private func unitBinding(_ unitId: String) -> Binding<Bool> {
        Binding(
            get: { vm.preferences.units.contains(unitId) },
            set: { isOn in
                if isOn {
                    vm.preferences.units.insert(unitId)
                } else {
                    vm.preferences.units.remove(unitId)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
    }
}
