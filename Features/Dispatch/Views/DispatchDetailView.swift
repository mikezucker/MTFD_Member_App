import SwiftUI
import MapKit
import CoreLocation

struct DispatchDetailView: View {
    let dispatch: DispatchNotificationPayload

    @StateObject private var viewModel = DispatchDetailViewModel()
    @State private var refreshTask: Task<Void, Never>?

    private var liveDispatch: LiveDispatchDetail? {
        viewModel.dispatch
    }

    private var callType: String {
        liveDispatch?.callType ?? dispatch.callType ?? dispatch.title
    }

    private var address: String {
        liveDispatch?.address ?? dispatch.address ?? "Unknown Location"
    }

    private var placeName: String? {
        liveDispatch?.placeName
    }

    private var units: [String] {
        if let liveUnits = liveDispatch?.units, !liveUnits.isEmpty {
            return liveUnits
        }

        return dispatch.units
    }

    private var message: String? {
        liveDispatch?.message ?? dispatch.body
    }

    private var isCritical: Bool {
        dispatch.type == .dispatchCritical
    }

    private var coordinatesText: String? {
        guard let latitude = liveDispatch?.latitude,
              let longitude = liveDispatch?.longitude
        else {
            return nil
        }

        return "\(latitude), \(longitude)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            AppDetailHeader(
                title: "Dispatch",
                subtitle: dispatch.callType ?? dispatch.title,
                systemImage: "bell.and.waves.left.and.right.fill"
            )

                VStack(spacing: 16) {
                    headerCard
                    locationCard
                    arrivalPreviewCard
                    unitsCard
                    notesCard
                    metadataCard
                    actionButtons
                }
                .padding()
            }
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Dispatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.load(dispatchId: dispatch.id)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .foregroundStyle(AppTheme.gold)
                }
            }
            .task {
                await viewModel.load(dispatchId: dispatch.id)
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isCritical ? "exclamationmark.triangle.fill" : "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(isCritical ? .red : AppTheme.gold)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isCritical ? "CRITICAL DISPATCH" : "LIVE DISPATCH")
                        .font(.caption.bold())
                        .foregroundStyle(isCritical ? .red : AppTheme.gold)

                    Text(callType)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Live updates active")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Location", icon: "location.fill")

                if let placeName, !placeName.isEmpty {
                    Text(placeName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Text(address)
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))

                if let city = liveDispatch?.city {
                    Text([city, liveDispatch?.state].compactMap { $0 }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                if let coordinatesText {
                    Text(coordinatesText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                }

                Button {
                    openMaps()
                } label: {
                    Label("Navigate to Scene", systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var arrivalPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Arrival Preview", icon: "binoculars.fill")

            DispatchDetailLookAroundPreview(
                address: address,
                city: liveDispatch?.city,
                state: liveDispatch?.state,
                latitude: liveDispatch?.latitude,
                longitude: liveDispatch?.longitude
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var unitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Assigned Units", icon: "truck.box.fill")

            if units.isEmpty {
                Text("No units listed.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                FlowLayout(items: units)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("CAD Notes", icon: "text.alignleft")

            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .textSelection(.enabled)
            } else {
                Text("No CAD notes available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Incident Details", icon: "info.circle.fill")

            detailRow("Dispatch ID", dispatch.id)
            detailRow("Dispatched", liveDispatch?.dispatchedAt ?? "Unavailable")
            detailRow("Last Updated", liveDispatch?.fetchedAt ?? "Unavailable")

            if let tacChannel = liveDispatch?.tacChannel, !tacChannel.isEmpty {
                detailRow("Tac Channel", tacChannel)
            }

            if let status = liveDispatch?.status, !status.isEmpty {
                detailRow("Status", status)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = address
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.1))
                    .foregroundStyle(AppTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.gold)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 95, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)

            Spacer()
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))

                guard !Task.isCancelled else {
                    return
                }

                await viewModel.load(dispatchId: dispatch.id)
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func openMaps() {
        if let latitude = liveDispatch?.latitude,
           let longitude = liveDispatch?.longitude {
            let location = CLLocation(
                latitude: latitude,
                longitude: longitude
            )

            let placemark = MKPlacemark(coordinate: location.coordinate)
            let item = MKMapItem(placemark: placemark)

            item.name = address

            item.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])

            return
        }

        Task {
            do {
                let request = MKLocalSearch.Request()

                let city = liveDispatch?.city?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state = liveDispatch?.state?.trimmingCharacters(in: .whitespacesAndNewlines)

                let searchAddress: String
                if let city, !city.isEmpty {
                    searchAddress = [
                        address,
                        city,
                        state?.isEmpty == false ? state : "NJ"
                    ]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                } else {
                    searchAddress = "\(address), Morris Township, NJ"
                }

                request.naturalLanguageQuery = searchAddress
                request.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 40.7968, longitude: -74.4815),
                    span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                )

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                guard let item = response.mapItems.first else {
                    print("❌ No map item found")
                    return
                }

                item.name = "Dispatch Location"

                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey:
                        MKLaunchOptionsDirectionsModeDriving
                ])
            } catch {
                print("❌ Map search failed:", error.localizedDescription)
            }
        }
    }
}

private struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 82), spacing: 8)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.gold.opacity(0.22))
                    .clipShape(Capsule())
            }
        }
    }
}


private struct DispatchDetailLookAroundPreview: View {
    let address: String
    let city: String?
    let state: String?
    let latitude: Double?
    let longitude: Double?

    @State private var scene: MKLookAroundScene?
    @State private var isLoading = false

    private var normalizedAddress: String {
        normalizeDispatchAddress(address: address, city: city, state: state)
    }

    var body: some View {
        ZStack {
            if let scene {
                LookAroundDetailControllerPreview(scene: scene)
            } else {
                DispatchMapPreview(address: normalizedAddress)
            }

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)

                    Text("Checking Look Around")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                )
            }
        }
        .task(id: normalizedAddress) {
            await loadLookAroundScene()
        }
    }

    private func loadLookAroundScene() async {
        await MainActor.run {
            isLoading = true
            scene = nil
        }

        do {
            let trimmedAddress = normalizedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedAddress.isEmpty, trimmedAddress != "Unknown Location" else {
                await MainActor.run {
                    scene = nil
                    isLoading = false
                }
                return
            }

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

    private func normalizeDispatchAddress(address: String, city: String?, state: String?) -> String {
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

        let cleanCity = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanState = state?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cleanCity, !cleanCity.isEmpty {
            return [
                trimmed,
                cleanCity,
                cleanState?.isEmpty == false ? cleanState : "NJ"
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        }

        return "\(trimmed), Morris Township, NJ"
    }
}

private struct LookAroundDetailControllerPreview: UIViewControllerRepresentable {
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
