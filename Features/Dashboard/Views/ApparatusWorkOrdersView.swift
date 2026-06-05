import SwiftUI

struct ApparatusWorkOrdersView: View {
    let workOrders: [DashboardApparatusWorkOrder]

    @State private var selectedApparatusId: String?

    private var groupedWorkOrders: [(apparatusId: String, apparatusName: String, workOrders: [DashboardApparatusWorkOrder])] {
        let grouped = Dictionary(grouping: workOrders) { workOrder in
            workOrder.apparatusApiId ?? workOrder.apparatusName
        }

        return grouped
            .map { apparatusId, orders in
                (
                    apparatusId: apparatusId,
                    apparatusName: orders.first?.apparatusName ?? "Apparatus",
                    workOrders: orders.sorted { lhs, rhs in
                        lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                lhs.apparatusName.localizedStandardCompare(rhs.apparatusName) == .orderedAscending
            }
    }

    private var selectedGroup: (apparatusId: String, apparatusName: String, workOrders: [DashboardApparatusWorkOrder])? {
        if let selectedApparatusId,
           let group = groupedWorkOrders.first(where: { $0.apparatusId == selectedApparatusId }) {
            return group
        }

        return groupedWorkOrders.first
    }

    private var totalCount: Int {
        workOrders.count
    }

    var body: some View {
        AppScreen(title: "Work Orders") {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    AppDetailHeader(
                        title: "Apparatus Work Orders",
                        subtitle: "\(totalCount) open item\(totalCount == 1 ? "" : "s") across \(groupedWorkOrders.count) apparatus.",
                        systemImage: "wrench.and.screwdriver.fill"
                    )

                    if groupedWorkOrders.count > 1 {
                        apparatusFilter
                    }

                    if let selectedGroup {
                        selectedApparatusSummary(selectedGroup)

                        LazyVStack(spacing: 10) {
                            ForEach(selectedGroup.workOrders) { workOrder in
                                workOrderRow(workOrder)
                            }
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 120)
            }
        }
        .onAppear {
            if selectedApparatusId == nil {
                selectedApparatusId = groupedWorkOrders.first?.apparatusId
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            DashboardColorIcon(systemImage: "wrench.and.screwdriver.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text("Apparatus Work Orders")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(totalCount) open item\(totalCount == 1 ? "" : "s") across \(groupedWorkOrders.count) apparatus")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var apparatusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupedWorkOrders, id: \.apparatusId) { group in
                    let isSelected = selectedGroup?.apparatusId == group.apparatusId

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedApparatusId = group.apparatusId
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(shortApparatusLabel(group.apparatusName))
                                .font(.caption.bold())

                            Text("\(group.workOrders.count)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AppTheme.navy.opacity(0.16) : Color.white.opacity(0.12))
                                )
                        }
                        .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.78))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func selectedApparatusSummary(
        _ group: (apparatusId: String, apparatusName: String, workOrders: [DashboardApparatusWorkOrder])
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.apparatusName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(group.workOrders.count) open work order\(group.workOrders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    private func workOrderRow(_ workOrder: DashboardApparatusWorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(workOrder.apparatusName)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)
                    .lineLimit(1)

                Spacer()

                if let status = workOrder.status,
                   !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Text(workOrder.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No open apparatus work orders.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text("When apparatus issues are returned by the backend, they will appear here.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func shortApparatusLabel(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.localizedCaseInsensitiveContains("engine") {
            let number = trimmed.filter(\.isNumber)
            return number.isEmpty ? "ENG" : "E\(number)"
        }

        if trimmed.localizedCaseInsensitiveContains("ladder") {
            let number = trimmed.filter(\.isNumber)
            return number.isEmpty ? "LAD" : "L\(number)"
        }

        if trimmed.localizedCaseInsensitiveContains("truck") {
            let number = trimmed.filter(\.isNumber)
            return number.isEmpty ? "TRK" : "T\(number)"
        }

        if trimmed.localizedCaseInsensitiveContains("rescue") {
            let number = trimmed.filter(\.isNumber)
            return number.isEmpty ? "RES" : "R\(number)"
        }

        if trimmed.localizedCaseInsensitiveContains("utility") {
            let number = trimmed.filter(\.isNumber)
            return number.isEmpty ? "UTL" : "U\(number)"
        }

        return String(trimmed.prefix(4)).uppercased()
    }
}

#Preview {
    ApparatusWorkOrdersView(
        workOrders: [
            DashboardApparatusWorkOrder(
                id: "1",
                apparatusApiId: "41806",
                apparatusName: "Engine 2",
                title: "1242 - No A/C",
                status: "Awaiting parts"
            ),
            DashboardApparatusWorkOrder(
                id: "2",
                apparatusApiId: "41806",
                apparatusName: "Engine 2",
                title: "1269 - Horn on steering wheel does not work.",
                status: "Requested"
            ),
            DashboardApparatusWorkOrder(
                id: "3",
                apparatusApiId: "41807",
                apparatusName: "Ladder 1",
                title: "Compartment light not working",
                status: "Pending"
            )
        ]
    )
}
