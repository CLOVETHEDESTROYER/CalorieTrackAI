import Foundation
import CoreLocation

struct ActivityDailySummary: Equatable {
    var date: Date
    var steps: Int
    var stepGoal: Int
    var activeEnergyCalories: Double
    var exerciseMinutes: Double
    var workoutCount: Int
    var gymVisits: [GymVisit]

    static var emptyToday: ActivityDailySummary {
        emptyToday(stepGoal: 10_000)
    }

    static func emptyToday(stepGoal: Int, gymVisits: [GymVisit] = []) -> ActivityDailySummary {
        empty(on: Date(), stepGoal: stepGoal, gymVisits: gymVisits)
    }

    static func empty(
        on date: Date,
        stepGoal: Int,
        gymVisits: [GymVisit] = [],
        calendar: Calendar = .current
    ) -> ActivityDailySummary {
        ActivityDailySummary(
            date: calendar.startOfDay(for: date),
            steps: 0,
            stepGoal: stepGoal,
            activeEnergyCalories: 0,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: gymVisits
        )
    }

    var stepProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(steps) / Double(stepGoal), 1.25)
    }

    var isBehindStepPace: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let expectedProgress = min(max(Double(hour) / 22.0, 0.15), 1.0)
        return Double(steps) < Double(stepGoal) * expectedProgress * 0.75
    }

    var completedWorkoutToday: Bool {
        workoutCount > 0 || !gymVisits.isEmpty || exerciseMinutes >= 20
    }
}

struct StepMovementSnapshot: Equatable {
    var lastStepCount: Int
    var lastStepCountDate: Date?
    var lastMovementAt: Date?
}

enum StepMovementTracker {
    static func updatedSnapshot(
        for summary: ActivityDailySummary,
        previous: StepMovementSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StepMovementSnapshot {
        let isSameObservedDay = previous.lastStepCountDate.map {
            calendar.isDate($0, inSameDayAs: summary.date)
        } ?? false
        let baselineSteps = isSameObservedDay ? previous.lastStepCount : 0
        let didMove = summary.steps > baselineSteps

        return StepMovementSnapshot(
            lastStepCount: summary.steps,
            lastStepCountDate: summary.date,
            lastMovementAt: didMove ? now : previous.lastMovementAt
        )
    }
}

struct ManualWorkoutLog: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var completedAt: Date
    var durationMinutes: Double

    init(
        id: UUID = UUID(),
        name: String = "Manual workout",
        completedAt: Date = Date(),
        durationMinutes: Double = 30
    ) {
        self.id = id
        self.name = name
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
    }
}

struct ManualWorkoutDailyRollup: Equatable {
    var count: Int
    var minutes: Double
}

struct ActivityDailySummaryRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var activity_date: String
    var steps: Int
    var step_goal: Int
    var active_energy_calories: Double
    var exercise_minutes: Double
    var workout_count: Int
    var created_at: Date?
    var updated_at: Date?

    init(id: UUID = UUID(), summary: ActivityDailySummary, userId: UUID? = nil) {
        self.id = id
        user_id = userId
        activity_date = ActivityDateFormatter.string(from: summary.date)
        steps = summary.steps
        step_goal = summary.stepGoal
        active_energy_calories = summary.activeEnergyCalories
        exercise_minutes = summary.exerciseMinutes
        workout_count = summary.workoutCount
        created_at = nil
        updated_at = nil
    }

    func toSummary(gymVisits: [GymVisit] = []) -> ActivityDailySummary {
        ActivityDailySummary(
            date: ActivityDateFormatter.date(from: activity_date) ?? Date(),
            steps: steps,
            stepGoal: step_goal,
            activeEnergyCalories: active_energy_calories,
            exerciseMinutes: exercise_minutes,
            workoutCount: workout_count,
            gymVisits: gymVisits
        )
    }
}

enum ActivityDateFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

struct GymLocation: Identifiable, Codable, Equatable {
    static let automaticCheckInRadiusMeters: Double = 3.1
    static let maximumAutomaticCheckInHorizontalAccuracyMeters: Double = 10
    static let regionMonitoringRadiusMeters: Double = 120
    static let maximumAutomaticLocationAge: TimeInterval = 20

