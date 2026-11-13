import Foundation

enum WidgetControl: String, CaseIterable {
    case locks, trunk, heat, flash

    var title: String {
        switch self {
        case .locks: return "Замки"
        case .trunk: return "Багажник"
        case .heat: return "Прогреть"
        case .flash: return "Поморгать"
        }
    }

    var symbol: String {
        switch self {
        case .locks: return "lock.fill"
        case .trunk: return "car.rear.fill"
        case .heat: return "fanblades.fill"
        case .flash: return "lightbulb.fill"
        }
    }

    func url(token: String?) -> URL? {
        guard let token, token.utf8.count == 64,
              token.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        var components = URLComponents()
        components.scheme = "lynkruwidget"
        components.host = "control"
        components.path = "/" + rawValue
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }
}
