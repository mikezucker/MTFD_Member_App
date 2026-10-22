import SwiftUI

struct AppScreen<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        ZStack {
            AppTheme.navy
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                if !title.isEmpty {
                    AppScreenHeader(
                        title: title,
                        subtitle: subtitle,
                        systemImage: systemImage ?? defaultSystemImage(for: title)
                    )
                }

                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .toolbarBackground(AppTheme.navy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func defaultSystemImage(for title: String) -> String {
        switch title.lowercased() {
        case let value where value.contains("schedule"):
            return "calendar.badge.clock"
        case let value where value.contains("message"):
            return "envelope.fill"
        case let value where value.contains("document"):
            return "doc.text.fill"
        case let value where value.contains("profile"):
            return "person.crop.circle.fill"
        case let value where value.contains("uniform"):
            return "tshirt.fill"
        case let value where value.contains("announcement"):
            return "megaphone.fill"
        case let value where value.contains("work order"):
            return "wrench.and.screwdriver.fill"
        case let value where value.contains("more"):
            return "ellipsis.circle.fill"
        default:
            return "square.grid.2x2.fill"
        }
    }
}

struct AppScreenHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AppDashboardIcon(systemImage: systemImage, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                if let subtitle,
                   !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppTheme.navy)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}
