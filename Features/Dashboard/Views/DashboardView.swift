import SwiftUI
import UIKit
import Combine
import MapKit

struct DashboardView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var unitCatalog = UnitCatalog()
    @StateObject private var router = NavigationRouter.shared
    @StateObject private var scheduleViewModel = ScheduleViewModel()

    @State private var dispatchNotificationCount = 0
    @State private var isDispatchBellRinging = false
    @State private var showContent = true
    @State private var hasLoadedDispatchUnits = false
    @State private var showMessageModal = false
    @State private var showMessageCenter = false
    @State private var showApparatusWorkOrders = false
    @State private var messageCenterMode: MessageCenterView.Mode = .combined
    @State private var dashboardLayoutRefreshID = UUID()
    @State private var showDashboardLayoutEditor = false
    @State private var selectedDispatch: DispatchNotificationPayload?

    @State private var latestDispatch: DispatchNotificationPayload?
    @State private var showNewDispatchBanner = false
    @State private var highlightedDispatchId: String?

    @AppStorage("dashboardTotalsWindow") private var selectedWindowRawValue = DashboardTotalsWindow.ytd.rawValue
    @State private var selectedChiefScheduleDayId: String?

    private var dashboardRole: DashboardRole {
        DashboardRole.from(session.currentUser?.role)
    }


    private var primaryActiveDispatch: APIClient.ActiveDispatch? {
        viewModel.activeDispatches.first
    }

    private var secondaryActiveDispatches: [APIClient.ActiveDispatch] {
        Array(viewModel.activeDispatches.dropFirst())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.18, blue: 0.38),
                        Color(red: 0.03, green: 0.10, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    DashboardHeaderView(
                        firstName: firstName,
                        roleTitle: memberRoleDisplayName(from: session.currentUser?.role),
                        stationTitle: stationDisplayName,
                        alertMode: headerAlertMode,
                        isBellRinging: isDispatchBellRinging,
                        onTapAlert: handleHeaderAlertTap
                    )

                    ScrollView(showsIndicators: false) {

                        switch dashboardRole {

                        case .admin:
                            AdminDashboardView()

                        case .chief:
                            ChiefDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                departmentStats: viewModel.state.dashboardDepartment,
                                recentCalls: viewModel.state.recentDepartmentCalls,
                                outlookDays: scheduleViewModel.outlookDays,
                                isLoading: viewModel.state.isLoading || viewModel.state.isLoadingStats || scheduleViewModel.isLoading
                            ) {
                                showApparatusWorkOrders = true
                            } onOpenMessages: {
                                openMessageCenter(mode: .messagesOnly)
                            } onOpenDispatch: { dispatch in
                                latestDispatch = dispatch
                                highlightedDispatchId = dispatch.id

                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedDispatch = dispatch
                                }
                            } onOpenPastDispatches: {
                                openMessageCenter(mode: .dispatchesOnly)
                            }

                        case .officerCareer:
                            CareerOfficerDashboardView()

                        case .officerVolunteer:
                            VolunteerOfficerDashboardView()

                        case .memberCareer:
                            CareerMemberDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                departmentStats: viewModel.state.dashboardDepartment,
                                stationStats: viewModel.state.dashboardStation,
                                upcomingSchedule: viewModel.state.upcomingSchedule,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                recentCalls: viewModel.state.recentDepartmentCalls,
                                assignedTraining: viewModel.state.assignedTrainingPreview,
                                pendingDocuments: viewModel.state.pendingDocumentSignatures,
                                isLoading: viewModel.state.isLoading || viewModel.state.isLoadingStats,
                                onOpenDispatch: { dispatch in
                                    latestDispatch = dispatch
                                    highlightedDispatchId = dispatch.id

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        selectedDispatch = dispatch
                                    }
                                },
                                onOpenMessages: {
                                    openMessageCenter(mode: .messagesOnly)
                                },
                                onOpenWorkOrders: {
                                    showApparatusWorkOrders = true
                                },
                                onOpenSchedule: {
                                    router.selectedTab = .schedule
                                },
                                onOpenTraining: {
                                    handleNavigation(to: .trainingAssigned)
                                },
                                onOpenDocuments: {
                                    handleNavigation(to: .documents)
                                },
                                onOpenPastDispatches: {
                                    openMessageCenter(mode: .dispatchesOnly)
                                }
                            )

                        case .memberVolunteer:
                            VolunteerMemberDashboardView()
                        }

                        /*
                            if let primaryActiveDispatch {
                                sectionTitle("Current Dispatch")

                                DashboardDispatchPreviewCard(
                                    dispatch: makeDispatchPayload(from: primaryActiveDispatch),
                                    isHighlighted: highlightedDispatchId == primaryActiveDispatch.id
                                ) {
                                    let dispatch = makeDispatchPayload(from: primaryActiveDispatch)

                                    latestDispatch = dispatch
                                    highlightedDispatchId = dispatch.id

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        selectedDispatch = dispatch
                                    }
                                }
                            }

                            if !secondaryActiveDispatches.isEmpty {
                                ActiveDispatchStackView(dispatches: secondaryActiveDispatches) { activeDispatch in
                                    let dispatch = makeDispatchPayload(from: activeDispatch)

                                    latestDispatch = dispatch
                                    highlightedDispatchId = dispatch.id

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        selectedDispatch = dispatch
                                    }
                                }
                            }

                            if isChiefRole {
                                chiefCallSummarySection
                                chiefScheduleOutlookSection
                            } else {
                                DashboardCallSummarySection(
                                    selectedWindowRawValue: $selectedWindowRawValue,
                                    department: viewModel.state.dashboardDepartment,
                                    station: viewModel.state.dashboardStation,
                                    isLoading: viewModel.state.isLoading || viewModel.state.isLoadingStats
                                )
                            }

                            dashboardEditHeader

                            ForEach(visibleDashboardCards, id: \.rawValue) { card in
                                dashboardCard(card)
                                    .transaction { transaction in
                                        transaction.animation = nil
                                    }
                            }

                            if let errorMessage = viewModel.state.errorMessage,
                               !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                        .opacity(1)

                        */
                    }
                    .refreshable {
                        await refreshDashboardContent()
                    }

                }

                if showNewDispatchBanner, let latestDispatch {
                    NewDispatchBanner(dispatch: latestDispatch) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            selectedDispatch = latestDispatch
                            showNewDispatchBanner = false
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                showContent = true
                viewModel.loadIfNeeded(role: mappedUserRole(from: session.currentUser?.role))
                scheduleLiveActivitySync()

                if (dashboardRole == .chief || dashboardRole == .admin) && scheduleViewModel.outlookDays.isEmpty {
                    Task {
                        await scheduleViewModel.loadOutlookDays(count: 4)

                        if selectedChiefScheduleDayId == nil {
                            selectedChiefScheduleDayId = scheduleViewModel.outlookDays.first?.id
                        }

                        print("🗓️ Chief dashboard schedule outlook days:", scheduleViewModel.outlookDays.count)
                        print("🗓️ Chief dashboard schedule error:", scheduleViewModel.errorMessage ?? "none")
                    }
                }

                if !hasLoadedDispatchUnits {
                    hasLoadedDispatchUnits = true

                    DispatchService.fetchUnits { units in
                        DispatchQueue.main.async {
                            unitCatalog.ingest(units: units)
                        }
                    }
                }

                if hasNewMessage {
                    showMessageModal = true
                }
            }
            .onChange(of: activeDispatchLiveActivitySignature) { _, _ in
                syncLiveActivityWithDashboardActiveDispatches()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                viewModel.refreshIfStale(role: mappedUserRole(from: session.currentUser?.role))
                scheduleLiveActivitySync()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveDispatchNotification)) { notification in
                guard let dispatch = notification.object as? DispatchNotificationPayload else {
                    print("⚠️ Received dispatch notification, but payload was not DispatchNotificationPayload.")
                    return
                }

                print("🔔 Dispatch RECEIVED:", dispatch.id)

                latestDispatch = dispatch
                viewModel.addActiveDispatch(from: dispatch)

                if dashboardHapticsEnabled {
                    let hapticGenerator = UINotificationFeedbackGenerator()
                    hapticGenerator.prepare()
                    hapticGenerator.notificationOccurred(dispatch.type == .dispatchCritical ? .warning : .success)
                }

                highlightedDispatchId = dispatch.id
                dispatchNotificationCount += 1

                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    showNewDispatchBanner = true
                    isDispatchBellRinging = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isDispatchBellRinging = false
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showNewDispatchBanner = false
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    highlightedDispatchId = nil
                }
            }
            .onReceive(router.$dispatchToOpen.compactMap { $0 }) { dispatch in
                print("🧭 Dashboard opening dispatch:", dispatch.id)

                latestDispatch = dispatch
                viewModel.addActiveDispatch(from: dispatch)

                highlightedDispatchId = dispatch.id

                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedDispatch = dispatch
                }

                router.dispatchToOpen = nil
            }
            .sheet(isPresented: $showMessageModal) {
                Text("New Message")
                    .font(.title)
                    .padding()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedDispatch != nil },
                    set: { if !$0 { selectedDispatch = nil } }
                )
            ) {
                if let selectedDispatch {
                    DispatchDetailView(dispatch: selectedDispatch)
                }
            }
            .navigationDestination(isPresented: $showMessageCenter) {
                MessageCenterView(mode: messageCenterMode)
            }
            .navigationDestination(isPresented: $showApparatusWorkOrders) {
                ApparatusWorkOrdersView(
                    workOrders: viewModel.state.apparatusWorkOrders
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .dashboardLayoutDidChange)) { _ in
                dashboardLayoutRefreshID = UUID()
            }
            .sheet(isPresented: $showDashboardLayoutEditor) {
                NavigationStack {
                    DashboardLayoutView()
                }
            }
        }
    }


    @MainActor
    private func refreshDashboardContent() async {
        viewModel.refresh(role: mappedUserRole(from: session.currentUser?.role))

        switch dashboardRole {
        case .admin, .chief:
            await scheduleViewModel.loadOutlookDays(count: 4)
            if selectedChiefScheduleDayId == nil {
                selectedChiefScheduleDayId = scheduleViewModel.outlookDays.first?.id
            }
        default:
            break
        }
    }

    private var firstName: String {
        let role = session.currentUser?.role.uppercased() ?? ""

        if role == "CHIEF" {
            return "Chief"
        }

        let fullName = session.currentUser?.name ?? ""

        if fullName.isEmpty {
            return "Member"
        }

        return fullName.components(separatedBy: " ").first ?? "Member"
    }

    private var stationDisplayName: String {
        StationMapper.displayName(from: session.currentUser?.company)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var hasNewMessage: Bool {
        false
    }

    private var headerAlertMode: DashboardHeaderAlertMode {
        if !viewModel.activeDispatches.isEmpty {
            return .activeDispatch(messageCount: viewModel.state.unreadNonDispatchMessageCount)
        }

        if viewModel.state.unreadNonDispatchMessageCount > 0 {
            return .unreadMessages(count: viewModel.state.unreadNonDispatchMessageCount)
        }

        return .latestDispatches
    }

    private func handleHeaderAlertTap() {
        isDispatchBellRinging = false

        if let activeDispatch = viewModel.activeDispatches.first {
            let dispatch = makeDispatchPayload(from: activeDispatch)
            latestDispatch = dispatch
            highlightedDispatchId = dispatch.id

            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedDispatch = dispatch
            }
            return
        }

        if viewModel.state.unreadNonDispatchMessageCount > 0 {
            openMessageCenter(mode: .messagesOnly)
        } else {
            openMessageCenter(mode: .dispatchesOnly)
        }
    }

    private var isCommandRole: Bool {
        let role = session.currentUser?.role.uppercased() ?? ""
        return role == "ADMIN" ||
            role == "CHIEF" ||
            role == "OFFICER_CAREER" ||
            role == "OFFICER_VOLUNTEER"
    }

    private var isChiefRole: Bool {
        let role = session.currentUser?.role.uppercased() ?? ""
        return role == "ADMIN" || role == "CHIEF"
    }

    private var chiefScheduleOutlookSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Schedule Outlook")

                Spacer()

                HStack(spacing: 6) {
                    ForEach(scheduleViewModel.outlookDays) { day in
                        Button {
                            selectedChiefScheduleDayId = day.id
                        } label: {
                            let isSelected = selectedChiefScheduleDayId == day.id || (selectedChiefScheduleDayId == nil && day.id == scheduleViewModel.outlookDays.first?.id)

                            Text(day.label)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                                .frame(minWidth: isSelected ? 66 : 46, minHeight: 34)
                                .padding(.horizontal, isSelected ? 10 : 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let entries = chiefScheduleEntriesForSelectedWindow
            let displayEntries = entries.filter { entry in
                entry.staffingDetails.contains { !$0.isVacant }
            }
            let totalVacancies = entries.reduce(0) { total, entry in
                total + entry.staffingDetails.filter { $0.isVacant }.count
            }

            VStack(alignment: .leading, spacing: 10) {
                if displayEntries.isEmpty {
                    Text("\(DashboardEmoji.schedule) No staffing returned for \(selectedChiefScheduleDay?.label ?? "this day").")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("If staffing is posted in FirstDue, it will appear here. Full details remain available in Schedule.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                } else {
                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(displayEntries) { entry in
                                chiefScheduleEntryRow(entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)

                    Text("Full staffing details available in Schedule.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.52))
                }

                if totalVacancies > 0 {
                    Text("\(DashboardEmoji.warning) \(totalVacancies) vacanc\(totalVacancies == 1 ? "y" : "ies"). View full Schedule for open positions.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
    }

    private var selectedChiefScheduleDay: ScheduleOutlookDay? {
        if let selectedChiefScheduleDayId,
           let selectedDay = scheduleViewModel.outlookDays.first(where: { $0.id == selectedChiefScheduleDayId }) {
            return selectedDay
        }

        return scheduleViewModel.outlookDays.first
    }

    private var chiefScheduleEntriesForSelectedWindow: [APIClient.MobileScheduleEntry] {
        selectedChiefScheduleDay?.entries ?? []
    }

    private func horizontalDashboardSwipeGesture(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else {
                    return
                }

                if horizontal < 0 {
                    onNext()
                } else {
                    onPrevious()
                }
            }
    }

    private func selectNextChiefScheduleDay() {
        let days = scheduleViewModel.outlookDays
        guard !days.isEmpty else { return }

        let currentId = selectedChiefScheduleDay?.id ?? days.first?.id
        let currentIndex = days.firstIndex { $0.id == currentId } ?? 0
        let nextIndex = min(currentIndex + 1, days.count - 1)

        selectedChiefScheduleDayId = days[nextIndex].id
    }

    private func selectPreviousChiefScheduleDay() {
        let days = scheduleViewModel.outlookDays
        guard !days.isEmpty else { return }

        let currentId = selectedChiefScheduleDay?.id ?? days.first?.id
        let currentIndex = days.firstIndex { $0.id == currentId } ?? 0
        let previousIndex = max(currentIndex - 1, 0)

        selectedChiefScheduleDayId = days[previousIndex].id
    }

    private func chiefScheduleEntryRow(_ entry: APIClient.MobileScheduleEntry) -> some View {
        let filledNames = entry.staffingDetails
            .filter { !$0.isVacant }
            .compactMap { detail -> String? in
                let name = detail.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { return nil }

                let qualifier = detail.qualifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return qualifier.isEmpty ? name : "\(name) (\(qualifier))"
            }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let station = entry.station, !station.isEmpty {
                    Text(station)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(entry.timeRange)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }

            Text(filledNames.joined(separator: " • "))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }


    private enum ChiefCallTotalKind {
        case department
        case fire
        case ems
    }

    private var selectedChiefTotalsWindow: DashboardTotalsWindow {
        DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd
    }

    private var chiefCallSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Call Totals")

                Spacer()

                HStack(spacing: 6) {
                    ForEach(DashboardTotalsWindow.allCases, id: \.rawValue) { window in
                        Button {
                            selectedWindowRawValue = window.rawValue
                        } label: {
                            Text(window.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(selectedChiefTotalsWindow == window ? AppTheme.navy : .white.opacity(0.72))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedChiefTotalsWindow == window ? AppTheme.gold : Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(alignment: .center, spacing: 0) {
                chiefInlineTotal(
                    value: chiefCallTotalValue(.department),
                    label: "Department"
                )

                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.18))

                chiefInlineTotal(
                    value: chiefCallTotalValue(.fire),
                    label: "🔥 Fire"
                )

                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.18))

                chiefInlineTotal(
                    value: chiefCallTotalValue(.ems),
                    label: "🚑 EMS"
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
    }

    private func selectNextChiefTotalsWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedChiefTotalsWindow) else { return }

        let nextIndex = min(currentIndex + 1, windows.count - 1)

        selectedWindowRawValue = windows[nextIndex].rawValue
    }

    private func selectPreviousChiefTotalsWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedChiefTotalsWindow) else { return }

        let previousIndex = max(currentIndex - 1, 0)

        selectedWindowRawValue = windows[previousIndex].rawValue
    }

    private func chiefInlineTotal(value: Int, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func chiefCallTotalValue(_ kind: ChiefCallTotalKind) -> Int {
        let department = viewModel.state.dashboardDepartment

        switch (selectedChiefTotalsWindow, kind) {
        case (.last24h, .department):
            return department?.total24h ?? 0
        case (.last24h, .fire):
            return department?.fire24h ?? 0
        case (.last24h, .ems):
            return department?.ems24h ?? 0

        case (.last7d, .department):
            return department?.total7d ?? 0
        case (.last7d, .fire):
            return department?.fire7d ?? 0
        case (.last7d, .ems):
            return department?.ems7d ?? 0

        case (.last30d, .department):
            return department?.total30d ?? 0
        case (.last30d, .fire):
            return department?.fire30d ?? 0
        case (.last30d, .ems):
            return department?.ems30d ?? 0

        case (.ytd, .department):
            return department?.totalYtd ?? 0
        case (.ytd, .fire):
            return department?.fireYtd ?? 0
        case (.ytd, .ems):
            return department?.emsYtd ?? 0
        }
    }

    private var activeDispatchLiveActivitySignature: String {
        viewModel.activeDispatches
            .map { dispatch in
                let priority = dispatch.priority ?? ""
                let callType = dispatch.callType
                let address = dispatch.address ?? ""
                let message = dispatch.message ?? ""
                let isWorkingFire = dispatch.isWorkingFire ?? false

                return "\(dispatch.id)|\(priority)|\(callType)|\(address)|\(message)|\(isWorkingFire)"
            }
            .joined(separator: "||")
    }

    private func syncLiveActivityWithDashboardActiveDispatches() {
        print("🟣 Dashboard LiveActivity sync. activeDispatches:", viewModel.activeDispatches.count)

        guard let newestDispatch = viewModel.activeDispatches.first else {
            print("🟣 Dashboard LiveActivity no active dispatches. Ending all.")
            DispatchLiveActivityManager.shared.endAll()
            return
        }

        let payload = makeDispatchPayload(
            from: newestDispatch,
            activeCallCount: viewModel.activeDispatches.count
        )
        print("🟣 Dashboard LiveActivity newest dispatch:", payload.id, payload.title)

        DispatchLiveActivityManager.shared.startOrUpdate(from: payload)
    }

    private func scheduleLiveActivitySync() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            syncLiveActivityWithDashboardActiveDispatches()
        }
    }

    private var visibleDashboardCards: [DashboardCardID] {
        _ = dashboardLayoutRefreshID

        let hiddenCards = DashboardCardLayoutDefaults.hiddenCards()
        let enabledCards = DashboardCardLayoutDefaults
            .savedOrder(for: session.currentUser?.role)
            .filter { !hiddenCards.contains($0) }

        return enabledCards.sorted { lhs, rhs in
            let lhsPriority = dashboardCardPriority(lhs)
            let rhsPriority = dashboardCardPriority(rhs)

            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }

            let lhsIndex = enabledCards.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = enabledCards.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private func dashboardCardPriority(_ card: DashboardCardID) -> Int {
        switch card {
        case .recentCalls:
            return viewModel.activeDispatches.isEmpty ? 0 : 100

        case .needsAttention:
            return viewModel.state.attentionItems.isEmpty ? 0 : 95

        case .messages:
            return viewModel.state.unreadNonDispatchMessageCount > 0 ? 90 : 10

        case .apparatusWorkOrders:
            return viewModel.state.apparatusWorkOrders.isEmpty ? 0 : 85

        case .scheduleEvents:
            if viewModel.state.upcomingSchedule?.isWorkingNow == true {
                return 80
            }

            if viewModel.state.upcomingSchedule?.nextShift != nil {
                return 35
            }

            return 0

        case .assignedTraining:
            return viewModel.state.assignedTrainingPreview.isEmpty ? 0 : 75

        case .documents:
            return viewModel.state.pendingDocumentSignatures > 0 ? 70 : 0

        case .departmentUpdates:
            return viewModel.state.departmentUpdates.isEmpty ? 0 : 55

        case .stationUpdates:
            return viewModel.state.stationUpdates.isEmpty ? 0 : 50

        case .commandOverview:
            let role = session.currentUser?.role.uppercased() ?? ""
            return role == "ADMIN" || role == "CHIEF" || role.contains("OFFICER") ? 40 : 0
        }
    }

    private func dashboardCardHasData(_ card: DashboardCardID) -> Bool {
        switch card {
        case .commandOverview:
            return false

        case .messages:
            return true
        case .assignedTraining:
            return !viewModel.state.assignedTrainingPreview.isEmpty
        case .departmentUpdates:
            return !viewModel.state.departmentUpdates.isEmpty
        case .stationUpdates:
            return !viewModel.state.stationUpdates.isEmpty
        case .needsAttention:
            return !viewModel.state.attentionItems.isEmpty
        case .documents:
            return viewModel.state.pendingDocumentSignatures > 0
        case .recentCalls:
            return !viewModel.state.recentDepartmentCalls.isEmpty
        case .apparatusWorkOrders:
            return !viewModel.state.apparatusWorkOrders.isEmpty
        case .scheduleEvents:
            return true
        }
    }

    @ViewBuilder
    private func dashboardCard(_ card: DashboardCardID) -> some View {
        switch card {
        case .commandOverview:
            sectionTitle(isChiefRole ? "Chief Command" : "Officer Command")

            DashboardSmallStatusCard(
                title: isChiefRole ? "Command Overview" : "Officer Overview",
                subtitle: isChiefRole
                    ? "Department staffing, command messages, training compliance, and operational readiness."
                    : "Station staffing, assigned members, training progress, and apparatus readiness.",
                systemImage: "shield.lefthalf.filled"
            ) {
                router.selectedTab = .command
            }

        case .messages:
            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Messages",
                    subtitle: "Loading messages...",
                    systemImage: "envelope.fill"
                )
            } else {
                DashboardMessageCenterCard {
                    dispatchNotificationCount = 0
                    isDispatchBellRinging = false
                    openMessageCenter(mode: .messagesOnly)
                }
            }

        case .assignedTraining:
            sectionTitle("Assigned Training")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Assigned Training",
                    subtitle: "Loading assignments...",
                    systemImage: "graduationcap.fill"
                )
            } else if viewModel.state.assignedTrainingPreview.isEmpty {
                DashboardSmallStatusCard(
                    title: "Assigned Training",
                    subtitle: "No assigned training right now.",
                    systemImage: "graduationcap.fill",
                ) {
                    handleNavigation(to: .trainingAssigned)
                }
            } else {
                DashboardAssignedTrainingPreviewCard(
                    items: viewModel.state.assignedTrainingPreview
                ) {
                    handleNavigation(to: .trainingAssigned)
                }
            }

        case .departmentUpdates:
            sectionTitle("Dept. Update")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Department Updates",
                    subtitle: "Loading updates...",
                    systemImage: "megaphone.fill"
                )
            } else if viewModel.state.departmentUpdates.isEmpty {
                DashboardSmallStatusCard(
                    title: "Department Updates",
                    subtitle: "No department updates posted.",
                    systemImage: "megaphone.fill",
                ) {
                    handleNavigation(to: .messageCenter)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.state.departmentUpdates) { update in
                        DashboardUpdateBlock(update: update)
                    }
                }
            }

        case .stationUpdates:
            sectionTitle("Station Update")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Station Updates",
                    subtitle: "Loading station updates...",
                    systemImage: "building.2.fill"
                )
            } else if viewModel.state.stationUpdates.isEmpty {
                DashboardSmallStatusCard(
                    title: "Station Updates",
                    subtitle: "No station updates posted.",
                    systemImage: "building.2.fill",
                ) {
                    handleNavigation(to: .messageCenter)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.state.stationUpdates) { update in
                        DashboardUpdateBlock(update: update)
                    }
                }
            }

        case .needsAttention:
            sectionTitle("Needs Attention")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Needs Attention",
                    subtitle: "Checking items...",
                    systemImage: "checkmark.seal.fill"
                )
            } else if viewModel.state.attentionItems.isEmpty {
                DashboardSmallStatusCard(
                    title: "Needs Attention",
                    subtitle: "Nothing needs your attention right now.",
                    systemImage: "checkmark.seal.fill",
                ) {
                    handleNavigation(to: .messageCenter)
                }
            } else {
                ForEach(viewModel.state.attentionItems) { item in
                    DashboardAttentionCard(item: item) {
                        handleNavigation(to: item.destination)
                    }
                }
            }

        case .documents:
            sectionTitle("Documents / SOPs")

            let pendingCount = viewModel.state.pendingDocumentSignatures

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Documents / SOPs",
                    subtitle: "Checking documents...",
                    systemImage: "doc.text.fill"
                )
            } else {
                DashboardSmallStatusCard(
                    title: "Documents / SOPs",
                    subtitle: pendingCount > 0
                        ? "\(pendingCount) item\(pendingCount == 1 ? "" : "s") need acknowledgement."
                        : "No documents need acknowledgement.",
                    systemImage: "doc.text.fill"
                ) {
                    handleNavigation(to: .documents)
                }
            }

        case .apparatusWorkOrders:
            sectionTitle("Apparatus Work Orders")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Apparatus Work Orders",
                    subtitle: "Loading apparatus issues...",
                    systemImage: "wrench.and.screwdriver.fill"
                )
            } else if viewModel.state.apparatusWorkOrders.isEmpty {
                DashboardSmallStatusCard(
                    title: "Apparatus Work Orders",
                    subtitle: viewModel.state.apparatusWorkOrdersMessage ?? "No open apparatus work orders.",
                    systemImage: "wrench.and.screwdriver.fill",
                ) {
                    handleNavigation(to: .messageCenter)
                }
            } else {
                DashboardApparatusWorkOrdersCard(
                    workOrders: viewModel.state.apparatusWorkOrders
                ) {
                    showApparatusWorkOrders = true
                }
            }

        case .scheduleEvents:
            sectionTitle(viewModel.state.upcomingSchedule?.isWorkingNow == true ? "Working Now" : "Next Shift")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Schedule",
                    subtitle: "Loading schedule...",
                    systemImage: "calendar.badge.clock"
                )
            } else if let upcomingSchedule = viewModel.state.upcomingSchedule,
                      upcomingSchedule.isWorkingNow == true,
                      upcomingSchedule.nextShift == nil {
                DashboardSmallStatusCard(
                    title: "Working Now",
                    subtitle: "You are currently scheduled as working.",
                    systemImage: "calendar.badge.clock"
                ) {
                    router.selectedTab = .schedule
                }
            } else if let upcomingSchedule = viewModel.state.upcomingSchedule,
                      let nextShift = upcomingSchedule.nextShift {
                DashboardUpcomingScheduleCard(
                    schedule: upcomingSchedule,
                    shift: nextShift
                ) {
                    router.selectedTab = .schedule
                }
            } else {
                DashboardSmallStatusCard(
                    title: "Schedule",
                    subtitle: viewModel.state.upcomingSchedule?.error
                        ?? "Schedule status unavailable or no upcoming shift found.",
                    systemImage: "calendar.badge.clock",
                ) {
                    router.selectedTab = .schedule
                }
            }

        case .recentCalls:
            sectionTitle("Latest Dispatches")

            if viewModel.state.isLoading {
                DashboardLoadingCard(
                    title: "Latest Dispatches",
                    subtitle: "Loading dispatch history...",
                    systemImage: "clock.arrow.circlepath"
                )
            } else if viewModel.state.recentDepartmentCalls.isEmpty {
                DashboardSmallStatusCard(
                    title: "Latest Dispatches",
                    subtitle: "No recent dispatches available.",
                    systemImage: "clock.arrow.circlepath",
                ) {
                    openMessageCenter(mode: .dispatchesOnly)
                }
            } else {
                DashboardRecentCallsCard(
                    calls: viewModel.state.recentDepartmentCalls
                ) {
                    openMessageCenter(mode: .dispatchesOnly)
                }
            }
        }
    }

    private var dashboardEditHeader: some View {
        HStack {
            Text("Your Dashboard")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                showDashboardLayoutEditor = true
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.top, 4)
    }

    private func mappedUserRole(from rawRole: String?) -> UserRole {
        guard let rawRole = rawRole?.uppercased() else {
            return .member
        }

        if rawRole == "ADMIN" || rawRole == "CHIEF" {
            return .chief
        } else if rawRole.contains("OFFICER") {
            return .officer
        } else {
            return .member
        }
    }

    private var dashboardHapticsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "notification_haptics_enabled") == nil {
            return true
        }

        return UserDefaults.standard.bool(forKey: "notification_haptics_enabled")
    }

    private func makeDispatchPayload(
        from activeDispatch: APIClient.ActiveDispatch,
        activeCallCount: Int = 1
    ) -> DispatchNotificationPayload {
        let baseBody = activeDispatch.address ?? activeDispatch.message ?? "Dispatch details available"

        let liveActivityBody = activeCallCount > 1
            ? "\(baseBody) • \(activeCallCount) active calls"
            : baseBody

        return DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: liveActivityBody,
            callType: activeDispatch.callType,
            address: activeDispatch.address,
            units: activeDispatch.units,
            isWorkingFire: activeDispatch.isWorkingFire ?? false,
            activeCallCount: activeCallCount,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }

    private func memberRoleDisplayName(from rawRole: String?) -> String {
        guard let rawRole = rawRole?.uppercased() else {
            return "Member"
        }

        switch rawRole {
        case "ADMIN":
            return "Administrator"
        case "CHIEF":
            return "Chief"
        case "OFFICER_CAREER":
            return "Career Officer"
        case "OFFICER_VOLUNTEER":
            return "Volunteer Officer"
        case "MEMBER_CAREER":
            return "Career Member"
        case "MEMBER_VOLUNTEER":
            return "Volunteer Member"
        default:
            return "Member"
        }
    }

    private func openMessageCenter(mode: MessageCenterView.Mode) {
        messageCenterMode = mode
        showMessageCenter = true
    }

    private func handleNavigation(to destination: AppDestination) {
        switch destination {
        case .trainingAssigned:
            router.selectedTab = .training

        case .messageCenter:
            openMessageCenter(mode: .messagesOnly)

        case .documents:
            router.selectedTab = .documents

        default:
            print("Navigate to: \(destination)")
        }
    }

    private struct DashboardUpdateBlock: View {
        let update: DashboardBulletin

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(update.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(update.message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.82))

                if let updatedAt = update.updatedAt, !updatedAt.isEmpty {
                    Text(updatedAt)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }
}

