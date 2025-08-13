import Foundation
import Vision
import CoreGraphics

struct HandLandmark: Identifiable, Codable {
    let id: UUID
    let jointName: VNHumanHandPoseObservation.JointName
    let position: CGPoint
    let confidence: Float
    let timestamp: TimeInterval
    let handedness: Handedness
}

