import SwiftUI

/// Presentational "Wake Up!" screen: clock, step-progress circle and walking prompt.
struct WakeUpView: View {
    var now: Date = .now
    var stepCount: Int
    var stepGoal: Int
    var isMoving: Bool = false
    var title: String = "Wake Up!"
    var message: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 80, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 24)

            Text(title)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.top, 48)

            ZStack {
                Circle().fill(Theme.surface)
                Circle()
                    .trim(from: 0, to: min(1, Double(stepCount) / Double(max(stepGoal, 1))))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                VStack(spacing: 6) {
                    Text("\(stepCount)")
                        .font(.system(size: 96, weight: .regular))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("of \(stepGoal) steps")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 250, height: 250)
            .padding(.top, 40)
            .animation(.easeOut(duration: 0.3), value: stepCount)

            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(Theme.textPrimary)

            Text("Walk continuously for 3 seconds to count each step")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 32)
                .padding(.top, 20)

            Text(message ?? (isMoving ? "Movement detected" : "Detecting movement..."))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer()

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

/// The live version: reads the walk session (real or demo) and refreshes
/// the clock / "moving" status once a second.
struct WakeUpScreen: View {
    private var session = WalkSession.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            WakeUpView(
                now: context.date,
                stepCount: session.steps,
                stepGoal: session.goal,
                isMoving: session.lastStepDate.map { context.date.timeIntervalSince($0) < 3 } ?? false,
                title: session.isComplete ? "You're up!" : "Wake Up!",
                message: session.motionMessage
            )
        }
    }
}

#Preview {
    WakeUpView(stepCount: 2, stepGoal: 50)
}
