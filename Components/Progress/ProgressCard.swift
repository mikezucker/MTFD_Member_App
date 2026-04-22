import SwiftUI

struct ProgressCard: View {
    let title: String
    let progress: Double

    @State private var animatedProgress: Double = 0

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percentText: String {
        "\(Int(clampedProgress * 100))% Complete"
    }

    private var progressGradient: LinearGradient {
        let colors: [Color]

        switch clampedProgress {
        case 0..<0.5:
            // Red
            colors = [
                Color(red: 0.85, green: 0.20, blue: 0.20),
                Color(red: 1.00, green: 0.35, blue: 0.35)
            ]

        case 0.5..<0.8:
            // Yellow
            colors = [
                Color(red: 1.00, green: 0.80, blue: 0.20),
                Color(red: 1.00, green: 0.90, blue: 0.35)
            ]

        default:
            // Green
            colors = [
                Color(red: 0.20, green: 0.70, blue: 0.35),
                Color(red: 0.30, green: 0.85, blue: 0.45)
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 16)

                    Capsule(style: .continuous)
                        .fill(progressGradient)
                        .frame(
                            width: max(24, geometry.size.width * animatedProgress),
                            height: 16
                        )
                        .animation(.easeInOut(duration: 0.6), value: animatedProgress)
                        .animation(.easeInOut(duration: 0.35), value: clampedProgress)
                }
            }
            .frame(height: 16)

            Text(percentText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.35), value: clampedProgress)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.24, blue: 0.48),
                            Color(red: 0.07, green: 0.18, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 8)
        )
        .scaleEffect(animatedProgress > 0 ? 1 : 0.985)
        .opacity(animatedProgress > 0 ? 1 : 0.92)
        .animation(.easeOut(duration: 0.4), value: animatedProgress)
        .onAppear {
            animatedProgress = clampedProgress
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = clampedProgress
            }
        }
    }
}
