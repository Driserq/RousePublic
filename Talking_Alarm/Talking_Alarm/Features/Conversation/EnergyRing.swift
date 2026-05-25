import SwiftUI

// 1. THE PATH GENERATOR (Hollow)
struct EnergyPath: Shape {
    var time: Double
    var amplitude: Double
    var frequency: Double
    var phaseShift: Double // Allows offsetting different layers
    
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(time, AnimatablePair(amplitude, frequency)) }
        set {
            time = newValue.first
            amplitude = newValue.second.first
            frequency = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Base radius: maximized to fill frame. 
        // We use 0.95 to leave just a tiny margin for stroke width/blur
        let radius = min(rect.width, rect.height) / 2 * 0.95
        
        let points = 100
        let angleStep = (2 * Double.pi) / Double(points)
        
        for i in 0...points { // Go to points (inclusive) to close loop cleanly
            let angle = Double(i) * angleStep
            
            // MATH: Sine wave wrapping around a circle
            // phaseShift ensures the 3 layers don't overlap perfectly
            // FIX: Removed `+ time` from sin() to avoid rotation (if not desired) or keep it if continuous.
            // FIX: frequency multiplier must be integer-aligned with 2*PI. 
            // `frequency` is integer.
            let mainWave = sin(angle * frequency + phaseShift)
            
            // Secondary noise wave
            // FIX: Changed `frequency * 0.5` to `frequency` (or just angle * 2 or similar integer multiplier)
            // to ensure continuity at 0 and 2*PI.
            // Using `frequency * 2.0` ensures even cycles.
            let noise = cos(angle * (frequency * 2.0) - time * 2.0) * 0.5 
            
            let distortion = (mainWave + noise) * (radius * 0.1 * amplitude)
            
            let currentRadius = radius + distortion
            
            let x = center.x + CGFloat(cos(angle) * currentRadius)
            let y = center.y + CGFloat(sin(angle) * currentRadius)
            
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } 
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        // Close the loop
        path.closeSubpath() 
        return path
    }
}

// 2. THE COMPOSITED VIEW (The "Look")
struct ZenEnergyRing: View {
    var time: Double
    var amplitude: Double
    var frequency: Double
    var color: Color
    
    var body: some View {
        ZStack {
            // LAYER 1: OUTER HAZE (Atmosphere)
            EnergyPath(time: time, amplitude: amplitude, frequency: frequency, phaseShift: 0)
                .stroke(color.opacity(0.3), lineWidth: 20)
                .blur(radius: 15)
            
            // LAYER 2: MAIN GLOW (Plasma)
            EnergyPath(time: time, amplitude: amplitude, frequency: frequency, phaseShift: 1.5)
                .stroke(color.opacity(0.8), lineWidth: 6)
                .blur(radius: 4)
            
            // LAYER 3: HOT CORE (Electricity)
            EnergyPath(time: time, amplitude: amplitude, frequency: frequency + 5, phaseShift: 3.0)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .blur(radius: 0.5)
        }
        // This makes the glow "additive" (brighter where they overlap)
        .blendMode(.screen) 
    }
}
