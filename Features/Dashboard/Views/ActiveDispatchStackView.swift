import SwiftUI

struct ActiveDispatchStackView: View {
    let dispatches: [APIClient.ActiveDispatch]
    let onSelect: (APIClient.ActiveDispatch) -> Void

    var body: some View {
        if !dispatches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(dispatches.count == 1 ? "Other Active Dispatch" : "Other Active Dispatches")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(dispatches.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.9))
                        .clipShape(Capsule())
                }

                ForEach(dispatches) { dispatch in
                    Button {
                        onSelect(dispatch)
                    } label: {
                        ActiveDispatchCard(dispatch: dispatch)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ActiveDispatchCard: View {
    let dispatch: APIClient.ActiveDispatch

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.18))
                    .frame(width: 58, height: 58)

                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(dispatch.callType)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let placeName = dispatch.placeName, !placeName.isEmpty {
                    Text(placeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                if let address = dispatch.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }

                if !dispatch.units.isEmpty {
                    Text(dispatch.units.joined(separator: ", "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.95))
                        .lineLimit(1)
                }

                if let dispatchedAt = dispatch.dispatchedAt {
                    Text("Dispatched \(relativeTime(from: dispatchedAt))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.orange.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var iconName: String {
        let type = dispatch.callType.lowercased()

        if type.contains("ems") ||
            type.contains("medical") ||
            type.contains("sick") ||
            type.contains("hemorrhage") ||
            type.contains("laceration") {
            return "cross.case.fill"
        }

        if type.contains("fire") ||
            type.contains("alarm") ||
            dispatch.isWorkingFire == true {
            return "flame.fill"
        }

        if type.contains("mva") ||
            type.contains("motor vehicle") ||
            type.contains("accident") {
            return "car.fill"
        }

        return "bell.fill"
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
