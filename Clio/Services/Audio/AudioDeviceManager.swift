import AVFoundation
import CoreAudio
import os

/// Manages audio input device enumeration and selection.
@MainActor
@Observable
final class AudioDeviceManager {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AudioDevice")

    struct AudioDevice: Identifiable, Hashable {
        let id: AudioDeviceID
        let name: String
        let uid: String
        let isDefault: Bool
    }

    var availableInputDevices: [AudioDevice] = []
    var selectedDeviceUID: String? {
        didSet {
            UserDefaults.standard.set(selectedDeviceUID, forKey: "selectedMicrophoneUID")
        }
    }

    init() {
        selectedDeviceUID = UserDefaults.standard.string(forKey: "selectedMicrophoneUID")
        refreshDevices()
    }

    func refreshDevices() {
        let defaultID = getDefaultInputDeviceID()
        availableInputDevices = getInputDevices().map { device in
            AudioDevice(
                id: device.id,
                name: device.name,
                uid: device.uid,
                isDefault: device.id == defaultID
            )
        }

        // If no device is selected, use default
        if selectedDeviceUID == nil, let defaultDevice = availableInputDevices.first(where: \.isDefault) {
            selectedDeviceUID = defaultDevice.uid
        }

        logger.info("Found \(self.availableInputDevices.count) input devices")
    }

    /// Returns the AudioDeviceID for the currently selected device, or the system default.
    var selectedDeviceID: AudioDeviceID? {
        if let uid = selectedDeviceUID,
           let device = availableInputDevices.first(where: { $0.uid == uid }) {
            return device.id
        }
        return getDefaultInputDeviceID()
    }

    // MARK: - CoreAudio Helpers

    private func getDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func getInputDevices() -> [(id: AudioDeviceID, name: String, uid: String)] {
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

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { deviceID -> (id: AudioDeviceID, name: String, uid: String)? in
            // Check if device has input channels
            guard hasInputChannels(deviceID) else { return nil }
            guard let name = getDeviceName(deviceID),
                  let uid = getDeviceUID(deviceID) else { return nil }
            return (id: deviceID, name: name, uid: uid)
        }
    }

    private func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        let bufferListData = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListData.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListData) == noErr else {
            return false
        }

        let bufferList = bufferListData.assumingMemoryBound(to: AudioBufferList.self).pointee
        return bufferList.mNumberBuffers > 0
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else {
            return nil
        }
        return name as String
    }

    private func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid) == noErr else {
            return nil
        }
        return uid as String
    }
}
