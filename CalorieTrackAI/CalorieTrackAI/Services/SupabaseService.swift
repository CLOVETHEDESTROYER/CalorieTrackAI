import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient
    @Published var currentUser: Supabase.User?
    @Published var isAuthenticated = false
    @Published var isGuestMode = true
    @Published var isPasswordRecovery = false
    private var pendingProfile: UserProfile? = nil
    static let authRedirectURL = URL(string: "myfatnesstracker://auth-callback")!

    private init() {
        // Load configuration from Info.plist (which reads from Config.xcconfig)
        let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        let supabaseKey = [publishableKey, anonKey]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { key in
                !key.isEmpty &&
                key != "your-supabase-publishable-key-here" &&
                key != "your-supabase-anon-key-here" &&
                key != "$(SUPABASE_PUBLISHABLE_KEY)" &&
                key != "$(SUPABASE_ANON_KEY)"
            }

        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey,
              !supabaseURL.isEmpty && !supabaseKey.isEmpty,
              supabaseURL != "your-supabase-url-here" && supabaseURL != "$(SUPABASE_URL)",
              let url = URL(string: supabaseURL) else {
            #if DEBUG
            print("""
            ⚠️ Supabase configuration missing!

            Please set up your Supabase credentials:
            1. Copy Config.xcconfig.template to Config.xcconfig
            2. Add your Supabase URL and publishable key to Config.xcconfig
            3. Get your credentials from: https://supabase.com/dashboard

            Current values:
            - SUPABASE_URL: \(Self.maskedConfigValue(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String))
            - SUPABASE_PUBLISHABLE_KEY: \(Self.maskedConfigValue(publishableKey))
            - SUPABASE_ANON_KEY: \(Self.maskedConfigValue(anonKey))
            """)
            #endif

            self.client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder"
            )
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestMode = true
            return
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(redirectToURL: Self.authRedirectURL)
            )
        )

        // Check if user is already authenticated
        self.currentUser = client.auth.currentUser
        self.isAuthenticated = currentUser != nil
        self.isGuestMode = !self.isAuthenticated

        // Listen for auth state changes
        Task {
            for await state in client.auth.authStateChanges {
                await MainActor.run {
                    self.currentUser = state.session?.user
                    self.isAuthenticated = state.session != nil
                    self.isGuestMode = !self.isAuthenticated
                    if state.event == .passwordRecovery {
                        self.isPasswordRecovery = true
                    }
                    // If just authenticated and pendingProfile exists, create it with retry
                    if self.isAuthenticated, let profile = self.pendingProfile {
                        Task {
                            await self.retryCreateUserProfile(profile)
                            self.pendingProfile = nil
                        }
                    }
                }
            }
        }
    }

    private static func maskedConfigValue(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return "missing"
        }

        let placeholderValues = [
            "your-supabase-url-here",
            "your-supabase-publishable-key-here",
            "your-supabase-anon-key-here",
            "$(SUPABASE_URL)",
            "$(SUPABASE_PUBLISHABLE_KEY)",
            "$(SUPABASE_ANON_KEY)"
        ]

        if placeholderValues.contains(value) {
            return "placeholder"
        }

        return "configured"
    }

    // MARK: - Authentication

    func signUp(email: String, password: String, name: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        // Create user profile using RPC function to bypass RLS
        let profile = UserProfile(
            user_id: response.user.id,
            name: name,
            age: 25,
            weight: 70.0,
            height: 170.0,
            activity_level: "sedentary",
            goal_type: "maintain weight",
            daily_calorie_goal: 2000
        )

        do {
            try await createInitialUserProfile(profile)
        } catch {
            pendingProfile = profile
            #if DEBUG
            print("Profile creation deferred until the user session is active: \(error)")
            #endif
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String, name: String?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        currentUser = session.user
        isAuthenticated = true
        isGuestMode = false
        try await ensureProfileForCurrentUser(name: name)
    }

    func signOut() async throws {
        await RemoteNotificationService.shared.unregisterCurrentUser()
        try await client.auth.signOut()
        isPasswordRecovery = false
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: Self.authRedirectURL)
    }

    func handleIncomingURL(_ url: URL) {
        client.handle(url)
    }

    func updatePassword(_ password: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: password))
        isPasswordRecovery = false
    }

    func cancelPasswordRecovery() async {
        isPasswordRecovery = false
        try? await client.auth.signOut()
    }

    // MARK: - User Profile Operations

    func saveUserProfile(_ profile: UserProfile) async throws {
        try await client
            .from("user_profiles")
            .upsert(profile)
            .execute()
    }

    // Function to create initial user profile bypassing RLS
    private func createInitialUserProfile(_ profile: UserProfile) async throws {
        try await client
            .rpc("create_user_profile", params: [
                "p_user_id": profile.user_id.uuidString,
                "p_name": profile.name,
                "p_age": String(profile.age),
                "p_weight": String(profile.weight),
                "p_height": String(profile.height),
                "p_activity_level": profile.activity_level,
                "p_goal_type": profile.goal_type,
                "p_daily_calorie_goal": String(profile.daily_calorie_goal)
            ])
            .execute()
    }

    private func ensureProfileForCurrentUser(name: String?) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        if let _ = try? await getUserProfile() {
            return
        }

        let fallbackName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = UserProfile(
            user_id: userId,
            name: fallbackName?.isEmpty == false ? fallbackName! : "Apple User",
            age: 25,
            weight: 70.0,
            height: 170.0,
            activity_level: "sedentary",
            goal_type: "maintain weight",
            daily_calorie_goal: 2000
        )

        do {
            try await createInitialUserProfile(profile)
        } catch {
            pendingProfile = profile
            #if DEBUG
            print("Apple profile creation deferred: \(error)")
            #endif
        }
    }

    private func retryCreateUserProfile(_ profile: UserProfile, maxAttempts: Int = 3, delaySeconds: UInt64 = 1) async {
        for attempt in 1...maxAttempts {
            do {
                try await createInitialUserProfile(profile)
                #if DEBUG
                print("✅ User profile created successfully (attempt \(attempt))")
                #endif
                return
            } catch {
                let errorString = String(describing: error)
                #if DEBUG
                print("❌ Attempt \(attempt) to create user profile failed: \(error)")
                #endif
                // Check for foreign key error code (23503) or message
                if errorString.contains("violates foreign key constraint") || errorString.contains("23503") {
                    if attempt < maxAttempts {
                        try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                        continue
                    }
                }
                // For other errors or after max attempts, break and log
                #if DEBUG
                print("❌ Failed to create user profile after \(attempt) attempts: \(error)")
                #endif
                break
            }
        }
    }


    func getUserProfile() async throws -> UserProfile? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    // MARK: - Meal Entry Operations

    func saveMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        var mealEntry = entry
        mealEntry.user_id = userId

        let response: [MealEntry] = try await client
            .from("meal_entries")
            .insert(mealEntry)
            .select()
            .execute()
            .value

        guard let savedEntry = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedEntry
    }

    func getMealEntriesForDate(_ date: Date) async throws -> [MealEntry] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let response: [MealEntry] = try await client
            .from("meal_entries")
            .select()
            .eq("user_id", value: userId)
            .gte("consumed_at", value: startOfDay.toISOString())
            .lt("consumed_at", value: endOfDay.toISOString())
            .order("consumed_at")
            .execute()
            .value

        return response
    }

    func getMealEntriesForDateRange(from startDate: Date, to endDate: Date) async throws -> [MealEntry] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [MealEntry] = try await client
            .from("meal_entries")
            .select()
            .eq("user_id", value: userId)
            .gte("consumed_at", value: startDate.toISOString())
            .lte("consumed_at", value: endDate.toISOString())
            .order("consumed_at")
            .execute()
            .value

        return response
    }

    func updateMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [MealEntry] = try await client
            .from("meal_entries")
            .update(entry)
            .eq("id", value: entry.id)
            .eq("user_id", value: userId)
            .select()
            .execute()
            .value

        guard let updatedEntry = response.first else {
            throw SupabaseError.updateFailed
        }

        return updatedEntry
    }

    func deleteMealEntry(_ entryId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("meal_entries")
            .delete()
            .eq("id", value: entryId)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteAllMealEntriesForCurrentUser() async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("meal_entries")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteAllUserGeneratedDataForCurrentUser() async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("peptide_logs")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("movement_challenge_sessions")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("gym_visits")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("gym_locations")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("activity_daily_summaries")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("fitness_plans")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("coach_user_settings")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("meal_entries")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("user_profiles")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Peptide Log Operations

    func savePeptideLog(_ log: PeptideLog) async throws -> PeptideLog {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = PeptideLogRecord(log: log, userId: userId)
        let response: [PeptideLogRecord] = try await client
            .from("peptide_logs")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toLog()
    }

    func getPeptideLogs() async throws -> [PeptideLog] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [PeptideLogRecord] = try await client
            .from("peptide_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: false)
            .execute()
            .value

        return response.map { $0.toLog() }
    }

    func deletePeptideLog(_ logId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("peptide_logs")
            .delete()
            .eq("id", value: logId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Fitness Plan Operations

    func saveFitnessPlan(_ plan: FitnessPlan) async throws -> FitnessPlan {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = FitnessPlanRecord(plan: plan, userId: userId)
        let response: [FitnessPlanRecord] = try await client
            .from("fitness_plans")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toPlan()
    }

    func getActiveFitnessPlan() async throws -> FitnessPlan? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [FitnessPlanRecord] = try await client
            .from("fitness_plans")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return response.first?.toPlan()
    }

    // MARK: - Activity Operations

    func saveActivitySummary(_ summary: ActivityDailySummary) async throws -> ActivityDailySummary {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = ActivityDailySummaryRecord(summary: summary, userId: userId)
        let response: [ActivityDailySummaryRecord] = try await client
            .from("activity_daily_summaries")
            .upsert(record, onConflict: "user_id,activity_date")
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toSummary(gymVisits: summary.gymVisits)
    }

    func getActivitySummary(for date: Date, gymVisits: [GymVisit] = []) async throws -> ActivityDailySummary? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [ActivityDailySummaryRecord] = try await client
            .from("activity_daily_summaries")
            .select()
            .eq("user_id", value: userId)
            .eq("activity_date", value: ActivityDateFormatter.string(from: date))
            .limit(1)
            .execute()
            .value

        return response.first?.toSummary(gymVisits: gymVisits)
    }

    // MARK: - Movement Challenge Operations

    func saveMovementChallengeSession(_ session: MovementChallengeSession) async throws -> MovementChallengeSession {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = MovementChallengeSessionRecord(session: session, userId: userId)
        let response: [MovementChallengeSessionRecord] = try await client
            .from("movement_challenge_sessions")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toSession()
    }

    func getMovementChallengeSessions(since startDate: Date? = nil) async throws -> [MovementChallengeSession] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        var query = client
            .from("movement_challenge_sessions")
            .select()
            .eq("user_id", value: userId)

        if let startDate {
            query = query.gte("started_at", value: startDate.toISOString())
        }

        let response: [MovementChallengeSessionRecord] = try await query
            .order("started_at", ascending: false)
            .execute()
            .value

        return response.map { $0.toSession() }
    }

    // MARK: - Social Fitness Operations

    func ensureSocialProfile() async throws -> SocialProfile {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        if let existing = try await getSocialProfile() {
            return existing
        }

        let userProfile = try? await getUserProfile()
        let authName = currentUser?.userMetadata["full_name"]?.stringValue
            ?? currentUser?.userMetadata["name"]?.stringValue
        let displayName = userProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = authName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = [displayName, fallbackName]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "Athlete"

        let response: [SocialProfile] = try await client
            .from("social_profiles")
            .insert(SocialProfileInsert(user_id: userId, display_name: String(resolvedName.prefix(40))))
            .select()
            .execute()
            .value

        guard let profile = response.first else {
            throw SupabaseError.saveFailed
        }
        return profile
    }

    func getSocialProfile() async throws -> SocialProfile? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [SocialProfile] = try await client
            .from("social_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func searchSocialProfile(friendCode: String) async throws -> SocialProfile? {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let response: [SocialProfile] = try await client
            .rpc(
                "search_social_profile_by_friend_code",
                params: ["p_friend_code": friendCode.uppercased()]
            )
            .execute()
            .value

        return response.first
    }

    func getFriendships() async throws -> [Friendship] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        async let requested: [Friendship] = client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .execute()
            .value
        async let received: [Friendship] = client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .execute()
            .value

        let records = try await requested + received
        return Array(Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }).values)
            .sorted { $0.created_at > $1.created_at }
    }

    func getVisibleSocialProfiles(userIds: [UUID]) async throws -> [SocialProfile] {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }
        guard !userIds.isEmpty else { return [] }

        return try await client
            .from("social_profiles")
            .select()
            .in("user_id", values: userIds)
            .execute()
            .value
    }

    func sendFriendRequest(to addresseeId: UUID) async throws -> Friendship {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [Friendship] = try await client
            .from("friendships")
            .insert(FriendshipInsert(requester_id: userId, addressee_id: addresseeId))
            .select()
            .execute()
            .value

        guard let friendship = response.first else {
            throw SupabaseError.saveFailed
        }
        return friendship
    }

    func answerFriendRequest(_ friendshipId: UUID, status: FriendshipStatus) async throws -> Friendship {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let response: [Friendship] = try await client
            .from("friendships")
            .update(FriendshipStatusUpdate(status: status))
            .eq("id", value: friendshipId)
            .select()
            .execute()
            .value

        guard let friendship = response.first else {
            throw SupabaseError.updateFailed
        }
        return friendship
    }

    func removeFriendship(_ friendshipId: UUID) async throws {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId)
            .execute()
    }

    func getFitnessChallenges() async throws -> [FitnessChallenge] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        async let sent: [FitnessChallenge] = client
            .from("fitness_challenges")
            .select()
            .eq("challenger_id", value: userId)
            .execute()
            .value
        async let received: [FitnessChallenge] = client
            .from("fitness_challenges")
            .select()
            .eq("challenged_id", value: userId)
            .execute()
            .value

        let records = try await sent + received
        return Array(Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }).values)
            .sorted { $0.created_at > $1.created_at }
    }

    func sendFitnessChallenge(session: MovementChallengeSession, to friendId: UUID) async throws -> FitnessChallenge {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let insert = FitnessChallengeInsert(
            challenger_id: userId,
            challenged_id: friendId,
            challenge_type: session.challengeType,
            challenger_session_id: session.id
        )
        let response: [FitnessChallenge] = try await client
            .from("fitness_challenges")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let challenge = response.first else {
            throw SupabaseError.saveFailed
        }
        return challenge
    }

    func createSharedChallengeInvite(session: MovementChallengeSession) async throws -> SharedChallengeInvite {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let insert = SharedChallengeInviteInsert(
            inviter_id: userId,
            challenger_session_id: session.id,
            challenge_type: session.challengeType
        )
        let response: [SharedChallengeInvite] = try await client
            .from("shared_challenge_invites")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let invite = response.first else {
            throw SupabaseError.saveFailed
        }
        return invite
    }

    func redeemSharedChallengeInvite(code: String) async throws -> FitnessChallenge {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let response: [FitnessChallenge] = try await client
            .rpc(
                "redeem_shared_fitness_challenge",
                params: ["p_invite_code": code.uppercased()]
            )
            .execute()
            .value

        guard let challenge = response.first else {
            throw SupabaseError.saveFailed
        }
        return challenge
    }

    func submitFitnessChallengeResponse(
        challengeId: UUID,
        sessionId: UUID
    ) async throws -> FitnessChallenge {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let response: [FitnessChallenge] = try await client
            .from("fitness_challenges")
            .update(FitnessChallengeResponseUpdate(challenged_session_id: sessionId))
            .eq("id", value: challengeId)
            .select()
            .execute()
            .value

        guard let challenge = response.first else {
            throw SupabaseError.updateFailed
        }
        return challenge
    }

    func declineFitnessChallenge(_ challengeId: UUID) async throws -> FitnessChallenge {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let response: [FitnessChallenge] = try await client
            .from("fitness_challenges")
            .update(FitnessChallengeStatusUpdate(status: .declined))
            .eq("id", value: challengeId)
            .select()
            .execute()
            .value

        guard let challenge = response.first else {
            throw SupabaseError.updateFailed
        }
        return challenge
    }

    func registerPushDevice(deviceToken: String, environment: String, bundleId: String) async throws {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }
        try await client
            .rpc(
                "register_push_device",
                params: PushDeviceRegistration(
                    p_device_token: deviceToken,
                    p_environment: environment,
                    p_bundle_id: bundleId
                )
            )
            .execute()
    }

    func unregisterPushDevice(deviceToken: String) async throws {
        guard currentUser?.id != nil else { return }
        try await client
            .rpc("unregister_push_device", params: PushDeviceUnregistration(p_device_token: deviceToken))
            .execute()
    }

    func sendSocialPush(event: SocialPushEvent, recordId: UUID) async throws -> SocialPushResponse {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }
        return try await client.functions.invoke(
            "social-push",
            options: FunctionInvokeOptions(
                body: SocialPushRequest(event_type: event, record_id: recordId)
            )
        )
    }

    // MARK: - Gym Operations

    func saveGymLocation(_ location: GymLocation) async throws -> GymLocation {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = GymLocationRecord(location: location, userId: userId)
        let response: [GymLocationRecord] = try await client
            .from("gym_locations")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toLocation()
    }

    func getGymLocations() async throws -> [GymLocation] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let response: [GymLocationRecord] = try await client
            .from("gym_locations")
            .select()
            .eq("user_id", value: userId)
            .order("name")
            .execute()
            .value

        return response.map { $0.toLocation() }
    }

    func deleteGymLocation(_ locationId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        try await client
            .from("gym_locations")
            .delete()
            .eq("id", value: locationId)
            .eq("user_id", value: userId)
            .execute()
    }

    func saveGymVisit(_ visit: GymVisit) async throws -> GymVisit {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let record = GymVisitRecord(visit: visit, userId: userId)
        let response: [GymVisitRecord] = try await client
            .from("gym_visits")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toVisit()
    }

    func getGymVisits(since startDate: Date? = nil) async throws -> [GymVisit] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        var query = client
            .from("gym_visits")
            .select()
            .eq("user_id", value: userId)

        if let startDate {
            query = query.gte("arrived_at", value: startDate.toISOString())
        }

        let response: [GymVisitRecord] = try await query
            .order("arrived_at", ascending: false)
            .execute()
            .value

        return response.map { $0.toVisit() }
    }

    // MARK: - Coach Settings Operations

    func saveCoachNotificationSettings(_ settings: CoachNotificationSettings) async throws -> CoachNotificationSettings {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let existingRecord = try await getCoachUserSettingsRecord(userId: userId)
        let toneSettings = existingRecord?.toToneSettings() ?? .defaultFullRoast
        let record = CoachUserSettingsRecord(
            toneSettings: toneSettings,
            notificationSettings: settings,
            userId: userId
        )
        let response: [CoachUserSettingsRecord] = try await client
            .from("coach_user_settings")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toNotificationSettings()
    }

    func getCoachNotificationSettings() async throws -> CoachNotificationSettings? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        return try await getCoachUserSettingsRecord(userId: userId)?.toNotificationSettings()
    }

    func saveCoachToneSettings(_ settings: CoachToneSettings) async throws -> CoachToneSettings {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let existingRecord = try await getCoachUserSettingsRecord(userId: userId)
        let notificationSettings = existingRecord?.toNotificationSettings() ?? .defaults
        let record = CoachUserSettingsRecord(
            toneSettings: settings,
            notificationSettings: notificationSettings,
            userId: userId
        )
        let response: [CoachUserSettingsRecord] = try await client
            .from("coach_user_settings")
            .upsert(record)
            .select()
            .execute()
            .value

        guard let savedRecord = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedRecord.toToneSettings()
    }

    func getCoachToneSettings() async throws -> CoachToneSettings? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        return try await getCoachUserSettingsRecord(userId: userId)?.toToneSettings()
    }

    private func getCoachUserSettingsRecord(userId: UUID) async throws -> CoachUserSettingsRecord? {
        let response: [CoachUserSettingsRecord] = try await client
            .from("coach_user_settings")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    // MARK: - Food Database Operations

    func searchFoods(query: String) async throws -> [FoodItem] {
        let response: [FoodItem] = try await client
            .from("food_database")
            .select()
            .textSearch("name", query: query)
            .limit(20)
            .execute()
            .value

        return response
    }

    func getFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        let response: [FoodItem] = try await client
            .from("food_database")
            .select()
            .eq("barcode", value: barcode)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func addCustomFood(_ food: FoodItem) async throws -> FoodItem {
        let response: [FoodItem] = try await client
            .from("food_database")
            .insert(food)
            .select()
            .execute()
            .value

        guard let savedFood = response.first else {
            throw SupabaseError.saveFailed
        }

        return savedFood
    }

    // MARK: - Analytics

    func getNutritionSummary(for days: Int = 7) async throws -> NutritionSummary {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!

        let entries = try await getMealEntriesForDateRange(from: startDate, to: endDate)

        let totalCalories = entries.reduce(0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0) { $0 + $1.protein }
        let totalCarbs = entries.reduce(0) { $0 + $1.carbohydrates }
        let totalFat = entries.reduce(0) { $0 + $1.fat }

        return NutritionSummary(
            totalCalories: totalCalories,
            averageCalories: totalCalories / Double(days),
            totalProtein: totalProtein,
            totalCarbohydrates: totalCarbs,
            totalFat: totalFat,
            entryCount: entries.count,
            period: days
        )
    }

    // MARK: - Real-time Subscriptions

    func subscribeToMealEntries(callback: @escaping ([MealEntry]) -> Void) {
        guard currentUser?.id != nil else { return }

        // Simplified implementation - just call the callback initially
        // Real-time subscriptions can be added later when API is stabilized
        Task {
            do {
                let entries = try await getMealEntriesForDate(Date())
                await MainActor.run {
                    callback(entries)
                }
            } catch {
                #if DEBUG
                print("Error fetching meal entries: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Error Handling

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case saveFailed
    case updateFailed
    case deleteFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .saveFailed:
            return "Failed to save data"
        case .updateFailed:
            return "Failed to update data"
        case .deleteFailed:
            return "Failed to delete data"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Extensions

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
