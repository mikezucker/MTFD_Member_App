import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var router = NavigationRouter.shared
    @State private var showGlobalDispatchBanner = false
    @State private var activeDispatchPayload: AppNotificationPayload?

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 3/255,
            green: 22/255,
            blue: 51/255,
            alpha: 1
        )

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = .lightGray
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $router.selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(NavigationRouter.AppTab.home)

                if canUseCommandTab {
                    CommandView()
                        .tabItem {
                            Label("Command", systemImage: "shield.lefthalf.filled")
                        }
                        .tag(NavigationRouter.AppTab.command)
                }

                TrainingView()
                    .tabItem {
                        Label("Training", systemImage: "flame.fill")
                    }
                    .tag(NavigationRouter.AppTab.training)

                DocumentsView()
                    .tabItem {
                        Label("Documents", systemImage: "doc.text.fill")
                    }
                    .tag(NavigationRouter.AppTab.documents)

                ScheduleView()
                    .tabItem {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                    }
                    .tag(NavigationRouter.AppTab.schedule)

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(NavigationRouter.AppTab.more)
            }
            .tint(AppTheme.gold)

            if showGlobalDispatchBanner, let activeDispatchPayload {
                GlobalDispatchBanner(
                    payload: activeDispatchPayload,
                    onTap: {
                        openDispatchDetail(activeDispatchPayload)
                    },
                    onDismiss: {
                        dismissBanner()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showGlobalDispatchBanner)
        .onReceive(router.$dispatchToOpen) { payload in
            guard let payload else { return }

            router.selectedTab = .home
            activeDispatchPayload = payload

            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showGlobalDispatchBanner = true
            }

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if activeDispatchPayload?.id == payload.id {
                    dismissBanner()
                }
            }
        }
        .sheet(item: $router.dispatchToOpen, onDismiss: {
            router.clearDispatchRoute()
        }) { payload in
            DispatchDetailView(dispatch: payload)
        }
    }

    private var canUseCommandTab: Bool {
        let role = session.currentUser?.role.uppercased()

        return role == "ADMIN"
            || role == "CHIEF"
            || role == "OFFICER_CAREER"
            || role == "OFFICER_VOLUNTEER"
    }

    private func openDispatchDetail(_ payload: AppNotificationPayload) {
        router.selectedTab = .home
        router.dispatchToOpen = payload

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showGlobalDispatchBanner = false
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func dismissBanner() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showGlobalDispatchBanner = false
        }
    }
}

private struct GlobalDispatchBanner: View {
    let payload: AppNotificationPayload
    let onTap: () -> Void
    let onDismiss: () -> Void

