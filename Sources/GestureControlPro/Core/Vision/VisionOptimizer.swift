import Foundation
import Vision

class VisionOptimizer {
    static func configureOptimalVision() -> VNDetectHumanHandPoseRequest {
        let request = VNDetectHumanHandPoseRequest()

        // Use the most recent and optimized revision of the request.
        request.revision = VNDetectHumanHandPoseRequest.currentRevision

        // Limit the number of hands to detect for performance.
        // The project is designed to control a PC with one hand.
        request.maximumHandCount = 1

        return request
    }
}
