# PixooTimer

A macOS menu bar app that displays a visual countdown timer on your [Divoom Pixoo 64](https://divoom.com/products/pixoo-64) LED display.

![Timer Display](https://img.shields.io/badge/Platform-macOS%2014%2B-blue)

## Features

- **Menu bar timer** - Quick access to preset durations (5, 10, 15, 25, 45 minutes)
- **Pixoo 64 integration** - Displays timer on your LED panel with vivid gradient colors
- **Time Timer-style progress** - Shrinking pie chart shows remaining time at a glance
- **Mac fallback display** - Floating window when Pixoo is unavailable
- **Completion alerts** - Buzzer on Pixoo or customizable system sounds on Mac

## Screenshots

The timer displays:
- Bright cyan → electric blue → vivid purple gradient as time progresses
- Darker pie chart that shrinks clockwise from 12 o'clock
- Large, readable minute count centered on the display

## Requirements

- macOS 14.0 (Sonoma) or later
- Divoom Pixoo 64 on the same network (optional)

## Setup

1. Build and run in Xcode
2. Click the timer icon in the menu bar
3. Go to **Settings** and enter your Pixoo 64's IP address
4. Click **Test Connection** to verify

To find your Pixoo's IP address, open the Divoom app → Device → Settings.

## Usage

- Click the menu bar icon to select a timer duration
- The timer appears on your Pixoo (or as a floating Mac window)
- When complete, the Pixoo buzzes or Mac plays your selected sound
- Click **Cancel Timer** to stop early

## How It Works

The app communicates with the Pixoo 64 via its local HTTP API:
- Renders 64x64 RGB frames with the timer display
- Sends frames every 5 seconds to update the progress
- Saves and restores your previous Pixoo channel when done

## License

MIT
