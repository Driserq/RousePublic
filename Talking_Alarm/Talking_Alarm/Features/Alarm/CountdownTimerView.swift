import SwiftUI
import Combine

struct CountdownTimerView: View {
    let targetDate: Date
    @State private var now: Date = Date()

    private var timer: Timer.TimerPublisher { Timer.publish(every: 1, on: .main, in: .common) }
    @State private var timerCancellable: Cancellable?

    var body: some View {
        Text(TimeUtils.formattedCountdown(until: targetDate, now: now))
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .onAppear { start() }
            .onDisappear { stop() }
    }

    private func start() {
        stop()
        timerCancellable = timer.autoconnect().sink { date in
            now = date
        }
    }

    private func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); CountdownTimerView(targetDate: Date().addingTimeInterval(3723)) }
}


