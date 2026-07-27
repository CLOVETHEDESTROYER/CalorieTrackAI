import Foundation

struct PeptideTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let note: String

    static let custom = PeptideTemplate(
        id: "custom",
        name: "Custom label",
        category: "User-entered",
        note: "Enter exactly what appears on your clinician, pharmacy, or product label. This app does not verify or recommend it."
    )

    static let popular: [PeptideTemplate] = [
        PeptideTemplate(id: "semaglutide", name: "Semaglutide", category: "GLP-1", note: "Logbook label only. Follow clinician and pharmacy instructions."),
        PeptideTemplate(id: "tirzepatide", name: "Tirzepatide", category: "GLP-1/GIP", note: "Logbook label only. Follow clinician and pharmacy instructions."),
        PeptideTemplate(id: "retatrutide", name: "Retatrutide", category: "Triple agonist", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "bpc-157", name: "BPC-157", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "tb-500", name: "TB-500", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "cjc-1295", name: "CJC-1295", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "ipamorelin", name: "Ipamorelin", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "aod-9604", name: "AOD-9604", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "tesamorelin", name: "Tesamorelin", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "nad-plus", name: "NAD+", category: "Wellness", note: "Tracking label only. This app does not recommend use."),
        PeptideTemplate(id: "mots-c", name: "MOTS-c", category: "Peptide", note: "Tracking label only. This app does not recommend use."),
        custom
    ]

    var requiresCustomName: Bool {
        id == Self.custom.id
    }

    func resolvedName(customName: String) -> String? {
        let trimmedCustomName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if requiresCustomName {
            return trimmedCustomName.isEmpty ? nil : trimmedCustomName
        }

        return name
    }
}

struct ReconstitutionResult: Equatable {
    let concentrationMcgPerMl: Double
    let concentrationMgPerMl: Double
    let drawVolumeMl: Double
    let syringeUnits: Double

    var safetyWarnings: [String] {
        Self.safetyWarnings(drawVolumeMl: drawVolumeMl, syringeUnits: syringeUnits)
    }

    static func safetyWarnings(drawVolumeMl: Double, syringeUnits: Double) -> [String] {
        var warnings: [String] = []

        if syringeUnits > 100 {
            warnings.append("Calculated draw is more than 100 U-100 units. Confirm the label amount, concentration, and syringe size with a clinician or pharmacy before recording it.")
        }

        if drawVolumeMl < 0.01 || syringeUnits < 1 {
            warnings.append("Calculated draw is very small. Tiny volumes can be hard to measure accurately; confirm the label math before recording it.")
        }

        return warnings
    }
}

struct ReconstitutionMathStep: Identifiable, Equatable {
    let id: Int
    let title: String
    let detail: String
}

struct BACWaterPlanningResult: Equatable {
    let targetDrawVolumeMl: Double
    let bacWaterMl: Double
    let concentrationMcgPerMl: Double
    let concentrationMgPerMl: Double
    let syringeUnits: Double

    var safetyWarnings: [String] {
        var warnings = ReconstitutionResult.safetyWarnings(
            drawVolumeMl: targetDrawVolumeMl,
            syringeUnits: syringeUnits
        )

        if bacWaterMl > 5 {
            warnings.append("Calculated BAC water is more than 5 mL. Confirm vial capacity, product label, and syringe plan before recording it.")
        }

        if bacWaterMl < 0.1 {
            warnings.append("Calculated BAC water is very low. That may be hard to measure accurately and may not match the product label.")
        }

        return warnings
    }
}

enum PeptideLogStatus: String, Codable, CaseIterable, Identifiable {
    case logged
    case planned
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logged:
            return "Logged"
        case .planned:
            return "Planned"
        case .skipped:
            return "Skipped"
        }
    }
}

enum ReconstitutionCalculator {
    enum CalculatorError: LocalizedError {
        case invalidInput
        case labelAmountExceedsVial

