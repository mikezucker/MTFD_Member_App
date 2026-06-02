import SwiftUI

struct DashboardLayoutView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var cards: [DashboardCardID] = []
    @State private var hiddenCards: Set<DashboardCardID> = []

    var body: some View {
        List {
            Section("Pinned") {
                pinnedRow(title: "Active Dispatches", systemImage: "flame.fill")
                pinnedRow(title: "Call Totals", systemImage: "chart.bar.fill")
            }

            Section {
                ForEach(cards) { card in
                    HStack(spacing: 12) {
                        Image(systemName: card.systemImage)
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        Text(card.title)

                        Spacer()

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { !hiddenCards.contains(card) },
                                set: { isVisible in
                                    if isVisible {
                                        hiddenCards.remove(card)
                                    } else {
                                        hiddenCards.insert(card)
                                    }

                                    DashboardCardLayoutDefaults.saveHiddenCards(hiddenCards)
                                }
                            )
                        )
                        .labelsHidden()
                        .tint(.blue)
                    }
                }
                .onMove(perform: moveCards)
            } header: {
                Text("Customize")
            } footer: {
                Text("Cards can be reordered and hidden. Cards with no current data may not appear on the dashboard even when enabled.")
            }

            Section {
                Button(role: .destructive) {
                    DashboardCardLayoutDefaults.reset()
                    loadLayout()
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Dashboard Layout")
        .toolbar {
            EditButton()
        }
        .onAppear {
            loadLayout()
        }
    }

    private func pinnedRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(title)

            Spacer()

            Text("Pinned")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
        DashboardCardLayoutDefaults.saveOrder(cards)
    }

    private func loadLayout() {
        cards = DashboardCardLayoutDefaults.savedOrder(for: session.currentUser?.role)
        hiddenCards = DashboardCardLayoutDefaults.hiddenCards()
    }
}
