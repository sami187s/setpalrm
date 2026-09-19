import SwiftUI

/// Phase 1 UI: one hardcoded button, nothing else. Do not add settings,
/// alarm lists, or step counting here yet — those are Phases 2/3/5.
struct ContentView: View {
    private var scheduler = AlarmScheduler.shared
    private var liveActivity = LiveActivityController.shared
    @State private var isScheduling = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Step Alarm — Phase 1")
                .font(.headline)

            if let error = scheduler.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                isScheduling = true
                Task {
                    await scheduler.scheduleTestAlarm(secondsFromNow: 120)
                    isScheduling = false
                }
            } label: {
                Text(isScheduling ? "Scheduling…" : "Set alarm 2 minutes from now")
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScheduling || !scheduler.isAuthorized)
            .padding(.horizontal)

            if !scheduler.isAuthorized {
                Text("Alarm permission not granted yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 8)

            Text("Live Activity validation (design-spec risk item)")
                .font(.subheadline.bold())

            if let error = liveActivity.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Text(liveActivity.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Test A: counter-only Live Activity (30s)") {
                liveActivity.startCounterOnlyTest(stepGoal: 15, durationSeconds: 30)
            }
            .buttonStyle(.bordered)

            Button("Test B: alarm + Live Activity together") {
                Task {
                    await liveActivity.startCombinedWithAlarmTest(stepGoal: 15, alarmSecondsFromNow: 30)
                }
            }
            .buttonStyle(.bordered)

            Button("End test", role: .destructive) {
                liveActivity.endTest()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await scheduler.requestAuthorizationIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
