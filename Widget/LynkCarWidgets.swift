import Foundation
import SwiftUI
import WidgetKit

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
        Group {
            if family == .systemSmall { smallHome } else { controlHome }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var controlHome: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "car.side.fill").foregroundStyle(accent)
                Text("Lynk & Co").fontWeight(.semibold)
                Spacer(minLength: 4)
                Text(dataTime).font(.system(size: 9)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }.font(.system(size: 11))
            HStack(alignment: .firstTextBaseline) {
                Text(range).font(.system(size: 29, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 5)
                Label(battery, systemImage: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(accent)
            }
            HStack(spacing: 4) {
                Text(value(state?.electricRangeKm, suffix: " км") + " · " + value(state?.fuelLitres, suffix: " л"))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text("Салон " + inside + " · Улица " + outside)
            }.font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                ForEach(WidgetControl.allCases, id: \.rawValue) { control in
                    if let url = control.url(token: state?.actionToken) {
                        Link(destination: url) { controlLabel(control, enabled: true) }
                    } else {
                        controlLabel(control, enabled: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func controlLabel(_ control: WidgetControl, enabled: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: control.symbol).font(.system(size: 17, weight: .medium))
            Text(control.title).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(enabled ? accent : .gray)
        .frame(maxWidth: .infinity).frame(height: 42)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(enabled ? 0.08 : 0.04)))
        .accessibilityLabel(control.title)
    }

    private var smallHome: some View {
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
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
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
            .description("Показания автомобиля и четыре кнопки управления в среднем виджете.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LynkCarWidgets: WidgetBundle {
    var body: some Widget { CarStatusWidget() }
}
