//
//  CarPlaySceneDelegate.swift
//  MTFD Member App
//

import CarPlay
import Foundation
import MapKit
import CoreLocation
import UIKit

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate, CPMapTemplateDelegate {
    private weak var interfaceController: CPInterfaceController?

    private var hasConfiguredRootTemplate = false
    private var refreshTimer: Timer?
    private var dispatchNotificationObserver: NSObjectProtocol?
    private var isLoading = false
    private var lastRefreshAt: Date?
    private var lastErrorMessage: String?

    private var activeDispatches: [APIClient.ActiveDispatch] = []
    private var recentDispatches: [APIClient.DispatchHistoryItem] = []
    private var knownActiveDispatchIds = Set<String>()
    private var hasLoadedDispatchBaseline = false
    private var selectedActiveDispatchId: String?
    private var activeNavigationSession: CPNavigationSession?

    private enum CarPlayScreen {
        case root
        case active
        case recent
        case detail
    }

    private var currentScreen: CarPlayScreen = .root
    private var detailParentScreen: CarPlayScreen?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        configureCarPlay(interfaceController: interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        tearDownCarPlay(interfaceController: interfaceController)
    }

    private func configureCarPlay(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self
        currentScreen = .root
        detailParentScreen = nil

        guard !hasConfiguredRootTemplate else {
            return
        }

        hasConfiguredRootTemplate = true

        interfaceController.setRootTemplate(
            makeRootTemplate(isLoading: true),
            animated: true,
            completion: nil
        )

        startDispatchNotificationObserver()
        startRefreshTimer()
        refreshDispatches(updateVisibleScreen: true)
    }

    private func tearDownCarPlay(interfaceController: CPInterfaceController) {
        stopRefreshTimer()
        stopDispatchNotificationObserver()

        if self.interfaceController === interfaceController {
            interfaceController.delegate = nil
            self.interfaceController = nil
        }

        hasConfiguredRootTemplate = false
        currentScreen = .root
        activeDispatches = []
        recentDispatches = []
        knownActiveDispatchIds = []
        hasLoadedDispatchBaseline = false
        isLoading = false
        lastRefreshAt = nil
        lastErrorMessage = nil
        selectedActiveDispatchId = nil
        detailParentScreen = nil
        activeNavigationSession = nil
    }

    // MARK: - Refresh

    private func startRefreshTimer() {
        stopRefreshTimer()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshDispatches(updateVisibleScreen: true)
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startDispatchNotificationObserver() {
        stopDispatchNotificationObserver()

        dispatchNotificationObserver = NotificationCenter.default.addObserver(
            forName: .didReceiveDispatchNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let payload = notification.object as? DispatchNotificationPayload else {
                return
            }

            self?.handleDispatchNotification(payload)
        }
    }

    private func stopDispatchNotificationObserver() {
        if let dispatchNotificationObserver {
            NotificationCenter.default.removeObserver(dispatchNotificationObserver)
            self.dispatchNotificationObserver = nil
        }
    }

    private func handleDispatchNotification(_ payload: DispatchNotificationPayload) {
        guard payload.type == .dispatch || payload.type == .dispatchCritical else {
            return
        }

        let dispatch = makeActiveDispatch(from: payload)
        let isNewDispatch = !knownActiveDispatchIds.contains(dispatch.id)

        if isNewDispatch {
            activeDispatches.insert(dispatch, at: 0)
            knownActiveDispatchIds.insert(dispatch.id)
            lastRefreshAt = Date()
            lastErrorMessage = nil
            updateVisibleScreenAfterDispatchChange()
            presentNewDispatchAlert(dispatch)
        }

        refreshDispatches(updateVisibleScreen: true)
    }

    private func makeActiveDispatch(from payload: DispatchNotificationPayload) -> APIClient.ActiveDispatch {
        APIClient.ActiveDispatch(
            id: payload.id,
            callType: payload.callType ?? payload.title,
            address: payload.address ?? payload.body,
            address2: nil,
            placeName: nil,
            city: nil,
            state: nil,
            latitude: nil,
            longitude: nil,
            message: payload.body,
            units: DispatchUnitFilter.visibleRespondingUnits(from: payload.units),
            dispatchedAt: Date(),
            lastActivityAt: Date(),
            priority: payload.type == .dispatchCritical ? "CRITICAL" : nil,
            isWorkingFire: payload.isWorkingFire,
            status: "active",
            isClosed: false
        )
    }

    private func updateVisibleScreenAfterDispatchChange() {
        switch currentScreen {
        case .root:
            interfaceController?.setRootTemplate(
                makeRootTemplate(isLoading: isLoading),
                animated: false,
                completion: nil
            )
        case .active:
            replaceVisibleTemplate(with: makeActiveDispatchesTemplate(), screen: .active)
        case .recent:
            break
        case .detail:
            updateVisibleDetailAfterRefresh()
        }
    }

    private func refreshDispatches(updateVisibleScreen: Bool) {
        guard !isLoading else { return }

        if APIClient.shared.authToken?.isEmpty != false,
           let token = KeychainService.shared.loadToken(),
           !token.isEmpty {
            APIClient.shared.authToken = token
        }

        isLoading = true

        Task { [weak self] in
            guard let self else { return }

            do {
                async let dispatchHistoryResponse = APIClient.shared.fetchDispatchHistory(window: "24h")

                let response = try await dispatchHistoryResponse

                let resolvedActiveDispatches = response.activeDispatches

                await MainActor.run {
                    let newDispatches = resolvedActiveDispatches.filter {
                        !self.knownActiveDispatchIds.contains($0.id)
                    }
                    let shouldAlertForNewDispatches = self.hasLoadedDispatchBaseline

                    self.activeDispatches = resolvedActiveDispatches
                    self.recentDispatches = Array(response.historicalDispatches.prefix(12))
                    self.knownActiveDispatchIds = Set(resolvedActiveDispatches.map(\.id))
                    self.hasLoadedDispatchBaseline = true
                    self.lastRefreshAt = response.fetchedAt ?? Date()
                    self.lastErrorMessage = nil

                    if let newest = newDispatches.first, shouldAlertForNewDispatches {
                        self.presentNewDispatchAlert(newest)
                    }
                    self.isLoading = false

                    print("🚗 CarPlay dispatch refresh active=\(self.activeDispatches.count) recent=\(self.recentDispatches.count)")

                    guard updateVisibleScreen else { return }

                    switch self.currentScreen {
                    case .root:
                        self.interfaceController?.setRootTemplate(
                            self.makeRootTemplate(isLoading: false),
                            animated: false,
                            completion: nil
                        )
                    case .active:
                        self.replaceVisibleTemplate(with: self.makeActiveDispatchesTemplate(), screen: .active)
                    case .recent:
                        self.replaceVisibleTemplate(with: self.makeRecentDispatchesTemplate(), screen: .recent)
                    case .detail:
                        self.updateVisibleDetailAfterRefresh()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.lastErrorMessage = self.dispatchErrorMessage(error)
                    print("🚗 CarPlay dispatch refresh failed: \(self.lastErrorMessage ?? error.localizedDescription)")

                    guard updateVisibleScreen else { return }

                    switch self.currentScreen {
                    case .root:
                        self.interfaceController?.setRootTemplate(
                            self.makeRootTemplate(isLoading: false),
                            animated: false,
                            completion: nil
                        )
                    case .active:
                        self.replaceVisibleTemplate(with: self.makeActiveDispatchesTemplate(), screen: .active)
                    case .recent:
                        self.replaceVisibleTemplate(with: self.makeRecentDispatchesTemplate(), screen: .recent)
                    case .detail:
                        break
                    }
                }
            }
        }
    }

    private func replaceVisibleTemplate(with template: CPTemplate, screen: CarPlayScreen) {
        guard let interfaceController else { return }

        if interfaceController.templates.count > 1 {
            interfaceController.popTemplate(animated: false) { [weak self] _, _ in
                self?.interfaceController?.pushTemplate(template, animated: false, completion: nil)
            }
        } else {
            rebuildTemplateStack(endingWith: template, screen: screen)
        }
    }

    private func rebuildTemplateStack(endingWith template: CPTemplate, screen: CarPlayScreen) {
        guard let interfaceController else { return }

        let rootTemplate = makeRootTemplate(isLoading: isLoading)
        interfaceController.setRootTemplate(rootTemplate, animated: false) { [weak self] _, _ in
            guard let self else { return }

            switch screen {
            case .root:
                self.currentScreen = .root
            case .active, .recent:
                self.interfaceController?.pushTemplate(template, animated: false, completion: nil)
            case .detail:
                let parentScreen = self.detailParentScreen ?? .active
                let parentTemplate: CPTemplate

                switch parentScreen {
                case .recent:
                    parentTemplate = self.makeRecentDispatchesTemplate()
                default:
                    parentTemplate = self.makeActiveDispatchesTemplate()
                }

                self.interfaceController?.pushTemplate(parentTemplate, animated: false) { [weak self] _, _ in
                    self?.interfaceController?.pushTemplate(template, animated: false, completion: nil)
                }
            }
        }
    }

    // MARK: - Root

    private func makeRootTemplate(isLoading: Bool, errorMessage: String? = nil) -> CPListTemplate {
        let activeCount = activeDispatches.count
        let recentCount = recentDispatches.count

        let activeItem = CPListItem(
            text: "Active Incidents",
            detailText: activeCount == 0 ? "No active dispatches" : "\(activeCount) active"
        )
        activeItem.setImage(carPlayIcon("flame.fill", tintColor: .systemRed))

        activeItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }

            self.currentScreen = .active
            self.selectedActiveDispatchId = nil
            self.interfaceController?.pushTemplate(
                self.makeActiveDispatchesTemplate(),
                animated: true,
                completion: nil
            )
            completion()
        }

        let recentItem = CPListItem(
            text: "Recent Dispatches",
            detailText: recentCount == 0 ? "Last 24 hours" : "Last \(recentCount) calls"
        )
        recentItem.setImage(carPlayIcon("clock.fill", tintColor: .systemTeal))

        recentItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }

            self.currentScreen = .recent
            self.selectedActiveDispatchId = nil
            self.interfaceController?.pushTemplate(
                self.makeRecentDispatchesTemplate(),
                animated: true,
                completion: nil
            )
            completion()
        }

        let refreshItem = CPListItem(
            text: isLoading ? "Refreshing…" : "Refresh Dispatch Feed",
            detailText: refreshDetailText(isLoading: isLoading)
        )
        refreshItem.setImage(carPlayIcon("arrow.clockwise", tintColor: .systemBlue))

        refreshItem.handler = { [weak self] _, completion in
            self?.refreshDispatches(updateVisibleScreen: true)
            completion()
        }

        let headerItem = CPListItem(
            text: "Morris Township Fire Dept.",
            detailText: activeCount == 0 ? "Dispatch Center • No Active Incidents" : "Dispatch Center • \(activeCount) Active Incident\(activeCount == 1 ? "" : "s")"
        )
        headerItem.setImage(UIImage(named: "MTFDHeaderIcon"))

        var items: [CPListItem] = [headerItem, activeItem, recentItem, refreshItem]

        if let errorMessage = errorMessage ?? lastErrorMessage {
            let errorItem = CPListItem(
                text: dispatchErrorTitle(errorMessage),
                detailText: errorMessage
            )
            errorItem.setImage(carPlayIcon("exclamationmark.triangle.fill", tintColor: .systemYellow))
            items.append(errorItem)
        }

        return CPListTemplate(
            title: "MTFD",
            sections: [
                CPListSection(items: items)
            ]
        )
    }

    // MARK: - Active

    private func makeActiveDispatchesTemplate() -> CPListTemplate {
        let items: [CPListItem]

        if activeDispatches.isEmpty {
            let item = CPListItem(
                text: "No active dispatches",
                detailText: "You are clear at this time"
            )
            item.setImage(carPlayIcon("checkmark.shield.fill", tintColor: .systemGreen))
            items = [item]
        } else {
            items = activeDispatches.map { dispatch in
                let item = CPListItem(
                    text: activeTitle(dispatch),
                    detailText: activeSubtitle(dispatch)
                )
                item.setImage(carPlayIcon(
                    iconName(callType: dispatch.callType, message: dispatch.message),
                    tintColor: iconColor(callType: dispatch.callType, message: dispatch.message)
                ))

                item.handler = { [weak self] _, completion in
                    guard let self else {
                        completion()
                        return
                    }

                    self.currentScreen = .detail
                    self.detailParentScreen = .active
                    self.selectedActiveDispatchId = dispatch.id
                    self.interfaceController?.pushTemplate(
                        self.makeActiveDispatchDetailTemplate(dispatch),
                        animated: true,
                        completion: nil
                    )
                    completion()
                }

                return item
            }
        }

        return CPListTemplate(
            title: "Active Incidents",
            sections: [
                CPListSection(items: items)
            ]
        )
    }

    private func makeActiveDispatchDetailTemplate(_ dispatch: APIClient.ActiveDispatch) -> CPListTemplate {
        var primaryItems: [CPListItem] = []
        var detailItems: [CPListItem] = []
        var navigationItem: CPListItem?

        let typeItem = CPListItem(
            text: "Call Type",
            detailText: activeTitle(dispatch)
        )
        typeItem.setImage(carPlayIcon(
            iconName(callType: dispatch.callType, message: dispatch.message),
            tintColor: iconColor(callType: dispatch.callType, message: dispatch.message)
        ))
        typeItem.handler = { _, completion in
            completion()
        }
        detailItems.append(typeItem)

        if let displayAddress = formattedAddress(placeName: dispatch.placeName, address: dispatch.address, city: dispatch.city, state: dispatch.state) {
            let navigationAddress = navigationAddress(
                placeName: dispatch.placeName,
                address: dispatch.address,
                city: dispatch.city,
                state: dispatch.state
            ) ?? displayAddress

            navigationItem = makeNavigateToCallItem(
                address: navigationAddress,
                displayAddress: displayAddress,
                displayName: activeTitle(dispatch),
                coordinate: coordinate(latitude: dispatch.latitude, longitude: dispatch.longitude)
            )

            let locationItem = CPListItem(text: "Location", detailText: carPlayReadableAddress(displayAddress))
            locationItem.setImage(carPlayIcon("mappin.and.ellipse", tintColor: .systemRed))
            locationItem.handler = { _, completion in
                completion()
            }
            detailItems.append(locationItem)
        }

        if !dispatch.units.isEmpty {
            let unitsItem = CPListItem(text: "Units", detailText: dispatch.units.joined(separator: ", "))
            unitsItem.setImage(carPlayIcon("person.3.fill", tintColor: .systemOrange))
            unitsItem.handler = { _, completion in
                completion()
            }
            detailItems.append(unitsItem)
        }

        if let dispatchedAt = dispatch.dispatchedAt {
            let dispatchedItem = CPListItem(text: "Dispatched", detailText: formatDate(dispatchedAt))
            dispatchedItem.setImage(carPlayIcon("clock.fill", tintColor: .systemTeal))
            dispatchedItem.handler = { _, completion in
                completion()
            }
            detailItems.append(dispatchedItem)
        }

        if let lastRefreshAt {
            let statusItem = CPListItem(
                text: "Feed Updated",
                detailText: formatDate(lastRefreshAt)
            )
            statusItem.setImage(carPlayIcon("checkmark.shield.fill", tintColor: .systemGreen))
            statusItem.handler = { _, completion in
                completion()
            }
            detailItems.append(statusItem)
        }

        if let navigationItem {
            primaryItems.append(navigationItem)
        }

        return CPListTemplate(
            title: "Incident Details",
            sections: makeDispatchDetailSections(primaryItems: primaryItems, detailItems: detailItems)
        )
    }

    // MARK: - Recent

    private func makeRecentDispatchesTemplate() -> CPListTemplate {
        let items: [CPListItem]

        if recentDispatches.isEmpty {
            let item = CPListItem(
                text: "No recent dispatches",
                detailText: "No calls found in the last 24 hours"
            )
            item.setImage(carPlayIcon("clock.badge.xmark", tintColor: .systemGray))
            items = [item]
        } else {
            items = recentDispatches.map { dispatch in
                let item = CPListItem(
                    text: recentTitle(dispatch),
                    detailText: recentSubtitle(dispatch)
                )
                item.setImage(carPlayIcon(
                    iconName(callType: dispatch.callType, message: dispatch.message),
                    tintColor: iconColor(callType: dispatch.callType, message: dispatch.message)
                ))

                item.handler = { [weak self] _, completion in
                    guard let self else {
                        completion()
                        return
                    }

                    self.currentScreen = .detail
                    self.detailParentScreen = .recent
                    self.selectedActiveDispatchId = nil
                    self.interfaceController?.pushTemplate(
                        self.makeRecentDispatchDetailTemplate(dispatch),
                        animated: true,
                        completion: nil
                    )
                    completion()
                }

                return item
            }
        }

        return CPListTemplate(
            title: "Recent Dispatches",
            sections: [
                CPListSection(items: items)
            ]
        )
    }

    private func makeRecentDispatchDetailTemplate(_ dispatch: APIClient.DispatchHistoryItem) -> CPListTemplate {
        var primaryItems: [CPListItem] = []
        var detailItems: [CPListItem] = []
        var navigationItem: CPListItem?

        let typeItem = CPListItem(
            text: "Call Type",
            detailText: recentTitle(dispatch)
        )
        typeItem.setImage(carPlayIcon(
            iconName(callType: dispatch.callType, message: dispatch.message),
            tintColor: iconColor(callType: dispatch.callType, message: dispatch.message)
        ))
        typeItem.handler = { _, completion in
            completion()
        }
        detailItems.append(typeItem)

        if let displayAddress = formattedAddress(
            placeName: dispatch.placeName,
            address: dispatch.address,
            city: dispatch.city,
            state: dispatch.state
        ) {
            let navAddress = navigationAddress(
                placeName: dispatch.placeName,
                address: dispatch.address,
                city: dispatch.city,
                state: dispatch.state
            ) ?? displayAddress

            navigationItem = makeNavigateToCallItem(
                address: navAddress,
                displayAddress: displayAddress,
                displayName: recentTitle(dispatch),
                coordinate: coordinate(latitude: dispatch.latitude, longitude: dispatch.longitude)
            )

            let locationItem = CPListItem(text: "Location", detailText: carPlayReadableAddress(displayAddress))
            locationItem.setImage(carPlayIcon("mappin.and.ellipse", tintColor: .systemRed))
            locationItem.handler = { _, completion in
                completion()
            }
            detailItems.append(locationItem)
        }

        if !dispatch.units.isEmpty {
            let unitsItem = CPListItem(text: "Units", detailText: dispatch.units.joined(separator: ", "))
            unitsItem.setImage(carPlayIcon("person.3.fill", tintColor: .systemOrange))
            unitsItem.handler = { _, completion in
                completion()
            }
            detailItems.append(unitsItem)
        }

        if let tacChannel = dispatch.tacChannel, !tacChannel.isEmpty {
            let tacItem = CPListItem(text: "Tac Channel", detailText: tacChannel)
            tacItem.setImage(carPlayIcon("dot.radiowaves.left.and.right", tintColor: .systemPurple))
            tacItem.handler = { _, completion in
                completion()
            }
            detailItems.append(tacItem)
        }

        if let status = dispatch.status, !status.isEmpty {
            let statusItem = CPListItem(text: "Status", detailText: status)
            statusItem.setImage(carPlayIcon("checkmark.circle.fill", tintColor: .systemGreen))
            statusItem.handler = { _, completion in
                completion()
            }
            detailItems.append(statusItem)
        }

        if let dispatchedAt = dispatch.dispatchedAt {
            let dispatchedItem = CPListItem(text: "Dispatched", detailText: formatDate(dispatchedAt))
            dispatchedItem.setImage(carPlayIcon("clock.fill", tintColor: .systemTeal))
            dispatchedItem.handler = { _, completion in
                completion()
            }
            detailItems.append(dispatchedItem)
        }

        if let navigationItem {
            primaryItems.append(navigationItem)
        }

        return CPListTemplate(
            title: "Dispatch Details",
            sections: makeDispatchDetailSections(primaryItems: primaryItems, detailItems: detailItems)
        )
    }

    // MARK: - Text Helpers

    private func activeTitle(_ dispatch: APIClient.ActiveDispatch) -> String {
        displayCallType(callType: dispatch.callType, message: dispatch.message, isWorkingFire: dispatch.isWorkingFire)
    }

    private func recentTitle(_ dispatch: APIClient.DispatchHistoryItem) -> String {
        displayCallType(callType: dispatch.callType, message: dispatch.message, isWorkingFire: dispatch.isWorkingFire)
    }

    private func activeSubtitle(_ dispatch: APIClient.ActiveDispatch) -> String {
        [
            formattedAddress(placeName: dispatch.placeName, address: dispatch.address, city: dispatch.city, state: dispatch.state),
            dispatch.units.isEmpty ? nil : dispatch.units.joined(separator: ", "),
            dispatch.dispatchedAt.map(formatDate)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private func recentSubtitle(_ dispatch: APIClient.DispatchHistoryItem) -> String {
        [
            formattedAddress(placeName: dispatch.placeName, address: dispatch.address, city: dispatch.city, state: dispatch.state),
            dispatch.units.isEmpty ? nil : dispatch.units.joined(separator: ", "),
            dispatch.dispatchedAt.map(formatDate)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private func makeDispatchDetailSections(
        primaryItems: [CPListItem],
        detailItems: [CPListItem]
    ) -> [CPListSection] {
        var sections: [CPListSection] = []

        if !primaryItems.isEmpty {
            sections.append(CPListSection(items: primaryItems))
        }

        if !detailItems.isEmpty {
            sections.append(CPListSection(items: detailItems))
        }

        return sections
    }

    private func carPlayReadableAddress(_ address: String) -> String {
        let parts = address
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count > 1 else {
            return address
        }

        return parts.joined(separator: ", ")
    }

    private func displayCallType(callType: String, message: String?, isWorkingFire: Bool?) -> String {
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

    private func iconName(callType: String, message: String?) -> String {
        let combined = "\(callType) \(message ?? "")".lowercased()

        if combined.contains("ems") ||
            combined.contains("medical") ||
            combined.contains("cardiac") ||
            combined.contains("breathing") ||
            combined.contains("unconscious") ||
            combined.contains("sick") {
            return "cross.case.fill"
        }

        if combined.contains("mva") ||
            combined.contains("motor vehicle") ||
            combined.contains("accident") ||
            combined.contains("crash") {
            return "car.fill"
        }

        if combined.contains("alarm") {
            return "bell.fill"
        }

        if combined.contains("gas") ||
            combined.contains("odor") ||
            combined.contains("hazmat") {
            return "exclamationmark.triangle.fill"
        }

        return "flame.fill"
    }

    private func iconColor(callType: String, message: String?) -> UIColor {
        let combined = "\(callType) \(message ?? "")".lowercased()

        if combined.contains("ems") ||
            combined.contains("medical") ||
            combined.contains("cardiac") ||
            combined.contains("breathing") ||
            combined.contains("unconscious") ||
            combined.contains("sick") {
            return .systemBlue
        }

        if combined.contains("mva") ||
            combined.contains("motor vehicle") ||
            combined.contains("accident") ||
            combined.contains("crash") {
            return .systemOrange
        }

        if combined.contains("alarm") {
            return .systemYellow
        }

        if combined.contains("gas") ||
            combined.contains("odor") ||
            combined.contains("hazmat") {
            return .systemPurple
        }

        return .systemRed
    }

    private func formattedAddress(placeName: String?, address: String?, city: String?, state: String?) -> String? {
        var parts: [String] = []

        if let placeName, !placeName.isEmpty {
            parts.append(placeName)
        }

        if let address, !address.isEmpty {
            parts.append(address)
        }

        let cityState = [city, state]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")

        if !cityState.isEmpty {
            parts.append(cityState)
        }

        let result = parts.joined(separator: " • ")
        return result.isEmpty ? nil : result
    }


    private func navigationAddress(placeName: String?, address: String?, city: String?, state: String?) -> String? {
        let cleanedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPlaceName = placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedState = state?.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []

        if let cleanedAddress, !cleanedAddress.isEmpty {
            parts.append(cleanedAddress)
        } else if let cleanedPlaceName, !cleanedPlaceName.isEmpty {
            parts.append(cleanedPlaceName)
        }

        if let cleanedCity, !cleanedCity.isEmpty {
            parts.append(cleanedCity)
        } else {
            parts.append("Morris Township")
        }

        if let cleanedState, !cleanedState.isEmpty {
            parts.append(cleanedState)
        } else {
            parts.append("NJ")
        }

        let result = parts.joined(separator: ", ")
        return result.isEmpty ? nil : result
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func refreshDetailText(isLoading: Bool) -> String {
        if isLoading {
            return "Checking MTFD dispatches"
        }

        if let lastRefreshAt {
            return "Last updated \(formatDate(lastRefreshAt))"
        }

        return "Update active and recent calls"
    }

    private func dispatchErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIClient.APIError {
            switch apiError {
            case .missingAuthToken, .sessionExpired, .unauthorized:
                return "Open the MTFD app on iPhone and sign in again."
            case .networkError:
                return "Network unavailable. CarPlay will keep showing the last dispatches it loaded."
            default:
                return apiError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    private func dispatchErrorTitle(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("sign in") {
            return "Sign In Required"
        }

        return "Dispatch Feed Warning"
    }

    private func updateVisibleDetailAfterRefresh() {
        guard let selectedActiveDispatchId else { return }

        if let updatedDispatch = activeDispatches.first(where: { $0.id == selectedActiveDispatchId }) {
            replaceVisibleTemplate(with: makeActiveDispatchDetailTemplate(updatedDispatch), screen: .detail)
            return
        }

        self.selectedActiveDispatchId = nil
        currentScreen = .active
        detailParentScreen = nil
        replaceVisibleTemplate(with: makeActiveDispatchesTemplate(), screen: .active)
    }

    // MARK: - CPInterfaceControllerDelegate

    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
        if let listTemplate = aTemplate as? CPListTemplate {
            switch listTemplate.title {
            case "MTFD":
                currentScreen = .root
                selectedActiveDispatchId = nil
                detailParentScreen = nil
            case "Active Incidents":
                currentScreen = .active
                selectedActiveDispatchId = nil
                detailParentScreen = nil
            case "Recent Dispatches":
                currentScreen = .recent
                selectedActiveDispatchId = nil
                detailParentScreen = nil
            case "Incident Details", "Dispatch Details":
                currentScreen = .detail
            default:
                break
            }
        }
    }

    // MARK: - CarPlay Actions

    private func makeNavigateToCallItem(
        address: String,
        displayAddress: String,
        displayName: String,
        coordinate: CLLocationCoordinate2D?
    ) -> CPListItem {
        let item = CPListItem(
            text: "Navigate to Call",
            detailText: "Start route in Maps"
        )
        item.setImage(carPlayPrimaryActionIcon("arrow.triangle.turn.up.right.circle.fill"))
        item.accessoryType = .disclosureIndicator

        item.handler = { [weak self] _, completion in
            print("🚗 CarPlay Navigate to Call tapped")
            self?.navigateToAddress(
                address,
                displayName: displayName.isEmpty ? displayAddress : displayName,
                coordinate: coordinate
            ) {
                completion()
            }
        }

        return item
    }

    private func carPlayPrimaryActionIcon(_ systemName: String) -> UIImage? {
        carPlayIcon(systemName, tintColor: .systemBlue, weight: .bold)
    }

    private func carPlayIcon(
        _ systemName: String,
        tintColor: UIColor? = nil,
        weight: UIImage.SymbolWeight = .semibold
    ) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(weight: weight)

        guard let image = UIImage(systemName: systemName)?
            .applyingSymbolConfiguration(configuration) else {
            return nil
        }

        if let tintColor {
            return renderedCarPlayIcon(image, tintColor: tintColor)
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    private func renderedCarPlayIcon(_ image: UIImage, tintColor: UIColor) -> UIImage {
        let tintedImage = image.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = tintedImage.scale

        let renderer = UIGraphicsImageRenderer(size: tintedImage.size, format: format)
        let renderedImage = renderer.image { _ in
            tintedImage.draw(in: CGRect(origin: .zero, size: tintedImage.size))
        }

        return renderedImage.withRenderingMode(.alwaysOriginal)
    }

    private func navigateToAddress(
        _ address: String,
        displayName: String,
        coordinate: CLLocationCoordinate2D?,
        completion: @escaping () -> Void = {}
    ) {
        let searchAddress = address.localizedCaseInsensitiveContains("NJ")
            ? address
            : "\(address), Morris Township, NJ"

        print("🚗 CarPlay navigation requested: \(searchAddress)")

        if let coordinate {
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = displayName.isEmpty ? searchAddress : displayName
            showCarPlayNavigation(to: mapItem, displayName: displayName, searchAddress: searchAddress)
            completion()
            return
        }

        CLGeocoder().geocodeAddressString(searchAddress) { placemarks, error in
            DispatchQueue.main.async {
                if let coordinate = placemarks?.first?.location?.coordinate {
                    let placemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = displayName.isEmpty ? searchAddress : displayName

                    print("🚗 CarPlay resolved navigation: \(searchAddress) @ \(coordinate.latitude), \(coordinate.longitude)")

                    self.showCarPlayNavigation(to: mapItem, displayName: displayName, searchAddress: searchAddress)

                    completion()
                    return
                }

                print("🚗 CarPlay navigation geocode failed: \(error?.localizedDescription ?? "Unknown error")")
                self.presentCarPlayNavigationError(address: searchAddress)
                completion()
            }
        }
    }

    private func showCarPlayNavigation(to destination: MKMapItem, displayName: String, searchAddress: String) {
        guard let interfaceController else {
            return
        }

        let origin = MKMapItem.forCurrentLocation()
        origin.name = "Current Location"

        let routeChoice = CPRouteChoice(
            summaryVariants: ["Route to Call", "Dispatch Route"],
            additionalInformationVariants: [carPlayReadableAddress(searchAddress), "CarPlay only"],
            selectionSummaryVariants: ["Start Route"]
        )

        let trip = CPTrip(origin: origin, destination: destination, routeChoices: [routeChoice])
        let destinationName = displayName.isEmpty ? destination.name ?? "Dispatch Location" : displayName
        trip.destinationNameVariants = [destinationName, "Dispatch Location"]

        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self
        mapTemplate.guidanceBackgroundColor = .systemBlue

        let textConfiguration = CPTripPreviewTextConfiguration(
            startButtonTitle: "Navigate",
            additionalRoutesButtonTitle: nil,
            overviewButtonTitle: "Overview"
        )

        interfaceController.pushTemplate(mapTemplate, animated: true) { _, _ in
            mapTemplate.showTripPreviews([trip], selectedTrip: trip, textConfiguration: textConfiguration)
            self.activeNavigationSession = mapTemplate.startNavigationSession(for: trip)
        }
    }

    private func coordinate(latitude: Double?, longitude: Double?) -> CLLocationCoordinate2D? {
        guard let latitude,
              let longitude,
              latitude >= -90,
              latitude <= 90,
              longitude >= -180,
              longitude <= 180,
              latitude != 0,
              longitude != 0 else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func presentCarPlayNavigationError(address: String) {
        let dismissAction = CPAlertAction(title: "OK", style: .cancel) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }

        let alert = CPAlertTemplate(
            titleVariants: [
                "Navigation Unavailable",
                "Could not route to \(address)"
            ],
            actions: [dismissAction]
        )

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        startedTrip trip: CPTrip,
        using routeChoice: CPRouteChoice
    ) {
        activeNavigationSession = mapTemplate.startNavigationSession(for: trip)
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        activeNavigationSession?.cancelTrip()
        activeNavigationSession = nil
    }

    private func presentNewDispatchAlert(_ dispatch: APIClient.ActiveDispatch) {
        guard let interfaceController else { return }

        let viewAction = CPAlertAction(title: "View", style: .default) { [weak self] _ in
            guard let self else { return }

            self.interfaceController?.dismissTemplate(animated: true) { _, _ in
                self.currentScreen = .detail
                self.detailParentScreen = .active
                self.selectedActiveDispatchId = dispatch.id
                self.interfaceController?.pushTemplate(
                    self.makeActiveDispatchDetailTemplate(dispatch),
                    animated: true,
                    completion: nil
                )
            }
        }

        let dismissAction = CPAlertAction(title: "Dismiss", style: .cancel) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }

        let alert = CPAlertTemplate(
            titleVariants: [
                "New Dispatch",
                activeTitle(dispatch)
            ],
            actions: [
                viewAction,
                dismissAction
            ]
        )

        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

}
