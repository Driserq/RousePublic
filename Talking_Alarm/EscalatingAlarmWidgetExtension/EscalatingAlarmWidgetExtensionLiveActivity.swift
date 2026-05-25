//
//  EscalatingAlarmWidgetExtensionLiveActivity.swift
//  EscalatingAlarmWidgetExtension
//
//  Created by Jakub Szewczyk on 27/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct EscalatingAlarmWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EscalatingAlarmActivityAttributes.self) { context in
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.red)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Talking Alarm").font(.headline).fontWeight(.bold)
                        Text("\(context.attributes.name)").font(.subheadline).foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(context.state.currentAttempt)/\(context.state.totalAttempts)")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }

                if context.state.isActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal: \(context.attributes.goal)").font(.caption).foregroundColor(.secondary)
                        if let remaining = context.state.timeRemaining {
                            Text("Next attempt in \(Int(remaining))s").font(.caption).foregroundColor(.orange)
                        } else {
                            Text("Attempt \(context.state.currentAttempt) in progress...")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                } else {
                    Text("Alarm sequence completed").font(.caption).foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundColor(.red).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentAttempt)/\(context.state.totalAttempts)")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("Talking Alarm").font(.headline).fontWeight(.bold)
                        Text("\(context.attributes.name)").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal: \(context.attributes.goal)").font(.caption).foregroundColor(.secondary)
                        if context.state.isActive {
                            if let remaining = context.state.timeRemaining {
                                Text("Next attempt in \(Int(remaining))s").font(.caption).foregroundColor(.orange)
                            } else {
                                Text("Attempt \(context.state.currentAttempt) in progress...")
                                    .font(.caption).foregroundColor(.red)
                            }
                        } else {
                            Text("Alarm sequence completed").font(.caption).foregroundColor(.green)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundColor(.red)
            } compactTrailing: {
                Text("\(context.state.currentAttempt)/\(context.state.totalAttempts)")
                    .font(.caption).fontWeight(.semibold).foregroundColor(.red)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundColor(.red)
            }
        }
    }
}

extension EscalatingAlarmActivityAttributes {
    fileprivate static var preview: EscalatingAlarmActivityAttributes {
        EscalatingAlarmActivityAttributes(name: "Kuba", goal: "Get morning push-ups in")
    }
}

extension EscalatingAlarmActivityAttributes.ContentState {
    fileprivate static var active: EscalatingAlarmActivityAttributes.ContentState {
        EscalatingAlarmActivityAttributes.ContentState(currentAttempt: 2, totalAttempts: 4, isActive: true, timeRemaining: 15)
    }
    
    fileprivate static var completed: EscalatingAlarmActivityAttributes.ContentState {
        EscalatingAlarmActivityAttributes.ContentState(currentAttempt: 4, totalAttempts: 4, isActive: false, timeRemaining: nil)
    }
}

#Preview("Notification", as: .content, using: EscalatingAlarmActivityAttributes.preview) {
   EscalatingAlarmWidgetExtensionLiveActivity()
} contentStates: {
    EscalatingAlarmActivityAttributes.ContentState.active
    EscalatingAlarmActivityAttributes.ContentState.completed
}
