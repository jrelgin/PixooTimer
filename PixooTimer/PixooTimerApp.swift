//
//  PixooTimerApp.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import SwiftUI
import UserNotifications

@main
struct PixooTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

// MARK: - App Delegate for Notifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request permission
        center.requestAuthorization(options: [.alert, .badge]) { granted, error in
            if granted {
                self.registerNotificationCategory()
            }
        }
    }

    private func registerNotificationCategory() {
        let fiveMin = UNNotificationAction(
            identifier: "START_5",
            title: "5 min",
            options: .foreground
        )
        let tenMin = UNNotificationAction(
            identifier: "START_10",
            title: "10 min",
            options: .foreground
        )
        let repeatTimer = UNNotificationAction(
            identifier: "REPEAT",
            title: "Repeat",
            options: .foreground
        )
        let dismiss = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: "TIMER_COMPLETE",
            actions: [fiveMin, tenMin, repeatTimer, dismiss],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        var minutes: Int? = nil

        switch response.actionIdentifier {
        case "START_5":
            minutes = 5
        case "START_10":
            minutes = 10
        case "REPEAT":
            minutes = response.notification.request.content.userInfo["duration"] as? Int
        default:
            break
        }

        if let minutes = minutes {
            NotificationCenter.default.post(
                name: .startTimerFromNotification,
                object: nil,
                userInfo: ["minutes": minutes]
            )
        }
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startTimerFromNotification = Notification.Name("startTimerFromNotification")
}
