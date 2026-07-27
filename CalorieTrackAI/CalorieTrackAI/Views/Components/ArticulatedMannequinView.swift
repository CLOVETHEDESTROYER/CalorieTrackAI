import RealityKit
import SwiftUI
import UIKit

struct ArticulatedMannequinView: UIViewRepresentable {
    let challengeType: MovementChallengeType
    let isAnimated: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(challengeType: challengeType)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        view.isOpaque = false
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        view.renderOptions = [
            .disableCameraGrain,
            .disableDepthOfField,
            .disableMotionBlur
        ]
        view.isUserInteractionEnabled = false

        context.coordinator.installScene(in: view)
        context.coordinator.setAnimating(isAnimated)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setChallengeType(challengeType)
        context.coordinator.setAnimating(isAnimated)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let rig = ArticulatedMannequinRig()
        private var challengeType: MovementChallengeType
        private weak var camera: PerspectiveCamera?
        private var displayLink: CADisplayLink?
        private var animationStartedAt: CFTimeInterval?

        init(challengeType: MovementChallengeType) {
            self.challengeType = challengeType
        }

        func installScene(in view: ARView) {
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(rig.root)
            view.scene.addAnchor(anchor)

            let camera = PerspectiveCamera()
            self.camera = camera
            configureCamera(camera)
            anchor.addChild(camera)

            let keyLight = PointLight()
            keyLight.light.color = UIColor(white: 1, alpha: 1)
            keyLight.light.intensity = 23_000
            keyLight.light.attenuationRadius = 6
            keyLight.position = [1.3, 1.7, 2.1]
            anchor.addChild(keyLight)

            let fillLight = PointLight()
            fillLight.light.color = UIColor(red: 0.78, green: 1, blue: 0.25, alpha: 1)
            fillLight.light.intensity = 7_500
            fillLight.light.attenuationRadius = 5
            fillLight.position = [-1.5, 0.2, 1.1]
            anchor.addChild(fillLight)

            rig.configure(for: challengeType)
            rig.apply(pose: ChallengeMannequinMotion.pose(for: challengeType, progress: 0))
        }

        func setChallengeType(_ newValue: MovementChallengeType) {
            guard challengeType != newValue else { return }
            challengeType = newValue
            animationStartedAt = nil
            rig.configure(for: newValue)
            rig.apply(pose: ChallengeMannequinMotion.pose(for: newValue, progress: 0))
            if let camera {
                configureCamera(camera)
            }
        }

        func setAnimating(_ shouldAnimate: Bool) {
            guard shouldAnimate else {
                stop()
                rig.apply(pose: ChallengeMannequinMotion.pose(for: challengeType, progress: 0))
                return
            }

            guard displayLink == nil else { return }
            animationStartedAt = nil
            let link = CADisplayLink(target: self, selector: #selector(updateFrame(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            animationStartedAt = nil
        }

        @objc private func updateFrame(_ link: CADisplayLink) {
            if animationStartedAt == nil {
                animationStartedAt = link.timestamp
            }
            let elapsed = link.timestamp - (animationStartedAt ?? link.timestamp)
            let progress = ChallengeMannequinMotion.progress(
                for: challengeType,
                at: elapsed
            )
            rig.apply(
                pose: ChallengeMannequinMotion.pose(
                    for: challengeType,
                    progress: progress
                )
            )
        }

        private func configureCamera(_ camera: PerspectiveCamera) {
            switch challengeType {
            case .pushUp, .plank:
                camera.camera.fieldOfViewInDegrees = 39
                camera.look(
                    at: [0, -0.06, -0.42],
                    from: [0, 0.14, 2.55],
                    relativeTo: nil
                )
            case .squat, .jumpingJack:
                camera.camera.fieldOfViewInDegrees = 42
                camera.look(
                    at: [0, 0.12, 0],
                    from: [0, 0.12, 3.0],
                    relativeTo: nil
                )
            }
        }
    }
}

enum MannequinJoint: CaseIterable, Hashable {
    case head
    case neck
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
}

struct MannequinPose {
    let joints: [MannequinJoint: SIMD3<Float>]

    subscript(_ joint: MannequinJoint) -> SIMD3<Float> {
        joints[joint] ?? .zero
    }
}

enum PushUpMannequinMotion {
    static let cycleDuration: TimeInterval = 3.1

