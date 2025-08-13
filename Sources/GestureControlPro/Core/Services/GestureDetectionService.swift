import Foundation
import Vision
import AVFoundation

class GestureDetectionService {
    private let gestureManager = GestureManager()
    func detect(in buffer: CVPixelBuffer) async throws -> DetectedGesture? {
        return try await gestureManager.processFrame(buffer)
    }
}

