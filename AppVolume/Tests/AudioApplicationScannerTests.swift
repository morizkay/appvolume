import Foundation
import XCTest
@testable import AppVolume

final class AudioApplicationScannerTests: XCTestCase {
    func testScanDeduplicatesByBundleIdentifierAndIgnoresInactiveSessions() throws {
        let sessions = [
            makeSession(bundleIdentifier: "com.example.player", processID: 300, name: "Player"),
            makeSession(bundleIdentifier: "com.example.player", processID: 200, name: "Player helper"),
            makeSession(bundleIdentifier: "com.example.paused", processID: 100, name: "Paused", isActive: false)
        ]

        let scanner = AudioApplicationScanner(provider: { sessions })
        let result = try scanner.scan()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.bundleIdentifier, "com.example.player")
        XCTAssertEqual(result.first?.processID, 200)
    }

    func testScannerPrefersSessionWithApplicationMetadata() throws {
        let sessions = [
            makeSession(bundleIdentifier: "com.example.player", processID: 100, name: "com.example.player"),
            makeSession(bundleIdentifier: "com.example.player", processID: 200, name: "Player")
        ]

        let scanner = AudioApplicationScanner(provider: { sessions })
        let result = try scanner.scan()

        XCTAssertEqual(result.first?.processID, 200)
    }

    private func makeSession(
        bundleIdentifier: String,
        processID: Int32,
        name: String,
        isActive: Bool = true
    ) -> AudioSession {
        AudioSession(
            bundleIdentifier: bundleIdentifier,
            processID: processID,
            name: name,
            icon: nil,
            outputDeviceObjectID: nil,
            outputDeviceID: nil,
            outputDeviceName: nil,
            isActive: isActive,
            hasBundleIdentifier: !bundleIdentifier.isEmpty
        )
    }
}
