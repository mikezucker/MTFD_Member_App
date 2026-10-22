//
//  ContentView.swift
//  MTFD Watch App Watch App
//

import SwiftUI
import Combine
import WatchKit
import WatchConnectivity
import UserNotifications

struct WatchDispatch: Identifiable, Codable {
    let id: String
    let callType: String
    let address: String
    let units: [String]
    let isCritical: Bool
    let isWorkingFire: Bool
    let updatedAt: Date
}

private struct WatchDispatchFeedResponse: Decodable {
    let activeDispatches: [WatchActiveDispatch]
    let historicalDispatches: [WatchActiveDispatch]?
}

private struct WatchSnapshotResponse: Decodable {
    let success: Bool?
    let fetchedAt: Date?
    let message: String?
    let dispatches: WatchSnapshotDispatches?
    let schedule: WatchScheduleResponse?
    let workOrders: WatchWorkOrdersResponse?
    let callTotals: WatchCallTotalsResponse?
}

private struct WatchSnapshotDispatches: Decodable {
    let activeDispatches: [WatchActiveDispatch]
    let historicalDispatches: [WatchActiveDispatch]?
}

private struct WatchActiveDispatch: Decodable {
    let id: String
    let callType: String
    let message: String?
    let address: String?
    let city: String?
    let state: String?
    let units: [String]
    let priority: String?
    let isWorkingFire: Bool?
    let dispatchedAt: Date?
    let lastActivityAt: Date?
}

private struct WatchScheduleEntry: Identifiable, Codable {
    let id: String
    let title: String
    let station: String?
    let timeRange: String?
    let staffing: [String]
    let staffingDetails: [WatchScheduleStaffingDetail]?
}

private struct WatchScheduleStaffingDetail: Codable {
    let name: String?
    let qualifier: String?
    let isVacant: Bool?
}

private struct WatchScheduleResponse: Decodable {
    let ok: Bool?
    let message: String?
    let date: String?
    let entries: [WatchScheduleEntry]
}

private struct WatchWorkOrder: Identifiable, Codable {
    let id: String
    let apparatusApiId: String?
    let apparatusName: String
    let title: String
    let status: String?
}

private struct WatchWorkOrdersResponse: Decodable {
    let ok: Bool?
    let message: String?
    let items: [WatchWorkOrder]
}

private struct WatchCallTotalsResponse: Codable {
    let ok: Bool?
    let message: String?
    let sourceLabel: String?
    let lastUpdated: String?
    let department: WatchDispatchBucket?
}

private struct WatchDispatchBucket: Codable {
    let total24h: Int?
    let total7d: Int?
    let total30d: Int?
    let totalYtd: Int?
    let fire24h: Int?
    let fire7d: Int?
    let fire30d: Int?
    let fireYtd: Int?
    let ems24h: Int?
    let ems7d: Int?
    let ems30d: Int?
    let emsYtd: Int?
    let other24h: Int?
    let other7d: Int?
    let other30d: Int?
    let otherYtd: Int?
}

@MainActor
private final class WatchDispatchViewModel: ObservableObject {
    @Published var activeDispatches: [WatchDispatch] = []
    @Published var recentDispatches: [WatchDispatch] = []
    @Published var scheduleEntries: [WatchScheduleEntry] = []
    @Published var workOrders: [WatchWorkOrder] = []
    @Published var callTotals: WatchDispatchBucket?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadedAt: Date?

    private let feedURL = URL(string: "https://new-mtfd-site.vercel.app/api/shared/watch-snapshot")!
    private let cacheKey = "watch_active_dispatch_cache_v1"

    init() {
        loadCachedDispatches()
    }

