import Foundation

@MainActor
final class SocialLinkRouter: ObservableObject {
    static let shared = SocialLinkRouter()

    enum Route: Equatable {
        case friend(code: String)
        case challenge(code: String)
    }

    @Published private(set) var pendingRoute: Route?

    private init() {}

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "myfatnesstracker" else { return false }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?
            .first(where: { $0.name == "code" })?
            .value?
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        switch url.host?.lowercased() {
        case "friend":
            guard let code, code.count == 8 else { return false }
            pendingRoute = .friend(code: code)
        case "challenge":
            guard let code, code.count == 12 else { return false }
            pendingRoute = .challenge(code: code)
        default:
            return false
        }
        return true
    }

    func consume() -> Route? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
