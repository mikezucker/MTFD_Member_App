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

    @State private var dispatchNotificationCount = 0
    @State private var isDispatchBellRinging = false
    @State private var showContent = false
    @State private var hasLoadedDispatchUnits = false
    @State private var showMessageModal = false
    @State private var showMessageCenter = false
    @State private var selectedDispatch: DispatchNotificationPayload?

    @State private var latestDispatch: DispatchNotificationPayload?
    @State private var showNewDispatchBanner = false
    @State private var highlightedDispatchId: String?

    @AppStorage("dashboardTotalsWindow") private var selectedWindowRawValue = DashboardTotalsWindow.ytd.rawValue

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
                        unreadCount: dispatchNotificationCount,
                        isBellRinging: isDispatchBellRinging,
                        onTapMessages: {
                            dispatchNotificationCount = 0
                            isDispatchBellRinging = false
                            showMessageCenter = true
                        }
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            DashboardCallSummarySection(
                                selectedWindowRawValue: $selectedWindowRawValue,
                                department: viewModel.state.dashboardDepartment,
                                station: viewModel.state.dashboardStation,
                                isLoading: viewModel.state.isLoading
                            )
                            DashboardMessageCenterCard {
                                dispatchNotificationCount = 0
                                isDispatchBellRinging = false
                                showMessageCenter = true
                            }

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

                            if !viewModel.state.assignedTrainingPreview.isEmpty {
                                sectionTitle("Assigned Training")

                                DashboardAssignedTrainingPreviewCard(
                                    items: viewModel.state.assignedTrainingPreview
                                ) {
                                    handleNavigation(to: .trainingAssigned)
                                }
                            }

                            if !viewModel.state.stationUpdates.isEmpty {
                                sectionTitle("Station Update")

                                VStack(spacing: 10) {
                                    ForEach(viewModel.state.stationUpdates) { update in
                                        DashboardUpdateBlock(update: update)
                                    }
                                }
                            }

                            if !viewModel.state.departmentUpdates.isEmpty {
                                sectionTitle("Dept. Update")

                                VStack(spacing: 10) {
                                    ForEach(viewModel.state.departmentUpdates) { update in
                                        DashboardUpdateBlock(update: update)
                                    }
                                }
                            }

                            if !viewModel.state.attentionItems.isEmpty {
                                sectionTitle("Needs Attention")

                                ForEach(viewModel.state.attentionItems) { item in
                                    DashboardAttentionCard(item: item) {
                                        handleNavigation(to: item.destination)
                                    }
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
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 16)
                        .animation(.easeInOut(duration: 0.35), value: showContent)
                    }
                    .refreshable {
                        viewModel.refresh(role: mappedUserRole(from: session.currentUser?.role))
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                viewModel.refreshIfStale(role: mappedUserRole(from: session.currentUser?.role))
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
                MessageCenterView()
            }
        }
    }

    private var firstName: String {
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

    private func makeDispatchPayload(from activeDispatch: APIClient.ActiveDispatch) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: activeDispatch.message ?? activeDispatch.address,
            callType: activeDispatch.callType,
            address: activeDispatch.address,
            units: activeDispatch.units,
            isWorkingFire: activeDispatch.isWorkingFire ?? false,
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

    private func handleNavigation(to destination: AppDestination) {
        print("Navigate to: \(destination)")
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

private struct DashboardMessageCenterCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 40, height: 40)

                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.gold)
                }

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

private struct DashboardAssignedTrainingPreviewCard: View {
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
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 36, height: 36)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.gold)
                }

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
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 20, weight: .bold))
                }

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

private struct DashboardDispatchPreviewCard: View {
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
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.red)

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

private struct DispatchMapPreview: View {
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
            request.naturalLanguageQuery = address

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            guard let item = response.mapItems.first else {
                return
            }

            let newCoordinate = item.location.coordinate

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
