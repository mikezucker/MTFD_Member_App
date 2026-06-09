import Foundation
import Combine

@MainActor
final class MessageCenterViewModel: ObservableObject {
    @Published var messages: [MobileMessage] = []
    @Published var unreadCount: Int = 0
    @Published var activeDispatches: [APIClient.ActiveDispatch] = []
    @Published var historicalDispatches: [APIClient.DispatchHistoryItem] = []
    @Published var selectedDispatchWindow: String = "24h"
    @Published var isLoading = false
    @Published var isLoadingDispatchHistory = false
    @Published var errorMessage: String?

    @Published private(set) var readDispatchIds: Set<String> = []

    private let readDispatchIdsKey = "messageCenter.readDispatchIds"

    private var hasLoaded = false
    private var isLoadingMessages = false
    private var lastLoadedAt: Date?
    private let minimumRefreshInterval: TimeInterval = 60

    var hasUnreadMessages: Bool {
        unreadCount > 0
    }

    var unreadDepartmentMessageCount: Int {
        messages.filter { message in
            message.type != "DISPATCH" &&
            message.type != "DISPATCH_UPDATE" &&
            message.dispatchId == nil &&
            !message.isRead
        }.count
    }

    var unreadDispatchCount: Int {
        activeDispatches.filter { dispatch in
            !readDispatchIds.contains(dispatch.id)
        }.count
    }

    func loadMessagesIfNeeded() async {
        guard !hasLoaded else { return }
        await loadMessages(force: false)
    }

    func refreshIfStale() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < minimumRefreshInterval {
            return
        }

        await loadMessages(force: true)
    }

    func loadMessages(force: Bool = true) async {
        guard !isLoadingMessages else { return }

        if !force, hasLoaded {
            return
        }

        isLoadingMessages = true
        isLoading = true
        errorMessage = nil

        loadReadDispatchIds()

        do {
            async let messagesResponse = APIClient.shared.fetchMessages()
            async let dashboardResponse = APIClient.shared.fetchDashboard()
            async let dispatchHistoryResponse = APIClient.shared.fetchDispatchHistory(window: selectedDispatchWindow)

            let resolvedMessages = try await messagesResponse
            let resolvedDashboard = try await dashboardResponse
            let resolvedDispatchHistory = try await dispatchHistoryResponse

            messages = resolvedMessages.messages
            unreadCount = resolvedMessages.unreadCount
            activeDispatches = resolvedDashboard.activeDispatches ?? []
            historicalDispatches = resolvedDispatchHistory.historicalDispatches

            pruneOldReadDispatchIds()
            updateBadgeCount()

            hasLoaded = true
            lastLoadedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        isLoadingMessages = false
    }

    func changeDispatchWindow(to window: String) async {
        guard selectedDispatchWindow != window else {
            return
        }

        selectedDispatchWindow = window
        await loadDispatchHistory()
    }

    func loadDispatchHistory() async {
        isLoadingDispatchHistory = true
        errorMessage = nil

        loadReadDispatchIds()

        do {
            let response = try await APIClient.shared.fetchDispatchHistory(window: selectedDispatchWindow)

            activeDispatches = response.activeDispatches
            historicalDispatches = response.historicalDispatches

            pruneOldReadDispatchIds()
            updateBadgeCount()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingDispatchHistory = false
    }

    func markRead(_ message: MobileMessage) async {
        guard !message.isRead else {
            return
        }

        do {
            let response = try await APIClient.shared.markMessageRead(id: message.id)

            unreadCount = response.unreadCount

            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = response.message
            }

            updateBadgeCount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markDispatchRead(id: String) {
        readDispatchIds.insert(id)
        saveReadDispatchIds()
        updateBadgeCount()
    }

    func isDispatchRead(id: String) -> Bool {
        readDispatchIds.contains(id)
    }

    func refresh() async {
        await loadMessages(force: true)
    }

    private func updateBadgeCount() {
        AppBadgeManager.shared.updateAppBadge(
            dispatchCount: unreadDispatchCount,
            unreadMessageCount: unreadDepartmentMessageCount
        )
    }

    private func loadReadDispatchIds() {
        let ids = UserDefaults.standard.stringArray(forKey: readDispatchIdsKey) ?? []
        readDispatchIds = Set(ids)
    }

    private func saveReadDispatchIds() {
        UserDefaults.standard.set(Array(readDispatchIds), forKey: readDispatchIdsKey)
    }

    private func pruneOldReadDispatchIds() {
        let activeIds = Set(activeDispatches.map { $0.id })
        let recentHistoryIds = Set(historicalDispatches.prefix(100).map { $0.id })

        readDispatchIds = readDispatchIds.filter { id in
            activeIds.contains(id) || recentHistoryIds.contains(id)
        }

        saveReadDispatchIds()
    }
}