    let id: UUID
    var name: String
    var chain: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var address: String?
    var distanceMeters: Double?
    /// A user-confirmed gym entrance. Map search coordinates remain the place identity.
    var entranceLatitude: Double?
    var entranceLongitude: Double?

    init(
        id: UUID = UUID(),
        name: String,
        chain: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 160,
        address: String? = nil,
        distanceMeters: Double? = nil,
        entranceLatitude: Double? = nil,
        entranceLongitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.chain = chain
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.address = address
        self.distanceMeters = distanceMeters
        self.entranceLatitude = entranceLatitude
        self.entranceLongitude = entranceLongitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var checkInCoordinate: CLLocationCoordinate2D {
        guard let entranceLatitude, let entranceLongitude else {
            return coordinate
        }
        return CLLocationCoordinate2D(latitude: entranceLatitude, longitude: entranceLongitude)
    }

    var hasEntrancePin: Bool {
        entranceLatitude != nil && entranceLongitude != nil
    }

    var effectiveCheckInRadiusMeters: Double {
        min(radiusMeters, Self.automaticCheckInRadiusMeters)
    }

    var effectiveMonitoringRadiusMeters: Double {
        max(Self.regionMonitoringRadiusMeters, radiusMeters)
    }
}

struct GymLocationRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var name: String
    var chain: String?
    var latitude: Double
    var longitude: Double
    var radius_meters: Double
    var address: String?
    var entrance_latitude: Double?
    var entrance_longitude: Double?
    var created_at: Date?
    var updated_at: Date?

    init(location: GymLocation, userId: UUID? = nil) {
        id = location.id
        user_id = userId
        name = location.name
        chain = location.chain
        latitude = location.latitude
        longitude = location.longitude
        radius_meters = location.radiusMeters
        address = location.address
        entrance_latitude = location.entranceLatitude
        entrance_longitude = location.entranceLongitude
        created_at = nil
        updated_at = nil
    }

    func toLocation() -> GymLocation {
        GymLocation(
            id: id,
            name: name,
            chain: chain ?? "Custom Gym",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radius_meters,
            address: address,
            entranceLatitude: entrance_latitude,
            entranceLongitude: entrance_longitude
        )
    }
}

struct GymVisit: Identifiable, Codable, Equatable {
    let id: UUID
    var gymLocationId: UUID
    var gymName: String
    var arrivedAt: Date
    var departedAt: Date?
    var source: Source

    enum Source: String, Codable {
        case geofence
        case manual
    }

    init(
        id: UUID = UUID(),
        gymLocationId: UUID,
        gymName: String,
        arrivedAt: Date = Date(),
        departedAt: Date? = nil,
        source: Source
    ) {
        self.id = id
        self.gymLocationId = gymLocationId
        self.gymName = gymName
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.source = source
    }
}

enum GymVisitReceiptPolicy {
    static func hasReceiptToday(
        for gym: GymLocation,
        visits: [GymVisit],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        visits.contains { visit in
            visit.gymLocationId == gym.id &&
                calendar.isDate(visit.arrivedAt, inSameDayAs: now)
        }
    }
}

struct PendingGymAutoCheckIn: Equatable {
    var gymId: UUID
    var gymName: String
    var firstMatchedAt: Date
    var firstDistanceMeters: Double?
}

enum GymAutoCheckInDwellPolicy {
    static let requiredDwellSeconds: TimeInterval = 90

    static func candidate(from diagnostic: GymCheckInDiagnostic) -> PendingGymAutoCheckIn? {
        guard diagnostic.outcome == .checkedIn,
              let gymId = diagnostic.nearestGymId,
              let gymName = diagnostic.nearestGymName else {
            return nil
        }

        return PendingGymAutoCheckIn(
            gymId: gymId,
            gymName: gymName,
            firstMatchedAt: diagnostic.checkedAt,
            firstDistanceMeters: diagnostic.distanceMeters
        )
    }

    static func shouldLogAutomaticVisit(
        pending: PendingGymAutoCheckIn?,
        diagnostic: GymCheckInDiagnostic,
        now: Date
    ) -> Bool {
        guard diagnostic.outcome == .checkedIn,
              let pending,
              diagnostic.nearestGymId == pending.gymId else {
            return false
        }

        return now.timeIntervalSince(pending.firstMatchedAt) >= requiredDwellSeconds
    }

