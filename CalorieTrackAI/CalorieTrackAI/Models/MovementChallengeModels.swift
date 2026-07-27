import CoreGraphics
import Foundation

enum MovementChallengeType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pushUp = "push_up"
    case squat
    case jumpingJack = "jumping_jack"
    case plank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushUp:
            return "Push-Up Test"
        case .squat:
            return "Squat Test"
        case .jumpingJack:
            return "Jumping Jacks"
        case .plank:
            return "Plank Hold"
        }
    }

    var shortTitle: String {
        switch self {
        case .pushUp: return "Push-Ups"
        case .squat: return "Squats"
        case .jumpingJack: return "Jumping Jacks"
        case .plank: return "Plank"
        }
    }

    var icon: String {
        switch self {
        case .pushUp: return "figure.strengthtraining.traditional"
        case .squat: return "figure.strengthtraining.functional"
        case .jumpingJack: return "figure.highintensity.intervaltraining"
        case .plank: return "figure.core.training"
        }
    }

    var isTimedHold: Bool {
        self == .plank
    }

    var cameraInstruction: String {
        switch self {
        case .pushUp:
            return "Set the phone upright on the floor, face it, and keep both hands and shoulders visible."
        case .squat, .jumpingJack:
            return "Face the camera and step back until your whole body is visible."
        case .plank:
            return "Set the phone upright on the floor, face it, and hold a straight forearm plank."
        }
    }

    var positioningDistance: String {
        switch self {
        case .pushUp:
            return "6-8 FT"
        case .squat:
            return "8-10 FT"
        case .jumpingJack:
            return "10-12 FT"
        case .plank:
            return "6-8 FT"
        }
    }

    var positioningInstruction: String {
        switch self {
        case .pushUp:
            return "Set the phone upright on the floor. Face the camera and keep your head, shoulders, hips, and both hands inside the frame."
        case .squat:
            return "Set the phone upright near floor level. Face it squarely and keep your head, hips, knees, and feet inside the frame."
        case .jumpingJack:
            return "Set the phone upright near floor level. Leave room above your head and keep your raised hands and wide feet inside the frame."
        case .plank:
            return "Set the phone upright on the floor and face it. Rest on both forearms, then keep your head, shoulders, elbows, and hands visible."
        }
    }
}

struct MovementChallengeSession: Identifiable, Codable, Equatable {
    static let pushUpPoints = 10
    static let analysisVersion = "pushup-front-v3"

    let id: UUID
    var challengeType: MovementChallengeType
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var validRepCount: Int
    var rejectedRepCount: Int
    var pointsAwarded: Int
    var analysisVersion: String

    init(
        id: UUID = UUID(),
        challengeType: MovementChallengeType = .pushUp,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double? = nil,
        validRepCount: Int,
        rejectedRepCount: Int,
        pointsAwarded: Int? = nil,
        analysisVersion: String? = nil
    ) {
        self.id = id
        self.challengeType = challengeType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(durationSeconds ?? endedAt.timeIntervalSince(startedAt), 0)
        self.validRepCount = max(validRepCount, 0)
        self.rejectedRepCount = max(rejectedRepCount, 0)
        self.pointsAwarded = pointsAwarded ?? Self.points(
            for: challengeType,
            validRepCount: validRepCount,
            durationSeconds: self.durationSeconds
        )
        self.analysisVersion = analysisVersion ?? Self.analysisVersion(for: challengeType)
    }

    static func points(
        for challengeType: MovementChallengeType,
        validRepCount: Int,
        durationSeconds: Double = 0
    ) -> Int {
        switch challengeType {
        case .pushUp, .squat, .jumpingJack:
            return max(validRepCount, 0) * pushUpPoints
        case .plank:
            return max(Int(durationSeconds.rounded(.down)), 0)
        }
    }

    static func analysisVersion(for challengeType: MovementChallengeType) -> String {
        switch challengeType {
        case .pushUp: return analysisVersion
        case .squat: return "squat-front-v1"
        case .jumpingJack: return "jumping-jack-front-v1"
        case .plank: return "plank-forearm-front-v3"
        }
    }

    static func holdDisplay(seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    /// The comparable score is reps for movement tests and verified whole seconds for holds.
    var competitionScore: Int {
        challengeType.isTimedHold
            ? max(Int(durationSeconds.rounded(.down)), 0)
            : validRepCount
    }

    var competitionScoreDisplay: String {
        challengeType.isTimedHold
            ? Self.holdDisplay(seconds: durationSeconds)
            : "\(competitionScore)"
    }

    var competitionMetricLabel: String {
        challengeType.isTimedHold ? "hold" : "reps"
    }

    var competitionTargetScore: Int {
        competitionScore + 1
    }

    var competitionTargetDisplay: String {
        challengeType.isTimedHold
            ? Self.holdDisplay(seconds: Double(competitionTargetScore))
            : "\(competitionTargetScore)"
    }
}

struct MovementChallengeDailyRollup: Equatable {
    var sessionCount: Int
    var validRepCount: Int
    var rejectedRepCount: Int
    var pointsAwarded: Int
    var durationSeconds: Double

    static var empty: MovementChallengeDailyRollup {
        MovementChallengeDailyRollup(
            sessionCount: 0,
            validRepCount: 0,
            rejectedRepCount: 0,
            pointsAwarded: 0,
            durationSeconds: 0
        )
    }

    var durationMinutes: Double {
        durationSeconds / 60
    }
}

struct MovementChallengeSessionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var challenge_type: String
    var started_at: Date
    var ended_at: Date
    var duration_seconds: Double
    var valid_rep_count: Int
    var rejected_rep_count: Int
    var points_awarded: Int
    var analysis_version: String
    var created_at: Date?
    var updated_at: Date?

    init(session: MovementChallengeSession, userId: UUID? = nil) {
        id = session.id
        user_id = userId
        challenge_type = session.challengeType.rawValue
        started_at = session.startedAt
        ended_at = session.endedAt
        duration_seconds = session.durationSeconds
        valid_rep_count = session.validRepCount
        rejected_rep_count = session.rejectedRepCount
        points_awarded = session.pointsAwarded
        analysis_version = session.analysisVersion
        created_at = nil
        updated_at = nil
    }

    func toSession() -> MovementChallengeSession {
        MovementChallengeSession(
            id: id,
            challengeType: MovementChallengeType(rawValue: challenge_type) ?? .pushUp,
            startedAt: started_at,
            endedAt: ended_at,
            durationSeconds: duration_seconds,
            validRepCount: valid_rep_count,
            rejectedRepCount: rejected_rep_count,
            pointsAwarded: points_awarded,
            analysisVersion: analysis_version
        )
    }
}

