//
//  ContentView.swift
//  MTFD Watch App Watch App
//

import SwiftUI
import Combine
import WatchKit

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

@MainActor
private final class WatchDispatchViewModel: ObservableObject {
    @Published var activeDispatches: [WatchDispatch] = []
    @Published var recentDispatches: [WatchDispatch] = []
    @Published var scheduleEntries: [WatchScheduleEntry] = []
    @Published var workOrders: [WatchWorkOrder] = []
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
    let lastLoadedAt: Date?
}

struct ContentView: View {
    @StateObject private var viewModel = WatchDispatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                WatchHomeHeader(
                    activeCount: viewModel.activeDispatches.count,
                    workOrderCount: viewModel.workOrders.count
                )

                NavigationLink {
                    WatchActiveCallsView(viewModel: viewModel)
                } label: {
                    WatchMenuRow(
                        title: "Active Calls",
                        subtitle: activeDispatchCountText,
                        systemImage: "dot.radiowaves.left.and.right",
                        color: viewModel.activeDispatches.isEmpty ? .green : .orange
                    )
                }

                NavigationLink {
                    WatchRecentCallsView(viewModel: viewModel)
                } label: {
                    WatchMenuRow(
                        title: "Past Calls",
                        subtitle: recentDispatchCountText,
                        systemImage: "clock.arrow.circlepath",
                        color: .blue
                    )
                }

                NavigationLink {
                    WatchStatsView(
                        activeCount: viewModel.activeDispatches.count,
                        recentCount: viewModel.recentDispatches.count,
                        scheduleCount: viewModel.scheduleEntries.count,
                        workOrderCount: viewModel.workOrders.count,
                        lastLoadedAt: viewModel.lastLoadedAt
                    )
                } label: {
                    WatchMenuRow(
                        title: "Stats",
                        subtitle: "Dispatch snapshot",
                        systemImage: "chart.bar.fill",
                        color: .purple
                    )
                }

                NavigationLink {
                    WatchScheduleView(viewModel: viewModel)
                } label: {
                    WatchMenuRow(
                        title: "Schedule",
                        subtitle: scheduleCountText,
                        systemImage: "calendar",
                        color: .cyan
                    )
                }

                NavigationLink {
                    WatchWorkOrdersView(viewModel: viewModel)
                } label: {
                    WatchMenuRow(
                        title: "Work Orders",
                        subtitle: workOrderCountText,
                        systemImage: "wrench.and.screwdriver.fill",
                        color: .yellow
                    )
                }

                if let lastLoadedAt = viewModel.lastLoadedAt {
                    Text("Updated \(lastLoadedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text("Using cached data. \(errorMessage)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .listStyle(.carousel)
            .navigationTitle("")
            .task {
                await viewModel.loadDispatches()
            }
            .refreshable {
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
}

private struct WatchHomeHeader: View {
    let activeCount: Int
    let workOrderCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("MTFD")
                        .font(.headline.weight(.black))

                    Text("Member Watch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                WatchStatusChip(
                    value: "\(activeCount)",
                    label: "Active",
                    color: activeCount > 0 ? .orange : .green
                )

                WatchStatusChip(
                    value: "\(workOrderCount)",
                    label: "Work",
                    color: workOrderCount > 0 ? .yellow : .green
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WatchStatusChip: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.black))

            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.16), in: Capsule())
    }
}

