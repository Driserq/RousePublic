import SwiftUI

struct TwoWaySwipeToEndView: View {
    private enum Phase: Equatable {
        case swipeRight
        case swipeLeft
    }

    let onCompleted: () -> Void

    @State private var phase: Phase = .swipeRight
    @State private var progress: CGFloat = 0
    @State private var dragStartProgress: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = 56
            let knobSize: CGFloat = 44
            let padding: CGFloat = 6

            let trackWidth = proxy.size.width
            let usableWidth = max(1, trackWidth - (knobSize + padding * 2))
            let knobX = padding + usableWidth * progress

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )

                Text(instructionText)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, knobSize + 18)

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        Image(systemName: knobSymbolName)
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                    }
                    .offset(x: knobX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStartProgress = progress
                                }

                                let delta = value.translation.width / usableWidth
                                progress = clamp(dragStartProgress + delta)
                            }
                            .onEnded { _ in
                                isDragging = false
                                handleRelease()
                            }
                    )
            }
            .frame(height: height)
        }
        .frame(height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("End offline wake session")
        .accessibilityHint("Swipe right, then left, to end. If you use VoiceOver, activate the End action.")
        .accessibilityAction(named: "End") {
            onCompleted()
        }
    }

    private var instructionText: String {
        switch phase {
        case .swipeRight:
            return "Swipe right to arm"
        case .swipeLeft:
            return "Now swipe left to end"
        }
    }

    private var knobSymbolName: String {
        switch phase {
        case .swipeRight:
            return "chevron.right"
        case .swipeLeft:
            return "chevron.left"
        }
    }

    private func handleRelease() {
        switch phase {
        case .swipeRight:
            if progress >= 0.9 {
                Haptics.warning()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    progress = 1
                }
                phase = .swipeLeft
            } else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    progress = 0
                }
            }

        case .swipeLeft:
            if progress <= 0.1 {
                Haptics.success()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    progress = 0
                }
                onCompleted()
            } else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    progress = 1
                }
            }
        }
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TwoWaySwipeToEndView(onCompleted: {})
            .padding(.horizontal, 24)
    }
}
