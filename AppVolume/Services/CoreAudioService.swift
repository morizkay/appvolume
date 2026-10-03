import AppKit
import CoreAudio
import Foundation
import OSLog

final class CoreAudioService: AudioService {
    let capabilities = AudioCapabilities(
        canControlApplicationVolume: false,
        canMuteApplications: false,
        canRouteApplications: false,
        canControlSystemVolume: true,
        explanation: "macOS public Core Audio exposes active process metadata and device controls, but it does not expose a writable per-application gain, mute, or output-route property. AppVolume does not pretend these controls work."
    )

    private let logger = Logger(subsystem: "com.morizkay.AppVolume", category: "CoreAudio")
    private let systemVolumeService: SystemVolumeService
    private let routingService: AudioRoutingService
    private let scanner: AudioApplicationScanner

    init(
        systemVolumeService: SystemVolumeService = CoreAudioSystemVolumeService(),
        routingService: AudioRoutingService = UnavailableAudioRoutingService(),
        scanner: AudioApplicationScanner? = nil
    ) {
        self.systemVolumeService = systemVolumeService
        self.routingService = routingService
        self.scanner = scanner ?? AudioApplicationScanner(provider: CoreAudioHAL.readProcessSessions)
    }

    func snapshot() throws -> AudioSnapshot {
        let devices = try CoreAudioHAL.readDevices()
        let sessions: [AudioSession]
        var notice: String?

        if #available(macOS 14.2, *) {
            sessions = try scanner.scan().map { session in
                var mappedSession = session
                if let objectID = session.outputDeviceObjectID,
                   let device = devices.first(where: { $0.objectID == objectID }) {
                    mappedSession.outputDeviceID = device.uid
                    mappedSession.outputDeviceName = device.name
                }
                return mappedSession
            }
        } else {
            sessions = []
            notice = "Active application audio detection requires macOS 14.2 or later. System volume controls remain available."
        }

        let system = try systemVolumeService.currentState(devices: devices)
        if notice == nil {
            notice = system.notice
        }

        logger.debug("Scanned \(sessions.count, privacy: .public) active audio applications and \(devices.count, privacy: .public) devices")
        return AudioSnapshot(applications: sessions, devices: devices, system: system, notice: notice)
    }

    func setApplicationVolume(_ volume: Double, for bundleIdentifier: String) throws {
        throw AudioServiceError.unsupported(.applicationVolume, capabilities.explanation)
    }

    func setApplicationMuted(_ muted: Bool, for bundleIdentifier: String) throws {
        throw AudioServiceError.unsupported(.applicationMute, capabilities.explanation)
    }

    func setApplicationOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws {
        guard routingService.capabilities.canRouteApplications else {
            throw AudioServiceError.unsupported(.applicationRouting, routingService.capabilities.explanation)
        }
        try routingService.setOutputDevice(deviceID, for: bundleIdentifier)
    }

    func setSystemVolume(_ volume: Double) throws {
        try systemVolumeService.setVolume(volume)
    }

    func setSystemMuted(_ muted: Bool) throws {
        try systemVolumeService.setMuted(muted)
    }

    func openSoundSettings() {
        systemVolumeService.openSoundSettings()
    }
}

enum CoreAudioHAL {
    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func readDevices() throws -> [AudioDevice] {
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        let deviceIDs = try readArray(AudioObjectID.self, objectID: systemObjectID, address: address(kAudioHardwarePropertyDevices))
        let defaultOutputID = try? defaultOutputDeviceObjectID()

        return deviceIDs.compactMap { objectID in
            guard hasOutputChannels(objectID: objectID) else { return nil }

            let uid = (try? readString(objectID: objectID, address: address(kAudioDevicePropertyDeviceUID))) ?? "audio-device-\(objectID)"
            let name = (try? readString(objectID: objectID, address: address(kAudioObjectPropertyName))) ?? uid
            let transportType = try? readValue(UInt32.self, objectID: objectID, address: address(kAudioDevicePropertyTransportType))
            let isVirtual = transportType == kAudioDeviceTransportTypeVirtual ||
                transportType == kAudioDeviceTransportTypeAggregate ||
                transportType == kAudioDeviceTransportTypeAutoAggregate

            return AudioDevice(
                objectID: objectID,
                uid: uid,
                name: name,
                isVirtual: isVirtual,
                isDefaultOutput: objectID == defaultOutputID
            )
        }
    }

    static func defaultOutputDeviceObjectID() throws -> AudioObjectID {
        try readValue(
            AudioObjectID.self,
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address(kAudioHardwarePropertyDefaultOutputDevice)
        )
    }

    static func readProcessSessions() throws -> [AudioSession] {
        guard #available(macOS 14.2, *) else {
            throw AudioServiceError.unsupported(
                .applicationScanning,
                "The public Core Audio process object list was introduced in macOS 14.2."
            )
        }

