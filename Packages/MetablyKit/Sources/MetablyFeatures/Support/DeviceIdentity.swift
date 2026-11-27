import Foundation

/// A random per-install device id used for provenance and future sync.
/// It is not derived from hardware identifiers and carries no personal information.
enum DeviceIdentity {
    private static let key = "device.installationID"

    static func current(defaults: UserDefaults = .standard) -> UUID {
        if let stored = defaults.string(forKey: key), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }
}