    static func secondsRemaining(
        pending: PendingGymAutoCheckIn,
        now: Date
    ) -> Int {
        max(Int(ceil(requiredDwellSeconds - now.timeIntervalSince(pending.firstMatchedAt))), 0)
    }

    static func pendingMessage(gymName: String, secondsRemaining: Int) -> String {
        "You look close to \(gymName). Hold still for \(secondsRemaining)s so this does not count a drive-by as a workout."
    }
}

struct GymCheckInDiagnostic: Equatable {
    enum Outcome: Equatable {
        case checkedIn
        case alreadyCheckedIn
        case awaitingConfirmation
        case outsideRadius
        case lowAccuracy
        case staleLocation
        case movingTooFast
        case noSavedGyms
    }

    enum AutomaticTrigger: Equatable {
        case currentLocation
        case regionEntry
    }

    var outcome: Outcome
    var checkedAt: Date
    var nearestGymId: UUID?
    var nearestGymName: String?
    var distanceMeters: Double?
    var radiusMeters: Double?
    var message: String

    var shouldLogAutomaticVisit: Bool {
        outcome == .checkedIn
    }

    static func awaitingConfirmation(
        from diagnostic: GymCheckInDiagnostic,
        secondsRemaining: Int
    ) -> GymCheckInDiagnostic {
        GymCheckInDiagnostic(
            outcome: .awaitingConfirmation,
            checkedAt: diagnostic.checkedAt,
            nearestGymId: diagnostic.nearestGymId,
            nearestGymName: diagnostic.nearestGymName,
            distanceMeters: diagnostic.distanceMeters,
            radiusMeters: diagnostic.radiusMeters,
            message: GymAutoCheckInDwellPolicy.pendingMessage(
                gymName: diagnostic.nearestGymName ?? "this gym",
                secondsRemaining: secondsRemaining
            )
        )
    }

    static func evaluate(
        location: CLLocation,
        savedGyms: [GymLocation],
        todaysVisits: [GymVisit],
        checkedAt: Date = Date()
    ) -> GymCheckInDiagnostic {
        guard !savedGyms.isEmpty else {
            return GymCheckInDiagnostic(
                outcome: .noSavedGyms,
                checkedAt: checkedAt,
                nearestGymId: nil,
                nearestGymName: nil,
                distanceMeters: nil,
                radiusMeters: nil,
                message: "Save a gym before checking whether you are standing in one."
            )
        }

        if location.timestamp.timeIntervalSinceNow < -GymLocation.maximumAutomaticLocationAge {
            return GymCheckInDiagnostic(
                outcome: .staleLocation,
                checkedAt: checkedAt,
                nearestGymId: nil,
                nearestGymName: nil,
                distanceMeters: nil,
                radiusMeters: nil,
                message: "That location is too old to count. Let the phone settle and try the arrival check again."
            )
        }

        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > GymLocation.maximumAutomaticCheckInHorizontalAccuracyMeters {
            return GymCheckInDiagnostic(
                outcome: .lowAccuracy,
                checkedAt: checkedAt,
                nearestGymId: nil,
                nearestGymName: nil,
                distanceMeters: nil,
                radiusMeters: nil,
                message: "Location accuracy is too loose for an automatic gym receipt. Get closer and let GPS settle before counting it."
            )
        }

        if location.speed > 6.7 {
            return GymCheckInDiagnostic(
                outcome: .movingTooFast,
                checkedAt: checkedAt,
                nearestGymId: nil,
                nearestGymName: nil,
                distanceMeters: nil,
                radiusMeters: nil,
                message: "You are moving too fast for a gym check-in. Drive-bys do not count as workouts."
            )
        }

        let nearestGym = savedGyms
            .map { gym -> (gym: GymLocation, distance: CLLocationDistance) in
                let gymLocation = CLLocation(latitude: gym.checkInCoordinate.latitude, longitude: gym.checkInCoordinate.longitude)
                return (gym, location.distance(from: gymLocation))
            }
            .sorted { $0.distance < $1.distance }
            .first!

        let arrivalRadius = nearestGym.gym.effectiveCheckInRadiusMeters
        let alreadyLoggedTodayForGym = todaysVisits.contains { $0.gymLocationId == nearestGym.gym.id }

        if nearestGym.distance <= arrivalRadius, alreadyLoggedTodayForGym {
            return GymCheckInDiagnostic(
                outcome: .alreadyCheckedIn,
                checkedAt: checkedAt,
                nearestGymId: nearestGym.gym.id,
                nearestGymName: nearestGym.gym.name,
                distanceMeters: nearestGym.distance,
                radiusMeters: arrivalRadius,
                message: "You are inside \(nearestGym.gym.name)'s check-in radius, but you already have a receipt there today."
            )
        }

        if nearestGym.distance <= arrivalRadius {
            return GymCheckInDiagnostic(
                outcome: .checkedIn,
                checkedAt: checkedAt,
                nearestGymId: nearestGym.gym.id,
                nearestGymName: nearestGym.gym.name,
                distanceMeters: nearestGym.distance,
                radiusMeters: arrivalRadius,
                message: "Current location matched \(nearestGym.gym.name). Automatic check-in logged."
            )
        }

        let distance = Int(nearestGym.distance.rounded())
        return GymCheckInDiagnostic(
            outcome: .outsideRadius,
            checkedAt: checkedAt,
            nearestGymId: nearestGym.gym.id,
            nearestGymName: nearestGym.gym.name,
            distanceMeters: nearestGym.distance,
            radiusMeters: arrivalRadius,
            message: "Nearest saved gym is \(distance)m away from \(nearestGym.gym.name). No auto check-in yet."
        )
    }

