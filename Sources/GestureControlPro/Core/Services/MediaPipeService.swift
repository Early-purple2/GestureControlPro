import Foundation
import MediaPipeTasksVision
import AVFoundation
import UIKit

/// A result from the MediaPipe Hand Landmarker, containing the detected landmarks and handedness.
struct MediaPipeResult {
    let landmarks: [[Landmark]]
    let worldLandmarks: [[Landmark]]
    let handedness: [[Handedness]]
}

/// Protocol for a delegate that receives results from the MediaPipeService.
protocol MediaPipeServiceDelegate: AnyObject {
    /// Called when the hand landmarker successfully processes a frame.
    func mediaPipeService(_ mediaPipeService: MediaPipeService, didFinishWith result: Result<MediaPipeResult, Error>)
    /// Called when the hand landmarker fails during processing.
    func mediaPipeService(_ mediaPipeService: MediaPipeService, didFailWithError error: Error)
}

/// This service class encapsulates the setup and execution of the MediaPipe Hand Landmarker task.
class MediaPipeService: NSObject {

    weak var delegate: MediaPipeServiceDelegate?
    private var handLandmarker: HandLandmarker?

    /// Initializes and configures the HandLandmarker.
    /// This method should be called once before starting the video stream.
    func setupHandLandmarker() {
        // Assume the model is bundled with the app.
        // In a production app, you might download this model and store it locally.
        let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task")
        guard let modelPath = modelPath else {
            delegate?.mediaPipeService(self, didFailWithError: MediaPipeError.modelFileNotFound)
            return
        }

        // Configure the HandLandmarker options.
        let options = HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video // Use video mode for continuous stream processing.
        options.numHands = 1 // For this application, we will only track one hand.
        options.minHandDetectionConfidence = 0.5
        options.minHandPresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5

        do {
            handLandmarker = try HandLandmarker(options: options)
        } catch {
            delegate?.mediaPipeService(self, didFailWithError: error)
        }
    }

    /// Processes a single video frame to detect hand landmarks.
    /// - Parameters:
    ///   - videoFrame: The CMSampleBuffer of the video frame to process.
    ///   - timestamp: The timestamp of the frame, in seconds.
    func detect(videoFrame: CMSampleBuffer, timestamp: TimeInterval) {
        guard let handLandmarker = handLandmarker else {
            delegate?.mediaPipeService(self, didFailWithError: MediaPipeError.landmarkerNotInitialized)
            return
        }

        // Convert the CMSampleBuffer to a VisionImage.
        guard let image = try? VisionImage.from(sampleBuffer: videoFrame) else {
            delegate?.mediaPipeService(self, didFailWithError: MediaPipeError.failedToCreateImage)
            return
        }

        // The detection runs synchronously on the current thread.
        do {
            let result = try handLandmarker.detect(videoFrame: image, timestampInMilliseconds: Int(timestamp * 1000))

            let mediaPipeResult = MediaPipeResult(
                landmarks: result.landmarks,
                worldLandmarks: result.worldLandmarks,
                handedness: result.handedness
            )

            // Pass the result back to the delegate.
            delegate?.mediaPipeService(self, didFinishWith: .success(mediaPipeResult))

        } catch {
            delegate?.mediaPipeService(self, didFailWithError: error)
        }
    }
}

/// Custom errors for the MediaPipeService to provide more specific feedback.
enum MediaPipeError: Error {
    case modelFileNotFound
    case landmarkerNotInitialized
    case failedToCreateImage
}
