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

private enum PolicyLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case needsAcknowledgement
    case current

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .needsAcknowledgement:
            return "Needs Ack"
        case .current:
            return "Current"
        }
    }

    var emoji: String {
        switch self {
        case .all:
            return "📚"
        case .needsAcknowledgement:
            return "✍️"
        case .current:
            return "✅"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all:
            return "Try a different search or folder."
        case .needsAcknowledgement:
            return "No policies in this view need acknowledgement."
        case .current:
            return "No current policies match this view."
        }
    }
}

struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @StateObject private var router = NavigationRouter.shared
    @State private var query = ""
    @State private var selectedFolderId: String?
    @State private var selectedFilter = PolicyLibraryFilter.all

    private var filteredDocuments: [APIClient.MobileDocument] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingDocuments: [APIClient.MobileDocument]

        if normalizedQuery.isEmpty {
            matchingDocuments = viewModel.documents
        } else {
            matchingDocuments = viewModel.documents.filter { document in
            document.title.lowercased().contains(normalizedQuery) ||
                (document.description?.lowercased().contains(normalizedQuery) ?? false) ||
                    document.category.lowercased().contains(normalizedQuery) ||
                    folderTitle(for: document.folderId ?? "__unfiled__").lowercased().contains(normalizedQuery)
            }
        }

        switch selectedFilter {
        case .all:
            return matchingDocuments
        case .needsAcknowledgement:
            return matchingDocuments.filter { $0.latestVersion?.requiresAcknowledgement == true }
        case .current:
            return matchingDocuments.filter { $0.latestVersion != nil && $0.latestVersion?.requiresAcknowledgement != true }
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

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleFolders: [APIClient.MobileDocumentFolder] {
        viewModel.folders
            .filter { folder in
                (folder.parentId ?? "") == (selectedFolderId ?? "")
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var visibleDocuments: [APIClient.MobileDocument] {
        if isSearching {
            return filteredDocuments.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return filteredDocuments
            .filter { ($0.folderId ?? "") == (selectedFolderId ?? "") }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var selectedFolder: APIClient.MobileDocumentFolder? {
        guard let selectedFolderId else { return nil }
        return viewModel.folders.first { $0.id == selectedFolderId }
    }

    private var folderBreadcrumbs: [APIClient.MobileDocumentFolder] {
        guard let selectedFolder else { return [] }

        var breadcrumbs = [selectedFolder]
        var parentId = selectedFolder.parentId
        var visited = Set([selectedFolder.id])

        while let id = parentId,
              let parent = viewModel.folders.first(where: { $0.id == id }),
              !visited.contains(parent.id) {
            breadcrumbs.insert(parent, at: 0)
            visited.insert(parent.id)
            parentId = parent.parentId
        }

        return breadcrumbs
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
                    filterBar

                    if viewModel.isLoading && viewModel.documents.isEmpty {
                        loadingCard
                    } else if let error = viewModel.errorMessage {
                        errorCard(error)
                    } else if filteredDocuments.isEmpty {
                        emptyCard
                    } else {
                        libraryHeaderCard
                        statusMetrics
                        pendingAcknowledgementSection
                        policyLibrarySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .onChange(of: viewModel.folders.map(\.id)) { _, folderIds in
                if let selectedFolderId, !folderIds.contains(selectedFolderId) {
                    self.selectedFolderId = nil
                }
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PolicyLibraryFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(filter.emoji)
                                .font(.caption)

                            Text(filter.title)
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(selectedFilter == filter ? AppTheme.navy : .white.opacity(0.76))
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(selectedFilter == filter ? AppTheme.gold : Color.white.opacity(0.09))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var libraryHeaderCard: some View {
        HStack(alignment: .top, spacing: 12) {
            policyEmojiBadge(selectedFolderId == nil ? "📚" : "📁", size: 38, fontSize: 22)

            VStack(alignment: .leading, spacing: 6) {
                Text(selectedFolder?.name ?? "All Policies")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(libraryHeaderSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                if selectedFolderId != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedFolderId = selectedFolder?.parentId
                        }
                    } label: {
                        Label("Up one folder", systemImage: "arrow.up.left")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var libraryHeaderSubtitle: String {
        if isSearching {
            return "\(filteredDocuments.count) result\(filteredDocuments.count == 1 ? "" : "s") for your search."
        }

        let folderCount = visibleFolders.count
        let documentCount = visibleDocuments.count
        return "\(folderCount) folder\(folderCount == 1 ? "" : "s") and \(documentCount) polic\(documentCount == 1 ? "y" : "ies") shown."
    }

    private var statusMetrics: some View {
        HStack(spacing: 10) {
            policyMetric(title: "Policies", value: "\(filteredDocuments.count)", emoji: "📄")
            policyMetric(title: "Current", value: "\(currentCount(in: filteredDocuments))", emoji: "✅", color: .green)
            policyMetric(title: "Waiting", value: "\(pendingDocuments.count)", emoji: "✍️", color: .orange, isWarning: !pendingDocuments.isEmpty)
        }
    }

    @ViewBuilder
    private var pendingAcknowledgementSection: some View {
        if !pendingDocuments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Text("✍️")
                        Text("Awaiting Acknowledgement")
                    }
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
                HStack(spacing: 8) {
                    Text("📁")
                    Text("Policy Library")
                }
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

            if isSearching {
                searchResultsSection
            } else {
                folderNavigation

                VStack(spacing: 10) {
                    ForEach(visibleFolders) { folder in
                        folderRow(folder)
                    }

                    ForEach(visibleDocuments) { document in
                        documentRow(document)
                    }
                }

                if visibleFolders.isEmpty && visibleDocuments.isEmpty {
                    emptyFolderCard
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(spacing: 10) {
            ForEach(visibleDocuments) { document in
                documentRow(document, showFolder: true)
            }
        }
    }

    private var folderNavigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Button("All Policies") {
                    selectedFolderId = nil
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(selectedFolderId == nil ? AppTheme.gold : .white.opacity(0.66))
                .buttonStyle(.plain)

                ForEach(folderBreadcrumbs) { folder in
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.4))

                    Button(folder.name) {
                        selectedFolderId = folder.id
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(folder.id == selectedFolderId ? AppTheme.gold : .white.opacity(0.66))
                    .lineLimit(1)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func folderRow(_ folder: APIClient.MobileDocumentFolder) -> some View {
                Button {
                    selectedFolderId = folder.id
                } label: {
            HStack(spacing: 12) {
                policyEmojiBadge("📁", size: 34, fontSize: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(folderCountLine(folder))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var emptyFolderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("📭")
                Text("Nothing here")
            }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(selectedFilter.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("🔎")
                Text("No policies found")
            }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(selectedFilter.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
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
                policyEmojiBadge(documentEmoji(for: document), size: 34, fontSize: 20)

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
        emoji: String,
        color: Color = AppTheme.gold,
        isWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.caption)

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

    private func folderCountLine(_ folder: APIClient.MobileDocumentFolder) -> String {
        let childFolderCount = viewModel.folders.filter { $0.parentId == folder.id }.count
        let documentCount = filteredDocuments.filter { $0.folderId == folder.id }.count

        if childFolderCount == 0 {
            return "\(documentCount) polic\(documentCount == 1 ? "y" : "ies")"
        }

        if documentCount == 0 {
            return "\(childFolderCount) folder\(childFolderCount == 1 ? "" : "s")"
        }

        return "\(childFolderCount) folder\(childFolderCount == 1 ? "" : "s") / \(documentCount) polic\(documentCount == 1 ? "y" : "ies")"
    }

    private func documentEmoji(for document: APIClient.MobileDocument) -> String {
        switch document.category.uppercased() {
        case "POLICY":
            return "📋"
        case "SOP", "SOG":
            return "🚒"
        case "TRAINING":
            return "🎓"
        case "FORM":
            return "📝"
        default:
            return "📄"
        }
    }

    private func policyEmojiBadge(_ emoji: String, size: CGFloat = 34, fontSize: CGFloat = 20) -> some View {
        Text(emoji)
            .font(.system(size: fontSize))
            .frame(width: size, height: size)
            .background(AppTheme.gold.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 9))
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
