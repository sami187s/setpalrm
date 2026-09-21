import Foundation
import Observation

/// One saved alarm. `days` uses 0 = Sunday … 6 = Saturday; empty = ring once.
struct AlarmItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var steps: Int = 15
    var days: Set<Int> = []
    var isOn: Bool = true

    static func new() -> AlarmItem {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return AlarmItem(hour: now.hour ?? 7, minute: now.minute ?? 0)
    }

    /// Today at this alarm's hour/minute — used only for display and the wheel.
    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    var detail: String {
        var text = "Alarm, \(steps) \(steps == 1 ? "step" : "steps")"
        if !days.isEmpty { text += ", " + Self.repeatSummary(days) }
        return text
    }

    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// "Never", "Every day", "Tue and Sat", "Mon, Wed and Fri".
    static func repeatSummary(_ days: Set<Int>) -> String {
        let names = days.sorted().map { dayNames[$0] }
        switch names.count {
        case 0: return "Never"
        case 7: return "Every day"
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }
}

/// The saved alarm list. Every change is persisted and mirrored into AlarmKit
/// (schedule when on, cancel when off or deleted).
@MainActor @Observable
final class AlarmStore {
    static let shared = AlarmStore()

    private(set) var alarms: [AlarmItem] = []
    private let key = "stepalarm.alarms.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            alarms = saved
        }
    }

    func isSaved(_ id: UUID) -> Bool {
        alarms.contains { $0.id == id }
    }

    func upsert(_ item: AlarmItem) async {
        if let i = alarms.firstIndex(where: { $0.id == item.id }) {
            alarms[i] = item
        } else {
            alarms.append(item)
        }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        save()
        await sync(item)
    }

    func setEnabled(_ id: UUID, _ isOn: Bool) async {
        guard let i = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[i].isOn = isOn
        save()
        await sync(alarms[i])
    }

    func delete(_ id: UUID) async {
        alarms.removeAll { $0.id == id }
        save()
        await AlarmScheduler.shared.cancel(id)
    }

    /// One-time alarms that already rang are gone from AlarmKit, so flip them
    /// off here; repeating alarms that went missing get scheduled again.
    func refreshFromSystem() async {
        guard let live = AlarmScheduler.shared.systemAlarmIDs() else { return }
        for item in alarms where item.isOn && !live.contains(item.id) {
            if item.days.isEmpty {
                if let i = alarms.firstIndex(where: { $0.id == item.id }) { alarms[i].isOn = false }
            } else {
                await AlarmScheduler.shared.schedule(item)
            }
        }
        save()
    }

    private func sync(_ item: AlarmItem) async {
        if item.isOn {
            await AlarmScheduler.shared.schedule(item)
        } else {
            await AlarmScheduler.shared.cancel(item.id)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
