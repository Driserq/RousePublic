import SwiftUI

struct CircularSoundVisualizer: View {
    let state: ConversationManager.State
    let attempt: Int
    let currentVolume: Float
    let isRecording: Bool
    let isSpeaking: Bool
    
    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Main reactive background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: backgroundColors,
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(dynamicScale)
                .animation(.spring(response: 0.1, dampingFraction: 0.6), value: currentVolume)
                .shadow(color: mainColor.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Animated rings (decorative, slower pulse)
            ForEach(0..<3, id: \.self) { ringIndex in
                Circle()
                    .stroke(
                        ringColor.opacity(0.3),
                        lineWidth: 2
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(ringScale(for: ringIndex) * dynamicScale)
                    .opacity(ringOpacity(for: ringIndex))
                    .animation(.spring(response: 0.1, dampingFraction: 0.6), value: currentVolume)
            }
            
            // Center state indicator
            VStack(spacing: 8) {
                Circle()
                    .fill(stateIndicatorColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                
                Text(stateIndicatorText)
                    .foregroundStyle(stateIndicatorColor)
                    .font(.caption)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .onReceive(timer) { _ in
            updateAnimation()
        }
        .onAppear {
            pulseScale = 1.2
        }
    }
    
    // MARK: - Computed Properties
    
    private var dynamicScale: CGFloat {
        let volume = CGFloat(max(0, currentVolume))
        // Only pulse if we are in a state that produces/records sound
        if isSpeaking || isRecording {
            // Base scale 1.0, expands up to ~1.3 based on volume
            return 1.0 + (volume * 0.3)
        } else {
            return 1.0
        }
    }
    
    private var mainColor: Color {
        switch state {
        case .idle: return .white
        case .preparing: return .orange
        case .speaking: return attempt == 1 ? .white : .red
        case .recording: return .white
        case .evaluating: return .orange
        case .offlineFallback: return .orange
        case .playingGoodLuck: return .green
        case .done: return .blue
        }
    }
    
    private var backgroundColors: [Color] {
        let base = mainColor
        return [base.opacity(0.15), base.opacity(0.05)]
    }
    
    private var ringColor: Color {
        return mainColor
    }
    
    private var stateIndicatorColor: Color {
        return mainColor.opacity(0.8)
    }
    
    private var stateIndicatorText: String {
        switch state {
        case .idle: return "READY"
        case .preparing: return "WAKING"
        case .speaking: return "AI"
        case .recording: return "YOU"
        case .evaluating: return "THINKING"
        case .offlineFallback: return "OFFLINE"
        case .playingGoodLuck: return "SUCCESS"
        case .done: return "DONE"
        }
    }
    
    // MARK: - Animation Helpers
    
    private func ringScale(for index: Int) -> CGFloat {
        let baseScale = 1.0 + CGFloat(index) * 0.1
        let animationOffset = sin(animationPhase + Double(index) * 0.5) * 0.05
        return baseScale + animationOffset
    }
    
    private func ringOpacity(for index: Int) -> Double {
        let baseOpacity = 0.3 - Double(index) * 0.1
        let animationOffset = sin(animationPhase + Double(index) * 0.3) * 0.1
        return max(0.1, baseOpacity + animationOffset)
    }
    
    private func updateAnimation() {
        animationPhase += 0.1
    }
}
