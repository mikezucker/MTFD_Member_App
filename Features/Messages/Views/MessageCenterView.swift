import SwiftUI
import MapKit

struct MessageCenterView: View {
    enum Mode {
        case combined
        case dispatchesOnly
        case messagesOnly
    }

    let mode: Mode

    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = MessageCenterViewModel()

    @State private var selectedMessage: MobileMessage?
    @State private var selectedDispatch: DispatchNotificationPayload?
    @State private var highlightedDispatchId: String?
    @State private var selectedTab: MessageCenterTab
    @State private var selectedMessageFilter: DashboardMessageTypeFilter = .all
    @State private var showComposer = false

    init(mode: Mode = .combined) {
        self.mode = mode

        switch mode {
        case .combined, .dispatchesOnly:
            _selectedTab = State(initialValue: .dispatches)
        case .messagesOnly:
            _selectedTab = State(initialValue: .department)
        }
    }

    private enum MessageCenterTab: String, CaseIterable {
        case dispatches = "Dispatches"
        case department = "Dept Messages"
    }

    private let dispatchHistoryWindows: [(label: String, value: String)] = [
        ("24H", "24h"),
        ("72H", "72h"),
        ("7D", "7d")
    ]

    private var primaryActiveDispatch: APIClient.ActiveDispatch? {
        viewModel.activeDispatches.first
    }

    private var secondaryActiveDispatches: [APIClient.ActiveDispatch] {
        Array(viewModel.activeDispatches.dropFirst())
    }

