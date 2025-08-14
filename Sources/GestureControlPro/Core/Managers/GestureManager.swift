import Foundation
import Vision
import CoreGraphics
import HandVector // Assuming this is how the module is imported

// --- Placeholder Types ---
// These types are based on the documentation. I will implement them later.
class ConfigurationManager {
    static let shared = ConfigurationManager()
    var settings = GestureSettings()
}

struct GestureSettings {
    var isKalmanFilterEnabled = false
    var gestureThreshold: Float = 0.8
}

class KalmanFilter {
    init(initialPoint: CGPoint) {}
    func update(measurement: CGPoint) -> CGPoint { return measurement }
}

class MLPredictionService {
    func predict(landmarks: [HVHandLandmark]) async -> String? {
        // Placeholder for ML prediction
        return nil
    }
}

struct DetectedGesture {
    let type: String // e.g., "click", "drag"
    let position: CGPoint
    let confidence: Float
}


// --- Main Class ---

@MainActor
@Observable
class GestureManager {

    private let mlPredictionService: MLPredictionService
    private let configManager = ConfigurationManager.shared

    // Store the built-in gestures from HandVector
    private var builtinGestures: [String: HVHandInfo] = [:]

    // Kalman filter for index finger tip smoothing
    private var indexTipFilter: KalmanFilter?

    // --- Wave Detection State ---
    private enum WaveDetectionState {
        case idle
        case detecting(startTime: TimeInterval, startPosition: CGPoint, directionChanges: Int)
    }
    private var waveDetectionState: WaveDetectionState = .idle
    private var wristPositionHistory: [CGPoint] = []
    private let waveDetectionThreshold: TimeInterval = 1.0 // 1 second

    init() {
        self.mlPredictionService = MLPredictionService()
        loadBuiltinGestures()
    }

    private func loadBuiltinGestures() {
        // Load the built-in gestures from HandVector's JSON files
        // The HandVector README mentions built-in gestures.
        // I'll assume there's a way to load them like this.
        if let loadedGestures = HVHandInfo.builtinHandInfo {
             self.builtinGestures = loadedGestures
        }
    }

    /// Processes a hand tracking update to detect gestures.
    /// I'm assuming the input is a HVHandInfo object, which is created from a HandAnchor.
    func processHandInfo(_ handInfo: HVHandInfo) async -> DetectedGesture? {

        // --- Kalman Filter for Smoothing ---
        // Get the index finger tip landmark for position tracking
        guard let indexTipLandmark = handInfo.landmarks.first(where: { $0.jointName == .indexTip }) else {
            return nil
        }
        let trackedPoint: CGPoint

        if configManager.settings.isKalmanFilterEnabled {
            if let filter = self.indexTipFilter {
                trackedPoint = filter.update(measurement: indexTipLandmark.position)
            } else {
                self.indexTipFilter = KalmanFilter(initialPoint: indexTipLandmark.position)
                trackedPoint = indexTipLandmark.position
            }
        } else {
            self.indexTipFilter = nil
            trackedPoint = indexTipLandmark.position
        }

        // --- Gesture Recognition ---
        return await recognizeGesture(handInfo: handInfo, trackedPoint: trackedPoint)
    }

    /// Recognizes a gesture from a set of hand landmarks.
    private func recognizeGesture(handInfo: HVHandInfo, trackedPoint: CGPoint) async -> DetectedGesture? {
        let waveResult = recognizeWaveGesture(handInfo: handInfo)
        let cosineResult = recognizeWithCosineSimilarity(handInfo: handInfo)
        let fingerShapeResult = recognizeWithFingerShape(handInfo: handInfo)
        // ML result will be implemented later
        // let mlResult = await recognizeWithML(landmarks: handInfo.landmarks)

        // Fusion logic
        if let finalResult = fuseResults(wave: waveResult, cosine: cosineResult, finger: fingerShapeResult, ml: nil) {
            return DetectedGesture(type: finalResult.gesture, position: trackedPoint, confidence: finalResult.confidence)
        }

        // If no specific gesture is recognized, it's a move.
        return DetectedGesture(type: "move", position: trackedPoint, confidence: 0.5)
    }

    // --- Recognition Methods ---

    private func recognizeWaveGesture(handInfo: HVHandInfo) -> (gesture: String, confidence: Float)? {
        // A wave is an open hand moving horizontally.
        // First, check if the hand is open.
        guard let fingerShape = handInfo.fingerShape() else { return nil }
        let isOpenHand = fingerShape.thumb.fullCurl < 0.3 &&
                         fingerShape.index.fullCurl < 0.3 &&
                         fingerShape.middle.fullCurl < 0.3 &&
                         fingerShape.ring.fullCurl < 0.3 &&
                         fingerShape.little.fullCurl < 0.3

        guard isOpenHand else {
            // If the hand is not open, reset the wave detection state.
            waveDetectionState = .idle
            wristPositionHistory.removeAll()
            return nil
        }

        // Get the wrist position.
        guard let wristLandmark = handInfo.landmarks.first(where: { $0.jointName == .wrist }) else {
            return nil
        }
        let wristPosition = wristLandmark.position

        // Add the current wrist position to the history.
        wristPositionHistory.append(wristPosition)
        // Keep the history at a reasonable size.
        if wristPositionHistory.count > 50 {
            wristPositionHistory.removeFirst()
        }

        // Analyze the history for horizontal movement.
        if wristPositionHistory.count > 10 {
            let recentHistory = wristPositionHistory.suffix(10)
            let xPositions = recentHistory.map { $0.x }
            let yPositions = recentHistory.map { $0.y }

            let xStdDev = standardDeviation(of: xPositions)
            let yStdDev = standardDeviation(of: yPositions)

            // A wave should have more horizontal movement than vertical.
            if xStdDev > yStdDev * 2.0 && xStdDev > 10.0 {
                 // Check for direction changes
                var directionChanges = 0
                for i in 1..<xPositions.count {
                    let dx = xPositions[i] - xPositions[i-1]
                    let prev_dx = i > 1 ? xPositions[i-1] - xPositions[i-2] : dx
                    if dx * prev_dx < 0 { // Direction changed
                        directionChanges += 1
                    }
                }

                if directionChanges >= 2 {
                    waveDetectionState = .idle
                    wristPositionHistory.removeAll()
                    return (gesture: "wave", confidence: 0.9)
                }
            }
        }

        return nil
    }