    static func progress(at elapsed: TimeInterval) -> Float {
        let phase = Float(elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration)

        switch phase {
        case 0..<0.16:
            return 0
        case 0.16..<0.46:
            return smoothStep((phase - 0.16) / 0.30)
        case 0.46..<0.60:
            return 1
        case 0.60..<0.90:
            return 1 - smoothStep((phase - 0.60) / 0.30)
        default:
            return 0
        }
    }

    static func pose(progress rawProgress: Float) -> MannequinPose {
        let progress = min(max(rawProgress, 0), 1)
        let chestDrop = 0.23 * progress
        let hipDrop = 0.18 * progress
        let kneeDrop = 0.09 * progress
        let elbowOut = 0.14 * progress

        return MannequinPose(joints: [
            .head: [0, 0.63 - chestDrop, 0.02],
            .neck: [0, 0.45 - chestDrop, 0],
            .leftShoulder: [-0.27, 0.33 - chestDrop, 0],
            .rightShoulder: [0.27, 0.33 - chestDrop, 0],
            .leftElbow: [-0.43 - elbowOut, 0.04 - (0.06 * progress), 0.10],
            .rightElbow: [0.43 + elbowOut, 0.04 - (0.06 * progress), 0.10],
            .leftWrist: [-0.51, -0.26, 0.22],
            .rightWrist: [0.51, -0.26, 0.22],
            .leftHip: [-0.18, 0.18 - hipDrop, -0.46],
            .rightHip: [0.18, 0.18 - hipDrop, -0.46],
            .leftKnee: [-0.16, -0.01 - kneeDrop, -0.82],
            .rightKnee: [0.16, -0.01 - kneeDrop, -0.82],
            .leftAnkle: [-0.16, -0.22, -1.12],
            .rightAnkle: [0.16, -0.22, -1.12]
        ])
    }

