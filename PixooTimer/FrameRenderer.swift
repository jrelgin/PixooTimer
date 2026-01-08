//
//  FrameRenderer.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import Foundation

struct RGB {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let white = RGB(r: 255, g: 255, b: 255)
    static let black = RGB(r: 0, g: 0, b: 0)

    static func lerp(_ a: RGB, _ b: RGB, t: Double) -> RGB {
        let t = max(0, min(1, t))
        return RGB(
            r: UInt8(Double(a.r) + t * (Double(b.r) - Double(a.r))),
            g: UInt8(Double(a.g) + t * (Double(b.g) - Double(a.g))),
            b: UInt8(Double(a.b) + t * (Double(b.b) - Double(a.b)))
        )
    }
}

class FrameRenderer {
    static let size = 64
    static let totalBytes = size * size * 3 // 12288 bytes

    // Gradient colors: cyan -> blue -> purple (vivid)
    private let gradientColors: [RGB] = [
        RGB(r: 0, g: 220, b: 255),    // Bright Cyan (start)
        RGB(r: 30, g: 100, b: 255),   // Electric Blue (middle)
        RGB(r: 160, g: 50, b: 255)    // Vivid Purple (end)
    ]

    // Flash color for completion alert
    private let flashColor = RGB(r: 255, g: 180, b: 100) // Warm orange

    // Scale factor for digits (3x makes 5x7 -> 15x21)
    private let digitScale = 3

    /// Renders a timer frame with the minutes remaining and gradient background
    /// - Parameters:
    ///   - minutesRemaining: The number of minutes to display
    ///   - progress: Progress from 0.0 (start) to 1.0 (end)
    /// - Returns: Raw RGB data (12288 bytes)
    func renderTimerFrame(minutesRemaining: Int, progress: Double) -> Data {
        var buffer = [UInt8](repeating: 0, count: Self.totalBytes)

        let bgColor = colorForProgress(progress)

        // 1. Fill background with gradient color
        for y in 0..<Self.size {
            for x in 0..<Self.size {
                let offset = (y * Self.size + x) * 3
                buffer[offset] = bgColor.r
                buffer[offset + 1] = bgColor.g
                buffer[offset + 2] = bgColor.b
            }
        }

        // 2. Draw pie (remaining time indicator) - 40% darker than background
        let pieColor = darken(bgColor, by: 0.4)
        let remainingFraction = 1.0 - progress
        drawPie(center: (Self.size / 2, Self.size / 2),
                radius: 24,
                remainingFraction: remainingFraction,
                color: pieColor,
                in: &buffer)

        // 3. Draw the minutes number centered (on top of pie)
        drawNumber(minutesRemaining, in: &buffer, color: .white)

        return Data(buffer)
    }

    /// Renders a completion frame showing "0" with full progress
    func renderCompletionFrame() -> Data {
        return renderTimerFrame(minutesRemaining: 0, progress: 1.0)
    }

    /// Renders a flash frame for completion alert
    /// - Parameter on: Whether the flash is on (bright) or off (dark)
    /// - Returns: Raw RGB data (12288 bytes)
    func renderFlashFrame(on: Bool) -> Data {
        var buffer = [UInt8](repeating: 0, count: Self.totalBytes)

        let color = on ? flashColor : RGB.black

        for i in 0..<(Self.size * Self.size) {
            let offset = i * 3
            buffer[offset] = color.r
            buffer[offset + 1] = color.g
            buffer[offset + 2] = color.b
        }

        return Data(buffer)
    }

    // MARK: - Private Helpers

    private func colorForProgress(_ progress: Double) -> RGB {
        let progress = max(0, min(1, progress))

        // Map progress to position in gradient
        let segment = progress * Double(gradientColors.count - 1)
        let index = Int(segment)
        let t = segment - Double(index)

        let c1 = gradientColors[min(index, gradientColors.count - 1)]
        let c2 = gradientColors[min(index + 1, gradientColors.count - 1)]

        return RGB.lerp(c1, c2, t: t)
    }

    private func darken(_ color: RGB, by factor: Double) -> RGB {
        return RGB(
            r: UInt8(Double(color.r) * (1 - factor)),
            g: UInt8(Double(color.g) * (1 - factor)),
            b: UInt8(Double(color.b) * (1 - factor))
        )
    }

    private func drawPie(
        center: (x: Int, y: Int),
        radius: Int,
        remainingFraction: Double,
        color: RGB,
        in buffer: inout [UInt8]
    ) {
        for y in 0..<Self.size {
            for x in 0..<Self.size {
                let dx = Double(x - center.x)
                let dy = Double(y - center.y)
                let distance = sqrt(dx * dx + dy * dy)

                // Skip if outside circle
                if distance > Double(radius) { continue }

                // Calculate angle from 12 o'clock, clockwise (0 to 2π)
                var angle = atan2(dx, -dy)  // -dy so 12 o'clock = 0
                if angle < 0 { angle += 2 * .pi }

                // Draw if within remaining arc
                let remainingAngle = remainingFraction * 2 * .pi
                if angle < remainingAngle {
                    let offset = (y * Self.size + x) * 3
                    buffer[offset] = color.r
                    buffer[offset + 1] = color.g
                    buffer[offset + 2] = color.b
                }
            }
        }
    }

    private func drawNumber(_ number: Int, in buffer: inout [UInt8], color: RGB) {
        let digits = String(number).compactMap { $0.wholeNumberValue }

        // Calculate total width of all digits with spacing
        let scaledDigitWidth = PixelFont.digitWidth * digitScale
        let scaledDigitHeight = PixelFont.digitHeight * digitScale
        let spacing = 2 * digitScale
        let totalWidth = digits.count * scaledDigitWidth + (digits.count - 1) * spacing

        // Center the number
        var startX = (Self.size - totalWidth) / 2
        let startY = (Self.size - scaledDigitHeight) / 2

        for digit in digits {
            drawDigit(digit, at: (startX, startY), in: &buffer, color: color)
            startX += scaledDigitWidth + spacing
        }
    }

    private func drawDigit(_ digit: Int, at position: (x: Int, y: Int), in buffer: inout [UInt8], color: RGB) {
        for dy in 0..<PixelFont.digitHeight {
            for dx in 0..<PixelFont.digitWidth {
                if PixelFont.getPixel(digit: digit, x: dx, y: dy) {
                    // Scale up the pixel
                    for sy in 0..<digitScale {
                        for sx in 0..<digitScale {
                            let px = position.x + dx * digitScale + sx
                            let py = position.y + dy * digitScale + sy

                            if px >= 0 && px < Self.size && py >= 0 && py < Self.size {
                                let offset = (py * Self.size + px) * 3
                                buffer[offset] = color.r
                                buffer[offset + 1] = color.g
                                buffer[offset + 2] = color.b
                            }
                        }
                    }
                }
            }
        }
    }
}
