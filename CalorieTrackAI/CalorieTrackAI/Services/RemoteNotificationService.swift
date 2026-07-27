import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let openSocialCompetition = Notification.Name("openSocialCompetition")
}

enum RemoteNotificationRoute: Equatable {
    case competition

    init?(userInfo: [AnyHashable: Any]) {
        guard userInfo["route"] as? String == "competition" else { return nil }
        self = .competition
    }
}

@MainActor
final class RemoteNotificationService: ObservableObject {
    static let shared = RemoteNotificationService()

    @Published private(set) var deviceToken: String?
    @Published private(set) var registrationError: String?
    @Published private(set) var isRegistered = false

    private let tokenKey = "APNsDeviceToken"
    private let supabase = SupabaseService.shared

    private init() {
        deviceToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    func registerIfAvailable() async {
        guard supabase.isAuthenticated else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
        if let deviceToken {
            await sync(deviceToken: deviceToken)
        }
    }

    func didRegister(deviceToken data: Data) {
        let token = Self.deviceTokenString(data)
        deviceToken = token
        registrationError = nil
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await sync(deviceToken: token) }
    }

    nonisolated static func deviceTokenString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func didFailToRegister(error: Error) {
        isRegistered = false
        registrationError = error.localizedDescription
    }

    func unregisterCurrentUser() async {
        guard let deviceToken, supabase.isAuthenticated else { return }
        try? await supabase.unregisterPushDevice(deviceToken: deviceToken)
        isRegistered = false
    }

    func handle(userInfo: [AnyHashable: Any]) {
        guard RemoteNotificationRoute(userInfo: userInfo) == .competition else { return }
        NotificationCenter.default.post(name: .openSocialCompetition, object: nil)
    }

    private func sync(deviceToken: String) async {
        guard supabase.isAuthenticated else { return }
        do {
            try await supabase.registerPushDevice(
                deviceToken: deviceToken,
                environment: Self.apnsEnvironment,
                bundleId: Bundle.main.bundleIdentifier ?? "com.hyperlabsAI.CalorieTrackAI"
            )
            isRegistered = true
            registrationError = nil
        } catch {
            isRegistered = false
            registrationError = error.localizedDescription
            #if DEBUG
            print("APNs token sync failed: \(error)")
            #endif
        }
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

final class MFTAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            RemoteNotificationService.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            RemoteNotificationService.shared.didFailToRegister(error: error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            RemoteNotificationService.shared.handle(userInfo: response.notification.request.content.userInfo)
        }
    }
}
