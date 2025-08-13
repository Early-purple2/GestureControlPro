
import Foundation

struct GestureModel: Codable {
    let type: GestureType
    let referenceHandPose: HandPose
    let displayName: String
    let iconName: String
}
