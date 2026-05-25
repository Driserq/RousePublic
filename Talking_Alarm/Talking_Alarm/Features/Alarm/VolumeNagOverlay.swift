//
//  VolumeNagOverlay.swift
//  Talking_Alarm
//
//  Full-screen overlay that blocks the conversation until volume is turned up.
//

import SwiftUI

/// A full-screen attention-grabbing overlay that displays when the device volume is too low.
///
/// This overlay blocks the wake-up conversation from starting until the user turns up
/// their volume to at least 15%. It displays a prominent "VOLUME UP" message with a
/// speaker icon and an embedded volume slider for easy adjustment.
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
struct VolumeNagOverlay: View {
    
    /// The volume gate manager that tracks volume state.
    let volumeGate: VolumeGateManager
    
    /// Called when the overlay should be dismissed (volume crossed threshold).
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Full-screen red background for attention
            Color.red
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Speaker icon
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                
                // "VOLUME UP" text
                Text("VOLUME UP")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)
                
                // Current volume indicator
                Text("\(Int(volumeGate.currentVolume * 100))%")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
                
                // Volume slider
                VStack(spacing: 16) {
                    Text("Drag to adjust volume")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    MPVolumeViewRepresentable()
                        .frame(height: 44)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Volume too low. Turn up your volume to continue.")
        .accessibilityHint("Use the volume buttons or slider to increase volume above 15 percent")
    }
}

#Preview {
    VolumeNagOverlay(
        volumeGate: VolumeGateManager(),
        onDismiss: {}
    )
}
