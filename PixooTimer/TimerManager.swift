//
//  TimerManager.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import Foundation
import AppKit
import Combine
import UserNotifications

enum DisplayMode {
    case pixoo(originalChannel: Int)
    case macFallback
}

@MainActor
class TimerManager: ObservableObject {
    enum State {
        case idle
        case running(endTime: Date, totalMinutes: Int, displayMode: DisplayMode)
    }

    private(set) var state: State = .idle {
        didSet { objectWillChange.send() }
    }
    private var displayTimer: Timer?
    private var lastDisplayedMinute: Int = -1
    private var lastDisplayUpdate: Date = .distantPast

    private let pixooClient: PixooClient
    private let frameRenderer = FrameRenderer()
    private var fallbackWindow: FallbackTimerWindow?

    var onStateChange: (() -> Void)?

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var minutesRemaining: Int {
        guard case .running(let endTime, _, _) = state else { return 0 }
        let remaining = endTime.timeIntervalSinceNow
        return max(0, Int(ceil(remaining / 60)))
    }

    var progress: Double {
        guard case .running(let endTime, let totalMinutes, _) = state else { return 0 }
        let totalSeconds = Double(totalMinutes * 60)
        let remainingSeconds = endTime.timeIntervalSinceNow
        return max(0, min(1, 1 - (remainingSeconds / totalSeconds)))
    }

    init(pixooClient: PixooClient) {
        self.pixooClient = pixooClient
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .startTimerFromNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let minutes = notification.userInfo?["minutes"] as? Int else { return }
            Task { @MainActor in
                await self?.startTimer(minutes: minutes)
            }
        }
    }

    // MARK: - Public Methods

    func startTimer(minutes: Int) async {
        // If already running with Pixoo, preserve original channel
        var originalChannel: Int? = nil
        if case .running(_, _, .pixoo(let channel)) = state {
            originalChannel = channel
        }

        // Stop existing timer
        stopDisplayTimer()

        // Try to connect to Pixoo (quick check with 1.5s timeout)
        let displayMode: DisplayMode
        if let existing = originalChannel {
            // Already connected, reuse channel
            try? await pixooClient.resetAnimationId()
            displayMode = .pixoo(originalChannel: existing)
        } else if let channel = await pixooClient.quickCheck() {
            // Pixoo responded quickly
            try? await pixooClient.resetAnimationId()
            displayMode = .pixoo(originalChannel: channel)
        } else {
            // Pixoo unavailable or too slow, use fallback
            displayMode = .macFallback
        }

        // Set state
        let endTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        state = .running(endTime: endTime, totalMinutes: minutes, displayMode: displayMode)
        lastDisplayedMinute = -1
        lastDisplayUpdate = .distantPast

        // Start display updates
        startDisplayTimer()

        // Initial display update
        await updateDisplay()

        onStateChange?()
    }

    func cancelTimer() async {
        guard case .running(_, _, let displayMode) = state else { return }

        stopDisplayTimer()

        // Restore state based on display mode
        switch displayMode {
        case .pixoo(let originalChannel):
            try? await pixooClient.setChannel(originalChannel)
        case .macFallback:
            fallbackWindow?.hide()
        }

        state = .idle
        lastDisplayedMinute = -1

        onStateChange?()
    }

    // MARK: - Private Methods

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.onDisplayTimerFire()
            }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func onDisplayTimerFire() async {
        guard case .running(let endTime, _, _) = state else { return }

        // Check if timer is up
        if Date() >= endTime {
            await timerCompleted()
            return
        }

        // Update display every 5 seconds
        if Date().timeIntervalSince(lastDisplayUpdate) >= 5.0 {
            lastDisplayUpdate = Date()
            await updateDisplay()
        }

        // Update menu bar text when minute changes
        let currentMinute = minutesRemaining
        if currentMinute != lastDisplayedMinute {
            lastDisplayedMinute = currentMinute
            onStateChange?()
        }
    }

    private func updateDisplay() async {
        guard case .running(_, _, let displayMode) = state else { return }

        let minutes = minutesRemaining
        let currentProgress = progress

        switch displayMode {
        case .pixoo:
            let frameData = frameRenderer.renderTimerFrame(minutesRemaining: minutes, progress: currentProgress)
            try? await pixooClient.resetAnimationId()
            try? await pixooClient.sendFrame(frameData)
        case .macFallback:
            if fallbackWindow == nil {
                fallbackWindow = FallbackTimerWindow()
            }
            fallbackWindow?.show()
            fallbackWindow?.update(minutes: minutes, progress: currentProgress)
        }
    }

    private func timerCompleted() async {
        guard case .running(_, let totalMinutes, let displayMode) = state else { return }

        stopDisplayTimer()

        // Send notification
        sendCompletionNotification(minutes: totalMinutes)

        switch displayMode {
        case .pixoo(let originalChannel):
            // Show "0" frame during buzzer
            let completionFrame = frameRenderer.renderCompletionFrame()
            try? await pixooClient.resetAnimationId()
            try? await pixooClient.sendFrame(completionFrame)

            // Play buzzer
            try? await pixooClient.playBuzzer(activeMs: 500, offMs: 500, totalMs: 3000)

            // Wait for buzzer to finish
            try? await Task.sleep(for: .seconds(3.5))

            // Restore channel
            try? await pixooClient.setChannel(originalChannel)

        case .macFallback:
            fallbackWindow?.flash()

            // Play selected sound for ~3 seconds
            let soundName = UserDefaults.standard.string(forKey: "completionSound") ?? "Glass"
            if let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
                try? await Task.sleep(for: .seconds(1))
                sound.play()
                try? await Task.sleep(for: .seconds(1))
                sound.play()
                try? await Task.sleep(for: .seconds(1))
            }

            fallbackWindow?.hide()
        }

        state = .idle
        lastDisplayedMinute = -1

        onStateChange?()
    }

    private func sendCompletionNotification(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(minutes)-minute timer complete"
        content.categoryIdentifier = "TIMER_COMPLETE"
        content.sound = nil  // Use existing buzzer/sound
        content.userInfo = ["duration": minutes]  // For "Repeat" action

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
