//
//  MPVolumeViewRepresentable.swift
//  Talking_Alarm
//
//  SwiftUI wrapper for MPVolumeView to display the system volume slider.
//

import SwiftUI
import MediaPlayer

/// A SwiftUI wrapper for `MPVolumeView` that displays the system volume slider.
///
/// This allows users to adjust the device volume directly within the app UI,
/// which is useful for the Volume Gate overlay where we need users to turn up
/// their volume before proceeding.
///
/// **Validates: Requirements 3.5**
struct MPVolumeViewRepresentable: UIViewRepresentable {
    
    /// Creates the `MPVolumeView` instance.
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        
        // Style the volume view for better visibility
        // Note: showsRouteButton is deprecated in iOS 26 - route button is hidden by default
        volumeView.setVolumeThumbImage(nil, for: .normal) // Use default thumb
        
        // Tint the slider to match the overlay's attention-grabbing style
        volumeView.tintColor = .white
        
        return volumeView
    }
    
    /// Updates the view when SwiftUI state changes.
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // No dynamic updates needed - the volume slider handles its own state
    }
}

#Preview {
    ZStack {
        Color.red.ignoresSafeArea()
        
        VStack {
            Text("Volume Slider")
                .foregroundStyle(.white)
                .bold()
            
            MPVolumeViewRepresentable()
                .frame(height: 44)
                .padding(.horizontal, 40)
        }
    }
}
