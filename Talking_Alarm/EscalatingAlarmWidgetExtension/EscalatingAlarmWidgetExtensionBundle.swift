//
//  EscalatingAlarmWidgetExtensionBundle.swift
//  EscalatingAlarmWidgetExtension
//
//  Created by Jakub Szewczyk on 27/09/2025.
//

import WidgetKit
import SwiftUI

@main
struct EscalatingAlarmWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        EscalatingAlarmWidgetExtension()
        EscalatingAlarmWidgetExtensionControl()
        EscalatingAlarmWidgetExtensionLiveActivity()
    }
}
