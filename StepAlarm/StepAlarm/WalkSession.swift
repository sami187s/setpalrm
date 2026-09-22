import CoreMotion
import Observation
import UIKit

/// The "walk to dismiss" logic. While a session is active the Wake Up screen
/// is shown, real steps are counted with CMPedometer, and reaching the goal
/// silences the alarm. `beginDemo` runs the same flow with simulated steps
/// and no alarm, so the screen can be tried without waiting for a ring.
@MainActor @Observable
final class WalkSession {
    static let shared = WalkSession()

    private(set) var isActive = false
    private(set) var isComplete = false
    private(set) var isDemo = false
    private(set) var steps = 0
    private(set) var goal = 15
    private(set) var lastStepDate: Date?
    private(set) var motionMessage: String?

    private var alarmID: UUID?
    private var startDate = Date()
    private var demoTask: Task<Void, Never>?
    @ObservationIgnored private let pedometer = CMPedometer()

    private init() {}

    // MARK: - Starting

    /// Called when the alarm's "Walk" button is tapped, or when the app opens
    /// while an alarm is ringing.
    func begin(alarmID: UUID) {
        guard !isActive else { return }
        start(alarmID: alarmID, goal: AlarmGoals.goal(for: alarmID) ?? 15, demo: false)
    }

    func beginDemo(goal: Int = 15) {
        guard !isActive else { return }
        start(alarmID: nil, goal: goal, demo: true)
    }

    /// If an alarm is ringing while the app comes to the foreground, go
    /// straight to the walking screen.
    func resumeIfAlarmRinging() {
        guard !isActive, let id = AlarmScheduler.shared.alertingAlarmID() else { return }
        begin(alarmID: id)
    }

    /// Triggers the Motion & Fitness permission prompt early, not mid-alarm.
    func requestMotionPermission() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-60), to: Date()) { @Sendable _, _ in }
    }

    private func start(alarmID: UUID?, goal: Int, demo: Bool) {
        self.alarmID = alarmID
        self.goal = goal
        self.isDemo = demo
        steps = 0
        lastStepDate = nil
        motionMessage = nil
        isComplete = false
        startDate = Date()
        isActive = true
        UIApplication.shared.isIdleTimerDisabled = true

        if demo {
            demoTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard let self, !Task.isCancelled else { return }
                    self.apply(count: self.steps + 1, error: nil)
                }
            }
        } else {
            startPedometer()
        }
    }

    // MARK: - Counting

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else {
            motionMessage = "Step counting isn't available on this device."
            return
        }
        pedometer.startUpdates(from: startDate) { @Sendable [weak self] data, error in
            let count = data?.numberOfSteps.intValue
            let message = error?.localizedDescription
            Task { @MainActor in self?.apply(count: count, error: message) }
        }
    }

    /// Steps taken while the app was suspended (phone locked) are read back
    /// from the pedometer's history when the app returns to the foreground.
    func refresh() {
        guard isActive, !isDemo, CMPedometer.isStepCountingAvailable() else { return }
        pedometer.queryPedometerData(from: startDate, to: Date()) { @Sendable [weak self] data, error in
            let count = data?.numberOfSteps.intValue
            let message = error?.localizedDescription
            Task { @MainActor in self?.apply(count: count, error: message) }
        }
    }

    private func apply(count: Int?, error: String?) {
        guard isActive, !isComplete else { return }
        if let error {
            motionMessage = "Allow Motion & Fitness access in Settings. (\(error))"
        }
        if let count, count > steps {
            motionMessage = nil
            steps = count
            lastStepDate = Date()
        }
        if steps >= goal { complete() }
    }

    // MARK: - Finishing

    /// Goal reached: silence the alarm, show the success state briefly, close.
    private func complete() {
        guard !isComplete else { return }
        isComplete = true
        stopCounting()
        let id = alarmID
        let demo = isDemo
        Task {
            if !demo {
                if let id { await AlarmScheduler.shared.stopAlarm(id) }
                await AlarmScheduler.shared.cancelReRings()
            }
            try? await Task.sleep(for: .seconds(2))
            close()
        }
    }

    private func stopCounting() {
        pedometer.stopUpdates()
        demoTask?.cancel()
        demoTask = nil
    }

    private func close() {
        isActive = false
        isComplete = false
        alarmID = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
