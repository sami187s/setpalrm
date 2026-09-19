import AppIntents
import AlarmKit

/// Runs in-process (no app launch, no UI) when the user taps the alarm's
/// Stop button — on the Lock Screen, Dynamic Island, or notification banner.
///
/// NOTE: exact protocol name/requirements for AlarmKit's button intents
/// (`LiveActivityIntent` here) come from Apple's WWDC25 "Wake up to the
/// AlarmKit API" session and sample code. Verify against Xcode 26's
/// jump-to-definition before relying on this — this was written without
/// a macOS/Xcode toolchain available to compile-check it.
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"

    @Parameter(title: "alarmID")
    var alarmIDString: String

    init() {}

    init(alarmID: UUID) {
        self.alarmIDString = alarmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmIDString) {
            try? await AlarmManager.shared.stop(id: id)
        }
        return .result()
    }
}
