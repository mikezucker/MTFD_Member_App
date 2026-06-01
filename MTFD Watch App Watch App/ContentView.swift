//
//  ContentView.swift
//  MTFD Watch App Watch App
//

import SwiftUI

struct WatchDispatch: Identifiable {
    let id: String
    let callType: String
    let address: String
    let units: [String]
    let isCritical: Bool
    let isWorkingFire: Bool
    let updatedAt: Date
}

struct ContentView: View {
    @State private var dispatches: [WatchDispatch] = [
        WatchDispatch(
            id: "preview-1",
            callType: "Structure Fire",
            address: "123 Test Street",
            units: ["E2", "T1", "C1"],
            isCritical: true,
            isWorkingFire: true,
            updatedAt: Date()
        )
    ]

    var body: some View {
        NavigationStack {
            Group {
                if dispatches.isEmpty {
                    noDispatchesView
                } else {
                    List(dispatches) { dispatch in
                        NavigationLink {
                            WatchDispatchDetailView(dispatch: dispatch)
                        } label: {
                            WatchDispatchRow(dispatch: dispatch)
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("MTFD")
        }
    }

    private var noDispatchesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)

            Text("No Active Dispatches")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("You’re clear right now.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct WatchDispatchRow: View {
    let dispatch: WatchDispatch

    private var accentColor: Color {
        dispatch.isCritical ? .red : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: dispatch.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                    .foregroundStyle(accentColor)

                Text(dispatch.isCritical ? "CRITICAL" : "DISPATCH")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(accentColor)

                Spacer()
            }

            Text(dispatch.callType)
                .font(.headline.weight(.bold))
                .lineLimit(1)

            Text(dispatch.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !dispatch.units.isEmpty {
                Text(dispatch.units.joined(separator: " • "))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WatchDispatchDetailView: View {
    let dispatch: WatchDispatch

    private var accentColor: Color {
        dispatch.isCritical ? .red : .orange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: dispatch.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                        .foregroundStyle(accentColor)

                    Text(dispatch.isCritical ? "Critical Dispatch" : "Active Dispatch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentColor)
                }

                Text(dispatch.callType)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)

                if dispatch.isWorkingFire {
                    Text("WORKING FIRE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.red)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Address", systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(dispatch.address)
                        .font(.body.weight(.semibold))
                }

                if !dispatch.units.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Units", systemImage: "truck.box.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text(dispatch.units.joined(separator: " • "))
                            .font(.body.weight(.semibold))
                    }
                }

                Button {
                    // Later: hand off to iPhone dispatch detail.
                } label: {
                    Label("Open on iPhone", systemImage: "iphone")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Dispatch")
    }
}

#Preview {
    ContentView()
}
