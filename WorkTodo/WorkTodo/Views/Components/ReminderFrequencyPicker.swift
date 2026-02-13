import SwiftUI

struct ReminderFrequencyPicker: View {
    @Binding var frequency: ReminderFrequency
    @Binding var customDays: Int

    var body: some View {
        Section {
            Picker("Reminder", selection: $frequency) {
                ForEach(ReminderFrequency.allCases) { freq in
                    Label(freq.rawValue, systemImage: freq.systemImage)
                        .tag(freq)
                }
            }

            if frequency == .custom {
                Stepper(
                    "Every \(customDays) day\(customDays > 1 ? "s" : "")",
                    value: $customDays,
                    in: 1...365
                )
            }
        } header: {
            Text("Reminders")
        } footer: {
            if frequency != .none {
                Text("You will receive notifications based on this schedule starting from the due date.")
            }
        }
    }
}
