import SwiftUI

/// "Add Alarm" / "Edit Alarm" sheet: time wheel, steps-to-dismiss slider and
/// weekday repeat. Returns the edited alarm through `onSave`.
struct AddAlarmView: View {
    let alarm: AlarmItem
    let title: String
    var onCancel: () -> Void
    var onSave: (AlarmItem) -> Void

    @State private var time: Date
    @State private var steps: Double
    @State private var days: Set<Int>   // 0 = Sunday … 6 = Saturday

    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let card = Theme.surface
    private let chip = Color(white: 0.24)

    init(alarm: AlarmItem, title: String,
         onCancel: @escaping () -> Void, onSave: @escaping (AlarmItem) -> Void) {
        self.alarm = alarm
        self.title = title
        self.onCancel = onCancel
        self.onSave = onSave
        _time = State(initialValue: alarm.date)
        _steps = State(initialValue: Double(alarm.steps))
        _days = State(initialValue: alarm.days)
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(white: 0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            header

            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            stepsCard
            repeatCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    private var header: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(chip, in: Circle())
                }
                Spacer()
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white, in: Circle())
                }
            }
        }
    }

    private var stepsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Steps to dismiss", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(steps)) \(Int(steps) == 1 ? "step" : "steps")")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)

            Divider().overlay(Color(white: 0.28))

            Slider(value: $steps, in: 1...30, step: 1)
                .tint(.white)

            HStack {
                Text("1 step")
                Spacer()
                Text("30 steps max")
            }
            .font(.caption)
            .foregroundStyle(Color(white: 0.6))
        }
        .padding(16)
        .background(card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var repeatCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Repeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(AlarmItem.repeatSummary(days))
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.6))
            }

            Divider().overlay(Color(white: 0.28))

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let selected = days.contains(i)
                    Button {
                        if selected { days.remove(i) } else { days.insert(i) }
                    } label: {
                        Text(Self.dayLetters[i])
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(selected ? .black : Color(white: 0.6))
                            .frame(width: 40, height: 40)
                            .background(selected ? Color.white : chip, in: Circle())
                    }
                    if i < 6 { Spacer(minLength: 0) }
                }
            }
        }
        .padding(16)
        .background(card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var updated = alarm
        updated.hour = parts.hour ?? alarm.hour
        updated.minute = parts.minute ?? alarm.minute
        updated.steps = Int(steps)
        updated.days = days
        updated.isOn = true
        onSave(updated)
    }
}

#Preview {
    AddAlarmView(alarm: .new(), title: "Add Alarm", onCancel: {}, onSave: { _ in })
}