struct DashboardApparatusWorkOrdersCard: View {
    let workOrders: [DashboardApparatusWorkOrder]
    let onTap: () -> Void

    @State private var selectedApparatusName: String?

    private var groupedWorkOrders: [(apparatusName: String, workOrders: [DashboardApparatusWorkOrder])] {
        let grouped = Dictionary(grouping: workOrders) { workOrder in
            workOrder.apparatusName
        }

        return grouped
            .map { apparatusName, orders in
                (
                    apparatusName: apparatusName,
                    workOrders: orders
                )
            }
            .sorted { lhs, rhs in
                lhs.apparatusName.localizedStandardCompare(rhs.apparatusName) == .orderedAscending
            }
    }

    private var selectedGroup: (apparatusName: String, workOrders: [DashboardApparatusWorkOrder])? {
        if let selectedApparatusName,
           let group = groupedWorkOrders.first(where: { $0.apparatusName == selectedApparatusName }) {
            return group
        }

        return groupedWorkOrders.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DashboardColorIcon(systemImage: "wrench.and.screwdriver.fill")

                Text("Open apparatus issues")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Text("View")
                            .font(.caption.bold())

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
            }

            if groupedWorkOrders.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groupedWorkOrders.prefix(6), id: \.apparatusName) { group in
                            let isSelected = selectedGroup?.apparatusName == group.apparatusName

                            Button {
                                selectedApparatusName = group.apparatusName
                            } label: {
                                Text(shortApparatusLabel(group.apparatusName))
                                    .font(.caption.bold())
                                    .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                                    .frame(minWidth: 44, minHeight: 32)
                                    .padding(.horizontal, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if groupedWorkOrders.count > 6 {
                            Text("+\(groupedWorkOrders.count - 6)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.58))
                                .frame(minHeight: 32)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(apparatusFilterSwipeGesture)
            }

            if let selectedGroup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedGroup.apparatusName)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.gold)
                            .lineLimit(1)

                        Spacer()

                        Text("\(selectedGroup.workOrders.count) open")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 10) {
                            ForEach(selectedGroup.workOrders) { workOrder in
                                VStack(alignment: .leading, spacing: 5) {
                                    if let status = workOrder.status, !status.isEmpty {
                                        Text(status)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .lineLimit(1)
                                    }

                                    Text(workOrder.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 172)

                    if selectedGroup.workOrders.count > 3 {
                        Button(action: onTap) {
                            Text("View all \(selectedGroup.workOrders.count) work orders")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.gold)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No open apparatus work orders.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear {
            if selectedApparatusName == nil {
                selectedApparatusName = groupedWorkOrders.first?.apparatusName
            }
        }
        .onChange(of: workOrders) { _, _ in
            if let selectedApparatusName,
               groupedWorkOrders.contains(where: { $0.apparatusName == selectedApparatusName }) {
                return
            }

            selectedApparatusName = groupedWorkOrders.first?.apparatusName
        }
    }

    private var apparatusFilterSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else {
                    return
                }

                if horizontal < 0 {
                    selectNextApparatus()
                } else {
                    selectPreviousApparatus()
                }
            }
    }

    private func selectNextApparatus() {
        let groups = groupedWorkOrders
        guard !groups.isEmpty else { return }

        let currentName = selectedGroup?.apparatusName ?? groups.first?.apparatusName
        let currentIndex = groups.firstIndex { $0.apparatusName == currentName } ?? 0
        let nextIndex = min(currentIndex + 1, groups.count - 1)

        selectedApparatusName = groups[nextIndex].apparatusName
    }

    private func selectPreviousApparatus() {
        let groups = groupedWorkOrders
        guard !groups.isEmpty else { return }

        let currentName = selectedGroup?.apparatusName ?? groups.first?.apparatusName
        let currentIndex = groups.firstIndex { $0.apparatusName == currentName } ?? 0
        let previousIndex = max(currentIndex - 1, 0)

        selectedApparatusName = groups[previousIndex].apparatusName
    }

    private func shortApparatusLabel(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)

        if trimmed.localizedCaseInsensitiveContains("engine") {
            return digits.isEmpty ? "ENG" : "E\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("ladder") {
            return digits.isEmpty ? "LAD" : "L\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("truck") {
            return digits.isEmpty ? "TRK" : "T\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("rescue") {
            return digits.isEmpty ? "RES" : "R\(digits)"
        }

        return String(trimmed.prefix(4)).uppercased()
    }
}


