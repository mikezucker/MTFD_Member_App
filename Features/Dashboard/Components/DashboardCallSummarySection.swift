import SwiftUI

struct DashboardCallSummarySection: View {
    @Binding var selectedWindowRawValue: String

    let department: APIClient.DispatchBucket?
    let station: APIClient.DispatchBucket?
    let isLoading: Bool

    private var selectedWindowBinding: Binding<DashboardTotalsWindow> {
        Binding(
            get: {
                DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd
            },
            set: { newValue in
                selectedWindowRawValue = newValue.rawValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Call Totals")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            Picker("", selection: selectedWindowBinding) {
                ForEach(DashboardTotalsWindow.allCases, id: \.self) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 24) {
                totalBlock(
                    label: "Department Total Number",
                    value: departmentValue
                )

                totalBlock(
                    label: "Station Total Number",
                    value: stationValue
                )
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private var departmentValue: Int {
        let selectedWindow = DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd

        switch selectedWindow {
        case .last24h:
            return department?.total24h ?? 0
        case .last7d:
            return department?.total7d ?? 0
        case .last30d:
            return department?.total30d ?? 0
        case .ytd:
            return department?.totalYtd ?? 0
        }
    }

    private var stationValue: Int {
        let selectedWindow = DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd

        switch selectedWindow {
        case .last24h:
            return station?.total24h ?? 0
        case .last7d:
            return station?.total7d ?? 0
        case .last30d:
            return station?.total30d ?? 0
        case .ytd:
            return station?.totalYtd ?? 0
        }
    }

    @ViewBuilder
    private func totalBlock(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DashboardCallSummarySection(
        selectedWindowRawValue: .constant(DashboardTotalsWindow.ytd.rawValue),
        department: APIClient.DispatchBucket(
            total24h: 7,
            total7d: 45,
            total30d: 179,
            totalYtd: 681,
            fire24h: 3,
            fire7d: 19,
            fire30d: 75,
            fireYtd: 317,
            ems24h: 4,
            ems7d: 26,
            ems30d: 98,
            emsYtd: 355
        ),
        station: APIClient.DispatchBucket(
            total24h: 1,
            total7d: 6,
            total30d: 28,
            totalYtd: 562,
            fire24h: 0,
            fire7d: 0,
            fire30d: 0,
            fireYtd: 0,
            ems24h: 0,
            ems7d: 0,
            ems30d: 0,
            emsYtd: 0
        ),
        isLoading: false
    )
    .padding()
    .background(Color.black)
}
