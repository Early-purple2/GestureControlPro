import Foundation

/// A struct to hold all user-configurable gesture settings.
/// This object is managed and persisted by the ConfigurationManager.
struct GestureSettings: Codable {

    // MARK: - Smoothing and Filtering

    /// When true, a Kalman filter is applied to the hand landmarks to reduce jitter.
    var isKalmanFilterEnabled: Bool = false

    // MARK: - Recognition Parameters

    /// The sensitivity for gesture recognition. A higher value means gestures are detected more easily.
    var gestureSensitivity: Double = 0.8

    /// The minimum confidence level required for a gesture to be considered valid.
    var confidenceThreshold: Double = 0.85

    // MARK: - Network Settings

    /// The IP address of the Python server.
    var serverIPAddress: String = "127.0.0.1"

    // MARK: - Initializer

    init(isKalmanFilterEnabled: Bool = false, gestureSensitivity: Double = 0.8, confidenceThreshold: Double = 0.85, serverIPAddress: String = "127.0.0.1") {
        self.isKalmanFilterEnabled = isKalmanFilterEnabled
        self.gestureSensitivity = gestureSensitivity
        self.confidenceThreshold = confidenceThreshold
        self.serverIPAddress = serverIPAddress
    }
}