struct DashboardRecentCallsCard: View {
    let calls: [RecentDepartmentCall]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    DashboardColorIcon(systemImage: "clock.arrow.circlepath")

                    Text("Latest dispatches")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("View")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold.opacity(0.9))
                }

                VStack(spacing: 10) {
                    ForEach(calls.prefix(3)) { call in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(call.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Spacer()

                                Text(call.timestamp)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.52))
                                    .lineLimit(1)
                            }

                            Text(call.address)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .lineLimit(1)

                            if let incidentNumber = call.incidentNumber,
                               !incidentNumber.isEmpty {
                                Text(incidentNumber)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardColorIcon: View {
    let systemImage: String

    private var emoji: String {
        switch systemImage {
        case "envelope.fill", "text.bubble.fill":
            return "📨"
        case "graduationcap.fill":
            return "🎓"
        case "checkmark.seal.fill":
            return "✅"
        case "doc.text.fill":
            return "📄"
        case "wrench.and.screwdriver.fill":
            return "🛠️"
        case "calendar.badge.clock":
            return "🗓️"
        case "person.fill.checkmark":
            return "👤"
        case "clock.arrow.circlepath":
            return "🚨"
        case "megaphone.fill":
            return "📣"
        case "building.2.fill":
            return "🏢"
        case "flame.fill":
            return "🔥"
        case "bell.and.waves.left.and.right.fill":
            return "🚨"
        case "shield.lefthalf.filled":
            return "🛡️"
        default:
            return "📌"
        }
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: 30))
            .frame(width: 42, height: 42)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(Text(systemImage))
    }
}

