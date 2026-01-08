//
//  TimerMenuView.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import SwiftUI

struct TimerMenuView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.openWindow) private var openWindow

    private let durations = [5, 10, 15, 25, 45]

    var body: some View {
        ForEach(durations, id: \.self) { minutes in
            Button("Start \(minutes) min") {
                Task {
                    await timerManager.startTimer(minutes: minutes)
                }
            }
        }

        Divider()

        if timerManager.isRunning {
            Button("Cancel Timer") {
                Task {
                    await timerManager.cancelTimer()
                }
            }

            Divider()
        }

        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }

        Divider()

        Button("Quit") {
            Task {
                await timerManager.cancelTimer()
                NSApplication.shared.terminate(nil)
            }
        }
        .keyboardShortcut("q")
    }
}
