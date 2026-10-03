import Foundation

final class AudioApplicationScanner {
    typealias Provider = () throws -> [AudioSession]

    private let provider: Provider

    init(provider: @escaping Provider) {
        self.provider = provider
    }

    func scan() throws -> [AudioSession] {
        Self.deduplicate(try provider())
    }

    static func deduplicate(_ sessions: [AudioSession]) -> [AudioSession] {
        var sessionsByBundleIdentifier: [String: AudioSession] = [:]

        for session in sessions where session.isActive {
            let identifier = session.bundleIdentifier.isEmpty
                ? "pid:\(session.processID)"
                : session.bundleIdentifier

            let candidate: AudioSession
            if session.bundleIdentifier.isEmpty {
                candidate = AudioSession(
                    bundleIdentifier: identifier,
                    processID: session.processID,
                    name: session.name,
                    icon: session.icon,
                    outputDeviceObjectID: session.outputDeviceObjectID,
                    outputDeviceID: session.outputDeviceID,
                    outputDeviceName: session.outputDeviceName,
                    isActive: session.isActive,
                    hasBundleIdentifier: false
                )
            } else {
                candidate = session
            }

            guard let current = sessionsByBundleIdentifier[identifier] else {
                sessionsByBundleIdentifier[identifier] = candidate
                continue
            }

            if shouldPrefer(candidate, over: current) {
                sessionsByBundleIdentifier[identifier] = candidate
            }
        }

        return sessionsByBundleIdentifier.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func shouldPrefer(_ candidate: AudioSession, over current: AudioSession) -> Bool {
        if candidate.hasBundleIdentifier != current.hasBundleIdentifier {
            return candidate.hasBundleIdentifier
        }

        let candidateHasApplicationMetadata = candidate.icon != nil || candidate.name != candidate.bundleIdentifier
        let currentHasApplicationMetadata = current.icon != nil || current.name != current.bundleIdentifier
        if candidateHasApplicationMetadata != currentHasApplicationMetadata {
            return candidateHasApplicationMetadata
        }

        return candidate.processID < current.processID
    }
}