    private var departmentMessages: [MobileMessage] {
        viewModel.messages
            .filter { message in
                selectedMessageFilter.includes(message)
            }
            .sorted { lhs, rhs in
                if (lhs.isPinned ?? false) != (rhs.isPinned ?? false) {
                    return lhs.isPinned == true
                }

                if messagePriorityRank(lhs.priority) != messagePriorityRank(rhs.priority) {
                    return messagePriorityRank(lhs.priority) < messagePriorityRank(rhs.priority)
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    private func canDeleteMessage(_ message: MobileMessage) -> Bool {
        message.canDelete == true || viewModel.manageableMessages.contains(where: { $0.id == message.id })
    }

    private var unreadDepartmentMessageCount: Int {
        departmentMessages.filter { !$0.isRead }.count
    }

    private var dispatchBadgeCount: Int {
        viewModel.unreadDispatchCount
    }

    private var screenTitle: String {
        switch mode {
        case .combined:
            return "Message Center"
        case .dispatchesOnly:
            return "Latest Dispatches"
        case .messagesOnly:
            return "Messages"
        }
    }

    private var introText: String {
        switch mode {
        case .combined:
            return "Dispatches, training reminders, uniform updates, and department messages."
        case .dispatchesOnly:
            return "Recent dispatch history and active incidents."
        case .messagesOnly:
            return "Training reminders, uniform updates, and department messages."
        }
    }

    private var introUnreadCount: Int {
        switch mode {
        case .combined:
            return viewModel.unreadCount
        case .dispatchesOnly:
            return dispatchBadgeCount
        case .messagesOnly:
            return unreadDepartmentMessageCount
        }
    }

    private var canCreateMessages: Bool {
        guard let user = sessionManager.currentUser else { return false }

        return user.canPostStationMessages
            || user.canManageUsers
            || user.role == "ADMIN"
            || user.role == "CHIEF"
            || user.role == "BATTALION_CHIEF"
            || user.role == "OFFICER_CAREER"
            || user.isFireHeadquarters
    }

    var body: some View {
        AppScreen(
            title: screenTitle,
            subtitle: introText,
            systemImage: mode == .dispatchesOnly ? "bell.and.waves.left.and.right.fill" : "envelope.fill"
        ) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if mode == .combined {
                        tabSelector
                    }

                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage,
                              viewModel.messages.isEmpty,
                              viewModel.activeDispatches.isEmpty,
                              viewModel.historicalDispatches.isEmpty {
                        errorView(errorMessage)
                    } else {
                        switch selectedTab {
                        case .dispatches:
                            dispatchesContent

                        case .department:
                            departmentMessagesSection
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 120)
            }
        }
        .task {
            await viewModel.loadMessagesIfNeeded()
        }
        .task {
            await activeDispatchRefreshLoop()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .toolbar {
            if canCreateMessages {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Create message")
                }
            }
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailSheet(message: message)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showComposer) {
            MessageComposeView { title, body, audience, priority, type, stationNumberTarget, isPinned in
                try await viewModel.createMessage(
                    title: title,
                    body: body,
                    audience: audience,
                    priority: priority,
                    type: type,
                    stationNumberTarget: stationNumberTarget,
                    isPinned: isPinned
                )

                selectedTab = .department
            }
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
    }

    private var introHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(introText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if introUnreadCount > 0 {
                Text("\(introUnreadCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(introUnreadCount) unread")
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 2)
    }

    private var tabSelector: some View {
        HStack(spacing: 10) {
            MessageCenterTabButton(
                title: "Dispatches",
                systemImage: "bell.and.waves.left.and.right.fill",
                badgeCount: dispatchBadgeCount,
                isSelected: selectedTab == .dispatches,
                tint: .red
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    selectedTab = .dispatches
                }
            }

            MessageCenterTabButton(
                title: "Dept Messages",
                systemImage: "tray.full.fill",
                badgeCount: unreadDepartmentMessageCount,
                isSelected: selectedTab == .department,
                tint: AppTheme.gold
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    selectedTab = .department
                }
            }
        }
    }

    @ViewBuilder
    private var dispatchesContent: some View {
        activeDispatchContent
        recentDispatchHistorySection
    }

    @ViewBuilder
    private var activeDispatchContent: some View {
        if let primaryActiveDispatch {
            MessageSectionTitle(
                title: "Current Dispatch",
                subtitle: "Most recent active call.",
                systemImage: "bell.and.waves.left.and.right.fill",
                tint: .red
            )

            MessageCurrentDispatchCard(
                dispatch: makeDispatchPayload(from: primaryActiveDispatch),
                isHighlighted: highlightedDispatchId == primaryActiveDispatch.id,
                isRead: viewModel.isDispatchRead(id: primaryActiveDispatch.id)
            ) {
                let dispatch = makeDispatchPayload(from: primaryActiveDispatch)

                highlightedDispatchId = dispatch.id
                viewModel.markDispatchRead(id: dispatch.id)
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedDispatch = dispatch
                }
            }
        }

        if !secondaryActiveDispatches.isEmpty {
            ActiveDispatchStackView(dispatches: secondaryActiveDispatches) { activeDispatch in
                let dispatch = makeDispatchPayload(from: activeDispatch)

                highlightedDispatchId = dispatch.id
                viewModel.markDispatchRead(id: dispatch.id)

                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedDispatch = dispatch
                }
            }
        }
    }

    private var recentDispatchHistorySection: some View {
        MessageSectionContainer(
            title: "Recent Dispatch History",
            subtitle: "Recent calls for your selected history window.",
            systemImage: "clock.arrow.circlepath"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(dispatchHistoryWindows, id: \.value) { option in
                        Button {
                            Task {
                                await viewModel.changeDispatchWindow(to: option.value)
                            }
                        } label: {
                            Text(option.label)
                                .font(.caption.bold())
                                .foregroundStyle(
                                    viewModel.selectedDispatchWindow == option.value
                                    ? AppTheme.navy
                                    : .white.opacity(0.82)
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(
                                            viewModel.selectedDispatchWindow == option.value
                                            ? AppTheme.gold
                                            : Color.white.opacity(0.12)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if viewModel.isLoadingDispatchHistory {
                        ProgressView()
                            .scaleEffect(0.75)
                    }
                }

                if viewModel.historicalDispatches.isEmpty {
                    EmptySectionRow(
                        systemImage: "clock",
                        title: "No recent dispatches",
                        subtitle: "Dispatch history for this time window will appear here."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.historicalDispatches.prefix(25))) { dispatch in
                            Button {
                                let payload = makeDispatchPayload(from: dispatch)

                                highlightedDispatchId = payload.id

                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedDispatch = payload
                                }
                            } label: {
                                DispatchHistoryRow(
                                    dispatch: dispatch,
                                    isRead: viewModel.isDispatchRead(id: dispatch.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var departmentMessagesSection: some View {
        MessageSectionContainer(
            title: canCreateMessages ? "Current Message Queue" : "Department Messages",
            subtitle: canCreateMessages
                ? "Active messages visible in the app and station displays."
                : "Training, uniforms, documents, and announcements.",
            systemImage: "tray.full.fill"
        ) {
            messageTypeFilterBar

            if departmentMessages.isEmpty {
                EmptySectionRow(
                    systemImage: "tray",
                    title: selectedMessageFilter == .all
                        ? (canCreateMessages ? "No active messages" : "No department messages")
                        : "No \(selectedMessageFilter.rawValue.lowercased()) messages",
                    subtitle: canCreateMessages
                        ? "Create a message to add it to the current queue."
                        : "Training, uniform, and department updates will appear here."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(departmentMessages) { message in
                        HStack(spacing: 10) {
                            Button {
                                selectedMessage = message

                                Task {
                                    await viewModel.markRead(message)
                                }
                            } label: {
                                DepartmentMessageRow(message: message)
                            }
                            .buttonStyle(.plain)

                            if canDeleteMessage(message) {
                                Button {
                                    Task {
                                        await viewModel.deleteMessage(message)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.red)
                                        .frame(width: 42, height: 42)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete message")
                            }
                        }
                        .contextMenu {
                            if canDeleteMessage(message) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteMessage(message)
                                    }
                                } label: {
                                    Label("Delete Message", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var messageTypeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardMessageTypeFilter.allCases) { filter in
                    Button {
                        selectedMessageFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedMessageFilter == filter ? Color.black : Color.white.opacity(0.78))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedMessageFilter == filter ? AppTheme.gold : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text("Loading messages...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Unable to load messages")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func activeDispatchRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 15_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            await viewModel.refreshActiveDispatches()
        }
    }

    private func makeDispatchPayload(
        from activeDispatch: APIClient.ActiveDispatch,
        activeCallCount: Int = 1
    ) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: activeDispatch.address,
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

    private func makeDispatchPayload(from dispatch: APIClient.DispatchHistoryItem) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: dispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: dispatch.id,
            title: dispatch.callType,
            body: dispatch.message ?? dispatch.address,
            callType: dispatch.callType,
            address: dispatch.address,
            units: DispatchUnitFilter.visibleRespondingUnits(from: dispatch.units),
            isWorkingFire: dispatch.isWorkingFire ?? false,
            activeCallCount: 1,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }

    private func messagePriorityRank(_ priority: String) -> Int {
        switch priority.uppercased() {
        case "CRITICAL": return 0
        case "HIGH": return 1
        case "IMPORTANT", "NORMAL": return 2
        case "INFO", "INFORMATION", "LOW": return 3
        default: return 4
        }
    }
}

// MARK: - Compose

private struct MessageComposeView: View {
    @Environment(\.dismiss) private var dismiss

    let onSend: (
        _ title: String,
        _ body: String,
        _ audience: String,
        _ priority: String,
        _ type: String,
        _ stationNumberTarget: Int?,
        _ isPinned: Bool
    ) async throws -> Void

    @State private var title = ""
    @State private var messageBody = ""
    @State private var audience = "ALL_MEMBERS"
    @State private var targetStation = false
    @State private var priority = "NORMAL"
    @State private var type = "ANNOUNCEMENT"
    @State private var stationText = ""
    @State private var isPinned = false
    @State private var isSending = false
    @State private var errorMessage: String?

    private let audiences: [(label: String, value: String)] = [
        ("Department", "ALL_MEMBERS"),
        ("Officers", "ALL_OFFICERS"),
        ("Chiefs", "CHIEFS"),
        ("Career", "CAREER_MEMBERS"),
        ("Volunteers", "VOLUNTEER_MEMBERS")
    ]

    private let priorities: [(label: String, value: String)] = [
        ("Information", "LOW"),
        ("Important", "NORMAL"),
        ("High Priority", "HIGH"),
        ("Critical", "CRITICAL")
    ]

    private let messageTypes: [(label: String, value: String)] = [
        ("Announcement", "ANNOUNCEMENT"),
        ("Staffing", "STAFFING"),
        ("Event", "EVENT"),
        ("Officer Note", "OFFICER_NOTE")
    ]

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stationNumber: Int? {
        Int(stationText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSend: Bool {
        !trimmedTitle.isEmpty
            && !trimmedBody.isEmpty
            && !isSending
            && (!targetStation || stationNumber != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Body", text: $messageBody, axis: .vertical)
                        .lineLimit(4...8)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Delivery") {
                    Picker("Audience", selection: $audience) {
                        ForEach(audiences, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    Toggle("Target a station", isOn: $targetStation)

                    if targetStation {
                        TextField("Station number", text: $stationText)
                            .keyboardType(.numberPad)
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    Toggle("Pin Message", isOn: $isPinned)

                    Picker("Type", selection: $type) {
                        ForEach(messageTypes, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSending)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending" : "Send") {
                        Task {
                            await send()
                        }
                    }
                    .disabled(!canSend)
                }
            }
        }
    }

    private func send() async {
        guard canSend else { return }

        isSending = true
        errorMessage = nil

        do {
            try await onSend(
                trimmedTitle,
                trimmedBody,
                audience,
                priority,
                type,
                targetStation ? stationNumber : nil,
                isPinned
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

// MARK: - Tab Button

private struct MessageCenterTabButton: View {
    let title: String
    let systemImage: String
    let badgeCount: Int
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))

                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(badgeCount) new")
    }
}

// MARK: - Section Title

private struct MessageSectionTitle: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }
}

// MARK: - Generic Section Container

private struct MessageSectionContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MessageSectionTitle(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: AppTheme.gold
            )

            content
        }
    }
}

// MARK: - Current Dispatch Card

private struct MessageCurrentDispatchCard: View {
    let dispatch: DispatchNotificationPayload
    let isHighlighted: Bool
    let isRead: Bool
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
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isRead ? .white.opacity(0.55) : .red)

                        if !isRead {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 9, height: 9)
                                .offset(x: 6, y: -5)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(callType)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)

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

                MessageDispatchMapPreview(address: address)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isRead ? 0.09 : (isHighlighted ? 0.20 : 0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isRead ? Color.white.opacity(0.08) : Color.red.opacity(0.85), lineWidth: isRead ? 1 : 2)
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

// MARK: - Dispatch History Row

private struct DispatchHistoryRow: View {
    let dispatch: APIClient.DispatchHistoryItem
    let isRead: Bool

    private var iconName: String {
        let type = dispatch.callType.lowercased()

        if type.contains("ems") ||
            type.contains("medical") ||
            type.contains("sick") ||
            type.contains("hemorrhage") ||
            type.contains("laceration") {
            return "cross.case.fill"
        }

        if type.contains("fire") ||
            type.contains("alarm") ||
            dispatch.isWorkingFire == true {
            return "flame.fill"
        }

        if type.contains("mva") ||
            type.contains("motor vehicle") ||
            type.contains("accident") {
            return "car.fill"
        }

        return "bell.fill"
    }

    private var displayLocation: String {
        if let placeName = dispatch.placeName, !placeName.isEmpty {
            return placeName
        }

        if let address = dispatch.address, !address.isEmpty {
            return address
        }

        return "Unknown location"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 46, height: 46)

                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isRead ? .white.opacity(0.55) : (dispatch.isWorkingFire == true ? .red : AppTheme.gold))

                    if !isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 5, y: -5)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(dispatch.callType)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if dispatch.isWorkingFire == true {
                        Text("Critical")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(displayLocation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)

                if !dispatch.units.isEmpty {
                    Text(dispatch.units.joined(separator: ", "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.gold.opacity(0.9))
                        .lineLimit(1)
                }

                if let dispatchedAt = dispatch.dispatchedAt {
                    Text(dispatchedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isRead ? 0.08 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isRead ? Color.white.opacity(0.08) : Color.red.opacity(0.30), lineWidth: 1)
            )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Message Rows

private struct DepartmentMessageRow: View {
    let message: MobileMessage

    private var priorityLabel: String? {
        switch message.priority {
        case "CRITICAL":
            return "Critical"
        case "HIGH":
            return "High"
        default:
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 46, height: 46)

                Text(message.displayIcon)
                    .font(.system(size: 22))
                    .saturation(message.isRead ? 0.45 : 1.0)

                if !message.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(message.title)
                        .font(.subheadline.weight(message.isRead ? .semibold : .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let priorityLabel {
                        Text(priorityLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(message.typeDisplayLabel)
                    Text("•")
                    Text(message.audienceDisplayLabel)

                    if message.isPinned == true {
                        Text("• Pinned")
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.gold.opacity(0.9))
                .lineLimit(1)

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))

                    if let expiresAt = message.expiresAt {
                        Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(message.isRead ? 0.10 : 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(message.isRead ? Color.clear : AppTheme.gold.opacity(0.25), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptySectionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Map Preview

private struct MessageDispatchMapPreview: View {
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

// MARK: - Detail Sheet

private struct MessageDetailSheet: View {
    let message: MobileMessage

    private var linkURL: URL? {
        APIClient.shared.absoluteURL(from: message.linkUrl)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(message.displayIcon)
                            .font(.system(size: 34))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.title)
                                .font(.title3.bold())

                            Text("\(message.typeDisplayLabel) • \(message.audienceDisplayLabel)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let body = message.body, !body.isEmpty {
                        Text(body)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    } else {
                        Text("No additional message details were provided.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority: \(message.priority.capitalized)")
                        Text("Read: \(message.isRead ? "Yes" : "No")")

                        if let createdByName = message.createdByName, !createdByName.isEmpty {
                            Text("From: \(createdByName)")
                        } else if let createdByRole = message.createdByRole, !createdByRole.isEmpty {
                            Text("From: \(createdByRole.replacingOccurrences(of: "_", with: " ").capitalized)")
                        }

                        if let expiresAt = message.expiresAt {
                            Text("Expires: \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let linkURL {
                        Link(destination: linkURL) {
                            HStack {
                                Text(message.linkLabel ?? (message.type == "POLICY_LINK" ? "View Policy" : "Open Link"))
                                    .font(.headline.weight(.semibold))

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.caption.bold())
                            }
                            .padding()
                            .foregroundStyle(.white)
                            .background(AppTheme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