private struct WatchActiveCallsView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.activeDispatches.isEmpty {
                loadingView
            } else if viewModel.activeDispatches.isEmpty {
                noDispatchesView
            } else {
                List(viewModel.activeDispatches) { dispatch in
                    if dispatch.id == viewModel.activeDispatches.first?.id {
                        feedStatusRow
                    }

                    NavigationLink {
                        WatchDispatchDetailView(dispatch: dispatch)
                    } label: {
                        WatchDispatchRow(dispatch: dispatch)
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Active Calls")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()

            Text("Checking Dispatches")
                .font(.headline)

            Text("Loading the active MTFD feed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var feedStatusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.green)

                Text(activeDispatchCountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            }

            if let lastLoadedAt = viewModel.lastLoadedAt {
                Text("Updated \(lastLoadedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var activeDispatchCountText: String {
        let count = viewModel.activeDispatches.count
        return count == 1 ? "1 active dispatch" : "\(count) active dispatches"
    }

    private var noDispatchesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)

            Text("No Active Dispatches")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("You’re clear right now.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastLoadedAt = viewModel.lastLoadedAt {
                Text("Updated \(lastLoadedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.loadDispatches()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding()
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

private struct WatchStatsView: View {
    let activeCount: Int
    let recentCount: Int
    let scheduleCount: Int
    let workOrderCount: Int
    let lastLoadedAt: Date?

    var body: some View {
        List {
            Label("\(activeCount) active", systemImage: "dot.radiowaves.left.and.right")
            Label("\(recentCount) recent", systemImage: "clock.arrow.circlepath")
            Label("\(scheduleCount) schedule", systemImage: "calendar")
            Label("\(workOrderCount) work orders", systemImage: "wrench.and.screwdriver.fill")

            if let lastLoadedAt {
                Label("Updated \(lastLoadedAt, style: .relative) ago", systemImage: "clock")
            } else {
                Label("Not synced yet", systemImage: "icloud.slash")
            }
        }
        .navigationTitle("Stats")
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
                List(viewModel.recentDispatches) { dispatch in
                    NavigationLink {
                        WatchDispatchDetailView(dispatch: dispatch, isRecent: true)
                    } label: {
                        WatchDispatchRow(dispatch: dispatch)
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Past Calls")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()

            Text("Loading History")
                .font(.headline)

            Text("Checking recent dispatches.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var noRecentDispatchesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No Recent Calls")
                .font(.headline)

            Text("Recent dispatch history will appear here after the feed syncs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadDispatches()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}

private struct WatchPlaceholderListView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
                List(viewModel.scheduleEntries) { entry in
                    WatchScheduleRow(entry: entry)
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Schedule")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()

            Text("Loading Schedule")
                .font(.headline)

            Text("Checking today’s staffing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var noScheduleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No Schedule Data")
                .font(.headline)

            Text("Today’s schedule will appear here when FirstDue syncs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadDispatches()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: vacancyCount > 0 ? "person.crop.circle.badge.exclamationmark" : "person.2.fill")
                    .foregroundStyle(vacancyCount > 0 ? .orange : .green)

                Text(entry.station ?? "MTFD")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            Text(entry.title)
                .font(.headline.weight(.bold))
                .lineLimit(2)

            if let timeRange = entry.timeRange, !timeRange.isEmpty {
                Text(timeRange)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("\(staffedCount) staffed • \(vacancyCount) vacant")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(vacancyCount > 0 ? .orange : .green)
                .lineLimit(1)

            let visibleStaffing = entry.staffing.prefix(3)
            if !visibleStaffing.isEmpty {
                Text(visibleStaffing.joined(separator: "\n"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
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
                List(viewModel.workOrders) { workOrder in
                    WatchWorkOrderRow(workOrder: workOrder)
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Work Orders")
        .refreshable {
            await viewModel.loadDispatches()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()

            Text("Loading Work Orders")
                .font(.headline)

            Text("Checking apparatus readiness.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var noWorkOrdersView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)

            Text("No Open Work Orders")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Apparatus work orders will appear here when FirstDue reports open items.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadDispatches()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}

private struct WatchWorkOrderRow: View {
    let workOrder: WatchWorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.yellow)

                Text(workOrder.apparatusName)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)

                Spacer()
            }

            Text(workOrder.title)
                .font(.headline.weight(.bold))
                .lineLimit(3)

            if let status = workOrder.status, !status.isEmpty {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WatchDispatchRow: View {
    let dispatch: WatchDispatch

    private var accentColor: Color {
        dispatch.isCritical ? .red : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: dispatch.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                    .foregroundStyle(accentColor)

                Text(dispatch.isCritical ? "CRITICAL" : "DISPATCH")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(accentColor)

                Spacer()
            }

            Text(dispatch.callType)
                .font(.headline.weight(.bold))
                .lineLimit(1)

            Text(dispatch.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !dispatch.units.isEmpty {
                Text(dispatch.units.prefix(4).joined(separator: " • "))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Updated \(dispatch.updatedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct WatchDispatchDetailView: View {
    let dispatch: WatchDispatch
    var isRecent = false

    private var accentColor: Color {
        dispatch.isCritical ? .red : .orange
    }

    private var canNavigate: Bool {
        let address = dispatch.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return !address.isEmpty && address != "Address unavailable"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: dispatch.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                        .foregroundStyle(accentColor)

                    Text(isRecent ? "Past Dispatch" : dispatch.isCritical ? "Critical Dispatch" : "Active Dispatch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentColor)
                }

                Text(dispatch.callType)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)

                if dispatch.isWorkingFire {
                    Text("WORKING FIRE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.red)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Address", systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(dispatch.address)
                        .font(.body.weight(.semibold))
                }

                if !dispatch.units.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Units", systemImage: "truck.box.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text(dispatch.units.joined(separator: " • "))
                            .font(.body.weight(.semibold))
                    }
                }

                if canNavigate {
                    Button {
                        openNavigation()
                    } label: {
                        Label("Navigate", systemImage: "location.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Updated", systemImage: "clock")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(dispatch.updatedAt, style: .relative)
                        .font(.body.weight(.semibold))
                }

                if !canNavigate {
                    Text("Navigation unavailable until a dispatch address is provided.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Dispatch")
    }

    private func openNavigation() {
        guard let encodedAddress = dispatch.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)&dirflg=d") else {
            return
        }

        WKExtension.shared().openSystemURL(url)
    }
}

#Preview {
    ContentView()
}