    func loadDispatches() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: feedURL)

            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard 200...299 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }

            let decoded = try Self.decoder.decode(WatchSnapshotResponse.self, from: data)
            let dispatches = decoded.dispatches
            let active = (dispatches?.activeDispatches ?? []).map(Self.mapDispatch)
            let activeIds = Set(active.map(\.id))
            let recent = (dispatches?.historicalDispatches ?? [])
                .map(Self.mapDispatch)
                .filter { !activeIds.contains($0.id) }

            activeDispatches = active
            recentDispatches = Array(recent.prefix(20))
            scheduleEntries = Array((decoded.schedule?.entries ?? []).prefix(20))
            workOrders = Array((decoded.workOrders?.items ?? []).prefix(30))
            callTotals = decoded.callTotals?.department
            lastLoadedAt = decoded.fetchedAt ?? Date()
            cacheDispatches()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadCachedDispatches() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }

        do {
            let cached = try JSONDecoder().decode(WatchDispatchCache.self, from: data)
            activeDispatches = cached.activeDispatches ?? cached.dispatches ?? []
            recentDispatches = cached.recentDispatches ?? []
            scheduleEntries = cached.scheduleEntries ?? []
            workOrders = cached.workOrders ?? []
            callTotals = cached.callTotals
            lastLoadedAt = cached.lastLoadedAt
        } catch {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }

    private func cacheDispatches() {
        do {
            let data = try JSONEncoder().encode(
                WatchDispatchCache(
                    dispatches: nil,
                    activeDispatches: activeDispatches,
                    recentDispatches: recentDispatches,
                    scheduleEntries: scheduleEntries,
                    workOrders: workOrders,
                    callTotals: callTotals,
                    lastLoadedAt: lastLoadedAt
                )
            )
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            // Cache failures should not block the watch feed.
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let withMilliseconds = ISO8601DateFormatter()
            withMilliseconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = withMilliseconds.date(from: value) {
                return date
            }

            let withoutMilliseconds = ISO8601DateFormatter()
            withoutMilliseconds.formatOptions = [.withInternetDateTime]

            if let date = withoutMilliseconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()

    private static func mapDispatch(_ dispatch: WatchActiveDispatch) -> WatchDispatch {
        WatchDispatch(
            id: dispatch.id,
            callType: displayCallType(callType: dispatch.callType, message: dispatch.message, isWorkingFire: dispatch.isWorkingFire),
            address: formattedAddress(address: dispatch.address, city: dispatch.city, state: dispatch.state),
            units: visibleRespondingUnits(dispatch.units),
            isCritical: dispatch.priority == "CRITICAL" || dispatch.isWorkingFire == true,
            isWorkingFire: dispatch.isWorkingFire == true,
            updatedAt: dispatch.lastActivityAt ?? dispatch.dispatchedAt ?? Date()
        )
    }

    private static func formattedAddress(address: String?, city: String?, state: String?) -> String {
        let parts = [address, city, state]
            .compactMap { value -> String? in
                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    return nil
                }
                return value
            }

        return parts.isEmpty ? "Address unavailable" : parts.joined(separator: ", ")
    }

    private static func visibleRespondingUnits(_ units: [String]) -> [String] {
        var seen = Set<String>()

        return units.filter { unit in
            let normalized = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return false }

            let blockedUnits = [
                "hq",
                "oem",
                "station",
                "station 1",
                "station 2",
                "station 3",
                "station 4",
                "station 5",
                "f22man1",
                "f22man2",
                "f22man3",
                "f22man4",
                "f22man5"
            ]

            guard !blockedUnits.contains(normalized), !normalized.hasPrefix("station ") else {
                return false
            }

            guard !seen.contains(normalized) else {
                return false
            }

            seen.insert(normalized)
            return true
        }
    }

    private static func displayCallType(callType: String, message: String?, isWorkingFire: Bool?) -> String {
        if isWorkingFire == true {
            return "Working Fire"
        }

        let combined = "\(callType) \(message ?? "")".lowercased()

        if combined.contains("cardiac") {
            return "Cardiac Arrest"
        }

        if combined.contains("ems") || combined.contains("medical") || combined.contains("difficulty breathing") {
            return "EMS Dispatch"
        }

        if combined.contains("mva") || combined.contains("motor vehicle") || combined.contains("accident") || combined.contains("crash") {
            return "Motor Vehicle Accident"
        }

        if combined.contains("alarm") {
            return "Fire Alarm"
        }

        if combined.contains("structure") || combined.contains("building fire") {
            return "Structure Fire"
        }

        if combined.contains("gas") || combined.contains("odor") || combined.contains("hazmat") {
            return "Hazardous Condition"
        }

        return callType
    }
}

private struct WatchDispatchCache: Codable {
    let dispatches: [WatchDispatch]?
    let activeDispatches: [WatchDispatch]?
    let recentDispatches: [WatchDispatch]?
    let scheduleEntries: [WatchScheduleEntry]?
    let workOrders: [WatchWorkOrder]?
    let callTotals: WatchDispatchBucket?
    let lastLoadedAt: Date?
}

private extension WatchDispatch {
    var commandCallType: String {
        let uppercased = callType.uppercased()

        if uppercased.contains("EMS") || uppercased.contains("MEDICAL") || uppercased.contains("CARDIAC") {
            return "EMS"
        }

        if uppercased.contains("MOTOR") || uppercased.contains("MVA") || uppercased.contains("ACCIDENT") {
            return "MVA"
        }

        if uppercased.contains("ALARM") {
            return "ALARM"
        }

        if uppercased.contains("FIRE") {
            return "FIRE"
        }

        if uppercased.contains("HAZ") || uppercased.contains("GAS") {
            return "HAZMAT"
        }

        return uppercased
    }

    var commandProblem: String {
        let trimmed = callType.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Dispatch details" : trimmed
    }

