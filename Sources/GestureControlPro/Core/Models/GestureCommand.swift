import Foundation
import CoreGraphics

struct GestureCommand: Codable {
    let id: UUID
    let action: GestureAction
    let position: CGPoint
    let timestamp: TimeInterval
    let meta [String:String]
}

