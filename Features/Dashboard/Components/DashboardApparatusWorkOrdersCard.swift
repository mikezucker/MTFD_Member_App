import SwiftUI

struct DashboardApparatusWorkOrdersCard: View {
    let workOrders: [DashboardApparatusWorkOrder]
    let onTap: () -> Void

    @State private var selectedApparatusName: String?

    private var groupedWorkOrders: [(apparatusName: String, workOrders: [DashboardApparatusWorkOrder])] {
        let grouped = Dictionary(grouping: workOrders) { workOrder in
            workOrder.apparatusName
        }

        return grouped
            .map { apparatusName, orders in
                (
                    apparatusName: apparatusName,
                    workOrders: orders
                )
            }
            .sorted { lhs, rhs in
                lhs.apparatusName.localizedStandardCompare(rhs.apparatusName) == .orderedAscending
            }
    }

    private var selectedGroup: (apparatusName: String, workOrders: [DashboardApparatusWorkOrder])? {
        if let selectedApparatusName,
           let group = groupedWorkOrders.first(where: { $0.apparatusName == selectedApparatusName }) {
            return group
        }

        return groupedWorkOrders.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("Open apparatus issues")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Text("View")
                            .font(.caption.bold())

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            if groupedWorkOrders.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groupedWorkOrders.prefix(6), id: \.apparatusName) { group in
                            let isSelected = selectedGroup?.apparatusName == group.apparatusName

                            Button {
                                selectedApparatusName = group.apparatusName
                            } label: {
                                Text(shortApparatusLabel(group.apparatusName))
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

                        if groupedWorkOrders.count > 6 {
                            Text("+\(groupedWorkOrders.count - 6)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.58))
                                .frame(minHeight: 32)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }

            if let selectedGroup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedGroup.apparatusName)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.gold)
                            .lineLimit(1)

                        Spacer()

                        Text("\(selectedGroup.workOrders.count) open")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                    VStack(spacing: 12) {
                        ForEach(selectedGroup.workOrders.prefix(3)) { workOrder in
                            VStack(alignment: .leading, spacing: 5) {
                                if let status = workOrder.status, !status.isEmpty {
                                    Text(status)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }

                                Text(workOrder.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    if selectedGroup.workOrders.count > 3 {
                        Button(action: onTap) {
                            Text("View all \(selectedGroup.workOrders.count) work orders")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.gold)
                                .padding(.top, 12)
                                .padding(.leading, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No open apparatus work orders.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear {
            if selectedApparatusName == nil {
                selectedApparatusName = groupedWorkOrders.first?.apparatusName
            }
        }
        .onChange(of: workOrders) { _, _ in
            if let selectedApparatusName,
               groupedWorkOrders.contains(where: { $0.apparatusName == selectedApparatusName }) {
                return
            }

            selectedApparatusName = groupedWorkOrders.first?.apparatusName
        }
    }

private func selectNextApparatus() {
        let groups = groupedWorkOrders
        guard !groups.isEmpty else { return }

        let currentName = selectedGroup?.apparatusName ?? groups.first?.apparatusName
        let currentIndex = groups.firstIndex { $0.apparatusName == currentName } ?? 0
        let nextIndex = min(currentIndex + 1, groups.count - 1)

        selectedApparatusName = groups[nextIndex].apparatusName
    }

    private func selectPreviousApparatus() {
        let groups = groupedWorkOrders
        guard !groups.isEmpty else { return }

        let currentName = selectedGroup?.apparatusName ?? groups.first?.apparatusName
        let currentIndex = groups.firstIndex { $0.apparatusName == currentName } ?? 0
        let previousIndex = max(currentIndex - 1, 0)

        selectedApparatusName = groups[previousIndex].apparatusName
    }

    private func shortApparatusLabel(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)

        if trimmed.localizedCaseInsensitiveContains("engine") {
            return digits.isEmpty ? "ENG" : "E\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("ladder") {
            return digits.isEmpty ? "LAD" : "L\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("truck") {
            return digits.isEmpty ? "TRK" : "T\(digits)"
        }

        if trimmed.localizedCaseInsensitiveContains("rescue") {
            return digits.isEmpty ? "RES" : "R\(digits)"
        }

        return String(trimmed.prefix(4)).uppercased()
    }
}
