import Foundation

@MainActor
final class SocialChallengeStore: ObservableObject {
    static let shared = SocialChallengeStore()

    @Published private(set) var profile: SocialProfile?
    @Published private(set) var friendships: [Friendship] = []
    @Published private(set) var profilesById: [UUID: SocialProfile] = [:]
    @Published private(set) var challenges: [FitnessChallenge] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var confirmationMessage: String?

    private let supabase = SupabaseService.shared

    private init() {}

    var currentUserId: UUID? {
        supabase.currentUser?.id
    }

    var isAvailable: Bool {
        supabase.isAuthenticated && currentUserId != nil
    }

    var acceptedFriendships: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    var friends: [SocialProfile] {
        guard let currentUserId else { return [] }
        return acceptedFriendships
            .compactMap { profilesById[$0.otherUserId(for: currentUserId)] }
            .sorted { $0.display_name.localizedCaseInsensitiveCompare($1.display_name) == .orderedAscending }
    }

    var incomingFriendRequests: [Friendship] {
        guard let currentUserId else { return [] }
        return friendships.filter { $0.status == .pending && $0.addressee_id == currentUserId }
    }

    var outgoingFriendRequests: [Friendship] {
        guard let currentUserId else { return [] }
        return friendships.filter { $0.status == .pending && $0.requester_id == currentUserId }
    }

    var incomingChallenges: [FitnessChallenge] {
        guard let currentUserId else { return [] }
        return challenges.filter { $0.status == .pending && $0.challenged_id == currentUserId }
    }

    var outgoingChallenges: [FitnessChallenge] {
        guard let currentUserId else { return [] }
        return challenges.filter { $0.status == .pending && $0.challenger_id == currentUserId }
    }

    var completedChallenges: [FitnessChallenge] {
        challenges.filter { $0.status == .completed }
    }

    var standings: [FriendStanding] {
        guard let currentUserId else { return [] }

        return friends.map { friend in
            let matchups = challenges.filter { $0.opponentId(for: currentUserId) == friend.id }
            return FriendStanding(
                friend: friend,
                myWins: matchups.filter { $0.status == .completed && $0.winner_id == currentUserId }.count,
                friendWins: matchups.filter { $0.status == .completed && $0.winner_id == friend.id }.count,
                openChallenges: matchups.filter { $0.status == .pending }.count
            )
        }
    }

    func profile(for userId: UUID) -> SocialProfile? {
        profilesById[userId]
    }

    func friendship(with friendId: UUID) -> Friendship? {
        guard let currentUserId else { return nil }
        return friendships.first { $0.otherUserId(for: currentUserId) == friendId }
    }

