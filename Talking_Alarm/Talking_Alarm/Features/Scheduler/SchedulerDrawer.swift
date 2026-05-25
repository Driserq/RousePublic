import SwiftUI

struct SchedulerDrawer: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void

    @State private var scheduleDraft: [Int: Date] = [:]
    @State private var isEditing = false
    @State private var selectedDays: Set<Int> = []
    @State private var isTimePickerPresented = false
    @State private var timeDraft: Date = Date()
    @State private var isOverrideConflictAlertPresented = false

    private let weekDays: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    ZStack {
                        Text("SCHEDULES")
                            .font(.headline)
                            .tracking(2)
                            .foregroundColor(.white)

                        HStack {
                            Button(action: toggleEdit) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.leading, 20)

                            Spacer()

                            Button(action: handleClose) {
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.trailing, 20)
                            }
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                    VStack(spacing: 14) {
                        ForEach(weekDays, id: \.0) { day in
                            DayRow(
                                label: day.1,
                                timeText: timeText(for: day.0),
                                isActive: scheduleDraft[day.0] != nil,
                                isSelected: selectedDays.contains(day.0),
                                isEditing: isEditing
                            )
                            .onTapGesture {
                                handleDayTap(day.0)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)

                    if isEditing {
                        HStack(spacing: 12) {
                            Button(action: { isTimePickerPresented = true }) {
                                Text("Set Time")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .disabled(selectedDays.isEmpty)
                            .opacity(selectedDays.isEmpty ? 0.4 : 1)

                            Button(action: clearSelectedDays) {
                                Text("Turn Off")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .disabled(selectedDays.isEmpty)
                            .opacity(selectedDays.isEmpty ? 0.4 : 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }

                    Spacer()

                    Text(isEditing ? "Select days, then set a time • Tap Done to save" : "Tap Edit to change days")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $isTimePickerPresented) {
                NavigationView {
                    VStack(spacing: 24) {
                        ZStack {
                            AlarmPickerView(time: $timeDraft)

                            VStack(spacing: 0) {
                                Text(timeDraft.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                                Text(timePeriod(for: timeDraft))
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .allowsHitTesting(false)
                        }

                        Text("Drag the sun/moon to set time")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.35))

                        Spacer()
                    }
                    .navigationTitle("Set Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isTimePickerPresented = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") {
                                if wouldConflictWithDailyOverride {
                                    isTimePickerPresented = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isOverrideConflictAlertPresented = true
                                    }
                                } else {
                                    applyTimeAndSave()
                                    selectedDays.removeAll()
                                    isTimePickerPresented = false
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadDraft()
            }
            .alert("Replace Adjusted Alarm?", isPresented: $isOverrideConflictAlertPresented) {
                Button("Replace", role: .destructive) {
                    clearDailyOverrideApplyAndSave()
                    selectedDays.removeAll()
                }
                Button("Keep Adjusted", role: .cancel) {
                    selectedDays.removeAll()
                }
            } message: {
                Text(overrideConflictMessage)
            }
        }
    }

    private func loadDraft() {
        scheduleDraft = appState.alarmSchedule
        if scheduleDraft.isEmpty, !appState.alarmDays.isEmpty {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: appState.alarmDate)
            if let dateWithTime = calendar.date(bySettingHour: components.hour ?? 7, minute: components.minute ?? 0, second: 0, of: Date()) {
                for day in appState.alarmDays {
                    scheduleDraft[day] = dateWithTime
                }
            }
        }
    }

    private func toggleEdit() {
        if isEditing {
            selectedDays.removeAll()
        }
        isEditing.toggle()
    }

    private func handleDayTap(_ day: Int) {
        guard isEditing else { return }
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
            if let existing = scheduleDraft[day] {
                timeDraft = existing
            }
        }
    }

    private func timeText(for day: Int) -> String {
        guard let time = scheduleDraft[day] else { return "Off" }
        return TimeUtils.formatTime(time)
    }

    private func applyTimeToSelection() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: timeDraft)
        guard let hour = components.hour, let minute = components.minute else { return }
        guard let dateWithTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) else { return }
        for day in selectedDays {
            scheduleDraft[day] = dateWithTime
        }
    }

    private func applyTimeAndSave() {
        applyTimeToSelection()
        saveChanges()
    }

    private func clearDailyOverrideApplyAndSave() {
        appState.dailyOverrideDate = nil
        appState.dailyOverrideTime = nil
        appState.suppressedScheduleKey = nil
        appState.suppressedScheduleDate = nil
        applyTimeToSelection()
        saveChanges()
    }

    private func clearSelectedDays() {
        for day in selectedDays {
            scheduleDraft.removeValue(forKey: day)
        }
    }

    private func saveChanges() {
        appState.alarmSchedule = scheduleDraft
        appState.suppressedScheduleKey = nil
        appState.suppressedScheduleDate = nil
        appState.persist()

        Task { @MainActor in
            await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .scheduleChanged)
        }
    }

    private var wouldConflictWithDailyOverride: Bool {
        guard let overrideDate = appState.dailyOverrideDate,
              Calendar.current.isDateInToday(overrideDate),
              appState.dailyOverrideTime != nil else {
            return false
        }

        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        return selectedDays.contains(todayWeekday)
    }

    private var overrideConflictMessage: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        var adjustedTimeStr = "an earlier time"
        if let overrideTime = appState.dailyOverrideTime {
            adjustedTimeStr = formatter.string(from: overrideTime)
        }

        let newTimeStr = formatter.string(from: timeDraft)

        return "You have an adjusted alarm set for \(adjustedTimeStr). Setting this schedule will replace it with \(newTimeStr)."
    }

    private func timePeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 5 && hour < 12 { return "Morning" }
        if hour >= 12 && hour < 17 { return "Afternoon" }
        if hour >= 17 && hour < 22 { return "Evening" }
        return "Night"
    }

    private func handleClose() {
        isTimePickerPresented = false
        if isEditing {
            isEditing = false
        }
        selectedDays.removeAll()
        onClose()
    }
}

private struct DayRow: View {
    let label: String
    let timeText: String
    let isActive: Bool
    let isSelected: Bool
    let isEditing: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(timeText)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.4))

            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color.blue : Color.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditing && isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        if isEditing && isSelected {
            return Color.blue.opacity(0.22)
        }
        return Color.white.opacity(isActive ? 0.08 : 0.04)
    }
}
