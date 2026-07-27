import Foundation

struct SocialProfile: Codable, Identifiable, Equatable, Sendable {
    var id: UUID { user_id }

    let user_id: UUID
    var display_name: String
    let friend_code: String
    var created_at: Date? = nil
    var updated_at: Date? = nil
}

struct SocialProfileInsert: Encodable, Sendable {
    let user_id: UUID
    let display_name: String
}

enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}

struct Friendship: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let requester_id: UUID
    let addressee_id: UUID
    var status: FriendshipStatus
    let created_at: Date
    var updated_at: Date

    func otherUserId(for currentUserId: UUID) -> UUID {
        requester_id == currentUserId ? addressee_id : requester_id
    }
}

struct FriendshipInsert: Encodable, Sendable {
    let requester_id: UUID
    let addressee_id: UUID
}

struct FriendshipStatusUpdate: Encodable, Sendable {
    let status: FriendshipStatus
}

enum FitnessChallengeStatus: String, Codable, Sendable {
    case pending
    case completed
    case declined
}

struct FitnessChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challenger_id: UUID
    let challenged_id: UUID
    let challenge_type: MovementChallengeType
    let challenger_session_id: UUID
    var challenged_session_id: UUID?
    let challenger_rep_count: Int
    var challenged_rep_count: Int?
    let target_rep_count: Int
    var winner_id: UUID?
    var status: FitnessChallengeStatus
    let created_at: Date
    var updated_at: Date
    var completed_at: Date?

    func opponentId(for currentUserId: UUID) -> UUID {
        challenger_id == currentUserId ? challenged_id : challenger_id
    }

    func resultText(for currentUserId: UUID) -> String {
        guard status == .completed, let winner_id else {
            return status == .declined ? "Declined" : "Waiting"
        }
        return winner_id == currentUserId ? "Win" : "Loss"
    }

    var isTimedHold: Bool { challenge_type.isTimedHold }

    var challengerScoreDisplay: String {
        isTimedHold
            ? MovementChallengeSession.holdDisplay(seconds: Double(challenger_rep_count))
            : "\(challenger_rep_count)"
    }

    var challengedScoreDisplay: String {
        isTimedHold
            ? MovementChallengeSession.holdDisplay(seconds: Double(challenged_rep_count ?? 0))
            : "\(challenged_rep_count ?? 0)"
    }

    var targetScoreDisplay: String {
        isTimedHold
            ? MovementChallengeSession.holdDisplay(seconds: Double(target_rep_count))
            : "\(target_rep_count)"
    }

    var competitionMetricLabel: String {
        isTimedHold ? "hold" : "reps"
    }
}

struct FitnessChallengeInsert: Encodable, Sendable {
    let challenger_id: UUID
    let challenged_id: UUID
    let challenge_type: MovementChallengeType
    let challenger_session_id: UUID
}

struct FitnessChallengeResponseUpdate: Encodable, Sendable {
    let challenged_session_id: UUID
    let status: FitnessChallengeStatus = .completed
}

struct FitnessChallengeStatusUpdate: Encodable, Sendable {
    let status: FitnessChallengeStatus
}

struct SharedChallengeInvite: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let invite_code: String
    let inviter_id: UUID
    let challenger_session_id: UUID
    let challenge_type: MovementChallengeType
    let challenger_rep_count: Int
    let target_rep_count: Int
    let claimed_by: UUID?
    let status: String
    let expires_at: Date
    let created_at: Date
    let claimed_at: Date?

    var isPending: Bool {
        status == "pending" && claimed_by == nil && expires_at > Date()
    }

    var isTimedHold: Bool { challenge_type.isTimedHold }

    var challengerScoreDisplay: String {
        isTimedHold
            ? MovementChallengeSession.holdDisplay(seconds: Double(challenger_rep_count))
            : "\(challenger_rep_count)"
    }

    var targetScoreDisplay: String {
        isTimedHold
            ? MovementChallengeSession.holdDisplay(seconds: Double(target_rep_count))
            : "\(target_rep_count)"
    }
}

struct SharedChallengeInviteInsert: Encodable, Sendable {
    let inviter_id: UUID
    let challenger_session_id: UUID
    let challenge_type: MovementChallengeType
}

enum SocialPushEvent: String, Encodable, Sendable {
    case friendRequest = "friend_request"
    case fitnessChallenge = "fitness_challenge"
    case challengeCompleted = "challenge_completed"
}

struct SocialPushRequest: Encodable, Sendable {
    let event_type: SocialPushEvent
    let record_id: UUID
}

struct SocialPushResponse: Decodable, Sendable {
    let delivered: Int
    let configured: Bool
}

struct PushDeviceRegistration: Encodable, Sendable {
    let p_device_token: String
    let p_environment: String
    let p_bundle_id: String
}

struct PushDeviceUnregistration: Encodable, Sendable {
    let p_device_token: String
}

struct FriendStanding: Identifiable, Equatable {
    var id: UUID { friend.id }

    let friend: SocialProfile
    let myWins: Int
    let friendWins: Int
    let openChallenges: Int

    var leadText: String {
        if myWins == friendWins {
            return "Tied \(myWins)-\(friendWins)"
        }
        return myWins > friendWins
            ? "You lead \(myWins)-\(friendWins)"
            : "\(friend.display_name) leads \(friendWins)-\(myWins)"
    }
}

enum SocialChallengeError: LocalizedError, Equatable {
    case signInRequired
    case profileNotFound
    case alreadyConnected
    case noValidReps
    case invalidChallenge
    case invalidInviteCode

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            return "Sign in to add friends and send verified challenges."
        case .profileNotFound:
            return "No athlete matched that friend code. Check all eight characters."
        case .alreadyConnected:
            return "You already have a friend request or connection with this athlete."
        case .noValidReps:
            return "Finish a verified set or hold before sending a challenge."
        case .invalidChallenge:
            return "That challenge can no longer be answered. Refresh and try again."
        case .invalidInviteCode:
            return "Enter the 12-character challenge code from the invitation."
        }
    }
}
