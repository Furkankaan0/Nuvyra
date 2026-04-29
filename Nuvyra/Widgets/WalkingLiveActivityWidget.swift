import ActivityKit
import SwiftUI
import WidgetKit

struct WalkingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkingActivityAttributes.self) { context in
            WalkingLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.06, green: 0.12, blue: 0.13))
                .activitySystemActionForegroundColor(NuvyraColors.softMint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nuvyra")
                            .font(.caption.weight(.bold))
                        Text(context.state.steps.formatted())
                            .font(.title3.weight(.heavy))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Kalan")
                            .font(.caption2.weight(.semibold))
                        Text(context.state.remaining.formatted())
                            .font(.title3.weight(.heavy))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WalkingProgressLine(steps: context.state.steps, goal: context.attributes.goal)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(NuvyraColors.softMint)
            } compactTrailing: {
                Text(context.state.remaining == 0 ? "Tamam" : context.state.remaining.formatted())
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk.circle.fill")
                    .foregroundStyle(NuvyraColors.softMint)
            }
        }
    }
}

private struct WalkingLockScreenView: View {
    let context: ActivityViewContext<WalkingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nuvyra yürüyüş", systemImage: "figure.walk")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(context.state.elapsedMinutes) dk")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline) {
                Text(context.state.steps.formatted())
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("/ \(context.attributes.goal.formatted()) adım")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            WalkingProgressLine(steps: context.state.steps, goal: context.attributes.goal)

            Text(context.state.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .foregroundStyle(.white)
    }
}

private struct WalkingProgressLine: View {
    var steps: Int
    var goal: Int

    private var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Yürüyüş ilerlemesi yüzde \(Int(progress * 100))")
    }
}
