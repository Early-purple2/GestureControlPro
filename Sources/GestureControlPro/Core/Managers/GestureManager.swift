import Foundation
import CoreGraphics
// This is a placeholder for the actual MediaPipe dependency.
// In a real project, this would be `import MediaPipeTasksVision`.
#if canImport(MediaPipeTasksVision)
import MediaPipeTasksVision
#else
// Define placeholder types if MediaPipe is not available,
// allowing the code to be syntactically correct.
struct Landmark { var x, y, z: Float }
struct MediaPipeResult {
    var landmarks: [[Landmark]] = []
    var worldLandmarks: [[Landmark]] = []
}
class MediaPipeService {}
protocol MediaPipeServiceDelegate {}
#endif

// --- Vector Math Helpers (Unchanged) ---
extension SIMD3 where Scalar == Float {
    static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
    var magnitude: Float { sqrt(SIMD3.dot(self, self)) }
    static func angle(from v1: SIMD3<Float>, to v2: SIMD3<Float>) -> Float {
        let dotProduct = dot(v1, v2)
        let mag1 = v1.magnitude
        let mag2 = v2.magnitude
        if mag1 == 0 || mag2 == 0 { return 0 }
        let cosTheta = min(max(dotProduct / (mag1 * mag2), -1.0), 1.0)
        return acos(cosTheta)
    }
    static func distance(from p1: SIMD3<Float>, to p2: SIMD3<Float>) -> Float { (p2 - p1).magnitude }
}

// --- Custom Data Structures for Hand Landmarks ---
// The raw value is a String to match the YAML config, but the CaseIterable conformance
// allows us to get an ordered list corresponding to MediaPipe's output array.
public enum HandJointName: String, CaseIterable, Codable {
    case wrist, thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

struct HandLandmark {
    let name: HandJointName
    let position: SIMD3<Float>
}

// The output of the gesture manager, ready to be sent to the server.
struct DetectedGesture {
    let id: String
    let position: CGPoint
    let confidence: Float
    let serverAction: String
    let serverMetadata: [String: String]?
}


@MainActor
@Observable
class GestureManager: MediaPipeServiceDelegate {

    private let configManager = ConfigurationManager.shared

    // History trackers for dynamic gestures
    private var wristPositionHistory: [SIMD3<Float>] = []
    private var indexTipPositionHistory: [SIMD3<Float>] = []

    // --- MediaPipeServiceDelegate Conformance (Conceptual) ---
    func mediaPipeService(_ mediaPipeService: MediaPipeService, didFinishWith result: Result<MediaPipeResult, Error>) {
        switch result {
        case .success(let mediaPipeResult):
            guard let worldLandmarks = mediaPipeResult.worldLandmarks.first,
                  let screenLandmarks = mediaPipeResult.landmarks.first else {
                wristPositionHistory.removeAll()
                indexTipPositionHistory.removeAll()
                return
            }
            processLandmarks(worldLandmarks, screenLandmarks: screenLandmarks)
        case .failure(let error):
            print("GestureManager received error: \(error.localizedDescription)")
        }
    }

    // MARK: - Gesture Recognition Pipeline (Refactored)

