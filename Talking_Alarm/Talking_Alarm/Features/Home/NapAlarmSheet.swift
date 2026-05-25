import SwiftUI

struct NapAlarmSheet: View {
    @Binding var durationMinutes: Int
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    NapDurationPickerView(minutes: $durationMinutes)

                    VStack(spacing: 6) {
                        Text(durationText(for: durationMinutes))
                            .font(.title)
                            .bold()
                            .foregroundStyle(.white)

                        Text("Nap length")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .allowsHitTesting(false)
                }

                Text("Drag the moon to set your nap length")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))

                Spacer()
            }
            .navigationTitle("Set Nap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onSave)
                }
            }
            .onAppear {
                durationMinutes = 5
            }
        }
    }

    private func durationText(for minutes: Int) -> String {
        let clamped = max(5, min(240, minutes))
        let hours = clamped / 60
        let mins = clamped % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, mins)
        }
        return String(format: "%dm", mins)
    }
}
