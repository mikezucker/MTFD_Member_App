import AppIntents
import SwiftUI

struct SiriShortcutsView: View {
    private let featuredPhrases = [
        "How many department calls at MTFD today",
        "How many department calls at MTFD this year",
        "How many calls for my station at MTFD this year",
        "How many EMS calls at MTFD this year",
        "How many fire calls at MTFD this year",
        "Navigate to the MTFD call",
        "Open the active dispatch in MTFD",
        "When is my next shift in MTFD",
        "Show my MTFD dashboard",
        "Show apparatus work orders in MTFD"
    ]

    private let personalShortcutIdeas = [
        "How many calls at the fire department this year",
        "How many calls did my station run this year",
        "Take me to the call",
        "What is my next shift",
        "Show truck issues"
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("MTFD Siri Shortcuts", systemImage: "sparkles")
                        .font(.headline)

                    Text("Use the built-in phrases below, or create personal shortcuts with the exact wording you prefer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ShortcutsLink()
                }
                .padding(.vertical, 6)
            }

            Section("Built-In Phrases") {
                ForEach(featuredPhrases, id: \.self) { phrase in
                    PhraseRow(phrase: phrase)
                }
            }

            Section("Personal Shortcut Ideas") {
                ForEach(personalShortcutIdeas, id: \.self) { phrase in
                    PhraseRow(phrase: phrase)
                }
            }
        }
        .navigationTitle("Siri Shortcuts")
    }
}

private struct PhraseRow: View {
    let phrase: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.bubble")
                .foregroundStyle(.blue)
                .padding(.top, 2)

            Text(phrase)
                .font(.body)
        }
        .textSelection(.enabled)
    }
}

#if targetEnvironment(simulator)
#Preview {
    NavigationStack {
        SiriShortcutsView()
    }
}
#endif
