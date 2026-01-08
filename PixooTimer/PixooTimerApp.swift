//
//  PixooTimerApp.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import SwiftUI

@main
struct PixooTimerApp: App {
    @StateObject private var timerManager = TimerManager(pixooClient: PixooClient.shared)

    var body: some Scene {
        MenuBarExtra(
            timerManager.isRunning ? "\(timerManager.minutesRemaining)" : "Timer",
            systemImage: timerManager.isRunning ? "timer.circle.fill" : "timer"
        ) {
            TimerMenuView(timerManager: timerManager)
        }

        Window("Settings", id: "settings") {
            SettingsView(pixooClient: PixooClient.shared)
        }
        .windowResizability(.contentSize)
    }
}
