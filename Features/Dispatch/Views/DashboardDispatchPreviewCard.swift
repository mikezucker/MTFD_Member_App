import SwiftUI
import MapKit
import CoreLocation
import UIKit


private func constrainedIncidentAddress(_ address: String) -> String {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    if lower.contains("morris township") ||
        lower.contains("morristown") ||
        lower.contains("morris county") {
        return trimmed
    }

    return "\(trimmed), Morristown, NJ"
}

private func isLikelyMorrisArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
    coordinate.latitude >= 40.70 &&
    coordinate.latitude <= 40.95 &&
    coordinate.longitude >= -74.75 &&
    coordinate.longitude <= -74.30
}

private func morrisSearchRegion() -> MKCoordinateRegion {
    MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7968, longitude: -74.4815),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.35)
    )
}

private func requestedAddressNumber(from address: String) -> String? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let match = trimmed.range(of: #"^\d+[A-Za-z]?"#, options: .regularExpression)
    return match.map { String(trimmed[$0]).lowercased() }
}

private func requestedStreetToken(from address: String) -> String? {
    let trimmed = address
        .replacingOccurrences(of: #",.*$"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"^\d+[A-Za-z]?\s+"#, with: "", options: .regularExpression)
        .lowercased()
    let ignored = Set(["street", "st", "road", "rd", "avenue", "ave", "lane", "ln", "drive", "dr", "court", "ct", "place", "pl", "circle", "cir", "way", "route", "rt"])

    return trimmed
        .split(separator: " ")
        .map(String.init)
        .first { token in
            token.count > 2 && !ignored.contains(token)
        }
}

private func isConfidentMorrisPlacemark(_ placemark: CLPlacemark, query: String) -> Bool {
    guard let coordinate = placemark.location?.coordinate,
          isLikelyMorrisArea(coordinate) else {
        return false
    }

    let components = [
        placemark.name,
        placemark.thoroughfare,
        placemark.locality,
        placemark.subLocality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
        placemark.postalCode,
    ]
    .compactMap { $0?.lowercased() }
    .joined(separator: " ")

    let normalizedQuery = query.lowercased()
    let hasNjContext = components.contains(" nj") || components.contains("new jersey") || placemark.administrativeArea == "NJ" || normalizedQuery.contains("nj")
    let hasMorrisContext = components.contains("morris") || components.contains("morristown") || normalizedQuery.contains("morris township") || normalizedQuery.contains("morristown")

    guard hasNjContext, hasMorrisContext else {
        return false
    }

    if let requestedNumber = requestedAddressNumber(from: query),
       let resolvedNumber = placemark.subThoroughfare?.lowercased(),
       resolvedNumber != requestedNumber {
        return false
    }

    if let requestedStreet = requestedStreetToken(from: query),
       let resolvedStreet = [placemark.thoroughfare, placemark.name]
        .compactMap({ $0?.lowercased() })
        .first(where: { !$0.isEmpty }),
       !resolvedStreet.contains(requestedStreet) {
        return false
    }

    return true
}

private func isConfidentMorrisMapItem(_ item: MKMapItem, query: String) -> Bool {
    let placemark = item.placemark
    let coordinate = placemark.coordinate

    guard isLikelyMorrisArea(coordinate) else {
        return false
    }

    let components = [
        placemark.name,
        placemark.thoroughfare,
        placemark.locality,
        placemark.subLocality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
        placemark.postalCode,
    ]
    .compactMap { $0?.lowercased() }
    .joined(separator: " ")

    let normalizedQuery = query.lowercased()
    let hasNjContext = components.contains(" nj") || components.contains("new jersey") || placemark.administrativeArea == "NJ" || normalizedQuery.contains("nj")
    let hasMorrisContext = components.contains("morris") || components.contains("morristown") || normalizedQuery.contains("morris township") || normalizedQuery.contains("morristown")

    guard hasNjContext, hasMorrisContext else {
        return false
    }

    if let requestedNumber = requestedAddressNumber(from: query),
       let resolvedNumber = placemark.subThoroughfare?.lowercased(),
       resolvedNumber != requestedNumber {
        return false
    }

    if let requestedStreet = requestedStreetToken(from: query),
       let resolvedStreet = [placemark.thoroughfare, placemark.name]
        .compactMap({ $0?.lowercased() })
        .first(where: { !$0.isEmpty }),
       !resolvedStreet.contains(requestedStreet) {
        return false
    }

    return true
}

struct DashboardDispatchPreviewCard: View {
    let dispatch: DispatchNotificationPayload
    let isHighlighted: Bool
    let onTap: () -> Void

    private var callType: String {
        dispatch.callType ?? "Dispatch"
    }

    private var address: String {
        dispatch.address ?? "Unknown Location"
    }

    private var alertAccent: Color {
        .red
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(alertAccent.opacity(0.22))
                            .frame(width: 48, height: 48)

                        Image(systemName: dispatch.type == .dispatchCritical ? "flame.fill" : "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(alertAccent.opacity(0.95))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(dispatch.type == .dispatchCritical ? "Critical Dispatch" : "Active Dispatch")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(alertAccent)
                            .textCase(.uppercase)

                        Text(callType)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(2)

                        if !dispatch.units.isEmpty {
                            Text(dispatch.units.joined(separator: ", "))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(alertAccent.opacity(0.95))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack(spacing: 8) {
                    if let callType = dispatch.callType, !callType.isEmpty {
                        dispatchMetaPill(callType)
                    }

                    if let address = dispatch.address, !address.isEmpty {
                        dispatchMetaPill(shortAddress(address))
                    }
                }

                if let dispatchAddress = dispatch.address, !dispatchAddress.isEmpty {
                    DispatchLookAroundCardPreview(address: dispatchAddress)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHighlighted ? 0.18 : 0.11),
                                Color.white.opacity(isHighlighted ? 0.10 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(alertAccent.opacity(isHighlighted ? 0.78 : 0.42), lineWidth: isHighlighted ? 2 : 1)
            )
            .shadow(
                color: isHighlighted ? Color.red.opacity(0.28) : Color.black.opacity(0.12),
                radius: isHighlighted ? 18 : 8,
                y: isHighlighted ? 8 : 4
            )
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .buttonStyle(.plain)
    }

    private func dispatchMetaPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.76))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func shortAddress(_ value: String) -> String {
        value
            .replacingOccurrences(of: ", Morristown, NJ", with: "")
            .replacingOccurrences(of: "Morris Township, NJ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DispatchMapPreview: View {
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
            let searchAddress = constrainedIncidentAddress(address)
            request.naturalLanguageQuery = searchAddress
            request.region = morrisSearchRegion()

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            guard let item = response.mapItems.first(where: { isConfidentMorrisMapItem($0, query: searchAddress) }) else {
                return
            }

            let newCoordinate = item.placemark.coordinate

            guard isLikelyMorrisArea(newCoordinate) else {
                print("❌ Rejecting out-of-area dispatch map coordinate:", newCoordinate.latitude, newCoordinate.longitude)
                return
            }

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

private struct DispatchLookAroundCardPreview: View {
    let address: String

    @State private var scene: MKLookAroundScene?
    @State private var isLoading = false

    private var normalizedAddress: String {
        normalizeDispatchAddress(address)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let scene {
                LookAroundCardControllerPreview(scene: scene)
            } else {
                DispatchMapPreview(address: normalizedAddress)
            }

            if isLoading {
                VStack {
                    Spacer()

                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.white)

                        Text("Checking Look Around")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.45))
                    )
                    .padding(8)
                }
            }
        }
        .task(id: normalizedAddress) {
            await loadLookAroundScene()
        }
    }

    private func loadLookAroundScene() async {
        let trimmedAddress = normalizedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            await MainActor.run {
                scene = nil
                isLoading = false
            }
            return
        }

        guard #available(iOS 16.0, *) else {
            await MainActor.run {
                scene = nil
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            scene = nil
        }

        do {
            let lookupAddress = constrainedIncidentAddress(trimmedAddress)
            let placemarks = try await CLGeocoder().geocodeAddressString(lookupAddress)

            guard let placemark = placemarks.first(where: { isConfidentMorrisPlacemark($0, query: lookupAddress) }),
                  let coordinate = placemark.location?.coordinate else {
                await MainActor.run {
                    scene = nil
                    isLoading = false
                }
                return
            }

            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            let resolvedScene = try await request.scene

            await MainActor.run {
                scene = resolvedScene
                isLoading = false
            }
        } catch {
            await MainActor.run {
                scene = nil
                isLoading = false
            }
        }
    }

    private func normalizeDispatchAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "Unknown Location"
        }

        let lowerAddress = trimmed.lowercased()

        if lowerAddress.contains("morristown") ||
            lowerAddress.contains("morris township") ||
            lowerAddress.contains("morris county") {
            return trimmed
        }

        return "\(trimmed), Morristown, NJ"
    }

}

private struct LookAroundCardControllerPreview: UIViewControllerRepresentable {
    let scene: MKLookAroundScene

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController()
        controller.scene = scene
        return controller
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {
        uiViewController.scene = scene
    }
}
