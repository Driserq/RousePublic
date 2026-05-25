import SwiftUI

struct ScheduleDetailView: View {
    @Binding var group: ScheduleGroup
    @Binding var isPresented: Bool
    var onDelete: () -> Void
    
    // Config
    private let config = AlarmLayoutConfig.self
    
    // Day Ordering
    private let weekDays = [2, 3, 4, 5, 6, 7, 1] // Mon -> Sun
    
    // Local State for Deferred Updates
    @State private var editingTime: Date = Date()
    @State private var hasUnsavedTimeChanges: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all) // Deep background
                
                VStack(spacing: 30) {
                    // 1. Header with Name
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "chevron.down")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        TextField("Schedule Name", text: $group.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .submitLabel(.done)
                        
                        Spacer()
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                    
                    // 2. Day Selector
                    HStack(spacing: 8) {
                        ForEach(weekDays, id: \.self) { day in
                            DayPill(
                                day: day,
                                isSelected: group.days.contains(day),
                                color: group.color
                            )
                            .onTapGesture {
                                toggleDay(day)
                            }
                        }
                    }
                    .frame(height: 50)
                    
                    Spacer()
                    
                    // 3. The Hero Alarm Picker
                    ZStack {
                        // The Interactive Blob & Orbit
                        AlarmPickerView(time: $editingTime)
                            .onChange(of: editingTime) {
                                hasUnsavedTimeChanges = true
                            }
                        
                        // Center Time Display (Non-interactive overlay)
                        VStack(spacing: 0) {
                            Text(editingTime.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            
                            Text(timePeriod(for: editingTime))
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .allowsHitTesting(false) // Pass touches to the blob/orbit
                    }
                    
                    Spacer()
                    
                    // 4. Instructions / Update Button
                    if hasUnsavedTimeChanges {
                        Button(action: {
                            group.time = editingTime
                            hasUnsavedTimeChanges = false
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            Text("Update Alarm Time")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 30)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Drag the sun/moon to set time")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            self.editingTime = group.time
        }
    }
    
    // MARK: - Logic
    
    private func toggleDay(_ day: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if group.days.contains(day) {
                group.days.remove(day)
            } else {
                group.days.insert(day)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func timePeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 5 && hour < 12 { return "Morning" }
        if hour >= 12 && hour < 17 { return "Afternoon" }
        if hour >= 17 && hour < 22 { return "Evening" }
        return "Night"
    }
}

// Subview: Day Pill
struct DayPill: View {
    let day: Int
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        Text(dayInitial(day))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(isSelected ? .white : .white.opacity(0.3))
            .frame(width: 36, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? color : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.0 : 0.1), lineWidth: 1)
            )
    }
    
    private func dayInitial(_ day: Int) -> String {
        switch day {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return ""
        }
    }
}
