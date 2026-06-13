//
//  CarPlaySceneDelegate.swift
//  MTFD Member App
//

import CarPlay
import Foundation
import MapKit
import CoreLocation
import UIKit

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?

    private var hasConfiguredRootTemplate = false
    private var refreshTimer: Timer?
    private var isLoading = false

    private var activeDispatches: [APIClient.ActiveDispatch] = []
    private var recentDispatches: [APIClient.DispatchHistoryItem] = []
    private var knownActiveDispatchIds = Set<String>()

    private enum CarPlayScreen {
        case root
        case active
        case recent
        case detail
    }

    private var currentScreen: CarPlayScreen = .root

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
        currentScreen = .root

        guard !hasConfiguredRootTemplate else {
            return
        }

        hasConfiguredRootTemplate = true

        interfaceController.setRootTemplate(
            makeRootTemplate(isLoading: true),
            animated: true,
            completion: nil
        )

        startRefreshTimer()
        refreshDispatches(updateVisibleScreen: true)
    }

    private func tearDownCarPlay(interfaceController: CPInterfaceController) {
        stopRefreshTimer()

        if self.interfaceController === interfaceController {
            self.interfaceController = nil
        }

        hasConfiguredRootTemplate = false
        currentScreen = .root
        activeDispatches = []
        recentDispatches = []
        knownActiveDispatchIds = []
        isLoading = false
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

    private func refreshDispatches(updateVisibleScreen: Bool) {
        guard !isLoading else { return }

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

                    self.activeDispatches = resolvedActiveDispatches
                    self.recentDispatches = Array(response.historicalDispatches.prefix(12))
                    self.knownActiveDispatchIds = Set(resolvedActiveDispatches.map(\.id))

                    if let newest = newDispatches.first, !self.knownActiveDispatchIds.isEmpty {
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
                        self.replaceTopTemplate(with: self.makeActiveDispatchesTemplate())
                    case .recent:
                        self.replaceTopTemplate(with: self.makeRecentDispatchesTemplate())
                    case .detail:
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("🚗 CarPlay dispatch refresh failed: \(error.localizedDescription)")

                    guard updateVisibleScreen else { return }

                    self.interfaceController?.setRootTemplate(
                        self.makeRootTemplate(isLoading: false, errorMessage: error.localizedDescription),
                        animated: false,
                        completion: nil
                    )
                }
            }
        }
    }

    private func replaceTopTemplate(with template: CPTemplate) {
        guard let interfaceController else { return }

        if interfaceController.templates.count > 1 {
            interfaceController.popTemplate(animated: false, completion: nil)
            interfaceController.pushTemplate(template, animated: false, completion: nil)
        } else {
            interfaceController.setRootTemplate(template, animated: false, completion: nil)
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
        activeItem.setImage(carPlayIcon("flame.fill"))

        activeItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }

            self.currentScreen = .active
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
        recentItem.setImage(carPlayIcon("clock.fill"))

        recentItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }

            self.currentScreen = .recent
            self.interfaceController?.pushTemplate(
                self.makeRecentDispatchesTemplate(),
                animated: true,
                completion: nil
            )
            completion()
        }

        let refreshItem = CPListItem(
            text: isLoading ? "Refreshing…" : "Refresh Dispatch Feed",
            detailText: isLoading ? "Checking MTFD dispatches" : "Update active and recent calls"
        )
        refreshItem.setImage(carPlayIcon("arrow.clockwise"))

        refreshItem.handler = { [weak self] _, completion in
            self?.refreshDispatches(updateVisibleScreen: true)
            completion()
        }

        let headerItem = CPListItem(
            text: "Morris Township Fire Dept.",
            detailText: activeCount == 0 ? "MTFD Dispatch Center • No Active Incidents" : "MTFD Dispatch Center • \(activeCount) Active Incident\(activeCount == 1 ? "" : "s")"
        )
        headerItem.setImage(UIImage(named: "MTFDLogo"))

        var items: [CPListItem] = [headerItem, activeItem, recentItem, refreshItem]

        if let errorMessage {
            let errorItem = CPListItem(
                text: "Dispatch Feed Error",
                detailText: errorMessage
            )
            errorItem.setImage(carPlayIcon("exclamationmark.triangle.fill"))
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
            item.setImage(carPlayIcon("checkmark.shield.fill"))
            items = [item]
        } else {
            items = activeDispatches.map { dispatch in
                let item = CPListItem(
                    text: activeTitle(dispatch),
                    detailText: activeSubtitle(dispatch)
                )
                item.setImage(carPlayIcon(iconName(callType: dispatch.callType, message: dispatch.message)))

                item.handler = { [weak self] _, completion in
                    guard let self else {
                        completion()
                        return
                    }

                    self.currentScreen = .detail
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
        var items: [CPListItem] = []

        let typeItem = CPListItem(
            text: activeTitle(dispatch),
            detailText: dispatch.message
        )
        typeItem.setImage(carPlayIcon(iconName(callType: dispatch.callType, message: dispatch.message)))
        typeItem.handler = { _, completion in
            completion()
        }
        items.append(typeItem)

        if let displayAddress = formattedAddress(placeName: dispatch.placeName, address: dispatch.address, city: dispatch.city, state: dispatch.state) {
            let navigationAddress = navigationAddress(
                placeName: dispatch.placeName,
                address: dispatch.address,
                city: dispatch.city,
                state: dispatch.state
            ) ?? displayAddress

            let navigateItem = CPListItem(
                text: "Send to Apple Maps",
                detailText: displayAddress
            )
            navigateItem.setImage(carPlayIcon("location.fill"))

            navigateItem.handler = { [weak self] _, completion in
                print("🚗 CarPlay Navigate row tapped")
                self?.navigateToAddress(navigationAddress) {
                    completion()
                }
            }

            items.append(navigateItem)

            let locationItem = CPListItem(text: "Location", detailText: displayAddress)
            locationItem.handler = { _, completion in
                completion()
            }
            items.append(locationItem)
        }

        if !dispatch.units.isEmpty {
            let unitsItem = CPListItem(text: "Units", detailText: dispatch.units.joined(separator: ", "))
            unitsItem.handler = { _, completion in
                completion()
            }
            items.append(unitsItem)
        }

        if let dispatchedAt = dispatch.dispatchedAt {
            let dispatchedItem = CPListItem(text: "Dispatched", detailText: formatDate(dispatchedAt))
            dispatchedItem.handler = { _, completion in
                completion()
            }
            items.append(dispatchedItem)
        }

        return CPListTemplate(
            title: "Incident Details",
            sections: [
                CPListSection(items: items)
            ]
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
            item.setImage(carPlayIcon("clock.badge.xmark"))
            items = [item]
        } else {
            items = recentDispatches.map { dispatch in
                let item = CPListItem(
                    text: recentTitle(dispatch),
                    detailText: recentSubtitle(dispatch)
                )
                item.setImage(carPlayIcon(iconName(callType: dispatch.callType, message: dispatch.message)))

                item.handler = { [weak self] _, completion in
                    guard let self else {
                        completion()
                        return
                    }

                    self.currentScreen = .detail
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
        var items: [CPListItem] = []

        let typeItem = CPListItem(
            text: recentTitle(dispatch),
            detailText: dispatch.message
        )
        typeItem.setImage(carPlayIcon(iconName(callType: dispatch.callType, message: dispatch.message)))
        typeItem.handler = { _, completion in
            completion()
        }
        items.append(typeItem)

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

            let locationItem = CPListItem(text: "Location", detailText: displayAddress)
            locationItem.handler = { _, completion in
                completion()
            }
            items.append(locationItem)

            let navigateItem = CPListItem(
                text: "Send to Apple Maps",
                detailText: "Opens destination in Apple Maps"
            )
            navigateItem.setImage(carPlayIcon("location.fill"))

            navigateItem.handler = { [weak self] _, completion in
                self?.navigateToAddress(navAddress) {
                    completion()
                }
            }

            items.append(navigateItem)
        }

        if !dispatch.units.isEmpty {
            let unitsItem = CPListItem(text: "Units", detailText: dispatch.units.joined(separator: ", "))
            unitsItem.handler = { _, completion in
                completion()
            }
            items.append(unitsItem)
        }

        if let tacChannel = dispatch.tacChannel, !tacChannel.isEmpty {
            let tacItem = CPListItem(text: "Tac Channel", detailText: tacChannel)
            tacItem.handler = { _, completion in
                completion()
            }
            items.append(tacItem)
        }

        if let status = dispatch.status, !status.isEmpty {
            let statusItem = CPListItem(text: "Status", detailText: status)
            statusItem.handler = { _, completion in
                completion()
            }
            items.append(statusItem)
        }

        if let dispatchedAt = dispatch.dispatchedAt {
            let dispatchedItem = CPListItem(text: "Dispatched", detailText: formatDate(dispatchedAt))
            dispatchedItem.handler = { _, completion in
                completion()
            }
            items.append(dispatchedItem)
        }

        return CPListTemplate(
            title: "Dispatch Details",
            sections: [
                CPListSection(items: items)
            ]
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

    // MARK: - CarPlay Actions

    private func carPlayIcon(_ systemName: String) -> UIImage? {
        let color: UIColor

        switch systemName {
        case "cross.case.fill":
            color = .systemBlue
        case "car.fill":
            color = .systemOrange
        case "bell.fill":
            color = .systemYellow
        case "exclamationmark.triangle.fill":
            color = .systemPurple
        case "location.fill":
            color = .systemGreen
        case "checkmark.shield.fill":
            color = .systemGreen
        case "clock.fill", "clock.badge.xmark", "arrow.clockwise":
            color = .systemGray
        default:
            color = .systemRed
        }

        return UIImage(systemName: systemName)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    private func navigateToAddress(_ address: String, completion: @escaping () -> Void = {}) {
        let searchAddress = address.localizedCaseInsensitiveContains("NJ")
            ? address
            : "\(address), Morris Township, NJ"

        print("🚗 CarPlay navigation requested: \(searchAddress)")

        CLGeocoder().geocodeAddressString(searchAddress) { placemarks, error in
            DispatchQueue.main.async {
                if let coordinate = placemarks?.first?.location?.coordinate {
                    let placemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = searchAddress

                    print("🚗 CarPlay opening Apple Maps: \(searchAddress) @ \(coordinate.latitude), \(coordinate.longitude)")

                    MKMapItem.openMaps(
                        with: [mapItem],
                        launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                        ]
                    )

                    completion()
                    return
                }

                print("🚗 CarPlay navigation geocode failed: \(error?.localizedDescription ?? "Unknown error")")

                let encodedAddress = searchAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchAddress
                if let url = URL(string: "maps://?daddr=\(encodedAddress)&dirflg=d") {
                    print("🚗 CarPlay opening Apple Maps fallback URL: \(url.absoluteString)")
                    UIApplication.shared.open(url)
                }

                completion()
            }
        }
    }

    private func presentNewDispatchAlert(_ dispatch: APIClient.ActiveDispatch) {
        guard let interfaceController else { return }

        let viewAction = CPAlertAction(title: "View", style: .default) { [weak self] _ in
            guard let self else { return }

            self.interfaceController?.dismissTemplate(animated: true) { _, _ in
                self.currentScreen = .detail
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
