import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen / Dynamic Island content for the throwaway Live Activity
/// test. Styled per the design spec even though this is "just" a test —
/// no reason not to see the real black/white/red look while validating.
///
/// NOTE: written without Xcode available to compile-check. `ActivityConfiguration`,
/// `DynamicIsland`, and the region builders are standard WidgetKit/ActivityKit
/// API (stable since iOS 16.1) so confidence here is high — the uncertain
/// part of this whole feature is the AlarmKit-side integration in
/// LiveActivityController, not this file.
struct StepAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepAlarmActivityAttributes.self) { context in
            VStack(spacing: 8) {
                Text("WALK TO STOP")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("\(context.state.stepCount) / \(context.state.stepGoal)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188)) // #FF3B30
                ProgressView(value: Double(context.state.stepCount), total: Double(context.state.stepGoal))
                    .tint(Color(red: 1, green: 0.231, blue: 0.188))
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.stepCount) / \(context.state.stepGoal)")
                        .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
                        .font(.title2.bold())
                }
            } compactLeading: {
                Text("\(context.state.stepCount)")
                    .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
            } compactTrailing: {
                Text("/\(context.state.stepGoal)")
                    .foregroundStyle(.white)
            } minimal: {
                Text("\(context.state.stepCount)")
                    .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
            }
        }
    }
}
