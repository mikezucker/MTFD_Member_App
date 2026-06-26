import SwiftUI

struct DashboardApparatusWorkOrdersCard: View {
    let workOrders: [DashboardApparatusWorkOrder]
    var title: String = "Apparatus Status"
    var subtitle: String? = nil
    var emptyMessage: String = "No open apparatus issues."
    var showsFilters: Bool = true
    let onTap: () -> Void

    @State private var selectedApparatusName: String = "All"

    private var apparatusNames: [String] {
        let names = workOrders
            .map(\.apparatusName)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let unique = Array(Set(names)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        return ["All"] + unique
    }

    private var filteredWorkOrders: [DashboardApparatusWorkOrder] {
        guard selectedApparatusName != "All" else {
            return workOrders
        }

        return workOrders.filter { $0.apparatusName == selectedApparatusName }
    }

    private var groupedStatusRows: [(apparatusName: String, workOrders: [DashboardApparatusWorkOrder])] {
        let grouped = Dictionary(grouping: filteredWorkOrders) { workOrder in
            workOrder.apparatusName
        }

        return grouped
            .map { apparatusName, orders in
                (
                    apparatusName: apparatusName,
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
            header

            if showsFilters && apparatusNames.count > 2 {
                filterChips
            }

            if workOrders.isEmpty {
                emptyState(emptyMessage)
            } else if filteredWorkOrders.isEmpty {
                emptyState("No open apparatus issues for \(selectedApparatusName).")
            } else {
                DashboardScrollableList(
                    itemCount: groupedStatusRows.count,
                    maxHeight: 350
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(groupedStatusRows.enumerated()), id: \.element.apparatusName) { index, group in
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
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onChange(of: workOrders) { _, _ in
            if !apparatusNames.contains(selectedApparatusName) {
                selectedApparatusName = "All"
            }
        }
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
                ForEach(apparatusNames, id: \.self) { name in
                    let isSelected = selectedApparatusName == name

                    Button {
                        selectedApparatusName = name
                    } label: {
                        Text(shortApparatusLabel(name))
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                            .frame(minWidth: 44, minHeight: 32)
                            .padding(.horizontal, 6)
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
        _ group: (apparatusName: String, workOrders: [DashboardApparatusWorkOrder])
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
}