private struct DashboardLoadingCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DashboardColorIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ProgressView()
                .tint(.white.opacity(0.85))
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct DashboardSmallStatusCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let onTap: () -> Void


    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                DashboardColorIcon(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.9))
            }
            .padding(16)
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardMessageCenterCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                DashboardColorIcon(systemImage: "envelope.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Department, station, training, document, and operational updates.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.9))
            }
            .padding(16)
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardAssignedTrainingPreviewCard: View {
    let items: [DashboardTrainingPreviewItem]
    let onTap: () -> Void

    private var visibleItems: [DashboardTrainingPreviewItem] {
        Array(items.prefix(3))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 12) {
                    ForEach(visibleItems) { item in
                        trainingRow(item)
                    }
                }

                if items.count > visibleItems.count {
                    moreAssignmentsFooter
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.075)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.gold.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                DashboardColorIcon(systemImage: "graduationcap.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Assigned Training")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(items.count) active assignment\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("View")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.9))
            }
        }
    }

    private func trainingRow(_ item: DashboardTrainingPreviewItem) -> some View {
        let color = statusColor(for: item)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.20))
                        .frame(width: 34, height: 34)

                    Image(systemName: statusIcon(for: item))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(statusLine(for: item))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color.opacity(item.progressPercent <= 0 && !item.isOverdue ? 0.92 : 1.0))
                }

                Spacer(minLength: 10)

                Text("\(item.progressPercent)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.16))
                    .clipShape(Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(proxy.size.width * CGFloat(displayedProgress(for: item) / 100), 10),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.18),
                    Color.white.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }

    private var moreAssignmentsFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold)

            Text("+ \(items.count - visibleItems.count) more assignment\(items.count - visibleItems.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            Spacer()

            Text("View all")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold.opacity(0.9))

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.gold.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.gold.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 2)
    }

    private func displayedProgress(for item: DashboardTrainingPreviewItem) -> Double {
        if item.progressPercent <= 0 {
            return 2
        }

        return Double(item.progressPercent)
    }

    private func statusIcon(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "exclamationmark.triangle.fill"
        }

        if item.progressPercent >= 100 {
            return "checkmark.seal.fill"
        }

        if item.progressPercent > 0 {
            return "clock.fill"
        }

        return "circle.dashed"
    }

    private func statusLine(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "Overdue • \(item.progressText)"
        }

        return item.progressText
    }

    private func statusColor(for item: DashboardTrainingPreviewItem) -> Color {
        if item.isOverdue {
            return .orange
        }

        if item.progressPercent >= 100 {
            return .green
        }

        if item.progressPercent > 0 {
            return AppTheme.gold
        }

        return Color(red: 0.62, green: 0.78, blue: 1.0)
    }
}