    private static func smoothStep(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

enum SquatMannequinMotion {
    static let cycleDuration: TimeInterval = 3.25

    static func progress(at elapsed: TimeInterval) -> Float {
        RepetitionMannequinCurve.progress(
            at: elapsed,
            cycleDuration: cycleDuration
        )
    }

    static func pose(progress rawProgress: Float) -> MannequinPose {
        let progress = min(max(rawProgress, 0), 1)
        let bodyDrop = 0.36 * progress
        let kneeOut = 0.16 * progress

        return MannequinPose(joints: [
            .head: [0, 0.93 - bodyDrop, 0.01],
            .neck: [0, 0.75 - bodyDrop, 0],
            .leftShoulder: [-0.25, 0.64 - bodyDrop, 0],
            .rightShoulder: [0.25, 0.64 - bodyDrop, 0],
            .leftElbow: [-0.29 - (0.08 * progress), 0.27 - (0.05 * progress), 0.05],
            .rightElbow: [0.29 + (0.08 * progress), 0.27 - (0.05 * progress), 0.05],
            .leftWrist: [-0.24 + (0.12 * progress), -0.03 + (0.28 * progress), 0.13],
            .rightWrist: [0.24 - (0.12 * progress), -0.03 + (0.28 * progress), 0.13],
            .leftHip: [-0.17, 0.18 - bodyDrop, -0.03],
            .rightHip: [0.17, 0.18 - bodyDrop, -0.03],
            .leftKnee: [-0.23 - kneeOut, -0.27 - (0.08 * progress), 0.08],
            .rightKnee: [0.23 + kneeOut, -0.27 - (0.08 * progress), 0.08],
            .leftAnkle: [-0.30, -0.73, 0],
            .rightAnkle: [0.30, -0.73, 0]
        ])
    }
}

enum JumpingJackMannequinMotion {
    static let cycleDuration: TimeInterval = 2.45

    static func progress(at elapsed: TimeInterval) -> Float {
        RepetitionMannequinCurve.progress(
            at: elapsed,
            cycleDuration: cycleDuration,
            topHold: 0.08,
            bottomHold: 0.08
        )
    }

    static func pose(progress rawProgress: Float) -> MannequinPose {
        let progress = min(max(rawProgress, 0), 1)
        let bounce = 0.04 * sin(progress * .pi)

        return MannequinPose(joints: [
            .head: [0, 0.92 + bounce, 0],
            .neck: [0, 0.74 + bounce, 0],
            .leftShoulder: [-0.25, 0.63 + bounce, 0],
            .rightShoulder: [0.25, 0.63 + bounce, 0],
            .leftElbow: [-0.30 - (0.24 * progress), 0.25 + (0.61 * progress) + bounce, 0],
            .rightElbow: [0.30 + (0.24 * progress), 0.25 + (0.61 * progress) + bounce, 0],
            .leftWrist: [-0.24 - (0.46 * progress), -0.09 + (1.24 * progress) + bounce, 0],
            .rightWrist: [0.24 + (0.46 * progress), -0.09 + (1.24 * progress) + bounce, 0],
            .leftHip: [-0.16, 0.18 + bounce, 0],
            .rightHip: [0.16, 0.18 + bounce, 0],
            .leftKnee: [-0.15 - (0.20 * progress), -0.27 + bounce, 0],
            .rightKnee: [0.15 + (0.20 * progress), -0.27 + bounce, 0],
            .leftAnkle: [-0.14 - (0.48 * progress), -0.73 + bounce, 0],
            .rightAnkle: [0.14 + (0.48 * progress), -0.73 + bounce, 0]
        ])
    }
}

enum PlankMannequinMotion {
    static let cycleDuration: TimeInterval = 3.8

    static func progress(at elapsed: TimeInterval) -> Float {
        let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        return Float((1 - cos(phase * 2 * .pi)) * 0.5)
    }

    static func pose(progress rawProgress: Float) -> MannequinPose {
        let progress = min(max(rawProgress, 0), 1)
        let breathLift = 0.025 * progress

        return MannequinPose(joints: [
            .head: [0, 0.57 + breathLift, 0.03],
            .neck: [0, 0.40 + breathLift, 0],
            .leftShoulder: [-0.27, 0.28 + breathLift, 0],
            .rightShoulder: [0.27, 0.28 + breathLift, 0],
            .leftElbow: [-0.31, -0.22, 0.14],
            .rightElbow: [0.31, -0.22, 0.14],
            .leftWrist: [-0.24, -0.24, 0.39],
            .rightWrist: [0.24, -0.24, 0.39],
            .leftHip: [-0.18, 0.13, -0.46],
            .rightHip: [0.18, 0.13, -0.46],
            .leftKnee: [-0.16, -0.03, -0.82],
            .rightKnee: [0.16, -0.03, -0.82],
            .leftAnkle: [-0.16, -0.22, -1.12],
            .rightAnkle: [0.16, -0.22, -1.12]
        ])
    }
}

enum ChallengeMannequinMotion {
    static func progress(
        for challengeType: MovementChallengeType,
        at elapsed: TimeInterval
    ) -> Float {
        switch challengeType {
        case .pushUp:
            return PushUpMannequinMotion.progress(at: elapsed)
        case .squat:
            return SquatMannequinMotion.progress(at: elapsed)
        case .jumpingJack:
            return JumpingJackMannequinMotion.progress(at: elapsed)
        case .plank:
            return PlankMannequinMotion.progress(at: elapsed)
        }
    }

    static func pose(
        for challengeType: MovementChallengeType,
        progress: Float
    ) -> MannequinPose {
        switch challengeType {
        case .pushUp:
            return PushUpMannequinMotion.pose(progress: progress)
        case .squat:
            return SquatMannequinMotion.pose(progress: progress)
        case .jumpingJack:
            return JumpingJackMannequinMotion.pose(progress: progress)
        case .plank:
            return PlankMannequinMotion.pose(progress: progress)
        }
    }
}

private enum RepetitionMannequinCurve {
    static func progress(
        at elapsed: TimeInterval,
        cycleDuration: TimeInterval,
        topHold: Float = 0.16,
        bottomHold: Float = 0.14
    ) -> Float {
        let phase = Float(elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration)
        let movingDuration = (1 - topHold - bottomHold) * 0.5
        let descentEnd = topHold + movingDuration
        let bottomEnd = descentEnd + bottomHold
        let ascentEnd = bottomEnd + movingDuration

        switch phase {
        case 0..<topHold:
            return 0
        case topHold..<descentEnd:
            return smoothStep((phase - topHold) / movingDuration)
        case descentEnd..<bottomEnd:
            return 1
        case bottomEnd..<ascentEnd:
            return 1 - smoothStep((phase - bottomEnd) / movingDuration)
        default:
            return 0
        }
    }

    private static func smoothStep(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

@MainActor
private final class ArticulatedMannequinRig {
    let root = Entity()

    private let ivoryMaterial = SimpleMaterial(
        color: UIColor(red: 0.90, green: 0.91, blue: 0.87, alpha: 1),
        roughness: 0.72,
        isMetallic: false
    )
    private let jointMaterial = SimpleMaterial(
        color: UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1),
        roughness: 0.64,
        isMetallic: false
    )
    private let accentMaterial = SimpleMaterial(
        color: UIColor(red: 0.78, green: 1, blue: 0.20, alpha: 1),
        roughness: 0.58,
        isMetallic: false
    )

    private var jointEntities: [MannequinJoint: ModelEntity] = [:]
    private var segments: [Segment] = []
    private let head: ModelEntity
    private let torso: ModelEntity

    init() {
        head = ModelEntity(
            mesh: .generateSphere(radius: 0.13),
            materials: [ivoryMaterial]
        )
        head.scale = [0.82, 1.08, 0.84]
        root.addChild(head)

        torso = ModelEntity(
            mesh: Self.boneMesh(radius: 0.105),
            materials: [ivoryMaterial]
        )
        torso.scale.x = 1.16
        root.addChild(torso)

        for joint in MannequinJoint.allCases where joint != .head {
            let radius: Float = [.leftShoulder, .rightShoulder, .leftHip, .rightHip].contains(joint)
                ? 0.062
                : 0.052
            let material = [.leftWrist, .rightWrist].contains(joint) ? accentMaterial : jointMaterial
            let entity = ModelEntity(
                mesh: .generateSphere(radius: radius),
                materials: [material]
            )
            jointEntities[joint] = entity
            root.addChild(entity)
        }

        addSegment(.leftShoulder, .rightShoulder, radius: 0.055)
        addSegment(.neck, .leftShoulder, radius: 0.04)
        addSegment(.neck, .rightShoulder, radius: 0.04)
        addSegment(.leftHip, .rightHip, radius: 0.06)
        addSegment(.leftShoulder, .leftElbow, radius: 0.043)
        addSegment(.leftElbow, .leftWrist, radius: 0.038)
        addSegment(.rightShoulder, .rightElbow, radius: 0.043)
        addSegment(.rightElbow, .rightWrist, radius: 0.038)
        addSegment(.leftHip, .leftKnee, radius: 0.054)
        addSegment(.leftKnee, .leftAnkle, radius: 0.046)
        addSegment(.rightHip, .rightKnee, radius: 0.054)
        addSegment(.rightKnee, .rightAnkle, radius: 0.046)

        root.orientation = simd_quatf(angle: -0.08, axis: [0, 1, 0])
        root.scale = [1.12, 1.12, 1.12]
        root.position = [0, -0.05, 0]
    }

    func configure(for challengeType: MovementChallengeType) {
        switch challengeType {
        case .pushUp, .plank:
            root.orientation = simd_quatf(angle: -0.08, axis: [0, 1, 0])
            root.scale = [1.12, 1.12, 1.12]
            root.position = [0, -0.05, 0]
        case .squat, .jumpingJack:
            root.orientation = simd_quatf(angle: -0.04, axis: [0, 1, 0])
            root.scale = [0.92, 0.92, 0.92]
            root.position = [0, -0.05, 0]
        }
    }

    func apply(pose: MannequinPose) {
        for (joint, entity) in jointEntities {
            entity.position = pose[joint]
        }

        head.position = pose[.head]
        update(
            entity: torso,
            from: midpoint(pose[.leftShoulder], pose[.rightShoulder]),
            to: midpoint(pose[.leftHip], pose[.rightHip])
        )

        for segment in segments {
            update(
                entity: segment.entity,
                from: pose[segment.start],
                to: pose[segment.end]
            )
        }
    }

    private func addSegment(
        _ start: MannequinJoint,
        _ end: MannequinJoint,
        radius: Float
    ) {
        let entity = ModelEntity(
            mesh: Self.boneMesh(radius: radius),
            materials: [ivoryMaterial]
        )
        root.addChild(entity)
        segments.append(Segment(start: start, end: end, entity: entity))
    }

    private func update(
        entity: ModelEntity,
        from start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) {
        let direction = end - start
        let length = simd_length(direction)
        guard length > 0.0001 else { return }

        entity.position = midpoint(start, end)
        entity.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: simd_normalize(direction)
        )
        entity.scale.y = length
    }

    private func midpoint(
        _ first: SIMD3<Float>,
        _ second: SIMD3<Float>
    ) -> SIMD3<Float> {
        (first + second) * 0.5
    }

    private static func boneMesh(radius: Float) -> MeshResource {
        .generateBox(
            width: radius * 2,
            height: 1,
            depth: radius * 2,
            cornerRadius: radius
        )
    }

    private struct Segment {
        let start: MannequinJoint
        let end: MannequinJoint
        let entity: ModelEntity
    }
}
