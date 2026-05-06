import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct NuvyraWalkingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NuvyraWalkingAttributes.self) { context in
            NuvyraWalkingLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.05, green: 0.10, blue: 0.12))
                .activitySystemActionForegroundColor(NuvyraColors.softMint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adım")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.steps.formatted())
                            .font(.title3.weight(.heavy))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Enerji")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.formattedCalories)
                            .font(.title3.weight(.heavy))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.elapsedMinutes) dk", systemImage: "timer")
                        Spacer()
                        Text(context.attributes.sessionName)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "figure.walk.circle.fill")
                    .foregroundStyle(NuvyraColors.softMint)
            } compactTrailing: {
                Text(context.state.steps.formatted())
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(NuvyraColors.softMint)
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NuvyraWalkingLockScreenView: View {
    let context: ActivityViewContext<NuvyraWalkingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(context.attributes.sessionName, systemImage: "figure.walk.motion")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(context.state.elapsedMinutes) dk")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 18) {
                NuvyraWalkingMetric(title: "Adım", value: context.state.steps.formatted())
                NuvyraWalkingMetric(title: "Kalori", value: context.state.formattedCalories)
            }

            Text(context.state.summary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nuvyra yürüyüş. \(context.state.summary)")
    }
}

private struct NuvyraWalkingMetric: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
