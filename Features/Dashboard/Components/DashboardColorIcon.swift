import SwiftUI

struct DashboardColorIcon: View {
    let systemImage: String
    var size: CGFloat = 30
    var frameSize: CGFloat = 42

    private var emoji: String {
        switch systemImage {
        case "envelope.fill", "text.bubble.fill":
            return "📨"
        case "graduationcap.fill":
            return "🎓"
        case "checkmark.seal.fill":
            return "✅"
        case "doc.text.fill":
            return "📄"
        case "wrench.and.screwdriver.fill":
            return "🛠️"
        case "calendar.badge.clock":
            return "🗓️"
        case "person.fill.checkmark":
            return "👤"
        case "clock.arrow.circlepath":
            return "🚨"
        case "chart.bar.fill":
            return "📈"
        case "megaphone.fill":
            return "📣"
        case "building.2.fill":
            return "🏢"
        case "flame.fill":
            return "🔥"
        case "bell.and.waves.left.and.right.fill":
            return "🚨"
        case "shield.lefthalf.filled":
            return "🛡️"
        default:
            return "📌"
        }
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .frame(width: frameSize, height: frameSize)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(Text(systemImage))
    }
}