struct PoseLandmark: Equatable {
    static let analysisConfidenceThreshold = 0.20
    static let displayConfidenceThreshold = 0.12

    var point: CGPoint
    var confidence: Double

    static let missing = PoseLandmark(point: .zero, confidence: 0)

    var isReliable: Bool {
        confidence >= Self.analysisConfidenceThreshold
    }

    var isVisible: Bool {
        confidence >= Self.displayConfidenceThreshold
    }
}

/// Vision returns portrait-normalized points after the EXIF orientation is applied.
/// The camera preview uses aspect fill, so overlay points need the same crop without
/// being rotated a second time by AVCaptureVideoPreviewLayer.
struct PortraitPoseOverlayMapper: Equatable {
    var imageSize: CGSize
    var bounds: CGRect

    func map(_ point: CGPoint) -> CGPoint {
        let rect = aspectFillRect
        return CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    func mapHorizontalDistance(_ distance: CGFloat) -> CGFloat {
        distance * aspectFillRect.width
    }

    private var aspectFillRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

struct PushUpPoseSample: Equatable {
    var timestamp: Date
    var leftShoulder: PoseLandmark
    var rightShoulder: PoseLandmark
    var leftElbow: PoseLandmark
    var rightElbow: PoseLandmark
    var leftWrist: PoseLandmark
    var rightWrist: PoseLandmark
    var leftHip: PoseLandmark
    var rightHip: PoseLandmark
    var leftKnee: PoseLandmark
    var rightKnee: PoseLandmark
    var leftAnkle: PoseLandmark
    var rightAnkle: PoseLandmark
    /// Vision's body-pose request exposes a nose point even when it cannot identify
    /// the full face. It gives the camera overlay a real head anchor instead of a guess.
    var face: PoseLandmark = .missing

    var allLandmarks: [PoseLandmark] {
        [
            face,
            leftShoulder,
            rightShoulder,
            leftElbow,
            rightElbow,
            leftWrist,
            rightWrist,
            leftHip,
            rightHip,
            leftKnee,
            rightKnee,
            leftAnkle,
            rightAnkle
        ]
    }

    var upperBodyLandmarks: [PoseLandmark] {
        [leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist]
    }

    var lowerBodyLandmarks: [PoseLandmark] {
        [leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle]
    }

    var hasReliableUpperBody: Bool {
        let leftArmIsReliable = [leftShoulder, leftElbow, leftWrist].allSatisfy(\.isReliable)
        let rightArmIsReliable = [rightShoulder, rightElbow, rightWrist].allSatisfy(\.isReliable)
        return leftShoulder.isReliable && rightShoulder.isReliable && (leftArmIsReliable || rightArmIsReliable)
    }

    var hasReliableFullBody: Bool {
        allLandmarks.allSatisfy(\.isReliable)
    }

    var hasReliableLowerBody: Bool {
        lowerBodyLandmarks.allSatisfy(\.isReliable)
    }

    /// Squats can use hip travel when Vision briefly loses the ankles near the frame edge.
    var hasReliableSquatBody: Bool {
        [leftShoulder, rightShoulder, leftHip, rightHip, leftKnee, rightKnee].allSatisfy(\.isReliable)
    }

    /// Jumping jacks need both hands and the torso/leg centers. Elbows and ankles can
    /// disappear during fast motion, so knee spread is used as the lower-body fallback.
    var hasReliableJumpingJackBody: Bool {
        [
            leftShoulder, rightShoulder,
            leftWrist, rightWrist,
            leftHip, rightHip,
            leftKnee, rightKnee
        ].allSatisfy(\.isReliable)
    }

    var hasReliablePlankBody: Bool {
        [
            leftShoulder, rightShoulder,
            leftElbow, rightElbow,
            leftWrist, rightWrist,
            leftHip, rightHip,
            leftKnee, rightKnee
        ].allSatisfy(\.isReliable)
    }

    /// A floor-level front camera often cannot see hips and knees because the torso
    /// occludes them. Stable shoulders, elbows, and one complete arm are enough to
    /// establish a supported head-on plank when lower-body landmarks disappear.
    var hasReliablePlankSupportBody: Bool {
        let shouldersAndElbows = [
            leftShoulder, rightShoulder,
            leftElbow, rightElbow
        ].allSatisfy(\.isReliable)
        return shouldersAndElbows && (leftWrist.isReliable || rightWrist.isReliable)
    }

    var shoulderCenter: CGPoint {
        CGPoint.midpoint(leftShoulder.point, rightShoulder.point)
    }

    var hipCenter: CGPoint {
        CGPoint.midpoint(leftHip.point, rightHip.point)
    }

    var kneeCenter: CGPoint {
        CGPoint.midpoint(leftKnee.point, rightKnee.point)
    }

    var ankleCenter: CGPoint {
        CGPoint.midpoint(leftAnkle.point, rightAnkle.point)
    }

    var averageElbowAngleDegrees: Double {
        let angles = [
            elbowAngle(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist),
            elbowAngle(shoulder: rightShoulder, elbow: rightElbow, wrist: rightWrist)
        ].compactMap { $0 }
        return angles.reduce(0, +) / Double(max(angles.count, 1))
    }

    var averageKneeAngleDegrees: Double {
        reliableKneeAngleDegrees ?? 180
    }

    var reliableKneeAngleDegrees: Double? {
        let angles = [
            kneeAngle(hip: leftHip, knee: leftKnee, ankle: leftAnkle),
            kneeAngle(hip: rightHip, knee: rightKnee, ankle: rightAnkle)
        ].compactMap { $0 }
        guard !angles.isEmpty else { return nil }
        return angles.reduce(0, +) / Double(angles.count)
    }

    var minimumElbowAngleDegrees: Double {
        min(
            Self.angle(shoulder: leftShoulder.point, elbow: leftElbow.point, wrist: leftWrist.point),
            Self.angle(shoulder: rightShoulder.point, elbow: rightElbow.point, wrist: rightWrist.point)
        )
    }

    var maximumElbowAngleDegrees: Double {
        max(
            Self.angle(shoulder: leftShoulder.point, elbow: leftElbow.point, wrist: leftWrist.point),
            Self.angle(shoulder: rightShoulder.point, elbow: rightElbow.point, wrist: rightWrist.point)
        )
    }

    var shoulderWidth: CGFloat {
        hypot(leftShoulder.point.x - rightShoulder.point.x, leftShoulder.point.y - rightShoulder.point.y)
    }

    var wristWidth: CGFloat {
        hypot(leftWrist.point.x - rightWrist.point.x, leftWrist.point.y - rightWrist.point.y)
    }

    var averageArmLength: CGFloat {
        let left = hypot(leftShoulder.point.x - leftWrist.point.x, leftShoulder.point.y - leftWrist.point.y)
        let right = hypot(rightShoulder.point.x - rightWrist.point.x, rightShoulder.point.y - rightWrist.point.y)
        return (left + right) / 2
    }

    var wristToShoulderTravel: CGFloat {
        abs(CGPoint.midpoint(leftWrist.point, rightWrist.point).y - shoulderCenter.y)
    }

    var ankleWidth: CGFloat {
        hypot(leftAnkle.point.x - rightAnkle.point.x, leftAnkle.point.y - rightAnkle.point.y)
    }

    var kneeWidth: CGFloat {
        hypot(leftKnee.point.x - rightKnee.point.x, leftKnee.point.y - rightKnee.point.y)
    }

    var jumpingJackLowerBodyWidth: CGFloat {
        [leftAnkle, rightAnkle].allSatisfy(\.isReliable) ? ankleWidth : kneeWidth
    }

    var appearsUprightFrontFacing: Bool {
        let base = [leftAnkle, rightAnkle].allSatisfy(\.isReliable) ? ankleCenter : kneeCenter
        let bodyHeight = hypot(shoulderCenter.x - base.x, shoulderCenter.y - base.y)
        return shoulderWidth >= 0.1 && bodyHeight >= shoulderWidth * 1.2
    }

    var jumpingJackOpen: Bool {
        guard hasReliableJumpingJackBody else { return false }
        let usesAnkles = [leftAnkle, rightAnkle].allSatisfy(\.isReliable)
        let requiredSpread = usesAnkles ? shoulderWidth * 1.4 : shoulderWidth * 1.15
        return leftWrist.point.y < shoulderCenter.y - 0.03
            && rightWrist.point.y < shoulderCenter.y - 0.03
            && jumpingJackLowerBodyWidth >= max(requiredSpread, usesAnkles ? 0.14 : 0.10)
    }

    var jumpingJackClosed: Bool {
        guard hasReliableJumpingJackBody else { return false }
        return leftWrist.point.y > shoulderCenter.y + 0.03
            && rightWrist.point.y > shoulderCenter.y + 0.03
            && jumpingJackLowerBodyWidth <= shoulderWidth * 1.25
    }

    var jumpingJackIsInMotion: Bool {
        guard hasReliableJumpingJackBody else { return false }
        let wristsAreRising = leftWrist.point.y < shoulderCenter.y + 0.06
            || rightWrist.point.y < shoulderCenter.y + 0.06
        return wristsAreRising || jumpingJackLowerBodyWidth > shoulderWidth * 1.25
    }

    var appearsSupportedOnForearms: Bool {
        guard hasReliablePlankSupportBody else { return false }
        let elbowAngles = reliablePlankElbowAngles
        guard !elbowAngles.isEmpty else { return false }
        let elbowAngle = elbowAngles.reduce(0, +) / Double(elbowAngles.count)
        let elbowsBelowShoulders = leftElbow.point.y > leftShoulder.point.y + 0.05
            && rightElbow.point.y > rightShoulder.point.y + 0.05
        let wristsNearFloor = reliablePlankWristPairs.allSatisfy {
            $0.wrist.point.y >= $0.elbow.point.y - 0.04
        }
        return elbowAngle >= 55
            && elbowAngle <= 145
            && elbowsBelowShoulders
            && wristsNearFloor
    }

    var appearsSupportedOnHands: Bool {
        guard hasReliablePlankSupportBody else { return false }
        let elbowAngles = reliablePlankElbowAngles
        guard !elbowAngles.isEmpty else { return false }
        let armsAreExtended = elbowAngles.allSatisfy { $0 >= 145 }
        let elbowsBelowShoulders = leftElbow.point.y > leftShoulder.point.y + 0.03
            && rightElbow.point.y > rightShoulder.point.y + 0.03
        let handsBelowElbows = reliablePlankWristPairs.allSatisfy {
            $0.wrist.point.y > $0.elbow.point.y + 0.03
        }
        return armsAreExtended && elbowsBelowShoulders && handsBelowElbows
    }

    var hasFrontPlankAlignment: Bool {
        guard hasReliablePlankBody,
              appearsFrontFacing,
              shoulderCenter.y < hipCenter.y,
              hipCenter.y < kneeCenter.y else {
            return false
        }

        let base = [leftAnkle, rightAnkle].allSatisfy(\.isReliable) ? ankleCenter : kneeCenter
        let bodyLength = max(hypot(shoulderCenter.x - base.x, shoulderCenter.y - base.y), 0.001)
        let expectedHipY = shoulderCenter.y + (base.y - shoulderCenter.y) * 0.52
        let centerDrift = abs(hipCenter.x - shoulderCenter.x) / bodyLength
        let hipDeviation = abs(hipCenter.y - expectedHipY) / bodyLength
        return centerDrift <= 0.20 && hipDeviation <= 0.20
    }

    var hasFrontPlankAlignmentForVisibleBody: Bool {
        guard hasReliablePlankSupportBody,
              appearsFrontFacing,
              appearsSupportedOnForearms else {
            return false
        }

        // Preserve full alignment checks whenever Vision can actually see the
        // lower body. Otherwise, rely on the stable frontal support posture.
        return hasReliablePlankBody ? hasFrontPlankAlignment : true
    }

    var plankStabilityCenter: CGPoint {
        if [leftHip, rightHip].allSatisfy(\.isReliable) {
            return hipCenter
        }
        return CGPoint.midpoint(leftElbow.point, rightElbow.point)
    }

    var appearsStandingForSquat: Bool {
        guard hasReliableSquatBody,
              shoulderCenter.y < hipCenter.y,
              hipCenter.y < kneeCenter.y else {
            return false
        }
        return reliableKneeAngleDegrees.map { $0 >= 142 } ?? true
    }

    /// A floor-level, front-facing phone view exposes both arms and has a broad shoulder span.
    /// It intentionally does not require knees or ankles because Vision often loses them in this angle.
    var appearsFrontFacing: Bool {
        guard leftShoulder.isReliable, rightShoulder.isReliable, shoulderWidth >= 0.08 else {
            return false
        }

        let leftArmIsReliable = [leftShoulder, leftElbow, leftWrist].allSatisfy(\.isReliable)
        let rightArmIsReliable = [rightShoulder, rightElbow, rightWrist].allSatisfy(\.isReliable)
        guard leftArmIsReliable || rightArmIsReliable else { return false }

        guard leftArmIsReliable && rightArmIsReliable else {
            return true
        }

        let armLength = max(averageArmLength, 0.001)
        return shoulderWidth / armLength >= 0.32
            && wristWidth >= shoulderWidth * 0.45
            && wristToShoulderTravel >= 0.03
    }

    var appearsSideOn: Bool {
        let shoulderSpread = abs(leftShoulder.point.x - rightShoulder.point.x)
        let hipSpread = abs(leftHip.point.x - rightHip.point.x)
        let bodyLength = hypot(shoulderCenter.x - ankleCenter.x, shoulderCenter.y - ankleCenter.y)
        guard bodyLength > 0.25 else { return false }

        return max(shoulderSpread, hipSpread) <= bodyLength * 0.45
    }

    var hasPlankAlignment: Bool {
        let bodyLength = max(hypot(shoulderCenter.x - ankleCenter.x, shoulderCenter.y - ankleCenter.y), 0.001)
        let expectedHipY = (shoulderCenter.y + ankleCenter.y) / 2
        let expectedKneeY = shoulderCenter.y + (ankleCenter.y - shoulderCenter.y) * 0.72
        let hipDeviation = abs(hipCenter.y - expectedHipY) / bodyLength
        let kneeDeviation = abs(kneeCenter.y - expectedKneeY) / bodyLength

        return hipDeviation <= 0.16 && kneeDeviation <= 0.22
    }

    var hasSaggingHips: Bool {
        let bodyLength = max(hypot(shoulderCenter.x - ankleCenter.x, shoulderCenter.y - ankleCenter.y), 0.001)
        let expectedHipY = (shoulderCenter.y + ankleCenter.y) / 2
        return (hipCenter.y - expectedHipY) / bodyLength > 0.18
    }

    fileprivate static func angle(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint) -> Double {
        let first = CGVector(dx: shoulder.x - elbow.x, dy: shoulder.y - elbow.y)
        let second = CGVector(dx: wrist.x - elbow.x, dy: wrist.y - elbow.y)
        let dot = first.dx * second.dx + first.dy * second.dy
        let firstLength = hypot(first.dx, first.dy)
        let secondLength = hypot(second.dx, second.dy)
        guard firstLength > 0, secondLength > 0 else { return 0 }

        let cosine = min(max(dot / (firstLength * secondLength), -1), 1)
        return acos(cosine) * 180 / .pi
    }

    private func elbowAngle(shoulder: PoseLandmark, elbow: PoseLandmark, wrist: PoseLandmark) -> Double? {
        guard [shoulder, elbow, wrist].allSatisfy(\.isReliable) else { return nil }
        return Self.angle(shoulder: shoulder.point, elbow: elbow.point, wrist: wrist.point)
    }

    private var reliablePlankElbowAngles: [Double] {
        [
            elbowAngle(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist),
            elbowAngle(shoulder: rightShoulder, elbow: rightElbow, wrist: rightWrist)
        ].compactMap { $0 }
    }

    private var reliablePlankWristPairs: [(elbow: PoseLandmark, wrist: PoseLandmark)] {
        [
            (leftElbow, leftWrist),
            (rightElbow, rightWrist)
        ].filter { $0.elbow.isReliable && $0.wrist.isReliable }
    }

    private func kneeAngle(hip: PoseLandmark, knee: PoseLandmark, ankle: PoseLandmark) -> Double? {
        guard [hip, knee, ankle].allSatisfy(\.isReliable) else { return nil }
        return Self.angle(shoulder: hip.point, elbow: knee.point, wrist: ankle.point)
    }
}

struct MovementPoseSmoother {
    private let currentFrameWeight: CGFloat = 0.45
    private var previousSample: PushUpPoseSample?

    mutating func reset() {
        previousSample = nil
    }

    mutating func process(_ sample: PushUpPoseSample) -> PushUpPoseSample {
        guard let previousSample else {
            self.previousSample = sample
            return sample
        }

        let smoothed = PushUpPoseSample(
            timestamp: sample.timestamp,
            leftShoulder: blend(sample.leftShoulder, with: previousSample.leftShoulder),
            rightShoulder: blend(sample.rightShoulder, with: previousSample.rightShoulder),
            leftElbow: blend(sample.leftElbow, with: previousSample.leftElbow),
            rightElbow: blend(sample.rightElbow, with: previousSample.rightElbow),
            leftWrist: blend(sample.leftWrist, with: previousSample.leftWrist),
            rightWrist: blend(sample.rightWrist, with: previousSample.rightWrist),
            leftHip: blend(sample.leftHip, with: previousSample.leftHip),
            rightHip: blend(sample.rightHip, with: previousSample.rightHip),
            leftKnee: blend(sample.leftKnee, with: previousSample.leftKnee),
            rightKnee: blend(sample.rightKnee, with: previousSample.rightKnee),
            leftAnkle: blend(sample.leftAnkle, with: previousSample.leftAnkle),
            rightAnkle: blend(sample.rightAnkle, with: previousSample.rightAnkle),
            face: blend(sample.face, with: previousSample.face)
        )
        self.previousSample = smoothed
        return smoothed
    }

    private func blend(_ current: PoseLandmark, with previous: PoseLandmark) -> PoseLandmark {
        guard current.isVisible, previous.isVisible else { return current }
        let previousWeight = 1 - currentFrameWeight
        return PoseLandmark(
            point: CGPoint(
                x: previous.point.x * previousWeight + current.point.x * currentFrameWeight,
                y: previous.point.y * previousWeight + current.point.y * currentFrameWeight
            ),
            confidence: current.confidence
        )
    }
}

struct MovementChallengeCalibrator {
    static let requiredDuration: TimeInterval = 3

    private let allowedPoseGap: TimeInterval = 0.8
    private var firstValidPoseAt: Date?
    private var lastValidPoseAt: Date?
    private var latestGuidance: String?
    private(set) var progress = 0.0
    private(set) var isReady = false

    mutating func reset() {
        resetTiming()
        latestGuidance = nil
    }

    private mutating func resetTiming() {
        firstValidPoseAt = nil
        lastValidPoseAt = nil
        progress = 0
        isReady = false
    }

    mutating func process(sample: PushUpPoseSample, challengeType: MovementChallengeType) {
        guard accepts(sample, for: challengeType) else {
            latestGuidance = guidance(for: sample, challengeType: challengeType)
            processLostPose(at: sample.timestamp)
            return
        }

        latestGuidance = nil
        lastValidPoseAt = sample.timestamp
        guard !isReady else { return }

        if firstValidPoseAt == nil {
            firstValidPoseAt = sample.timestamp
        }

        let elapsed = sample.timestamp.timeIntervalSince(firstValidPoseAt ?? sample.timestamp)
        progress = min(max(elapsed / Self.requiredDuration, 0), 1)
        isReady = progress >= 1
    }

    mutating func processLostPose(at timestamp: Date) {
        guard !isReady else {
            if let lastValidPoseAt, timestamp.timeIntervalSince(lastValidPoseAt) > allowedPoseGap {
                resetTiming()
            }
            return
        }

        if let lastValidPoseAt, timestamp.timeIntervalSince(lastValidPoseAt) <= allowedPoseGap {
            return
        }
        resetTiming()
    }

    func message(for challengeType: MovementChallengeType) -> String {
        guard isReady else {
            if progress > 0 {
                let remaining = max(Self.requiredDuration * (1 - progress), 0)
                return "Hold still for \(String(format: "%.1f", remaining)) more seconds."
            }
            return latestGuidance ?? challengeType.cameraInstruction
        }

        return "Ready. Form locked in. Start when you are set."
    }

    private func accepts(_ sample: PushUpPoseSample, for challengeType: MovementChallengeType) -> Bool {
        switch challengeType {
        case .pushUp:
            return sample.hasReliableUpperBody && sample.appearsFrontFacing
        case .squat:
            return sample.hasReliableSquatBody
                && sample.appearsUprightFrontFacing
                && sample.appearsStandingForSquat
        case .jumpingJack:
            return sample.hasReliableJumpingJackBody
                && sample.appearsUprightFrontFacing
        case .plank:
            return sample.hasFrontPlankAlignmentForVisibleBody
        }
    }

    private func guidance(for sample: PushUpPoseSample, challengeType: MovementChallengeType) -> String {
        switch challengeType {
        case .pushUp:
            return challengeType.cameraInstruction
        case .squat:
            if !sample.hasReliableSquatBody {
                return "Step back until both shoulders, hips, and knees are visible."
            }
            if !sample.appearsUprightFrontFacing {
                return "Stand upright and face the camera squarely."
            }
            return "Stand tall with your hips above your knees to lock in calibration."
        case .jumpingJack:
            if !sample.hasReliableJumpingJackBody {
                return "Step back until both hands, hips, and knees are visible."
            }
            if !sample.appearsUprightFrontFacing {
                return "Stand upright and face the camera squarely."
            }
            return "Start with your arms down and feet together. Hold that position."
        case .plank:
            if !sample.hasReliablePlankSupportBody {
                return "Face the camera and keep both shoulders, elbows, and at least one hand visible."
            }
            if !sample.appearsSupportedOnForearms {
                return "Lower onto both forearms. This challenge tracks the classic forearm plank."
            }
            return "Keep your body straight and hold still while calibration locks in."
        }
    }
}

enum PushUpRepPhase: String, Codable, Equatable {
    case waitingForSetup
    case up
    case down
    case paused
}

enum PushUpPoseQuality: Equatable {
    case needFullBody
    case needFrontView
    case hipsSagging
    case holdPlank
    case forearmsDown
    case holdStill
    case plankHolding
    case lower
    case squatLower
    case standTall
    case openWide
    case bringItHome
    case goodRep
    case rejected(String)
    case ready

    var message: String {
        switch self {
        case .needFullBody:
            return "Keep both hands, elbows, and shoulders in frame. The app cannot count a disappearing act."
        case .needFrontView:
            return "Face the camera with the phone low on the floor. Keep both arms visible."
        case .hipsSagging:
            return "Straighten the plank. That saggy middle is trying to steal points."
        case .holdPlank:
            return "Straighten your plank. Shoulders, hips, and heels need one line."
        case .forearmsDown:
            return "Lower onto both forearms. This challenge tracks the classic forearm plank."
        case .holdStill:
            return "Hold still. The timer only counts verified plank time."
        case .plankHolding:
            return "Plank verified. Stay tight and keep breathing."
        case .lower:
            return "Lower. That was not a push-up yet."
        case .squatLower:
            return "Lower the squat. Your knees still have more to say."
        case .standTall:
            return "Stand tall to finish the rep."
        case .openWide:
            return "Hands overhead, feet wide. Make the jumping jack obvious."
        case .bringItHome:
            return "Bring your arms down and feet together to finish it."
        case .goodRep:
            return "Good rep. Finally."
        case .rejected(let reason):
            return reason
        case .ready:
            return "Ready. Start moving like points are on the line."
        }
    }
}

struct PushUpAnalysisResult: Equatable {
    var challengeType: MovementChallengeType = .pushUp
    var validRepCount: Int
    var rejectedRepCount: Int
    var phase: PushUpRepPhase
    var quality: PushUpPoseQuality
    var didCountRep: Bool
    var verifiedHoldSeconds: TimeInterval = 0
    var isHoldActive = false
    var pointsAwarded: Int {
        MovementChallengeSession.points(
            for: challengeType,
            validRepCount: validRepCount,
            durationSeconds: verifiedHoldSeconds
        )
    }
}

struct SquatPoseAnalyzer {
    private let standingKneeAngleThreshold: Double = 155
    private let squatKneeAngleThreshold: Double = 125
    private let minimumRepSeconds: TimeInterval = 0.45
    private let maximumRepSeconds: TimeInterval = 10
    private let minimumHipTravel: CGFloat = 0.045

    private(set) var validRepCount = 0
    private(set) var rejectedRepCount = 0
    private(set) var phase: PushUpRepPhase = .waitingForSetup
    private var enteredSquatAt: Date?
    private var standingHipCenter: CGPoint?
    private var maximumHipTravel = CGFloat.zero
    private var sawPartialDescent = false

    var currentResult: PushUpAnalysisResult {
        result(quality: .ready)
    }

    mutating func reset() {
        validRepCount = 0
        rejectedRepCount = 0
        phase = .waitingForSetup
        enteredSquatAt = nil
        standingHipCenter = nil
        maximumHipTravel = 0
        sawPartialDescent = false
    }

    mutating func processLostBody() -> PushUpAnalysisResult {
        let rejectedAttempt = phase == .down || sawPartialDescent
        phase = .paused
        enteredSquatAt = nil
        standingHipCenter = nil
        maximumHipTravel = 0
        sawPartialDescent = false
        if rejectedAttempt {
            rejectedRepCount += 1
            return result(quality: .rejected("Squat abandoned. Keep your hips and knees in frame."))
        }
        return result(quality: .needFullBody)
    }

    mutating func process(sample: PushUpPoseSample) -> PushUpAnalysisResult {
        guard sample.hasReliableSquatBody else {
            return processLostBody()
        }

        guard sample.appearsUprightFrontFacing else {
            let rejectedAttempt = phase == .down || sawPartialDescent
            phase = .waitingForSetup
            enteredSquatAt = nil
            standingHipCenter = nil
            maximumHipTravel = 0
            sawPartialDescent = false
            if rejectedAttempt {
                rejectedRepCount += 1
                return result(quality: .rejected("Squat abandoned. Stay square to the camera."))
            }
            return result(quality: .needFrontView)
        }

        switch phase {
        case .waitingForSetup, .paused:
            guard isStanding(sample) else {
                return result(quality: .standTall)
            }
            phase = .up
            standingHipCenter = sample.hipCenter
            maximumHipTravel = 0
            sawPartialDescent = false
            return result(quality: .ready)

        case .up:
            if isAtSquatBottom(sample) {
                phase = .down
                enteredSquatAt = sample.timestamp
                maximumHipTravel = hipTravel(for: sample)
                sawPartialDescent = false
                return result(quality: .squatLower)
            }
            if sawPartialDescent, isStanding(sample) {
                sawPartialDescent = false
                rejectedRepCount += 1
                return result(quality: .rejected("That was a half squat. Sit lower before standing back up."))
            }
            if isAttemptingSquat(sample) {
                sawPartialDescent = true
            }
            return result(quality: .squatLower)

        case .down:
            maximumHipTravel = max(maximumHipTravel, hipTravel(for: sample))
            guard isStanding(sample) else {
                return result(quality: .standTall)
            }

            let duration = enteredSquatAt.map { sample.timestamp.timeIntervalSince($0) } ?? 0
            let hipTravel = maximumHipTravel
            phase = .up
            enteredSquatAt = nil
            standingHipCenter = sample.hipCenter
            maximumHipTravel = 0
            sawPartialDescent = false

            guard duration >= minimumRepSeconds else {
                rejectedRepCount += 1
                return result(quality: .rejected("Too fast. Give the squat an actual bottom position."))
            }

            guard duration <= maximumRepSeconds else {
                rejectedRepCount += 1
                return result(quality: .rejected("Too slow. Reset, then give me one clean squat."))
            }

            guard hipTravel >= minimumHipTravel else {
                rejectedRepCount += 1
                return result(quality: .rejected("That was a knee bend, not a squat. Sit lower."))
            }

            validRepCount += 1
            return result(quality: .goodRep, didCountRep: true)
        }
    }

    private func hipTravel(for sample: PushUpPoseSample) -> CGFloat {
        guard let standingHipCenter else { return 0 }
        return hypot(sample.hipCenter.x - standingHipCenter.x, sample.hipCenter.y - standingHipCenter.y)
    }

    private func isStanding(_ sample: PushUpPoseSample) -> Bool {
        if let kneeAngle = sample.reliableKneeAngleDegrees {
            return kneeAngle >= standingKneeAngleThreshold
        }
        guard standingHipCenter != nil else { return sample.appearsStandingForSquat }
        return hipTravel(for: sample) <= 0.025 && sample.hipCenter.y < sample.kneeCenter.y
    }

    private func isAtSquatBottom(_ sample: PushUpPoseSample) -> Bool {
        if let kneeAngle = sample.reliableKneeAngleDegrees, kneeAngle <= squatKneeAngleThreshold {
            return true
        }
        return hipTravel(for: sample) >= 0.06
    }

    private func isAttemptingSquat(_ sample: PushUpPoseSample) -> Bool {
        if let kneeAngle = sample.reliableKneeAngleDegrees, kneeAngle < standingKneeAngleThreshold - 8 {
            return true
        }
        return hipTravel(for: sample) >= 0.022
    }

    private func result(quality: PushUpPoseQuality, didCountRep: Bool = false) -> PushUpAnalysisResult {
        PushUpAnalysisResult(
            challengeType: .squat,
            validRepCount: validRepCount,
            rejectedRepCount: rejectedRepCount,
            phase: phase,
            quality: quality,
            didCountRep: didCountRep
        )
    }
}

struct JumpingJackPoseAnalyzer {
    private let minimumRepSeconds: TimeInterval = 0.45
    private let maximumRepSeconds: TimeInterval = 8

    private(set) var validRepCount = 0
    private(set) var rejectedRepCount = 0
    private(set) var phase: PushUpRepPhase = .waitingForSetup
    private var openedAt: Date?
    private var sawPartialOpening = false

    var currentResult: PushUpAnalysisResult {
        result(quality: .ready)
    }

    mutating func reset() {
        validRepCount = 0
        rejectedRepCount = 0
        phase = .waitingForSetup
        openedAt = nil
        sawPartialOpening = false
    }

    mutating func processLostBody() -> PushUpAnalysisResult {
        let rejectedAttempt = phase == .down || sawPartialOpening
        phase = .paused
        openedAt = nil
        sawPartialOpening = false
        if rejectedAttempt {
            rejectedRepCount += 1
            return result(quality: .rejected("Jack abandoned. Keep your hands, hips, and knees in frame."))
        }
        return result(quality: .needFullBody)
    }

    mutating func process(sample: PushUpPoseSample) -> PushUpAnalysisResult {
        guard sample.hasReliableJumpingJackBody else {
            return processLostBody()
        }

        guard sample.appearsUprightFrontFacing else {
            let rejectedAttempt = phase == .down || sawPartialOpening
            phase = .waitingForSetup
            openedAt = nil
            sawPartialOpening = false
            if rejectedAttempt {
                rejectedRepCount += 1
                return result(quality: .rejected("Jack abandoned. Stay square to the camera."))
            }
            return result(quality: .needFrontView)
        }

        switch phase {
        case .waitingForSetup, .paused:
            guard sample.jumpingJackClosed else {
                return result(quality: .bringItHome)
            }
            phase = .up
            sawPartialOpening = false
            return result(quality: .ready)

        case .up:
            if sample.jumpingJackOpen {
                phase = .down
                openedAt = sample.timestamp
                sawPartialOpening = false
                return result(quality: .bringItHome)
            }
            if sawPartialOpening, sample.jumpingJackClosed {
                sawPartialOpening = false
                rejectedRepCount += 1
                return result(quality: .rejected("That was half a jumping jack. Hands up and feet wide."))
            }
            if !sample.jumpingJackClosed, sample.jumpingJackIsInMotion {
                sawPartialOpening = true
            }
            return result(quality: .openWide)

        case .down:
            guard sample.jumpingJackClosed else {
                return result(quality: .bringItHome)
            }

            let duration = openedAt.map { sample.timestamp.timeIntervalSince($0) } ?? 0
            phase = .up
            openedAt = nil
            sawPartialOpening = false

            guard duration >= minimumRepSeconds else {
                rejectedRepCount += 1
                return result(quality: .rejected("Too fast. Let the camera see the full jack."))
            }

            guard duration <= maximumRepSeconds else {
                rejectedRepCount += 1
                return result(quality: .rejected("Too slow. Reset and make the next jack clean."))
            }

            validRepCount += 1
            return result(quality: .goodRep, didCountRep: true)
        }
    }

    private func result(quality: PushUpPoseQuality, didCountRep: Bool = false) -> PushUpAnalysisResult {
        PushUpAnalysisResult(
            challengeType: .jumpingJack,
            validRepCount: validRepCount,
            rejectedRepCount: rejectedRepCount,
            phase: phase,
            quality: quality,
            didCountRep: didCountRep
        )
    }
}

struct PlankPoseAnalyzer {
    private let maximumFrameGap: TimeInterval = 0.5
    private let maximumBodyMovement: CGFloat = 0.055

    private(set) var verifiedHoldSeconds: TimeInterval = 0
    private(set) var breakCount = 0
    private(set) var phase: PushUpRepPhase = .waitingForSetup
    private var lastValidPoseAt: Date?
    private var previousShoulderCenter: CGPoint?
    private var previousStabilityCenter: CGPoint?

    var currentResult: PushUpAnalysisResult {
        result(quality: .forearmsDown)
    }

    mutating func reset() {
        verifiedHoldSeconds = 0
        breakCount = 0
        phase = .waitingForSetup
        clearTrackingBaseline()
    }

    mutating func processLostBody() -> PushUpAnalysisResult {
        pauseHold()
        return result(quality: .needFullBody)
    }

    mutating func process(sample: PushUpPoseSample) -> PushUpAnalysisResult {
        guard sample.hasReliablePlankSupportBody else {
            pauseHold()
            return result(quality: .needFullBody)
        }

        guard sample.appearsSupportedOnForearms else {
            pauseHold()
            return result(quality: .forearmsDown)
        }

        guard sample.hasFrontPlankAlignmentForVisibleBody else {
            pauseHold()
            return result(quality: .holdPlank)
        }

        if bodyMovement(for: sample) > maximumBodyMovement {
            pauseHold()
            return result(quality: .holdStill)
        }

        guard phase == .up else {
            phase = .up
            lastValidPoseAt = sample.timestamp
            previousShoulderCenter = sample.shoulderCenter
            previousStabilityCenter = sample.plankStabilityCenter
            return result(quality: .plankHolding, isHoldActive: true)
        }

        if let lastValidPoseAt {
            let frameDuration = sample.timestamp.timeIntervalSince(lastValidPoseAt)
            if frameDuration > 0, frameDuration <= maximumFrameGap {
                verifiedHoldSeconds += frameDuration
            }
        }

        lastValidPoseAt = sample.timestamp
        previousShoulderCenter = sample.shoulderCenter
        previousStabilityCenter = sample.plankStabilityCenter
        return result(quality: .plankHolding, isHoldActive: true)
    }

    private mutating func pauseHold() {
        if phase == .up {
            breakCount += 1
        }
        phase = .paused
        clearTrackingBaseline()
    }

    private mutating func clearTrackingBaseline() {
        lastValidPoseAt = nil
        previousShoulderCenter = nil
        previousStabilityCenter = nil
    }

    private func bodyMovement(for sample: PushUpPoseSample) -> CGFloat {
        guard let previousShoulderCenter, let previousStabilityCenter else { return 0 }
        let shoulderMovement = hypot(
            sample.shoulderCenter.x - previousShoulderCenter.x,
            sample.shoulderCenter.y - previousShoulderCenter.y
        )
        let supportMovement = hypot(
            sample.plankStabilityCenter.x - previousStabilityCenter.x,
            sample.plankStabilityCenter.y - previousStabilityCenter.y
        )
        return max(shoulderMovement, supportMovement)
    }

    private func result(
        quality: PushUpPoseQuality,
        isHoldActive: Bool = false
    ) -> PushUpAnalysisResult {
        PushUpAnalysisResult(
            challengeType: .plank,
            validRepCount: 0,
            rejectedRepCount: breakCount,
            phase: phase,
            quality: quality,
            didCountRep: false,
            verifiedHoldSeconds: verifiedHoldSeconds,
            isHoldActive: isHoldActive
        )
    }
}

enum MovementRepAnalyzer {
    case pushUp(PushUpPoseAnalyzer)
    case squat(SquatPoseAnalyzer)
    case jumpingJack(JumpingJackPoseAnalyzer)
    case plank(PlankPoseAnalyzer)

    init(challengeType: MovementChallengeType) {
        switch challengeType {
        case .pushUp: self = .pushUp(PushUpPoseAnalyzer())
        case .squat: self = .squat(SquatPoseAnalyzer())
        case .jumpingJack: self = .jumpingJack(JumpingJackPoseAnalyzer())
        case .plank: self = .plank(PlankPoseAnalyzer())
        }
    }

    var currentResult: PushUpAnalysisResult {
        switch self {
        case .pushUp(let analyzer): return analyzer.currentResult
        case .squat(let analyzer): return analyzer.currentResult
        case .jumpingJack(let analyzer): return analyzer.currentResult
        case .plank(let analyzer): return analyzer.currentResult
        }
    }

    mutating func reset() {
        switch self {
        case .pushUp(var analyzer):
            analyzer.reset()
            self = .pushUp(analyzer)
        case .squat(var analyzer):
            analyzer.reset()
            self = .squat(analyzer)
        case .jumpingJack(var analyzer):
            analyzer.reset()
            self = .jumpingJack(analyzer)
        case .plank(var analyzer):
            analyzer.reset()
            self = .plank(analyzer)
        }
    }

    mutating func processLostBody() -> PushUpAnalysisResult {
        switch self {
        case .pushUp(var analyzer):
            let result = analyzer.processLostBody()
            self = .pushUp(analyzer)
            return result
        case .squat(var analyzer):
            let result = analyzer.processLostBody()
            self = .squat(analyzer)
            return result
        case .jumpingJack(var analyzer):
            let result = analyzer.processLostBody()
            self = .jumpingJack(analyzer)
            return result
        case .plank(var analyzer):
            let result = analyzer.processLostBody()
            self = .plank(analyzer)
            return result
        }
    }

    mutating func process(sample: PushUpPoseSample) -> PushUpAnalysisResult {
        switch self {
        case .pushUp(var analyzer):
            let result = analyzer.process(sample: sample)
            self = .pushUp(analyzer)
            return result
        case .squat(var analyzer):
            let result = analyzer.process(sample: sample)
            self = .squat(analyzer)
            return result
        case .jumpingJack(var analyzer):
            let result = analyzer.process(sample: sample)
            self = .jumpingJack(analyzer)
            return result
        case .plank(var analyzer):
            let result = analyzer.process(sample: sample)
            self = .plank(analyzer)
            return result
        }
    }
}

struct PushUpPoseAnalyzer {
    private let upElbowAngleThreshold: Double = 150
    private let downElbowAngleThreshold: Double = 110
    private let minimumRepSeconds: TimeInterval = 0.35
    private let maximumRepSeconds: TimeInterval = 10.0
    private let minimumFrontShoulderTravel: CGFloat = 0.035

    private(set) var validRepCount = 0
    private(set) var rejectedRepCount = 0
    private(set) var phase: PushUpRepPhase = .waitingForSetup
    private var enteredDownAt: Date?
    private var setupShoulderCenter: CGPoint?
    private var maximumShoulderTravel = CGFloat.zero
    private var sawPartialDescent = false

    var currentResult: PushUpAnalysisResult {
        PushUpAnalysisResult(
            validRepCount: validRepCount,
            rejectedRepCount: rejectedRepCount,
            phase: phase,
            quality: .ready,
            didCountRep: false
        )
    }

    mutating func reset() {
        validRepCount = 0
        rejectedRepCount = 0
        phase = .waitingForSetup
        enteredDownAt = nil
        setupShoulderCenter = nil
        maximumShoulderTravel = 0
        sawPartialDescent = false
    }

    mutating func processLostBody() -> PushUpAnalysisResult {
        let rejectedAttempt = phase == .down
        phase = .paused
        enteredDownAt = nil
        setupShoulderCenter = nil
        maximumShoulderTravel = 0
        sawPartialDescent = false
        if rejectedAttempt {
            rejectedRepCount += 1
            return result(quality: .rejected("Rep abandoned. Keep your full upper body in frame."))
        }
        return result(quality: .needFullBody)
    }

    mutating func process(sample: PushUpPoseSample) -> PushUpAnalysisResult {
        guard sample.hasReliableUpperBody else {
            let rejectedAttempt = phase == .down
            phase = .paused
            enteredDownAt = nil
            setupShoulderCenter = nil
            maximumShoulderTravel = 0
            sawPartialDescent = false
            if rejectedAttempt {
                rejectedRepCount += 1
                return result(quality: .rejected("Rep abandoned. Keep your full upper body in frame."))
            }
            return result(quality: .needFullBody)
        }

        guard sample.appearsFrontFacing else {
            let rejectedAttempt = phase == .down
            phase = .waitingForSetup
            enteredDownAt = nil
            setupShoulderCenter = nil
            maximumShoulderTravel = 0
            sawPartialDescent = false
            if rejectedAttempt {
                rejectedRepCount += 1
                return result(quality: .rejected("Rep abandoned. Face the camera and keep both arms visible."))
            }
            return result(quality: .needFrontView)
        }

        let elbowAngle = sample.averageElbowAngleDegrees
        switch phase {
        case .waitingForSetup, .paused:
            if elbowAngle >= upElbowAngleThreshold {
                phase = .up
                setupShoulderCenter = sample.shoulderCenter
                maximumShoulderTravel = 0
                sawPartialDescent = false
                return result(quality: .ready)
            }
            return result(quality: .lower)

        case .up:
            if elbowAngle <= downElbowAngleThreshold {
                phase = .down
                enteredDownAt = sample.timestamp
                maximumShoulderTravel = shoulderTravel(for: sample)
                sawPartialDescent = false
                return result(quality: .lower)
            }
            if elbowAngle < upElbowAngleThreshold {
                sawPartialDescent = true
                return result(quality: .lower)
            }
            if sawPartialDescent {
                sawPartialDescent = false
                rejectedRepCount += 1
                return result(quality: .rejected("That was a half rep. Lower until your elbows clearly bend."))
            }
            return result(quality: .ready)

        case .down:
            maximumShoulderTravel = max(maximumShoulderTravel, shoulderTravel(for: sample))
            guard elbowAngle >= upElbowAngleThreshold else {
                return result(quality: .lower)
            }

            let duration = enteredDownAt.map { sample.timestamp.timeIntervalSince($0) } ?? 0
            let frontShoulderTravel = maximumShoulderTravel
            phase = .up
            enteredDownAt = nil
            setupShoulderCenter = sample.shoulderCenter
            maximumShoulderTravel = 0
            sawPartialDescent = false

            if duration < minimumRepSeconds {
                rejectedRepCount += 1
                return result(quality: .rejected("Too fast. Points are for push-ups, not panic flinches."))
            }

            if duration > maximumRepSeconds {
                rejectedRepCount += 1
                return result(quality: .rejected("Too slow. Reset and give me one clean rep."))
            }

            if frontShoulderTravel < minimumFrontShoulderTravel {
                rejectedRepCount += 1
                return result(quality: .rejected("Bring your chest down. Arm wiggles do not buy points."))
            }

            validRepCount += 1
            return result(quality: .goodRep, didCountRep: true)
        }
    }

    private func shoulderTravel(for sample: PushUpPoseSample) -> CGFloat {
        guard let setupShoulderCenter else { return 0 }
        return hypot(
            sample.shoulderCenter.x - setupShoulderCenter.x,
            sample.shoulderCenter.y - setupShoulderCenter.y
        )
    }

    private func result(quality: PushUpPoseQuality, didCountRep: Bool = false) -> PushUpAnalysisResult {
        PushUpAnalysisResult(
            validRepCount: validRepCount,
            rejectedRepCount: rejectedRepCount,
            phase: phase,
            quality: quality,
            didCountRep: didCountRep
        )
    }
}

extension CGPoint {
    fileprivate static func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