private struct NewDispatchBanner: View {
    let dispatch: DispatchNotificationPayload
    let onTap: () -> Void

    private var callType: String {
        dispatch.callType ?? "Dispatch"
    }

    private var address: String {
        dispatch.address ?? "Unknown Location"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                DashboardColorIcon(systemImage: "bell.and.waves.left.and.right.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW DISPATCH")
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                    Text(callType)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}

struct DashboardDispatchPreviewCard: View {
    let dispatch: DispatchNotificationPayload
    let isHighlighted: Bool
    let onTap: () -> Void

    private var callType: String {
        dispatch.callType ?? "Dispatch"
    }

    private var address: String {
        dispatch.address ?? "Unknown Location"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 23, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(callType)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(2)

                        if !dispatch.units.isEmpty {
                            Text(dispatch.units.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                }

                DispatchMapPreview(address: address)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(isHighlighted ? 0.20 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.red.opacity(0.85), lineWidth: 2)
            )
            .scaleEffect(isHighlighted ? 1.015 : 1.0)
            .shadow(
                color: isHighlighted ? Color.red.opacity(0.28) : Color.black.opacity(0.12),
                radius: isHighlighted ? 18 : 8,
                y: isHighlighted ? 8 : 4
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isHighlighted)
        }
        .buttonStyle(.plain)
    }
}

