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

@MainActor
private final class WatchDispatchViewModel: ObservableObject {
    @Published var dispatches: [WatchDispatch] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadedAt: Date?

    private let feedURL = URL(string: "https://new-mtfd-site.vercel.app/api/shared/active-dispatches")!
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

            let decoded = try Self.decoder.decode(WatchDispatchFeedResponse.self, from: data)
            dispatches = decoded.activeDispatches.map(Self.mapDispatch)
            lastLoadedAt = Date()
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
            dispatches = cached.dispatches
            lastLoadedAt = cached.lastLoadedAt
        } catch {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }

    private func cacheDispatches() {
        do {
            let data = try JSONEncoder().encode(
                WatchDispatchCache(
                    dispatches: dispatches,
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
    let dispatches: [WatchDispatch]
    let lastLoadedAt: Date?
}

struct ContentView: View {
    @StateObject private var viewModel = WatchDispatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    WatchActiveCallsView(viewModel: viewModel)
                } label: {
                    WatchMenuRow(
                        title: "Active Calls",
                        subtitle: activeDispatchCountText,
                        systemImage: "dot.radiowaves.left.and.right",
                        color: viewModel.dispatches.isEmpty ? .green : .orange
                    )
                }

                NavigationLink {
                    WatchPlaceholderListView(
                        title: "Past Calls",
                        systemImage: "clock.arrow.circlepath",
                        message: "Recent call history will sync here when the shared history endpoint is available to the Watch app."
                    )
                } label: {
                    WatchMenuRow(
                        title: "Past Calls",
                        subtitle: "Recent history",
                        systemImage: "clock.arrow.circlepath",
                        color: .blue
                    )
                }

                NavigationLink {
                    WatchStatsView(activeCount: viewModel.dispatches.count, lastLoadedAt: viewModel.lastLoadedAt)
                } label: {
                    WatchMenuRow(
                        title: "Stats",
                        subtitle: "Dispatch snapshot",
                        systemImage: "chart.bar.fill",
                        color: .purple
                    )
                }

                NavigationLink {
                    WatchPlaceholderListView(
                        title: "Work Orders",
                        systemImage: "wrench.and.screwdriver.fill",
                        message: "Work orders should mirror phone permissions, filters, and status rules once the Watch API is connected."
                    )
                } label: {
                    WatchMenuRow(
                        title: "Work Orders",
                        subtitle: "Phone rules",
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
            .navigationTitle("MTFD")
            .task {
                await viewModel.loadDispatches()
            }
            .refreshable {
                await viewModel.loadDispatches()
            }
        }
    }

    private var activeDispatchCountText: String {
        let count = viewModel.dispatches.count
        return count == 1 ? "1 active dispatch" : "\(count) active dispatches"
    }
}

private struct WatchActiveCallsView: View {
    @ObservedObject var viewModel: WatchDispatchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.dispatches.isEmpty {
                loadingView
            } else if viewModel.dispatches.isEmpty {
                noDispatchesView
            } else {
                List(viewModel.dispatches) { dispatch in
                    if dispatch.id == viewModel.dispatches.first?.id {
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
        let count = viewModel.dispatches.count
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
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct WatchStatsView: View {
    let activeCount: Int
    let lastLoadedAt: Date?

    var body: some View {
        List {
            Label("\(activeCount) active", systemImage: "dot.radiowaves.left.and.right")

            if let lastLoadedAt {
                Label("Updated \(lastLoadedAt, style: .relative) ago", systemImage: "clock")
            } else {
                Label("Not synced yet", systemImage: "icloud.slash")
            }
        }
        .navigationTitle("Stats")
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

                    Text(dispatch.isCritical ? "Critical Dispatch" : "Active Dispatch")
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