    var canNavigate: Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedAddress.isEmpty && trimmedAddress != "Address unavailable"
    }

    var isRecentlyUpdated: Bool {
        Date().timeIntervalSince(updatedAt) < 120
    }

    var commandStatus: String {
        isRecentlyUpdated ? "UPDATED" : "ACTIVE"
    }

    var commandAccentColor: Color {
        if isRecentlyUpdated {
            return AppTheme.pending
        }

        return isCritical ? AppTheme.danger : AppTheme.pending
    }
}

private enum WatchNavigationAction {
    static func open(_ dispatch: WatchDispatch) {
        guard dispatch.canNavigate,
              let encodedAddress = dispatch.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)&dirflg=d") else {
            return
        }

        WatchPhoneNavigationBridge.shared.sendNavigateToCall(address: dispatch.address)
        WKApplication.shared().openSystemURL(url)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = WatchDispatchViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.activeDispatches.isEmpty && viewModel.lastLoadedAt == nil {
                    WatchLoadingCommandView()
                } else if viewModel.activeDispatches.isEmpty {
                    WatchClearStatusView(
                        viewModel: viewModel,
                        lastDispatch: viewModel.recentDispatches.first,
                        lastLoadedAt: viewModel.lastLoadedAt,
                        errorMessage: viewModel.errorMessage
                    ) {
                        Task {
                            await viewModel.loadDispatches()
                        }
                    }
                } else if viewModel.activeDispatches.count == 1, let dispatch = viewModel.activeDispatches.first {
                    WatchActiveDispatchSurface(
                        dispatch: dispatch,
                        status: dispatch.commandStatus,
                        reduceMotion: reduceMotion,
                        viewModel: viewModel
                    )
                } else {
                    WatchMultipleDispatchCardsView(
                        dispatches: viewModel.activeDispatches,
                        reduceMotion: reduceMotion,
                        lastLoadedAt: viewModel.lastLoadedAt,
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle("")
            .task {
                _ = WatchPhoneNavigationBridge.shared
                await viewModel.loadDispatches()
            }
        }
    }

    private var activeDispatchCountText: String {
        let count = viewModel.activeDispatches.count
        return count == 1 ? "1 active dispatch" : "\(count) active dispatches"
    }

    private var recentDispatchCountText: String {
        let count = viewModel.recentDispatches.count
        return count == 1 ? "1 recent dispatch" : "\(count) recent dispatches"
    }

    private var scheduleCountText: String {
        let count = viewModel.scheduleEntries.count
        return count == 1 ? "1 schedule item" : "\(count) schedule items"
    }

    private var workOrderCountText: String {
        let count = viewModel.workOrders.count
        return count == 1 ? "1 open item" : "\(count) open items"
    }

    private var callTotalsSummaryText: String {
        guard let total = viewModel.callTotals?.totalYtd else {
            return "Loading totals"
        }

        return "\(total) YTD calls"
    }
}

