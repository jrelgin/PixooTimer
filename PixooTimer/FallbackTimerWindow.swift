//
//  FallbackTimerWindow.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import AppKit
import SwiftUI

@MainActor
class FallbackTimerWindow {
    private var window: NSWindow?
    private var hostingView: NSHostingView<FallbackTimerView>?

    private var minutes: Int = 0
    private var progress: Double = 0.0
    private var isFlashing: Bool = false

    private let windowSizeKey = "fallbackWindowPosition"

    init() {
        setupWindow()
    }

    private func setupWindow() {
        let contentView = FallbackTimerView(minutes: minutes, progress: progress, isFlashing: isFlashing)
        hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window?.contentView = hostingView
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window?.isMovableByWindowBackground = true
        window?.hasShadow = true

        // Restore saved position, but only if it still lands on a real screen.
        // Display arrangements change (monitor moved to the other side, laptop
        // undocked), which can strand the saved origin in dead space where the
        // window is invisible and unreachable.
        let savedString = UserDefaults.standard.string(forKey: windowSizeKey)
        let savedFrame = savedString.map(NSRectFromString) ?? .zero
        if !savedFrame.isEmpty, isSufficientlyVisible(savedFrame) {
            window?.setFrameOrigin(savedFrame.origin)
        } else {
            positionBottomRight()
        }

        // Displays can change while the app is running
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.ensureOnScreen()
            }
        }

        // Save position when window moves
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.saveWindowPosition()
            }
        }
    }

    /// A restored frame is only usable if a meaningful part of it is on a screen.
    /// Requiring half the window keeps a slightly-clipped position (which the user
    /// chose) while rejecting one that is effectively invisible.
    private func isSufficientlyVisible(_ frame: NSRect) -> Bool {
        let required = frame.width * frame.height * 0.5
        return NSScreen.screens.contains { screen in
            let overlap = screen.visibleFrame.intersection(frame)
            return !overlap.isNull && overlap.width * overlap.height >= required
        }
    }

    /// Pull the window back to a visible spot if the screen layout stranded it.
    private func ensureOnScreen() {
        guard let frame = window?.frame else { return }
        guard !isSufficientlyVisible(frame) else { return }
        positionBottomRight()
        saveWindowPosition()
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window?.frame ?? NSRect(x: 0, y: 0, width: 120, height: 120)

        let x = screenFrame.maxX - windowFrame.width - 20
        let y = screenFrame.minY + 20

        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveWindowPosition() {
        guard let frame = window?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowSizeKey)
    }

    func show() {
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func update(minutes: Int, progress: Double) {
        self.minutes = minutes
        self.progress = progress
        self.isFlashing = false
        updateView()
    }

    func flash() {
        minutes = 0  // Show "0" during flash
        isFlashing = true
        updateView()

        // Flash animation: toggle a few times
        Task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .milliseconds(200))
                isFlashing.toggle()
                updateView()
            }
            isFlashing = false
            updateView()
        }
    }

    private func updateView() {
        hostingView?.rootView = FallbackTimerView(
            minutes: minutes,
            progress: progress,
            isFlashing: isFlashing
        )
    }
}
