import Foundation
import CoreLocation
import MapKit

@MainActor
final class GymLocationService: NSObject, ObservableObject {
    static let shared = GymLocationService()

    @Published private(set) var savedGyms: [GymLocation] = []
    @Published private(set) var visits: [GymVisit] = []
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isMonitoring = false
    @Published private(set) var monitoredGymCount = 0
    @Published private(set) var isSyncing = false
    @Published private(set) var locationErrorMessage: String?
    @Published private(set) var proximityCheckMessage: String?
    @Published private(set) var checkInDiagnostic: GymCheckInDiagnostic?
    @Published private(set) var latestLocationFix: CLLocation?
    @Published private(set) var isLocatingForSearch = false
    @Published private(set) var isCheckingCurrentGymArrival = false

    private let manager = CLLocationManager()
    private let gymsKey = "SavedGymLocations"
    private let visitsKey = "GymVisits"
    private let supabaseService = SupabaseService.shared
    private var pendingAutoCheckIn: PendingGymAutoCheckIn?
    private var pendingAutoCheckInTask: Task<Void, Never>?
    private var pendingEntrancePinGymId: UUID?
    private var searchLocationContinuation: CheckedContinuation<CLLocation, Error>?
    private var searchLocationTimeoutTask: Task<Void, Never>?
    private var shouldVerifyAfterAuthorization = false

