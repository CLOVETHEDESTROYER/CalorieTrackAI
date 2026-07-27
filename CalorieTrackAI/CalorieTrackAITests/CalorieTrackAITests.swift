import Foundation
import CoreGraphics
import CoreLocation
import Security
import Speech
import Testing
@testable import CalorieTrackAI

struct CalorieTrackAITests {

    @Test func reconstitutionCalculatorUsesUserEnteredLabelAmount() throws {
        let result = try ReconstitutionCalculator.calculate(
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250
        )

        #expect(result.concentrationMcgPerMl == 2_500)
        #expect(result.concentrationMgPerMl == 2.5)
        #expect(result.drawVolumeMl == 0.1)
        #expect(result.syringeUnits == 10)
    }

    @Test func reconstitutionCalculatorRejectsInvalidInputs() {
        #expect(throws: ReconstitutionCalculator.CalculatorError.invalidInput) {
            try ReconstitutionCalculator.calculate(
                vialAmountMg: 0,
                bacWaterMl: 2,
                labelAmountMcg: 250
            )
        }
    }

    @Test func reconstitutionCalculatorRejectsLabelAmountLargerThanVial() {
        #expect(throws: ReconstitutionCalculator.CalculatorError.labelAmountExceedsVial) {
            try ReconstitutionCalculator.calculate(
                vialAmountMg: 1,
                bacWaterMl: 2,
                labelAmountMcg: 1_001
            )
        }
    }

    @Test func reconstitutionResultWarnsForLargeU100Draw() throws {
        let result = try ReconstitutionCalculator.calculate(
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 3_000
        )

        #expect(result.syringeUnits == 120)
        #expect(result.safetyWarnings.contains { $0.contains("more than 100 U-100 units") })
    }

    @Test func reconstitutionResultWarnsForTinyDraw() throws {
        let result = try ReconstitutionCalculator.calculate(
            vialAmountMg: 10,
            bacWaterMl: 1,
            labelAmountMcg: 50
        )

        #expect(result.syringeUnits == 0.5)
        #expect(result.safetyWarnings.contains { $0.contains("very small") })
    }

    @Test func bacWaterPlannerSolvesVolumeForTargetU100Units() throws {
        let plan = try ReconstitutionCalculator.calculateBACWaterNeeded(
            vialAmountMg: 10,
            labelAmountMcg: 2_000,
            targetSyringeUnits: 40
        )

        #expect(abs(plan.bacWaterMl - 2.0) < 0.0001)
        #expect(abs(plan.targetDrawVolumeMl - 0.4) < 0.0001)
        #expect(abs(plan.concentrationMcgPerMl - 5_000) < 0.0001)
        #expect(abs(plan.concentrationMgPerMl - 5.0) < 0.0001)
    }

    @Test func bacWaterPlannerWarnsForTinyTargetDraw() throws {
        let plan = try ReconstitutionCalculator.calculateBACWaterNeeded(
            vialAmountMg: 10,
            labelAmountMcg: 50,
            targetSyringeUnits: 0.5
        )

        #expect(plan.safetyWarnings.contains { $0.contains("very small") })
    }

    @Test func reconstitutionExplanationShowsUnitConversionSteps() throws {
        let result = try ReconstitutionCalculator.calculate(
            vialAmountMg: 10,
            bacWaterMl: 2,
            labelAmountMcg: 2_000
        )
        let steps = ReconstitutionCalculator.explanationSteps(
            vialAmountMg: 10,
            bacWaterMl: 2,
            labelAmountMcg: 2_000,
            result: result
        )

        #expect(steps.count == 4)
        #expect(steps[0].detail.contains("10000 mcg"))
        #expect(steps[1].detail.contains("5000 mcg/mL"))
        #expect(steps[3].detail.contains("40.0 units"))
    }

    @Test func customPeptideTemplateRequiresUserEnteredLabelName() {
        #expect(PeptideTemplate.custom.requiresCustomName)
        #expect(PeptideTemplate.custom.resolvedName(customName: "  Custom RX Label  ") == "Custom RX Label")
        #expect(PeptideTemplate.custom.resolvedName(customName: "   ") == nil)
    }

    @Test func testingModeStatusUnlocksCoreToolsForGuestQA() {
        let status = AppFeatureFlags.testingModeStatus(
            isGuestMode: true,
            unlockFeaturesForTesting: true
        )

        #expect(status.title == "Testing Mode")
        #expect(status.badge == "Unlocked")
        #expect(status.isUnlocked)
        #expect(status.detail.contains("Core tracker tools are unlocked"))
        #expect(status.detail.contains("Sign in only when you want sync"))
    }

    @Test func testingModeStatusExplainsNormalGuestLockWhenDisabled() {
        let status = AppFeatureFlags.testingModeStatus(
            isGuestMode: true,
            unlockFeaturesForTesting: false
        )

        #expect(status.title == "Account Required")
        #expect(status.badge == "Locked")
        #expect(!status.isUnlocked)
        #expect(status.detail.contains("Sign up"))
    }

    @Test func presetPeptideTemplateIgnoresCustomLabelName() {
        let template = PeptideTemplate.popular[0]

        #expect(!template.requiresCustomName)
        #expect(template.resolvedName(customName: "Something else") == template.name)
    }

    @Test func manualWorkoutRollupCountsOnlySelectedDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let targetDay = Date(timeIntervalSince1970: 10_000)
        let sameDay = targetDay.addingTimeInterval(3_600)
        let nextDay = targetDay.addingTimeInterval(90_000)
        let logs = [
            ManualWorkoutLog(name: "Lift", completedAt: targetDay, durationMinutes: 45),
            ManualWorkoutLog(name: "Walk", completedAt: sameDay, durationMinutes: 20),
            ManualWorkoutLog(name: "Tomorrow", completedAt: nextDay, durationMinutes: 30)
        ]

        let rollup = ManualWorkoutStore.rollup(for: targetDay, from: logs, calendar: calendar)

        #expect(rollup.count == 2)
        #expect(rollup.minutes == 65)
    }

    @Test func manualWorkoutRollupDoesNotSubtractNegativeDurations() {
        let now = Date(timeIntervalSince1970: 10_000)
        let logs = [
            ManualWorkoutLog(name: "Bad import", completedAt: now, durationMinutes: -45),
            ManualWorkoutLog(name: "Real session", completedAt: now, durationMinutes: 30)
        ]

        let rollup = ManualWorkoutStore.rollup(for: now, from: logs)

        #expect(rollup.count == 2)
        #expect(rollup.minutes == 30)
    }

    @Test func gymCheckInDiagnosticLogsWhenInsideRadius() {
        let gymId = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(latitude: 35.10002, longitude: -106.6000)

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: []
        )

        #expect(diagnostic.outcome == .checkedIn)
        #expect(diagnostic.nearestGymId == gymId)
        #expect(diagnostic.shouldLogAutomaticVisit)
    }

    @Test func gymCheckInDiagnosticUsesTightAutoCheckInRadius() {
        let gymId = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 60
        )
        let location = CLLocation(latitude: 35.1011, longitude: -106.6000)

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: []
        )

        #expect(gym.effectiveCheckInRadiusMeters == GymLocation.automaticCheckInRadiusMeters)
        #expect(diagnostic.outcome == .outsideRadius)
        #expect(diagnostic.radiusMeters == GymLocation.automaticCheckInRadiusMeters)
    }

    @Test func gymCheckInDiagnosticRejectsDriveBySpeed() {
        let gym = GymLocation(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.1000, longitude: -106.6000),
            altitude: 0,
            horizontalAccuracy: 8,
            verticalAccuracy: 8,
            course: 0,
            speed: 13,
            timestamp: Date()
        )

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: []
        )

        #expect(diagnostic.outcome == .movingTooFast)
        #expect(!diagnostic.shouldLogAutomaticVisit)
        #expect(diagnostic.message.contains("Drive-bys do not count"))
    }

    @Test func gymAutoCheckInDwellPolicyWaitsBeforeFirstAutomaticReceipt() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let gym = GymLocation(
            id: UUID(uuidString: "56565656-5656-5656-5656-565656565656")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(latitude: 35.1000, longitude: -106.6000)
        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: [],
            checkedAt: now
        )

        let pending = try #require(GymAutoCheckInDwellPolicy.candidate(from: diagnostic))

        #expect(pending.gymId == gym.id)
        #expect(!GymAutoCheckInDwellPolicy.shouldLogAutomaticVisit(
            pending: pending,
            diagnostic: diagnostic,
            now: now.addingTimeInterval(30)
        ))
        #expect(GymAutoCheckInDwellPolicy.secondsRemaining(
            pending: pending,
            now: now.addingTimeInterval(30)
        ) == 60)
    }

    @Test func gymAutoCheckInDwellPolicyAllowsSameGymAfterDwellWindow() throws {
        let firstMatchAt = Date(timeIntervalSince1970: 2_000)
        let gym = GymLocation(
            id: UUID(uuidString: "78787878-7878-7878-7878-787878787878")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let firstLocation = CLLocation(latitude: 35.1000, longitude: -106.6000)
        let firstDiagnostic = GymCheckInDiagnostic.evaluate(
            location: firstLocation,
            savedGyms: [gym],
            todaysVisits: [],
            checkedAt: firstMatchAt
        )
        let pending = try #require(GymAutoCheckInDwellPolicy.candidate(from: firstDiagnostic))
        let confirmationDiagnostic = GymCheckInDiagnostic.evaluate(
            location: CLLocation(latitude: 35.10001, longitude: -106.6000),
            savedGyms: [gym],
            todaysVisits: [],
            checkedAt: firstMatchAt.addingTimeInterval(91)
        )

        #expect(GymAutoCheckInDwellPolicy.shouldLogAutomaticVisit(
            pending: pending,
            diagnostic: confirmationDiagnostic,
            now: firstMatchAt.addingTimeInterval(91)
        ))
    }

    @Test func gymAutoCheckInDwellPolicyRejectsDifferentGymConfirmation() throws {
        let firstMatchAt = Date(timeIntervalSince1970: 3_000)
        let firstGym = GymLocation(
            id: UUID(uuidString: "90909090-9090-9090-9090-909090909090")!,
            name: "Chuze Fitness West",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )
        let secondGym = GymLocation(
            id: UUID(uuidString: "91919191-9191-9191-9191-919191919191")!,
            name: "Chuze Fitness East",
            chain: "Chuze Fitness",
            latitude: 35.2000,
            longitude: -106.6000
        )
        let pendingDiagnostic = GymCheckInDiagnostic.evaluate(
            location: CLLocation(latitude: 35.1000, longitude: -106.6000),
            savedGyms: [firstGym],
            todaysVisits: [],
            checkedAt: firstMatchAt
        )
        let pending = try #require(GymAutoCheckInDwellPolicy.candidate(from: pendingDiagnostic))
        let differentGymDiagnostic = GymCheckInDiagnostic.evaluate(
            location: CLLocation(latitude: 35.2000, longitude: -106.6000),
            savedGyms: [secondGym],
            todaysVisits: [],
            checkedAt: firstMatchAt.addingTimeInterval(120)
        )

        #expect(!GymAutoCheckInDwellPolicy.shouldLogAutomaticVisit(
            pending: pending,
            diagnostic: differentGymDiagnostic,
            now: firstMatchAt.addingTimeInterval(120)
        ))
    }

    @Test func gymCheckInDiagnosticCanExplainPendingDwellConfirmation() {
        let gym = GymLocation(
            id: UUID(uuidString: "92929292-9292-9292-9292-929292929292")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )
        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: CLLocation(latitude: 35.1000, longitude: -106.6000),
            savedGyms: [gym],
            todaysVisits: []
        )

        let pendingDiagnostic = GymCheckInDiagnostic.awaitingConfirmation(
            from: diagnostic,
            secondsRemaining: 90
        )

        #expect(pendingDiagnostic.outcome == .awaitingConfirmation)
        #expect(!pendingDiagnostic.shouldLogAutomaticVisit)
        #expect(pendingDiagnostic.message.contains("Hold still"))
        #expect(pendingDiagnostic.message.contains("drive-by"))
    }

    @Test func gymCheckInDiagnosticRejectsLooseAccuracyEvenInsideRadius() {
        let gym = GymLocation(
            id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.1000, longitude: -106.6000),
            altitude: 0,
            horizontalAccuracy: GymLocation.maximumAutomaticCheckInHorizontalAccuracyMeters + 1,
            verticalAccuracy: 8,
            course: 0,
            speed: 0,
            timestamp: Date()
        )

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: []
        )

        #expect(diagnostic.outcome == .lowAccuracy)
        #expect(!diagnostic.shouldLogAutomaticVisit)
    }

    @Test func gymSearchResultsRankClosestFirst() {
        let near = GymLocation(
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            address: "Near address",
            distanceMeters: 120
        )
        let far = GymLocation(
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.2000,
            longitude: -106.6000,
            address: "Far address",
            distanceMeters: 4_000
        )
        let unknown = GymLocation(
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.3000,
            longitude: -106.6000,
            address: "Unknown address",
            distanceMeters: nil
        )

        let ranked = GymLocationService.rankedSearchResults([unknown, far, near])

        #expect(ranked.map(\.id) == [near.id, far.id, unknown.id])
    }

    @Test func gymSearchLocationSelectionRejectsStaleCachedCoordinates() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        let stale = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: now.addingTimeInterval(-120)
        )
        let current = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.0844, longitude: -106.6504),
            altitude: 0,
            horizontalAccuracy: 18,
            verticalAccuracy: 8,
            course: 0,
            speed: 0,
            timestamp: now.addingTimeInterval(-2)
        )

        let selected = try #require(
            GymLocationService.bestFreshSearchLocation(from: [stale, current], now: now)
        )

        #expect(selected.coordinate.latitude == current.coordinate.latitude)
        #expect(selected.coordinate.longitude == current.coordinate.longitude)
    }

    @Test func gymSearchLocationSelectionPrefersBestFreshAccuracy() throws {
        let now = Date(timeIntervalSince1970: 21_000)
        let loose = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.08, longitude: -106.65),
            altitude: 0,
            horizontalAccuracy: 90,
            verticalAccuracy: 10,
            course: 0,
            speed: 0,
            timestamp: now.addingTimeInterval(-1)
        )
        let precise = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.081, longitude: -106.651),
            altitude: 0,
            horizontalAccuracy: 12,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: now.addingTimeInterval(-3)
        )

        let selected = try #require(
            GymLocationService.bestFreshSearchLocation(from: [loose, precise], now: now)
        )

        #expect(selected.horizontalAccuracy == precise.horizontalAccuracy)
        #expect(selected.coordinate.latitude == precise.coordinate.latitude)
    }

    @Test func gymLocationRecordPreservesAddressForSavedGyms() {
        let gym = GymLocation(
            id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160,
            address: "123 Main St, Albuquerque, NM"
        )

        let record = GymLocationRecord(location: gym)
        let restored = record.toLocation()

        #expect(record.address == "123 Main St, Albuquerque, NM")
        #expect(restored.address == gym.address)
    }

    @Test func gymCheckInDiagnosticExplainsAlreadyLoggedGym() {
        let gymId = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(latitude: 35.10002, longitude: -106.6000)
        let visit = GymVisit(gymLocationId: gymId, gymName: gym.name, source: .geofence)

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: [visit]
        )

        #expect(diagnostic.outcome == .alreadyCheckedIn)
        #expect(!diagnostic.shouldLogAutomaticVisit)
        #expect(diagnostic.message.contains("already have a receipt"))
    }

    @Test func gymVisitReceiptPolicyBlocksSameGymDuplicateForTheDay() {
        let gymId = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )
        let firstVisit = GymVisit(
            gymLocationId: gymId,
            gymName: gym.name,
            arrivedAt: Date(timeIntervalSince1970: 10_000),
            source: .manual
        )

        let hasReceipt = GymVisitReceiptPolicy.hasReceiptToday(
            for: gym,
            visits: [firstVisit],
            now: Date(timeIntervalSince1970: 12_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(hasReceipt)
    }

    @Test func gymVisitReceiptPolicyAllowsSameGymOnDifferentDay() {
        let gymId = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )
        let yesterdayVisit = GymVisit(
            gymLocationId: gymId,
            gymName: gym.name,
            arrivedAt: Date(timeIntervalSince1970: 10_000),
            source: .geofence
        )

        let hasReceipt = GymVisitReceiptPolicy.hasReceiptToday(
            for: gym,
            visits: [yesterdayVisit],
            now: Date(timeIntervalSince1970: 100_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(!hasReceipt)
    }

    @Test func gymCheckInDiagnosticExplainsOutsideRadius() {
        let gymId = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let gym = GymLocation(
            id: gymId,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            radiusMeters: 160
        )
        let location = CLLocation(latitude: 35.1200, longitude: -106.6000)

        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: [gym],
            todaysVisits: []
        )

        #expect(diagnostic.outcome == .outsideRadius)
        #expect(diagnostic.nearestGymId == gymId)
        #expect(!diagnostic.shouldLogAutomaticVisit)
        #expect(diagnostic.message.contains("No auto check-in yet"))
    }

    @Test func gymCheckInDiagnosticExplainsRegionEntryAutoReceipt() {
        let gym = GymLocation(
            id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )

        let diagnostic = GymCheckInDiagnostic.automaticVisitResult(
            for: gym,
            didLogVisit: true,
            trigger: .regionEntry
        )

        #expect(diagnostic.outcome == .checkedIn)
        #expect(diagnostic.nearestGymId == gym.id)
        #expect(diagnostic.distanceMeters == nil)
        #expect(diagnostic.radiusMeters == gym.effectiveCheckInRadiusMeters)
        #expect(diagnostic.message == "iOS reported arrival at Chuze Fitness. Automatic check-in logged.")
    }

    @Test func gymCheckInDiagnosticExplainsCurrentLocationDuplicateReceipt() {
        let gym = GymLocation(
            id: UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000
        )

        let diagnostic = GymCheckInDiagnostic.automaticVisitResult(
            for: gym,
            didLogVisit: false,
            distanceMeters: 42,
            trigger: .currentLocation
        )

        #expect(diagnostic.outcome == .alreadyCheckedIn)
        #expect(diagnostic.distanceMeters == 42)
        #expect(diagnostic.message.contains("already have a receipt"))
    }

    @Test func voiceFoodLogParserExtractsNutritionFromNaturalSpeech() {
        let draft = VoiceFoodLogParser.parse(
            "I had Greek yogurt 150 calories 20 grams protein 18g carbs and 2 grams fat"
        )

        #expect(draft.name == "Greek yogurt")
        #expect(draft.calories == 150)
        #expect(draft.protein == 20)
        #expect(draft.carbs == 18)
        #expect(draft.fat == 2)
    }

    @Test func voiceFoodLogParserKeepsNameWhenNutritionIsMissing() {
        let draft = VoiceFoodLogParser.parse("candy bar")

        #expect(draft.name == "candy bar")
        #expect(draft.calories == nil)
        #expect(draft.protein == nil)
        #expect(draft.carbs == nil)
        #expect(draft.fat == nil)
    }

    @MainActor
    @Test func voiceTranscriptPrefillsManualFoodEntryFields() {
        let viewModel = LogFoodViewModel()

        viewModel.applyVoiceTranscript(
            "I had Greek yogurt 150 calories 20 grams protein 18 grams carbs and 2 grams fat"
        )

        #expect(viewModel.foodName == "Greek yogurt")
        #expect(viewModel.calories == 150)
        #expect(viewModel.protein == 20)
        #expect(viewModel.carbs == 18)
        #expect(viewModel.fat == 2)
        #expect(viewModel.isValidEntry)
    }

    @MainActor
    @Test func voiceTranscriptPreservesExistingNutritionWhenTranscriptOnlyHasName() {
        let viewModel = LogFoodViewModel()
        viewModel.calories = 220
        viewModel.protein = 12

        viewModel.applyVoiceTranscript("candy bar")

        #expect(viewModel.foodName == "candy bar")
        #expect(viewModel.calories == 220)
        #expect(viewModel.protein == 12)
    }

    @MainActor
    @Test func voiceTranscriptUsesAIAnalysisAndLogsFoodForToday() async throws {
        let analysis = MealAnalysis(
            totalCalories: 275,
            protein: 21,
            carbohydrates: 34,
            fat: 6,
            fiber: 4,
            confidence: 82,
            foodItems: [
                AnalyzedFood(
                    name: "Greek yogurt",
                    quantity: "1 cup",
                    calories: 150,
                    protein: 20,
                    carbohydrates: 9,
                    fat: 2
                ),
                AnalyzedFood(
                    name: "Blueberries",
                    quantity: "1/2 cup",
                    calories: 125,
                    protein: 1,
                    carbohydrates: 25,
                    fat: 4
                )
            ],
            assumptions: ["Typical serving sizes used."]
        )
        let analyzer = MockMealAnalyzer(analysis: analysis)
        let foodService = SpyFoodLoggingService()
        let viewModel = LogFoodViewModel(
            foodService: foodService,
            userService: NilCurrentUserProvider(),
            fitnessPlanService: NilFitnessPlanProvider(),
            mealAnalyzer: analyzer
        )

        await viewModel.analyzeAndLogVoiceTranscript("I had Greek yogurt with blueberries")

        #expect(analyzer.lastDescription == "I had Greek yogurt with blueberries")
        let loggedFood = try #require(foodService.addedFoods.first)
        #expect(loggedFood.name == "Greek yogurt, Blueberries")
        #expect(loggedFood.calories == 275)
        #expect(loggedFood.protein == 21)
        #expect(loggedFood.carbs == 34)
        #expect(loggedFood.fat == 6)
        #expect(loggedFood.servingSize == "1 meal")
        #expect(viewModel.showingCoachAlert)
        #expect(!viewModel.isVoiceAnalyzing)
    }

    @Test func mealTimeClassifierUsesConfiguredMealWindows() {
        let calendar = Calendar(identifier: .gregorian)

        func date(hour: Int, minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: hour, minute: minute))!
        }

        #expect(MealTimeClassifier.mealType(for: date(hour: 5, minute: 0), calendar: calendar) == .breakfast)
        #expect(MealTimeClassifier.mealType(for: date(hour: 10, minute: 59), calendar: calendar) == .breakfast)
        #expect(MealTimeClassifier.mealType(for: date(hour: 11, minute: 0), calendar: calendar) == .lunch)
        #expect(MealTimeClassifier.mealType(for: date(hour: 14, minute: 59), calendar: calendar) == .lunch)
        #expect(MealTimeClassifier.mealType(for: date(hour: 15, minute: 0), calendar: calendar) == .snack)
        #expect(MealTimeClassifier.mealType(for: date(hour: 16, minute: 0), calendar: calendar) == .dinner)
        #expect(MealTimeClassifier.mealType(for: date(hour: 20, minute: 59), calendar: calendar) == .dinner)
        #expect(MealTimeClassifier.mealType(for: date(hour: 21, minute: 0), calendar: calendar) == .snack)
    }

    @Test func mealTimeClassifierUsesExplicitMealMentionsBeforeClock() {
        let calendar = Calendar(identifier: .gregorian)
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 27, hour: 8, minute: 0))!

        #expect(MealTimeClassifier.mealType(for: morning, explicitText: "chicken bowl for dinner", calendar: calendar) == .dinner)
        #expect(MealTimeClassifier.mealType(for: morning, explicitText: "protein bar snack", calendar: calendar) == .snack)
        #expect(MealTimeClassifier.mealType(for: morning, explicitText: "eggs and toast", calendar: calendar) == .breakfast)
    }

    @MainActor
    @Test func dashboardCommandCenterShowsCalorieRemainder() {
        let viewModel = DashboardViewModel()
        viewModel.dailyGoal = 2_000
        viewModel.consumedCalories = 1_450

        #expect(viewModel.calorieBudgetDisplay == "1450/2000")
        #expect(viewModel.calorieRemainingDisplay == "550 left")

        viewModel.consumedCalories = 2_125

        #expect(viewModel.calorieBudgetDisplay == "2125/2000")
        #expect(viewModel.calorieRemainingDisplay == "125 over")
    }

    @Test func dailyMealSectionSummarizesPreviewAndHiddenReceipts() {
        let section = DailyMealSection(mealType: .lunch, foods: [
            Food(name: "Chicken bowl", calories: 520, protein: 42, carbs: 48, fat: 16),
            Food(name: "Protein shake", calories: 180, protein: 30, carbs: 8, fat: 3),
            Food(name: "Apple", calories: 95, protein: 0, carbs: 25, fat: 0),
            Food(name: "Pretzels", calories: 240, protein: 5, carbs: 48, fat: 2)
        ])

        #expect(section.itemCount == 4)
        #expect(section.totalCalories == 1_035)
        #expect(section.foodPreviewText() == "Chicken bowl, Protein shake, Apple")
        #expect(section.remainingItemCount() == 1)
        #expect(section.macroSummaryText == "P 77g | C 129g | F 21g")
    }

    @Test func accountabilityDayWindowResetsAtNextMidnight() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 22, minute: 15)))
        let expectedReset = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 0, minute: 0)))

        let window = AccountabilityDayWindow.make(now: now, calendar: calendar)

        #expect(window.start == calendar.startOfDay(for: now))
        #expect(window.nextReset == expectedReset)
        #expect(AccountabilityDayWindow.countdownDisplay(now: now, calendar: calendar) == "Resets in 1h 45m")
    }

    @MainActor
    @Test func dashboardResetSubtitleExplainsWhatRollsOver() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 22, minute: 15)))
        let viewModel = DashboardViewModel()

        let subtitle = viewModel.mealResetSubtitle(now: now, calendar: calendar)

        #expect(subtitle.contains("Resets in 1h 45m"))
        #expect(subtitle.contains("Calories, meals, steps, and gym receipts start over at midnight"))
    }

    @Test func emptyActivitySummaryUsesStartOfAccountabilityDay() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 18, minute: 30)))

        let summary = ActivityDailySummary.empty(on: now, stepGoal: 12_000, calendar: calendar)

        #expect(summary.date == calendar.startOfDay(for: now))
        #expect(summary.stepGoal == 12_000)
        #expect(summary.steps == 0)
        #expect(summary.gymVisits.isEmpty)
    }

    @MainActor
    @Test func dashboardNextActionPrioritizesIncompleteSetup() {
        let viewModel = DashboardViewModel()

        #expect(viewModel.shouldShowSetupChecklist)
        #expect(viewModel.dashboardNextAction.kind == .buildPlan)

        viewModel.currentPlan = testFitnessPlan()
        #expect(viewModel.shouldShowSetupChecklist)
        #expect(viewModel.dashboardNextAction.kind == .connectActivity)

        viewModel.hasRequestedHealthAccess = true
        #expect(viewModel.shouldShowSetupChecklist)
        #expect(viewModel.dashboardNextAction.kind == .saveGym)
    }

    @MainActor
    @Test func dashboardNextActionMovesToMealLoggingAfterSetup() {
        let viewModel = DashboardViewModel()
        viewModel.currentPlan = testFitnessPlan()
        viewModel.hasRequestedHealthAccess = true
        viewModel.savedGymCount = 1
        viewModel.mealSections = [
            DailyMealSection(mealType: .breakfast, foods: [
                Food(name: "Eggs", calories: 220, dateLogged: Date(), mealType: .breakfast)
            ]),
            DailyMealSection(mealType: .lunch, foods: []),
            DailyMealSection(mealType: .dinner, foods: []),
            DailyMealSection(mealType: .snack, foods: [])
        ]

        #expect(!viewModel.shouldShowSetupChecklist)
        #expect(viewModel.missingMealSummary == "Missing Lunch, Dinner")
        #expect(viewModel.dashboardNextAction.kind == .logFood)
        #expect(viewModel.dashboardNextAction.detail.contains("Missing Lunch, Dinner"))
        #expect(!viewModel.trainerBriefingBody.localizedCaseInsensitiveContains("peptide"))
    }

    @MainActor
    @Test func profileSettingsSummaryShowsMissingSetupClearly() {
        let viewModel = ProfileViewModel()
        viewModel.currentPlan = nil
        viewModel.healthAccessRequested = false
        viewModel.savedGymCount = 0
        viewModel.peptideSummary = PeptideTrackerSummary.make(logs: [])

        #expect(viewModel.planStatusDisplay == "Missing")
        #expect(viewModel.healthStatusDisplay == "Off")
        #expect(viewModel.gymStatusDisplay == "None")
        #expect(viewModel.peptideStatusDisplay == "Ready")
        #expect(viewModel.mealPlanSettingsDetail.contains("No active plan"))
        #expect(viewModel.activitySettingsDetail.contains("Connect Health"))
        #expect(viewModel.peptideSettingsDetail.contains("BAC water planner"))
    }

    @MainActor
    @Test func profileSettingsSummaryUsesConfiguredPlanActivityAndPeptideLogs() {
        let viewModel = ProfileViewModel()
        let plan = testFitnessPlan()
        let nextPeptide = PeptideLog(
            peptideName: "Semaglutide",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            scheduledAt: Date(timeIntervalSince1970: 4_000)
        )

        viewModel.currentPlan = plan
        viewModel.healthAccessRequested = true
        viewModel.savedGymCount = 2
        viewModel.peptideSummary = PeptideTrackerSummary.make(
            logs: [nextPeptide],
            now: Date(timeIntervalSince1970: 1_000)
        )

        #expect(viewModel.planStatusDisplay == "2000 cal")
        #expect(viewModel.healthStatusDisplay == "Linked")
        #expect(viewModel.gymStatusDisplay == "2 saved")
        #expect(viewModel.peptideStatusDisplay == "1 planned")
        #expect(viewModel.mealPlanSettingsDetail.contains("150g protein"))
        #expect(viewModel.mealPlanSettingsDetail.contains("10000 steps"))
        #expect(viewModel.activitySettingsDetail.contains("2 saved gyms"))
        #expect(viewModel.peptideSettingsDetail.contains("Next planned: Semaglutide"))
    }

    @MainActor
    @Test func manualFoodLogPassesSelectedMealTypeToFoodService() async throws {
        let foodService = SpyFoodLoggingService()
        let viewModel = LogFoodViewModel(
            foodService: foodService,
            userService: NilCurrentUserProvider(),
            fitnessPlanService: NilFitnessPlanProvider()
        )
        viewModel.foodName = "Turkey wrap"
        viewModel.calories = 430
        viewModel.selectedMealType = .lunch

        await viewModel.addFood()

        #expect(foodService.addedFoods.first?.name == "Turkey wrap")
        #expect(foodService.addedMealTypes.first == .lunch)
        #expect(viewModel.showingCoachAlert)
    }

    @MainActor
    @Test func voiceFoodLogUsesMentionedMealType() async throws {
        let analyzer = MockMealAnalyzer(analysis: MealAnalysis(
            totalCalories: 520,
            protein: 42,
            carbohydrates: 48,
            fat: 16,
            fiber: 8,
            confidence: 82,
            foodItems: [
                AnalyzedFood(
                    name: "Chicken bowl",
                    quantity: "1 bowl",
                    calories: 520,
                    protein: 42,
                    carbohydrates: 48,
                    fat: 16
                )
            ],
            assumptions: []
        ))
        let foodService = SpyFoodLoggingService()
        let viewModel = LogFoodViewModel(
            foodService: foodService,
            userService: NilCurrentUserProvider(),
            fitnessPlanService: NilFitnessPlanProvider(),
            mealAnalyzer: analyzer
        )

        await viewModel.analyzeAndLogVoiceTranscript("I had a chicken bowl for dinner")

        #expect(foodService.addedFoods.first?.name == "Chicken bowl")
        #expect(foodService.addedMealTypes.first == .dinner)
    }

    @MainActor
    @Test func voiceTranscriptKeepsManualFallbackWhenAIAnalysisFails() async {
        let analyzer = MockMealAnalyzer(error: OpenAIError.invalidAPIKey)
        let foodService = SpyFoodLoggingService()
        let viewModel = LogFoodViewModel(
            foodService: foodService,
            userService: NilCurrentUserProvider(),
            fitnessPlanService: NilFitnessPlanProvider(),
            mealAnalyzer: analyzer
        )

        await viewModel.analyzeAndLogVoiceTranscript("candy bar 250 calories")

        #expect(foodService.addedFoods.isEmpty)
        #expect(viewModel.foodName == "candy bar")
        #expect(viewModel.calories == 250)
        #expect(viewModel.showingVoiceError)
        #expect(viewModel.voiceErrorMessage.contains("AI could not estimate"))
        #expect(!viewModel.isVoiceAnalyzing)
    }

    @Test func voicePermissionProblemsOfferSettingsRecovery() {
        #expect(VoiceLogProblem.microphoneDenied.shouldOfferSettings)
        #expect(VoiceLogProblem.speechDenied.shouldOfferSettings)
        #expect(VoiceLogProblem.speechUnknown.shouldOfferSettings)
        #expect(VoiceLogProblem.microphoneDenied.message.contains("Open iOS Settings"))
    }

    @Test func voiceRuntimeProblemsDoNotSendUsersToSettings() {
        #expect(!VoiceLogProblem.noTranscript.shouldOfferSettings)
        #expect(!VoiceLogProblem.microphoneStartFailed.shouldOfferSettings)
        #expect(!VoiceLogProblem.speechUnavailable.shouldOfferSettings)
    }

    @Test func voicePermissionPreflightMapsDeniedSpeechToSettingsRecovery() {
        let problem = VoicePermissionPreflight.speechProblem(for: .denied)

        #expect(problem == .speechDenied)
        #expect(problem?.shouldOfferSettings == true)
    }

    @Test func voicePermissionPreflightAllowsAuthorizedSpeech() {
        #expect(VoicePermissionPreflight.speechProblem(for: .authorized) == nil)
    }

    @Test func voicePermissionPreflightMapsDeniedMicrophoneToSettingsRecovery() {
        let problem = VoicePermissionPreflight.microphoneProblem(for: .denied)

        #expect(problem == .microphoneDenied)
        #expect(problem?.shouldOfferSettings == true)
    }

    @Test func voicePermissionPreflightAllowsGrantedMicrophone() {
        #expect(VoicePermissionPreflight.microphoneProblem(for: .granted) == nil)
    }

    @Test func peptideLogDecodesLegacyLocalDesiredDoseKey() throws {
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "peptideName": "Semaglutide",
          "vialAmountMg": 5,
          "bacWaterMl": 2,
          "desiredDoseMcg": 250,
          "drawVolumeMl": 0.1,
          "syringeUnits": 10,
          "notes": "legacy local log",
          "loggedAt": 0
        }
        """

        let log = try JSONDecoder().decode(PeptideLog.self, from: Data(legacyJSON.utf8))

        #expect(log.labelAmountMcg == 250)
        #expect(log.status == .logged)
        #expect(log.site.isEmpty)
        #expect(log.scheduledAt == nil)
        #expect(log.notes == "legacy local log")
    }

    @Test func peptideLogRecordPreservesTrackerFields() {
        let scheduledAt = Date(timeIntervalSince1970: 1_800)
        let loggedAt = Date(timeIntervalSince1970: 1_700)
        let log = PeptideLog(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            peptideName: "Tirzepatide",
            status: .planned,
            vialAmountMg: 10,
            bacWaterMl: 2,
            labelAmountMcg: 500,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            site: "left side",
            notes: "label math only",
            loggedAt: loggedAt,
            scheduledAt: scheduledAt
        )

        let record = PeptideLogRecord(log: log)
        let decoded = record.toLog()

        #expect(record.status == "planned")
        #expect(record.site == "left side")
        #expect(record.scheduled_at == scheduledAt)
        #expect(decoded.status == .planned)
        #expect(decoded.site == "left side")
        #expect(decoded.scheduledAt == scheduledAt)
    }

    @Test func notificationSettingsDecodeLegacyValuesWithPeptideRemindersOn() throws {
        let legacyJSON = """
        {
          "dailyWorkoutReminder": true,
          "mealReminders": false,
          "weeklyReports": true,
          "breakfastTime": { "hour": 8, "minute": 0 },
          "lunchTime": { "hour": 12, "minute": 30 },
          "dinnerTime": { "hour": 18, "minute": 30 },
          "workoutTime": { "hour": 18, "minute": 0 },
          "weeklyReportTime": { "hour": 8, "minute": 30, "weekday": 2 }
        }
        """

        let settings = try JSONDecoder().decode(CoachNotificationSettings.self, from: Data(legacyJSON.utf8))

        #expect(settings.peptideReminders)
    }

    @Test func defaultNotificationSettingsEnableMealAccountability() {
        #expect(CoachNotificationSettings.defaults.mealReminders)
    }

    @Test func movementReminderPlannerUsesFortyMinuteToughLoveCadence() {
        let now = Date(timeIntervalSince1970: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let settings = CoachNotificationSettings.defaults
        let toneSettings = CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 3,
            allowExplicitBodyShame: true
        )

        let items = CoachNotificationPlanner.movementReminderItems(
            settings: settings,
            toneSettings: toneSettings,
            now: now,
            calendar: calendar
        )

        #expect(items.first?.id == "coach.movement.0")
        #expect(items.first?.components.minute == 40)
        #expect(items.first?.body.contains("Get your butt moving") == true)
        #expect(items.allSatisfy { !$0.repeats })
    }

    @Test func movementReminderPlannerAnchorsToLastStepMovement() {
        let now = Date(timeIntervalSince1970: 60 * 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let settings = CoachNotificationSettings.defaults
        let toneSettings = CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 3,
            allowExplicitBodyShame: true
        )

        let items = CoachNotificationPlanner.movementReminderItems(
            settings: settings,
            toneSettings: toneSettings,
            lastMovementAt: Date(timeIntervalSince1970: 0),
            now: now,
            calendar: calendar
        )

        #expect(items.first?.components.hour == 0)
        #expect(items.first?.components.minute == 40)
    }

    @Test func staleMovementReminderPlannerSchedulesNearTermNudge() throws {
        let now = Date(timeIntervalSince1970: 60 * 50)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let settings = CoachNotificationSettings.defaults
        let toneSettings = CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 3,
            allowExplicitBodyShame: true
        )

        let items = CoachNotificationPlanner.movementReminderItems(
            settings: settings,
            toneSettings: toneSettings,
            lastMovementAt: Date(timeIntervalSince1970: 0),
            now: now,
            calendar: calendar
        )

        let first = try #require(items.first)
        let fireDate = try #require(calendar.date(from: first.components))
        #expect(fireDate.timeIntervalSince(now) <= 120)
    }

    @Test func mealReminderPlannerSkipsMealsAlreadyLoggedToday() {
        let now = Date(timeIntervalSince1970: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let settings = CoachNotificationSettings.defaults
        let toneSettings = CoachToneSettings.defaultFullRoast

        let items = CoachNotificationPlanner.mealReminderItems(
            loggedMealTypes: [.breakfast],
            settings: settings,
            toneSettings: toneSettings,
            now: now,
            calendar: calendar
        )

        #expect(!items.contains { $0.id == CoachNotificationPlanner.breakfast })
        #expect(items.contains { $0.id == CoachNotificationPlanner.lunch })
        #expect(items.contains { $0.id == CoachNotificationPlanner.dinner })
    }

    @Test func activityAccountabilityPlannerAddsStepAndGymReceiptsWhenBehind() {
        let now = Date(timeIntervalSince1970: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let settings = CoachNotificationSettings.defaults
        let toneSettings = CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 23,
            allowExplicitBodyShame: true
        )
        let summary = ActivityDailySummary(
            date: now,
            steps: 2_000,
            stepGoal: 10_000,
            activeEnergyCalories: 50,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: []
        )

        let items = CoachNotificationPlanner.activityAccountabilityItems(
            summary: summary,
            settings: settings,
            toneSettings: toneSettings,
            now: now,
            calendar: calendar
        )

        #expect(items.contains { $0.id == CoachNotificationPlanner.stepGoal })
        #expect(items.contains { $0.id == CoachNotificationPlanner.gymCheckIn })
        #expect(items.first { $0.id == CoachNotificationPlanner.gymCheckIn }?.body.contains("No gym check-in") == true)
    }

    @Test func gymCheckInReceiptCopyUsesToughLoveTone() {
        let copy = CoachNotificationPlanner.gymCheckInReceiptCopy(
            gymName: "Chuze Fitness",
            toneSettings: CoachToneSettings.defaultFullRoast
        )

        #expect(copy.title == "Gym Receipt Captured")
        #expect(copy.body.contains("Caught you at Chuze Fitness"))
        #expect(copy.body.contains("parking-lot achievement"))
    }

    @Test func stepMovementTrackerTreatsNewDayStepCountAsFreshMovement() {
        let yesterday = Date(timeIntervalSince1970: 86_400)
        let today = Date(timeIntervalSince1970: 86_400 * 2)
        let now = today.addingTimeInterval(60 * 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousMovementAt = yesterday.addingTimeInterval(60 * 60 * 12)
        let summary = ActivityDailySummary(
            date: today,
            steps: 125,
            stepGoal: 10_000,
            activeEnergyCalories: 5,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: []
        )

        let snapshot = StepMovementTracker.updatedSnapshot(
            for: summary,
            previous: StepMovementSnapshot(
                lastStepCount: 6_000,
                lastStepCountDate: yesterday,
                lastMovementAt: previousMovementAt
            ),
            now: now,
            calendar: calendar
        )

        #expect(snapshot.lastStepCount == 125)
        #expect(snapshot.lastStepCountDate == today)
        #expect(snapshot.lastMovementAt == now)
    }

    @Test func stepMovementTrackerDoesNotMoveWhenSameDayStepCountIsUnchanged() {
        let today = Date(timeIntervalSince1970: 86_400)
        let now = today.addingTimeInterval(60 * 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousMovementAt = today.addingTimeInterval(60 * 5)
        let summary = ActivityDailySummary(
            date: today,
            steps: 1_500,
            stepGoal: 10_000,
            activeEnergyCalories: 25,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: []
        )

        let snapshot = StepMovementTracker.updatedSnapshot(
            for: summary,
            previous: StepMovementSnapshot(
                lastStepCount: 1_500,
                lastStepCountDate: today,
                lastMovementAt: previousMovementAt
            ),
            now: now,
            calendar: calendar
        )

        #expect(snapshot.lastStepCount == 1_500)
        #expect(snapshot.lastMovementAt == previousMovementAt)
    }

    @Test func stepMovementTrackerMovesWhenSameDayStepsIncrease() {
        let today = Date(timeIntervalSince1970: 86_400)
        let now = today.addingTimeInterval(60 * 45)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousMovementAt = today.addingTimeInterval(60 * 5)
        let summary = ActivityDailySummary(
            date: today,
            steps: 1_525,
            stepGoal: 10_000,
            activeEnergyCalories: 25,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: []
        )

        let snapshot = StepMovementTracker.updatedSnapshot(
            for: summary,
            previous: StepMovementSnapshot(
                lastStepCount: 1_500,
                lastStepCountDate: today,
                lastMovementAt: previousMovementAt
            ),
            now: now,
            calendar: calendar
        )

        #expect(snapshot.lastStepCount == 1_525)
        #expect(snapshot.lastMovementAt == now)
    }

    @Test func healthRefreshProblemMessageListsFailedReadTypes() {
        let message = HealthKitService.refreshProblemMessage(for: ["steps", "workouts", "steps"])

        #expect(message?.contains("steps") == true)
        #expect(message?.contains("workouts") == true)
        #expect(message?.contains("My Fatness Tracker") == true)
    }

    @Test func healthRefreshProblemMessageIsNilWhenReadsSucceed() {
        #expect(HealthKitService.refreshProblemMessage(for: []) == nil)
    }

    @MainActor
    @Test func pendingPeptideRemindersOnlyIncludeFuturePlannedLogs() {
        let now = Date(timeIntervalSince1970: 10_000)
        let future = now.addingTimeInterval(3_600)
        let later = now.addingTimeInterval(7_200)
        let past = now.addingTimeInterval(-3_600)

        let futurePlanned = PeptideLog(
            peptideName: "Semaglutide",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            scheduledAt: future
        )
        let laterPlanned = PeptideLog(
            peptideName: "Tirzepatide",
            status: .planned,
            vialAmountMg: 10,
            bacWaterMl: 2,
            labelAmountMcg: 500,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            scheduledAt: later
        )
        let pastPlanned = PeptideLog(
            peptideName: "Past",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            scheduledAt: past
        )
        let logged = PeptideLog(
            peptideName: "Logged",
            status: .logged,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            scheduledAt: future
        )

        let pending = PeptideLogStore.pendingReminderLogs(
            from: [laterPlanned, pastPlanned, logged, futurePlanned],
            now: now
        )

        #expect(pending.map(\.id) == [futurePlanned.id, laterPlanned.id])
    }

    @MainActor
    @Test func replacingPeptideLogKeepsSameEntryAndSortsByLoggedDate() {
        let olderDate = Date(timeIntervalSince1970: 1_000)
        let newerDate = Date(timeIntervalSince1970: 2_000)
        let planned = PeptideLog(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            peptideName: "Semaglutide",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: olderDate,
            scheduledAt: newerDate
        )
        let existing = PeptideLog(
            peptideName: "Tirzepatide",
            status: .logged,
            vialAmountMg: 10,
            bacWaterMl: 2,
            labelAmountMcg: 500,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: olderDate.addingTimeInterval(100)
        )
        var logged = planned
        logged.status = .logged
        logged.loggedAt = newerDate
        logged.scheduledAt = nil

        let logs = PeptideLogStore.replacing(logged, in: [planned, existing])

        #expect(logs.count == 2)
        #expect(logs.first?.id == planned.id)
        #expect(logs.first?.status == .logged)
        #expect(logs.first?.scheduledAt == nil)
        #expect(logs.filter { $0.id == planned.id }.count == 1)
    }

    @Test func peptideTrackerSummarySeparatesUpcomingAndOverdueLogs() {
        let now = Date(timeIntervalSince1970: 10_000)
        let overdue = PeptideLog(
            peptideName: "Overdue",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(-3_600),
            scheduledAt: now.addingTimeInterval(-3_600)
        )
        let next = PeptideLog(
            peptideName: "Next",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(3_600),
            scheduledAt: now.addingTimeInterval(3_600)
        )
        let later = PeptideLog(
            peptideName: "Later",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(7_200),
            scheduledAt: now.addingTimeInterval(7_200)
        )
        let logged = PeptideLog(
            peptideName: "Logged",
            status: .logged,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(-1_000)
        )

        let summary = PeptideTrackerSummary.make(logs: [later, overdue, logged, next], now: now)

        #expect(summary.loggedCount == 1)
        #expect(summary.plannedCount == 3)
        #expect(summary.overdueCount == 1)
        #expect(summary.nextPlanned?.peptideName == "Next")
        #expect(summary.lastLogged?.peptideName == "Logged")
    }

    @Test func peptideLogListFilterReturnsActionableOverdueLogs() {
        let now = Date(timeIntervalSince1970: 20_000)
        let overdue = PeptideLog(
            peptideName: "Overdue",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(-7_200),
            scheduledAt: now.addingTimeInterval(-7_200)
        )
        let upcoming = PeptideLog(
            peptideName: "Upcoming",
            status: .planned,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(3_600),
            scheduledAt: now.addingTimeInterval(3_600)
        )
        let logged = PeptideLog(
            peptideName: "Logged",
            status: .logged,
            vialAmountMg: 5,
            bacWaterMl: 2,
            labelAmountMcg: 250,
            drawVolumeMl: 0.1,
            syringeUnits: 10,
            loggedAt: now.addingTimeInterval(-100)
        )

        let overdueLogs = PeptideLogListFilter.overdue.logs(from: [upcoming, logged, overdue], now: now)
        let plannedLogs = PeptideLogListFilter.planned.logs(from: [upcoming, logged, overdue], now: now)

        #expect(overdueLogs.map(\.peptideName) == ["Overdue"])
        #expect(plannedLogs.map(\.peptideName) == ["Overdue", "Upcoming"])
    }

    @MainActor
    @Test func peptideTrackerCanBeEmbeddedWithoutNestedNavigation() {
        let tabView = PeptideTrackerView()
        let pushedView = PeptideTrackerView(embedsInNavigation: false)

        #expect(tabView.embedsInNavigation)
        #expect(!pushedView.embedsInNavigation)
        #expect(!tabView.showsCloseButton)
        #expect(pushedView.showsCloseButton)
    }

    @MainActor
    @Test func coachToneSettingsCanRemoveBodyShamingCopy() {
        let service = CoachMessageService.shared
        let originalSettings = service.settings
        defer { service.updateSettings(originalSettings) }

        service.updateSettings(CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 23,
            allowExplicitBodyShame: false
        ))

        let message = service.dashboardMessage(
            consumedCalories: 2_400,
            dailyGoal: 2_000,
            protein: 40,
            proteinGoal: 150
        )

        #expect(message.title == "Calorie Alert")
        #expect(!message.title.localizedCaseInsensitiveContains("fatness"))
    }

    @MainActor
    @Test func coachToneSettingsStillAllowFullRoastWhenEnabled() {
        let service = CoachMessageService.shared
        let originalSettings = service.settings
        defer { service.updateSettings(originalSettings) }

        service.updateSettings(CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 23,
            allowExplicitBodyShame: true
        ))

        let message = service.dashboardMessage(
            consumedCalories: 2_400,
            dailyGoal: 2_000,
            protein: 40,
            proteinGoal: 150
        )

        #expect(message.title == "Fatness Alert")
    }

    @MainActor
    @Test func workoutReminderUsesCompletedActivityContext() {
        let service = CoachMessageService.shared
        let originalSettings = service.settings
        defer { service.updateSettings(originalSettings) }

        service.updateSettings(CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 23,
            allowExplicitBodyShame: true
        ))

        let summary = ActivityDailySummary(
            date: Date(),
            steps: 12_000,
            stepGoal: 10_000,
            activeEnergyCalories: 350,
            exerciseMinutes: 45,
            workoutCount: 1,
            gymVisits: []
        )

        let message = service.workoutReminderMessage(summary: summary, plan: nil)

        #expect(message.title == "Fine, You Did It")
        #expect(message.severity == .praise)
    }

    @MainActor
    @Test func foodLoggedMessageUsesPlanMacroOverage() {
        let service = CoachMessageService.shared
        let originalSettings = service.settings
        defer { service.updateSettings(originalSettings) }

        service.updateSettings(CoachToneSettings(
            enabled: true,
            severity: .fullRoast,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 24,
            allowExplicitBodyShame: true
        ))

        let food = Food(name: "Candy bar", calories: 350, protein: 3, carbs: 45, fat: 18)
        let message = service.foodLoggedMessage(
            food: food,
            progress: DailyNutritionProgress(calories: 2_125, protein: 80, carbs: 210, fat: 70),
            plan: testFitnessPlan(),
            fallbackDailyGoal: 2_000
        )

        #expect(message.title == "Macro Collision")
        #expect(message.body.localizedCaseInsensitiveContains("125 calories over"))
        #expect(message.severity == .roast)
    }

    @MainActor
    @Test func glpSupportPlanUsesSmallerProteinForwardMeals() {
        let user = User(
            name: "Plan Test",
            age: 38,
            weight: 210,
            height: 70,
            activityLevel: .lightlyActive,
            goalType: .loseWeight,
            dailyCalorieGoal: 1_900,
            weightUnit: .lb,
            heightUnit: .inch,
            weeklyWeightChange: -1,
            gender: .female
        )

        let plan = FitnessPlanService.shared.generatePlan(
            for: user,
            trainingDaysPerWeek: 4,
            mealStyle: .glpSupport
        )

        #expect(plan.meals.count == 3)
        #expect(plan.meals.allSatisfy { $0.meals.count == 5 })
        #expect(plan.meals.flatMap(\.meals).contains { $0.notes.localizedCaseInsensitiveContains("clinician") })
        #expect(plan.coachNote.localizedCaseInsensitiveContains("GLP-support"))
    }

    @MainActor
    @Test func generatedWorkoutPlanIncludesCompletionAndProgressionTargets() {
        let user = User(
            name: "Workout Plan Test",
            age: 34,
            weight: 205,
            height: 70,
            activityLevel: .lightlyActive,
            goalType: .loseWeight,
            dailyCalorieGoal: 2_000,
            weightUnit: .lb,
            heightUnit: .inch,
            weeklyWeightChange: -1,
            gender: .male
        )

        let plan = FitnessPlanService.shared.generatePlan(
            for: user,
            trainingDaysPerWeek: 4,
            mealStyle: .balanced
        )

        #expect(plan.workouts.count == 4)
        #expect(plan.workouts.allSatisfy { !($0.completionTarget ?? "").isEmpty })
        #expect(plan.workouts.allSatisfy { !($0.progression ?? "").isEmpty })
        #expect(plan.workouts.first?.completionTarget?.localizedCaseInsensitiveContains("Log the workout") == true)
    }

    @MainActor
    @Test func nutritionTargetsUseProfileWeightGoalAndCalorieBudget() {
        let user = User(
            name: "Macro Test",
            age: 40,
            weight: 200,
            height: 70,
            activityLevel: .moderatelyActive,
            goalType: .loseWeight,
            dailyCalorieGoal: 2_100,
            weightUnit: .lb,
            heightUnit: .inch,
            weeklyWeightChange: -1,
            gender: .male
        )

        let targets = FitnessPlanService.nutritionTargets(for: user)

        #expect(targets.calories == 2_100)
        #expect(targets.protein == 180)
        #expect(targets.fat >= 45)
        #expect(targets.carbs >= 75)
        #expect(abs((targets.protein * 4) + (targets.carbs * 4) + (targets.fat * 9) - targets.calories) < 10)
    }

    @Test func nutritionMetricProgressCapsRingAndReportsGoalState() {
        let underGoal = NutritionMetricProgress(consumed: 90, target: 150)
        let overGoal = NutritionMetricProgress(consumed: 175, target: 150)

        #expect(abs(underGoal.fraction - 0.6) < 0.001)
        #expect(underGoal.remaining == 60)
        #expect(!underGoal.hasReachedGoal)
        #expect(overGoal.fraction == 1)
        #expect(overGoal.remaining == 0)
        #expect(overGoal.hasReachedGoal)
    }

    @MainActor
    @Test func calorieTargetsUseGenderWhenBodyFatIsUnavailable() {
        let male = User(
            name: "Male",
            age: 40,
            weight: 180,
            height: 70,
            activityLevel: .lightlyActive,
            goalType: .maintainWeight,
            weightUnit: .lb,
            heightUnit: .inch,
            gender: .male
        )
        var female = male
        female.name = "Female"
        female.gender = .female

        let maleGoal = UserService.shared.calculateDailyCalorieGoal(for: male)
        let femaleGoal = UserService.shared.calculateDailyCalorieGoal(for: female)

        #expect(maleGoal > femaleGoal)
    }

    @MainActor
    @Test func foodLoggedMessageCallsOutProteinGapAgainstPlan() {
        let service = CoachMessageService.shared
        let originalSettings = service.settings
        defer { service.updateSettings(originalSettings) }

        service.updateSettings(CoachToneSettings(
            enabled: true,
            severity: .spicy,
            foodRoastThresholdPercent: 75,
            activeStartHour: 0,
            activeEndHour: 24,
            allowExplicitBodyShame: true
        ))

        let food = Food(name: "Pretzels", calories: 240, protein: 5, carbs: 48, fat: 2)
        let message = service.foodLoggedMessage(
            food: food,
            progress: DailyNutritionProgress(calories: 1_350, protein: 45, carbs: 170, fat: 42),
            plan: testFitnessPlan(),
            fallbackDailyGoal: 2_000
        )

        #expect(message.title == "Where Is The Protein?")
        #expect(message.severity == .warning)
    }

    @Test func overdueMovementReminderSchedulesPromptToughLoveNudge() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 14, minute: 0)))
        let lastMovement = now.addingTimeInterval(-41 * 60)

        let items = CoachNotificationPlanner.movementReminderItems(
            settings: .defaults,
            toneSettings: .defaultFullRoast,
            lastMovementAt: lastMovement,
            now: now,
            calendar: calendar
        )

        let first = try #require(items.first)
        let fireDate = try #require(calendar.date(from: first.components))
        #expect(fireDate.timeIntervalSince(now) <= 120)
        #expect(first.title == "Get Moving")
        #expect(first.body.contains("Get your butt moving"))
        #expect(first.body.contains("Take yourself for a walk"))
    }

    @Test func movementRemindersStopOutsideActiveHours() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 22, minute: 5)))

        let items = CoachNotificationPlanner.movementReminderItems(
            settings: .defaults,
            toneSettings: .defaultFullRoast,
            lastMovementAt: now.addingTimeInterval(-2_500),
            now: now,
            calendar: calendar
        )

        #expect(items.isEmpty)
    }

    @Test func pushUpPoseAnalyzerCountsOneStrictFullRep() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 1_000)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        _ = analyzer.process(sample: frontPushUpPoseSample(position: .down, at: start.addingTimeInterval(0.4)))
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(1.4)))

        #expect(result.validRepCount == 1)
        #expect(result.rejectedRepCount == 0)
        #expect(result.didCountRep)
        #expect(result.pointsAwarded == 10)
        #expect(result.quality == .goodRep)
    }

    @Test func friendshipResolvesTheOtherUserForEitherParticipant() {
        let requester = UUID()
        let addressee = UUID()
        let friendship = Friendship(
            id: UUID(),
            requester_id: requester,
            addressee_id: addressee,
            status: .accepted,
            created_at: Date(),
            updated_at: Date()
        )

        #expect(friendship.otherUserId(for: requester) == addressee)
        #expect(friendship.otherUserId(for: addressee) == requester)
    }

    @Test func fitnessChallengeTracksOpponentAndWinner() {
        let challenger = UUID()
        let challenged = UUID()
        let challenge = FitnessChallenge(
            id: UUID(),
            challenger_id: challenger,
            challenged_id: challenged,
            challenge_type: .pushUp,
            challenger_session_id: UUID(),
            challenged_session_id: UUID(),
            challenger_rep_count: 12,
            challenged_rep_count: 13,
            target_rep_count: 13,
            winner_id: challenged,
            status: .completed,
            created_at: Date(),
            updated_at: Date(),
            completed_at: Date()
        )

        #expect(challenge.opponentId(for: challenger) == challenged)
        #expect(challenge.opponentId(for: challenged) == challenger)
        #expect(challenge.resultText(for: challenger) == "Loss")
        #expect(challenge.resultText(for: challenged) == "Win")
    }

    @Test func plankCompetitionUsesVerifiedWholeSecondsInsteadOfReps() {
        let started = Date(timeIntervalSince1970: 5_000)
        let session = MovementChallengeSession(
            challengeType: .plank,
            startedAt: started,
            endedAt: started.addingTimeInterval(43.9),
            durationSeconds: 43.9,
            validRepCount: 0,
            rejectedRepCount: 1
        )

        #expect(session.competitionScore == 43)
        #expect(session.competitionScoreDisplay == "0:43")
        #expect(session.competitionTargetScore == 44)
        #expect(session.competitionTargetDisplay == "0:44")
    }

    @Test func plankChallengeDisplaysTimeBasedScoresAcrossSocialSurfaces() {
        let challenger = UUID()
        let challenged = UUID()
        let challenge = FitnessChallenge(
            id: UUID(),
            challenger_id: challenger,
            challenged_id: challenged,
            challenge_type: .plank,
            challenger_session_id: UUID(),
            challenged_session_id: nil,
            challenger_rep_count: 42,
            challenged_rep_count: nil,
            target_rep_count: 43,
            winner_id: nil,
            status: .pending,
            created_at: Date(),
            updated_at: Date(),
            completed_at: nil
        )

        #expect(challenge.isTimedHold)
        #expect(challenge.challengerScoreDisplay == "0:42")
        #expect(challenge.targetScoreDisplay == "0:43")
        #expect(challenge.competitionMetricLabel == "hold")
    }

    @Test func friendStandingReportsWhoLeads() {
        let friend = SocialProfile(
            user_id: UUID(),
            display_name: "Marcus",
            friend_code: "AB12CD34"
        )

        let myLead = FriendStanding(friend: friend, myWins: 3, friendWins: 1, openChallenges: 1)
        let theirLead = FriendStanding(friend: friend, myWins: 2, friendWins: 4, openChallenges: 0)
        let tied = FriendStanding(friend: friend, myWins: 2, friendWins: 2, openChallenges: 0)

        #expect(myLead.leadText == "You lead 3-1")
        #expect(theirLead.leadText == "Marcus leads 4-2")
        #expect(tied.leadText == "Tied 2-2")
    }

    @Test func fitnessChallengeInsertUsesVerifiedSessionContract() throws {
        let challenger = UUID()
        let challenged = UUID()
        let session = UUID()
        let insert = FitnessChallengeInsert(
            challenger_id: challenger,
            challenged_id: challenged,
            challenge_type: .squat,
            challenger_session_id: session
        )

        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(insert)) as? [String: String])
        #expect(object["challenger_id"] == challenger.uuidString)
        #expect(object["challenged_id"] == challenged.uuidString)
        #expect(object["challenge_type"] == "squat")
        #expect(object["challenger_session_id"] == session.uuidString)
        #expect(object["challenger_rep_count"] == nil)
    }

    @Test func movementCalibrationRequiresThreeSecondsOfAValidPose() throws {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 900)

        calibrator.process(
            sample: frontPushUpPoseSample(position: .up, at: start),
            challengeType: .pushUp
        )
        calibrator.process(
            sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(2.9)),
            challengeType: .pushUp
        )

        #expect(!calibrator.isReady)
        #expect(calibrator.progress > 0.9)

        calibrator.process(
            sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(3.0)),
            challengeType: .pushUp
        )

        #expect(calibrator.isReady)
        #expect(calibrator.progress == 1)
    }

    @Test func movementCalibrationResetsAfterLosingThePoseBeyondGracePeriod() throws {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 950)

        calibrator.process(
            sample: frontPushUpPoseSample(position: .up, at: start),
            challengeType: .pushUp
        )
        calibrator.process(
            sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(1)),
            challengeType: .pushUp
        )
        calibrator.processLostPose(at: start.addingTimeInterval(1.9))

        #expect(!calibrator.isReady)
        #expect(calibrator.progress == 0)
    }

    @Test func portraitPoseOverlayMapperKeepsHeadAboveHipsWithoutRotatingPoints() {
        let mapper = PortraitPoseOverlayMapper(
            imageSize: CGSize(width: 1080, height: 1920),
            bounds: CGRect(x: 0, y: 0, width: 390, height: 844)
        )

        let leftShoulder = mapper.map(CGPoint(x: 0.25, y: 0.25))
        let rightShoulder = mapper.map(CGPoint(x: 0.75, y: 0.25))
        let hips = mapper.map(CGPoint(x: 0.50, y: 0.60))

        #expect(leftShoulder.x < rightShoulder.x)
        #expect(abs(leftShoulder.y - rightShoulder.y) < 0.001)
        #expect(leftShoulder.y < hips.y)
    }

    @Test func squatCalibrationAcceptsStandingPoseWithUncertainAnkles() {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 1_200)
        var standing = frontSquatPoseSample(position: .standing, at: start)
        standing.leftAnkle.confidence = 0.1
        standing.rightAnkle.confidence = 0.1

        calibrator.process(sample: standing, challengeType: .squat)
        standing.timestamp = start.addingTimeInterval(3)
        calibrator.process(sample: standing, challengeType: .squat)

        #expect(calibrator.isReady)
        #expect(calibrator.progress == 1)
    }

    @Test func jumpingJackCalibrationAcceptsNeutralPoseWithUncertainElbowsAndAnkles() {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 1_300)
        var closed = jumpingJackPoseSample(position: .closed, at: start)
        closed.leftElbow.confidence = 0.1
        closed.rightElbow.confidence = 0.1
        closed.leftAnkle.confidence = 0.1
        closed.rightAnkle.confidence = 0.1

        calibrator.process(sample: closed, challengeType: .jumpingJack)
        closed.timestamp = start.addingTimeInterval(3)
        calibrator.process(sample: closed, challengeType: .jumpingJack)

        #expect(calibrator.isReady)
        #expect(calibrator.progress == 1)
    }

    @Test func plankCalibrationRequiresAStableForearmPlank() {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 1_400)

        calibrator.process(sample: frontPlankPoseSample(at: start), challengeType: .plank)
        calibrator.process(
            sample: frontPlankPoseSample(at: start.addingTimeInterval(2.9)),
            challengeType: .plank
        )

        #expect(!calibrator.isReady)

        calibrator.process(
            sample: frontPlankPoseSample(at: start.addingTimeInterval(3)),
            challengeType: .plank
        )

        #expect(calibrator.isReady)
        #expect(calibrator.progress == 1)
    }

    @Test func plankCalibrationAcceptsHeadOnPoseWithOccludedLowerBody() {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 1_450)
        var sample = frontPlankPoseSample(at: start)
        hidePlankLowerBody(in: &sample)

        calibrator.process(sample: sample, challengeType: .plank)
        sample.timestamp = start.addingTimeInterval(3)
        calibrator.process(sample: sample, challengeType: .plank)

        #expect(calibrator.isReady)
        #expect(calibrator.progress == 1)
    }

    @Test func plankCalibrationRequiresForearmsRatherThanAHighPlank() {
        var calibrator = MovementChallengeCalibrator()
        let start = Date(timeIntervalSince1970: 1_500)

        calibrator.process(sample: frontHighPlankPoseSample(at: start), challengeType: .plank)
        calibrator.process(
            sample: frontHighPlankPoseSample(at: start.addingTimeInterval(3)),
            challengeType: .plank
        )

        #expect(!calibrator.isReady)
        #expect(calibrator.progress == 0)
    }

    @Test func movementPoseSmootherAveragesVisibleLandmarksAcrossFrames() throws {
        let start = Date(timeIntervalSince1970: 980)
        var first = frontPushUpPoseSample(position: .up, at: start)
        first.leftShoulder.point = CGPoint(x: 0.20, y: 0.45)
        var second = first
        second.timestamp = start.addingTimeInterval(0.15)
        second.leftShoulder.point = CGPoint(x: 0.60, y: 0.45)

        var smoother = MovementPoseSmoother()
        _ = smoother.process(first)
        let result = smoother.process(second)

        #expect(abs(result.leftShoulder.point.x - 0.38) < 0.001)
        #expect(result.leftShoulder.confidence == second.leftShoulder.confidence)
    }

    @Test func pushUpPoseAnalyzerDoesNotCountPartialRep() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 2_000)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .down, at: start.addingTimeInterval(0.7)))

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 0)
        #expect(result.phase == .down)
        #expect(result.quality == .lower)
    }

    @Test func pushUpPoseAnalyzerCountsAHalfRepAsOneRejectedAttempt() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 2_500)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        var partial = frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(0.4))
        partial.leftElbow.point = CGPoint(x: 0.10, y: 0.53)
        partial.rightElbow.point = CGPoint(x: 0.90, y: 0.53)
        _ = analyzer.process(sample: partial)
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(0.9)))

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 1)
        #expect(result.quality == .rejected("That was a half rep. Lower until your elbows clearly bend."))
    }

    @Test func pushUpPoseAnalyzerPausesWhenLandmarksAreLost() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 3_000)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(0.2), confidence: 0.1))

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 0)
        #expect(result.phase == .paused)
        #expect(result.quality == .needFullBody)
    }

    @Test func pushUpPoseAnalyzerRequiresFrontFacingSetup() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 4_000)

        let result = analyzer.process(sample: pushUpPoseSample(elbow: .up, at: start))

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 0)
        #expect(result.phase == .waitingForSetup)
        #expect(result.quality == .needFrontView)
    }

    @Test func pushUpPoseAnalyzerCountsFrontFacingRepWithoutReliableLegLandmarks() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 5_000)

        let setup = frontPushUpPoseSample(position: .up, at: start)
        #expect(setup.hasReliableUpperBody)
        #expect(!setup.hasReliableFullBody)
        #expect(setup.appearsFrontFacing)

        _ = analyzer.process(sample: setup)
        _ = analyzer.process(sample: frontPushUpPoseSample(position: .down, at: start.addingTimeInterval(0.5)))
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(1.2)))

        #expect(result.validRepCount == 1)
        #expect(result.rejectedRepCount == 0)
        #expect(result.didCountRep)
        #expect(result.quality == .goodRep)
    }

    @Test func pushUpPoseAnalyzerKeepsTrackingWhenOneArmBrieflyFallsBelowConfidence() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 5_500)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        var down = frontPushUpPoseSample(position: .down, at: start.addingTimeInterval(0.5))
        down.rightElbow.confidence = 0.1
        down.rightWrist.confidence = 0.1
        _ = analyzer.process(sample: down)

        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(1.2)))

        #expect(result.validRepCount == 1)
        #expect(result.didCountRep)
    }

    @Test func pushUpPoseAnalyzerRejectsFrontFacingArmOnlyMotion() throws {
        var analyzer = PushUpPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 6_000)

        _ = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start))
        _ = analyzer.process(sample: frontPushUpPoseSample(position: .shallowDown, at: start.addingTimeInterval(0.5)))
        let result = analyzer.process(sample: frontPushUpPoseSample(position: .up, at: start.addingTimeInterval(1.2)))

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 1)
        #expect(result.quality == .rejected("Bring your chest down. Arm wiggles do not buy points."))
    }

    @Test func squatPoseAnalyzerCountsOneFrontFacingFullSquat() throws {
        var analyzer = SquatPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 7_000)

        _ = analyzer.process(sample: frontSquatPoseSample(position: .standing, at: start))
        _ = analyzer.process(sample: frontSquatPoseSample(position: .squat, at: start.addingTimeInterval(0.6)))
        let result = analyzer.process(sample: frontSquatPoseSample(position: .standing, at: start.addingTimeInterval(1.4)))

        #expect(result.challengeType == .squat)
        #expect(result.validRepCount == 1)
        #expect(result.rejectedRepCount == 0)
        #expect(result.didCountRep)
        #expect(result.pointsAwarded == 10)
    }

    @Test func squatPoseAnalyzerCountsWhenAnklesAreNearTheBottomFrameEdge() throws {
        var analyzer = SquatPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 7_500)

        var standing = frontSquatPoseSample(position: .standing, at: start)
        standing.leftAnkle.confidence = 0.1
        standing.rightAnkle.confidence = 0.1
        _ = analyzer.process(sample: standing)

        var squat = frontSquatPoseSample(position: .squat, at: start.addingTimeInterval(0.6))
        squat.leftAnkle.confidence = 0.1
        squat.rightAnkle.confidence = 0.1
        _ = analyzer.process(sample: squat)

        standing.timestamp = start.addingTimeInterval(1.4)
        let result = analyzer.process(sample: standing)

        #expect(result.validRepCount == 1)
        #expect(result.didCountRep)
    }

    @Test func squatPoseAnalyzerRejectsOnePartialDownAndUpCycle() {
        var analyzer = SquatPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 7_700)
        let standing = frontSquatPoseSample(position: .standing, at: start)
        _ = analyzer.process(sample: standing)

        var partial = standing
        partial.timestamp = start.addingTimeInterval(0.5)
        partial.leftHip.point.y += 0.035
        partial.rightHip.point.y += 0.035
        _ = analyzer.process(sample: partial)

        var returned = standing
        returned.timestamp = start.addingTimeInterval(1)
        let result = analyzer.process(sample: returned)

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 1)
        #expect(result.quality == .rejected("That was a half squat. Sit lower before standing back up."))
    }

    @Test func squatPoseAnalyzerRejectsAnInterruptedBottomPositionOnce() {
        var analyzer = SquatPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 7_800)

        _ = analyzer.process(sample: frontSquatPoseSample(position: .standing, at: start))
        _ = analyzer.process(sample: frontSquatPoseSample(position: .squat, at: start.addingTimeInterval(0.6)))
        let rejected = analyzer.processLostBody()
        let stillLost = analyzer.processLostBody()

        #expect(rejected.rejectedRepCount == 1)
        #expect(stillLost.rejectedRepCount == 1)
    }

    @Test func jumpingJackPoseAnalyzerCountsClosedOpenClosedCycle() throws {
        var analyzer = JumpingJackPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_000)

        _ = analyzer.process(sample: jumpingJackPoseSample(position: .closed, at: start))
        _ = analyzer.process(sample: jumpingJackPoseSample(position: .open, at: start.addingTimeInterval(0.5)))
        let result = analyzer.process(sample: jumpingJackPoseSample(position: .closed, at: start.addingTimeInterval(1.2)))

        #expect(result.challengeType == .jumpingJack)
        #expect(result.validRepCount == 1)
        #expect(result.rejectedRepCount == 0)
        #expect(result.didCountRep)
        #expect(result.pointsAwarded == 10)
    }

    @Test func jumpingJackPoseAnalyzerCountsWithUncertainElbowsAndAnkles() {
        var analyzer = JumpingJackPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_200)

        func uncertain(_ sample: PushUpPoseSample) -> PushUpPoseSample {
            var sample = sample
            sample.leftElbow.confidence = 0.1
            sample.rightElbow.confidence = 0.1
            sample.leftAnkle.confidence = 0.1
            sample.rightAnkle.confidence = 0.1
            return sample
        }

        _ = analyzer.process(sample: uncertain(jumpingJackPoseSample(position: .closed, at: start)))
        _ = analyzer.process(sample: uncertain(jumpingJackPoseSample(position: .open, at: start.addingTimeInterval(0.5))))
        let result = analyzer.process(sample: uncertain(jumpingJackPoseSample(position: .closed, at: start.addingTimeInterval(1.2))))

        #expect(result.validRepCount == 1)
        #expect(result.rejectedRepCount == 0)
    }

    @Test func jumpingJackPoseAnalyzerRejectsOnePartialOpenAndCloseCycle() {
        var analyzer = JumpingJackPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_300)
        let closed = jumpingJackPoseSample(position: .closed, at: start)
        _ = analyzer.process(sample: closed)

        var partial = closed
        partial.timestamp = start.addingTimeInterval(0.5)
        partial.leftWrist.point.y = 0.22
        partial.rightWrist.point.y = 0.22
        _ = analyzer.process(sample: partial)

        var returned = closed
        returned.timestamp = start.addingTimeInterval(1)
        let result = analyzer.process(sample: returned)

        #expect(result.validRepCount == 0)
        #expect(result.rejectedRepCount == 1)
        #expect(result.quality == .rejected("That was half a jumping jack. Hands up and feet wide."))
    }

    @Test func jumpingJackPoseAnalyzerRejectsAnInterruptedOpenPositionOnce() {
        var analyzer = JumpingJackPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_400)

        _ = analyzer.process(sample: jumpingJackPoseSample(position: .closed, at: start))
        _ = analyzer.process(sample: jumpingJackPoseSample(position: .open, at: start.addingTimeInterval(0.5)))
        let rejected = analyzer.processLostBody()
        let stillLost = analyzer.processLostBody()

        #expect(rejected.rejectedRepCount == 1)
        #expect(stillLost.rejectedRepCount == 1)
    }

    @Test func plankPoseAnalyzerCountsOnlyVerifiedHoldTime() {
        var analyzer = PlankPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_500)

        _ = analyzer.process(sample: frontPlankPoseSample(at: start))
        _ = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(0.25)))
        _ = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(0.50)))
        _ = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(0.75)))
        let result = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(1.00)))

        #expect(result.challengeType == .plank)
        #expect(abs(result.verifiedHoldSeconds - 1) < 0.001)
        #expect(result.pointsAwarded == 1)
        #expect(result.rejectedRepCount == 0)
        #expect(result.isHoldActive)
        #expect(result.quality == .plankHolding)
    }

    @Test func plankPoseAnalyzerCountsHeadOnHoldWhenLowerBodyIsOccluded() {
        var analyzer = PlankPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_550)
        var first = frontPlankPoseSample(at: start)
        hidePlankLowerBody(in: &first)
        var second = first
        second.timestamp = start.addingTimeInterval(0.25)

        _ = analyzer.process(sample: first)
        let result = analyzer.process(sample: second)

        #expect(abs(result.verifiedHoldSeconds - 0.25) < 0.001)
        #expect(result.rejectedRepCount == 0)
        #expect(result.isHoldActive)
        #expect(result.quality == .plankHolding)
    }

    @Test func plankPoseAnalyzerPausesAndRecordsOneBreakUntilFormReturns() {
        var analyzer = PlankPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_600)

        _ = analyzer.process(sample: frontPlankPoseSample(at: start))
        _ = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(0.25)))
        let lost = analyzer.processLostBody()
        let stillLost = analyzer.processLostBody()

        #expect(abs(lost.verifiedHoldSeconds - 0.25) < 0.001)
        #expect(lost.rejectedRepCount == 1)
        #expect(stillLost.rejectedRepCount == 1)
        #expect(!lost.isHoldActive)

        _ = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(1)))
        let resumed = analyzer.process(sample: frontPlankPoseSample(at: start.addingTimeInterval(1.25)))

        #expect(abs(resumed.verifiedHoldSeconds - 0.50) < 0.001)
        #expect(resumed.rejectedRepCount == 1)
        #expect(resumed.isHoldActive)
    }

    @Test func plankPoseAnalyzerRejectsLargeBodyMovement() {
        var analyzer = PlankPoseAnalyzer()
        let start = Date(timeIntervalSince1970: 8_700)

        _ = analyzer.process(sample: frontPlankPoseSample(at: start))
        var moved = frontPlankPoseSample(at: start.addingTimeInterval(0.25))
        moved.leftShoulder.point.x += 0.08
        moved.rightShoulder.point.x += 0.08
        moved.leftHip.point.x += 0.08
        moved.rightHip.point.x += 0.08
        let result = analyzer.process(sample: moved)

        #expect(result.verifiedHoldSeconds == 0)
        #expect(result.rejectedRepCount == 1)
        #expect(result.quality == .holdStill)
        #expect(!result.isHoldActive)
    }

    @Test func movementChallengeSessionPersistsAllChallengeTypes() throws {
        let started = Date(timeIntervalSince1970: 9_000)
        let squat = MovementChallengeSession(
            challengeType: .squat,
            startedAt: started,
            endedAt: started.addingTimeInterval(30),
            validRepCount: 3,
            rejectedRepCount: 1
        )
        let jumpingJack = MovementChallengeSession(
            challengeType: .jumpingJack,
            startedAt: started,
            endedAt: started.addingTimeInterval(30),
            validRepCount: 4,
            rejectedRepCount: 0
        )
        let plank = MovementChallengeSession(
            challengeType: .plank,
            startedAt: started,
            endedAt: started.addingTimeInterval(75),
            durationSeconds: 42.8,
            validRepCount: 0,
            rejectedRepCount: 2
        )
        let plankRecord = MovementChallengeSessionRecord(session: plank)

        #expect(MovementChallengeSessionRecord(session: squat).challenge_type == "squat")
        #expect(MovementChallengeSessionRecord(session: jumpingJack).challenge_type == "jumping_jack")
        #expect(plankRecord.challenge_type == "plank")
        #expect(squat.pointsAwarded == 30)
        #expect(jumpingJack.pointsAwarded == 40)
        #expect(plank.pointsAwarded == 42)
        #expect(squat.analysisVersion == "squat-front-v1")
        #expect(jumpingJack.analysisVersion == "jumping-jack-front-v1")
        #expect(plank.analysisVersion == "plank-forearm-front-v3")
        #expect(plankRecord.toSession() == plank)
    }

    @Test func movementChallengePointsAndDailyRollupUseOnlyValidReps() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 9)))
        let sameDay = day.addingTimeInterval(60 * 60)
        let otherDay = day.addingTimeInterval(60 * 60 * 24)
        let sessions = [
            MovementChallengeSession(startedAt: day, endedAt: day.addingTimeInterval(60), validRepCount: 8, rejectedRepCount: 3),
            MovementChallengeSession(startedAt: sameDay, endedAt: sameDay.addingTimeInterval(30), validRepCount: 2, rejectedRepCount: 1),
            MovementChallengeSession(startedAt: otherDay, endedAt: otherDay.addingTimeInterval(60), validRepCount: 99, rejectedRepCount: 0)
        ]

        let rollup = MovementChallengeStore.rollup(on: day, from: sessions, calendar: calendar)

        #expect(sessions[0].pointsAwarded == 80)
        #expect(rollup.sessionCount == 2)
        #expect(rollup.validRepCount == 10)
        #expect(rollup.rejectedRepCount == 4)
        #expect(rollup.pointsAwarded == 100)
        #expect(rollup.durationSeconds == 90)
    }

    @Test func movementChallengeSessionRecordRoundTripsWithoutMediaPayload() throws {
        let started = Date(timeIntervalSince1970: 10_000)
        let ended = started.addingTimeInterval(75)
        let session = MovementChallengeSession(
            startedAt: started,
            endedAt: ended,
            validRepCount: 12,
            rejectedRepCount: 2
        )
        let userId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000123"))

        let record = MovementChallengeSessionRecord(session: session, userId: userId)
        let roundTrip = record.toSession()

        #expect(record.user_id == userId)
        #expect(record.challenge_type == "push_up")
        #expect(record.valid_rep_count == 12)
        #expect(record.rejected_rep_count == 2)
        #expect(record.points_awarded == 120)
        #expect(record.analysis_version == MovementChallengeSession.analysisVersion)
        #expect(roundTrip == session)
    }

    @Test func mealReminderPlannerSkipsAlreadyLoggedMeals() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 7, minute: 45)))

        let items = CoachNotificationPlanner.mealReminderItems(
            loggedMealTypes: [.breakfast],
            settings: .defaults,
            toneSettings: .defaultFullRoast,
            now: now,
            calendar: calendar
        )

        #expect(items.map(\.id) == [
            CoachNotificationPlanner.lunch,
            CoachNotificationPlanner.dinner
        ])
        #expect(items.allSatisfy { $0.body.localizedCaseInsensitiveContains("missing") })
    }

    @Test func lateEatingCutoffSchedulesKitchenClosedReminder() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 18, minute: 0)))

        let item = try #require(CoachNotificationPlanner.lateEatingCutoffItem(
            settings: .defaults,
            toneSettings: .defaultFullRoast,
            now: now,
            calendar: calendar
        ))
        let fireDate = try #require(calendar.date(from: item.components))

        #expect(item.id == CoachNotificationPlanner.lateEatingCutoff)
        #expect(calendar.component(.hour, from: fireDate) == 21)
        #expect(item.body.contains("Kitchen is closed"))
    }

    @Test func activityAccountabilityPlannerWarnsForStepsAndMissingGymReceipt() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12, minute: 0)))
        let summary = ActivityDailySummary(
            date: calendar.startOfDay(for: now),
            steps: 2_500,
            stepGoal: 10_000,
            activeEnergyCalories: 120,
            exerciseMinutes: 0,
            workoutCount: 0,
            gymVisits: []
        )

        let items = CoachNotificationPlanner.activityAccountabilityItems(
            summary: summary,
            settings: .defaults,
            toneSettings: .defaultFullRoast,
            now: now,
            calendar: calendar
        )

        #expect(items.map(\.id).contains(CoachNotificationPlanner.stepGoal))
        #expect(items.map(\.id).contains(CoachNotificationPlanner.gymCheckIn))
        #expect(items.first { $0.id == CoachNotificationPlanner.stepGoal }?.body.contains("7500 steps left") == true)
        #expect(items.first { $0.id == CoachNotificationPlanner.gymCheckIn }?.body.contains("No gym check-in") == true)
    }

    @Test func appleSignInProviderErrorExplainsSupabaseSetup() {
        let error = TestLocalizedError("provider issuer https://appleid.apple.com not enabled")

        let message = AppleSignInErrorMessage.friendlyMessage(from: error)

        #expect(message.contains("Apple provider is not enabled"))
        #expect(message.contains("Authentication > Providers > Apple"))
    }

    @Test func appleSignInAudienceErrorExplainsClientIDSetup() {
        let error = TestLocalizedError("invalid claim: aud")

        let message = AppleSignInErrorMessage.friendlyMessage(from: error)

        #expect(message.contains("client ID does not match"))
        #expect(message.contains("com.hyperlabsAI.CalorieTrackAI"))
    }

    @Test func appleSignInEntitlementErrorExplainsProvisioningSetup() {
        let error = TestLocalizedError("Authorization failed because the capability is missing")

        let message = AppleSignInErrorMessage.friendlyMessage(from: error)

        #expect(message.contains("Sign in with Apple is enabled"))
        #expect(message.contains("provisioning profile"))
    }

    @Test func appleNonceGenerationFailureIsRecoverable() {
        #expect(throws: AppleSignInNonce.NonceError.randomGenerationFailed(OSStatus(-1))) {
            try AppleSignInNonce.randomNonceString { _ in
                OSStatus(-1)
            }
        }

        let message = AppleSignInErrorMessage.friendlyMessage(
            from: AppleSignInNonce.NonceError.randomGenerationFailed(OSStatus(-1))
        )

        #expect(message.contains("could not start"))
        #expect(message.contains("secure request nonce"))
    }

    @Test func appleNonceGenerationRejectsInvalidLengthWithoutCrashing() {
        #expect(throws: AppleSignInNonce.NonceError.invalidLength) {
            try AppleSignInNonce.randomNonceString(length: 0) { _ in
                errSecSuccess
            }
        }
    }

    @Test func supabaseAIProxyRequestUsesAuthenticatedJWTAndPublishableKey() throws {
        let client = SupabaseAIFunctionClient(
            supabaseURL: try #require(URL(string: "https://tlbdjexawwfpeuykumbv.supabase.co")),
            apiKey: "sb_publishable_test"
        )

        let request = try client.makeRequest(["action": "mealAnalysis"], accessToken: "user-session-jwt")

        #expect(request.url?.absoluteString == "https://tlbdjexawwfpeuykumbv.supabase.co/functions/v1/mft-ai-coach")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-session-jwt")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func supabaseAIProxyRequiresSessionToken() throws {
        let client = SupabaseAIFunctionClient(
            supabaseURL: try #require(URL(string: "https://tlbdjexawwfpeuykumbv.supabase.co")),
            apiKey: "sb_publishable_test"
        )

        do {
            _ = try client.makeRequest(["action": "mealAnalysis"], accessToken: nil)
            Issue.record("Proxy request should require an authenticated Supabase session token.")
        } catch OpenAIError.proxyAuthenticationRequired {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func supabaseAIProxyAllowsAnonJWTForTestingGuestAccess() throws {
        let client = SupabaseAIFunctionClient(
            supabaseURL: try #require(URL(string: "https://tlbdjexawwfpeuykumbv.supabase.co")),
            apiKey: "sb_publishable_test",
            testingGuestAccessToken: "anon-jwt-for-testflight-qa"
        )

        let request = try client.makeRequest(
            ["action": "mealAnalysis"],
            accessToken: nil,
            allowsTestingGuestAccess: true
        )

        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer anon-jwt-for-testflight-qa")
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private enum PushUpElbowFixture {
        case up
        case down
    }

    private enum FrontPushUpPosition {
        case up
        case down
        case shallowDown
    }

    private enum FrontSquatPosition {
        case standing
        case squat
    }

    private enum JumpingJackPosition {
        case closed
        case open
    }

    private func pushUpPoseSample(
        elbow: PushUpElbowFixture,
        at timestamp: Date,
        confidence: Double = 0.95,
        hipYOffset: CGFloat = 0
    ) -> PushUpPoseSample {
        let leftShoulder = CGPoint(x: 0.25, y: 0.32)
        let rightShoulder = CGPoint(x: 0.28, y: 0.32)
        let leftHip = CGPoint(x: 0.50, y: 0.34 + hipYOffset)
        let rightHip = CGPoint(x: 0.53, y: 0.34 + hipYOffset)
        let leftKnee = CGPoint(x: 0.70, y: 0.35)
        let rightKnee = CGPoint(x: 0.73, y: 0.35)
        let leftAnkle = CGPoint(x: 0.90, y: 0.36)
        let rightAnkle = CGPoint(x: 0.93, y: 0.36)

        let leftElbow: CGPoint
        let rightElbow: CGPoint
        let leftWrist: CGPoint
        let rightWrist: CGPoint

        switch elbow {
        case .up:
            leftElbow = CGPoint(x: 0.22, y: 0.48)
            rightElbow = CGPoint(x: 0.25, y: 0.48)
            leftWrist = CGPoint(x: 0.19, y: 0.64)
            rightWrist = CGPoint(x: 0.22, y: 0.64)
        case .down:
            leftElbow = CGPoint(x: 0.30, y: 0.46)
            rightElbow = CGPoint(x: 0.33, y: 0.46)
            leftWrist = CGPoint(x: 0.20, y: 0.50)
            rightWrist = CGPoint(x: 0.23, y: 0.50)
        }

        func landmark(_ point: CGPoint) -> PoseLandmark {
            PoseLandmark(point: point, confidence: confidence)
        }

        return PushUpPoseSample(
            timestamp: timestamp,
            leftShoulder: landmark(leftShoulder),
            rightShoulder: landmark(rightShoulder),
            leftElbow: landmark(leftElbow),
            rightElbow: landmark(rightElbow),
            leftWrist: landmark(leftWrist),
            rightWrist: landmark(rightWrist),
            leftHip: landmark(leftHip),
            rightHip: landmark(rightHip),
            leftKnee: landmark(leftKnee),
            rightKnee: landmark(rightKnee),
            leftAnkle: landmark(leftAnkle),
            rightAnkle: landmark(rightAnkle)
        )
    }

    private func frontPushUpPoseSample(
        position: FrontPushUpPosition,
        at timestamp: Date,
        confidence: Double = 0.95
    ) -> PushUpPoseSample {
        let shoulderY: CGFloat
        let leftElbow: CGPoint
        let rightElbow: CGPoint

        switch position {
        case .up:
            shoulderY = 0.45
            leftElbow = CGPoint(x: 0.20, y: 0.55)
            rightElbow = CGPoint(x: 0.80, y: 0.55)
        case .down:
            shoulderY = 0.52
            leftElbow = CGPoint(x: 0.05, y: 0.55)
            rightElbow = CGPoint(x: 0.95, y: 0.55)
        case .shallowDown:
            shoulderY = 0.46
            leftElbow = CGPoint(x: 0.05, y: 0.55)
            rightElbow = CGPoint(x: 0.95, y: 0.55)
        }

        func landmark(_ point: CGPoint) -> PoseLandmark {
            PoseLandmark(point: point, confidence: confidence)
        }

        return PushUpPoseSample(
            timestamp: timestamp,
            leftShoulder: landmark(CGPoint(x: 0.35, y: shoulderY)),
            rightShoulder: landmark(CGPoint(x: 0.65, y: shoulderY)),
            leftElbow: landmark(leftElbow),
            rightElbow: landmark(rightElbow),
            leftWrist: landmark(CGPoint(x: 0.05, y: 0.65)),
            rightWrist: landmark(CGPoint(x: 0.95, y: 0.65)),
            leftHip: .missing,
            rightHip: .missing,
            leftKnee: .missing,
            rightKnee: .missing,
            leftAnkle: .missing,
            rightAnkle: .missing
        )
    }

    private func frontSquatPoseSample(position: FrontSquatPosition, at timestamp: Date) -> PushUpPoseSample {
        let hips: (CGPoint, CGPoint)
        let knees: (CGPoint, CGPoint)

        switch position {
        case .standing:
            hips = (CGPoint(x: 0.42, y: 0.45), CGPoint(x: 0.58, y: 0.45))
            knees = (CGPoint(x: 0.42, y: 0.68), CGPoint(x: 0.58, y: 0.68))
        case .squat:
            hips = (CGPoint(x: 0.42, y: 0.58), CGPoint(x: 0.58, y: 0.58))
            knees = (CGPoint(x: 0.30, y: 0.72), CGPoint(x: 0.70, y: 0.72))
        }

        return frontFullBodyPoseSample(
            timestamp: timestamp,
            leftHip: hips.0,
            rightHip: hips.1,
            leftKnee: knees.0,
            rightKnee: knees.1,
            leftAnkle: CGPoint(x: 0.40, y: 0.90),
            rightAnkle: CGPoint(x: 0.60, y: 0.90),
            leftWrist: CGPoint(x: 0.30, y: 0.42),
            rightWrist: CGPoint(x: 0.70, y: 0.42)
        )
    }

    private func jumpingJackPoseSample(position: JumpingJackPosition, at timestamp: Date) -> PushUpPoseSample {
        switch position {
        case .closed:
            return frontFullBodyPoseSample(
                timestamp: timestamp,
                leftHip: CGPoint(x: 0.42, y: 0.45),
                rightHip: CGPoint(x: 0.58, y: 0.45),
                leftKnee: CGPoint(x: 0.43, y: 0.68),
                rightKnee: CGPoint(x: 0.57, y: 0.68),
                leftAnkle: CGPoint(x: 0.45, y: 0.90),
                rightAnkle: CGPoint(x: 0.55, y: 0.90),
                leftWrist: CGPoint(x: 0.35, y: 0.55),
                rightWrist: CGPoint(x: 0.65, y: 0.55)
            )
        case .open:
            return frontFullBodyPoseSample(
                timestamp: timestamp,
                leftHip: CGPoint(x: 0.42, y: 0.45),
                rightHip: CGPoint(x: 0.58, y: 0.45),
                leftKnee: CGPoint(x: 0.32, y: 0.68),
                rightKnee: CGPoint(x: 0.68, y: 0.68),
                leftAnkle: CGPoint(x: 0.20, y: 0.90),
                rightAnkle: CGPoint(x: 0.80, y: 0.90),
                leftWrist: CGPoint(x: 0.43, y: 0.07),
                rightWrist: CGPoint(x: 0.57, y: 0.07)
            )
        }
    }

    private func frontPlankPoseSample(at timestamp: Date) -> PushUpPoseSample {
        func landmark(_ point: CGPoint) -> PoseLandmark {
            PoseLandmark(point: point, confidence: 0.95)
        }

        return PushUpPoseSample(
            timestamp: timestamp,
            leftShoulder: landmark(CGPoint(x: 0.35, y: 0.35)),
            rightShoulder: landmark(CGPoint(x: 0.65, y: 0.35)),
            leftElbow: landmark(CGPoint(x: 0.25, y: 0.55)),
            rightElbow: landmark(CGPoint(x: 0.75, y: 0.55)),
            leftWrist: landmark(CGPoint(x: 0.40, y: 0.58)),
            rightWrist: landmark(CGPoint(x: 0.60, y: 0.58)),
            leftHip: landmark(CGPoint(x: 0.43, y: 0.50)),
            rightHip: landmark(CGPoint(x: 0.57, y: 0.50)),
            leftKnee: landmark(CGPoint(x: 0.46, y: 0.60)),
            rightKnee: landmark(CGPoint(x: 0.54, y: 0.60)),
            leftAnkle: landmark(CGPoint(x: 0.48, y: 0.68)),
            rightAnkle: landmark(CGPoint(x: 0.52, y: 0.68))
        )
    }

    private func frontHighPlankPoseSample(at timestamp: Date) -> PushUpPoseSample {
        var sample = frontPlankPoseSample(at: timestamp)
        sample.leftElbow.point = CGPoint(x: 0.30, y: 0.50)
        sample.rightElbow.point = CGPoint(x: 0.70, y: 0.50)
        sample.leftWrist.point = CGPoint(x: 0.24, y: 0.68)
        sample.rightWrist.point = CGPoint(x: 0.76, y: 0.68)
        return sample
    }

    private func hidePlankLowerBody(in sample: inout PushUpPoseSample) {
        sample.leftHip.confidence = 0.1
        sample.rightHip.confidence = 0.1
        sample.leftKnee.confidence = 0.1
        sample.rightKnee.confidence = 0.1
        sample.leftAnkle.confidence = 0.1
        sample.rightAnkle.confidence = 0.1
    }

    private func frontFullBodyPoseSample(
        timestamp: Date,
        leftHip: CGPoint,
        rightHip: CGPoint,
        leftKnee: CGPoint,
        rightKnee: CGPoint,
        leftAnkle: CGPoint,
        rightAnkle: CGPoint,
        leftWrist: CGPoint,
        rightWrist: CGPoint
    ) -> PushUpPoseSample {
        func landmark(_ point: CGPoint) -> PoseLandmark {
            PoseLandmark(point: point, confidence: 0.95)
        }

        return PushUpPoseSample(
            timestamp: timestamp,
            leftShoulder: landmark(CGPoint(x: 0.40, y: 0.20)),
            rightShoulder: landmark(CGPoint(x: 0.60, y: 0.20)),
            leftElbow: landmark(CGPoint(x: 0.36, y: 0.34)),
            rightElbow: landmark(CGPoint(x: 0.64, y: 0.34)),
            leftWrist: landmark(leftWrist),
            rightWrist: landmark(rightWrist),
            leftHip: landmark(leftHip),
            rightHip: landmark(rightHip),
            leftKnee: landmark(leftKnee),
            rightKnee: landmark(rightKnee),
            leftAnkle: landmark(leftAnkle),
            rightAnkle: landmark(rightAnkle)
        )
    }

    @Test func gymLocationRecordRoundTripsEntrancePin() {
        let gym = GymLocation(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            address: "123 Main St, Albuquerque, NM",
            entranceLatitude: 35.10004,
            entranceLongitude: -106.60007
        )

        let restored = GymLocationRecord(location: gym).toLocation()

        #expect(restored.address == gym.address)
        #expect(restored.entranceLatitude == gym.entranceLatitude)
        #expect(restored.entranceLongitude == gym.entranceLongitude)
        #expect(restored.hasEntrancePin)
    }

    @Test func gymCheckInUsesEntrancePinAndRejectsStaleLocation() {
        let now = Date()
        let gym = GymLocation(
            name: "Chuze Fitness",
            chain: "Chuze Fitness",
            latitude: 35.1000,
            longitude: -106.6000,
            entranceLatitude: 35.10012,
            entranceLongitude: -106.6000
        )
        let entranceLocation = CLLocation(
            coordinate: gym.checkInCoordinate,
            altitude: 0,
            horizontalAccuracy: 6,
            verticalAccuracy: 6,
            course: 0,
            speed: 0,
            timestamp: now
        )

        let verified = GymCheckInDiagnostic.evaluate(
            location: entranceLocation,
            savedGyms: [gym],
            todaysVisits: [],
            checkedAt: now
        )
        #expect(verified.outcome == .checkedIn)

        let staleLocation = CLLocation(
            coordinate: gym.checkInCoordinate,
            altitude: 0,
            horizontalAccuracy: 6,
            verticalAccuracy: 6,
            course: 0,
            speed: 0,
            timestamp: now.addingTimeInterval(-GymLocation.maximumAutomaticLocationAge - 1)
        )
        let stale = GymCheckInDiagnostic.evaluate(
            location: staleLocation,
            savedGyms: [gym],
            todaysVisits: [],
            checkedAt: now
        )
        #expect(stale.outcome == .staleLocation)
        #expect(!stale.shouldLogAutomaticVisit)
    }

    @Test func remoteNotificationRoutesCompetitionPayload() {
        #expect(RemoteNotificationRoute(userInfo: ["route": "competition"]) == .competition)
        #expect(RemoteNotificationRoute(userInfo: ["route": "food"]) == nil)
        #expect(RemoteNotificationRoute(userInfo: [:]) == nil)
    }

    @Test func apnsDeviceTokenUsesLowercaseHex() {
        let token = RemoteNotificationService.deviceTokenString(Data([0x00, 0x0A, 0xF1, 0xFF]))
        #expect(token == "000af1ff")
    }

    @Test func legacyNotificationSettingsEnableSocialPushByDefault() throws {
        let encoded = try JSONEncoder().encode(CoachNotificationSettings.defaults)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "socialNotifications")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CoachNotificationSettings.self, from: legacyData)

        #expect(decoded.socialNotifications)
    }

    private func testFitnessPlan() -> FitnessPlan {
        FitnessPlan(
            goal: .loseWeight,
            calorieTarget: 2_000,
            proteinGoal: 150,
            carbsGoal: 220,
            fatGoal: 65,
            stepGoal: 10_000,
            trainingDaysPerWeek: 4,
            meals: [],
            workouts: [],
            coachNote: "test plan"
        )
    }
}

struct ArticulatedMannequinMotionTests {
    @Test func pushUpPoseKeepsHandsPlanted() {
        let top = PushUpMannequinMotion.pose(progress: 0)
        let bottom = PushUpMannequinMotion.pose(progress: 1)

        #expect(top[.leftWrist] == bottom[.leftWrist])
        #expect(top[.rightWrist] == bottom[.rightWrist])
    }

    @Test func pushUpPoseLowersBodyAndBendsElbowsOutward() {
        let top = PushUpMannequinMotion.pose(progress: 0)
        let bottom = PushUpMannequinMotion.pose(progress: 1)

        #expect(bottom[.leftShoulder].y < top[.leftShoulder].y)
        #expect(bottom[.leftHip].y < top[.leftHip].y)
        #expect(bottom[.leftElbow].x < top[.leftElbow].x)
        #expect(bottom[.rightElbow].x > top[.rightElbow].x)
    }

    @Test func pushUpAnimationIncludesReadableTopAndBottomHolds() {
        let duration = PushUpMannequinMotion.cycleDuration

        #expect(PushUpMannequinMotion.progress(at: 0.05 * duration) == 0)
        #expect(PushUpMannequinMotion.progress(at: 0.50 * duration) == 1)
        #expect(PushUpMannequinMotion.progress(at: 0.95 * duration) == 0)
    }

    @Test func pushUpPoseClampsAnimationInput() {
        let belowRange = PushUpMannequinMotion.pose(progress: -10)
        let top = PushUpMannequinMotion.pose(progress: 0)
        let aboveRange = PushUpMannequinMotion.pose(progress: 10)
        let bottom = PushUpMannequinMotion.pose(progress: 1)

        #expect(belowRange[.head] == top[.head])
        #expect(aboveRange[.head] == bottom[.head])
    }

    @Test func squatLowersBodyWithFeetPlantedAndKneesTrackingOut() {
        let standing = SquatMannequinMotion.pose(progress: 0)
        let depth = SquatMannequinMotion.pose(progress: 1)

        #expect(depth[.head].y < standing[.head].y)
        #expect(depth[.leftHip].y < standing[.leftHip].y)
        #expect(depth[.leftAnkle] == standing[.leftAnkle])
        #expect(depth[.rightAnkle] == standing[.rightAnkle])
        #expect(depth[.leftKnee].x < standing[.leftKnee].x)
        #expect(depth[.rightKnee].x > standing[.rightKnee].x)
    }

    @Test func jumpingJackOpensArmsAndLegsSymmetrically() {
        let closed = JumpingJackMannequinMotion.pose(progress: 0)
        let open = JumpingJackMannequinMotion.pose(progress: 1)

        #expect(open[.leftWrist].y > open[.head].y)
        #expect(open[.rightWrist].y > open[.head].y)
        #expect(abs(open[.leftWrist].x) == abs(open[.rightWrist].x))
        #expect(abs(open[.leftAnkle].x) > abs(closed[.leftAnkle].x))
        #expect(abs(open[.rightAnkle].x) > abs(closed[.rightAnkle].x))
    }

    @Test func plankBreathingKeepsForearmsAndHipsLocked() {
        let resting = PlankMannequinMotion.pose(progress: 0)
        let inhaled = PlankMannequinMotion.pose(progress: 1)

        #expect(inhaled[.leftElbow] == resting[.leftElbow])
        #expect(inhaled[.rightElbow] == resting[.rightElbow])
        #expect(inhaled[.leftWrist] == resting[.leftWrist])
        #expect(inhaled[.rightWrist] == resting[.rightWrist])
        #expect(inhaled[.leftHip] == resting[.leftHip])
        #expect(inhaled[.rightHip] == resting[.rightHip])
        #expect(inhaled[.leftShoulder].y > resting[.leftShoulder].y)
    }

    @Test func challengeDispatcherUsesEachExercisePose() {
        let squat = ChallengeMannequinMotion.pose(for: .squat, progress: 1)
        let jumpingJack = ChallengeMannequinMotion.pose(for: .jumpingJack, progress: 1)
        let plank = ChallengeMannequinMotion.pose(for: .plank, progress: 1)

        #expect(squat[.leftAnkle].x == -0.30)
        #expect(jumpingJack[.leftWrist].y > 1)
        #expect(plank[.leftElbow].z > 0)
    }
}

struct NutritionInsightsTests {
    @Test func periodSummaryUsesOnlyLoggedDaysForPlanComparison() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = Date(timeIntervalSince1970: 86_400)
        let secondDay = firstDay.addingTimeInterval(86_400)
        let entries = [
            MealEntry(food_name: "Breakfast", calories: 1_800, consumed_at: firstDay),
            MealEntry(food_name: "Lunch", calories: 1_000, consumed_at: firstDay.addingTimeInterval(3_600)),
            MealEntry(food_name: "Dinner", calories: 1_500, consumed_at: secondDay)
        ]

        let summary = CaloriePeriodSummary.make(
            period: .week,
            entries: entries,
            dailyTarget: 2_000,
            calendar: calendar
        )

        #expect(summary.totalCalories == 4_300)
        #expect(summary.daysWithEntries == 2)
        #expect(summary.plannedCalories == 4_000)
        #expect(summary.calorieVariance == 300)
        #expect(summary.isSurplus)
    }

    @Test func macroCatchUpBudgetNeverUsesAlreadyExceededMacros() {
        let budget = MacroCatchUpBudget(
            progress: DailyNutritionProgress(calories: 1_900, protein: 90, carbs: 210, fat: 72),
            targets: DailyNutritionTargets(calories: 2_000, protein: 150, carbs: 220, fat: 70)
        )

        #expect(budget.caloriesRemaining == 100)
        #expect(budget.proteinRemaining == 60)
        #expect(budget.carbohydratesRemaining == 10)
        #expect(budget.fatRemaining == 0)
        #expect(budget.canSuggestFood)
    }
}

private struct TestLocalizedError: LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

@MainActor
private final class MockMealAnalyzer: MealAnalysisProviding {
    private let result: Result<MealAnalysis, Error>
    private(set) var lastDescription: String?

    init(analysis: MealAnalysis) {
        result = .success(analysis)
    }

    init(error: Error) {
        result = .failure(error)
    }

    func analyzeMealDescription(_ description: String) async throws -> MealAnalysis {
        lastDescription = description
        return try result.get()
    }
}

@MainActor
private final class SpyFoodLoggingService: FoodLoggingProviding {
    private(set) var addedFoods: [Food] = []
    private(set) var offlineFoods: [Food] = []
    private(set) var addedMealTypes: [MealEntry.MealType?] = []

    func addFood(_ food: Food, mealType: MealEntry.MealType?) async throws {
        addedMealTypes.append(mealType)
        addedFoods.append(food)
    }

    func addFoodOffline(_ food: Food, mealType: MealEntry.MealType?) {
        offlineFoods.append(food)
    }

    func getFoodsForDate(_ date: Date) async throws -> [Food] {
        addedFoods
    }

    func getFoodsForDateOffline(_ date: Date) -> [Food] {
        offlineFoods
    }
}

@MainActor
private struct NilCurrentUserProvider: CurrentUserProviding {
    func getCurrentUserSync() -> User? {
        nil
    }
}

@MainActor
private struct NilFitnessPlanProvider: CurrentFitnessPlanProviding {
    var currentPlan: FitnessPlan? {
        nil
    }
}
