//
//  MTFDLiveActivitiesLiveActivity.swift
//  MTFDLiveActivities
//

import ActivityKit
import WidgetKit
import SwiftUI
import Foundation

struct DispatchLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var callType: String
        var address: String
        var units: [String]
        var statusText: String
        var isCritical: Bool
        var isWorkingFire: Bool
        var lastUpdated: Date
    }

    var dispatchId: String
    var startedAt: Date
}

struct MTFDLiveActivitiesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DispatchLiveActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.025, green: 0.075, blue: 0.16))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(appURL(for: context.attributes.dispatchId))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusPill(context: context)

                        Text(context.state.callType)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: context.state.isWorkingFire ? "flame.fill" : "location.fill")
                            .foregroundStyle(context.state.isCritical ? .red : .orange)

                        Text(context.state.lastUpdated, style: .time)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.address)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if !context.state.units.isEmpty {
                            Text(context.state.units.joined(separator: " • "))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                    .foregroundStyle(context.state.isCritical ? .red : .orange)
            } compactTrailing: {
                Text(context.state.units.first ?? "MT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(context.state.isCritical ? .red : .orange)
            }
            .keylineTint(context.state.isCritical ? .red : .orange)
            .widgetURL(appURL(for: context.attributes.dispatchId))
        }
    }

    private func lockScreenView(context: ActivityViewContext<DispatchLiveActivityAttributes>) -> some View {
        let accentColor = context.state.isCritical ? Color.red : Color.orange

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 34, height: 34)

                    Image(systemName: context.state.isCritical ? "exclamationmark.triangle.fill" : "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.statusText.uppercased())
                        .font(.caption2.weight(.black))
                        .foregroundStyle(accentColor)
                        .tracking(0.6)

                    Text("Morris Township Fire")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Text(context.state.lastUpdated, style: .time)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(context.state.callType)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if context.state.isWorkingFire {
                        Text("WORKING")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }

                Text(context.state.address)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if !context.state.units.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "truck.box.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.32))

                        Text(context.state.units.joined(separator: "  •  "))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Tap for details")
                }
                .font(.caption2.weight(.black))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(accentColor.opacity(0.14))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.025, green: 0.075, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.9), lineWidth: 1.5)
        )
        .padding(2)
    }

    private func statusPill(context: ActivityViewContext<DispatchLiveActivityAttributes>) -> some View {
        Text(context.state.isCritical ? "CRITICAL" : "DISPATCH")
            .font(.caption2.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background((context.state.isCritical ? Color.red : Color.orange).opacity(0.85))
            .clipShape(Capsule())
    }

    private func appURL(for dispatchId: String) -> URL {
        URL(string: "mtfdmember://dispatch/\(dispatchId)") ?? URL(string: "mtfdmember://dispatch")!
    }
}

#Preview("Dispatch", as: .content, using: DispatchLiveActivityAttributes(
    dispatchId: "preview",
    startedAt: Date()
)) {
    MTFDLiveActivitiesLiveActivity()
} contentStates: {
    DispatchLiveActivityAttributes.ContentState(
        callType: "Structure Fire",
        address: "123 Test Street",
        units: ["E2", "T1", "C1"],
        statusText: "Critical Dispatch",
        isCritical: true,
        isWorkingFire: true,
        lastUpdated: Date()
    )
}
