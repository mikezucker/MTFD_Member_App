import SwiftUI
import UIKit
import Combine
import MapKit
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = DashboardViewModel()
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

    @State private var latestDispatch: DispatchNotificationPayload?


    private var dashboardRole: DashboardRole {
        DashboardRole.from(session.currentUser?.role)
    }

    private func refreshDashboard() async {
        await viewModel.refreshAsync(role: mappedUserRole(from: session.currentUser?.role))
        scheduleLiveActivitySync()
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

                    Group {

                        switch dashboardRole {

                        case .admin:
                            AdminDashboardView()

                        case .chief:
                            ChiefDashboardView(
                                activeDispatches: viewModel.activeDispatches,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                departmentStats: viewModel.state.dashboardDepartment,
                                stationStats: viewModel.state.dashboardStation,
                                chiefStationStats: viewModel.state.dashboardStations,
                                recentCalls: viewModel.state.recentDepartmentCalls,
                                isLoading: viewModel.state.isLoading || viewModel.state.isLoadingStats,
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
                                departmentUpdates: viewModel.state.departmentUpdates,
                                stationUpdates: viewModel.state.stationUpdates,
                                isLoading: viewModel.state.isLoading || viewModel.state.isLoadingStats,
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
                                volunteerContext: viewModel.state.volunteerContext,
                                stationStats: viewModel.state.dashboardStation,
                                workOrders: viewModel.state.apparatusWorkOrders,
                                workOrdersMessage: viewModel.state.apparatusWorkOrdersMessage,
                                assignedTrainingPreview: viewModel.state.assignedTrainingPreview,
                                isLoading: viewModel.state.isLoading
                            )
                        }
}
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {

                showContent = true
                viewModel.loadIfNeeded(role: mappedUserRole(from: session.currentUser?.role))
                scheduleLiveActivitySync()


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
            .onDisappear {
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
                dispatchNotificationCount += 1

                isDispatchBellRinging = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isDispatchBellRinging = false
                }
            }
            .onReceive(router.$dispatchToOpen.compactMap { $0 }) { dispatch in
                print("🧭 Dashboard opening dispatch:", dispatch.id)

                latestDispatch = dispatch
                viewModel.addActiveDispatch(from: dispatch)

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
}