        var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Enter positive numbers for vial label amount, BAC water, and the label-directed amount you want to record."
            case .labelAmountExceedsVial:
                return "The label-directed amount is larger than the amount listed for the vial."
            }
        }
    }

    static func calculate(
        vialAmountMg: Double,
        bacWaterMl: Double,
        labelAmountMcg: Double
    ) throws -> ReconstitutionResult {
        guard vialAmountMg > 0, bacWaterMl > 0, labelAmountMcg > 0 else {
            throw CalculatorError.invalidInput
        }

        let totalMcg = vialAmountMg * 1000
        guard labelAmountMcg <= totalMcg else {
            throw CalculatorError.labelAmountExceedsVial
        }

        let concentrationMcgPerMl = totalMcg / bacWaterMl
        let drawVolumeMl = labelAmountMcg / concentrationMcgPerMl

        return ReconstitutionResult(
            concentrationMcgPerMl: concentrationMcgPerMl,
            concentrationMgPerMl: concentrationMcgPerMl / 1000,
            drawVolumeMl: drawVolumeMl,
            syringeUnits: drawVolumeMl * 100
        )
    }

    static func calculateBACWaterNeeded(
        vialAmountMg: Double,
        labelAmountMcg: Double,
        targetSyringeUnits: Double
    ) throws -> BACWaterPlanningResult {
        guard vialAmountMg > 0, labelAmountMcg > 0, targetSyringeUnits > 0 else {
            throw CalculatorError.invalidInput
        }

        let totalMcg = vialAmountMg * 1000
        guard labelAmountMcg <= totalMcg else {
            throw CalculatorError.labelAmountExceedsVial
        }

        let targetDrawVolumeMl = targetSyringeUnits / 100
        let concentrationMcgPerMl = labelAmountMcg / targetDrawVolumeMl
        let bacWaterMl = totalMcg / concentrationMcgPerMl

        return BACWaterPlanningResult(
            targetDrawVolumeMl: targetDrawVolumeMl,
            bacWaterMl: bacWaterMl,
            concentrationMcgPerMl: concentrationMcgPerMl,
            concentrationMgPerMl: concentrationMcgPerMl / 1000,
            syringeUnits: targetSyringeUnits
        )
    }

    static func explanationSteps(
        vialAmountMg: Double,
        bacWaterMl: Double,
        labelAmountMcg: Double,
        result: ReconstitutionResult
    ) -> [ReconstitutionMathStep] {
        let totalMcg = vialAmountMg * 1000
        return [
            ReconstitutionMathStep(
                id: 1,
                title: "Convert the vial label",
                detail: "\(format(vialAmountMg, decimals: 2)) mg = \(format(totalMcg, decimals: 0)) mcg total in the vial."
            ),
            ReconstitutionMathStep(
                id: 2,
                title: "Find concentration",
                detail: "\(format(totalMcg, decimals: 0)) mcg ÷ \(format(bacWaterMl, decimals: 2)) mL BAC = \(format(result.concentrationMcgPerMl, decimals: 0)) mcg/mL."
            ),
            ReconstitutionMathStep(
                id: 3,
                title: "Convert the label amount to volume",
                detail: "\(format(labelAmountMcg, decimals: 0)) mcg ÷ \(format(result.concentrationMcgPerMl, decimals: 0)) mcg/mL = \(format(result.drawVolumeMl, decimals: 3)) mL."
            ),
            ReconstitutionMathStep(
                id: 4,
                title: "Map volume to U-100 units",
                detail: "\(format(result.drawVolumeMl, decimals: 3)) mL × 100 = \(format(result.syringeUnits, decimals: 1)) units."
            )
        ]
    }

    private static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

struct PeptideLog: Identifiable, Codable, Equatable {
    let id: UUID
    var peptideName: String
    var status: PeptideLogStatus
    var vialAmountMg: Double
    var bacWaterMl: Double
    var labelAmountMcg: Double
    var drawVolumeMl: Double
    var syringeUnits: Double
    var site: String
    var notes: String
    var loggedAt: Date
    var scheduledAt: Date?

    init(
        id: UUID = UUID(),
        peptideName: String,
        status: PeptideLogStatus = .logged,
        vialAmountMg: Double,
        bacWaterMl: Double,
        labelAmountMcg: Double,
        drawVolumeMl: Double,
        syringeUnits: Double,
        site: String = "",
        notes: String = "",
        loggedAt: Date = Date(),
        scheduledAt: Date? = nil
    ) {
        self.id = id
        self.peptideName = peptideName
        self.status = status
        self.vialAmountMg = vialAmountMg
        self.bacWaterMl = bacWaterMl
        self.labelAmountMcg = labelAmountMcg
        self.drawVolumeMl = drawVolumeMl
        self.syringeUnits = syringeUnits
        self.site = site
        self.notes = notes
        self.loggedAt = loggedAt
        self.scheduledAt = scheduledAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case peptideName
        case status
        case vialAmountMg
        case bacWaterMl
        case labelAmountMcg
        case legacyDesiredDoseMcg = "desiredDoseMcg"
        case drawVolumeMl
        case syringeUnits
        case site
        case notes
        case loggedAt
        case scheduledAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        peptideName = try container.decode(String.self, forKey: .peptideName)
        status = try container.decodeIfPresent(PeptideLogStatus.self, forKey: .status) ?? .logged
        vialAmountMg = try container.decode(Double.self, forKey: .vialAmountMg)
        bacWaterMl = try container.decode(Double.self, forKey: .bacWaterMl)
        labelAmountMcg = try container.decodeIfPresent(Double.self, forKey: .labelAmountMcg)
            ?? container.decode(Double.self, forKey: .legacyDesiredDoseMcg)
        drawVolumeMl = try container.decode(Double.self, forKey: .drawVolumeMl)
        syringeUnits = try container.decode(Double.self, forKey: .syringeUnits)
        site = try container.decodeIfPresent(String.self, forKey: .site) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        loggedAt = try container.decode(Date.self, forKey: .loggedAt)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(peptideName, forKey: .peptideName)
        try container.encode(status, forKey: .status)
        try container.encode(vialAmountMg, forKey: .vialAmountMg)
        try container.encode(bacWaterMl, forKey: .bacWaterMl)
        try container.encode(labelAmountMcg, forKey: .labelAmountMcg)
        try container.encode(drawVolumeMl, forKey: .drawVolumeMl)
        try container.encode(syringeUnits, forKey: .syringeUnits)
        try container.encode(site, forKey: .site)
        try container.encode(notes, forKey: .notes)
        try container.encode(loggedAt, forKey: .loggedAt)
        try container.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
    }
}

