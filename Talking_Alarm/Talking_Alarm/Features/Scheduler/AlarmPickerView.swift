import SwiftUI

struct AlarmPickerView: View {
    @Binding var time: Date
    
    @State private var angle: Angle = .degrees(-90)
    @State private var isDragging: Bool = false
    @State private var previousQuarterHour: Int = -1
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // Config
    private let config = AlarmLayoutConfig.self
    
    // Logic Constants
    // Map -90 degrees (Top) to 12:00 (Standard Clock)
    // 12:00 = 720 minutes from midnight
    // 24 hours = 1440 minutes = 360 degrees
    // 1 minute = 0.25 degrees
    // 0 degrees (Right) would be:
    // Top (-90) is 12:00. Right (0) is +90 from Top -> +6 hours -> 18:00.
    // So 0 degrees = 18:00 (6:00 PM).
    private let degreesPerMinute: Double = 0.25
    private let zeroDegreesTimeOffset: Double = 18 * 60 // 18:00 in minutes
    
    var body: some View {
        ZStack {
            // Layer 1: Background Blob (Optimized)
            ZenBlobView(state: .idle, audioLevel: 0)
                .frame(width: config.blobMaxRadius * 2, height: config.blobMaxRadius * 2)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isDragging)
                .drawingGroup() // OPTIMIZATION: Force Metal rendering
            
            // Layer 2: Interaction Track
            Circle()
                .stroke(Color.clear, lineWidth: 60)
                .frame(width: config.orbitRadius * 2, height: config.orbitRadius * 2)
                .contentShape(Circle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.isDragging = true
                            updateTime(from: value.location)
                        }
                        .onEnded { _ in
                            self.isDragging = false
                        }
                )
            
            // Layer 3: Satellite Icon
            satelliteIcon
                .position(
                    x: config.orbitRadius * 2 / 2 + CGFloat(cos(angle.radians)) * config.orbitRadius,
                    y: config.orbitRadius * 2 / 2 + CGFloat(sin(angle.radians)) * config.orbitRadius
                )
                .frame(width: config.orbitRadius * 2, height: config.orbitRadius * 2)
                // Keep icon upright or rotate with orbit? Plan says "start with up" or rotate.
                // Let's keep it upright relative to screen for readability.
        }
        .frame(width: config.orbitRadius * 2 + config.iconSize, height: config.orbitRadius * 2 + config.iconSize)
        .onAppear {
            syncAngleToTime()
        }
        .onChange(of: time) {
            if !isDragging {
                syncAngleToTime()
            }
        }
    }
    
    private var satelliteIcon: some View {
        let isDay = isDaytime(date: time)
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: config.iconSize, height: config.iconSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(isDay ? .yellow : .purple)
        }
        .shadow(color: (isDay ? Color.yellow : Color.purple).opacity(0.5), radius: 5)
    }
    
    // MARK: - Logic
    
    private func syncAngleToTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let totalMinutes = Double(hour * 60 + minute)
        
        // Calculate degrees relative to 12:00 PM (0 degrees)
        // Angle = (TimeMinutes - 12:00Minutes) * 0.25
        let degrees = (totalMinutes - zeroDegreesTimeOffset) * degreesPerMinute
        self.angle = .degrees(degrees)
    }
    
    private func updateTime(from location: CGPoint) {
        let center = CGPoint(x: config.orbitRadius, y: config.orbitRadius)
        let vector = CGPoint(x: location.x - center.x, y: location.y - center.y)
        
        // Calculate angle (-pi to pi)
        let radians = atan2(vector.y, vector.x)
        self.angle = .radians(radians)
        
        // Convert Angle to Time
        // degrees = radians * 180 / pi
        var degrees = radians * 180 / .pi
        if degrees < 0 { degrees += 360 }
        
        // 0 degrees = 12:00 PM (720 minutes)
        // degrees / 0.25 = minutes offset from 12:00 PM
        let minutesFromNoon = degrees / degreesPerMinute
        var totalMinutes = zeroDegreesTimeOffset + minutesFromNoon
        
        // Normalize to 0-1440
        if totalMinutes >= 1440 { totalMinutes -= 1440 }
        if totalMinutes < 0 { totalMinutes += 1440 }
        
        // Snap to nearest 5 minutes
        let snappedMinutes = (round(totalMinutes / 5) * 5)
        
        // Calculate Haptics (every 15 mins)
        let quarterHour = Int(snappedMinutes / 15)
        if quarterHour != previousQuarterHour {
            feedbackGenerator.impactOccurred()
            previousQuarterHour = quarterHour
        }
        
        // Update Binding
        let hours = Int(snappedMinutes) / 60
        let minutes = Int(snappedMinutes) % 60
        
        let calendar = Calendar.current
        if let newDate = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: time) {
            self.time = newDate
        }
    }
    
    private func isDaytime(date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 6 && hour < 18
    }
}
