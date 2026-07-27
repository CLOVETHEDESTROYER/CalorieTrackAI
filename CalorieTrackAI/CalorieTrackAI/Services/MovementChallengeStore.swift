import Foundation

@MainActor
final class MovementChallengeStore: ObservableObject {
    static let shared = MovementChallengeStore()

    @Published private(set) var sessions: [MovementChallengeSession] = []
    @Published private(set) var isSyncing = false

    private let storageKey = "MovementChallengeSessions"
    private let supabaseService = SupabaseService.shared

    private init() {
        load()
    }

    func saveSession(_ session: MovementChallengeSession) async {
        upsertLocal(session)

        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let saved = try await supabaseService.saveMovementChallengeSession(session)
            upsertLocal(saved)
        } catch {
            #if DEBUG
            print("Movement challenge sync failed: \(error)")
            #endif
        }
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let remoteSessions = try await supabaseService.getMovementChallengeSessions()
            merge(remoteSessions)
        } catch {
            #if DEBUG
            print("Movement challenge refresh failed: \(error)")
            #endif
        }
    }

    func clearLocalSessions() {
        sessions = []
        save()
    }

    func todaysRollup(now: Date = Date(), calendar: Calendar = .current) -> MovementChallengeDailyRollup {
        Self.rollup(on: now, from: sessions, calendar: calendar)
    }

    func rollup(for date: Date, calendar: Calendar = .current) -> MovementChallengeDailyRollup {
        Self.rollup(on: date, from: sessions, calendar: calendar)
    }

    nonisolated static func sessions(
        on date: Date,
        from sessions: [MovementChallengeSession],
        calendar: Calendar = .current
    ) -> [MovementChallengeSession] {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    nonisolated static func rollup(
        on date: Date,
        from sessions: [MovementChallengeSession],
        calendar: Calendar = .current
    ) -> MovementChallengeDailyRollup {
        let dailySessions = Self.sessions(on: date, from: sessions, calendar: calendar)
        guard !dailySessions.isEmpty else {
            return .empty
        }

        return MovementChallengeDailyRollup(
            sessionCount: dailySessions.count,
            validRepCount: dailySessions.reduce(0) { $0 + $1.validRepCount },
            rejectedRepCount: dailySessions.reduce(0) { $0 + $1.rejectedRepCount },
            pointsAwarded: dailySessions.reduce(0) { $0 + $1.pointsAwarded },
            durationSeconds: dailySessions.reduce(0) { $0 + $1.durationSeconds }
        )
    }

    private func upsertLocal(_ session: MovementChallengeSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }

        sortAndSave()
    }

    private func merge(_ remoteSessions: [MovementChallengeSession]) {
        var mergedById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for session in remoteSessions {
            mergedById[session.id] = session
        }

        sessions = Array(mergedById.values)
            .sorted { $0.startedAt > $1.startedAt }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MovementChallengeSession].self, from: data) else {
            sessions = []
            return
        }

        sessions = decoded.sorted { $0.startedAt > $1.startedAt }
    }

    private func sortAndSave() {
        sessions.sort { $0.startedAt > $1.startedAt }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
