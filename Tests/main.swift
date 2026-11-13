import Foundation

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    count += 1
    if !condition() { fatalError(message) }
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: root) }
let host = root.appendingPathComponent("Example.app", isDirectory: true)
let ext = host.appendingPathComponent("PlugIns/Status.appex", isDirectory: true)
try FileManager.default.createDirectory(at: ext, withIntermediateDirectories: true)
let info: [String: Any] = ["CFBundleIdentifier": "com.example.car.SIGNEDTEAM", "LynkWidgetAppGroup": "group.com.example.shared.SIGNEDTEAM"]
try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0).write(to: host.appendingPathComponent("Info.plist"))
check(CarSnapshot.containingAppURL(extensionURL: ext)?.path == host.path, "Containing app with a directory URL")
check(CarSnapshot.containingAppURL(extensionURL: URL(fileURLWithPath: ext.path))?.path == host.path, "Containing app without trailing slash")
check(CarSnapshot.containingAppURL(extensionURL: root) == nil, "Reject an unrelated parent")
let groups = CarSnapshot.candidateGroups(hostURL: host, configured: "group.com.example.shared.SIGNEDTEAM", fallbackIdentifier: "com.example.legacy")
check(groups == ["group.com.example.car.SIGNEDTEAM", "group.com.example.shared.SIGNEDTEAM", "group.com.example.legacy"], "Signed disk ID must precede the overridden SDK ID, without duplicates")
check(CarSnapshot.candidateGroups(hostURL: nil, configured: "bad", fallbackIdentifier: nil).isEmpty, "Reject invalid configured group")
check(CarSnapshot.candidateGroups(hostURL: root, configured: "group.example", fallbackIdentifier: nil) == ["group.example"], "Missing Info.plist keeps the explicit fallback")
let good = Data(#"{"schemaVersion":1,"statusTime":1700000000000,"batteryPercent":0,"totalRangeKm":42,"cabinTemp":21.5,"outsideTemp":-2}"#.utf8)
let decoded = CarSnapshot.decode(good)
check(decoded?.batteryPercent == 0, "Preserve a real zero")
check(decoded?.outsideTemp == -2, "Preserve a negative temperature")
check(decoded?.fuelLitres == nil, "Absent field remains absent")
check(decoded?.date.timeIntervalSince1970 == 1700000000, "Use milliseconds without inventing fresh time")
check(CarSnapshot.decode(Data(#"{"schemaVersion":2,"statusTime":1700000000000}"#.utf8)) == nil, "Reject unknown schema")
check(CarSnapshot.decode(Data(#"{"schemaVersion":1,"statusTime":1700000000}"#.utf8)) == nil, "Reject seconds in place of milliseconds")
check(CarSnapshot.decode(Data(#"{"schemaVersion":1,"statusTime":1700000000000,"batteryPercent":"42"}"#.utf8)) == nil, "Reject a malformed host snapshot")
check(CarSnapshot.decode(Data(repeating: 32, count: 4097)) == nil, "Reject oversized input")
print("Snapshot reader: \(count) checks passed")
