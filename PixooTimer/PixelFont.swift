//
//  PixelFont.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import Foundation

struct PixelFont {
    // 5x7 bitmap font for digits 0-9
    // Each digit is represented as an array of rows, where each row is an array of booleans
    static let digits: [[UInt8]] = [
        // 0
        [
            0b01110,
            0b10001,
            0b10011,
            0b10101,
            0b11001,
            0b10001,
            0b01110
        ],
        // 1
        [
            0b00100,
            0b01100,
            0b00100,
            0b00100,
            0b00100,
            0b00100,
            0b01110
        ],
        // 2
        [
            0b01110,
            0b10001,
            0b00001,
            0b00110,
            0b01000,
            0b10000,
            0b11111
        ],
        // 3
        [
            0b01110,
            0b10001,
            0b00001,
            0b00110,
            0b00001,
            0b10001,
            0b01110
        ],
        // 4
        [
            0b00010,
            0b00110,
            0b01010,
            0b10010,
            0b11111,
            0b00010,
            0b00010
        ],
        // 5
        [
            0b11111,
            0b10000,
            0b11110,
            0b00001,
            0b00001,
            0b10001,
            0b01110
        ],
        // 6
        [
            0b00110,
            0b01000,
            0b10000,
            0b11110,
            0b10001,
            0b10001,
            0b01110
        ],
        // 7
        [
            0b11111,
            0b00001,
            0b00010,
            0b00100,
            0b01000,
            0b01000,
            0b01000
        ],
        // 8
        [
            0b01110,
            0b10001,
            0b10001,
            0b01110,
            0b10001,
            0b10001,
            0b01110
        ],
        // 9
        [
            0b01110,
            0b10001,
            0b10001,
            0b01111,
            0b00001,
            0b00010,
            0b01100
        ]
    ]

    static let digitWidth = 5
    static let digitHeight = 7

    /// Returns the pixel data for a digit at the given position
    /// - Parameters:
    ///   - digit: The digit (0-9)
    ///   - x: X position within the digit (0-4)
    ///   - y: Y position within the digit (0-6)
    /// - Returns: true if the pixel should be on
    static func getPixel(digit: Int, x: Int, y: Int) -> Bool {
        guard digit >= 0 && digit <= 9 else { return false }
        guard x >= 0 && x < digitWidth && y >= 0 && y < digitHeight else { return false }

        let row = digits[digit][y]
        let bit = 4 - x // Bits are stored left-to-right, MSB first
        return (row >> bit) & 1 == 1
    }
}
