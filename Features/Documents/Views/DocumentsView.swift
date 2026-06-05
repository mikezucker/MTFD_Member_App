import SwiftUI

struct DocumentsView: View {
    var body: some View {
        AppScreen(title: "Documents") {
            AppDetailHeader(
                title: "Documents",
                subtitle: "SOPs, forms, and assigned acknowledgements.",
                systemImage: "doc.text.fill"
            )

            Text("Documents Module")
                .foregroundColor(.white)
        }
    }
}
