import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject private var session: SessionManager

    @StateObject private var vm = NotificationPreferencesViewModel()
    @StateObject private var unitCatalog = UnitCatalog()

    private var canUseScheduleBasedNotifications: Bool {
        let role = session.currentUser?.role
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""

        let isEligibleRole = role == "CHIEF"
            || role == "OFFICER_CAREER"
            || role == "MEMBER_CAREER"

        return isEligibleRole || session.currentUser?.isReliefDriver == true
    }

    private var availableScheduleModes: [NotificationScheduleMode] {
        if canUseScheduleBasedNotifications {
            return NotificationScheduleMode.allCases
        }

        return [.always, .never]
    }

    private var normalAlertScheduleBinding: Binding<NotificationScheduleMode> {
        Binding(
            get: {
                if !canUseScheduleBasedNotifications,
                   vm.preferences.normalAlertScheduleMode == .onlyWhenWorking {
                    return .always
                }

                return vm.preferences.normalAlertScheduleMode
            },
            set: { newValue in
                vm.preferences.normalAlertScheduleMode = sanitizedScheduleMode(newValue)
            }
        )
    }

    private var criticalAlertScheduleBinding: Binding<NotificationScheduleMode> {
        Binding(
            get: {
                if !canUseScheduleBasedNotifications,
                   vm.preferences.criticalAlertScheduleMode == .onlyWhenWorking {
                    return .always
                }

                return vm.preferences.criticalAlertScheduleMode
            },
            set: { newValue in
                vm.preferences.criticalAlertScheduleMode = sanitizedScheduleMode(newValue)
            }
        )
    }

    private var scheduleDescriptionSuffix: String {
        if canUseScheduleBasedNotifications {
            return "Always means whether you are working or not. Only while working means only when you are listed on the department schedule."
        }

        return "Always means dispatch alerts are sent when your other filters match. Off disables this alert type."
    }

    private var allUnitsBinding: Binding<Bool> {
        Binding(
            get: { vm.preferences.allUnits },
            set: { isOn in
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.preferences.allUnits = isOn
                    if isOn {
                        vm.preferences.units.removeAll()
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
    }

    var body: some View {
        Form {
            if vm.isLoading || vm.errorMessage != nil {
                Section {
                    if vm.isLoading {
                        Label("Loading preferences...", systemImage: "arrow.clockwise")
                    } else if let errorMessage = vm.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                settingToggle(
                    title: "Notifications",
                    description: vm.preferences.isEnabled
                        ? "Notifications are enabled for this device."
                        : "All app notifications are currently disabled.",
                    isOn: $vm.preferences.isEnabled
                )
            } header: {
                Text("Master")
            }

            if vm.preferences.isEnabled {
                // MARK: - Dispatch
                Section {
                    Toggle("Dispatch Alerts", isOn: $vm.preferences.dispatchAlertsEnabled)

                    if vm.preferences.dispatchAlertsEnabled {
                        settingPicker(
                            title: "Normal Dispatch Alerts",
                            description: "Choose when routine dispatch notifications are sent. \(scheduleDescriptionSuffix)",
                            selection: normalAlertScheduleBinding,
                            modes: availableScheduleModes
                        )

                        settingPicker(
                            title: "Critical Dispatch Alerts",
                            description: "Choose when serious emergency dispatch notifications are sent. \(scheduleDescriptionSuffix)",
                            selection: criticalAlertScheduleBinding,
                            modes: availableScheduleModes
                        )

                        settingToggle(
                            title: "Critical Alert",
                            description: "Allows serious dispatches to use the emergency alert sound when supported by your iPhone settings.",
                            isOn: $vm.preferences.criticalDispatchAlerts
                        )


                    if vm.preferences.criticalDispatchAlerts {
                        Picker("Critical Dispatch Alert Mode", selection: $vm.preferences.criticalDispatchAlertMode) {
                            ForEach(CriticalDispatchAlertMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(vm.preferences.criticalDispatchAlertMode.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Dispatch Alert Tone", selection: $vm.preferences.dispatchAlertTone) {
                        ForEach(DispatchAlertTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(vm.preferences.dispatchAlertTone.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        settingToggle(
                            title: "Working Fires Only",
                            description: "Only receive fire dispatch alerts for working, structure, building, or confirmed fires.",
                            isOn: $vm.preferences.workingOnly
                        )

                        settingToggle(
                            title: "All Apparatus",
                            description: "Receive alerts for all dispatched apparatus. Turn this off to choose specific units.",
                            isOn: allUnitsBinding
                        )
                    }

                    if vm.preferences.dispatchAlertsEnabled && !vm.preferences.allUnits {
                        unitListView
                    }
                } header: {
                    Text("Dispatch")
                } footer: {
                    Text("Critical alerts may bypass silent mode and Focus. Use only if required for emergency response.")
                }

                // MARK: - Messages
                Section {
                    settingToggle(
                        title: "Department Messages",
                        description: "Receive department-wide announcements and important updates.",
                        isOn: $vm.preferences.departmentMessagesEnabled
                    )

                    settingToggle(
                        title: "Station Messages",
                        description: "Receive messages that apply to your assigned station or company.",
                        isOn: $vm.preferences.stationMessagesEnabled
                    )

                    settingToggle(
                        title: "Message Center",
                        description: "Show messages in the app Message Center and update unread counts.",
                        isOn: $vm.preferences.messageCenterEnabled
                    )
                } header: {
                    Text("Messages")
                }

                // MARK: - Training & Documents
                Section {
                    settingToggle(
                        title: "Training Assignments",
                        description: "Receive alerts for assigned training, due dates, and training updates.",
                        isOn: $vm.preferences.trainingAssignmentsEnabled
                    )

                    settingToggle(
                        title: "Document / SOP Assignments",
                        description: "Receive alerts when documents, SOPs, or acknowledgements are assigned to you.",
                        isOn: $vm.preferences.documentAssignmentsEnabled
                    )
                } header: {
                    Text("Training & Documents")
                }


                // MARK: - Notification Haptics

                hapticsSection

                // MARK: - Quiet Hours
                Section {
                    settingToggle(
                        title: "Quiet Hours",
                        description: "Suppress routine notifications during your selected hours. Critical Alerts may still sound if enabled.",
                        isOn: $vm.preferences.quietHoursEnabled
                    )

                    if vm.preferences.quietHoursEnabled {
                        DatePicker("Start", selection: $vm.preferences.quietStart, displayedComponents: .hourAndMinute)

                        Text("Routine alerts will begin being quieted at this time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        DatePicker("End", selection: $vm.preferences.quietEnd, displayedComponents: .hourAndMinute)

                        Text("Routine alerts will resume after this time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Quiet Hours")
                }

                // MARK: - Behavior
                Section {
                    settingToggle(
                        title: "Respect Focus / Do Not Disturb",
                        description: "Routine notifications follow your iPhone Focus and Do Not Disturb settings.",
                        isOn: $vm.preferences.respectDoNotDisturb
                    )
                } header: {
                    Text("Behavior")
                }
            }
        }
        .navigationTitle("Notifications")
        .listStyle(.insetGrouped)
        .tint(.blue)
        .task {
            await unitCatalog.loadUnits()
            await vm.loadRemote()
            sanitizeScheduleModesIfNeeded()
        }
        .onChange(of: vm.preferences) { _, _ in
            UserDefaults.standard.set(vm.preferences.hapticsEnabled, forKey: "notification_haptics_enabled")
            vm.scheduleSave()
        }
        .onChange(of: session.currentUser?.role) { _, _ in
            sanitizeScheduleModesIfNeeded()
        }
        .onDisappear {
            sanitizeScheduleModesIfNeeded()
            vm.cancelPendingSave()
            vm.saveLocal()
        }
    }

    private func sanitizedScheduleMode(_ mode: NotificationScheduleMode) -> NotificationScheduleMode {
        if !canUseScheduleBasedNotifications && mode == .onlyWhenWorking {
            return .always
        }

        return mode
    }

    private func sanitizeScheduleModesIfNeeded() {
        guard !canUseScheduleBasedNotifications else {
            return
        }

        if vm.preferences.normalAlertScheduleMode == .onlyWhenWorking {
            vm.preferences.normalAlertScheduleMode = .always
        }

        if vm.preferences.criticalAlertScheduleMode == .onlyWhenWorking {
            vm.preferences.criticalAlertScheduleMode = .always
        }
    }

    private var hapticsSection: some View {
        Section {
            settingToggle(
                title: "Notification Haptics",
                description: "Use vibration feedback for in-app dispatch and notification alerts when supported by iOS.",
                isOn: $vm.preferences.hapticsEnabled
            )
        } header: {
            Text("Haptics")
        }
    }

    private func settingToggle(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func settingPicker(
        title: String,
        description: String,
        selection: Binding<NotificationScheduleMode>,
        modes: [NotificationScheduleMode]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(title, selection: selection) {
                ForEach(modes) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Current selection: \(selection.wrappedValue.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(selection.wrappedValue.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical, 4)
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
