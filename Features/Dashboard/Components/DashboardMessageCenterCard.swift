import SwiftUI

struct DashboardMessageCenterCard: View {
    var messages: [DashboardMessagePreview] = []
    var unreadCount: Int = 0
    let onTap: () -> Void

    @State private var selectedFilter: DashboardMessageTypeFilter = .all

    private var filteredMessages: [DashboardMessagePreview] {
        messages
            .filter { preview in
                selectedFilter.includes(preview)
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) < priorityRank(rhs.priority)
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Messages")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)

                            if unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(messages.isEmpty ? "No active database messages." : "\(messages.count) active message\(messages.count == 1 ? "" : "s") from the message center.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold.opacity(0.9))
                }
            }
            .buttonStyle(.plain)

            if !messages.isEmpty {
                filterScroller

                VStack(spacing: 10) {
                    ForEach(filteredMessages.prefix(4)) { message in
                        messageRow(message)
                    }

                    if filteredMessages.isEmpty {
                        Text("No \(selectedFilter.rawValue.lowercased()) messages.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var filterScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardMessageTypeFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selectedFilter == filter ? Color.black : Color.white.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? AppTheme.gold : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func messageRow(_ message: DashboardMessagePreview) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(message.icon)
                .font(.subheadline)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !message.isRead {
                        Circle()
                            .fill(AppTheme.gold)
                            .frame(width: 7, height: 7)
                    }

                    Text(message.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(2)
                }

                Text("\(message.typeLabel) • \(message.audienceLabel)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.gold.opacity(0.86))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "CRITICAL":
            return 0
        case "HIGH":
            return 1
        default:
            return 2
        }
    }
}
