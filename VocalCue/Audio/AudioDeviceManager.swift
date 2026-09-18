import Foundation
import CoreAudio
import Combine

// MARK: - AudioDevice Model

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}

// MARK: - AudioDeviceManager

class AudioDeviceManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var outputDevices: [AudioDevice] = []
    @Published var selectedInputDeviceID: AudioDeviceID?
    @Published var selectedOutputDeviceID: AudioDeviceID?

    private var listenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        refreshDevices()
        observeDeviceChanges()
    }

    deinit {
        removeDeviceObserver()
    }

    // MARK: - Public API

    func refreshDevices() {
        let allDevices = getAllDevices()
        inputDevices = allDevices.filter { $0.hasInput }
        outputDevices = allDevices.filter { $0.hasOutput }

        if selectedInputDeviceID == nil {
            selectedInputDeviceID = getDefaultDevice(forInput: true)
        }
        if selectedOutputDeviceID == nil {
            selectedOutputDeviceID = getDefaultDevice(forInput: false)
        }
    }

    func setBufferSize(_ frames: UInt32, forDevice deviceID: AudioDeviceID) {
        var bufferSize = frames
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &bufferSize
        )
    }

    func isBuiltInSpeaker(_ deviceID: AudioDeviceID) -> Bool {
        guard let name = getDeviceName(deviceID) else { return false }
        let lower = name.lowercased()
        return lower.contains("built-in") || lower.contains("macbook") || lower.contains("speaker")
    }

    func getDefaultDevice(forInput: Bool) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: forInput
                ? kAudioHardwarePropertyDefaultInputDevice
                : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    /// Returns the clock domain ID for a given device. Devices sharing the same
    /// clock domain are synchronized; mixing different domains causes drift.
    func clockDomain(for deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyClockDomain,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var domain: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &domain)
        return status == noErr ? domain : nil
    }

    /// Check whether two devices share the same clock. If they don't, the user
    /// risks periodic audio glitches from clock drift.
    func areDevicesOnSameClock(inputID: AudioDeviceID, outputID: AudioDeviceID) -> Bool {
        guard let inClock = clockDomain(for: inputID),
              let outClock = clockDomain(for: outputID) else {
            return true  // If we can't determine, assume OK
        }
        return inClock == outClock
    }

    // MARK: - Private Helpers

    private func getAllDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { id -> AudioDevice? in
            guard let name = getDeviceName(id),
                  let uid = getDeviceUID(id) else { return nil }

            let hasInput = streamCount(id, scope: kAudioObjectPropertyScopeInput) > 0
            let hasOutput = streamCount(id, scope: kAudioObjectPropertyScopeOutput) > 0

            guard hasInput || hasOutput else { return nil }
            return AudioDevice(id: id, uid: uid, name: name, hasInput: hasInput, hasOutput: hasOutput)
        }
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var prop: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &prop)
        guard status == noErr, let cfName = prop?.takeUnretainedValue() else { return nil }
        return cfName as String
    }

    private func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var prop: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &prop)
        guard status == noErr, let cfUID = prop?.takeUnretainedValue() else { return nil }
        return cfUID as String
    }

    private func streamCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr else { return 0 }
        return Int(dataSize) / MemoryLayout<AudioStreamID>.size
    }

    // MARK: - Device Change Observation

    private func observeDeviceChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }
        self.listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func removeDeviceObserver() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }
}
