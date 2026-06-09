import SwiftUI
import MapKit
import UIKit

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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 23, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(callType)
                            .font(.headline)
                            .foregroundStyle(.white)

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

                DispatchLookAroundCardPreview(address: address)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(isHighlighted ? 0.20 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.red.opacity(0.85), lineWidth: 2)
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
            let searchAddress = address.localizedCaseInsensitiveContains("NJ")
                ? address
                : "\(address), Morristown, NJ"
            request.naturalLanguageQuery = searchAddress
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7968, longitude: -74.4815),
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            guard let item = response.mapItems.first else {
                return
            }

            let newCoordinate = item.placemark.coordinate

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
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmedAddress)

            guard let coordinate = placemarks.first?.location?.coordinate else {
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
            return trimmed
        }

        let lowercased = trimmed.lowercased()

        if lowercased.contains(" nj") ||
            lowercased.contains(",nj") ||
            lowercased.contains("new jersey") ||
            lowercased.contains("morristown") ||
            lowercased.contains("morris township") ||
            lowercased.contains("morris twp") {
            return trimmed
        }

        return "\(trimmed), Morris Township, NJ"
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
