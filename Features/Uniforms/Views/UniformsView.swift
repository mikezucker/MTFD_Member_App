import SwiftUI

struct UniformsView: View {
    var body: some View {
        AppScreen(title: "Uniforms") {
            AppDetailHeader(
                title: "Uniforms",
                subtitle: "Uniform requests and status.",
                systemImage: "tshirt.fill"
            )

            Text("Uniforms Module")
                .foregroundColor(.white)
        }
    }
}
