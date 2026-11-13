import Foundation

struct CarSnapshot: Decodable {
    let schemaVersion: Int
    let statusTime: Double
    let batteryPercent: Double?
    let totalRangeKm: Double?
    let electricRangeKm: Double?
    let fuelLitres: Double?
    let cabinTemp: Double?
    let outsideTemp: Double?
    let actionToken: String?

    var date: Date { Date(timeIntervalSince1970: statusTime / 1_000) }

    static func containingAppURL(extensionURL: URL) -> URL? {
        let candidate = extensionURL.deletingLastPathComponent().deletingLastPathComponent()
        return candidate.pathExtension == "app" ? candidate : nil
    }

    static func candidateGroups(hostURL: URL?, configured: String?, fallbackIdentifier: String?) -> [String] {
        var groups: [String] = []
        // Bundle identifiers exposed to an SDK can be overridden by compatibility code.
        // The installer's actual on-disk Info.plist is authoritative for the host ID.
        if let hostURL,
           let bytes = try? Data(contentsOf: hostURL.appendingPathComponent("Info.plist")),
           let info = try? PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any] {
            if let identifier = info["CFBundleIdentifier"] as? String { groups.append("group." + identifier) }
            if let explicit = info["LynkWidgetAppGroup"] as? String { groups.append(explicit) }
        }
        if let configured { groups.append(configured) }
        if let fallbackIdentifier { groups.append("group." + fallbackIdentifier) }
        var seen = Set<String>()
        return groups.filter { $0.hasPrefix("group.") && seen.insert($0).inserted }
    }

    static func decode(_ data: Data) -> CarSnapshot? {
        guard data.count <= 4_096,
              let snapshot = try? JSONDecoder().decode(CarSnapshot.self, from: data),
              snapshot.schemaVersion == 1,
              snapshot.statusTime.isFinite,
              (946_684_800_000...4_102_444_800_000).contains(snapshot.statusTime) else { return nil }
        return snapshot
    }

    static func read() -> CarSnapshot? {
        let hostURL = containingAppURL(extensionURL: Bundle.main.bundleURL)
        let groups = candidateGroups(hostURL: hostURL,
            configured: Bundle.main.object(forInfoDictionaryKey: "LynkWidgetAppGroup") as? String,
            fallbackIdentifier: hostURL.flatMap { Bundle(url: $0)?.bundleIdentifier })
        for group in groups {
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
                  let data = try? Data(contentsOf: container.appendingPathComponent("LynkCarWidgetSnapshot.json")),
                  let snapshot = decode(data) else { continue }
            return snapshot
        }
        return nil
    }
}
