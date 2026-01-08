//
//  FallbackTimerView.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import SwiftUI

struct FallbackTimerView: View {
    let minutes: Int
    let progress: Double
    let isFlashing: Bool

    // Same gradient colors as Pixoo display (vivid)
    private let cyan = Color(red: 0/255, green: 220/255, blue: 255/255)      // Bright Cyan
    private let blue = Color(red: 30/255, green: 100/255, blue: 255/255)     // Electric Blue
    private let purple = Color(red: 160/255, green: 50/255, blue: 255/255)   // Vivid Purple
    private let flashColor = Color(red: 255/255, green: 180/255, blue: 100/255)

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(isFlashing ? 0 : 1)

            // Flash overlay
            if isFlashing {
                flashColor
            }

            // Pie chart (remaining time) - darker than background
            if !isFlashing {
                Circle()
                    .trim(from: 0, to: 1.0 - progress)
                    .rotation(.degrees(-90))
                    .fill(pieColor)
                    .frame(width: 90, height: 90)
            }

            // Minutes display
            Text("\(minutes)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var gradientColors: [Color] {
        // Return colors based on progress for a smooth gradient effect
        if progress < 0.5 {
            return [cyan, blue]
        } else {
            return [blue, purple]
        }
    }

    private var pieColor: Color {
        // 40% darker version of current gradient color (approximated with opacity)
        let baseColor = progress < 0.5 ? cyan : blue
        return baseColor.opacity(0.6)
    }
}

#Preview {
    VStack(spacing: 20) {
        FallbackTimerView(minutes: 25, progress: 0.0, isFlashing: false)
        FallbackTimerView(minutes: 10, progress: 0.5, isFlashing: false)
        FallbackTimerView(minutes: 1, progress: 0.95, isFlashing: false)
        FallbackTimerView(minutes: 0, progress: 1.0, isFlashing: true)
    }
    .padding()
    .background(Color.gray)
}