    private func processLandmarks(_ worldLandmarks: [Landmark], screenLandmarks: [Landmark]) {
        // Map the array of landmarks from MediaPipe to our HandLandmark struct,
        // using the declaration order of HandJointName.allCases.
        let handLandmarks = worldLandmarks.enumerated().compactMap { (index, landmark) -> HandLandmark? in
            guard index < HandJointName.allCases.count else { return nil }
            let jointName = HandJointName.allCases[index]
            return HandLandmark(name: jointName, position: SIMD3<Float>(landmark.x, landmark.y, landmark.z))
        }

        // Update histories for dynamic gestures
        if let wrist = landmark(for: .wrist, in: handLandmarks) {
            wristPositionHistory.append(wrist.position)
            if wristPositionHistory.count > 50 { wristPositionHistory.removeFirst() }
        }
        if let indexTip = landmark(for: .indexTip, in: handLandmarks) {
            indexTipPositionHistory.append(indexTip.position)
            if indexTipPositionHistory.count > 30 { indexTipPositionHistory.removeFirst() }
        }

        // Get the 2D screen position for the cursor from the index tip.
        guard let indexTipIndex = HandJointName.allCases.firstIndex(of: .indexTip) else { return }
        let indexTipScreenLandmark = screenLandmarks[indexTipIndex]
        let trackedPoint2D = CGPoint(x: CGFloat(indexTipScreenLandmark.x), y: CGFloat(indexTipScreenLandmark.y))

        // Run the new data-driven recognition logic.
        if let gesture = recognizeGesture(landmarks: handLandmarks, trackedPoint: trackedPoint2D) {
            // In a real app, this would be delegated back to a coordinator.
            print("Detected Gesture: \(gesture.id) -> \(gesture.serverAction)")
        }
    }

    /// (REWRITTEN) Runs gesture recognition by iterating through the loaded configurations.
    private func recognizeGesture(landmarks: [HandLandmark], trackedPoint: CGPoint) -> DetectedGesture? {
        guard let gestureDefinitions = configManager.gestureConfig?.gestures else {
            return nil
        }

        // Iterate through all enabled gestures defined in the YAML file.
        // The order in the YAML file determines the priority.
        for gestureDef in gestureDefinitions where gestureDef.enabled {
            var recognized = false

            switch gestureDef.trigger.parameters {
            case .pinch(let params):
                recognized = _recognizePinch(landmarks: landmarks, params: params)
            case .fingerPose(let params):
                recognized = _recognizeFingerPose(landmarks: landmarks, params: params)
            case .swipe(let params):
                recognized = _recognizeSwipe(landmarks: landmarks, params: params)
            case .wave(let params):
                recognized = _recognizeWave(landmarks: landmarks, params: params)
            }

            if recognized {
                return DetectedGesture(
                    id: gestureDef.id,
                    position: trackedPoint,
                    confidence: 0.9, // Confidence can be made dynamic later
                    serverAction: gestureDef.serverAction,
                    serverMetadata: gestureDef.serverMetadata
                )
            }
        }

        // If no configured gesture is matched, check for the default 'move' action.
        if let moveGesture = gestureDefinitions.first(where: { $0.id == "move" && $0.enabled }) {
            if case .fingerPose(let params) = moveGesture.trigger.parameters {
                if _recognizeFingerPose(landmarks: landmarks, params: params) {
                     return DetectedGesture(id: "move", position: trackedPoint, confidence: 0.5, serverAction: "move", serverMetadata: nil)
                }
            }
        }

        return nil
    }

    // MARK: - NEW Data-Driven Recognizers

    private func _recognizePinch(landmarks: [HandLandmark], params: PinchParameters) -> Bool {
        guard let finger1Name = HandJointName(rawValue: params.finger1),
              let finger2Name = HandJointName(rawValue: params.finger2),
              let finger1Landmark = landmark(for: finger1Name, in: landmarks),
              let finger2Landmark = landmark(for: finger2Name, in: landmarks) else {
            return false
        }

        let distance = SIMD3<Float>.distance(from: finger1Landmark.position, to: finger2Landmark.position)
        return distance < params.distanceThreshold
    }

    private func _recognizeFingerPose(landmarks: [HandLandmark], params: [FingerPoseParameter]) -> Bool {
        for param in params {
            guard let fingerName = Finger(rawValue: param.finger) else {
                return false // An invalid finger name in config fails the pose
            }

            let isCurled = isFingerCurled(for: fingerName, landmarks: landmarks)

            if (param.state == .curled && !isCurled) || (param.state == .extended && isCurled) {
                return false // This finger's state doesn't match
            }
        }
        return true // All finger states in the config matched
    }

