import Foundation
import CoreGraphics
import MediaPipeTasksVision

// --- Vector Math Helpers ---
// An extension to provide common 3D vector operations for gesture calculations.
extension SIMD3 where Scalar == Float {
    /// Calculates the dot product of two vectors.
    static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }

    /// Calculates the magnitude (length) of the vector.
    var magnitude: Float {
        return sqrt(SIMD3.dot(self, self))
    }

    /// Calculates the angle in radians between two vectors.
    static func angle(from v1: SIMD3<Float>, to v2: SIMD3<Float>) -> Float {
        let dotProduct = dot(v1, v2)
        let mag1 = v1.magnitude
        let mag2 = v2.magnitude
        // Avoid division by zero
        if mag1 == 0 || mag2 == 0 { return 0 }
        // Clamp the cosine value to the valid range [-1, 1] to prevent domain errors from floating point inaccuracies.
        let cosTheta = min(max(dotProduct / (mag1 * mag2), -1.0), 1.0)
        return acos(cosTheta)
    }

    /// Calculates the Euclidean distance between two points.
    static func distance(from p1: SIMD3<Float>, to p2: SIMD3<Float>) -> Float {
        return (p2 - p1).magnitude
    }
}

// --- Custom Data Structures for Hand Landmarks ---
/// An enum to map MediaPipe's 21 hand landmark indices to physically meaningful joint names.
public enum HandJointName: Int, CaseIterable {
    case wrist = 0
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

/// A struct to hold information about a single hand landmark, combining its name and 3D position.
/// We use the 'worldLandmarks' from MediaPipe, which are in real-world meters.
struct HandLandmark {
    let name: HandJointName
    let position: SIMD3<Float>
}

// --- Placeholder Types (for context) ---
class ConfigurationManager {
    static let shared = ConfigurationManager()
    var settings = GestureSettings()
}
struct GestureSettings {
    var isKalmanFilterEnabled = false
    var gestureThreshold: Float = 0.8
}
class KalmanFilter {
    init(initialPoint: SIMD3<Float>) {}
    func update(measurement: SIMD3<Float>) -> SIMD3<Float> { return measurement }
}
struct DetectedGesture {
    let type: String
    let position: CGPoint // The 2D screen position for the cursor
    let confidence: Float
}

@MainActor
@Observable
class GestureManager: MediaPipeServiceDelegate {

    private let configManager = ConfigurationManager.shared

    // History trackers for dynamic gestures
    private var wristPositionHistory: [SIMD3<Float>] = []
    private var indexTipPositionHistory: [SIMD3<Float>] = []

    init() {}

    // MARK: - MediaPipeServiceDelegate Conformance

    func mediaPipeService(_ mediaPipeService: MediaPipeService, didFinishWith result: Result<MediaPipeResult, Error>) {
        switch result {
        case .success(let mediaPipeResult):
            // Extract the landmarks for the first detected hand.
            guard let worldLandmarks = mediaPipeResult.worldLandmarks.first,
                  let screenLandmarks = mediaPipeResult.landmarks.first else {
                // No hand detected, reset histories.
                wristPositionHistory.removeAll()
                indexTipPositionHistory.removeAll()
                return
            }
            processLandmarks(worldLandmarks, screenLandmarks: screenLandmarks)
        case .failure(let error):
            print("GestureManager received error: \(error.localizedDescription)")
        }
    }

    func mediaPipeService(_ mediaPipeService: MediaPipeService, didFailWithError error: Error) {
        print("GestureManager received failure: \(error.localizedDescription)")
    }

    // MARK: - Gesture Recognition Pipeline

    /// The main entry point for processing landmark data.
    private func processLandmarks(_ worldLandmarks: [Landmark], screenLandmarks: [Landmark]) {
        // Convert the raw MediaPipe landmarks into our custom, named structure.
        let handLandmarks = worldLandmarks.enumerated().compactMap { (index, landmark) -> HandLandmark? in
            guard let jointName = HandJointName(rawValue: index) else { return nil }
            return HandLandmark(name: jointName, position: SIMD3<Float>(landmark.x, landmark.y, landmark.z))
        }

        // Update position histories for dynamic gesture detection.
        if let wrist = landmark(for: .wrist, in: handLandmarks) {
            wristPositionHistory.append(wrist)
            if wristPositionHistory.count > 50 { wristPositionHistory.removeFirst() } // Keep history size manageable
        }
        if let indexTip = landmark(for: .indexTip, in: handLandmarks) {
            indexTipPositionHistory.append(indexTip)
            if indexTipPositionHistory.count > 30 { indexTipPositionHistory.removeFirst() }
        }

        // Use the 2D screen coordinates of the index tip for the cursor position.
        let indexTipScreenLandmark = screenLandmarks[HandJointName.indexTip.rawValue]
        let trackedPoint2D = CGPoint(x: CGFloat(indexTipScreenLandmark.x), y: CGFloat(indexTipScreenLandmark.y))

        // Run the recognition logic.
        if let gesture = recognizeGesture(landmarks: handLandmarks, trackedPoint: trackedPoint2D) {
            // In a real app, this would be delegated back to a coordinator.
            print("Detected Gesture: \(gesture.type) at \(gesture.position) with confidence \(gesture.confidence)")
        }
    }

