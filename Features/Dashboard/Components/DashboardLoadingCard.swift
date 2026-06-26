import SwiftUI

struct DashboardLoadingCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ProgressView()
                .tint(.white.opacity(0.85))
        }
        .padding(16)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct DashboardScrollableList<Content: View>: View {
    let itemCount: Int
    var visibleItemLimit: Int = 4
    var maxHeight: CGFloat = 360
    var showsIndicators: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        if itemCount > visibleItemLimit {
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                content()
            }
            .frame(maxHeight: maxHeight)
        } else {
            content()
        }
    }
}
