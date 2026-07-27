import Foundation

struct AppTestingModeStatus: Equatable {
    var title: String
    var detail: String
    var badge: String
    var isUnlocked: Bool
}

enum AppFeatureFlags {
    static var unlockFeaturesForTesting: Bool {
        boolValue(for: "MFT_UNLOCK_FEATURES_FOR_TESTING", defaultValue: true)
    }

    static func testingModeStatus(
        isGuestMode: Bool,
        unlockFeaturesForTesting: Bool = Self.unlockFeaturesForTesting
    ) -> AppTestingModeStatus {
        if unlockFeaturesForTesting {
            if isGuestMode {
                return AppTestingModeStatus(
                    title: "Testing Mode",
                    detail: "Core tracker tools are unlocked for TestFlight QA while signed out. Sign in only when you want sync across devices.",
                    badge: "Unlocked",
                    isUnlocked: true
                )
            }

            return AppTestingModeStatus(
                title: "Testing Mode",
                detail: "QA unlock is enabled. Signed-in data still syncs to Supabase while you test the full app.",
                badge: "Unlocked",
                isUnlocked: true
            )
        }

        if isGuestMode {
            return AppTestingModeStatus(
                title: "Account Required",
                detail: "Sign up so food, plans, activity, and peptide logs sync across devices.",
                badge: "Locked",
                isUnlocked: false
            )
        }

        return AppTestingModeStatus(
            title: "Signed In",
            detail: "Testing unlock is off. Account-backed features use the normal signed-in flow.",
            badge: "Standard",
            isUnlocked: false
        )
    }

    private static func boolValue(for key: String, defaultValue: Bool) -> Bool {
        if let environmentValue = ProcessInfo.processInfo.environment[key],
           let parsedEnvironmentValue = parseBool(environmentValue) {
            return parsedEnvironmentValue
        }

        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return defaultValue
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let stringValue = value as? String {
            if let parsedBundleValue = parseBool(stringValue) {
                return parsedBundleValue
            }
        }

        return defaultValue
    }

    private static func parseBool(_ value: String) -> Bool? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["1", "true", "yes", "enabled"].contains(normalized) {
            return true
        }
        if ["0", "false", "no", "disabled"].contains(normalized) {
            return false
        }
        return nil
    }
}
