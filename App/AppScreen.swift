import SwiftUI
import UIKit

// Document and dispatch sheets may use the iPad's working area instead of
// inheriting a narrow phone-sized form sheet. The system clamps to the window.
struct MemberReadingPresentation: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content
                .frame(idealWidth: 1200, idealHeight: 900)
                .presentationSizing(.fitted)
        } else {
            content
        }
    }
}

// Use available window width, rather than a device-name check, so iPad Split
// View and larger accessibility text can return to a single readable column.
struct DashboardCardGrid: Layout {
    var spacing: CGFloat = 22
    var allowsColumns = true

    private func columns(for width: CGFloat) -> Int {
        allowsColumns && width >= 940 ? 2 : 1
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 390
        let columns = columns(for: width)
        let cellWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var height: CGFloat = 0
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let rowHeight = (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            }.max() ?? 0
            height += rowHeight + (start == 0 ? 0 : spacing)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(for: bounds.width)
        let cellWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var y = bounds.minY
        for start in stride(from: 0, to: subviews.count, by: columns) {
            var rowHeight: CGFloat = 0
            for index in start..<min(start + columns, subviews.count) {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil))
                subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(index - start) * (cellWidth + spacing), y: y),
                                     anchor: .topLeading,
                                     proposal: ProposedViewSize(width: cellWidth, height: size.height))
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }
}

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
            .frame(maxWidth: 1200, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