    private func _recognizeSwipe(landmarks: [HandLandmark], params: SwipeParameters) -> Bool {
        let history = indexTipPositionHistory
        let swipeFrames = 10 // This could be a parameter
        guard history.count > swipeFrames else { return false }

        let startPoint = history[history.count - swipeFrames]
        let endPoint = history.last!
        let displacement = endPoint - startPoint
        let distance = displacement.magnitude

        if distance > params.minDistance {
            let matchesDirection: Bool
            switch params.direction {
            case "right":
                matchesDirection = displacement.x > abs(displacement.y) * params.minPrimaryAxisRatio
            case "left":
                matchesDirection = -displacement.x > abs(displacement.y) * params.minPrimaryAxisRatio
            case "up":
                matchesDirection = displacement.y > abs(displacement.x) * params.minPrimaryAxisRatio
            case "down":
                matchesDirection = -displacement.y > abs(displacement.x) * params.minPrimaryAxisRatio
            default:
                matchesDirection = false
            }

            if matchesDirection {
                indexTipPositionHistory.removeAll()
                return true
            }
        }
        return false
    }

    private func _recognizeWave(landmarks: [HandLandmark], params: WaveParameters) -> Bool {
        let history = wristPositionHistory
        guard history.count > 30 else { return false }

        let xPositions = history.map { $0.x }
        let yPositions = history.map { $0.y }
        let xRange = (xPositions.max() ?? 0) - (xPositions.min() ?? 0)
        let yRange = (yPositions.max() ?? 0) - (yPositions.min() ?? 0)

        if xRange > yRange * 1.5 && xRange > params.minDistance {
            var directionChanges = 0
            for i in 2..<xPositions.count {
                if (xPositions[i-1] - xPositions[i-2]) * (xPositions[i] - xPositions[i-1]) < 0 {
                    directionChanges += 1
                }
            }
            if directionChanges >= params.minDirectionChanges {
                wristPositionHistory.removeAll()
                return true
            }
        }
        return false
    }

    // MARK: - Gesture Logic Helpers (Largely Unchanged)

    private func landmark(for joint: HandJointName, in landmarks: [HandLandmark]) -> HandLandmark? {
        return landmarks.first(where: { $0.name == joint })
    }

    private enum Finger: String {
        case thumb, index, middle, ring, little
    }

    private func isFingerCurled(for finger: Finger, landmarks: [HandLandmark]) -> Bool {
        if finger == .thumb {
            guard let tip = landmark(for: .thumbTip, in: landmarks)?.position,
                  let cmc = landmark(for: .thumbCMC, in: landmarks)?.position,
                  let wrist = landmark(for: .wrist, in: landmarks)?.position else { return false }
            return SIMD3<Float>.distance(from: tip, to: wrist) < SIMD3<Float>.distance(from: cmc, to: wrist)
        }

        let mcpJoint, pipJoint, dipJoint, tipJoint: HandJointName
        switch finger {
        case .index: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.indexMCP, .indexPIP, .indexDIP, .indexTip)
        case .middle: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.middleMCP, .middlePIP, .middleDIP, .middleTip)
        case .ring: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.ringMCP, .ringPIP, .ringDIP, .ringTip)
        case .little: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.littleMCP, .littlePIP, .littleDIP, .littleTip)
        }

        guard let mcp = landmark(for: mcpJoint, in: landmarks)?.position,
              let pip = landmark(for: pipJoint, in: landmarks)?.position,
              let dip = landmark(for: dipJoint, in: landmarks)?.position,
              let tip = landmark(for: tipJoint, in: landmarks)?.position else {
            return false
        }

        let v1 = pip - mcp
        let v2 = dip - pip
        let v3 = tip - dip
        let anglePIP = SIMD3<Float>.angle(from: v1, to: v2)
        let angleDIP = SIMD3<Float>.angle(from: v2, to: v3)
        let curlThreshold: Float = 1.745 // ~100 degrees
        return anglePIP < curlThreshold && angleDIP < curlThreshold
    }
}