struct DispatchMapPreview: View {
    let address: String

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7968, longitude: -74.4815),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
    )

    @State private var coordinate = CLLocationCoordinate2D(
        latitude: 40.7968,
        longitude: -74.4815
    )

    var body: some View {
        Map(position: $position) {
            Marker("Incident", coordinate: coordinate)
                .tint(.red)
        }
        .allowsHitTesting(false)
        .task(id: address) {
            await updateRegion()
        }
        .overlay(alignment: .bottomLeading) {
            Label("Map Preview", systemImage: "map.fill")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
        }
    }

    private func updateRegion() async {
        guard !address.isEmpty else {
            return
        }

        do {
            let request = MKLocalSearch.Request()
            let searchAddress = address.localizedCaseInsensitiveContains("NJ")
                ? address
                : "\(address), Morristown, NJ"
            request.naturalLanguageQuery = searchAddress
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7968, longitude: -74.4815),
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            guard let item = response.mapItems.first else {
                return
            }

            let newCoordinate = item.placemark.coordinate

            await MainActor.run {
                coordinate = newCoordinate
                position = .region(
                    MKCoordinateRegion(
                        center: newCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
            }
        } catch {
            print("❌ Dispatch map preview failed:", error.localizedDescription)
        }
    }
}

struct DashboardUpcomingScheduleCard: View {
    let schedule: APIClient.MobileUpcomingScheduleResponse
    let shift: APIClient.MobileUpcomingShift
    let onTap: () -> Void

    private var statusText: String {
        schedule.isWorkingNow ? "Working now" : "Next scheduled shift"
    }

    private var stationLine: String {
        [shift.station, shift.assignment]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " • ")
    }

    private var detailLine: String {
        if !stationLine.isEmpty {
            return stationLine
        }

        return shift.title
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    DashboardColorIcon(systemImage: schedule.isWorkingNow ? "person.fill.checkmark" : "calendar.badge.clock")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(AppTheme.gold)
                            .tracking(0.6)

                        Text(shift.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 7) {
                    if schedule.isWorkingNow {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7, weight: .bold))

                            Text("Currently working")
                                .font(.caption2.weight(.black))
                                .tracking(0.4)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.14))
                        .clipShape(Capsule())
                    }

                    Text(shift.timeRange)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(detailLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)

                    if let date = shift.date, !date.isEmpty {
                        Text(date)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(schedule.isWorkingNow ? Color.green.opacity(0.75) : AppTheme.gold.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


