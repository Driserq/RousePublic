import SwiftUI
import AlarmKit

struct ScheduleView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // Day mapping: 1=Sun, ..., 7=Sat
    let days = [
        (1, "S", "Sunday"),
        (2, "M", "Monday"),
        (3, "T", "Tuesday"),
        (4, "W", "Wednesday"),
        (5, "T", "Thursday"),
        (6, "F", "Friday"),
        (7, "S", "Saturday")
    ]
    
    @State private var isSaving = false
    @State private var selectedDate: Date
    @State private var selectedDays: Set<Int>
    
    init(appState: AppState) {
        self.appState = appState
        _selectedDate = State(initialValue: appState.alarmDate)
        _selectedDays = State(initialValue: appState.alarmDays)
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("Schedule Alarm")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to balance the header
                    Text("Cancel")
                        .opacity(0)
                }
                .padding()
                
                // Time Picker
                DatePicker("Time", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                
                // Days Selection
                VStack(spacing: 16) {
                    Text("Repeat")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        ForEach(days, id: \.0) { day in
                            Button(action: {
                                toggleDay(day.0)
                            }) {
                                Text(day.1)
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(selectedDays.contains(day.0) ? Color.blue : Color.white.opacity(0.1))
                                    )
                                    .foregroundColor(.white)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Save Button
                Button(action: saveSchedule) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isSaving ? "Scheduling..." : "Save Schedule")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    private func saveSchedule() {
        isSaving = true
        
        // Update AppState
        appState.alarmDate = selectedDate
        appState.alarmDays = selectedDays
        appState.persist()
        
        Task {
            do {
                guard let name = UserDefaults.standard.string(forKey: "user_name"),
                      let goal = UserDefaults.standard.string(forKey: "user_goal") else {
                    DebugLogger.log("[ScheduleView] User data not found")
                    await MainActor.run { isSaving = false }
                    return
                }
                
                // Convert selected days to AlarmKit Weekdays
                let weekdays: [Locale.Weekday] = selectedDays.compactMap { dayInt in
                    // Mapping: 1=Sun (AlarmKit: sunday), ..., 7=Sat (AlarmKit: saturday)
                    switch dayInt {
                    case 1: return .sunday
                    case 2: return .monday
                    case 3: return .tuesday
                    case 4: return .wednesday
                    case 5: return .thursday
                    case 6: return .friday
                    case 7: return .saturday
                    default: return nil
                    }
                }
                
                if #available(iOS 26.0, *) {
                    let authorized = await AlarmKitManager.shared.requestAuthorization()
                    if authorized {
                        _ = try await AlarmKitManager.shared.schedulePersonalizedAlarm(
                            at: selectedDate,
                            name: name,
                            goal: goal,
                            days: weekdays.isEmpty ? nil : weekdays
                        )
                        Haptics.success()
                    } else {
                        // Fallback logic for unauthorized AlarmKit (if needed) or just error
                        DebugLogger.log("[ScheduleView] AlarmKit not authorized")
                        Haptics.error()
                    }
                } else {
                    // Fallback for older iOS
                    DebugLogger.log("[ScheduleView] iOS < 26.0 not supported for repeating alarms in this demo")
                    Haptics.error()
                }
            } catch {
                DebugLogger.log("[ScheduleView] Error scheduling: \(error)")
                Haptics.error()
            }
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
