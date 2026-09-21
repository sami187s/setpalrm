import AlarmKit
import SwiftUI

/// Remembers each scheduled alarm's step goal (AlarmKit can't hand custom
/// data back to us later) and which "re-ring" alarms are pending.
enum AlarmGoals {
    private static let goalsKey = "stepalarm.goals"
    private static let reRingKey = "stepalarm.reRings"

    static func set(_ goal: Int, for id: UUID) {
        var all = UserDefaults.standard.dictionary(forKey: goalsKey) as? [String: Int] ?? [:]
        all[id.uuidString] = goal
        UserDefaults.standard.set(all, forKey: goalsKey)
    }

    static func goal(for id: UUID) -> Int? {
        (UserDefaults.standard.dictionary(forKey: goalsKey) as? [String: Int])?[id.uuidString]
    }

    static var reRingIDs: [UUID] {
        get { (UserDefaults.standard.stringArray(forKey: reRingKey) ?? []).compactMap(UUID.init) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: reRingKey) }
    }
}

/// Wrapper around AlarmManager: authorization, scheduling, cancelling, and
/// the "re-ring" that fires if someone taps the system Stop button without
/// doing their steps.
///
/// NOTE: written without a macOS/Xcode toolchain to compile against the real
/// AlarmKit SDK. If Xcode disagrees with a name here (e.g. the
/// `AlarmConfiguration.alarm(...)` factory), trust Xcode's jump-to-definition.
@Observable
final class AlarmScheduler {
    static let shared = AlarmScheduler()

    private(set) var isAuthorized = false
    private(set) var lastError: String?

    /// Seconds before the alarm rings again after Stop is tapped without walking.
    static let reRingDelay: TimeInterval = 20

    private static let weekdays: [Locale.Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]

    private init() {}

    func requestAuthorizationIfNeeded() async {
        do {
            switch AlarmManager.shared.authorizationState {
            case .authorized:
                isAuthorized = true
            case .notDetermined:
                let state = try await AlarmManager.shared.requestAuthorization()
                isAuthorized = (state == .authorized)
            default:
                isAuthorized = false
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Scheduling

    /// Schedules a saved alarm: once (next occurrence of hour:minute) or
    /// weekly on the chosen days.
    func schedule(_ item: AlarmItem) async {
        let time = Alarm.Schedule.Relative.Time(hour: item.hour, minute: item.minute)
        let repeats: Alarm.Schedule.Relative.Recurrence =
            item.days.isEmpty ? .never : .weekly(item.days.sorted().map { Self.weekdays[$0] })
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: repeats))
        await submit(id: item.id, schedule: schedule, steps: item.steps)
    }

    /// Test alarm: fires N seconds from now with a 15-step goal.
    func scheduleTestAlarm(secondsFromNow: TimeInterval = 120) async {
        let fire = Date().addingTimeInterval(secondsFromNow)
        await submit(id: UUID(), schedule: .fixed(fire), steps: 15)
    }

    /// Rings again shortly after the system Stop button was tapped.
    func scheduleReRing(steps: Int) async {
        let id = UUID()
        AlarmGoals.reRingIDs.append(id)
        let fire = Date().addingTimeInterval(Self.reRingDelay)
        await submit(id: id, schedule: .fixed(fire), steps: steps)
    }

    private func submit(id: UUID, schedule: Alarm.Schedule, steps: Int) async {
        AlarmGoals.set(steps, for: id)

        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let walkButton = AlarmButton(text: "Walk", textColor: .white, systemImageName: "figure.walk")

        let alert = AlarmPresentation.Alert(
            title: "Wake up! Walk \(steps) steps",
            stopButton: stopButton,
            secondaryButton: walkButton,
            secondaryButtonBehavior: .custom
        )

        let attributes = AlarmAttributes<StepAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: StepAlarmMetadata(stepGoal: steps),
            tintColor: Theme.accent
        )

        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id),
            secondaryIntent: WalkToStopIntent(alarmID: id)
        )

        do {
            try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Stopping

    /// Silences a ringing alarm. A repeating alarm keeps its schedule.
    func stopAlarm(_ id: UUID) async {
        try? await AlarmManager.shared.stop(id: id)
    }

    /// Removes an alarm entirely (used for deletes / switching off).
    func cancel(_ id: UUID) async {
        try? await AlarmManager.shared.stop(id: id)
        try? await AlarmManager.shared.cancel(id: id)
    }

    /// Silences and removes every pending re-ring alarm.
    func cancelReRings() async {
        for id in AlarmGoals.reRingIDs {
            await cancel(id)
        }
        AlarmGoals.reRingIDs = []
    }

    // MARK: - Queries

    /// IDs AlarmKit currently knows about (scheduled or ringing), or nil if
    /// the query failed.
    func systemAlarmIDs() -> Set<UUID>? {
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        return Set(alarms.map(\.id))
    }

    /// The alarm that is ringing right now, if any.
    func alertingAlarmID() -> UUID? {
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        return alarms.first(where: { $0.state == .alerting })?.id
    }
}
