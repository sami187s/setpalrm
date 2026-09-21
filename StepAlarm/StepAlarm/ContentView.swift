import SwiftUI

/// Home screen styled like the iOS Clock "Alarms" list: Edit / title / +
/// header, big times with small AM/PM, green toggles. Everything here is
/// live: toggles schedule/cancel real alarms, rows open the editor, Edit
/// deletes, and the walk screen appears when an alarm is being dismissed.
struct ContentView: View {
    private var scheduler = AlarmScheduler.shared
    private var liveActivity = LiveActivityController.shared
    private var store = AlarmStore.shared
    private var session = WalkSession.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var isEditing = false
    @State private var sheetAlarm: AlarmItem?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !scheduler.isAuthorized {
                        note("Alarm permission not granted — enable it in Settings > StepAlarm.", isError: true)
                    }
                    if let error = scheduler.lastError { note(error, isError: true) }

                    sectionTitle("Other")
                    if store.alarms.isEmpty {
                        note("No alarms yet. Tap + to add one.")
                    }
                    ForEach(store.alarms) { alarm in
                        alarmRow(alarm)
                        Divider().overlay(Theme.surface)
                    }

                    sectionTitle("Tests").padding(.top, 32)
                    if let error = liveActivity.lastError { note(error, isError: true) }
                    note(liveActivity.statusMessage)

                    testButton("Try the Wake Up screen (simulated steps)") { session.beginDemo() }
                    testButton("Ring a 15-step alarm in 15 seconds") {
                        Task { await scheduler.scheduleTestAlarm(secondsFromNow: 15) }
                    }
                    testButton("Test A: Lock Screen counter (30s)") {
                        liveActivity.startCounterOnlyTest(stepGoal: 15, durationSeconds: 30)
                    }
                    testButton("Test B: alarm + Lock Screen counter") {
                        Task {
                            await liveActivity.startCombinedWithAlarmTest(stepGoal: 15, alarmSecondsFromNow: 30)
                        }
                    }
                    testButton("End test") { liveActivity.endTest() }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $sheetAlarm) { alarm in
            AddAlarmView(
                alarm: alarm,
                title: store.isSaved(alarm.id) ? "Edit Alarm" : "Add Alarm",
                onCancel: { sheetAlarm = nil },
                onSave: { saved in
                    sheetAlarm = nil
                    Task { await store.upsert(saved) }
                }
            )
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: Binding(get: { session.isActive }, set: { _ in })) {
            WakeUpScreen()
        }
        .task {
            await scheduler.requestAuthorizationIfNeeded()
            session.requestMotionPermission()
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            session.refresh()
            Task { await refresh() }
        }
        .onChange(of: session.isActive) { _, active in
            if !active { Task { await store.refreshFromSystem() } }
        }
    }

    /// Sync the list with AlarmKit and jump to the walk screen if an alarm is ringing.
    private func refresh() async {
        await store.refreshFromSystem()
        session.resumeIfAlarmRinging()
    }

    // MARK: - Pieces

    private var header: some View {
        ZStack {
            Text("Alarms")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack {
                Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { sheetAlarm = .new() } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color(white: 0.55))
            .padding(.vertical, 8)
    }

    private func alarmRow(_ alarm: AlarmItem) -> some View {
        HStack(spacing: 12) {
            if isEditing {
                Button {
                    Task { await store.delete(alarm.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }

            Button {
                sheetAlarm = alarm
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(alarm.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                            .font(.system(size: 54, weight: .light))
                        Text(alarm.hour < 12 ? "AM" : "PM")
                            .font(.system(size: 28, weight: .light))
                    }
                    Text(alarm.detail)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.6))
                }
                .foregroundStyle(alarm.isOn ? Theme.textPrimary : Color(white: 0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { alarm.isOn },
                set: { on in Task { await store.setEnabled(alarm.id, on) } }
            ))
            .labelsHidden()
            .tint(Color(red: 0.204, green: 0.78, blue: 0.349)) // iOS green
        }
        .padding(.vertical, 10)
    }

    private func note(_ text: String, isError: Bool = false) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(isError ? Theme.accent : Color(white: 0.6))
            .padding(.vertical, 4)
    }

    private func testButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 10)
        }
    }
}

#Preview {
    ContentView()
}
