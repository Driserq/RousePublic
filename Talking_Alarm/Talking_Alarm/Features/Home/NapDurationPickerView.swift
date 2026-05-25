import SwiftUI

struct NapDurationPickerView: View {
    @Binding var minutes: Int

    @State private var angle: Angle = .degrees(-90)
    @State private var isDragging: Bool = false
    @State private var previousStep: Int = -1

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private let config = AlarmLayoutConfig.self

    private let minMinutes: Int = 5
    private let maxMinutes: Int = 240
    private let step: Int = 5

    var body: some View {
        ZStack {
            ZenBlobView(state: .idle, audioLevel: 0)
                .frame(width: config.blobMaxRadius * 2, height: config.blobMaxRadius * 2)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isDragging)
                .drawingGroup()

            Circle()
                .stroke(Color.clear, lineWidth: 60)
                .frame(width: config.orbitRadius * 2, height: config.orbitRadius * 2)
                .contentShape(Circle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            updateMinutes(from: value.location)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )

            satelliteIcon
                .position(
                    x: config.orbitRadius * 2 / 2 + CGFloat(cos(angle.radians)) * config.orbitRadius,
                    y: config.orbitRadius * 2 / 2 + CGFloat(sin(angle.radians)) * config.orbitRadius
                )
                .frame(width: config.orbitRadius * 2, height: config.orbitRadius * 2)
        }
        .frame(width: config.orbitRadius * 2 + config.iconSize, height: config.orbitRadius * 2 + config.iconSize)
        .onAppear {
            syncAngleToMinutes()
        }
        .onChange(of: minutes) {
            if !isDragging {
                syncAngleToMinutes()
            }
        }
    }

    private var satelliteIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: config.iconSize, height: config.iconSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Image(systemName: "moon.zzz.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.purple)
        }
        .shadow(color: Color.purple.opacity(0.5), radius: 5)
    }

    private func syncAngleToMinutes() {
        let clamped = min(max(minutes, minMinutes), maxMinutes)
        let steps = (maxMinutes - minMinutes) / step
        let stepValue = (clamped - minMinutes) / step
        let normalized = Double(stepValue) / Double(steps)
        angle = .degrees(normalized * 360 - 90)
    }

    private func updateMinutes(from location: CGPoint) {
        let center = CGPoint(x: config.orbitRadius, y: config.orbitRadius)
        let vector = CGPoint(x: location.x - center.x, y: location.y - center.y)

        let radians = atan2(vector.y, vector.x)
        angle = .radians(radians)

        var degrees = radians * 180 / .pi
        if degrees < 0 { degrees += 360 }

        let steps = (maxMinutes - minMinutes) / step
        let normalized = degrees / 360
        let stepValue = Int(round(normalized * Double(steps)))
        let snapped = minMinutes + (stepValue * step)

        if stepValue != previousStep {
            feedbackGenerator.impactOccurred()
            previousStep = stepValue
        }

        minutes = min(max(snapped, minMinutes), maxMinutes)
    }
}
