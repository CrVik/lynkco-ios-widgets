import Foundation
import SwiftUI
import WidgetKit

struct CarSnapshot: Decodable {
    let schemaVersion: Int
    let statusTime: Double
    let batteryPercent: Double?
    let totalRangeKm: Double?
    let electricRangeKm: Double?
    let fuelLitres: Double?
    let cabinTemp: Double?
    let outsideTemp: Double?

    var date: Date { Date(timeIntervalSince1970: statusTime / 1_000) }

    static func read() -> CarSnapshot? {
        let own = Bundle.main.bundleURL
        let host = Bundle(url: own.deletingLastPathComponent().deletingLastPathComponent())
        var groups: [String] = []
        if let identifier = host?.bundleIdentifier { groups.append("group." + identifier) }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LynkWidgetAppGroup") as? String {
            groups.append(configured)
        }
        for group in Array(Set(groups)).sorted() {
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
                  let data = try? Data(contentsOf: container.appendingPathComponent("LynkCarWidgetSnapshot.json")),
                  data.count <= 4_096,
                  let snapshot = try? JSONDecoder().decode(CarSnapshot.self, from: data),
                  snapshot.schemaVersion == 1,
                  snapshot.statusTime.isFinite, snapshot.statusTime > 0 else { continue }
            return snapshot
        }
        return nil
    }
}

struct CarEntry: TimelineEntry {
    let date: Date
    let snapshot: CarSnapshot?
}

struct CarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarEntry { CarEntry(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (CarEntry) -> Void) {
        completion(CarEntry(date: .now, snapshot: CarSnapshot.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CarEntry>) -> Void) {
        let entry = CarEntry(date: .now, snapshot: CarSnapshot.read())
        // This only rereads the shared snapshot. It sends no requests to a car or server.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1_800))))
    }
}

struct CarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CarEntry
    private let accent = Color(red: 0.0, green: 0.86, blue: 0.69)
    private var state: CarSnapshot? { entry.snapshot }

    private func value(_ number: Double?, suffix: String = "", signed: Bool = false) -> String {
        guard let number, number.isFinite else { return "—" }
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(0...1)).locale(Locale(identifier: "ru_RU"))
        let sign = signed && number > 0 ? "+" : ""
        return sign + number.formatted(style) + suffix
    }

    private var battery: String { value(state?.batteryPercent, suffix: "%") }
    private var range: String { value(state?.totalRangeKm, suffix: " км") }
    private var inside: String { value(state?.cabinTemp, suffix: "°") }
    private var outside: String { value(state?.outsideTemp, suffix: "°", signed: true) }

    private var dataTime: String {
        guard let date = state?.date else { return "Откройте приложение" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Данные " + date.formatted(.dateTime.hour().minute())
        }
        return "Данные " + date.formatted(.dateTime.day().month().hour().minute())
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 9) {
            HStack(spacing: 6) {
                Image(systemName: "car.side.fill").foregroundStyle(accent)
                Text("Lynk & Co").fontWeight(.semibold)
                Spacer(minLength: 0)
            }.font(.caption)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(range).font(.system(size: family == .systemSmall ? 26 : 34, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.65)
                if family != .systemSmall {
                    Spacer(minLength: 0)
                    Label(battery, systemImage: "bolt.fill").font(.title3.bold()).foregroundStyle(accent)
                }
            }
            if family == .systemSmall {
                Label(battery, systemImage: "bolt.fill").font(.caption.weight(.semibold)).foregroundStyle(accent)
            } else {
                HStack(spacing: 12) {
                    Label(value(state?.electricRangeKm, suffix: " км"), systemImage: "bolt.car")
                    Label(value(state?.fuelLitres, suffix: " л"), systemImage: "fuelpump")
                }.font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                temperature("В салоне", inside)
                temperature("На улице", outside)
            }
            Text(dataTime).font(.system(size: 10)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func temperature(_ title: String, _ temperature: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(temperature).font(.system(size: 17, weight: .semibold, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            if let percent = state?.batteryPercent, percent.isFinite, (0...100).contains(percent) {
                Gauge(value: percent, in: 0...100) { Image(systemName: "bolt.fill") }
                    currentValueLabel: { Text(battery).font(.system(size: 11, weight: .semibold)) }
                    .gaugeStyle(.accessoryCircular)
            } else {
                VStack(spacing: 2) { Image(systemName: "car.side"); Text("—") }
            }
        case .accessoryInline:
            Label(battery + " · " + range, systemImage: "car.side")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(battery + " · " + range).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Text("Салон " + inside + " · Улица " + outside).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                Text(dataTime).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
        default:
            home
        }
    }

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 17.0, *) {
                content.containerBackground(for: .widget) {
                    Color(red: 0.065, green: 0.075, blue: 0.08)
                }
            } else {
                content
            }
        }
        .widgetURL(URL(string: "lynkruwidget://open"))
    }
}

struct CarStatusWidget: Widget {
    let kind = "LynkRussianCarStatus"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarProvider()) { entry in CarWidgetView(entry: entry) }
            .configurationDisplayName("Lynk & Co — автомобиль")
            .description("Заряд, запас хода, температуры и время данных автомобиля.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LynkCarWidgets: WidgetBundle {
    var body: some Widget { CarStatusWidget() }
}
