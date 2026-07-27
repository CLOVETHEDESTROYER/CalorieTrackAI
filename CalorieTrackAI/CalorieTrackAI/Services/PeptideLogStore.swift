import Foundation

@MainActor
final class PeptideLogStore: ObservableObject {
    static let shared = PeptideLogStore()

    @Published private(set) var logs: [PeptideLog] = []
    @Published private(set) var isSyncing = false

    private let storageKey = "PeptideLogs"
    private let supabaseService = SupabaseService.shared

    private init() {
        load()
    }

    func add(_ log: PeptideLog) async {
        logs.insert(log, at: 0)
        save()
        await CoachNotificationService.shared.rescheduleNotifications()

        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedLog = try await supabaseService.savePeptideLog(log)
            if let index = logs.firstIndex(where: { $0.id == log.id }) {
                logs[index] = savedLog
                sortAndSave()
                await CoachNotificationService.shared.rescheduleNotifications()
            }
        } catch {
            #if DEBUG
            print("Peptide log sync failed: \(error)")
            #endif
        }
    }

    func delete(at offsets: IndexSet) async {
        let deletedLogs = offsets.compactMap { index in
            logs.indices.contains(index) ? logs[index] : nil
        }

        for index in offsets.sorted(by: >) {
            logs.remove(at: index)
        }
        save()
        await CoachNotificationService.shared.rescheduleNotifications()

        guard supabaseService.isAuthenticated else {
            return
        }

        for log in deletedLogs {
            do {
                try await supabaseService.deletePeptideLog(log.id)
            } catch {
                #if DEBUG
                print("Peptide log delete sync failed: \(error)")
                #endif
            }
        }
    }

    func markPlannedLogLogged(_ log: PeptideLog, loggedAt: Date = Date()) async {
        var updatedLog = log
        updatedLog.status = .logged
        updatedLog.loggedAt = loggedAt
        updatedLog.scheduledAt = nil
        await update(updatedLog)
    }

    func markPlannedLogSkipped(_ log: PeptideLog, skippedAt: Date = Date()) async {
        var updatedLog = log
        updatedLog.status = .skipped
        updatedLog.loggedAt = skippedAt
        updatedLog.scheduledAt = nil
        await update(updatedLog)
    }

    func clearLocalLogs() {
        logs = []
        save()
        Task {
            await CoachNotificationService.shared.rescheduleNotifications()
        }
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let remoteLogs = try await supabaseService.getPeptideLogs()
            var merged = remoteLogs

            for localLog in logs where !merged.contains(where: { $0.id == localLog.id }) {
                do {
                    let saved = try await supabaseService.savePeptideLog(localLog)
                    merged.append(saved)
                } catch {
                    merged.append(localLog)
                }
            }

            logs = merged.sorted { $0.loggedAt > $1.loggedAt }
            save()
            await CoachNotificationService.shared.rescheduleNotifications()
        } catch {
            #if DEBUG
            print("Peptide log refresh failed: \(error)")
            #endif
        }
    }

    func pendingReminderLogs(now: Date = Date(), limit: Int = 20) -> [PeptideLog] {
        Self.pendingReminderLogs(from: logs, now: now, limit: limit)
    }

    static func pendingReminderLogs(from logs: [PeptideLog], now: Date = Date(), limit: Int = 20) -> [PeptideLog] {
        logs
            .filter { log in
                log.status == .planned && (log.scheduledAt ?? .distantPast) > now
            }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    static func replacing(_ updatedLog: PeptideLog, in logs: [PeptideLog]) -> [PeptideLog] {
        var updatedLogs = logs
        if let index = updatedLogs.firstIndex(where: { $0.id == updatedLog.id }) {
            updatedLogs[index] = updatedLog
        } else {
            updatedLogs.insert(updatedLog, at: 0)
        }

        return updatedLogs.sorted { $0.loggedAt > $1.loggedAt }
    }

    private func sortAndSave() {
        logs.sort { $0.loggedAt > $1.loggedAt }
        save()
    }

    private func update(_ updatedLog: PeptideLog) async {
        logs = Self.replacing(updatedLog, in: logs)
        save()
        await CoachNotificationService.shared.rescheduleNotifications()

        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedLog = try await supabaseService.savePeptideLog(updatedLog)
            logs = Self.replacing(savedLog, in: logs)
            save()
            await CoachNotificationService.shared.rescheduleNotifications()
        } catch {
            #if DEBUG
            print("Peptide log update sync failed: \(error)")
            #endif
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PeptideLog].self, from: data) else {
            logs = []
            return
        }
        logs = decoded.sorted { $0.loggedAt > $1.loggedAt }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
