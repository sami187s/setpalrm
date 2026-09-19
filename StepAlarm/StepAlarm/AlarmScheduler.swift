import AlarmKit
import SwiftUI

/// Thin wrapper around AlarmManager for Phase 1: request authorization once,
/// then schedule a single hardcoded test alarm.
///
/// NOTE: written without a macOS/Xcode toolchain available to compile
/// against the real AlarmKit SDK. The overall shape (authorize -> build
/// AlarmAttributes/AlarmPresentation.Alert -> schedule) matches Apple's
/// WWDC25 AlarmKit session and sample code, but verify exact type/method
/// names (e.g. whether `AlarmConfiguration` is nested under `AlarmManager`)
/// via Xcode 26 jump-to-definition before trusting this to build as-is.
@Observable
final class AlarmScheduler {
    static let shared = AlarmScheduler()

    private(set) var isAuthorized = false
    private(set) var lastError: String?

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

    /// Phase 1's hardcoded test alarm: fires N seconds from now, rings via
    /// AlarmKit's system-rendered alert (we don't draw that screen
    /// ourselves), and is silenced only by StopAlarmIntent.
    func scheduleTestAlarm(secondsFromNow: TimeInterval = 120) async {
        let id = UUID()
        let fireDate = Date().addingTimeInterval(secondsFromNow)

        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.fill"
        )

        let alertContent = AlarmPresentation.Alert(
            title: "Step Alarm",
            stopButton: stopButton
        )

        let attributes = AlarmAttributes<StepAlarmMetadata>(
            presentation: AlarmPresentation(alert: alertContent),
            metadata: StepAlarmMetadata(stepGoal: 15),
            tintColor: .red
        )

        let configuration = AlarmManager.AlarmConfiguration(
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id)
        )

        do {
            try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
