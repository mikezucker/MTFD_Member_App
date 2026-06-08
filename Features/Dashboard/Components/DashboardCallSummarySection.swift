import SwiftUI

private enum DashboardTotalsScope: String, CaseIterable {
    case department = "Dept"
    case station = "Station"
}

struct DashboardCallSummarySection: View {
    @Binding var selectedWindowRawValue: String

    let department: APIClient.DispatchBucket?
    let station: APIClient.DispatchBucket?
    let isLoading: Bool

    @AppStorage("dashboardTotalsScope") private var selectedScopeRawValue = DashboardTotalsScope.station.rawValue

    private var selectedWindow: DashboardTotalsWindow {
        DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd
    }

    private var selectedScope: DashboardTotalsScope {
        DashboardTotalsScope(rawValue: selectedScopeRawValue) ?? .station
    }

    private var selectedBucket: APIClient.DispatchBucket? {
        switch selectedScope {
        case .department:
            return department
        case .station:
            return station
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Call Totals")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(DashboardTotalsScope.allCases, id: \.rawValue) { scope in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScopeRawValue = scope.rawValue
                            }
                        } label: {
                            Text(scope.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(selectedScope == scope ? AppTheme.navy : .white.opacity(0.72))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedScope == scope ? AppTheme.gold : Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(DashboardTotalsWindow.allCases, id: \.rawValue) { window in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWindowRawValue = window.rawValue
                        }
                    } label: {
                        Text(window.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(selectedWindow == window ? AppTheme.navy : .white.opacity(0.72))
                            .frame(minWidth: 48, minHeight: 34)
                            .padding(.horizontal, 4)
                            .background(
                                Capsule()
                                    .fill(selectedWindow == window ? AppTheme.gold : Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .center, spacing: 0) {
                inlineTotal(
                    value: totalValue,
                    label: selectedScope == .department ? "Department" : "Station"
                )

                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.18))

                inlineTotal(
                    value: fireValue,
                    label: "🔥 Fire"
                )

                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.18))

                inlineTotal(
                    value: emsValue,
                    label: "🚑 EMS"
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 4)
    }

    private var totalValue: Int? {
        value(for: \.total24h, \.total7d, \.total30d, \.totalYtd)
    }

    private var fireValue: Int? {
        value(for: \.fire24h, \.fire7d, \.fire30d, \.fireYtd)
    }

    private var emsValue: Int? {
        value(for: \.ems24h, \.ems7d, \.ems30d, \.emsYtd)
    }

    private func value(
        for last24h: KeyPath<APIClient.DispatchBucket, Int?>,
        _ last7d: KeyPath<APIClient.DispatchBucket, Int?>,
        _ last30d: KeyPath<APIClient.DispatchBucket, Int?>,
        _ ytd: KeyPath<APIClient.DispatchBucket, Int?>
    ) -> Int? {
        guard let selectedBucket else { return nil }

        switch selectedWindow {
        case .last24h:
            return selectedBucket[keyPath: last24h]
        case .last7d:
            return selectedBucket[keyPath: last7d]
        case .last30d:
            return selectedBucket[keyPath: last30d]
        case .ytd:
            return selectedBucket[keyPath: ytd]
        }
    }

    private func inlineTotal(value: Int?, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(height: 38)
            } else if let value {
                Text("\(value)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Text("—")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func horizontalSwipeGesture(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else {
                    return
                }

                if horizontal < 0 {
                    onNext()
                } else {
                    onPrevious()
                }
            }
    }

    private func selectNextWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedWindow) else { return }

        let nextIndex = min(currentIndex + 1, windows.count - 1)

        withAnimation(.easeInOut(duration: 0.22)) {
            selectedWindowRawValue = windows[nextIndex].rawValue
        }
    }

    private func selectPreviousWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedWindow) else { return }

        let previousIndex = max(currentIndex - 1, 0)

        withAnimation(.easeInOut(duration: 0.22)) {
            selectedWindowRawValue = windows[previousIndex].rawValue
        }
    }
}

#Preview {
    DashboardCallSummarySection(
        selectedWindowRawValue: .constant(DashboardTotalsWindow.ytd.rawValue),
        department: APIClient.DispatchBucket(
            total24h: 7,
            total7d: 45,
            total30d: 179,
            totalYtd: 974,
            fire24h: 3,
            fire7d: 19,
            fire30d: 75,
            fireYtd: 438,
            ems24h: 4,
            ems7d: 26,
            ems30d: 98,
            emsYtd: 515,
            other24h: 0,
            other7d: 0,
            other30d: 6,
            otherYtd: 21
        ),
        station: APIClient.DispatchBucket(
            total24h: 1,
            total7d: 6,
            total30d: 28,
            totalYtd: 742,
            fire24h: 0,
            fire7d: 2,
            fire30d: 12,
            fireYtd: 339,
            ems24h: 1,
            ems7d: 4,
            ems30d: 16,
            emsYtd: 387,
            other24h: 0,
            other7d: 0,
            other30d: 0,
            otherYtd: 16
        ),
        isLoading: false
    )
    .padding()
    .background(Color.black)
}