struct PeptideTrackerSummary: Equatable {
    var loggedCount: Int
    var plannedCount: Int
    var skippedCount: Int
    var overdueCount: Int
    var nextPlanned: PeptideLog?
    var lastLogged: PeptideLog?

    var hasAnyLogs: Bool {
        loggedCount > 0 || plannedCount > 0 || skippedCount > 0
    }

    static func make(logs: [PeptideLog], now: Date = Date()) -> PeptideTrackerSummary {
        let logged = logs.filter { $0.status == .logged }
        let planned = logs.filter { $0.status == .planned }
        let skipped = logs.filter { $0.status == .skipped }
        let overdue = planned.filter { ($0.scheduledAt ?? $0.loggedAt) < now }
        let nextPlanned = planned
            .filter { ($0.scheduledAt ?? $0.loggedAt) >= now }
            .sorted { ($0.scheduledAt ?? $0.loggedAt) < ($1.scheduledAt ?? $1.loggedAt) }
            .first
        let lastLogged = logged.sorted { $0.loggedAt > $1.loggedAt }.first

        return PeptideTrackerSummary(
            loggedCount: logged.count,
            plannedCount: planned.count,
            skippedCount: skipped.count,
            overdueCount: overdue.count,
            nextPlanned: nextPlanned,
            lastLogged: lastLogged
        )
    }
}

enum PeptideLogListFilter: String, CaseIterable, Identifiable {
    case all
    case planned
    case overdue
    case logged
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .planned:
            return "Planned"
        case .overdue:
            return "Overdue"
        case .logged:
            return "Logged"
        case .skipped:
            return "Skipped"
        }
    }

    func logs(from logs: [PeptideLog], now: Date = Date()) -> [PeptideLog] {
        switch self {
        case .all:
            return logs.sorted { $0.loggedAt > $1.loggedAt }
        case .planned:
            return logs
                .filter { $0.status == .planned }
                .sorted { ($0.scheduledAt ?? $0.loggedAt) < ($1.scheduledAt ?? $1.loggedAt) }
        case .overdue:
            return logs
                .filter { $0.status == .planned && ($0.scheduledAt ?? $0.loggedAt) < now }
                .sorted { ($0.scheduledAt ?? $0.loggedAt) < ($1.scheduledAt ?? $1.loggedAt) }
        case .logged:
            return logs
                .filter { $0.status == .logged }
                .sorted { $0.loggedAt > $1.loggedAt }
        case .skipped:
            return logs
                .filter { $0.status == .skipped }
                .sorted { $0.loggedAt > $1.loggedAt }
        }
    }
}

struct PeptideLogRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var peptide_name: String
    var status: String?
    var vial_amount_mg: Double
    var bac_water_ml: Double
    var label_amount_mcg: Double
    var draw_volume_ml: Double
    var syringe_units: Double
    var site: String?
    var notes: String?
    var logged_at: Date
    var scheduled_at: Date?
    var created_at: Date?
    var updated_at: Date?

    init(log: PeptideLog, userId: UUID? = nil) {
        id = log.id
        user_id = userId
        peptide_name = log.peptideName
        status = log.status.rawValue
        vial_amount_mg = log.vialAmountMg
        bac_water_ml = log.bacWaterMl
        label_amount_mcg = log.labelAmountMcg
        draw_volume_ml = log.drawVolumeMl
        syringe_units = log.syringeUnits
        site = log.site.isEmpty ? nil : log.site
        notes = log.notes.isEmpty ? nil : log.notes
        logged_at = log.loggedAt
        scheduled_at = log.scheduledAt
        created_at = nil
        updated_at = nil
    }

    func toLog() -> PeptideLog {
        PeptideLog(
            id: id,
            peptideName: peptide_name,
            status: PeptideLogStatus(rawValue: status ?? "") ?? .logged,
            vialAmountMg: vial_amount_mg,
            bacWaterMl: bac_water_ml,
            labelAmountMcg: label_amount_mcg,
            drawVolumeMl: draw_volume_ml,
            syringeUnits: syringe_units,
            site: site ?? "",
            notes: notes ?? "",
            loggedAt: logged_at,
            scheduledAt: scheduled_at
        )
    }
}
