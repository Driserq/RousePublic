import SwiftUI

struct ZenBlobView: View {
    let state: BlobState
    let audioLevel: Float // Normalized 0.0 - 1.0
    var namespace: Namespace.ID? = nil
    var matchedGeometryId: String = "ZenBlob"
    
    // Timeline driver
    @State private var time: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            // Use the Energy Ring
            ZenEnergyRing(
                time: timeline.date.timeIntervalSinceReferenceDate,
                amplitude: state.amplitude, // Steady shape, not modulated by audio
                frequency: state.frequency,
                color: state.color
            )
            // Matched Geometry
            .if(namespace != nil) { view in
                view.matchedGeometryEffect(id: matchedGeometryId, in: namespace!)
            }
            // Scale Pulse (Volume drives diameter)
            .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
            // Smooth transitions for color/state changes
            // Using easeInOut instead of spring prevents "twitching" or overshooting during frequency changes
            .animation(Animation.easeInOut(duration: 0.5), value: state)
            .animation(Animation.linear(duration: 0.1), value: audioLevel) // Fast reaction to audio
        }
        // Removed hardcoded frame to allow parent to control size
    }
    
    private var computedAmplitude: Double {
        // Base amplitude from state + audio reactivity
        // If speaking/listening, audioLevel drives it significantly
        if state == .speaking || state == .listening {
            // Map audio (0-1) to amplitude boost
            // Base state.amplitude (e.g. 0.8 or 0.3) is the max potential? 
            // Or base is minimum?
            // Let's say base is the characteristic "energy", audio modulates it.
            return state.amplitude * (0.5 + Double(audioLevel))
        } else {
            return state.amplitude
        }
    }
}