    /// Runs the gesture recognition algorithms in a prioritized order.
    private func recognizeGesture(landmarks: [HandLandmark], trackedPoint: CGPoint) -> DetectedGesture? {
        // Priority 1: Check for transient, dynamic gestures first.
        if let swipeResult = recognizeSwipeGesture(landmarks: landmarks) {
            return DetectedGesture(type: swipeResult.gesture, position: trackedPoint, confidence: swipeResult.confidence)
        }
        if let waveResult = recognizeWaveGesture(landmarks: landmarks) {
             return DetectedGesture(type: waveResult.gesture, position: trackedPoint, confidence: waveResult.confidence)
        }

        // Priority 2: Check for sustained, static poses.
        if let fingerShapeResult = recognizeWithFingerShape(landmarks: landmarks) {
             return DetectedGesture(type: fingerShapeResult.gesture, position: trackedPoint, confidence: fingerShapeResult.confidence)
        }

        // Priority 3: If no specific gesture is detected, default to a "move" action.
        return DetectedGesture(type: "move", position: trackedPoint, confidence: 0.5)
    }

    // MARK: - Dynamic Gesture Recognizers

    private func recognizeSwipeGesture(landmarks: [HandLandmark]) -> (gesture: String, confidence: Float)? {
        // A swipe is a fast movement with a pointing finger.
        let isPointing = !isFingerCurled(for: .index, landmarks: landmarks) &&
                          isFingerCurled(for: .middle, landmarks: landmarks) &&
                          isFingerCurled(for: .ring, landmarks: landmarks) &&
                          isFingerCurled(for: .little, landmarks: landmarks)
        guard isPointing else { return nil }

        // A swipe is a quick gesture, so we check over a short history.
        let history = indexTipPositionHistory
        let swipeFrames = 10 // Analyze the last 10 frames
        guard history.count > swipeFrames else { return nil }

        let startPoint = history[history.count - swipeFrames]
        let endPoint = history.last!

        let displacement = endPoint - startPoint
        let distance = displacement.magnitude

        // These thresholds are crucial for performance and need real-world tuning.
        // They are based on the world coordinate system (meters).
        let minDistance: Float = 0.15 // about 15cm
        let minPrimaryAxisRatio: Float = 2.5 // Movement must be 2.5x more horizontal than vertical

        if distance > minDistance {
            if abs(displacement.x) > abs(displacement.y) * minPrimaryAxisRatio {
                indexTipPositionHistory.removeAll() // Reset after detection to prevent re-triggering
                return (gesture: displacement.x > 0 ? "swipe_right" : "swipe_left", confidence: 0.9)
            }
        }
        return nil
    }

    private func recognizeWaveGesture(landmarks: [HandLandmark]) -> (gesture: String, confidence: Float)? {
        // A wave is performed with an open hand.
        let isHandOpen = !isFingerCurled(for: .index, landmarks: landmarks) &&
                         !isFingerCurled(for: .middle, landmarks: landmarks) &&
                         !isFingerCurled(for: .ring, landmarks: landmarks) &&
                         !isFingerCurled(for: .little, landmarks: landmarks)
        guard isHandOpen else {
            wristPositionHistory.removeAll()
            return nil
        }

        let history = wristPositionHistory
        guard history.count > 30 else { return nil }

        let xPositions = history.map { $0.x }
        let yPositions = history.map { $0.y }
        let xRange = (xPositions.max() ?? 0) - (xPositions.min() ?? 0)
        let yRange = (yPositions.max() ?? 0) - (yPositions.min() ?? 0)

        // A wave should be primarily horizontal and cover a minimum distance.
        if xRange > yRange * 1.5 && xRange > 0.1 {
            var directionChanges = 0
            for i in 2..<xPositions.count {
                let dx1 = xPositions[i-1] - xPositions[i-2]
                let dx2 = xPositions[i] - xPositions[i-1]
                if dx1 * dx2 < 0 { directionChanges += 1 } // Detects a change in direction
            }

            // A wave should have at least two changes in direction (e.g., left-right-left).
            if directionChanges >= 2 {
                wristPositionHistory.removeAll()
                return (gesture: "wave", confidence: 0.9)
            }
        }
        return nil
    }

