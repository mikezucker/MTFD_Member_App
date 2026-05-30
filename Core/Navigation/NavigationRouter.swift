import SwiftUI
import Combine

@MainActor
final class NavigationRouter: ObservableObject {

    static let shared = NavigationRouter()

    @Published var selectedTab: AppTab = .home

    @Published var dispatchToOpen: AppNotificationPayload?
    @Published var trainingToOpen: AppNotificationPayload?
    @Published var documentToOpen: AppNotificationPayload?
    @Published var messageToOpen: AppNotificationPayload?

    enum AppTab {
        case home
        case command
        case training
        case documents
        case schedule
        case more
    }

    func route(from payload: AppNotificationPayload) {
        print("🧭 Routing notification:", payload.type.rawValue)

        switch payload.type {

        case .dispatch, .dispatchCritical:
            selectedTab = .home
            dispatchToOpen = payload

        case .trainingAssignment:
            selectedTab = .training
            trainingToOpen = payload

        case .documentAssignment:
            selectedTab = .documents
            documentToOpen = payload

        case .departmentMessage, .stationMessage, .messageCenter:
            selectedTab = .more
            messageToOpen = payload

        default:
            break
        }
    }

    func clearDispatchRoute() {
        dispatchToOpen = nil
    }

    func clearTrainingRoute() {
        trainingToOpen = nil
    }

    func clearDocumentRoute() {
        documentToOpen = nil
    }

    func clearMessageRoute() {
        messageToOpen = nil
    }
}