    static func automaticVisitResult(
        for gym: GymLocation,
        didLogVisit: Bool,
        checkedAt: Date = Date(),
        distanceMeters: Double? = nil,
        trigger: AutomaticTrigger
    ) -> GymCheckInDiagnostic {
        GymCheckInDiagnostic(
            outcome: didLogVisit ? .checkedIn : .alreadyCheckedIn,
            checkedAt: checkedAt,
            nearestGymId: gym.id,
            nearestGymName: gym.name,
            distanceMeters: distanceMeters,
            radiusMeters: gym.effectiveCheckInRadiusMeters,
            message: automaticVisitMessage(for: gym, didLogVisit: didLogVisit, trigger: trigger)
        )
    }

    private static func automaticVisitMessage(
        for gym: GymLocation,
        didLogVisit: Bool,
        trigger: AutomaticTrigger
    ) -> String {
        switch (trigger, didLogVisit) {
        case (.currentLocation, true):
            return "Current location matched \(gym.name). Automatic check-in logged."
        case (.currentLocation, false):
            return "Current location matched \(gym.name), but you already have a receipt there today."
        case (.regionEntry, true):
            return "iOS reported arrival at \(gym.name). Automatic check-in logged."
        case (.regionEntry, false):
            return "iOS reported arrival at \(gym.name), but you already have a receipt there today."
        }
    }
}

struct GymVisitRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var gym_location_id: UUID?
    var gym_name: String
    var arrived_at: Date
    var departed_at: Date?
    var source: String
    var created_at: Date?
    var updated_at: Date?

    init(visit: GymVisit, userId: UUID? = nil) {
        id = visit.id
        user_id = userId
        gym_location_id = visit.gymLocationId
        gym_name = visit.gymName
        arrived_at = visit.arrivedAt
        departed_at = visit.departedAt
        source = visit.source.rawValue
        created_at = nil
        updated_at = nil
    }

    func toVisit() -> GymVisit {
        GymVisit(
            id: id,
            gymLocationId: gym_location_id ?? UUID(),
            gymName: gym_name,
            arrivedAt: arrived_at,
            departedAt: departed_at,
            source: GymVisit.Source(rawValue: source) ?? .manual
        )
    }
}

enum KnownGymChain: String, CaseIterable, Identifiable {
    case chuze = "Chuze Fitness"
    case planetFitness = "Planet Fitness"
    case vasa = "VASA Fitness"
    case eos = "EOS Fitness"
    case crunch = "Crunch Fitness"
    case laFitness = "LA Fitness"
    case anytimeFitness = "Anytime Fitness"

    var id: String { rawValue }
}
