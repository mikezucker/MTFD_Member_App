import SwiftUI

struct UniformsView: View {
    @State private var response: APIClient.MobileUniformsResponse?
    @State private var drafts: [String: UniformItemDraft] = [:]
    @State private var comments = ""
    @State private var replacementAcknowledged = false
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedItems: [APIClient.UniformRequestSubmissionItem] {
        guard let response else { return [] }

        return response.catalog.flatMap { section in
            section.items.compactMap { item in
                let draft = drafts[draftKey(sectionId: section.id, style: item.style)] ?? UniformItemDraft()
                let size = draft.size.trimmingCharacters(in: .whitespacesAndNewlines)

                guard draft.quantity > 0 else { return nil }

                return APIClient.UniformRequestSubmissionItem(
                    sectionId: section.id,
                    style: item.style,
                    quantity: draft.quantity,
                    size: size
                )
            }
        }
    }

    private var selectedItemCount: Int {
        selectedItems.reduce(0) { $0 + $1.quantity }
    }

    private var hasMissingSize: Bool {
        selectedItems.contains { item in
            item.size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var canSubmitRequest: Bool {
        response?.canSubmit == true
            && selectedItemCount > 0
            && !hasMissingSize
            && replacementAcknowledged
            && !isSubmitting
    }

    var body: some View {
        AppScreen(
            title: "Uniforms",
            subtitle: "Requests, sizing, and status.",
            systemImage: "tshirt.fill"
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading && response == nil {
                        loadingCard
                    } else if let response {
                        summaryCard(response)

                        if response.canSubmit {
                            requestForm(response)
                        } else {
                            restrictedCard
                        }

                        historySection(response.requests)
                    } else if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .refreshable {
                await loadUniforms()
            }
        }
        .task {
            await loadUniforms()
        }
        .alert("Uniform Request", isPresented: successBinding) {
            Button("OK", role: .cancel) { successMessage = nil }
        } message: {
            Text(successMessage ?? "")
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )
    }

    private var loadingCard: some View {
        uniformCard {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.gold)

                Text("Loading uniform requests...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private var restrictedCard: some View {
        uniformCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Uniform request access is not enabled", systemImage: "lock.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Uniform requests are available to career staff and volunteer members who have been assigned uniform-request access.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryCard(_ response: APIClient.MobileUniformsResponse) -> some View {
        let pendingCount = response.requests.filter { $0.status == "PENDING" }.count
        let memberType = response.memberTypeLabel

        return uniformCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(response.canSubmit ? "Request Uniform Items" : "Uniform Status")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        Text(response.canSubmit ? "Build a request and send it to the uniform review queue." : "You can view request history here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    statusBadge(text: memberType, tint: AppTheme.gold)
                }

                HStack(spacing: 8) {
                    statPill(title: "Selected", value: "\(selectedItemCount)", tint: AppTheme.gold)
                    statPill(title: "Pending", value: "\(pendingCount)", tint: pendingCount > 0 ? .orange : .green)
                    statPill(title: "History", value: "\(response.requests.count)", tint: .white.opacity(0.7))
                }
            }
        }
    }

    private func requestForm(_ response: APIClient.MobileUniformsResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            uniformCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Request Details")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Member name, badge number, member type, and request date are attached automatically when this is submitted.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $comments)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(minHeight: 88)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Optional sizing or replacement details")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.38))
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }

            ForEach(response.catalog) { section in
                catalogSection(section)
            }

            uniformCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $replacementAcknowledged) {
                        Text("Replacement uniforms will not be issued until old uniform items have been returned.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .toggleStyle(.switch)
                    .tint(AppTheme.gold)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await submitRequest() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(AppTheme.navy)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }

                            Text(isSubmitting ? "Submitting..." : "Submit Uniform Request")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(AppTheme.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmitRequest ? AppTheme.gold : Color.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmitRequest)
                }
            }
        }
    }

    private func catalogSection(_ section: APIClient.UniformCatalogSection) -> some View {
        uniformCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(section.note)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text("\(selectedCount(in: section)) selected")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.gold)
                        .lineLimit(1)
                }

                VStack(spacing: 12) {
                    ForEach(section.items) { item in
                        catalogItemRow(section: section, item: item)
                    }
                }
            }
        }
    }

    private func catalogItemRow(
        section: APIClient.UniformCatalogSection,
        item: APIClient.UniformCatalogItem
    ) -> some View {
        let key = draftKey(sectionId: section.id, style: item.style)
        let quantity = drafts[key]?.quantity ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.description)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Style #\(item.style)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.48))
                        .textCase(.uppercase)
                }

                Spacer(minLength: 0)

                Stepper(value: quantityBinding(for: key), in: 0...10) {
                    Text("Qty \(quantity)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(quantity > 0 ? AppTheme.gold : .white.opacity(0.54))
                        .frame(minWidth: 48, alignment: .trailing)
                }
                .labelsHidden()
            }

            if quantity > 0 {
                TextField("Size", text: sizeBinding(for: key))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.vertical, 2)
    }

    private func historySection(_ requests: [APIClient.UniformRequest]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Request History", systemImage: "clock.badge.checkmark.fill")

            uniformCard {
                if requests.isEmpty {
                    Text("No uniform requests submitted yet.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    DashboardScrollableList(itemCount: requests.count, maxHeight: 420) {
                        VStack(spacing: 12) {
                            ForEach(requests) { request in
                                historyRow(request)
                            }
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ request: APIClient.UniformRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.referenceCode)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("\(request.totalItems) item\(request.totalItems == 1 ? "" : "s") requested \(formatDate(request.requestedAt))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer(minLength: 0)

                statusBadge(text: request.statusLabel, tint: statusTint(request.status))
            }

            if let assignedTo = request.assignedTo?.displayName {
                Text("Reviewer: \(assignedTo)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            if let reviewNote = request.reviewNote?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reviewNote.isEmpty {
                Text(reviewNote)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(request.items.prefix(4)) { item in
                    Text("\(item.quantity)x \(item.description) • \(item.size)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }

                if request.items.count > 4 {
                    Text("+\(request.items.count - 4) more item\(request.items.count - 4 == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            AppDashboardIcon(systemImage: systemImage, size: 22)

            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func uniformCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func errorCard(_ message: String) -> some View {
        uniformCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Uniforms unavailable")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await loadUniforms() }
                } label: {
                    Text("Try Again")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.navy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.gold)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(tint.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16))
            .clipShape(Capsule())
    }

    private func selectedCount(in section: APIClient.UniformCatalogSection) -> Int {
        section.items.reduce(0) { total, item in
            total + (drafts[draftKey(sectionId: section.id, style: item.style)]?.quantity ?? 0)
        }
    }

    private func quantityBinding(for key: String) -> Binding<Int> {
        Binding(
            get: { drafts[key]?.quantity ?? 0 },
            set: { newValue in
                var draft = drafts[key] ?? UniformItemDraft()
                draft.quantity = max(0, newValue)
                drafts[key] = draft
            }
        )
    }

    private func sizeBinding(for key: String) -> Binding<String> {
        Binding(
            get: { drafts[key]?.size ?? "" },
            set: { newValue in
                var draft = drafts[key] ?? UniformItemDraft()
                draft.size = newValue
                drafts[key] = draft
            }
        )
    }

    private func draftKey(sectionId: String, style: String) -> String {
        "\(sectionId):\(style)"
    }

    private func statusTint(_ status: String) -> Color {
        switch status {
        case "APPROVED":
            return .green
        case "DECLINED":
            return .red
        default:
            return .orange
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func loadUniforms() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            response = try await APIClient.shared.fetchUniforms()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func submitRequest() async {
        guard canSubmitRequest else {
            if selectedItemCount < 1 {
                errorMessage = "Add at least one uniform item."
            } else if hasMissingSize {
                errorMessage = "Size is required for every selected item."
            } else if !replacementAcknowledged {
                errorMessage = "Acknowledge the replacement policy before submitting."
            }

            return
        }

        isSubmitting = true
        errorMessage = nil

        let trimmedComments = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = APIClient.UniformRequestSubmissionRequest(
            comments: trimmedComments.isEmpty ? nil : trimmedComments,
            replacementAcknowledged: replacementAcknowledged,
            items: selectedItems
        )

        do {
            let updated = try await APIClient.shared.submitUniformRequest(payload)
            response = updated
            drafts = [:]
            comments = ""
            replacementAcknowledged = false

            if let request = updated.request {
                successMessage = "\(request.referenceCode) was submitted to the uniform review queue."
            } else {
                successMessage = "Uniform request submitted."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

private struct UniformItemDraft {
    var quantity = 0
    var size = ""
}

private extension APIClient.MobileUniformsResponse {
    var memberTypeLabel: String {
        switch memberType {
        case "CAREER_STAFF":
            return "Career Staff"
        case "WEEKEND_RELIEF_DRIVER":
            return "Relief Driver"
        default:
            return canSubmit ? "Eligible" : "Status"
        }
    }
}

private extension APIClient.UniformRequestPerson {
    var displayName: String? {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        return email?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