private struct WatchCommandMenuView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        WatchCommandScroll(stationName: "") {
            NavigationLink {
                WatchActiveCallsView(viewModel: viewModel)
            } label: {
                WatchCommandMenuRow(
                    title: "Active Calls",
                    subtitle: viewModel.activeDispatches.isEmpty
                        ? "All clear"
                        : "\(viewModel.activeDispatches.count) active calls",
                    systemImage: "flame.fill",
                    color: viewModel.activeDispatches.isEmpty ? AppTheme.approved : AppTheme.pending
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchRecentCallsView(viewModel: viewModel)
            } label: {
                WatchCommandMenuRow(
                    title: "Past Calls",
                    subtitle: recentDispatchCountText,
                    systemImage: "clock.arrow.circlepath",
                    color: AppTheme.gold
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchCallTotalsView(
                    totals: viewModel.callTotals,
                    lastLoadedAt: viewModel.lastLoadedAt
                )
            } label: {
                WatchCommandMenuRow(
                    title: "Call Totals",
                    subtitle: callTotalsSummaryText,
                    systemImage: "chart.bar.fill",
                    color: AppTheme.commandBlue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchScheduleView(viewModel: viewModel)
            } label: {
                WatchCommandMenuRow(
                    title: "Schedule",
                    subtitle: scheduleCountText,
                    systemImage: "calendar",
                    color: AppTheme.gold
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchWorkOrdersView(viewModel: viewModel)
            } label: {
                WatchCommandMenuRow(
                    title: "Work Orders",
                    subtitle: workOrderCountText,
                    systemImage: "wrench.and.screwdriver.fill",
                    color: AppTheme.gold
                )
            }
            .buttonStyle(.plain)

            if let lastLoadedAt = viewModel.lastLoadedAt {
                Text("Updated \(lastLoadedAt, style: .relative) ago")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .navigationTitle("")
    }

    private var recentDispatchCountText: String {
        let count = viewModel.recentDispatches.count
        return count == 1 ? "1 recent dispatch" : "\(count) recent dispatches"
    }

    private var scheduleCountText: String {
        let count = viewModel.scheduleEntries.count
        return count == 1 ? "1 schedule item" : "\(count) schedule items"
    }

    private var workOrderCountText: String {
        let count = viewModel.workOrders.count
        return count == 1 ? "1 open item" : "\(count) open items"
    }

    private var callTotalsSummaryText: String {
        guard let total = viewModel.callTotals?.totalYtd else {
            return "Loading totals"
        }

        return "\(total) YTD calls"
    }
}

private struct WatchCommandMenuRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        WatchGlassPanel {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.16), in: Circle())
                    .overlay {
                        Circle().stroke(color.opacity(0.32), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .default).weight(.bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct WatchMTFDCommandBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.navyHighlight,
                    AppTheme.navy,
                    AppTheme.navyDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Image("MTFDWatchLogo")
                .resizable()
                .scaledToFit()
                .opacity(0.08)
                .frame(width: 205, height: 205)
                .offset(x: 62, y: 68)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            content
                .foregroundStyle(.white)
        }
    }
}

private struct WatchBrandHeader: View {
    let stationName: String

    var body: some View {
        HStack(spacing: 8) {
            Image("MTFDWatchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: stationName.isEmpty ? 52 : 42, height: stationName.isEmpty ? 52 : 42)
                .clipShape(Circle())

            if !stationName.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text(stationName)
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WatchLoadingCommandView: View {
    var body: some View {
        WatchMTFDCommandBackground {
            VStack(spacing: 12) {
                WatchBrandHeader(stationName: "Member Watch")

                Spacer()

                ProgressView()
                    .tint(AppTheme.gold)

                Text("SYNCING")
                    .font(.system(.title3, design: .default).weight(.bold))

                Text("Checking active dispatches")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()
            }
            .padding(12)
        }
    }
}

private struct WatchClearStatusView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel
    let lastDispatch: WatchDispatch?
    let lastLoadedAt: Date?
    let errorMessage: String?
    let refresh: () -> Void

    var body: some View {
        WatchMTFDCommandBackground {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        WatchBrandHeader(stationName: "Station 22")

                        NavigationLink {
                            WatchCommandMenuView(viewModel: viewModel)
                        } label: {
                            Image(systemName: "square.grid.2x2.fill")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .accessibilityLabel("App Menu")
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 9) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.approved.opacity(0.16))
                                .frame(width: 78, height: 78)

                            Circle()
                                .stroke(AppTheme.approved.opacity(0.85), lineWidth: 2)
                                .frame(width: 78, height: 78)

                            Image(systemName: "checkmark")
                                .font(.system(size: 31, weight: .bold, design: .default))
                        }

                        Text("ALL\nCLEAR")
                            .font(.system(size: 27, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text("Dispatch channel quiet")
                            .font(.system(.caption2, design: .default).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        if let lastDispatch {
                            Text("LAST DISPATCH")
                                .font(.system(size: 8, weight: .bold, design: .default))
                                .foregroundStyle(AppTheme.gold)

                            Text("\(lastDispatch.callType) • \(lastDispatch.address)")
                                .font(.system(.caption2, design: .default).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(2)
                        } else {
                            Text(lastLoadedAt == nil ? "No dispatch snapshot yet" : "No recent dispatches")
                                .font(.system(.caption2, design: .default).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        if let lastLoadedAt {
                            Text("Updated \(lastLoadedAt, style: .relative) ago")
                                .font(.system(size: 9, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 9, weight: .medium, design: .default))
                                .foregroundStyle(AppTheme.pending)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }

                    Button(action: refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(.caption, design: .default).weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.gold)
                    .padding(.top, 7)
                }
                .padding(12)
            }
        }
    }
}

private struct WatchActiveDispatchSurface: View {
    let dispatch: WatchDispatch
    let status: String
    let reduceMotion: Bool
    @ObservedObject var viewModel: WatchDispatchViewModel

    private var accentColor: Color {
        dispatch.commandAccentColor
    }

    var body: some View {
        WatchMTFDCommandBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        WatchDispatchStatusPill(text: status, color: accentColor)

                        Spacer(minLength: 6)

                        Text(dispatch.updatedAt, style: .relative)
                            .font(.system(.caption, design: .default).weight(.bold))
                            .foregroundStyle(AppTheme.gold)
                            .lineLimit(1)

                        NavigationLink {
                            WatchCommandMenuView(viewModel: viewModel)
                        } label: {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }

                    Text(dispatch.commandCallType)
                        .font(.system(size: 37, weight: .bold, design: .default))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .padding(.top, 9)

                    Text(dispatch.commandProblem)
                        .font(.system(.headline, design: .default).weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .padding(.top, 4)

                    Text(dispatch.address)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .padding(.top, 6)

                    WatchUnitChipView(units: dispatch.units)
                        .padding(.top, 9)

                    Spacer(minLength: 8)

                    HStack(spacing: 7) {
                        Button {
                            WatchNavigationAction.open(dispatch)
                        } label: {
                            Label("Navigate", systemImage: "location.fill")
                                .font(.system(.caption, design: .default).weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.commandBlue)
                        .disabled(!dispatch.canNavigate)

                        NavigationLink {
                            WatchDispatchDetailView(dispatch: dispatch)
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .overlay {
                WatchDispatchStatusGlow(color: accentColor, reduceMotion: reduceMotion)
            }
        }
    }
}

private struct WatchMultipleDispatchCardsView: View {
    let dispatches: [WatchDispatch]
    let reduceMotion: Bool
    let lastLoadedAt: Date?
    @ObservedObject var viewModel: WatchDispatchViewModel

    private var firstAccent: Color {
        dispatches.first?.commandAccentColor ?? AppTheme.pending
    }

    var body: some View {
        WatchMTFDCommandBackground {
            VStack(spacing: 0) {
                HStack {
                    WatchDispatchStatusPill(text: "\(dispatches.count) ACTIVE", color: firstAccent)

                    Spacer()

                    if let lastLoadedAt {
                        Text("Updated \(lastLoadedAt, style: .relative) ago")
                            .font(.system(size: 9, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    NavigationLink {
                        WatchCommandMenuView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }

                TabView {
                    ForEach(dispatches) { dispatch in
                        NavigationLink {
                            WatchDispatchDetailView(dispatch: dispatch)
                        } label: {
                            WatchDispatchCommandCard(dispatch: dispatch)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .overlay {
                WatchDispatchStatusGlow(color: firstAccent, reduceMotion: reduceMotion)
            }
        }
    }
}

private struct WatchDispatchCommandCard: View {
    let dispatch: WatchDispatch

    private var accentColor: Color {
        dispatch.commandAccentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(dispatch.commandCallType)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 4)

                Text(dispatch.updatedAt, style: .relative)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundStyle(AppTheme.gold)
                    .lineLimit(1)
            }

            Text(dispatch.commandProblem)
                .font(.system(.subheadline, design: .default).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(dispatch.address)
                .font(.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)

            WatchUnitChipView(units: dispatch.units)
                .padding(.top, 2)

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(11)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct WatchDispatchStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .default))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: color.opacity(0.26), radius: 8)
    }
}

private struct WatchDispatchStatusGlow: View {
    let color: Color
    let reduceMotion: Bool
    @State private var isBright = false

    var body: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .stroke(color.opacity(isBright ? 0.78 : 0.42), lineWidth: 2)
            .shadow(color: color.opacity(isBright ? 0.44 : 0.18), radius: 15)
            .padding(1)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
    }
}

private struct WatchUnitChipView: View {
    let units: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(units.prefix(5), id: \.self) { unit in
                Text(unit)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppTheme.commandBlue.opacity(0.18), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.commandBlue.opacity(0.32), lineWidth: 1)
                    }
            }
        }
    }
}

private struct WatchGlassPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct WatchCommandScroll<Content: View>: View {
    let stationName: String
    @ViewBuilder var content: Content

    var body: some View {
        WatchMTFDCommandBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    WatchBrandHeader(stationName: stationName)
                        .padding(.bottom, 2)

                    content
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct WatchCommandLoadingView: View {
    let title: String
    let message: String

    var body: some View {
        WatchMTFDCommandBackground {
            VStack(spacing: 12) {
                WatchBrandHeader(stationName: title)

                Spacer()

                ProgressView()
                    .tint(AppTheme.gold)

                Text(title.uppercased())
                    .font(.system(.title3, design: .default).weight(.bold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(12)
        }
    }
}

private struct WatchCommandEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    let accent: Color
    let refresh: (() -> Void)?

    var body: some View {
        WatchMTFDCommandBackground {
            VStack(spacing: 10) {
                WatchBrandHeader(stationName: title)

                Spacer()

                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 68, height: 68)
                    .background(accent.opacity(0.16), in: Circle())
                    .overlay {
                        Circle().stroke(accent.opacity(0.42), lineWidth: 1)
                    }

                Text(title)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                if let refresh {
                    Button(action: refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(.caption, design: .default).weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.gold)
                    .padding(.top, 3)
                }

                Spacer()
            }
            .padding(12)
        }
    }
}

private struct WatchMenuRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}

private struct WatchCallTotalsView: View {
    let totals: WatchDispatchBucket?
    let lastLoadedAt: Date?

    var body: some View {
        WatchCommandScroll(stationName: "Call Totals") {
            if let totals {
                totalsRow(title: "24 Hours", total: totals.total24h, fire: totals.fire24h, ems: totals.ems24h, other: totals.other24h)
                totalsRow(title: "7 Days", total: totals.total7d, fire: totals.fire7d, ems: totals.ems7d, other: totals.other7d)
                totalsRow(title: "30 Days", total: totals.total30d, fire: totals.fire30d, ems: totals.ems30d, other: totals.other30d)
                totalsRow(title: "YTD", total: totals.totalYtd, fire: totals.fireYtd, ems: totals.emsYtd, other: totals.otherYtd)
            } else {
                WatchGlassPanel {
                    Label("Call totals unavailable", systemImage: "chart.bar.xaxis")
                        .font(.system(.caption, design: .default).weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }

            WatchGlassPanel {
                Label(
                    lastLoadedAt.map { "Updated \($0, style: .relative) ago" } ?? "Not synced yet",
                    systemImage: lastLoadedAt == nil ? "icloud.slash" : "clock"
                )
                .font(.system(.caption2, design: .default).weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
            }
        }
        .navigationTitle("Call Totals")
    }

    private func totalsRow(title: String, total: Int?, fire: Int?, ems: Int?, other: Int?) -> some View {
        WatchGlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .default).weight(.bold))

                    Spacer(minLength: 0)

                    Text("\(total ?? 0)")
                        .font(.system(.title3, design: .default).weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                }

                HStack(spacing: 8) {
                    miniTotal("Fire", fire ?? 0, AppTheme.danger)
                    miniTotal("EMS", ems ?? 0, AppTheme.commandBlue)
                    miniTotal("Other", other ?? 0, AppTheme.gold.opacity(0.75))
                }
            }
        }
    }

    private func miniTotal(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(.caption, design: .default).weight(.bold))

            Text(label)
                .font(.system(.caption2, design: .default).weight(.semibold))
        }
        .foregroundStyle(color)
    }
}

private struct WatchActiveCallsView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        WatchCommandScroll(stationName: "Active Calls") {
            if viewModel.activeDispatches.isEmpty {
                WatchGlassPanel {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("All Clear", systemImage: "checkmark.circle.fill")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.approved)

                        Text("No active calls")
                            .font(.caption)
                    }
                }
            } else {
                ForEach(viewModel.activeDispatches) { dispatch in
                    NavigationLink {
                        WatchDispatchDetailView(dispatch: dispatch)
                    } label: {
                        WatchDispatchRow(dispatch: dispatch)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.pending)
            }

            Button {
                Task { await viewModel.loadDispatches() }
            } label: {
                Label(viewModel.isLoading ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .navigationTitle("Active Calls")
        .task { await viewModel.loadDispatches() }
        .refreshable { await viewModel.loadDispatches() }
    }
}

private struct WatchRecentCallsView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recentDispatches.isEmpty {
                loadingView
            } else if viewModel.recentDispatches.isEmpty {
                noRecentDispatchesView
            } else {
                WatchCommandScroll(stationName: "Past Calls") {
                    ForEach(viewModel.recentDispatches) { dispatch in
                        NavigationLink {
                            WatchDispatchDetailView(dispatch: dispatch, isRecent: true)
                        } label: {
                            WatchDispatchRow(dispatch: dispatch)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Past Calls")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        WatchCommandLoadingView(title: "Past Calls", message: "Checking recent dispatches.")
    }

    private var noRecentDispatchesView: some View {
        WatchCommandEmptyState(
            title: "No Recent Calls",
            message: "Recent dispatch history will appear here after the feed syncs.",
            systemImage: "clock.arrow.circlepath",
            accent: AppTheme.gold
        ) {
            Task {
                await viewModel.loadDispatches()
            }
        }
    }
}

private struct WatchPlaceholderListView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        WatchCommandEmptyState(
            title: title,
            message: message,
            systemImage: systemImage,
            accent: AppTheme.gold,
            refresh: nil
        )
        .navigationTitle(title)
    }
}

private struct WatchScheduleView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.scheduleEntries.isEmpty {
                loadingView
            } else if viewModel.scheduleEntries.isEmpty {
                noScheduleView
            } else {
                WatchCommandScroll(stationName: "Schedule") {
                    ForEach(viewModel.scheduleEntries) { entry in
                        WatchScheduleRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        WatchCommandLoadingView(title: "Schedule", message: "Checking today's staffing.")
    }

    private var noScheduleView: some View {
        WatchCommandEmptyState(
            title: "No Schedule Data",
            message: "Today's schedule will appear here when FirstDue syncs.",
            systemImage: "calendar.badge.exclamationmark",
            accent: AppTheme.gold
        ) {
            Task {
                await viewModel.loadDispatches()
            }
        }
    }
}

private struct WatchScheduleRow: View {
    let entry: WatchScheduleEntry

    private var staffedCount: Int {
        entry.staffingDetails?.filter { $0.isVacant != true }.count ?? entry.staffing.filter {
            !$0.localizedCaseInsensitiveContains("vacant")
        }.count
    }

    private var vacancyCount: Int {
        entry.staffingDetails?.filter { $0.isVacant == true }.count ?? entry.staffing.filter {
            $0.localizedCaseInsensitiveContains("vacant")
        }.count
    }

    var body: some View {
        WatchGlassPanel {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: vacancyCount > 0 ? "person.crop.circle.badge.exclamationmark" : "person.2.fill")
                        .foregroundStyle(vacancyCount > 0 ? AppTheme.pending : AppTheme.approved)

                    Text(entry.station ?? "Station")
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)

                    Spacer()
                }

                Text(entry.title)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .lineLimit(2)

                if let timeRange = entry.timeRange, !timeRange.isEmpty {
                    Text(timeRange)
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                Text("\(staffedCount) staffed • \(vacancyCount) vacant")
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundStyle(vacancyCount > 0 ? AppTheme.pending : AppTheme.approved)
                    .lineLimit(1)

                let visibleStaffing = entry.staffing.prefix(3)
                if !visibleStaffing.isEmpty {
                    Text(visibleStaffing.joined(separator: "\n"))
                        .font(.system(.caption2, design: .default).weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)
                }
            }
        }
    }
}

private struct WatchWorkOrdersView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.workOrders.isEmpty {
                loadingView
            } else if viewModel.workOrders.isEmpty {
                noWorkOrdersView
            } else {
                WatchCommandScroll(stationName: "Work Orders") {
                    ForEach(viewModel.workOrders) { workOrder in
                        WatchWorkOrderRow(workOrder: workOrder)
                    }
                }
            }
        }
        .navigationTitle("Work Orders")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        WatchCommandLoadingView(title: "Work Orders", message: "Checking apparatus readiness.")
    }

    private var noWorkOrdersView: some View {
        WatchCommandEmptyState(
            title: "No Open Work Orders",
            message: "Apparatus work orders will appear here when FirstDue reports open items.",
            systemImage: "checkmark.seal.fill",
            accent: AppTheme.approved
        ) {
            Task {
                await viewModel.loadDispatches()
            }
        }
    }
}

private struct WatchWorkOrderRow: View {
    let workOrder: WatchWorkOrder

    var body: some View {
        WatchGlassPanel {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(AppTheme.gold)

                    Text(workOrder.apparatusName)
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                        .lineLimit(1)

                    Spacer()
                }

                Text(workOrder.title)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .lineLimit(3)

                if let status = workOrder.status, !status.isEmpty {
                    Text(status)
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct WatchDispatchRow: View {
    let dispatch: WatchDispatch

    private var accentColor: Color {
        dispatch.commandAccentColor
    }

    var body: some View {
        WatchGlassPanel {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: dispatch.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                        .foregroundStyle(accentColor)

                    Text(dispatch.isCritical ? "CRITICAL" : dispatch.commandStatus)
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundStyle(accentColor)

                    Spacer()
                }

                Text(dispatch.callType)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .lineLimit(2)

                Text(dispatch.address)
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                if !dispatch.units.isEmpty {
                    WatchUnitChipView(units: Array(dispatch.units.prefix(4)))
                }

                Text("Updated \(dispatch.updatedAt, style: .relative) ago")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
        }
    }
}

private struct WatchDispatchDetailView: View {
    let dispatch: WatchDispatch
    var isRecent = false

    private var accentColor: Color {
        dispatch.commandAccentColor
    }

    private var canNavigate: Bool {
        dispatch.canNavigate
    }

    var body: some View {
        WatchCommandScroll(stationName: isRecent ? "Past Dispatch" : "Dispatch") {
            WatchDispatchStatusPill(
                text: isRecent ? "PAST" : dispatch.commandStatus,
                color: isRecent ? AppTheme.gold : accentColor
            )

            Text(dispatch.commandCallType)
                .font(.system(size: 34, weight: .bold, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(dispatch.callType)
                .font(.system(.headline, design: .default).weight(.bold))
                .lineLimit(2)

            if dispatch.isWorkingFire {
                Text("WORKING FIRE")
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.danger, in: Capsule())
            }

            WatchGlassPanel {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Address", systemImage: "mappin.and.ellipse")
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundStyle(AppTheme.gold)

                    Text(dispatch.address)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .lineLimit(3)
                }
            }

            if !dispatch.units.isEmpty {
                WatchGlassPanel {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Units", systemImage: "truck.box.fill")
                            .font(.system(.caption2, design: .default).weight(.bold))
                            .foregroundStyle(AppTheme.commandBlue)

                        WatchUnitChipView(units: dispatch.units)
                    }
                }
            }

            WatchGlassPanel {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Updated", systemImage: "clock")
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundStyle(AppTheme.gold)

                    Text(dispatch.updatedAt, style: .relative)
                        .font(.system(.body, design: .default).weight(.semibold))
                }
            }

            if canNavigate {
                Button {
                    WatchNavigationAction.open(dispatch)
                } label: {
                    Label("Navigate to Call", systemImage: "location.fill")
                        .font(.system(.caption, design: .default).weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.commandBlue)
            } else {
                Text("Navigation unavailable until a dispatch address is provided.")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
        }
        .navigationTitle("Dispatch")
    }
}

final class WatchDispatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WatchDispatchNotificationDelegate()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        _ = WatchPhoneNavigationBridge.shared
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        let type = info["type"] as? String
        if type == "dispatch" || type == "dispatch_critical" || type == "test_push",
           let id = info["dispatchId"] as? String ?? info["id"] as? String {
            let message: [String: Any] = [
                "action": "dispatch_haptic",
                "dispatchId": id,
                "hapticAlertStyle": info["hapticAlertStyle"] as? String ?? "normal",
                "critical": info["critical"] as? Bool ?? (type == "dispatch_critical"),
                "sentAt": notification.date.timeIntervalSince1970
            ]
            Task { @MainActor in
                WatchDispatchHaptics.shared.receive(message)
            }
        }
        // Keep system presentation, including Silent and Focus behavior.
        completionHandler([.banner, .sound])
    }
}

@MainActor
private final class WatchDispatchHaptics {
    static let shared = WatchDispatchHaptics()
    private var playedIDs = Set<String>()
    private var playbackTask: Task<Void, Never>?

    func applySettings(_ message: [String: Any]) {
        if let enabled = message["hapticsEnabled"] as? Bool {
            UserDefaults.standard.set(enabled, forKey: "watch_dispatch_haptics_enabled")
        }
        if let style = message["hapticStyle"] as? String,
           ["followPhone", "normal", "strong", "pagerStyle"].contains(style) {
            UserDefaults.standard.set(style, forKey: "watch_dispatch_haptic_style")
        }
        playbackTask?.cancel()
    }

    @discardableResult
    func receive(_ message: [String: Any]) -> Bool {
        guard message["action"] as? String == "dispatch_haptic",
              let id = message["dispatchId"] as? String,
              let sentAt = message["sentAt"] as? TimeInterval,
              abs(Date().timeIntervalSince1970 - sentAt) < 30,
              WKApplication.shared().applicationState == .active,
              !playedIDs.contains(id) else { return false }

        guard UserDefaults.standard.object(forKey: "watch_dispatch_haptics_enabled") as? Bool ?? true else {
            playbackTask?.cancel()
            return false
        }

        playedIDs.insert(id)
        playbackTask?.cancel()
        let override = UserDefaults.standard.string(forKey: "watch_dispatch_haptic_style") ?? "followPhone"
        let style = override == "followPhone" ? message["hapticAlertStyle"] as? String ?? "normal" : override
        guard style != "off" else { return false }
        let count = style == "pagerStyle" ? 4 : style == "strong" ? 3 : 1
        let critical = message["critical"] as? Bool == true
        playbackTask = Task { @MainActor in
            for index in 0..<count {
                guard !Task.isCancelled,
                      WKApplication.shared().applicationState == .active else { return }
                WKInterfaceDevice.current().play(critical ? .notification : .directionUp)
                if index < count - 1 {
                    do { try await Task.sleep(nanoseconds: 1_200_000_000) } catch { return }
                }
            }
        }
        return true
    }
}

private final class WatchPhoneNavigationBridge: NSObject, WCSessionDelegate {
    static let shared = WatchPhoneNavigationBridge()

    private override init() {
        super.init()

        guard WCSession.isSupported() else { return }

        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendNavigateToCall(address: String) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        let message: [String: Any] = [
            "action": "navigate_to_call",
            "address": address
        ]

        if session.activationState != .activated {
            session.activate()
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("⌚️ Watch phone navigation handoff failed: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("⌚️ Watch phone navigation context failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⌚️ WatchConnectivity activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if message["action"] as? String == "watch_settings" {
                WatchDispatchHaptics.shared.applySettings(message)
            } else {
                WatchDispatchHaptics.shared.receive(message)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if applicationContext["action"] as? String == "watch_settings" {
                WatchDispatchHaptics.shared.applySettings(applicationContext)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            let action = message["action"] as? String
            guard action == "watch_settings" || action == "test_dispatch_haptic" else {
                replyHandler(["applied": false])
                return
            }
            WatchDispatchHaptics.shared.applySettings(message)
            if action == "test_dispatch_haptic" {
                let played = WatchDispatchHaptics.shared.receive([
                    "action": "dispatch_haptic", "dispatchId": "test-\(UUID().uuidString)",
                    "hapticAlertStyle": message["phoneHapticStyle"] as? String ?? "normal",
                    "sentAt": Date().timeIntervalSince1970, "critical": true
                ])
                replyHandler(["played": played])
            } else {
                replyHandler(["applied": true])
            }
        }
    }
}

#if targetEnvironment(simulator)
#Preview {
    ContentView()
}
#endif
