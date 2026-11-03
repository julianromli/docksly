import AppKit
import CoreGraphics
import Foundation

/// The parts of a connected display that stay the same when it is plugged in again.
struct DisplayIdentity: Hashable {
    var vendor: UInt32
    var model: UInt32
    var serial: UInt32
    var name: String

    /// Vendor, model, and serial. Two displays with serial 0 and the same model share a key.
    var key: String { "\(vendor)-\(model)-\(serial)" }

    /// The displays connected now, in no particular order.
    @MainActor
    static func current() -> [DisplayIdentity] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            return DisplayIdentity(
                vendor: CGDisplayVendorNumber(id),
                model: CGDisplayModelNumber(id),
                serial: CGDisplaySerialNumber(id),
                name: screen.localizedName
            )
        }
    }
}

enum DisplaySetKey {
    /// A key for a set of displays. The order of the displays does not change it.
    static func make(_ displays: [DisplayIdentity]) -> String {
        displays.map(\.key).sorted().joined(separator: "|")
    }

    /// A readable name for the set, for example "Studio Display + Built-in Retina Display".
    static func readableName(_ displays: [DisplayIdentity]) -> String {
        let names = displays.map(\.name).sorted()
        return names.isEmpty ? "No display" : names.joined(separator: " + ")
    }
}

/// "This exact set of displays → this dock". Stored in the library.
struct DisplayRule: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var setKey: String
    /// Shown in Settings, so the user can tell the rules apart.
    var setName: String
    var profileID: UUID

    init(id: UUID = UUID(), setKey: String, setName: String, profileID: UUID) {
        self.id = id
        self.setKey = setKey
        self.setName = setName
        self.profileID = profileID
    }
}

enum DisplayRuleResolver {
    /// The dock for an exact display set. A set with no rule changes nothing.
    static func profileID(for setKey: String, in rules: [DisplayRule]) -> UUID? {
        rules.first { $0.setKey == setKey }?.profileID
    }

    /// Adds a rule for the set, or moves an existing rule for the same set to the new dock.
    static func upsert(_ rule: DisplayRule, into rules: [DisplayRule]) -> [DisplayRule] {
        var result = rules
        if let index = result.firstIndex(where: { $0.setKey == rule.setKey }) {
            result[index].profileID = rule.profileID
            result[index].setName = rule.setName
        } else {
            result.append(rule)
        }
        return result
    }
}
