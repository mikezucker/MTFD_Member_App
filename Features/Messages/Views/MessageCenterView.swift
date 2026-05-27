import SwiftUI
import MapKit

struct MessageCenterView: View {
    @StateObject private var viewModel = MessageCenterViewModel()

    @State private var selectedMessage: MobileMessage?
    @State private var selectedDispatch: DispatchNotificationPayload?
    @State private var highlightedDispatchId: String?
    @State private var selectedTab: MessageCenterTab = .dispatches

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
        viewModel.messages.filter { message in
            message.type != "DISPATCH" &&
            message.type != "DISPATCH_UPDATE" &&
            message.dispatchId == nil
        }
    }

    private var unreadDepartmentMessageCount: Int {
        departmentMessages.filter { !$0.isRead }.count
    }

    private var dispatchBadgeCount: Int {
        viewModel.unreadDispatchCount
    }

    var body: some View {
        AppScreen(title: "Message Center") {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    introHeader
                    tabSelector

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
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailSheet(message: message)
                .presentationDetents([.medium, .large])
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
            Text("Dispatches, training reminders, uniform updates, and department messages.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if viewModel.unreadCount > 0 {
                Text("\(viewModel.unreadCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(viewModel.unreadCount) unread messages")
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
            title: "Department Messages",
            subtitle: "Training, uniforms, documents, and announcements.",
            systemImage: "tray.full.fill"
        ) {
            if departmentMessages.isEmpty {
                EmptySectionRow(
                    systemImage: "tray",
                    title: "No department messages",
                    subtitle: "Training, uniform, and department updates will appear here."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(departmentMessages) { message in
                        Button {
                            selectedMessage = message

                            Task {
                                await viewModel.markRead(message)
                            }
                        } label: {
                            DepartmentMessageRow(message: message)
                        }
                        .buttonStyle(.plain)
                    }
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

    private func makeDispatchPayload(from activeDispatch: APIClient.ActiveDispatch) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: activeDispatch.address,
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

    private func makeDispatchPayload(from dispatch: APIClient.DispatchHistoryItem) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: dispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: dispatch.id,
            title: dispatch.callType,
            body: dispatch.message ?? dispatch.address,
            callType: dispatch.callType,
            address: dispatch.address,
            units: dispatch.units,
            isWorkingFire: dispatch.isWorkingFire ?? false,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
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

    private var iconName: String {
        switch message.type {
        case "TRAINING_REMINDER", "TRAINING", "TRAINING_ASSIGNMENT":
            return "graduationcap.fill"
        case "UNIFORM", "UNIFORM_REQUEST", "UNIFORM_REQUEST_UPDATE":
            return "tshirt.fill"
        case "DOCUMENT", "DOCUMENT_SIGNATURE":
            return "doc.text.fill"
        case "ANNOUNCEMENT":
            return "megaphone.fill"
        case "OFFICER_NOTE":
            return "person.badge.shield.checkmark.fill"
        default:
            return "envelope.fill"
        }
    }

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

                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(message.isRead ? .white.opacity(0.55) : AppTheme.gold)

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

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }

                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
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

// MARK: - Detail Sheet

private struct MessageDetailSheet: View {
    let message: MobileMessage

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.title)
                            .font(.title3.bold())

                        Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                }
                .padding(20)
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
