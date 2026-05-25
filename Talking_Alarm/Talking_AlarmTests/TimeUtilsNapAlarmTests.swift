import Foundation
import Testing
@testable import Talking_Alarm

struct TimeUtilsNapAlarmTests {
    @Test func nextAlarmInfoPrefersNapWhenSooner() async throws {
        let now = Date()
        let scheduled = now.addingTimeInterval(60 * 60)
        let nap = now.addingTimeInterval(20 * 60)

        let info = TimeUtils.nextAlarmInfo(scheduledDate: scheduled, napDate: nap, now: now)

        #expect(info?.kind == .nap)
        #expect(info?.date == nap)
    }

    @Test func nextAlarmInfoFallsBackToScheduled() async throws {
        let now = Date()
        let scheduled = now.addingTimeInterval(30 * 60)

        let info = TimeUtils.nextAlarmInfo(scheduledDate: scheduled, napDate: nil, now: now)

        #expect(info?.kind == .scheduled)
        #expect(info?.date == scheduled)
    }

    @Test func nextAlarmInfoIgnoresExpiredNap() async throws {
        let now = Date()
        let scheduled = now.addingTimeInterval(45 * 60)
        let nap = now.addingTimeInterval(-10 * 60)

        let info = TimeUtils.nextAlarmInfo(scheduledDate: scheduled, napDate: nap, now: now)

        #expect(info?.kind == .scheduled)
        #expect(info?.date == scheduled)
    }
}
