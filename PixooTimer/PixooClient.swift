//
//  PixooClient.swift
//  PixooTimer
//
//  Created by Jason Elgin on 1/8/26.
//

import Foundation

enum PixooError: Error {
    case noIPConfigured
    case networkError(Error)
    case invalidResponse
    case apiError(Int)
}

class PixooClient {
    static let shared = PixooClient()

    private let session: URLSession
    private let timeout: TimeInterval = 5.0

    var ipAddress: String {
        get { UserDefaults.standard.string(forKey: "pixooIP") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "pixooIP") }
    }

    var isConfigured: Bool {
        !ipAddress.isEmpty
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Core API

    func sendCommand(_ payload: [String: Any]) async throws -> [String: Any] {
        guard !ipAddress.isEmpty else {
            throw PixooError.noIPConfigured
        }

        guard let url = URL(string: "http://\(ipAddress)/post") else {
            throw PixooError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PixooError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PixooError.invalidResponse
        }

        if let errorCode = json["error_code"] as? Int, errorCode != 0 {
            throw PixooError.apiError(errorCode)
        }

        return json
    }

    // MARK: - Channel Commands

    func getCurrentChannel() async throws -> Int {
        let response = try await sendCommand(["Command": "Channel/GetIndex"])
        guard let selectIndex = response["SelectIndex"] as? Int else {
            throw PixooError.invalidResponse
        }
        return selectIndex
    }

    func setChannel(_ index: Int) async throws {
        _ = try await sendCommand([
            "Command": "Channel/SetIndex",
            "SelectIndex": index
        ])
    }

    // MARK: - Animation Commands

    func resetAnimationId() async throws {
        _ = try await sendCommand(["Command": "Draw/ResetHttpGifId"])
    }

    func sendFrame(_ rgbData: Data, picId: Int = 1) async throws {
        let base64Data = rgbData.base64EncodedString()

        _ = try await sendCommand([
            "Command": "Draw/SendHttpGif",
            "PicID": picId,
            "PicNum": 1,
            "PicOffset": 0,
            "PicWidth": 64,
            "PicSpeed": 1000,
            "PicData": base64Data
        ])
    }

    // MARK: - Device Commands

    func playBuzzer(activeMs: Int = 500, offMs: Int = 500, totalMs: Int = 3000) async throws {
        _ = try await sendCommand([
            "Command": "Device/PlayBuzzer",
            "ActiveTimeInCycle": activeMs,
            "OffTimeInCycle": offMs,
            "PlayTotalTime": totalMs
        ])
    }

    // MARK: - Connection Test

    func testConnection() async -> Bool {
        do {
            _ = try await getCurrentChannel()
            return true
        } catch {
            return false
        }
    }

    /// Quick connection check with shorter timeout for startup
    func quickCheck() async -> Int? {
        guard isConfigured else { return nil }

        // Create a session with shorter timeout for quick check
        let quickConfig = URLSessionConfiguration.default
        quickConfig.timeoutIntervalForRequest = 1.5
        quickConfig.timeoutIntervalForResource = 1.5
        let quickSession = URLSession(configuration: quickConfig)

        guard let url = URL(string: "http://\(ipAddress)/post") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["Command": "Channel/GetIndex"])

        do {
            let (data, response) = try await quickSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let channel = json["SelectIndex"] as? Int else {
                return nil
            }
            return channel
        } catch {
            return nil
        }
    }
}
