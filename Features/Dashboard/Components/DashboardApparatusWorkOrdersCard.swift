import SwiftUI

struct DashboardApparatusWorkOrdersCard: View {
    private static let allApparatusFilterKey = "__all_apparatus__"

    let workOrders: [DashboardApparatusWorkOrder]
    var title: String = "Apparatus Status"
    var subtitle: String? = nil
    var emptyMessage: String = "No open apparatus issues."
    var showsFilters: Bool = true
    let onTap: () -> Void

    @State private var selectedApparatusKey: String = Self.allApparatusFilterKey

    private struct ApparatusFilterOption: Identifiable, Hashable {
        let id: String
        let name: String
        let count: Int
    }

    private var apparatusFilterOptions: [ApparatusFilterOption] {
        let grouped = Dictionary(grouping: workOrders) { workOrder in
            apparatusKey(for: workOrder)
        }

        let apparatusOptions = grouped
            .map { key, orders in
                ApparatusFilterOption(
                    id: key,
                    name: displayName(for: orders.first),
                    count: orders.count
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return [
            ApparatusFilterOption(
                id: Self.allApparatusFilterKey,
                name: "All",
                count: workOrders.count
            )
        ] + apparatusOptions
    }

    private var filteredWorkOrders: [DashboardApparatusWorkOrder] {
        guard selectedApparatusKey != Self.allApparatusFilterKey else {
            return workOrders
        }

        return workOrders.filter {
            apparatusKey(for: $0) == selectedApparatusKey
        }
    }

    private var groupedStatusRows: [(apparatusKey: String, apparatusName: String, workOrders: [DashboardApparatusWorkOrder])] {
        let grouped = Dictionary(grouping: filteredWorkOrders) { workOrder in
            apparatusKey(for: workOrder)
        }

        return grouped
            .map { apparatusKey, orders in
                (
                    apparatusKey: apparatusKey,
                    apparatusName: displayName(for: orders.first),
                    workOrders: orders.sorted { lhs, rhs in
                        lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                lhs.apparatusName.localizedStandardCompare(rhs.apparatusName) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onTap) {
                header
            }
            .buttonStyle(.plain)

            if showsFilters && apparatusFilterOptions.count > 1 {
                filterChips
            }

            if workOrders.isEmpty {
                emptyState(emptyMessage)
            } else if filteredWorkOrders.isEmpty {
                emptyState("No open apparatus issues for \(selectedApparatusLabel).")
            } else {
                DashboardScrollableList(
                    itemCount: groupedStatusRows.count,
                    visibleItemLimit: 3,
                    maxHeight: 245
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(groupedStatusRows.enumerated()), id: \.element.apparatusKey) { index, group in
                            apparatusStatusRow(group)

                            if index < groupedStatusRows.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.14))
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }

            Button(action: onTap) {
                HStack {
                    Text("Open Work Order Board")
                        .font(.caption.bold())

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(AppTheme.gold)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onChange(of: workOrders) { _, _ in
            if !apparatusFilterOptions.contains(where: { $0.id == selectedApparatusKey }) {
                selectedApparatusKey = Self.allApparatusFilterKey
            }
        }
    }

    private var selectedApparatusLabel: String {
        apparatusFilterOptions.first(where: { $0.id == selectedApparatusKey })?.name ?? "All"
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIcon(.apparatus)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("View")
                    .font(.caption.bold())

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .foregroundStyle(AppTheme.gold)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(apparatusFilterOptions) { option in
                    let isSelected = selectedApparatusKey == option.id

                    Button {
                        selectedApparatusKey = option.id
                    } label: {
                        HStack(spacing: 5) {
                            Text(shortApparatusLabel(option.name))
                                .font(.caption.bold())

                            Text("\(option.count)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AppTheme.navy.opacity(0.14) : Color.white.opacity(0.12))
                                )
                        }
                        .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                        .frame(minHeight: 32)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func apparatusStatusRow(
        _ group: (apparatusKey: String, apparatusName: String, workOrders: [DashboardApparatusWorkOrder])
    ) -> some View {
        let first = group.workOrders.first
        let status = first?.status?.trimmingCharacters(in: .whitespacesAndNewlines)
        let issueCount = group.workOrders.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.apparatusName)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)

                    Text(first?.title ?? "Open apparatus issue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    if issueCount > 1 {
                        Text("\(issueCount) open issues")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                Spacer()

                Text(status?.isEmpty == false ? status! : "\(issueCount) open")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.navy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func shortApparatusLabel(_ name: String) -> String {
        name
            .replacingOccurrences(of: "Engine ", with: "E")
            .replacingOccurrences(of: "Truck ", with: "T")
            .replacingOccurrences(of: "Rescue ", with: "R")
            .replacingOccurrences(of: "Ambulance ", with: "A")
            .replacingOccurrences(of: "Command ", with: "C")
    }

    private func apparatusKey(for workOrder: DashboardApparatusWorkOrder) -> String {
        let apiId = workOrder.apparatusApiId?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let apiId, !apiId.isEmpty {
            return "api:\(apiId)"
        }

        let name = workOrder.apparatusName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return name.isEmpty ? "unknown" : "name:\(name)"
    }

    private func displayName(for workOrder: DashboardApparatusWorkOrder?) -> String {
        let name = workOrder?.apparatusName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return name.isEmpty ? "Apparatus" : name
    }
}
