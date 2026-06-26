import AVFoundation
import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject private var session: SessionManager

    @StateObject private var vm = NotificationPreferencesViewModel()
    @StateObject private var unitCatalog = UnitCatalog()
    @State private var tonePreviewPlayer: AVAudioPlayer?
    @State private var tonePreviewStopTask: Task<Void, Never>?
    @State private var scheduleLinkStatus = ScheduleLinkStatus.idle

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
            return "Only while scheduled checks your FirstDue schedule before dispatch alerts are sent."
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
                        if canUseScheduleBasedNotifications {
                            scheduleLinkCard
                        }

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
            await refreshScheduleLinkStatus()
        }
        .onChange(of: vm.preferences) { _, _ in
            UserDefaults.standard.set(vm.preferences.hapticsEnabled, forKey: "notification_haptics_enabled")
            vm.scheduleSave()
        }
        .onChange(of: vm.preferences.criticalDispatchAlerts) { _, isEnabled in
            guard isEnabled else { return }

            Task {
                await NotificationManager.shared.requestCriticalAlertPermission()
            }
        }
        .onChange(of: vm.preferences.dispatchAlertTone) { _, tone in
            previewDispatchAlertTone(tone)
            Task {
                await vm.saveImmediately()
            }
        }
        .onChange(of: session.currentUser?.role) { _, _ in
            sanitizeScheduleModesIfNeeded()
            Task {
                await refreshScheduleLinkStatus()
            }
        }
        .onDisappear {
            stopTonePreview()
            sanitizeScheduleModesIfNeeded()
            vm.saveLocal()
            Task {
                await vm.flushPendingSave()
            }
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

    private func refreshScheduleLinkStatus() async {
        guard canUseScheduleBasedNotifications else {
            scheduleLinkStatus = .unavailable("Schedule-based dispatch alerts are not enabled for this role.")
            return
        }

        scheduleLinkStatus = .loading

        do {
            let response = try await APIClient.shared.fetchMobileUpcomingSchedule()

            if response.isWorkingNow {
                scheduleLinkStatus = .workingNow
            } else if let nextShift = response.nextShift {
                scheduleLinkStatus = .nextShift(nextShift)
            } else if response.isScheduleTrackedUser {
                scheduleLinkStatus = .notScheduled
            } else {
                scheduleLinkStatus = .unavailable("FirstDue did not return a schedule match for this member.")
            }
        } catch {
            scheduleLinkStatus = .unavailable(error.localizedDescription)
        }
    }

    private func previewDispatchAlertTone(_ tone: DispatchAlertTone) {
        stopTonePreview()

        guard let soundName = tone.previewSoundName else {
            return
        }

        let resource = (soundName as NSString).deletingPathExtension
        let extensionName = (soundName as NSString).pathExtension

        guard let url = Bundle.main.url(
            forResource: resource,
            withExtension: extensionName.isEmpty ? nil : extensionName
        ) else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            tonePreviewPlayer = player
            tonePreviewStopTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    stopTonePreview()
                }
            }
        } catch {
            tonePreviewPlayer = nil
            tonePreviewStopTask?.cancel()
            tonePreviewStopTask = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func stopTonePreview() {
        tonePreviewStopTask?.cancel()
        tonePreviewStopTask = nil
        tonePreviewPlayer?.stop()
        tonePreviewPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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

    private var scheduleLinkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: scheduleLinkStatus.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(scheduleLinkStatus.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("FirstDue Schedule Link")
                        .font(.subheadline.weight(.semibold))

                    Text(scheduleLinkStatus.title)
                        .font(.caption.weight(.semibold))

                    Text(scheduleLinkStatus.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if scheduleLinkStatus.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            await refreshScheduleLinkStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh FirstDue schedule link")
                }
            }
        }
        .padding(.vertical, 4)
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

private enum ScheduleLinkStatus {
    case idle
    case loading
    case workingNow
    case nextShift(APIClient.MobileUpcomingShift)
    case notScheduled
    case unavailable(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }

    var title: String {
        switch self {
        case .idle:
            return "Schedule status not checked yet"
        case .loading:
            return "Checking FirstDue schedule..."
        case .workingNow:
            return "You are listed as scheduled now"
        case .nextShift:
            return "You are not scheduled right now"
        case .notScheduled:
            return "No upcoming scheduled shift found"
        case .unavailable:
            return "Schedule link unavailable"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Only while scheduled uses FirstDue to decide whether dispatch alerts should be sent."
        case .loading:
            return "The app is checking your current and upcoming schedule."
        case .workingNow:
            return "Only while scheduled will allow matching dispatch alerts while FirstDue shows you working."
        case .nextShift(let shift):
            return nextShiftDetail(shift)
        case .notScheduled:
            return "Only while scheduled will suppress dispatch alerts until FirstDue lists you on the schedule."
        case .unavailable(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "calendar.badge.clock"
        case .loading:
            return "arrow.clockwise"
        case .workingNow:
            return "checkmark.circle.fill"
        case .nextShift:
            return "calendar"
        case .notScheduled:
            return "moon.zzz.fill"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle, .loading, .nextShift:
            return .blue
        case .workingNow:
            return .green
        case .notScheduled:
            return .secondary
        case .unavailable:
            return .orange
        }
    }

    private func nextShiftDetail(_ shift: APIClient.MobileUpcomingShift) -> String {
        let parts = [
            shift.date,
            shift.timeRange,
            shift.station,
            shift.assignment
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return "Only while scheduled will allow matching dispatch alerts during your next FirstDue shift."
        }

        return "Next FirstDue shift: \(parts.joined(separator: " • "))."
    }
}
