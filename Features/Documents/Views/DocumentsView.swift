import Combine
import PDFKit
import SwiftUI

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published var documents: [APIClient.MobileDocument] = []
    @Published var folders: [APIClient.MobileDocumentFolder] = []
    @Published var selectedDocument: APIClient.MobileDocument?
    @Published var selectedPDF: PDFDocument?
    @Published var isLoading = false
    @Published var isOpening = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.fetchDocuments()
            documents = response.documents
            folders = response.folders
            hasLoaded = true
        } catch {
            errorMessage = policyCenterErrorMessage(for: error)
        }

        isLoading = false
    }

    func open(_ document: APIClient.MobileDocument) async {
        guard let version = document.latestVersion else { return }

        isOpening = true
        errorMessage = nil

        do {
            let data = try await APIClient.shared.downloadDocumentVersion(versionId: version.id)
            guard let pdf = PDFDocument(data: data) else {
                errorMessage = "This policy cannot be previewed in the app."
                isOpening = false
                return
            }

            selectedDocument = document
            selectedPDF = pdf
        } catch {
            errorMessage = policyCenterErrorMessage(for: error)
        }

        isOpening = false
    }

    func markAcknowledged() async {
        await refresh()
        if let current = selectedDocument,
           let updated = documents.first(where: { $0.id == current.id }) {
            selectedDocument = updated
        }
    }

    func openDocument(id documentId: String?) async {
        guard let documentId else { return }
        if !hasLoaded {
            await refresh()
        }
        guard let document = documents.first(where: { $0.id == documentId }) else { return }
        await open(document)
    }

    private func policyCenterErrorMessage(for error: Error) -> String {
        if case APIClient.APIError.serverError(let statusCode, _) = error,
           statusCode == 404 {
            return "Policy Center is not available on the server yet. Please try again after the site update finishes."
        }

        return error.localizedDescription
    }
}

struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @StateObject private var router = NavigationRouter.shared
    @State private var query = ""

    private var filteredDocuments: [APIClient.MobileDocument] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return viewModel.documents }

        return viewModel.documents.filter { document in
            document.title.lowercased().contains(normalizedQuery) ||
                (document.description?.lowercased().contains(normalizedQuery) ?? false) ||
                document.category.lowercased().contains(normalizedQuery)
        }
    }

    private var requiredCount: Int {
        viewModel.documents.filter { $0.latestVersion?.requiresAcknowledgement == true }.count
    }

    private var headerSubtitle: String {
        if viewModel.isLoading && viewModel.documents.isEmpty {
            return "Loading policies and SOPs..."
        }

        if requiredCount > 0 {
            return "\(requiredCount) \(requiredCount == 1 ? "policy needs" : "policies need") acknowledgement."
        }

        if viewModel.documents.isEmpty {
            return "Policies, SOPs, forms, and assigned acknowledgements."
        }

        return "All \(viewModel.documents.count) assigned \(viewModel.documents.count == 1 ? "policy is" : "policies are") current."
    }

    private var pendingDocuments: [APIClient.MobileDocument] {
        filteredDocuments.filter { $0.latestVersion?.requiresAcknowledgement == true }
    }

    private var folderSections: [PolicyFolderSection] {
        let grouped = Dictionary(grouping: filteredDocuments) { document in
            document.folderId ?? "__unfiled__"
        }

        return grouped.map { folderId, documents in
            PolicyFolderSection(
                id: folderId,
                title: folderTitle(for: folderId),
                documents: documents.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )
        }
        .sorted { lhs, rhs in
            if lhs.id == "__unfiled__" { return false }
            if rhs.id == "__unfiled__" { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        AppScreen(
            title: "Policy Center",
            subtitle: headerSubtitle,
            systemImage: "doc.text.fill"
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField

                    if viewModel.isLoading && viewModel.documents.isEmpty {
                        loadingCard
                    } else if let error = viewModel.errorMessage {
                        errorCard(error)
                    } else if filteredDocuments.isEmpty {
                        emptyCard
                    } else {
                        statusMetrics
                        pendingAcknowledgementSection
                        policyLibrarySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: router.documentToOpen?.id) { _, _ in
            let payload = router.documentToOpen
            Task {
                await viewModel.openDocument(id: payload?.documentId ?? payload?.id)
                router.clearDocumentRoute()
            }
        }
        .sheet(item: $viewModel.selectedDocument) { document in
            if let pdf = viewModel.selectedPDF {
                DocumentPDFPreview(document: document, pdf: pdf) {
                    await viewModel.markAcknowledged()
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.58))

            TextField("Search Policy Center", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusMetrics: some View {
        HStack(spacing: 10) {
            policyMetric(title: "Policies", value: "\(filteredDocuments.count)", systemImage: "doc.text.fill")
            policyMetric(title: "Current", value: "\(currentCount(in: filteredDocuments))", systemImage: "checkmark.seal.fill", color: .green)
            policyMetric(title: "Waiting", value: "\(pendingDocuments.count)", systemImage: "signature", color: .orange, isWarning: !pendingDocuments.isEmpty)
        }
    }

    @ViewBuilder
    private var pendingAcknowledgementSection: some View {
        if !pendingDocuments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Awaiting Acknowledgement", systemImage: "signature")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(pendingDocuments.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.orange)
                        .clipShape(Capsule())
                }

                VStack(spacing: 10) {
                    ForEach(pendingDocuments) { document in
                        documentRow(document, highlighted: true, showFolder: true)
                    }
                }
            }
            .padding(14)
            .background(Color.orange.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var policyLibrarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Policy Library")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(filteredDocuments.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
            }

            ForEach(folderSections) { section in
                folderSection(section)
            }
        }
    }

    private func folderSection(_ section: PolicyFolderSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: section.id == "__unfiled__" ? "tray.fill" : "folder.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.gold)

                Text(section.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                Text("\(section.documents.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                ForEach(section.documents) { document in
                    documentRow(document)
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.gold)
            Text("Loading Policy Center...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unable to load Policy Center")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            Button("Try Again") {
                Task { await viewModel.refresh() }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.gold)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emptyCard: some View {
        Text("No policies found.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func documentRow(
        _ document: APIClient.MobileDocument,
        highlighted: Bool = false,
        showFolder: Bool = false
    ) -> some View {
        Button {
            Task { await viewModel.open(document) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: documentIcon(for: document))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(highlighted ? .orange : AppTheme.gold)
                    .frame(width: 30, height: 30)
                    .background((highlighted ? Color.orange : AppTheme.gold).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(document.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Spacer(minLength: 8)
                    }

                    if let description = document.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                    }

                    if showFolder {
                        Text(folderTitle(for: document.folderId ?? "__unfiled__"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        statusPill(document.category)

                        if let version = document.latestVersion {
                            statusPill("v\(version.version)")

                            if version.requiresAcknowledgement {
                                statusPill("Needs acknowledgement", tint: .orange)
                            } else if version.assigned {
                                statusPill("Acknowledged", tint: .green)
                            } else {
                                statusPill("Current")
                            }
                        } else {
                            statusPill("No file", tint: .orange)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(highlighted ? 0.10 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(highlighted ? Color.orange.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(document.latestVersion == nil)
    }

    private func policyMetric(
        title: String,
        value: String,
        systemImage: String,
        color: Color = AppTheme.gold,
        isWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isWarning ? Color.orange.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusPill(_ text: String, tint: Color? = nil) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint ?? .white.opacity(0.82))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint?.opacity(0.15) ?? Color.white.opacity(0.10))
            .clipShape(Capsule())
    }

    private func currentCount(in documents: [APIClient.MobileDocument]) -> Int {
        documents.filter { $0.latestVersion != nil && $0.latestVersion?.requiresAcknowledgement != true }.count
    }

    private func documentIcon(for document: APIClient.MobileDocument) -> String {
        switch document.category.uppercased() {
        case "POLICY":
            return "checklist.checked"
        case "SOP", "SOG":
            return "list.bullet.clipboard.fill"
        case "TRAINING":
            return "graduationcap.fill"
        case "FORM":
            return "square.and.pencil"
        default:
            return "doc.text.fill"
        }
    }

    private func folderTitle(for folderId: String) -> String {
        guard folderId != "__unfiled__",
              let folder = viewModel.folders.first(where: { $0.id == folderId }) else {
            return "Unfiled"
        }

        var names = [folder.name]
        var currentParentId = folder.parentId
        var visited = Set([folder.id])

        while let parentId = currentParentId,
              let parent = viewModel.folders.first(where: { $0.id == parentId }),
              !visited.contains(parent.id) {
            names.insert(parent.name, at: 0)
            visited.insert(parent.id)
            currentParentId = parent.parentId
        }

        return names.joined(separator: " / ")
    }
}

private struct PolicyFolderSection: Identifiable {
    let id: String
    let title: String
    let documents: [APIClient.MobileDocument]
}

struct DocumentPDFPreview: View {
    let document: APIClient.MobileDocument
    let pdf: PDFDocument
    let onAcknowledged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isSigning = false
    @State private var signError: String?
    @State private var signedAt: Date?

    private var latestVersion: APIClient.MobileDocumentVersion? {
        document.latestVersion
    }

    private var needsSignature: Bool {
        latestVersion?.requiresAcknowledgement == true && signedAt == nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFKitView(document: pdf)

                if needsSignature {
                    signPanel
                } else if let acknowledgedAt = signedAt ?? latestVersion?.acknowledgedAt {
                    acknowledgedPanel(acknowledgedAt)
                }
            }
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }

    private var signPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acknowledgement required")
                .font(.headline.weight(.bold))

            Text("Enter your account password after reviewing this policy. Your signature is recorded with date, time, device, and network details.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let signError {
                Text(signError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            Button {
                Task { await signDocument() }
            } label: {
                HStack {
                    if isSigning {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSigning ? "Signing..." : "Sign & Acknowledge")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AppTheme.navy)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSigning || password.isEmpty)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func acknowledgedPanel(_ date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("Acknowledged \(date.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func signDocument() async {
        guard let versionId = latestVersion?.id else { return }

        isSigning = true
        signError = nil

        do {
            let response = try await APIClient.shared.acknowledgeDocumentVersion(
                versionId: versionId,
                password: password
            )

            guard response.success else {
                signError = response.error ?? "Could not record acknowledgement."
                isSigning = false
                return
            }

            signedAt = response.acknowledgedAt ?? Date()
            password = ""
            await onAcknowledged()
        } catch {
            signError = error.localizedDescription
        }

        isSigning = false
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