    // MARK: - Static Pose Recognizers

    private func recognizeWithFingerShape(landmarks: [HandLandmark]) -> (gesture: String, confidence: Float)? {
        // Pinch gesture for 'click' has the highest priority among static poses.
        if let thumbTip = landmark(for: .thumbTip, in: landmarks), let indexTip = landmark(for: .indexTip, in: landmarks) {
            let pinchDistance = SIMD3<Float>.distance(from: thumbTip, to: indexTip)
            // This threshold is sensitive and needs tuning. It's in meters. 3cm is a reasonable start.
            if pinchDistance < 0.03 {
                return (gesture: "left_click", confidence: 0.95)
            }
        }

        let indexCurled = isFingerCurled(for: .index, landmarks: landmarks)
        let middleCurled = isFingerCurled(for: .middle, landmarks: landmarks)
        let ringCurled = isFingerCurled(for: .ring, landmarks: landmarks)
        let littleCurled = isFingerCurled(for: .little, landmarks: landmarks)

        if indexCurled && middleCurled && ringCurled && littleCurled { return (gesture: "fist", confidence: 0.9) }
        if !indexCurled && middleCurled && ringCurled && littleCurled { return (gesture: "point", confidence: 0.9) }
        if !indexCurled && !middleCurled && !ringCurled && !littleCurled { return (gesture: "open_hand", confidence: 0.9) }

        return nil
    }

    // MARK: - Gesture Logic Helpers

    private func landmark(for joint: HandJointName, in landmarks: [HandLandmark]) -> SIMD3<Float>? {
        return landmarks.first(where: { $0.name == joint })?.position
    }

    private enum Finger { case thumb, index, middle, ring, little }

    /// Determines if a finger is curled based on the angles of its joints.
    private func isFingerCurled(for finger: Finger, landmarks: [HandLandmark]) -> Bool {
        if finger == .thumb {
            // Thumb curl is complex. A simpler heuristic is to check the distance
            // between the thumb tip and the wrist. This is less accurate but effective.
            guard let tip = landmark(for: .thumbTip, in: landmarks),
                  let cmc = landmark(for: .thumbCMC, in: landmarks),
                  let wrist = landmark(for: .wrist, in: landmarks) else { return false }
            return SIMD3<Float>.distance(from: tip, to: wrist) < SIMD3<Float>.distance(from: cmc, to: wrist)
        }

        let mcpJoint, pipJoint, dipJoint, tipJoint: HandJointName
        switch finger {
        case .index: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.indexMCP, .indexPIP, .indexDIP, .indexTip)
        case .middle: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.middleMCP, .middlePIP, .middleDIP, .middleTip)
        case .ring: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.ringMCP, .ringPIP, .ringDIP, .ringTip)
        case .little: (mcpJoint, pipJoint, dipJoint, tipJoint) = (.littleMCP, .littlePIP, .littleDIP, .littleTip)
        default: return false
        }

        guard let mcp = landmark(for: mcpJoint, in: landmarks), let pip = landmark(for: pipJoint, in: landmarks),
              let dip = landmark(for: dipJoint, in: landmarks), let tip = landmark(for: tipJoint, in: landmarks) else {
            return false
        }

        // Create vectors for each segment of the finger.
        let v1 = pip - mcp // Vector from MCP to PIP
        let v2 = dip - pip // Vector from PIP to DIP
        let v3 = tip - dip  // Vector from DIP to Tip

        // Calculate the angle at the two main joints.
        let anglePIP = SIMD3<Float>.angle(from: v1, to: v2)
        let angleDIP = SIMD3<Float>.angle(from: v2, to: v3)

        // A finger is considered curled if the joint angles are sharp.
        // Straight finger is ~PI radians (180 deg). Curled is < ~PI/2 (90 deg).
        // Using a threshold of 100 degrees (1.745 rad) provides some tolerance.
        let curlThreshold: Float = 1.745
        return anglePIP < curlThreshold && angleDIP < curlThreshold
    }
}
