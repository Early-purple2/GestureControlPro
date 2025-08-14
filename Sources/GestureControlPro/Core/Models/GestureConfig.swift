import Foundation

// Root structure that matches the top-level key in gestures.yaml
struct GestureConfig: Codable {
    let gestures: [GestureDefinition]
}

// Defines a single gesture and its properties
struct GestureDefinition: Codable, Identifiable {
    let id: String
    let name: String
    let enabled: Bool
    let trigger: Trigger
    let serverAction: String
    let serverMetadata: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, trigger
        case serverAction = "server_action"
        case serverMetadata = "server_metadata"
    }
}

// Defines the trigger type and its specific parameters
struct Trigger: Codable {
    let type: TriggerType
    let parameters: TriggerParameters

    // Custom decoding to handle the polymorphic 'parameters' key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TriggerType.self, forKey: .type)

        // Based on the trigger type, decode the corresponding parameters
        switch self.type {
        case .pinch:
            let params = try container.decode(PinchParameters.self, forKey: .parameters)
            self.parameters = .pinch(params)
        case .fingerPose:
            let params = try container.decode([FingerPoseParameter].self, forKey: .parameters)
            self.parameters = .fingerPose(params)
        case .swipe:
            let params = try container.decode(SwipeParameters.self, forKey: .parameters)
            self.parameters = .swipe(params)
        case .wave:
            let params = try container.decode(WaveParameters.self, forKey: .parameters)
            self.parameters = .wave(params)
        }
    }

    // We only need to decode, so encode can be empty.
    func encode(to encoder: Encoder) throws {}

    private enum CodingKeys: String, CodingKey {
        case type, parameters
    }
}


// Enum for the different types of gesture triggers
enum TriggerType: String, Codable {
    case pinch
    case fingerPose = "finger_pose"
    case swipe
    case wave
}

// A wrapper enum for the different parameter structs, which makes the polymorphism possible.
enum TriggerParameters {
    case pinch(PinchParameters)
    case fingerPose([FingerPoseParameter])
    case swipe(SwipeParameters)
    case wave(WaveParameters)
}

// MARK: - Parameter Structs

// Parameters for the 'pinch' trigger
struct PinchParameters: Codable {
    let finger1: String
    let finger2: String
    let distanceThreshold: Float

    private enum CodingKeys: String, CodingKey {
        case finger1, finger2
        case distanceThreshold = "distance_threshold"
    }
}

// A single item in the 'finger_pose' parameters array
struct FingerPoseParameter: Codable {
    let finger: String
    let state: FingerState
}

enum FingerState: String, Codable {
    case curled
    case extended
}

// Parameters for the 'swipe' trigger
struct SwipeParameters: Codable {
    let direction: String
    let minDistance: Float
    let minPrimaryAxisRatio: Float

    private enum CodingKeys: String, CodingKey {
        case direction
        case minDistance = "min_distance"
        case minPrimaryAxisRatio = "min_primary_axis_ratio"
    }
}

// Parameters for the 'wave' trigger
struct WaveParameters: Codable {
    let minDistance: Float
    let minDirectionChanges: Int

    private enum CodingKeys: String, CodingKey {
        case minDistance = "min_distance"
        case minDirectionChanges = "min_direction_changes"
    }
}
