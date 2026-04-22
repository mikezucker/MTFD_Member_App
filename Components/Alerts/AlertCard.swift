import SwiftUI

struct AlertCard: View {
    let alert: AppAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(alert.title)
                .font(.headline)

            Text(alert.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundTint)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var backgroundTint: some ShapeStyle {
        switch alert.priority {
        case .critical:
            return AnyShapeStyle(Color.red.opacity(0.18))
        case .urgent:
            return AnyShapeStyle(Color.orange.opacity(0.18))
        case .important:
            return AnyShapeStyle(Color.blue.opacity(0.16))
        case .info:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
