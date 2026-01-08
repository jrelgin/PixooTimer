//
//  SettingsView.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("pixooIP") private var ipAddress: String = ""
    @AppStorage("completionSound") private var selectedSound: String = "Glass"
    @State private var testStatus: TestStatus = .idle
    @State private var isTesting: Bool = false

    let pixooClient: PixooClient

    private let systemSounds = ["Glass", "Ping", "Hero", "Submarine", "Funk",
                                "Sosumi", "Basso", "Blow", "Bottle", "Frog",
                                "Morse", "Pop", "Purr", "Tink"]

    enum TestStatus {
        case idle
        case testing
        case success
        case failure
    }

    var body: some View {
        Form {
            Section {
                TextField("Pixoo IP Address", text: $ipAddress)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: ipAddress) { _, newValue in
                        pixooClient.ipAddress = newValue
                        testStatus = .idle
                    }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(ipAddress.isEmpty || isTesting)

                    Spacer()

                    statusIndicator
                }
            } header: {
                Text("Pixoo Device")
            } footer: {
                Text("Enter the IP address of your Pixoo 64. You can find this in the Divoom app settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("Completion Sound", selection: $selectedSound) {
                    ForEach(systemSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }

                Button("Preview") {
                    playSound(selectedSound)
                }
            } header: {
                Text("Mac Fallback")
            } footer: {
                Text("Sound plays when timer completes (if Pixoo unavailable).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 280)
        .padding()
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .scaleEffect(0.7)
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .failure:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testStatus = .testing

        Task {
            let success = await pixooClient.testConnection()
            await MainActor.run {
                testStatus = success ? .success : .failure
                isTesting = false
            }
        }
    }

    private func playSound(_ name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        }
    }
}

#Preview {
    SettingsView(pixooClient: PixooClient())
}
