import SwiftUI

struct DashboardQuickActionTile: View {
    let action: DashboardQuickAction
    let onTap: (AppDestination) -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap(action.destination)
        } label: {
            VStack(spacing: 18) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(iconGradient)
                    .shadow(color: iconShadow.opacity(0.35), radius: 8, x: 0, y: 4)

                Text(action.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.26, blue: 0.52),
                                Color(red: 0.08, green: 0.18, blue: 0.39)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
            )
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }

    private var iconGradient: LinearGradient {
        let t = action.title.lowercased()
        if t.contains("training") {
            return .init(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom)
        } else if t.contains("uniform") {
            return .init(colors: [Color.green, Color.mint], startPoint: .top, endPoint: .bottom)
        } else if t.contains("document") {
            return .init(colors: [Color.blue, Color.cyan], startPoint: .top, endPoint: .bottom)
        } else if t.contains("profile") {
            return .init(colors: [Color.orange, Color.pink], startPoint: .top, endPoint: .bottom)
        }
        return .init(colors: [Color.white.opacity(0.95), Color.white.opacity(0.75)], startPoint: .top, endPoint: .bottom)
    }

    private var iconShadow: Color {
        let t = action.title.lowercased()
        if t.contains("training") { return .yellow }
        if t.contains("uniform") { return .green }
        if t.contains("document") { return .blue }
        if t.contains("profile") { return .orange }
        return .white
    }
}
