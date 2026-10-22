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

            Group {
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

                                        DashboardCardLayoutDefaults.saveHiddenCards(hiddenCards, for: session.currentUser?.role)
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
                    Text("Enabled cards appear in this order, including when there are no current items. Active dispatches appear when available; call totals stay pinned above your cards.")
                }

                Section {
                    Button(role: .destructive) {
                        DashboardCardLayoutDefaults.reset(for: session.currentUser?.role)
                        loadLayout()
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
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
        .onChange(of: session.currentUser?.role) { _, _ in
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
        DashboardCardLayoutDefaults.saveOrder(cards, for: session.currentUser?.role)
    }

    private func loadLayout() {
        cards = DashboardCardLayoutDefaults.savedOrder(for: session.currentUser?.role)
        hiddenCards = DashboardCardLayoutDefaults.hiddenCards(for: session.currentUser?.role)
    }
}
