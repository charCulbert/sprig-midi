import CoreMIDI
import Foundation

final class MIDIManager {
    struct Port {
        let id: String
        let name: String
    }

    var onDevicesChanged: (() -> Void)?

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var started = false

    func start() {
        var status = MIDIClientCreateWithBlock("Sprig" as CFString, &client) { [weak self] notification in
            switch notification.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved, .msgPropertyChanged:
                DispatchQueue.main.async { self?.onDevicesChanged?() }
            default:
                break
            }
        }
        if status == noErr {
            status = MIDIOutputPortCreate(client, "Sprig Output" as CFString, &outputPort)
        }
        started = status == noErr
        if !started {
            NSLog("CoreMIDI setup failed: %d", status)
        }
    }

    var outputs: [Port] {
        destinations.map { Port(id: endpointID($0), name: endpointName($0)) }
    }

    func send(_ bytes: [UInt8], to outputID: String) {
        guard started, let destination = destinations.first(where: { endpointID($0) == outputID }) else { return }
        // UMP: MIDI 1.0 channel voice, group 0
        let word = 0x2000_0000 | UInt32(bytes[0]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[2])
        var eventList = MIDIEventList()
        let packet = MIDIEventListInit(&eventList, ._1_0)
        MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, [word])
        MIDISendEventList(outputPort, destination, &eventList)
    }

    private var destinations: [MIDIEndpointRef] {
        (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).filter { $0 != 0 }
    }

    private func endpointID(_ endpoint: MIDIEndpointRef) -> String {
        var uniqueID = MIDIUniqueID()
        if MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID) == noErr {
            return String(uniqueID)
        }
        return String(endpoint)
    }

    private func stringProperty(_ endpoint: MIDIEndpointRef, _ property: CFString) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, property, &value) == noErr else {
            return nil
        }
        return value?.takeRetainedValue() as String?
    }

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        stringProperty(endpoint, kMIDIPropertyDisplayName)
            ?? stringProperty(endpoint, kMIDIPropertyName)
            ?? "MIDI Device"
    }
}
