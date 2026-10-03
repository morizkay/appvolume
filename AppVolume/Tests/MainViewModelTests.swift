import Foundation
import XCTest
@testable import AppVolume

@MainActor
final class MainViewModelTests: XCTestCase {
    func testRestoresVolumeAndRemovesApplicationWhenItsSessionEnds() throws {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceService(defaults: defaults)
        persistence.saveVolume(0.4, for: "com.spotify.client")
        persistence.saveMute(true, for: "com.spotify.client")
        let service = MockAudioService()
        let viewModel = MainViewModel(audioService: service, persistence: persistence)

        viewModel.refresh()

        let spotify = try XCTUnwrap(viewModel.applications.first(where: { $0.id == "com.spotify.client" }))
        XCTAssertEqual(spotify.application.volume, 0.4)
        XCTAssertTrue(spotify.application.isMuted)

        service.removeSession(bundleIdentifier: "com.spotify.client")
        viewModel.refresh()

        XCTAssertNil(viewModel.applications.first(where: { $0.id == "com.spotify.client" }))
    }

    func testShowInactiveKeepsExitedApplicationAsInactive() throws {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceService(defaults: defaults)
        var settings = AppSettings()
        settings.showInactiveAudioApplications = true
        persistence.saveSettings(settings)
        let service = MockAudioService()
        let viewModel = MainViewModel(audioService: service, persistence: persistence)

        viewModel.refresh()
        service.removeSession(bundleIdentifier: "com.spotify.client")
        viewModel.refresh()

        let inactive = try XCTUnwrap(viewModel.applications.first(where: { $0.id == "com.spotify.client" }))
        XCTAssertFalse(inactive.application.isActive)
    }

    func testPerAppChangeDoesNotChangeSystemVolume() throws {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceService(defaults: defaults)
        let service = MockAudioService(systemVolume: 0.8)
        let viewModel = MainViewModel(audioService: service, persistence: persistence)
        viewModel.refresh()
        let spotify = try XCTUnwrap(viewModel.applications.first(where: { $0.id == "com.spotify.client" }))

        spotify.setVolume(0.25)

        XCTAssertEqual(service.systemVolume, 0.8)
        XCTAssertEqual(persistence.savedVolume(for: "com.spotify.client"), 0.25)
    }

    func testInvalidAudioDeviceIsReported() {
        let service = MockAudioService()

        XCTAssertThrowsError(try service.setApplicationOutputDevice("missing-device", for: "com.spotify.client")) { error in
            XCTAssertEqual(error as? AudioServiceError, .deviceNotFound("missing-device"))
        }
    }

    func testEmptyAudioStateHasNoError() {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = MainViewModel(
            audioService: MockAudioService(sessions: []),
            persistence: PersistenceService(defaults: defaults)
        )
        viewModel.refresh()

        XCTAssertTrue(viewModel.applications.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testAudioServiceFailureProducesErrorState() {
        let suiteName = "AppVolumeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = MainViewModel(
            audioService: FailingAudioService(),
            persistence: PersistenceService(defaults: defaults)
        )
        viewModel.refresh()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class FailingAudioService: AudioService {
    let capabilities = AudioCapabilities(
        canControlApplicationVolume: false,
        canMuteApplications: false,
        canRouteApplications: false,
        canControlSystemVolume: false,
        explanation: "Test failure"
    )

    func snapshot() throws -> AudioSnapshot {
        throw AudioServiceError.unavailable("Test audio service failure")
    }

    func setApplicationVolume(_ volume: Double, for bundleIdentifier: String) throws {}
    func setApplicationMuted(_ muted: Bool, for bundleIdentifier: String) throws {}
    func setApplicationOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws {}
    func setSystemVolume(_ volume: Double) throws {}
    func setSystemMuted(_ muted: Bool) throws {}
    func openSoundSettings() {}
}
