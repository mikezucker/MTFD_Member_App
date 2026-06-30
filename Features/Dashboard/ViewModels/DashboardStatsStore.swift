import Foundation
import Combine

@MainActor
final class DashboardStatsStore: ObservableObject {
    static let shared = DashboardStatsStore()

    @Published private(set) var stats: APIClient.DispatchStatsResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private let cacheTTL: TimeInterval = 60 * 60
    private let minimumAttemptInterval: TimeInterval = 10
    private let cacheKey = "dashboard_stats_store_cache_v2"
    private var refreshTask: Task<Void, Never>?
    private var lastAttemptAt: Date?

    private init() {
        loadCachedStats()
    }

    func refreshIfNeeded(reason: String) async {
        if isLoading || refreshTask != nil {
            log("skipped refresh, request already in flight")
            return
        }

        guard isCacheStale else {
            log("using cached stats, age=\(cacheAgeDescription), reason=\(reason)")
            return
        }

        if shouldThrottleAttempt {
            log("using cached stats, age=\(cacheAgeDescription), reason=\(reason)")
            return
        }

        log("refreshing stats, reason=cacheExpired")
        await refresh(reason: reason, force: false)
    }

    func forceRefresh(reason: String) async {
        if isLoading || refreshTask != nil {
            log("skipped refresh, request already in flight")
            return
        }

        log("force refresh, reason=\(reason)")
        await refresh(reason: reason, force: true)
    }

    func markStale() {
        lastUpdated = .distantPast
    }

    private func refresh(reason: String, force: Bool) async {
        isLoading = true
        lastAttemptAt = Date()

        let task = Task { @MainActor in
            defer {
                isLoading = false
                refreshTask = nil
            }

            do {
                let response = try await APIClient.shared.fetchDispatchStats()
                stats = response
                lastUpdated = Date()
                saveCachedStats()
            } catch {
                log("refresh failed, keeping cached stats, reason=\(reason), error=\(error.localizedDescription)")
            }
        }

        refreshTask = task
        await task.value
    }

    private var isCacheStale: Bool {
        guard stats != nil, let lastUpdated else {
            return true
        }

        return Date().timeIntervalSince(lastUpdated) >= cacheTTL
    }

    private var shouldThrottleAttempt: Bool {
        guard let lastAttemptAt else {
            return false
        }

        return Date().timeIntervalSince(lastAttemptAt) < minimumAttemptInterval
    }

    private var cacheAgeDescription: String {
        guard let lastUpdated else {
            return "missing"
        }

        let ageMinutes = max(0, Int(Date().timeIntervalSince(lastUpdated) / 60))
        return "\(ageMinutes)m"
    }

    private func loadCachedStats() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedDashboardStats.self, from: data) else {
            return
        }

        stats = cached.response
        lastUpdated = cached.fetchedAt
    }

    private func saveCachedStats() {
        guard let stats, let lastUpdated else {
            return
        }

        let cached = CachedDashboardStats(response: stats, fetchedAt: lastUpdated)
        guard let data = try? JSONEncoder().encode(cached) else {
            return
        }

        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[StatsStore] \(message)")
        #endif
    }
}

private struct CachedDashboardStats: Codable {
    let response: APIClient.DispatchStatsResponse
    let fetchedAt: Date
}