    func refresh() async {
        guard isAvailable, let currentUserId else {
            clear()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await supabase.ensureSocialProfile()
            let friendships = try await supabase.getFriendships()
            let relatedIds = Set(friendships.map { $0.otherUserId(for: currentUserId) }).union([currentUserId])
            let visibleProfiles = try await supabase.getVisibleSocialProfiles(userIds: Array(relatedIds))
            let challenges = try await supabase.getFitnessChallenges()

            self.profile = profile
            self.friendships = friendships
            profilesById = Dictionary(uniqueKeysWithValues: visibleProfiles.map { ($0.id, $0) })
            profilesById[profile.id] = profile
            self.challenges = challenges
            errorMessage = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func addFriend(friendCode: String) async {
        guard isAvailable else {
            errorMessage = SocialChallengeError.signInRequired.localizedDescription
            return
        }

        let normalizedCode = friendCode
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard normalizedCode.count == 8 else {
            errorMessage = SocialChallengeError.profileNotFound.localizedDescription
            return
        }

        await perform {
            guard let foundProfile = try await supabase.searchSocialProfile(friendCode: normalizedCode) else {
                throw SocialChallengeError.profileNotFound
            }
            guard friendship(with: foundProfile.id) == nil else {
                throw SocialChallengeError.alreadyConnected
            }

            let friendship = try await supabase.sendFriendRequest(to: foundProfile.id)
            await sendPushBestEffort(event: .friendRequest, recordId: friendship.id)
            confirmationMessage = "Friend request sent to \(foundProfile.display_name)."
            await refresh()
        }
    }

    func answerFriendRequest(_ friendship: Friendship, accept: Bool) async {
        await perform {
            _ = try await supabase.answerFriendRequest(
                friendship.id,
                status: accept ? .accepted : .declined
            )
            confirmationMessage = accept ? "Friend added." : "Friend request declined."
            await refresh()
        }
    }

    func removeFriend(_ friend: SocialProfile) async {
        guard let friendship = friendship(with: friend.id) else { return }
        await perform {
            try await supabase.removeFriendship(friendship.id)
            confirmationMessage = "\(friend.display_name) removed from your friends."
            await refresh()
        }
    }

    func sendChallenge(session: MovementChallengeSession, to friend: SocialProfile) async {
        guard session.competitionScore > 0 else {
            errorMessage = SocialChallengeError.noValidReps.localizedDescription
            return
        }

        await perform {
            await MovementChallengeStore.shared.saveSession(session)
            let challenge = try await supabase.sendFitnessChallenge(session: session, to: friend.id)
            await sendPushBestEffort(event: .fitnessChallenge, recordId: challenge.id)
            confirmationMessage = session.challengeType.isTimedHold
                ? "\(friend.display_name) needs a \(session.competitionTargetDisplay) plank hold to beat you."
                : "\(friend.display_name) needs \(session.competitionTargetDisplay) \(session.challengeType.shortTitle.lowercased()) to beat you."
            await refresh()
        }
    }

    func createSharedChallengeInvite(session: MovementChallengeSession) async -> SharedChallengeInvite? {
        guard isAvailable else {
            errorMessage = SocialChallengeError.signInRequired.localizedDescription
            return nil
        }
        guard session.competitionScore > 0 else {
            errorMessage = SocialChallengeError.noValidReps.localizedDescription
            return nil
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        confirmationMessage = nil

        do {
            await MovementChallengeStore.shared.saveSession(session)
            let invite = try await supabase.createSharedChallengeInvite(session: session)
            confirmationMessage = "Share code \(invite.invite_code) is ready for seven days."
            return invite
        } catch {
            errorMessage = friendlyMessage(for: error)
            return nil
        }
    }

    func redeemSharedChallengeInvite(code: String) async -> FitnessChallenge? {
        guard isAvailable else {
            errorMessage = SocialChallengeError.signInRequired.localizedDescription
            return nil
        }

        let normalizedCode = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard normalizedCode.count == 12 else {
            errorMessage = SocialChallengeError.invalidInviteCode.localizedDescription
            return nil
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        confirmationMessage = nil

        do {
            let challenge = try await supabase.redeemSharedChallengeInvite(code: normalizedCode)
            confirmationMessage = challenge.isTimedHold
                ? "Challenge accepted. Camera up, then hold longer than \(challenge.challengerScoreDisplay)."
                : "Challenge accepted. Camera up, then beat \(challenge.challengerScoreDisplay)."
            await refresh()
            return challenge
        } catch {
            errorMessage = friendlyMessage(for: error)
            return nil
        }
    }

    func submitResponse(to challenge: FitnessChallenge, session: MovementChallengeSession) async {
        guard challenge.status == .pending,
              challenge.challenge_type == session.challengeType else {
            errorMessage = SocialChallengeError.invalidChallenge.localizedDescription
            return
        }

        await perform {
            await MovementChallengeStore.shared.saveSession(session)
            let result = try await supabase.submitFitnessChallengeResponse(
                challengeId: challenge.id,
                sessionId: session.id
            )
            await sendPushBestEffort(event: .challengeCompleted, recordId: result.id)
            confirmationMessage = result.winner_id == currentUserId
                ? "You beat the target. Scoreboard updated."
                : result.isTimedHold
                    ? "You needed \(result.targetScoreDisplay). Rematch material."
                    : "You missed it by \(max(result.target_rep_count - session.competitionScore, 0)). Rematch material."
            await refresh()
        }
    }

    func declineChallenge(_ challenge: FitnessChallenge) async {
        await perform {
            _ = try await supabase.declineFitnessChallenge(challenge.id)
            confirmationMessage = "Challenge declined."
            await refresh()
        }
    }

    func clearMessages() {
        errorMessage = nil
        confirmationMessage = nil
    }

    private func sendPushBestEffort(event: SocialPushEvent, recordId: UUID) async {
        do {
            _ = try await supabase.sendSocialPush(event: event, recordId: recordId)
        } catch {
            #if DEBUG
            print("Social push delivery failed without blocking the action: \(error)")
            #endif
        }
    }

    private func clear() {
        profile = nil
        friendships = []
        profilesById = [:]
        challenges = []
        isLoading = false
    }

    private func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        confirmationMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let socialError = error as? SocialChallengeError {
            return socialError.localizedDescription
        }

        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("duplicate") || description.contains("23505") {
            return SocialChallengeError.alreadyConnected.localizedDescription
        }
        return description
    }
}
