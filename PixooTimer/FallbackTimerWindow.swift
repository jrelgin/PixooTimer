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

        // Restore saved position or default to bottom-right
        if let savedFrame = UserDefaults.standard.string(forKey: windowSizeKey),
           let frameRect = NSRectFromString(savedFrame) as NSRect? {
            window?.setFrameOrigin(frameRect.origin)
        } else {
            positionBottomRight()
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
