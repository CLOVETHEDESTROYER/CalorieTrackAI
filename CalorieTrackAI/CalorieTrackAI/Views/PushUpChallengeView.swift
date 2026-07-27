import AVFoundation
import SwiftUI
import Vision

struct PushUpChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = MovementChallengeStore.shared
    @ObservedObject private var socialStore = SocialChallengeStore.shared
    let challengeType: MovementChallengeType
    let respondingToChallenge: FitnessChallenge?
    @StateObject private var camera: PushUpCameraModel
    @State private var startedAt: Date?
    @State private var isSaving = false
    @State private var repPulse = false
    @State private var savedSession: MovementChallengeSession?
    @State private var showingSendChallenge = false

    init(
        challengeType: MovementChallengeType = .pushUp,
        respondingToChallenge: FitnessChallenge? = nil
    ) {
        self.challengeType = challengeType
        self.respondingToChallenge = respondingToChallenge
        _camera = StateObject(wrappedValue: PushUpCameraModel(challengeType: challengeType))
    }

    var body: some View {
        ZStack {
            PushUpCameraPreview(
                session: camera.session,
                points: camera.overlayPoints,
                connections: camera.overlayConnections,
                head: camera.overlayHead,
                state: camera.overlayState,
                orientedImageSize: camera.overlayImageSize
            )
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.72), .clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            largeRepCounter

            VStack(spacing: 16) {
                header
                if !camera.isCounting {
                    positioningGuide
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                statusPanel
                controls
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: camera.isCounting)

            if let savedSession {
                completionOverlay(session: savedSession)
            }
        }
        .foregroundColor(.white)
        .onAppear {
            camera.configure()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.isCalibrated) { _, isReady in
            guard isReady else { return }
            startAutomaticallyAfterCalibration()
        }
        .onChange(of: camera.analysis.validRepCount) { previousCount, currentCount in
            guard !challengeType.isTimedHold, currentCount > previousCount else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                repPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                    repPulse = false
                }
            }
        }
        .sheet(isPresented: $showingSendChallenge) {
            if let savedSession {
                SendChallengeView(
                    session: savedSession,
                    onDismiss: {
                        showingSendChallenge = false
                    },
                    onChallengeSent: {
                        // Finish the sheet first, then leave the completed challenge state.
                        // Keeping these actions separate avoids trapping the user in a sheet stack.
                        showingSendChallenge = false
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(challengeType.title)
                    .font(.title2)
                    .fontWeight(.black)
                Text(headerDetail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                camera.stopCounting()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("Close \(challengeType.shortTitle) test")
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                metric(primaryMetricTitle, value: primaryMetricValue, tint: .green)
                metric("Points", value: "\(camera.analysis.pointsAwarded)", tint: .orange)
                metric(tertiaryMetricTitle, value: "\(camera.analysis.rejectedRepCount)", tint: .red)
            }

            Label(camera.statusMessage, systemImage: statusIcon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(
                        camera.isCounting ? "Calibration locked" : (camera.isCalibrated ? "Ready to auto-start" : "Calibrating"),
                        systemImage: camera.isCounting || camera.isCalibrated ? "checkmark.circle.fill" : "timer"
                    )
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(camera.isCalibrated ? .green : .white.opacity(0.8))

                    Spacer()

                    if !camera.isCalibrated {
                        Text("\(Int((camera.calibrationProgress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.78))
                    }
                }

                ProgressView(value: camera.calibrationProgress)
                    .tint(camera.isCalibrated ? .green : .orange)
            }

            Label(
                camera.isPoseVisible ? "Tracking \(camera.visibleJointCount) joints live" : "Looking for your movement",
                systemImage: camera.isPoseVisible ? "dot.radiowaves.left.and.right" : "viewfinder"
            )
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(camera.isPoseVisible ? .green : .white.opacity(0.72))

            if !camera.cameraErrorMessage.isEmpty {
                Text(camera.cameraErrorMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var positioningGuide: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "viewfinder")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(MFTTheme.accent)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.72), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("CAMERA SETUP")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.white.opacity(0.72))

                    Spacer()

                    Text(challengeType.positioningDistance)
                        .font(.caption.monospacedDigit())
                        .fontWeight(.black)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MFTTheme.accent, in: Capsule())
                }

                Text(challengeType.positioningInstruction)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MFTTheme.accent.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Group {
                if camera.isCounting {
                    Label("Challenge live", systemImage: "record.circle.fill")
                } else {
                    Label("Auto-start armed", systemImage: "bolt.fill")
                }
            }
            .font(.headline)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundColor(.white)
            .background(Color.green.opacity(camera.isCounting ? 0.9 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                Task { await finishSession() }
            } label: {
                Label(isSaving ? "Saving" : "Finish", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.orange.opacity(startedAt == nil ? 0.35 : 0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(startedAt == nil || isSaving)
        }
    }

    private var largeRepCounter: some View {
        GeometryReader { proxy in
            if shouldShowLargeCounter {
                VStack(spacing: 0) {
                    Text(primaryMetricValue)
                        .font(.system(size: challengeType.isTimedHold ? 118 : 152, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.75), radius: 8, x: 0, y: 3)

                    Text(challengeType.isTimedHold ? "VERIFIED HOLD" : "VALID REPS")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.white.opacity(0.88))
                        .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(repPulse ? 1.16 : 1)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.43)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(largeCounterAccessibilityLabel)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func completionOverlay(session: MovementChallengeSession) -> some View {
        ZStack {
            Color.black.opacity(0.74)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: completionIcon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(completionTint)

                VStack(spacing: 4) {
                    Text(completionTitle(session: session))
                        .font(.title2)
                        .fontWeight(.black)
                    Text(completionDetail(session: session))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 0) {
                    resultMetric(
                        value: session.challengeType.isTimedHold
                            ? MovementChallengeSession.holdDisplay(seconds: session.durationSeconds)
                            : "\(session.validRepCount)",
                        label: session.challengeType.isTimedHold ? "HOLD" : "REPS"
                    )
                    Divider().overlay(Color.white.opacity(0.18))
                    resultMetric(value: "\(session.pointsAwarded)", label: "POINTS")
                }
                .frame(height: 54)

                if respondingToChallenge == nil,
                   session.competitionScore > 0 {
                    Button {
                        showingSendChallenge = true
                    } label: {
                        Label("Challenge a Friend", systemImage: "paperplane.fill")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") { dismiss() }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(MFTTheme.performance, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(completionTint.opacity(0.55), lineWidth: 1)
            }
            .padding(20)
        }
    }

    private func resultMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.monospacedDigit())
                .fontWeight(.black)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var headerDetail: String {
        if let respondingToChallenge {
            if respondingToChallenge.isTimedHold {
                return "Beat \(respondingToChallenge.challengerScoreDisplay): hold for \(respondingToChallenge.targetScoreDisplay)."
            }
            return "Beat \(respondingToChallenge.challengerScoreDisplay): hit \(respondingToChallenge.targetScoreDisplay) clean reps."
        }
        if challengeType.isTimedHold {
            return "Camera stays on-device. Only verified hold time, breaks, and points are saved."
        }
        return "Camera stays on-device. Only reps and points are saved."
    }

    private var completionIcon: String {
        guard let respondingToChallenge else {
            return "checkmark.seal.fill"
        }
        return respondingToChallenge.target_rep_count <= (savedSession?.competitionScore ?? 0)
            ? "trophy.fill"
            : "arrow.clockwise.circle.fill"
    }

    private var completionTint: Color {
        guard respondingToChallenge != nil else { return MFTTheme.accent }
        return (savedSession?.competitionScore ?? 0) >= (respondingToChallenge?.target_rep_count ?? .max)
            ? MFTTheme.accent
            : MFTTheme.amber
    }

    private func completionTitle(session: MovementChallengeSession) -> String {
        guard let respondingToChallenge else {
            return session.challengeType.isTimedHold ? "Hold verified" : "Set verified"
        }
        return session.competitionScore >= respondingToChallenge.target_rep_count
            ? "You took the lead"
            : "Target survived"
    }

    private func completionDetail(session: MovementChallengeSession) -> String {
        if let error = socialStore.errorMessage, respondingToChallenge != nil {
            return error
        }
        guard let respondingToChallenge else {
            if session.challengeType.isTimedHold {
                return "\(session.competitionScoreDisplay) under tension with \(session.rejectedRepCount) \(session.rejectedRepCount == 1 ? "break" : "breaks"). Send the receipt and make somebody hold longer."
            }
            return "Send the receipt and make somebody earn the comeback."
        }
        if session.competitionScore >= respondingToChallenge.target_rep_count {
            if session.challengeType.isTimedHold {
                return "You held \(session.competitionScoreDisplay). Scoreboard updated."
            }
            return "You cleared the target by \(session.competitionScore - respondingToChallenge.target_rep_count + 1). Scoreboard updated."
        }
        return "You needed \(respondingToChallenge.targetScoreDisplay). The rematch button is emotionally available."
    }

    private func startAutomaticallyAfterCalibration() {
        guard startedAt == nil, !camera.isCounting else { return }
        startedAt = Date()
        camera.resetCounts()
        camera.startCounting()
    }

    private var statusIcon: String {
        switch camera.analysis.quality {
        case .goodRep, .plankHolding:
            return "checkmark.circle.fill"
        case .needFullBody, .needFrontView, .hipsSagging, .holdPlank, .forearmsDown, .holdStill, .rejected:
            return "exclamationmark.triangle.fill"
        case .lower, .squatLower, .standTall, .openWide, .bringItHome:
            return "arrow.down.circle.fill"
        case .ready:
            return "scope"
        }
    }

    private var primaryMetricTitle: String {
        challengeType.isTimedHold ? "Hold" : "Reps"
    }

    private var primaryMetricValue: String {
        if challengeType.isTimedHold {
            return MovementChallengeSession.holdDisplay(seconds: camera.analysis.verifiedHoldSeconds)
        }
        return "\(camera.analysis.validRepCount)"
    }

    private var tertiaryMetricTitle: String {
        challengeType.isTimedHold ? "Breaks" : "Rejected"
    }

    private var shouldShowLargeCounter: Bool {
        challengeType.isTimedHold ? camera.isCounting : camera.analysis.validRepCount > 0
    }

    private var largeCounterAccessibilityLabel: String {
        if challengeType.isTimedHold {
            return "\(Int(camera.analysis.verifiedHoldSeconds.rounded(.down))) verified hold seconds"
        }
        return "\(camera.analysis.validRepCount) valid reps"
    }

    private func metric(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func finishSession() async {
        guard let startedAt else { return }
        isSaving = true
        camera.stopCounting()

        let session = MovementChallengeSession(
            challengeType: challengeType,
            startedAt: startedAt,
            endedAt: Date(),
            durationSeconds: challengeType.isTimedHold ? camera.analysis.verifiedHoldSeconds : nil,
            validRepCount: camera.analysis.validRepCount,
            rejectedRepCount: camera.analysis.rejectedRepCount
        )
        await store.saveSession(session)
        if let respondingToChallenge {
            await socialStore.submitResponse(to: respondingToChallenge, session: session)
        }
        _ = await HealthKitService.shared.refreshTodayIfConnected(
            stepGoal: FitnessPlanService.shared.currentPlan?.stepGoal ?? 10_000,
            gymVisits: GymLocationService.shared.todaysVisits()
        )
        isSaving = false
        savedSession = session
    }
}

fileprivate struct PoseConnection: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
}

fileprivate struct PoseHead {
    let center: CGPoint
    let radius: CGFloat
}

fileprivate enum PoseOverlayState {
    case tracking
    case partial
    case lost

    var tint: UIColor {
        switch self {
        case .tracking: return .systemGreen
        case .partial: return .systemYellow
        case .lost: return .systemRed
        }
    }
}

private struct PushUpCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let points: [CGPoint]
    let connections: [PoseConnection]
    let head: PoseHead?
    let state: PoseOverlayState
    let orientedImageSize: CGSize

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.configurePreviewConnection()
        view.updatePose(
            points: points,
            connections: connections,
            head: head,
            state: state,
            orientedImageSize: orientedImageSize
        )
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.configurePreviewConnection()
        uiView.updatePose(
            points: points,
            connections: connections,
            head: head,
            state: state,
            orientedImageSize: orientedImageSize
        )
    }

    final class PreviewView: UIView {
        private let glowLayer = CAShapeLayer()
        private let skeletonLayer = CAShapeLayer()
        private let jointLayer = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            configure(glowLayer, lineWidth: 12)
            configure(skeletonLayer, lineWidth: 4)
            jointLayer.lineWidth = 1.5
            jointLayer.lineJoin = .round
            layer.addSublayer(glowLayer)
            layer.addSublayer(skeletonLayer)
            layer.addSublayer(jointLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        func configurePreviewConnection() {
            guard let connection = previewLayer.connection else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            glowLayer.frame = bounds
            skeletonLayer.frame = bounds
            jointLayer.frame = bounds
        }

        private func configure(_ shapeLayer: CAShapeLayer, lineWidth: CGFloat) {
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = lineWidth
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
        }

        func updatePose(
            points: [CGPoint],
            connections: [PoseConnection],
            head: PoseHead?,
            state: PoseOverlayState,
            orientedImageSize: CGSize
        ) {
            let skeletonPath = UIBezierPath()
            let jointPath = UIBezierPath()
            let mapper = PortraitPoseOverlayMapper(imageSize: orientedImageSize, bounds: bounds)

            for connection in connections {
                skeletonPath.move(to: mapper.map(connection.start))
                skeletonPath.addLine(to: mapper.map(connection.end))
            }

            if let head {
                let mappedCenter = mapper.map(head.center)
                let mappedRadius = max(mapper.mapHorizontalDistance(head.radius), 14)
                skeletonPath.append(UIBezierPath(
                    ovalIn: CGRect(
                        x: mappedCenter.x - mappedRadius,
                        y: mappedCenter.y - mappedRadius,
                        width: mappedRadius * 2,
                        height: mappedRadius * 2
                    )
                ))
            }

            for point in points {
                let mapped = mapper.map(point)
                jointPath.append(UIBezierPath(ovalIn: CGRect(x: mapped.x - 5, y: mapped.y - 5, width: 10, height: 10)))
            }

            let tint = state.tint
            glowLayer.path = skeletonPath.cgPath
            glowLayer.strokeColor = tint.withAlphaComponent(connections.isEmpty ? 0.22 : 0.35).cgColor

            skeletonLayer.path = skeletonPath.cgPath
            skeletonLayer.strokeColor = tint.withAlphaComponent(0.95).cgColor

            jointLayer.path = jointPath.cgPath
            jointLayer.fillColor = UIColor.white.withAlphaComponent(0.96).cgColor
            jointLayer.strokeColor = tint.withAlphaComponent(0.95).cgColor
        }
    }
}

final class PushUpCameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let portraitVideoRotationAngle: CGFloat = 90

    let session = AVCaptureSession()

    @Published private(set) var analysis: PushUpAnalysisResult
    @Published private(set) var overlayPoints: [CGPoint] = []
    @Published fileprivate var overlayConnections: [PoseConnection] = []
    @Published fileprivate var overlayHead: PoseHead?
    @Published fileprivate var overlayState: PoseOverlayState = .lost
    @Published fileprivate var overlayImageSize = CGSize(width: 9, height: 16)
    @Published private(set) var visibleJointCount = 0
    @Published private(set) var isPoseVisible = false
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var isCalibrated = false
    @Published private(set) var cameraErrorMessage = ""
    @Published private(set) var isCounting = false
    @Published private(set) var canAnalyze = false

    private let challengeType: MovementChallengeType
    private var analyzer: MovementRepAnalyzer
    private var calibrator = MovementChallengeCalibrator()
    private var poseSmoother = MovementPoseSmoother()
    private let videoQueue = DispatchQueue(label: "com.hyperlabsai.pushup-video")
    private let visionQueue = DispatchQueue(label: "com.hyperlabsai.pushup-vision")
    private var isConfigured = false
    private var lastFrameAnalyzedAt = Date.distantPast
    private var lastTrackedBodyAt = Date.distantPast

    init(challengeType: MovementChallengeType = .pushUp) {
        self.challengeType = challengeType
        analyzer = MovementRepAnalyzer(challengeType: challengeType)
        analysis = analyzer.currentResult
        super.init()
    }

    var statusMessage: String {
        if !cameraErrorMessage.isEmpty {
            return cameraErrorMessage
        }

        if !isCounting {
            return calibrator.message(for: challengeType)
        }

        return analysis.quality.message
    }

    var canStartCounting: Bool {
        canAnalyze && isCalibrated
    }

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSessionIfNeeded() : self?.setCameraError("Camera access is off. Open Settings if you want movement points.")
                }
            }
        case .denied, .restricted:
            setCameraError("Camera access is off. Open Settings if you want movement points.")
        @unknown default:
            setCameraError("Camera status is unknown. The camera is being weird, which is rude.")
        }
    }

    func startCounting() {
        guard canStartCounting else { return }
        isCounting = true
    }

    func stopCounting() {
        isCounting = false
    }

    func resetCounts() {
        analyzer.reset()
        analysis = analyzer.currentResult
    }

    func stop() {
        isCounting = false
        guard session.isRunning else { return }
        videoQueue.async { [session] in
            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            startSession()
            return
        }

        videoQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                    AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.setCameraError("No camera found on this device. Simulator life is hard.")
                }
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.setSampleBufferDelegate(self, queue: self.visionQueue)
                guard self.session.canAddOutput(output) else {
                    throw MovementCameraConfigurationError.cannotAddVideoOutput
                }
                self.session.addOutput(output)

                guard let outputConnection = output.connection(with: .video),
                      outputConnection.isVideoRotationAngleSupported(Self.portraitVideoRotationAngle) else {
                    throw MovementCameraConfigurationError.portraitVideoOutputUnavailable
                }
                outputConnection.automaticallyAdjustsVideoMirroring = false
                if outputConnection.isVideoMirroringSupported {
                    outputConnection.isVideoMirrored = true
                }
                outputConnection.videoRotationAngle = Self.portraitVideoRotationAngle

                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isConfigured = true
                    self.canAnalyze = true
                    self.cameraErrorMessage = ""
                }
                self.startSession()
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.setCameraError("Camera setup failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startSession() {
        videoQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func setCameraError(_ message: String) {
        cameraErrorMessage = message
        canAnalyze = false
        isCounting = false
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameAnalyzedAt) >= 0.15 else { return }
        lastFrameAnalyzedAt = now
        let portraitImageSize: CGSize
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            portraitImageSize = CGSize(
                width: CVPixelBufferGetWidth(imageBuffer),
                height: CVPixelBufferGetHeight(imageBuffer)
            )
        } else {
            portraitImageSize = CGSize(width: 9, height: 16)
        }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self else { return }

            if error != nil {
                return
            }

            guard let observation = request.results?.first as? VNHumanBodyPoseObservation,
                  let sample = Self.poseSample(from: observation, timestamp: now) else {
                DispatchQueue.main.async {
                    self.updateCalibrationForLostPose(at: now)
                    if self.isCounting, now.timeIntervalSince(self.lastTrackedBodyAt) > 0.65 {
                        self.analysis = self.analyzer.processLostBody()
                    }
                    self.overlayPoints = []
                    self.overlayConnections = []
                    self.overlayHead = nil
                    self.overlayState = .lost
                    self.visibleJointCount = 0
                    self.isPoseVisible = false
                }
                return
            }

            DispatchQueue.main.async {
                self.lastTrackedBodyAt = now
                // The capture output already delivers portrait-oriented pixels.
                self.overlayImageSize = portraitImageSize
                let smoothedSample = self.poseSmoother.process(sample)
                self.overlayPoints = smoothedSample.allLandmarks
                    .filter(\.isVisible)
                    .map(\.point)
                self.overlayConnections = Self.skeletonConnections(for: smoothedSample)
                self.overlayHead = Self.skeletonHead(for: smoothedSample)
                self.visibleJointCount = self.overlayPoints.count
                self.isPoseVisible = self.visibleJointCount >= 4
                self.overlayState = self.visibleJointCount >= 8 ? .tracking : .partial
                if self.isCounting {
                    self.analysis = self.analyzer.process(sample: smoothedSample)
                } else {
                    self.updateCalibration(with: smoothedSample)
                }
            }
        }

        // The video-data connection physically rotates and mirrors its buffers to match
        // the preview. Vision therefore analyzes upright pixels and returns coordinates
        // that can be drawn directly over the portrait preview.
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
        try? handler.perform([request])
    }

    private static func poseSample(from observation: VNHumanBodyPoseObservation, timestamp: Date) -> PushUpPoseSample? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }

        func landmark(_ joint: VNHumanBodyPoseObservation.JointName) -> PoseLandmark {
            guard let point = points[joint] else { return .missing }
            return PoseLandmark(
                point: CGPoint(x: CGFloat(point.location.x), y: CGFloat(1 - point.location.y)),
                confidence: Double(point.confidence)
            )
        }

        return PushUpPoseSample(
            timestamp: timestamp,
            leftShoulder: landmark(.leftShoulder),
            rightShoulder: landmark(.rightShoulder),
            leftElbow: landmark(.leftElbow),
            rightElbow: landmark(.rightElbow),
            leftWrist: landmark(.leftWrist),
            rightWrist: landmark(.rightWrist),
            leftHip: landmark(.leftHip),
            rightHip: landmark(.rightHip),
            leftKnee: landmark(.leftKnee),
            rightKnee: landmark(.rightKnee),
            leftAnkle: landmark(.leftAnkle),
            rightAnkle: landmark(.rightAnkle),
            face: landmark(.nose)
        )
    }

    private func updateCalibration(with sample: PushUpPoseSample) {
        calibrator.process(sample: sample, challengeType: challengeType)
        calibrationProgress = calibrator.progress
        isCalibrated = calibrator.isReady
    }

    private func updateCalibrationForLostPose(at timestamp: Date) {
        guard !isCounting else { return }
        calibrator.processLostPose(at: timestamp)
        calibrationProgress = calibrator.progress
        isCalibrated = calibrator.isReady
        if !isCalibrated {
            poseSmoother.reset()
        }
    }

    private static func skeletonConnections(for sample: PushUpPoseSample) -> [PoseConnection] {
        func connection(_ id: String, _ start: PoseLandmark, _ end: PoseLandmark) -> PoseConnection? {
            guard start.isVisible, end.isVisible else { return nil }
            return PoseConnection(id: id, start: start.point, end: end.point)
        }

        return [
            connection("shoulders", sample.leftShoulder, sample.rightShoulder),
            connection("left-arm-upper", sample.leftShoulder, sample.leftElbow),
            connection("left-arm-lower", sample.leftElbow, sample.leftWrist),
            connection("right-arm-upper", sample.rightShoulder, sample.rightElbow),
            connection("right-arm-lower", sample.rightElbow, sample.rightWrist),
            connection("left-torso", sample.leftShoulder, sample.leftHip),
            connection("right-torso", sample.rightShoulder, sample.rightHip),
            connection("hips", sample.leftHip, sample.rightHip),
            connection("left-leg-upper", sample.leftHip, sample.leftKnee),
            connection("left-leg-lower", sample.leftKnee, sample.leftAnkle),
            connection("right-leg-upper", sample.rightHip, sample.rightKnee),
            connection("right-leg-lower", sample.rightKnee, sample.rightAnkle)
        ].compactMap { $0 }
    }

    private static func skeletonHead(for sample: PushUpPoseSample) -> PoseHead? {
        guard sample.leftShoulder.isVisible, sample.rightShoulder.isVisible else {
            return nil
        }

        let left = sample.leftShoulder.point
        let right = sample.rightShoulder.point
        let shoulderWidth = hypot(right.x - left.x, right.y - left.y)
        guard shoulderWidth > 0.02 else { return nil }

        // A face point follows the actual person in a forearm plank. Vision can lose
        // that point at floor level, so fall back to a modest, non-ceiling-bound offset.
        let center = sample.face.isVisible
            ? sample.face.point
            : CGPoint(
                x: (left.x + right.x) / 2,
                y: (left.y + right.y) / 2 - shoulderWidth * 0.42
            )
        guard center.x >= 0, center.x <= 1, center.y >= 0, center.y <= 1 else {
            return nil
        }

        return PoseHead(center: center, radius: shoulderWidth * 0.34)
    }
}

private enum MovementCameraConfigurationError: LocalizedError {
    case cannotAddVideoOutput
    case portraitVideoOutputUnavailable

    var errorDescription: String? {
        switch self {
        case .cannotAddVideoOutput:
            return "The camera could not create a movement-analysis feed."
        case .portraitVideoOutputUnavailable:
            return "The camera could not create an upright movement-analysis feed."
        }
    }
}
