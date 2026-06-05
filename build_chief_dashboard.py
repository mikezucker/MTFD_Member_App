from pathlib import Path

path = Path("Features/Dashboard/Views/ChiefDashboardView.swift")

path.write_text("""import SwiftUI

struct ChiefDashboardView: View {

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                Text("Chief Dashboard")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 180)
                    .overlay {
                        Text("Dispatch Card")
                            .foregroundStyle(.white)
                    }

                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 120)
                    .overlay {
                        Text("Call Totals")
                            .foregroundStyle(.white)
                    }

                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 200)
                    .overlay {
                        Text("Schedule Outlook")
                            .foregroundStyle(.white)
                    }
            }
            .padding()
        }
    }
}
""")

print("✅ ChiefDashboardView.swift updated")
