import SwiftUI

// HELPER ENUM FOR VISUAL STATES
struct BlobState: Equatable {
    var amplitude: Double
    var frequency: Double
    var color: Color
    
    // All states now share the same smooth, subtle geometry.
    // Differentiation comes from color and the ZenBlobView's scale pulsing.
    static let idle = BlobState(amplitude: 0.1, frequency: 3.0, color: Color(red: 0.1, green: 0.1, blue: 0.5))
    static let speaking = BlobState(amplitude: 0.1, frequency: 3.0, color: .blue)
    static let listening = BlobState(amplitude: 0.1, frequency: 3.0, color: .white)
    static let thinking = BlobState(amplitude: 0.1, frequency: 3.0, color: .orange)
    static let failure = BlobState(amplitude: 0.1, frequency: 3.0, color: .red)
    static let success = BlobState(amplitude: 0.1, frequency: 3.0, color: .green)
}