    // Helper function to calculate standard deviation
    private func standardDeviation(of values: [CGFloat]) -> CGFloat {
        let mean = values.reduce(0, +) / CGFloat(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(values.count)
        return sqrt(variance)
    }

    private func recognizeWithCosineSimilarity(handInfo: HVHandInfo) -> (gesture: String, confidence: Float)? {
        var bestMatch: (gesture: String, confidence: Float)? = nil

        for (name, gestureInfo) in builtinGestures {
            let similarity = handInfo.similarity(of: .fiveFingers, to: gestureInfo) ?? -1.0
            if similarity > configManager.settings.gestureThreshold {
                if bestMatch == nil || similarity > bestMatch!.confidence {
                    bestMatch = (gesture: name, confidence: Float(similarity))
                }
            }
        }
        return bestMatch
    }

    private func recognizeWithFingerShape(handInfo: HVHandInfo) -> (gesture: String, confidence: Float)? {
        // This method requires defining gesture rules based on finger curl and pinch values.
        guard let fingerShape = handInfo.fingerShape() else { return nil }

        // Rule for "fist"
        let isFist = fingerShape.thumb.fullCurl > 0.8 &&
                     fingerShape.index.fullCurl > 0.8 &&
                     fingerShape.middle.fullCurl > 0.8 &&
                     fingerShape.ring.fullCurl > 0.8 &&
                     fingerShape.little.fullCurl > 0.8
        if isFist {
            return (gesture: "closed_fist", confidence: 0.9)
        }

        // Rule for "open_hand"
        let isOpenHand = fingerShape.thumb.fullCurl < 0.2 &&
                         fingerShape.index.fullCurl < 0.2 &&
                         fingerShape.middle.fullCurl < 0.2 &&
                         fingerShape.ring.fullCurl < 0.2 &&
                         fingerShape.little.fullCurl < 0.2
        if isOpenHand {
            return (gesture: "open_hand", confidence: 0.9)
        }

        // Rule for "point"
        let isPointing = fingerShape.index.fullCurl < 0.2 &&
                         fingerShape.middle.fullCurl > 0.8 &&
                         fingerShape.ring.fullCurl > 0.8 &&
                         fingerShape.little.fullCurl > 0.8
        if isPointing {
            return (gesture: "point", confidence: 0.9)
        }

        // Rule for "click" (pinch)
        // Assuming pinch is the distance to the thumb tip.
        if fingerShape.index.pinch < 0.1 {
            return (gesture: "left_click", confidence: 0.95)
        }

        return nil
    }

    private enum RecognitionMethod {
        case wave
        case cosineSimilarity
        case fingerShape
        case machineLearning
    }

    private func fuseResults(wave: (gesture: String, confidence: Float)?,
                           cosine: (gesture: String, confidence: Float)?,
                           finger: (gesture: String, confidence: Float)?,
                           ml: (gesture: String, confidence: Float)?) -> (gesture: String, confidence: Float)? {

        let weights: [RecognitionMethod: Float] = [
            .wave: 0.5, // High weight for dynamic gestures
            .cosineSimilarity: 0.3,
            .fingerShape: 0.2,
            .machineLearning: 0.3 // ML weight will be used when implemented
        ]

        var scores: [String: Float] = [:]

        if let wave = wave {
            scores[wave.gesture, default: 0] += wave.confidence * (weights[.wave] ?? 0)
        }
        if let cosine = cosine {
            scores[cosine.gesture, default: 0] += cosine.confidence * (weights[.cosineSimilarity] ?? 0)
        }
        if let finger = finger {
            scores[finger.gesture, default: 0] += finger.confidence * (weights[.fingerShape] ?? 0)
        }
        if let ml = ml {
            scores[ml.gesture, default: 0] += ml.confidence * (weights[.machineLearning] ?? 0)
        }

        guard let bestGesture = scores.max(by: { $0.value < $1.value }) else {
            return nil
        }

        // Normalize the confidence score
        let totalWeight = (wave != nil ? weights[.wave]! : 0) +
                          (cosine != nil ? weights[.cosineSimilarity]! : 0) +
                          (finger != nil ? weights[.fingerShape]! : 0) +
                          (ml != nil ? weights[.machineLearning]! : 0)

        let normalizedConfidence = bestGesture.value / max(totalWeight, 0.001) // avoid division by zero

        return (gesture: bestGesture.key, confidence: normalizedConfidence)
    }
}