    private override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        load()
        restartMonitoring()
    }

    func requestNearbySearchAccess() {
        locationErrorMessage = nil
        proximityCheckMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestFullAccuracyForGymArrival()
            manager.requestLocation()
        case .restricted:
            locationErrorMessage = "Location access is restricted on this device."
        case .denied:
            locationErrorMessage = "Location access is denied. Open Settings if you want nearby gym search."
        @unknown default:
            locationErrorMessage = "Location access is unavailable right now."
        }
    }

    func requestGymMonitoringAccess() {
        locationErrorMessage = nil
        proximityCheckMessage = nil

        guard !savedGyms.isEmpty else {
            isMonitoring = false
            locationErrorMessage = "Save a gym first, then the app can ask for automatic check-in access."
            return
        }

        switch authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            requestFullAccuracyForGymArrival()
            restartMonitoring()
            verifyCurrentGymArrival()
        case .restricted:
            isMonitoring = false
            locationErrorMessage = "Location access is restricted, so automatic gym check-ins are disabled."
        case .denied:
            isMonitoring = false
            locationErrorMessage = "Location access is denied. Manual check-ins still work."
        @unknown default:
            isMonitoring = false
            locationErrorMessage = "Location access is unavailable right now."
        }
    }

    func searchKnownChain(_ chain: KnownGymChain) async throws -> [GymLocation] {
        try await searchGyms(query: chain.rawValue, fallbackChain: chain.rawValue)
    }

    func searchNearbyGyms() async throws -> [GymLocation] {
        try await searchGyms(query: "gym", fallbackChain: "Nearby gym")
    }

    private func searchGyms(query: String, fallbackChain: String) async throws -> [GymLocation] {
        let currentLocation = try await freshLocationForSearch()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: 40_000,
            longitudinalMeters: 40_000
        )

        let response = try await MKLocalSearch(request: request).start()
        let results: [GymLocation] = response.mapItems.compactMap { item in
            guard let name = item.name else { return nil }
            let coordinate = item.placemark.coordinate
            let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return GymLocation(
                name: name,
                chain: Self.chainName(for: name, fallback: fallbackChain),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                address: Self.addressString(for: item.placemark),
                distanceMeters: currentLocation.distance(from: itemLocation)
            )
        }
        return Array(Self.rankedSearchResults(results).prefix(12))
    }

    nonisolated static func bestFreshSearchLocation(
        from locations: [CLLocation],
        now: Date = Date(),
        maximumAge: TimeInterval = 30,
        maximumHorizontalAccuracy: CLLocationAccuracy = 200
    ) -> CLLocation? {
        locations
            .filter {
                $0.horizontalAccuracy >= 0
                    && $0.horizontalAccuracy <= maximumHorizontalAccuracy
                    && abs($0.timestamp.timeIntervalSince(now)) <= maximumAge
            }
            .min { $0.horizontalAccuracy < $1.horizontalAccuracy }
    }

    nonisolated static func rankedSearchResults(_ gyms: [GymLocation]) -> [GymLocation] {
        gyms.sorted { lhs, rhs in
            switch (lhs.distanceMeters, rhs.distanceMeters) {
            case let (lhsDistance?, rhsDistance?) where lhsDistance != rhsDistance:
                return lhsDistance < rhsDistance
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                if lhs.name != rhs.name {
                    return lhs.name < rhs.name
                }

                return (lhs.address ?? "") < (rhs.address ?? "")
            }
        }
    }

    func saveGym(_ gym: GymLocation) {
        guard !savedGyms.contains(where: { $0.id == gym.id || samePlace($0, gym) }) else { return }
        savedGyms.append(gym)
        saveGyms()

        if authorizationStatus == .authorizedAlways {
            restartMonitoring()
            verifyCurrentGymArrival()
        } else {
            requestGymMonitoringAccess()
        }

        Task {
            await syncGym(gym)
        }
    }

    func captureCurrentEntrance(for gym: GymLocation) {
        guard savedGyms.contains(where: { $0.id == gym.id }) else { return }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            pendingEntrancePinGymId = gym.id
            requestFullAccuracyForGymArrival()
            locationErrorMessage = nil
            proximityCheckMessage = "Getting a precise entrance pin for \(gym.name). Stand at the door and let the location settle."
            manager.requestLocation()
        case .notDetermined:
            pendingEntrancePinGymId = gym.id
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            locationErrorMessage = "Location access is required to set a precise gym entrance pin."
        @unknown default:
            locationErrorMessage = "Location access is unavailable right now."
        }
    }

    func deleteGym(at offsets: IndexSet) {
        let deletedGyms = offsets.compactMap { index in
            savedGyms.indices.contains(index) ? savedGyms[index] : nil
        }

        for index in offsets.sorted(by: >) {
            savedGyms.remove(at: index)
        }
        saveGyms()
        restartMonitoring()

        Task {
            await deleteGymsFromServer(deletedGyms)
        }
    }

    func clearLocalData() {
        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
        savedGyms = []
        visits = []
        isMonitoring = false
        monitoredGymCount = 0
        locationErrorMessage = nil
        checkInDiagnostic = nil
        pendingAutoCheckIn = nil
        pendingAutoCheckInTask?.cancel()
        pendingAutoCheckInTask = nil
        saveGyms()
        saveVisits()
    }

    @discardableResult
    func logManualVisit(for gym: GymLocation) -> Bool {
        let now = Date()
        guard !GymVisitReceiptPolicy.hasReceiptToday(for: gym, visits: visits, now: now) else {
            let message = "Already checked in at \(gym.name) today. One receipt is enough; go do the workout part."
            proximityCheckMessage = message
            checkInDiagnostic = GymCheckInDiagnostic(
                outcome: .alreadyCheckedIn,
                checkedAt: now,
                nearestGymId: gym.id,
                nearestGymName: gym.name,
                distanceMeters: nil,
                radiusMeters: gym.effectiveCheckInRadiusMeters,
                message: message
            )
            return false
        }

        let visit = GymVisit(
            gymLocationId: gym.id,
            gymName: gym.name,
            arrivedAt: now,
            source: .manual
        )
        visits.insert(visit, at: 0)
        saveVisits()

        proximityCheckMessage = "Manual check-in logged for \(gym.name). Good. Now make the workout count."
        checkInDiagnostic = GymCheckInDiagnostic(
            outcome: .checkedIn,
            checkedAt: now,
            nearestGymId: gym.id,
            nearestGymName: gym.name,
            distanceMeters: nil,
            radiusMeters: gym.effectiveCheckInRadiusMeters,
            message: "Manual check-in logged for \(gym.name)."
        )

        Task {
            await syncVisit(visit)
            await refreshActivityAndNotifications()
        }

        return true
    }

    func todaysVisits() -> [GymVisit] {
        visits.filter { Calendar.current.isDateInToday($0.arrivedAt) }
    }

    func verifyCurrentGymArrival() {
        locationErrorMessage = nil
        proximityCheckMessage = "Finding a fresh, precise location fix..."

        guard !savedGyms.isEmpty else {
            proximityCheckMessage = "Save a gym before checking whether you are standing in one."
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isCheckingCurrentGymArrival = true
            requestFullAccuracyForGymArrival()
            manager.requestLocation()
        case .notDetermined:
            shouldVerifyAfterAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .restricted:
            proximityCheckMessage = nil
            locationErrorMessage = "Location access is restricted, so current gym detection is disabled."
        case .denied:
            proximityCheckMessage = nil
            locationErrorMessage = "Location access is denied. Manual check-ins still work."
        @unknown default:
            proximityCheckMessage = nil
            locationErrorMessage = "Location access is unavailable right now."
        }
    }

    func restartMonitoring() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            isMonitoring = false
            monitoredGymCount = 0
            locationErrorMessage = "This device does not support automatic gym check-ins."
            return
        }

        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }

        guard authorizationStatus == .authorizedAlways else {
            isMonitoring = false
            monitoredGymCount = 0
            return
        }

        let monitoredGyms = Array(savedGyms.prefix(20))
        for gym in monitoredGyms {
            let region = CLCircularRegion(
                center: gym.checkInCoordinate,
                radius: gym.effectiveMonitoringRadiusMeters,
                identifier: gym.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }

        isMonitoring = !savedGyms.isEmpty
        monitoredGymCount = monitoredGyms.count
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let remoteGyms = try await supabaseService.getGymLocations()
            var mergedGyms = remoteGyms
            for localGym in savedGyms where !mergedGyms.contains(where: { $0.id == localGym.id || samePlace($0, localGym) }) {
                do {
                    let saved = try await supabaseService.saveGymLocation(localGym)
                    mergedGyms.append(saved)
                } catch {
                    mergedGyms.append(localGym)
                }
            }

            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())
            let remoteVisits = try await supabaseService.getGymVisits(since: monthAgo)
            var mergedVisits = remoteVisits
            for localVisit in visits where !mergedVisits.contains(where: { $0.id == localVisit.id }) {
                do {
                    let saved = try await supabaseService.saveGymVisit(localVisit)
                    mergedVisits.append(saved)
                } catch {
                    mergedVisits.append(localVisit)
                }
            }

            savedGyms = mergedGyms.sorted { $0.name < $1.name }
            visits = mergedVisits.sorted { $0.arrivedAt > $1.arrivedAt }
            saveGyms()
            saveVisits()
            restartMonitoring()
            await refreshActivityAndNotifications()
        } catch {
            #if DEBUG
            print("Gym sync refresh failed: \(error)")
            #endif
        }
    }

    private func samePlace(_ lhs: GymLocation, _ rhs: GymLocation) -> Bool {
        lhs.name == rhs.name &&
        abs(lhs.latitude - rhs.latitude) < 0.0001 &&
        abs(lhs.longitude - rhs.longitude) < 0.0001
    }

    private static func addressString(for placemark: MKPlacemark) -> String? {
        let parts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func chainName(for name: String, fallback: String) -> String {
        KnownGymChain.allCases.first(where: {
            name.localizedCaseInsensitiveContains($0.rawValue)
        })?.rawValue ?? fallback
    }

    private func requestFullAccuracyForGymArrival() {
        guard #available(iOS 14.0, *), manager.accuracyAuthorization == .reducedAccuracy else {
            return
        }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "GymArrivalPrecision")
    }

    private func freshLocationForSearch() async throws -> CLLocation {
        guard searchLocationContinuation == nil else {
            throw GymLocationServiceError.locationRequestInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            searchLocationContinuation = continuation
            isLocatingForSearch = true
            locationErrorMessage = nil
            proximityCheckMessage = "Finding your current location before searching Apple Maps..."

            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                beginSearchLocationUpdates()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .restricted:
                completeSearchLocationRequest(
                    with: .failure(GymLocationServiceError.locationRestricted)
                )
            case .denied:
                completeSearchLocationRequest(
                    with: .failure(GymLocationServiceError.locationDenied)
                )
            @unknown default:
                completeSearchLocationRequest(
                    with: .failure(GymLocationServiceError.locationUnavailable)
                )
            }
        }
    }

    private func beginSearchLocationUpdates() {
        guard searchLocationContinuation != nil else { return }

        requestFullAccuracyForGymArrival()
        manager.startUpdatingLocation()
        searchLocationTimeoutTask?.cancel()
        searchLocationTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 12_000_000_000)
            } catch {
                return
            }

            await MainActor.run {
                self?.completeSearchLocationRequest(
                    with: .failure(GymLocationServiceError.locationTimedOut)
                )
            }
        }
    }

    private func completeSearchLocationRequest(with result: Result<CLLocation, Error>) {
        guard let continuation = searchLocationContinuation else { return }

        searchLocationContinuation = nil
        searchLocationTimeoutTask?.cancel()
        searchLocationTimeoutTask = nil
        isLocatingForSearch = false
        manager.stopUpdatingLocation()

        switch result {
        case .success(let location):
            latestLocationFix = location
            proximityCheckMessage = "Current location updated with ±\(Int(location.horizontalAccuracy.rounded()))m accuracy."
            continuation.resume(returning: location)
        case .failure(let error):
            locationErrorMessage = error.localizedDescription
            proximityCheckMessage = nil
            continuation.resume(throwing: error)
        }
    }

    private func saveEntrancePin(for gymId: UUID, location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= GymLocation.maximumAutomaticCheckInHorizontalAccuracyMeters,
              location.timestamp.timeIntervalSinceNow >= -GymLocation.maximumAutomaticLocationAge,
              let index = savedGyms.firstIndex(where: { $0.id == gymId }) else {
            locationErrorMessage = "The entrance pin needs a fresh, accurate location. Stay at the door and try again."
            return
        }

        savedGyms[index].entranceLatitude = location.coordinate.latitude
        savedGyms[index].entranceLongitude = location.coordinate.longitude
        let pinnedGym = savedGyms[index]
        saveGyms()
        restartMonitoring()
        proximityCheckMessage = "Entrance pin saved for \(pinnedGym.name). Automatic check-in now requires the 10 ft arrival proof."

        Task {
            await syncGym(pinnedGym)
        }
    }

    @discardableResult
    private func logAutomaticVisitIfNeeded(for gym: GymLocation) -> Bool {
        guard !GymVisitReceiptPolicy.hasReceiptToday(for: gym, visits: visits) else {
            proximityCheckMessage = "Already checked in at \(gym.name) today."
            return false
        }

        let visit = GymVisit(
            gymLocationId: gym.id,
            gymName: gym.name,
            source: .geofence
        )
        visits.insert(visit, at: 0)
        saveVisits()

        Task {
            await syncVisit(visit)
            await refreshActivityAndNotifications()
            await CoachNotificationService.shared.sendImmediateGymCheckInReceipt(gymName: gym.name)
        }

        return true
    }

    private func verifyArrival(from location: CLLocation) {
        let checkedAt = Date()
        let diagnostic = GymCheckInDiagnostic.evaluate(
            location: location,
            savedGyms: savedGyms,
            todaysVisits: todaysVisits(),
            checkedAt: checkedAt
        )
        checkInDiagnostic = diagnostic
        proximityCheckMessage = diagnostic.message

        guard diagnostic.shouldLogAutomaticVisit else {
            if diagnostic.outcome != .awaitingConfirmation {
                pendingAutoCheckIn = nil
                pendingAutoCheckInTask?.cancel()
                pendingAutoCheckInTask = nil
            }
            return
        }

        if GymAutoCheckInDwellPolicy.shouldLogAutomaticVisit(
            pending: pendingAutoCheckIn,
            diagnostic: diagnostic,
            now: checkedAt
        ),
           let gymId = diagnostic.nearestGymId,
           let gym = savedGyms.first(where: { $0.id == gymId }) {
            pendingAutoCheckIn = nil
            pendingAutoCheckInTask?.cancel()
            pendingAutoCheckInTask = nil

            let didLogVisit = logAutomaticVisitIfNeeded(for: gym)
            let finalDiagnostic = GymCheckInDiagnostic.automaticVisitResult(
                for: gym,
                didLogVisit: didLogVisit,
                checkedAt: diagnostic.checkedAt,
                distanceMeters: diagnostic.distanceMeters,
                trigger: .currentLocation
            )
            checkInDiagnostic = finalDiagnostic
            proximityCheckMessage = finalDiagnostic.message
            return
        }

        guard let candidate = GymAutoCheckInDwellPolicy.candidate(from: diagnostic) else {
            return
        }

        if pendingAutoCheckIn?.gymId != candidate.gymId {
            pendingAutoCheckIn = candidate
            scheduleDwellConfirmation()
        }

        let pending = pendingAutoCheckIn ?? candidate
        let secondsRemaining = GymAutoCheckInDwellPolicy.secondsRemaining(
            pending: pending,
            now: checkedAt
        )
        let awaitingDiagnostic = GymCheckInDiagnostic.awaitingConfirmation(
            from: diagnostic,
            secondsRemaining: secondsRemaining
        )
        checkInDiagnostic = awaitingDiagnostic
        proximityCheckMessage = awaitingDiagnostic.message
    }

    private func scheduleDwellConfirmation() {
        pendingAutoCheckInTask?.cancel()
        let delayNanoseconds = UInt64(GymAutoCheckInDwellPolicy.requiredDwellSeconds * 1_000_000_000)
        pendingAutoCheckInTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            await MainActor.run {
                guard let self,
                      self.pendingAutoCheckIn != nil else {
                    return
                }

                self.isCheckingCurrentGymArrival = true
                self.manager.requestLocation()
            }
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: gymsKey),
           let decoded = try? JSONDecoder().decode([GymLocation].self, from: data) {
            savedGyms = decoded
        }

        if let data = UserDefaults.standard.data(forKey: visitsKey),
           let decoded = try? JSONDecoder().decode([GymVisit].self, from: data) {
            visits = decoded.sorted { $0.arrivedAt > $1.arrivedAt }
        }
    }

    private func saveGyms() {
        if let data = try? JSONEncoder().encode(savedGyms) {
            UserDefaults.standard.set(data, forKey: gymsKey)
        }
    }

    private func saveVisits() {
        if let data = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(data, forKey: visitsKey)
        }
    }

    private func syncGym(_ gym: GymLocation) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedGym = try await supabaseService.saveGymLocation(gym)
            if let index = savedGyms.firstIndex(where: { $0.id == gym.id }) {
                savedGyms[index] = savedGym
                saveGyms()
                restartMonitoring()
            }
        } catch {
            #if DEBUG
            print("Gym location sync failed: \(error)")
            #endif
        }
    }

    private func syncVisit(_ visit: GymVisit) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedVisit = try await supabaseService.saveGymVisit(visit)
            if let index = visits.firstIndex(where: { $0.id == visit.id }) {
                visits[index] = savedVisit
                visits.sort { $0.arrivedAt > $1.arrivedAt }
                saveVisits()
                await refreshActivityAndNotifications()
            }
        } catch {
            #if DEBUG
            print("Gym visit sync failed: \(error)")
            #endif
        }
    }

    private func refreshActivityAndNotifications() async {
        _ = await HealthKitService.shared.refreshTodayIfConnected(
            stepGoal: FitnessPlanService.shared.currentPlan?.stepGoal ?? 10_000,
            gymVisits: todaysVisits()
        )
        await CoachNotificationService.shared.rescheduleNotifications()
    }

    private func deleteGymsFromServer(_ gyms: [GymLocation]) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        for gym in gyms {
            do {
                try await supabaseService.deleteGymLocation(gym.id)
            } catch {
                #if DEBUG
                print("Gym delete sync failed: \(error)")
                #endif
            }
        }
    }
}

