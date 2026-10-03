import Foundation
import XCTest
@testable import AppVolume

final class PersistenceServiceTests: XCTestCase {
    func testPersistsSettingsAndPerAppValues() throws {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceService(defaults: defaults)
        var settings = AppSettings()
        settings.startMinimized = false
        settings.refreshInterval = 0.5
        persistence.saveSettings(settings)
        persistence.saveVolume(0.35, for: "com.example.player")
        persistence.saveMute(true, for: "com.example.player")
        persistence.saveOutputDevice("device.airpods", for: "com.example.player")

        let restored = persistence.loadSettings()
        XCTAssertFalse(restored.startMinimized)
        XCTAssertEqual(restored.refreshInterval, 0.5)
        XCTAssertEqual(persistence.savedVolume(for: "com.example.player"), 0.35)
        XCTAssertEqual(persistence.savedMute(for: "com.example.player"), true)
        XCTAssertEqual(persistence.savedOutputDevice(for: "com.example.player"), "device.airpods")
    }

    func testResetRemovesOnlySavedPerAppValues() throws {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceService(defaults: defaults)
        var settings = AppSettings()
        settings.startMinimized = false
        persistence.saveSettings(settings)
        persistence.saveVolume(0.2, for: "com.example.player")
        persistence.saveMute(true, for: "com.example.player")

        persistence.resetSavedAppVolumes()

        XCTAssertNil(persistence.savedVolume(for: "com.example.player"))
        XCTAssertNil(persistence.savedMute(for: "com.example.player"))
        XCTAssertFalse(persistence.loadSettings().startMinimized)
    }
}