        let processObjectIDs = try readArray(
            AudioObjectID.self,
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address(kAudioHardwarePropertyProcessObjectList)
        )

        return processObjectIDs.compactMap { processObjectID -> AudioSession? in
            guard let runningOutput = try? readValue(
                UInt32.self,
                objectID: processObjectID,
                address: address(kAudioProcessPropertyIsRunningOutput)
            ), runningOutput != 0 else {
                return nil
            }

            guard let processID = try? readValue(
                pid_t.self,
                objectID: processObjectID,
                address: address(kAudioProcessPropertyPID)
            ) else {
                return nil
            }

            let runningApplication = NSRunningApplication(processIdentifier: processID)
            let coreBundleIdentifier = try? readString(
                objectID: processObjectID,
                address: address(kAudioProcessPropertyBundleID)
            )
            let resolvedBundleIdentifier = (coreBundleIdentifier?.isEmpty == false ? coreBundleIdentifier : nil)
                ?? runningApplication?.bundleIdentifier
            let hasBundleIdentifier = !(resolvedBundleIdentifier?.isEmpty ?? true)
            let bundleIdentifier: String
            if let resolvedBundleIdentifier, !resolvedBundleIdentifier.isEmpty {
                bundleIdentifier = resolvedBundleIdentifier
            } else {
                bundleIdentifier = "pid:\(processID)"
            }
            let name = runningApplication?.localizedName ?? resolvedBundleIdentifier ?? "Audio process \(processID)"
            let outputDeviceObjectID = ((try? readArray(
                AudioObjectID.self,
                objectID: processObjectID,
                address: address(kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeOutput)
            )) ?? []).first

            return AudioSession(
                bundleIdentifier: bundleIdentifier,
                processID: Int32(processID),
                name: name,
                icon: runningApplication?.icon,
                outputDeviceObjectID: outputDeviceObjectID,
                outputDeviceID: nil,
                outputDeviceName: nil,
                isActive: true,
                hasBundleIdentifier: hasBundleIdentifier
            )
        }
    }

    static func systemVolume(for objectID: AudioObjectID) throws -> Float32 {
        if let mainValue = try? readValue(
            Float32.self,
            objectID: objectID,
            address: address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput)
        ) {
            return min(max(mainValue, 0), 1)
        }

        let channelValues = [1, 2].compactMap { element -> Float32? in
            try? readValue(
                Float32.self,
                objectID: objectID,
                address: address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput, element: AudioObjectPropertyElement(element))
            )
        }
        guard !channelValues.isEmpty else {
            throw AudioServiceError.propertyUnavailable("output volume")
        }
        return min(max(channelValues.reduce(0, +) / Float32(channelValues.count), 0), 1)
    }

    static func systemMuted(for objectID: AudioObjectID) throws -> Bool {
        if let mainValue = try? readValue(
            UInt32.self,
            objectID: objectID,
            address: address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        ) {
            return mainValue != 0
        }

        let channelValues = [1, 2].compactMap { element -> UInt32? in
            try? readValue(
                UInt32.self,
                objectID: objectID,
                address: address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: AudioObjectPropertyElement(element))
            )
        }
        guard let first = channelValues.first else {
            throw AudioServiceError.propertyUnavailable("output mute")
        }
        return channelValues.contains { $0 != 0 } || first != 0
    }

    static func isSystemVolumeSettable(for objectID: AudioObjectID) -> Bool {
        if isPropertySettable(objectID: objectID, address: address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput)) {
            return true
        }
        return [1, 2].contains {
            isPropertySettable(
                objectID: objectID,
                address: address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput, element: AudioObjectPropertyElement($0))
            )
        }
    }

    static func isSystemMuteSettable(for objectID: AudioObjectID) -> Bool {
        if isPropertySettable(objectID: objectID, address: address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)) {
            return true
        }
        return [1, 2].contains {
            isPropertySettable(
                objectID: objectID,
                address: address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: AudioObjectPropertyElement($0))
            )
        }
    }

    static func setSystemVolume(_ volume: Double, for objectID: AudioObjectID) throws {
        let value = Float32(min(max(volume, 0), 1))
        let mainAddress = address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput)
        if isPropertySettable(objectID: objectID, address: mainAddress) {
            try writeValue(value, objectID: objectID, address: mainAddress)
            return
        }

        var lastError: Error?
        var didWrite = false
        for element in [1, 2] {
            let channelAddress = address(
                kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: AudioObjectPropertyElement(element)
            )
            guard isPropertySettable(objectID: objectID, address: channelAddress) else { continue }
            do {
                try writeValue(value, objectID: objectID, address: channelAddress)
                didWrite = true
            } catch {
                lastError = error
            }
        }

        if didWrite { return }
        if let lastError { throw lastError }
        throw AudioServiceError.propertyUnavailable("writable output volume")
    }

    static func setSystemMuted(_ muted: Bool, for objectID: AudioObjectID) throws {
        let value: UInt32 = muted ? 1 : 0
        let mainAddress = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        if isPropertySettable(objectID: objectID, address: mainAddress) {
            try writeValue(value, objectID: objectID, address: mainAddress)
            return
        }

        var lastError: Error?
        var didWrite = false
        for element in [1, 2] {
            let channelAddress = address(
                kAudioDevicePropertyMute,
                scope: kAudioObjectPropertyScopeOutput,
                element: AudioObjectPropertyElement(element)
            )
            guard isPropertySettable(objectID: objectID, address: channelAddress) else { continue }
            do {
                try writeValue(value, objectID: objectID, address: channelAddress)
                didWrite = true
            } catch {
                lastError = error
            }
        }

        if didWrite { return }
        if let lastError { throw lastError }
        throw AudioServiceError.propertyUnavailable("writable output mute")
    }

    private static func hasOutputChannels(objectID: AudioObjectID) -> Bool {
        guard let data = try? readData(
            objectID: objectID,
            address: address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        ) else {
            return false
        }

        return data.withUnsafeBytes { bytes in
            guard bytes.count >= MemoryLayout<UInt32>.size else { return false }
            let bufferCount = bytes.loadUnaligned(as: UInt32.self)
            var offset = MemoryLayout<UInt32>.size
            for _ in 0..<Int(bufferCount) {
                guard offset + MemoryLayout<AudioBuffer>.size <= bytes.count else { return false }
                let buffer = bytes.loadUnaligned(fromByteOffset: offset, as: AudioBuffer.self)
                if buffer.mNumberChannels > 0 { return true }
                offset += MemoryLayout<AudioBuffer>.stride
            }
            return false
        }
    }

    private static func readData(objectID: AudioObjectID, address inputAddress: AudioObjectPropertyAddress) throws -> Data {
        var address = inputAddress
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr else {
            throw AudioServiceError.osStatus(sizeStatus, operation: "reading the Core Audio property size")
        }
        guard dataSize > 0 else { return Data() }

        var data = Data(count: Int(dataSize))
        var actualSize = dataSize
        let status = data.withUnsafeMutableBytes { bytes -> OSStatus in
            guard let baseAddress = bytes.baseAddress else {
                return kAudioHardwareBadPropertySizeError
            }
            return AudioObjectGetPropertyData(objectID, &address, 0, nil, &actualSize, baseAddress)
        }
        guard status == noErr else {
            throw AudioServiceError.osStatus(status, operation: "reading a Core Audio property")
        }

        let usedSize = min(Int(actualSize), data.count)
        if usedSize < data.count {
            data.removeSubrange(usedSize..<data.count)
        }
        return data
    }

    private static func readValue<T>(_ type: T.Type, objectID: AudioObjectID, address: AudioObjectPropertyAddress) throws -> T {
        let data = try readData(objectID: objectID, address: address)
        guard data.count >= MemoryLayout<T>.size else {
            throw AudioServiceError.propertyUnavailable("property value")
        }
        return data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(as: T.self)
        }
    }

    private static func readArray<T>(_ type: T.Type, objectID: AudioObjectID, address: AudioObjectPropertyAddress) throws -> [T] {
        let data = try readData(objectID: objectID, address: address)
        let stride = MemoryLayout<T>.stride
        guard stride > 0 else { return [] }
        let count = data.count / stride
        return (0..<count).map { index in
            data.withUnsafeBytes { bytes in
                bytes.loadUnaligned(fromByteOffset: index * stride, as: T.self)
            }
        }
    }

    private static func readString(objectID: AudioObjectID, address inputAddress: AudioObjectPropertyAddress) throws -> String? {
        var address = inputAddress
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr else {
            throw AudioServiceError.osStatus(status, operation: "reading a Core Audio string")
        }
        guard let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func isPropertySettable(objectID: AudioObjectID, address inputAddress: AudioObjectPropertyAddress) -> Bool {
        var address = inputAddress
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private static func writeValue<T>(_ value: T, objectID: AudioObjectID, address inputAddress: AudioObjectPropertyAddress) throws {
        var address = inputAddress
        var mutableValue = value
        let dataSize = UInt32(MemoryLayout<T>.size)
        let status = withUnsafePointer(to: &mutableValue) { pointer in
            AudioObjectSetPropertyData(objectID, &address, 0, nil, dataSize, UnsafeRawPointer(pointer))
        }
        guard status == noErr else {
            throw AudioServiceError.osStatus(status, operation: "writing a Core Audio property")
        }
    }
}