extension GymLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            restartMonitoring()

            if searchLocationContinuation != nil {
                switch authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    beginSearchLocationUpdates()
                case .denied:
                    completeSearchLocationRequest(
                        with: .failure(GymLocationServiceError.locationDenied)
                    )
                case .restricted:
                    completeSearchLocationRequest(
                        with: .failure(GymLocationServiceError.locationRestricted)
                    )
                case .notDetermined:
                    break
                @unknown default:
                    completeSearchLocationRequest(
                        with: .failure(GymLocationServiceError.locationUnavailable)
                    )
                }
            }

            if shouldVerifyAfterAuthorization,
               authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                shouldVerifyAfterAuthorization = false
                verifyCurrentGymArrival()
            } else if pendingEntrancePinGymId != nil,
               authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                requestFullAccuracyForGymArrival()
                manager.requestLocation()
            } else if authorizationStatus == .authorizedAlways {
                verifyCurrentGymArrival()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationErrorMessage = nil
            guard let location = locations.last else { return }

            if let freshLocation = Self.bestFreshSearchLocation(
                from: locations,
                maximumAge: 60,
                maximumHorizontalAccuracy: 1_000
            ) {
                latestLocationFix = freshLocation
            }

            if searchLocationContinuation != nil,
               let searchLocation = Self.bestFreshSearchLocation(from: locations) {
                completeSearchLocationRequest(with: .success(searchLocation))
            }

            if let gymId = pendingEntrancePinGymId {
                pendingEntrancePinGymId = nil
                saveEntrancePin(for: gymId, location: location)
                return
            }

            guard isCheckingCurrentGymArrival else { return }
            isCheckingCurrentGymArrival = false
            verifyArrival(from: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if searchLocationContinuation != nil {
                if let locationError = error as? CLError,
                   locationError.code == .locationUnknown {
                    return
                }
                completeSearchLocationRequest(with: .failure(error))
            }
            isCheckingCurrentGymArrival = false
            locationErrorMessage = error.localizedDescription
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let gymId = UUID(uuidString: region.identifier),
                  let gym = savedGyms.first(where: { $0.id == gymId }) else {
                return
            }

            proximityCheckMessage = "iOS noticed \(gym.name) nearby. Verifying you are actually close enough before counting it."
            isCheckingCurrentGymArrival = true
            requestFullAccuracyForGymArrival()
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            isMonitoring = false
            monitoredGymCount = manager.monitoredRegions.count
            locationErrorMessage = "iOS could not monitor \(region?.identifier ?? "a saved gym"): \(error.localizedDescription)"
        }
    }
}

enum GymLocationServiceError: LocalizedError {
    case locationDenied
    case locationRestricted
    case locationUnavailable
    case locationTimedOut
    case locationRequestInProgress

    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Location access is denied. Open iPhone Settings and allow location access for nearby gym search."
        case .locationRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Your current location is unavailable right now."
        case .locationTimedOut:
            return "The app could not get a fresh location fix. Move near a window, confirm Precise Location is on, and try again."
        case .locationRequestInProgress:
            return "The app is already updating your current location."
        }
    }
}
