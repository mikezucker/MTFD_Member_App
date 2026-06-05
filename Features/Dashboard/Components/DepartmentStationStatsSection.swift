import SwiftUI

struct DepartmentStatItem: Identifiable {
    var id: String { "\(title)-\(subtitle)-\(systemImage)" }
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
}

struct DepartmentStationStatsSection: View {
    let stats: [DepartmentStatItem]
    let onTap: (DepartmentStatItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(stats) { stat in
                Button {
                    onTap(stat)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: stat.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()
                        }

                        Text(stat.value)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(stat.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(stat.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.18, blue: 0.38),
                Color(red: 0.03, green: 0.10, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        DepartmentStationStatsSection(
            stats: [
                DepartmentStatItem(title: "On Duty", value: "18", subtitle: "Dept Members", systemImage: "person.3.fill"),
                DepartmentStatItem(title: "Stations Active", value: "2", subtitle: "Online", systemImage: "building.2.fill"),
                DepartmentStatItem(title: "Apparatus Ready", value: "6", subtitle: "Available", systemImage: "truck.box.fill"),
                DepartmentStatItem(title: "Open Calls", value: "1", subtitle: "Current Incidents", systemImage: "flame.fill")
            ],
            onTap: { _ in }
        )
        .padding()
    }
}
