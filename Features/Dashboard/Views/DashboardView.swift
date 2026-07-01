import SwiftUI
import UIKit
import Combine
import MapKit
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var statsStore = DashboardStatsStore.shared
    @StateObject private var unitCatalog = UnitCatalog()
    @StateObject private var router = NavigationRouter.shared

    @State private var dispatchNotificationCount = 0
    @State private var isDispatchBellRinging = false
    @State private var showContent = true
    @State private var hasLoadedDispatchUnits = false
    @State private var showMessageModal = false
    @State private var showMessageCenter = false
    @State private var showApparatusWorkOrders = false
    @State private var messageCenterMode: MessageCenterView.Mode = .combined
    @State private var selectedDispatch: DispatchNotificationPayload?
    @State private var dashboardLayoutRefreshID = UUID()

    @State private var latestDispatch: DispatchNotificationPayload?


    private var dashboardRole: DashboardRole {
        DashboardRole.from(session.currentUser?.role)
    }

    private func refreshDashboard() async {
        guard hasAuthToken else { return }

        async let dashboardRefresh: Void = viewModel.refreshAsync(role: mappedUserRole(from: session.currentUser?.role))
        async let statsRefresh: Void = statsStore.forceRefresh(reason: "pullToRefresh")
        _ = await (dashboardRefresh, statsRefresh)
        scheduleLiveActivitySync()
    }

    private var hasAuthToken: Bool {
        APIClient.shared.authToken?.isEmpty == false || KeychainService.shared.loadToken()?.isEmpty == false
    }

    private var configuredDashboardCards: [DashboardCardID] {
        _ = dashboardLayoutRefreshID

        let hiddenCards = DashboardCardLayoutDefaults.hiddenCards(for: session.currentUser?.role)
        return DashboardCardLayoutDefaults
            .savedOrder(for: session.currentUser?.role)
            .filter { !hiddenCards.contains($0) }
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
                    .zIndex(1)

                    VStack(spacing: 0) {

                        switch dashboardRole {

                        case .admin:
                            AdminDashboardView()

                        case .chief:
                            ChiefDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                departmentStats: dashboardDepartmentStats,
                                stationStats: resolvedStationStats,
                                chiefStationStats: dashboardStationStats,
                                recentCalls: dashboardRecentCalls,
                                messagePreviews: viewModel.state.messagePreviews,
                                unreadMessageCount: viewModel.state.unreadNonDispatchMessageCount,
                                isLoading: dashboardIsLoading,
                                onRefresh: {
                                    await refreshDashboard()
                                }
                            ) {
                                showApparatusWorkOrders = true
                            } onOpenMessages: {
                                openMessageCenter(mode: .messagesOnly)
                            } onOpenDispatch: { dispatch in
                                latestDispatch = dispatch

                                selectedDispatch = dispatch
                            } onOpenPastDispatches: {
                                openMessageCenter(mode: .dispatchesOnly)
                            }

                        case .officerCareer:
                            CareerOfficerDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                departmentStats: dashboardDepartmentStats,
                                stationStats: resolvedStationStats,
                                chiefStationStats: dashboardStationStats,
                                upcomingSchedule: viewModel.state.upcomingSchedule,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                recentCalls: dashboardRecentCalls,
                                assignedTraining: viewModel.state.assignedTrainingPreview,
                                pendingDocuments: viewModel.state.pendingDocumentSignatures,
                                pendingPolicies: viewModel.state.pendingPolicyDocuments,
                                departmentUpdates: viewModel.state.departmentUpdates,
                                stationUpdates: viewModel.state.stationUpdates,
                                messagePreviews: viewModel.state.messagePreviews,
                                unreadMessageCount: viewModel.state.unreadNonDispatchMessageCount,
                                isLoading: dashboardIsLoading,
                                onRefresh: {
                                    await refreshDashboard()
                                },
                                onOpenDispatch: { dispatch in
                                    latestDispatch = dispatch

                                    selectedDispatch = dispatch
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

                        case .officerVolunteer:
                            VolunteerOfficerDashboardView(
                                activeDispatches: dashboardActiveDispatches,
                                departmentStats: dashboardDepartmentStats,
                                stationStats: resolvedStationStats,
                                upcomingSchedule: viewModel.state.upcomingSchedule,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                recentCalls: dashboardRecentCalls,
                                assignedTraining: viewModel.state.assignedTrainingPreview,
                                pendingDocuments: viewModel.state.pendingDocumentSignatures,
                                departmentUpdates: viewModel.state.departmentUpdates,
                                stationUpdates: viewModel.state.stationUpdates,
                                messagePreviews: viewModel.state.messagePreviews,
                                unreadMessageCount: viewModel.state.unreadNonDispatchMessageCount,
                                dashboardCards: configuredDashboardCards,
                                isLoading: dashboardIsLoading,
                                onRefresh: {
                                    await refreshDashboard()
                                },
                                onOpenDispatch: { dispatch in
                                    latestDispatch = dispatch

                                    selectedDispatch = dispatch
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

                        case .memberCareer:
                            CareerMemberDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                departmentStats: dashboardDepartmentStats,
                                stationStats: resolvedStationStats,
                                upcomingSchedule: viewModel.state.upcomingSchedule,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                recentCalls: dashboardRecentCalls,
                                assignedTraining: viewModel.state.assignedTrainingPreview,
                                pendingDocuments: viewModel.state.pendingDocumentSignatures,
                                departmentUpdates: viewModel.state.departmentUpdates,
                                stationUpdates: viewModel.state.stationUpdates,
                                messagePreviews: viewModel.state.messagePreviews,
                                unreadMessageCount: viewModel.state.unreadNonDispatchMessageCount,
                                dashboardCards: configuredDashboardCards,
                                isLoading: dashboardIsLoading,
                                onRefresh: {
                                    await refreshDashboard()
                                },
                                onOpenDispatch: { dispatch in
                                    latestDispatch = dispatch

                                    selectedDispatch = dispatch
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
                            VolunteerMemberDashboardView(
                                activeDispatches: dashboardActiveDispatches,
                                volunteerContext: viewModel.state.volunteerContext,
                                stationDisplayName: stationDisplayName,
                                departmentStats: dashboardDepartmentStats,
                                stationStats: resolvedStationStats,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                workOrdersMessage: viewModel.state.apparatusWorkOrdersMessage,
                                assignedTrainingPreview: viewModel.state.assignedTrainingPreview,
                                recentCalls: dashboardRecentCalls,
                                stationUpdates: viewModel.state.stationUpdates,
                                departmentUpdates: viewModel.state.departmentUpdates,
                                messagePreviews: viewModel.state.messagePreviews,
                                unreadMessageCount: viewModel.state.unreadNonDispatchMessageCount,
                                dashboardCards: configuredDashboardCards,
                                isLoading: dashboardIsLoading,
                                onRefresh: {
                                    await refreshDashboard()
                                },
                                onOpenDispatch: { dispatch in
                                    latestDispatch = dispatch

                                    selectedDispatch = dispatch
                                },
                                onOpenPastDispatches: {
                                    openMessageCenter(mode: .dispatchesOnly)
                                },
                                onOpenMessages: {
                                    openMessageCenter(mode: .messagesOnly)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .zIndex(0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                showContent = true

                if hasAuthToken {
                    viewModel.loadIfNeeded(role: mappedUserRole(from: session.currentUser?.role))

                    Task {
                        await statsStore.refreshIfNeeded(reason: "dashboardAppear")
                    }

                    scheduleLiveActivitySync()
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
            .onReceive(NotificationCenter.default.publisher(for: .dashboardLayoutDidChange)) { _ in
                dashboardLayoutRefreshID = UUID()
            }
            .task {
                if hasAuthToken {
                    await activeDispatchRefreshLoop()
                }
            }
            .onDisappear {
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                guard hasAuthToken else { return }

                viewModel.refreshIfStale(role: mappedUserRole(from: session.currentUser?.role))
                Task {
                    await statsStore.refreshIfNeeded(reason: "foreground")
                }
                scheduleLiveActivitySync()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveDispatchNotification)) { notification in
                guard let dispatch = notification.object as? DispatchNotificationPayload else {
                    print("⚠️ Received dispatch notification, but payload was not DispatchNotificationPayload.")
                    return
                }

                print("🔔 Dispatch RECEIVED:", dispatch.id)
                guard hasAuthToken else { return }

                latestDispatch = dispatch
                viewModel.refreshAfterDispatchNotification(role: mappedUserRole(from: session.currentUser?.role))
                Task {
                    await statsStore.refreshIfNeeded(reason: "pushDispatch")
                }

                let isCritical = dispatch.type == .dispatchCritical

                DispatchAlertSoundManager.shared.playDispatchAlert(
                    dispatchId: dispatch.id,
                    tone: dashboardDispatchAlertTone(isCritical: isCritical),
                    isCritical: isCritical
                )

                HapticAlertManager.shared.playDispatchAlert(
                    dispatchId: dispatch.id,
                    style: dashboardHapticAlertStyle,
                    isCritical: isCritical
                )
                dispatchNotificationCount += 1

                isDispatchBellRinging = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isDispatchBellRinging = false
                }
            }
            .onReceive(router.$dispatchToOpen.compactMap { $0 }) { dispatch in
                print("🧭 Dashboard opening dispatch:", dispatch.id)
                guard hasAuthToken else { return }

                latestDispatch = dispatch
                viewModel.refreshAfterDispatchNotification(role: mappedUserRole(from: session.currentUser?.role))
                Task {
                    await statsStore.refreshIfNeeded(reason: "pushDispatch")
                }

                selectedDispatch = dispatch

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
        }
    }


    @MainActor
    private func refreshDashboardContent() async {
        viewModel.refresh(role: mappedUserRole(from: session.currentUser?.role))
    }

    private var firstName: String {
        let role = session.currentUser?.role.uppercased() ?? ""

        if role == "CHIEF" || role == "BATTALION_CHIEF" {
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

    private var dashboardDepartmentStats: APIClient.DispatchBucket? {
        statsStore.stats?.department
    }

    private var dashboardStationStats: APIClient.ChiefStationStats? {
        statsStore.stats?.stations
    }

    private var dashboardIsLoading: Bool {
        viewModel.state.isLoading || (statsStore.isLoading && statsStore.stats == nil)
    }

    private var resolvedStationStats: APIClient.DispatchBucket? {
        if dashboardStationStats == nil {
            return statsStore.stats?.station
        }

        let candidates = [
            stationDisplayName,
            viewModel.state.volunteerContext?.station,
            viewModel.state.volunteerContext?.company,
            session.currentUser?.company
        ]
        .compactMap { $0 }

        for candidate in candidates {
            if let bucket = stationStatsBucket(for: candidate) {
                return bucket
            }
        }

        return statsStore.stats?.station
    }

    private func stationStatsBucket(for stationName: String) -> APIClient.DispatchBucket? {
        let normalized = stationName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let displayName = StationMapper.displayName(from: stationName).uppercased()
        let combined = "\(normalized) \(displayName)"
        let stations = dashboardStationStats

        if combined.contains("STATION 1") || combined.contains("MT KEMBLE") || combined.contains("MT. KEMBLE") {
            return stations?.station1
        }

        if combined.contains("STATION 2") || combined.contains("COLLINSVILLE") {
            return stations?.station2
        }

        if combined.contains("STATION 3") || combined.contains("HILLSIDE") {
            return stations?.station3
        }

        if combined.contains("STATION 4") || combined.contains("FAIRCHILD") {
            return stations?.station4
        }

        if combined.contains("STATION 5") || combined.contains("WOODLAND") {
            return stations?.station5
        }

        return nil
    }

    private var hasNewMessage: Bool {
        false
    }

    private var dashboardActiveDispatches: [APIClient.ActiveDispatch] {
        switch dashboardRole {
        case .officerVolunteer, .memberVolunteer:
            return stationScopedActiveDispatches
        case .admin, .chief, .officerCareer, .memberCareer:
            return viewModel.activeDispatches
        }
    }

    private var dashboardRecentCalls: [RecentDepartmentCall] {
        switch dashboardRole {
        case .officerVolunteer, .memberVolunteer:
            return stationScopedRecentCalls
        case .admin, .chief, .officerCareer, .memberCareer:
            return Array(viewModel.state.recentDepartmentCalls.prefix(3))
        }
    }

    private var stationScopedRecentCalls: [RecentDepartmentCall] {
        let stationTokens = volunteerStationDispatchUnitTokens

        guard !stationTokens.isEmpty else {
            return []
        }

        let stationCalls = viewModel.state.recentDepartmentCalls.filter { call in
            let unitValues = call.rawUnits.isEmpty ? call.units : call.rawUnits
            let callTokens = unitValues.flatMap(expandedDispatchUnitTokens)
            return callTokens.contains { stationTokens.contains($0) }
        }

        return Array(stationCalls.prefix(3))
    }

    private var stationScopedActiveDispatches: [APIClient.ActiveDispatch] {
        let stationTokens = volunteerStationDispatchUnitTokens

        guard !stationTokens.isEmpty else {
            return []
        }

        return viewModel.activeDispatches.filter { dispatch in
            let dispatchTokens = dispatch.units.flatMap(expandedDispatchUnitTokens)
            return dispatchTokens.contains { stationTokens.contains($0) }
        }
    }

    private var volunteerStationDispatchUnitTokens: Set<String> {
        var tokens = Set<String>()
        let context = viewModel.state.volunteerContext

        for apparatus in context?.stationApparatus ?? [] {
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.dispatchUnitIds))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.unitId))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.apparatusApiId))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.displayName))
        }

        if let apparatus = context?.apparatus {
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.dispatchUnitIds))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.unitId))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.apparatusApiId))
            tokens.formUnion(expandedDispatchUnitTokens(apparatus.displayName))
        }

        if tokens.isEmpty, let stationNumber = volunteerStationNumber {
            tokens.formUnion(defaultDispatchUnitTokens(forStationNumber: stationNumber))
        }

        return tokens
    }

    private var volunteerStationNumber: Int? {
        let candidates = [
            viewModel.state.volunteerContext?.station,
            viewModel.state.volunteerContext?.company,
            stationDisplayName,
            session.currentUser?.company
        ]
        .compactMap { $0 }

        for candidate in candidates {
            if let number = stationNumber(from: candidate) {
                return number
            }
        }

        return nil
    }

    private func stationNumber(from value: String) -> Int? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        if let match = normalized.range(of: #"STATION\s*([1-5])"#, options: .regularExpression) {
            let matched = String(normalized[match])
            return Int(matched.filter(\.isNumber))
        }

        let displayName = StationMapper.displayName(from: value)
        if displayName != value, let mapped = StationMapper.stationNumber(from: value) {
            return mapped
        }

        if normalized.contains("MT KEMBLE") || normalized.contains("MT. KEMBLE") {
            return 1
        }
        if normalized.contains("COLLINSVILLE") {
            return 2
        }
        if normalized.contains("HILLSIDE") {
            return 3
        }
        if normalized.contains("FAIRCHILD") {
            return 4
        }
        if normalized.contains("WOODLAND") {
            return 5
        }

        return nil
    }

    private func defaultDispatchUnitTokens(forStationNumber stationNumber: Int) -> Set<String> {
        let unitIds: [String]

        switch stationNumber {
        case 1:
            unitIds = ["F22E1", "Engine 1", "E1", "ENG1"]
        case 2:
            unitIds = ["F22E2", "Engine 2", "E2", "ENG2"]
        case 3:
            unitIds = ["F22E3", "Engine 3", "E3", "ENG3"]
        case 4:
            unitIds = ["F22E4", "Engine 4", "E4", "ENG4", "F22L2", "Ladder 2", "L2", "LAD2", "F22R6", "Rescue 6", "R6", "RES6"]
        case 5:
            unitIds = ["F22E5", "Engine 5", "E5", "ENG5", "F22E6", "Engine 6", "E6", "ENG6", "F22L1", "Ladder 1", "L1", "LAD1"]
        default:
            unitIds = []
        }

        return Set(unitIds.flatMap(expandedDispatchUnitTokens))
    }

    private func expandedDispatchUnitTokens(_ value: String?) -> [String] {
        guard let value else {
            return []
        }

        return value
            .split { character in
                character == "," || character == ";" || character == "|" || character.isNewline
            }
            .flatMap { part -> [String] in
                let normalized = part
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

                guard !normalized.isEmpty else {
                    return []
                }

                let compact = normalized
                    .filter { $0.isLetter || $0.isNumber }

                return Array(Set([normalized, compact].filter { !$0.isEmpty }))
            }
    }

    private var headerAlertMode: DashboardHeaderAlertMode {
        if !dashboardActiveDispatches.isEmpty {
            return .activeDispatch(messageCount: viewModel.state.unreadNonDispatchMessageCount)
        }

        if viewModel.state.unreadNonDispatchMessageCount > 0 {
            return .unreadMessages(count: viewModel.state.unreadNonDispatchMessageCount)
        }

        return .latestDispatches
    }

    private func handleHeaderAlertTap() {
        isDispatchBellRinging = false

        if let activeDispatch = dashboardActiveDispatches.first {
            let dispatch = makeDispatchPayload(from: activeDispatch)
            latestDispatch = dispatch

            selectedDispatch = dispatch
            return
        }

        if viewModel.state.unreadNonDispatchMessageCount > 0 {
            openMessageCenter(mode: .messagesOnly)
        } else {
            openMessageCenter(mode: .dispatchesOnly)
        }
    }

    private var activeDispatchLiveActivitySignature: String {
        dashboardActiveDispatches
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
        let activeDispatches = dashboardActiveDispatches
        print("🟣 Dashboard LiveActivity sync. activeDispatches:", activeDispatches.count)

        guard let newestDispatch = activeDispatches.first else {
            print("🟣 Dashboard LiveActivity no active dispatches. Ending all.")
            DispatchLiveActivityManager.shared.endAll()
            return
        }

        let payload = makeDispatchPayload(
            from: newestDispatch,
            activeCallCount: activeDispatches.count
        )
        print("🟣 Dashboard LiveActivity newest dispatch:", payload.id, payload.title)

        DispatchLiveActivityManager.shared.startOrUpdate(from: payload)
    }

    private func scheduleLiveActivitySync() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            syncLiveActivityWithDashboardActiveDispatches()
        }
    }

    private func activeDispatchRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 15_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            await viewModel.refreshDispatchFeed()
        }
    }

    private func mappedUserRole(from rawRole: String?) -> UserRole {
        guard let rawRole = rawRole?.uppercased() else {
            return .member
        }

        if rawRole == "ADMIN" || rawRole == "CHIEF" || rawRole == "BATTALION_CHIEF" {
            return .chief
        } else if rawRole.contains("OFFICER") {
            return .officer
        } else {
            return .member
        }
    }

    private var dashboardHapticAlertStyle: HapticAlertStyle {
        if let rawValue = UserDefaults.standard.string(forKey: "notification_haptic_alert_style"),
           let style = HapticAlertStyle(rawValue: rawValue) {
            return style
        }

        if UserDefaults.standard.object(forKey: "notification_haptics_enabled") == nil {
            return .normal
        }

        return UserDefaults.standard.bool(forKey: "notification_haptics_enabled") ? .normal : .off
    }

    private func dashboardDispatchAlertTone(isCritical: Bool) -> DispatchAlertTone {
        let key = isCritical
            ? "notification_critical_dispatch_alert_tone"
            : "notification_dispatch_alert_tone"

        if let rawValue = UserDefaults.standard.string(forKey: key),
           let tone = DispatchAlertTone(rawValue: rawValue) {
            return tone
        }

        guard let data = UserDefaults.standard.data(forKey: "notification_preferences"),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else {
            return isCritical ? .airHornBlast : .systemDefault
        }

        return isCritical ? preferences.criticalDispatchAlertTone : preferences.dispatchAlertTone
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
            units: DispatchUnitFilter.visibleRespondingUnits(from: activeDispatch.units),
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
        case "BATTALION_CHIEF":
            return "Battalion Chief"
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
}