    private var dispatchSubtitle: String {
        let parts = [
            payload.address,
            payload.units.isEmpty ? nil : payload.units.joined(separator: ", ")
        ].compactMap { $0 }

        return parts.joined(separator: " • ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(payload.type == .dispatchCritical ? "CRITICAL DISPATCH" : "LIVE DISPATCH")
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                    Text(payload.callType ?? payload.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if !dispatchSubtitle.isEmpty {
                        Text(dispatchSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}


private struct CommandView: View {
    @EnvironmentObject private var session: SessionManager

    private var role: String {
        session.currentUser?.role.uppercased() ?? ""
    }

    var body: some View {
        if role == "ADMIN" || role == "CHIEF" {
            ChiefCommandView()
        } else {
            LieutenantCommandView()
        }
    }
}

private struct ChiefCommandView: View {
    var body: some View {
        CommandWorkspaceView(
            title: "Chief Command",
            subtitle: "Department-wide command workspace",
            description: "Monitor department operations, staffing, training compliance, messages, documents, and future apparatus location tools.",
            tiles: [
                CommandTileData(
                    title: "Department Operations",
                    subtitle: "View active incidents, department-wide status, dispatch activity, and operational priorities.",
                    systemImage: "shield.lefthalf.filled"
                ),
                CommandTileData(
                    title: "Staffing Overview",
                    subtitle: "Review today’s staffing, vacancies, relief driver coverage, and department schedule status.",
                    systemImage: "person.3.sequence.fill",
                    destination: .staffing
                ),
                CommandTileData(
                    title: "Training Compliance",
                    subtitle: "Track assigned training, overdue members, JPR progress, and evaluator sign-offs.",
                    systemImage: "checklist.checked",
                    destination: .training
                ),
                CommandTileData(
                    title: "Department Messages",
                    subtitle: "Prepare department-wide messages, announcements, and operational updates.",
                    systemImage: "megaphone.fill",
                    destination: .messages
                ),
                CommandTileData(
                    title: "Documents / SOPs",
                    subtitle: "Review SOP acknowledgements, missing signatures, and document completion status.",
                    systemImage: "doc.text.magnifyingglass"
                ),
                CommandTileData(
                    title: "Apparatus GPS",
                    subtitle: "Future apparatus location map, stale-location warnings, and vehicle status overview.",
                    systemImage: "location.north.line.fill"
                )
            ]
        )
    }
}

private struct LieutenantCommandView: View {
    var body: some View {
        CommandWorkspaceView(
            title: "Lieutenant Command",
            subtitle: "Station and company command workspace",
            description: "Focus on assigned members, station staffing, training progress, station messages, and operational readiness.",
            tiles: [
                CommandTileData(
                    title: "Station Operations",
                    subtitle: "View active incidents, assigned units, station/company status, and operational updates.",
                    systemImage: "building.2.crop.circle.fill"
                ),
                CommandTileData(
                    title: "My Staffing",
                    subtitle: "Review station/company schedule, vacancies, assigned members, and relief driver coverage.",
                    systemImage: "person.2.badge.gearshape.fill",
                    destination: .staffing
                ),
                CommandTileData(
                    title: "Training Progress",
                    subtitle: "Track assigned member training, JPR completion, skill checkoffs, and sign-offs.",
                    systemImage: "checkmark.seal.fill",
                    destination: .training
                ),
                CommandTileData(
                    title: "Station Messages",
                    subtitle: "Prepare station or company-specific messages and updates.",
                    systemImage: "text.bubble.fill",
                    destination: .messages
                ),
                CommandTileData(
                    title: "Documents",
                    subtitle: "Review SOPs, station documents, acknowledgements, and required signatures.",
                    systemImage: "doc.text.fill"
                ),
                CommandTileData(
                    title: "Members",
                    subtitle: "View assigned member status, profiles, roles, and readiness information.",
                    systemImage: "person.crop.rectangle.stack.fill"
                )
            ]
        )
    }
}

private struct CommandWorkspaceView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var messageViewModel = MessageCenterViewModel()
    @State private var selectedDispatch: DispatchNotificationPayload?
    @State private var selectedCommandDestination: CommandDestination?

    private let title: String
    private let subtitle: String
    private let description: String
    private let tiles: [CommandTileData]

    init(
        title: String,
        subtitle: String,
        description: String,
        tiles: [CommandTileData]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.tiles = tiles
    }

    var body: some View {
        AppScreen(title: "Command") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if !dashboardViewModel.activeDispatches.isEmpty {
                        activeDispatchSection
                    }

                    staffingOverviewSection

                    trainingOversightSection

                    messagesOverviewSection

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        spacing: 14
                    ) {
                        ForEach(tiles) { tile in
                            commandTile(tile)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .refreshable {
                dashboardViewModel.refresh(role: mappedCommandUserRole)
                await scheduleViewModel.refresh()
                await messageViewModel.refresh()
            }
        }
        .task {
            dashboardViewModel.loadIfNeeded(role: mappedCommandUserRole)

            if scheduleViewModel.entries.isEmpty {
                await scheduleViewModel.load()
            }

            await messageViewModel.loadMessagesIfNeeded()
        }
        .sheet(item: $selectedDispatch) { dispatch in
            DispatchDetailView(dispatch: dispatch)
        }
        .sheet(item: $selectedCommandDestination) { destination in
            switch destination {
            case .staffing:
                CommandStaffingDetailView(
                    title: mappedCommandUserRole == .chief ? "Department Staffing" : "Station Staffing",
                    date: scheduleViewModel.date,
                    entries: scheduleViewModel.entries
                )

            case .training:
                CommandTrainingDetailView(
                    title: mappedCommandUserRole == .chief ? "Department Training" : "Station Training",
                    items: dashboardViewModel.state.assignedTrainingPreview
                )

            case .messages:
                CommandMessagesDetailView(
                    title: mappedCommandUserRole == .chief ? "Department Messages" : "Station Messages",
                    messages: commandPreviewAllMessages,
                    unreadCount: messageViewModel.unreadCount
                )
            }
        }
    }

    private var messagesOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages Overview")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Department, station, training, document, and operational updates")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                if messageViewModel.unreadCount > 0 {
                    Text("\(messageViewModel.unreadCount) unread")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.82))
                        .clipShape(Capsule())
                } else if !messageViewModel.messages.isEmpty {
                    Text("All read")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.gold.opacity(0.16))
                        .clipShape(Capsule())
                }
            }

            if messageViewModel.isLoading && messageViewModel.messages.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else if commandPreviewMessages.isEmpty {
                commandInfoCard(
                    title: "No messages",
                    message: messageViewModel.errorMessage ?? "Department, station, and training messages will appear here.",
                    systemImage: "tray"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(commandPreviewMessages) { message in
                        commandMessageRow(message)
                    }
                }
            }
        }
    }

    private var commandPreviewMessages: [MobileMessage] {
        Array(commandPreviewAllMessages.prefix(3))
    }

    private var commandPreviewAllMessages: [MobileMessage] {
        messageViewModel.messages.filter { message in
            message.type != "DISPATCH" &&
            message.type != "DISPATCH_UPDATE" &&
            message.dispatchId == nil
        }
    }

    private func commandMessageRow(_ message: MobileMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: messageIcon(for: message))
                .font(.headline.weight(.semibold))
                .foregroundStyle(message.isRead ? AppTheme.gold : .red)
                .frame(width: 30, height: 30)
                .background((message.isRead ? AppTheme.gold : Color.red).opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(message.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !message.isRead {
                        Text("NEW")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(2)
                }

                Text(messageTypeLabel(for: message))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(message.isRead ? Color.white.opacity(0.10) : Color.red.opacity(0.42), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func messageIcon(for message: MobileMessage) -> String {
        let type = message.type.uppercased()

        if type.contains("TRAINING") {
            return "checklist.checked"
        }

        if type.contains("DOCUMENT") || type.contains("SOP") {
            return "doc.text.fill"
        }

        if type.contains("STATION") {
            return "building.2.fill"
        }

        if type.contains("ANNOUNCEMENT") || type.contains("DEPARTMENT") {
            return "megaphone.fill"
        }

        return "text.bubble.fill"
    }

    private func messageTypeLabel(for message: MobileMessage) -> String {
        message.type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var trainingOversightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Oversight")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Assigned training and readiness indicators")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                if !dashboardViewModel.state.assignedTrainingPreview.isEmpty {
                    Text("\(dashboardViewModel.state.assignedTrainingPreview.count) active")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.gold.opacity(0.16))
                        .clipShape(Capsule())
                }
            }

            if dashboardViewModel.state.assignedTrainingPreview.isEmpty {
                commandInfoCard(
                    title: "No active assigned training",
                    message: "Assigned training, JPR readiness, and evaluator sign-offs will appear here as they become available.",
                    systemImage: "checkmark.seal.fill"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(dashboardViewModel.state.assignedTrainingPreview.prefix(3))) { item in
                        commandTrainingRow(item)
                    }
                }

                if dashboardViewModel.state.assignedTrainingPreview.count > 3 {
                    Text("+ \(dashboardViewModel.state.assignedTrainingPreview.count - 3) more training assignment\(dashboardViewModel.state.assignedTrainingPreview.count - 3 == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                        .padding(.leading, 4)
                }
            }
        }
    }

    private func commandTrainingRow(_ item: DashboardTrainingPreviewItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: trainingStatusIcon(for: item))
                .font(.headline.weight(.semibold))
                .foregroundStyle(trainingStatusColor(for: item))
                .frame(width: 28, height: 28)
                .background(trainingStatusColor(for: item).opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if item.isOverdue {
                        Text("OVERDUE")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }

                Text(item.progressText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                ProgressView(value: trainingProgress(for: item))
                    .tint(trainingStatusColor(for: item))
            }

            Spacer(minLength: 0)

            Text("\(Int(trainingProgress(for: item) * 100))%")
                .font(.caption.bold())
                .foregroundStyle(trainingStatusColor(for: item))
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isOverdue ? Color.red.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trainingProgress(for item: DashboardTrainingPreviewItem) -> Double {
        min(max(Double(item.progressPercent) / 100.0, 0), 1)
    }

    private func trainingStatusColor(for item: DashboardTrainingPreviewItem) -> Color {
        if item.isOverdue {
            return .red
        }

        if trainingProgress(for: item) >= 0.8 {
            return .green
        }

        if trainingProgress(for: item) >= 0.5 {
            return .orange
        }

        return .red
    }

    private func trainingStatusIcon(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "exclamationmark.triangle.fill"
        }

        if trainingProgress(for: item) >= 1.0 {
            return "checkmark.seal.fill"
        }

        if trainingProgress(for: item) >= 0.5 {
            return "clock.badge.checkmark.fill"
        }

        return "exclamationmark.triangle.fill"
    }

    private var staffingOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Staffing Overview")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(scheduleViewModel.date ?? "Today’s schedule")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                if scheduleVacancyCount > 0 {
                    Text("\(scheduleVacancyCount) vacant")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.16))
                        .clipShape(Capsule())
                } else if !scheduleViewModel.entries.isEmpty {
                    Text("Covered")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.gold.opacity(0.16))
                        .clipShape(Capsule())
                }
            }

            if scheduleViewModel.isLoading && scheduleViewModel.entries.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else if scheduleViewModel.entries.isEmpty {
                commandInfoCard(
                    title: "No staffing entries",
                    message: scheduleViewModel.errorMessage ?? "No schedule entries were returned for today.",
                    systemImage: "calendar.badge.exclamationmark"
                )
            } else {
                HStack(spacing: 10) {
                    commandMetricCard(
                        title: "Assignments",
                        value: "\(scheduleFilledCount)",
                        systemImage: "person.crop.circle.fill"
                    )

                    commandMetricCard(
                        title: "Vacancies",
                        value: "\(scheduleVacancyCount)",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }

                VStack(spacing: 10) {
                    ForEach(schedulePreviewEntries) { entry in
                        commandScheduleRow(entry)
                    }
                }
            }
        }
    }

    private var schedulePreviewEntries: [APIClient.MobileScheduleEntry] {
        Array(scheduleViewModel.entries.prefix(4))
    }

    private var scheduleFilledCount: Int {
        scheduleViewModel.entries.reduce(0) { total, entry in
            total + entry.staffingDetails.filter { !$0.isVacant }.count
        }
    }

    private var scheduleVacancyCount: Int {
        scheduleViewModel.entries.reduce(0) { total, entry in
            total + entry.staffingDetails.filter { $0.isVacant }.count
        }
    }

    private func commandScheduleRow(_ entry: APIClient.MobileScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(entry.timeRange)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.gold)
                }

                Spacer()

                if let station = entry.station, !station.isEmpty {
                    Text(station)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.76))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            if entry.staffing.isEmpty {
                Text("No staffing listed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else {
                ForEach(Array(entry.staffing.prefix(3).enumerated()), id: \.offset) { _, staff in
                    HStack(spacing: 8) {
                        Image(systemName: staff.lowercased().contains("vacant") ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(staff.lowercased().contains("vacant") ? .orange : AppTheme.gold)
                            .frame(width: 16)

                        Text(staff)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                }

                if entry.staffing.count > 3 {
                    Text("+ \(entry.staffing.count - 3) more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .padding(.leading, 24)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func commandMetricCard(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func commandInfoCard(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var activeDispatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Dispatches")
                .font(.headline)
                .foregroundStyle(.white)

            ActiveDispatchStackView(dispatches: dashboardViewModel.activeDispatches) { activeDispatch in
                selectedDispatch = makeDispatchPayload(from: activeDispatch)
            }
        }
    }

    private var mappedCommandUserRole: UserRole {
        let rawRole = session.currentUser?.role.uppercased() ?? ""

        if rawRole == "ADMIN" || rawRole == "CHIEF" {
            return .chief
        }

        if rawRole.contains("OFFICER") {
            return .officer
        }

        return .member
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))

            Text(description)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func commandTile(_ tile: CommandTileData) -> some View {
        Button {
            guard let destination = tile.destination else { return }

            selectedCommandDestination = destination
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: tile.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.gold)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Spacer()

                    if tile.destination != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(tile.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(tile.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .padding(16)
            .background(Color.white.opacity(tile.destination == nil ? 0.07 : 0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(tile.destination == nil ? 0.08 : 0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(tile.destination == nil)
    }
}

private enum CommandDestination: Identifiable {
    case staffing
    case training
    case messages

    var id: String {
        switch self {
        case .staffing:
            return "staffing"
        case .training:
            return "training"
        case .messages:
            return "messages"
        }
    }
}

private struct CommandTileData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    var destination: CommandDestination? = nil
}

private struct CommandStaffingDetailView: View {
    let title: String
    let date: String?
    let entries: [APIClient.MobileScheduleEntry]

    private var filledCount: Int {
        entries.reduce(0) { total, entry in
            total + entry.staffingDetails.filter { !$0.isVacant }.count
        }
    }

    private var vacancyCount: Int {
        entries.reduce(0) { total, entry in
            total + entry.staffingDetails.filter { $0.isVacant }.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        HStack(spacing: 10) {
                            metricCard(
                                title: "Filled",
                                value: "\(filledCount)",
                                systemImage: "person.crop.circle.fill"
                            )

                            metricCard(
                                title: "Vacant",
                                value: "\(vacancyCount)",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                isWarning: vacancyCount > 0
                            )
                        }

                        if entries.isEmpty {
                            emptyCard
                        } else {
                            VStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    staffingDetailCard(entry)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(date ?? "Today’s schedule")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))

            Text("Review staffing assignments, vacancies, and coverage for the current schedule.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 5) {
                Text("No staffing entries")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("No schedule entries were returned for today.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricCard(
        title: String,
        value: String,
        systemImage: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isWarning ? .orange : AppTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func staffingDetailCard(_ entry: APIClient.MobileScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(entry.timeRange)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.gold)
                }

                Spacer()

                if let station = entry.station, !station.isEmpty {
                    Text(station)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            if entry.staffing.isEmpty {
                Text("No staffing listed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(entry.staffing.enumerated()), id: \.offset) { _, staff in
                        HStack(alignment: .top, spacing: 10) {
                            let isVacant = staff.lowercased().contains("vacant")

                            Image(systemName: isVacant ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isVacant ? .orange : AppTheme.gold)
                                .frame(width: 22)

                            Text(staff)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}


private struct CommandTrainingDetailView: View {
    let title: String
    let items: [DashboardTrainingPreviewItem]

    private var overdueCount: Int {
        items.filter { $0.isOverdue }.count
    }

    private var completedCount: Int {
        items.filter { $0.progressPercent >= 100 }.count
    }

    private var averageProgress: Int {
        guard !items.isEmpty else { return 0 }

        let total = items.reduce(0) { $0 + $1.progressPercent }
        return total / items.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        HStack(spacing: 10) {
                            metricCard(
                                title: "Assigned",
                                value: "\(items.count)",
                                systemImage: "checklist.checked"
                            )

                            metricCard(
                                title: "Overdue",
                                value: "\(overdueCount)",
                                systemImage: "exclamationmark.triangle.fill",
                                isWarning: overdueCount > 0
                            )
                        }

                        HStack(spacing: 10) {
                            metricCard(
                                title: "Completed",
                                value: "\(completedCount)",
                                systemImage: "checkmark.seal.fill"
                            )

                            metricCard(
                                title: "Avg. progress",
                                value: "\(averageProgress)%",
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                        }

                        jprReadinessCard

                        if items.isEmpty {
                            emptyCard
                        } else {
                            VStack(spacing: 12) {
                                ForEach(items) { item in
                                    trainingDetailCard(item)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Training assignments, progress, overdue items, and JPR readiness")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))

            Text("Evaluator sign-offs and detailed JPR workflows will plug into this view as the training module expands.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var jprReadinessCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "signature")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 5) {
                Text("JPR / Evaluator Readiness")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Pending JPR reviews, skill checkoffs, and evaluator sign-offs will appear here when the training workflow is fully wired.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 5) {
                Text("No active assigned training")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Assigned training, overdue items, and JPR reviews will appear here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricCard(
        title: String,
        value: String,
        systemImage: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isWarning ? .red : AppTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trainingDetailCard(_ item: DashboardTrainingPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: trainingStatusIcon(for: item))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(trainingStatusColor(for: item))
                    .frame(width: 30, height: 30)
                    .background(trainingStatusColor(for: item).opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if item.isOverdue {
                            Text("OVERDUE")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }

                    Text(item.progressText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                }

                Spacer()

                Text("\(item.progressPercent)%")
                    .font(.caption.bold())
                    .foregroundStyle(trainingStatusColor(for: item))
            }

            ProgressView(value: trainingProgress(for: item))
                .tint(trainingStatusColor(for: item))
        }
        .padding(16)
        .background(.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(item.isOverdue ? Color.red.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func trainingProgress(for item: DashboardTrainingPreviewItem) -> Double {
        min(max(Double(item.progressPercent) / 100.0, 0), 1)
    }

    private func trainingStatusColor(for item: DashboardTrainingPreviewItem) -> Color {
        if item.isOverdue {
            return .red
        }

        if item.progressPercent >= 80 {
            return .green
        }

        if item.progressPercent >= 50 {
            return .orange
        }

        return .red
    }

    private func trainingStatusIcon(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "exclamationmark.triangle.fill"
        }

        if item.progressPercent >= 100 {
            return "checkmark.seal.fill"
        }

        if item.progressPercent >= 50 {
            return "clock.badge.checkmark.fill"
        }

        return "exclamationmark.triangle.fill"
    }
}


private struct CommandMessagesDetailView: View {
    let title: String
    let messages: [MobileMessage]
    let unreadCount: Int

    @State private var showCreateMessage = false
    @State private var createdMessage: MobileMessage?

    private var displayedMessages: [MobileMessage] {
        if let createdMessage,
           !messages.contains(where: { $0.id == createdMessage.id }) {
            return [createdMessage] + messages
        }

        return messages
    }

    private var readCount: Int {
        displayedMessages.filter { $0.isRead }.count
    }

    private var unreadVisibleCount: Int {
        displayedMessages.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        HStack(spacing: 10) {
                            metricCard(
                                title: "Messages",
                                value: "\(displayedMessages.count)",
                                systemImage: "text.bubble.fill"
                            )

                            metricCard(
                                title: "Unread",
                                value: "\(unreadVisibleCount)",
                                systemImage: "bell.badge.fill",
                                isWarning: unreadVisibleCount > 0
                            )
                        }

                        HStack(spacing: 10) {
                            metricCard(
                                title: "Read",
                                value: "\(readCount)",
                                systemImage: "checkmark.circle.fill"
                            )

                            metricCard(
                                title: "App unread",
                                value: "\(unreadCount)",
                                systemImage: "tray.full.fill",
                                isWarning: unreadCount > 0
                            )
                        }

                        futureActionsCard

                        if displayedMessages.isEmpty {
                            emptyCard
                        } else {
                            VStack(spacing: 12) {
                                ForEach(displayedMessages) { message in
                                    messageDetailCard(message)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Create message")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showCreateMessage) {
                CommandCreateMessageView { message in
                    createdMessage = message
                    showCreateMessage = false
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Message center overview")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))

            Text("Create and review command messages. Messages are saved through the shared backend and will appear in the app and website message center.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var futureActionsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "megaphone.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 5) {
                Text("Command messaging")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Chiefs and officers can create messages here. The backend enforces audience permissions.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tray")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            VStack(alignment: .leading, spacing: 5) {
                Text("No messages")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Department, station, training, uniform, and document updates will appear here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricCard(
        title: String,
        value: String,
        systemImage: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isWarning ? .red : AppTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func messageDetailCard(_ message: MobileMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: messageIcon(for: message))
                .font(.headline.weight(.semibold))
                .foregroundStyle(message.isRead ? AppTheme.gold : .red)
                .frame(width: 30, height: 30)
                .background((message.isRead ? AppTheme.gold : Color.red).opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(message.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !message.isRead {
                        Text("NEW")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(3)
                }

                Text(messageTypeLabel(for: message))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(message.isRead ? Color.white.opacity(0.10) : Color.red.opacity(0.42), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func messageIcon(for message: MobileMessage) -> String {
        let type = message.type.uppercased()

        if type.contains("TRAINING") {
            return "checklist.checked"
        }

        if type.contains("DOCUMENT") || type.contains("SOP") {
            return "doc.text.fill"
        }

        if type.contains("STATION") {
            return "building.2.fill"
        }

        if type.contains("ANNOUNCEMENT") || type.contains("DEPARTMENT") {
            return "megaphone.fill"
        }

        return "text.bubble.fill"
    }

    private func messageTypeLabel(for message: MobileMessage) -> String {
        message.type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private struct CommandCreateMessageView: View {
    @Environment(\.dismiss) private var dismiss

    let onCreated: (MobileMessage) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var audience = "OFFICERS"
    @State private var priority = "NORMAL"
    @State private var isSending = false
    @State private var errorMessage: String?

    private let audiences = [
        ("OFFICERS", "Officers"),
        ("ALL_MEMBERS", "All Members"),
        ("CHIEFS", "Chiefs")
    ]

    private let priorities = [
        ("NORMAL", "Normal"),
        ("HIGH", "High"),
        ("CRITICAL", "Critical")
    ]

    private var messageType: String {
        audience == "ALL_MEMBERS" ? "ANNOUNCEMENT" : "OFFICER_NOTE"
    }

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create Command Message")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Send a message through the shared MTFD message center. The backend will enforce role permissions.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.64))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Title")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.72))

                            TextField("Message title", text: $title)
                                .textInputAutocapitalization(.sentences)
                                .padding(12)
                                .background(.white.opacity(0.10))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Message")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.72))

                            TextEditor(text: $bodyText)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(.white.opacity(0.10))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Audience")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.72))

                            Picker("Audience", selection: $audience) {
                                ForEach(audiences, id: \.0) { value, label in
                                    Text(label).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Priority")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.72))

                            Picker("Priority", selection: $priority) {
                                ForEach(priorities, id: \.0) { value, label in
                                    Text(label).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            Task {
                                await sendMessage()
                            }
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(isSending ? "Sending..." : "Send Message")
                                    .font(.headline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSend ? AppTheme.gold : Color.white.opacity(0.16))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!canSend)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func sendMessage() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required."
            return
        }

        isSending = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.createCommandMessage(
                title: trimmedTitle,
                body: trimmedBody.isEmpty ? nil : trimmedBody,
                audience: audience,
                priority: priority,
                type: messageType,
                actionType: "NONE"
            )

            onCreated(response.message)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}
