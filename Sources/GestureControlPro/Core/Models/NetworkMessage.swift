import Foundation

struct NetworkMessage: Codable {
    let id: UUID
    let type: MessageType
    let payload: Data
    let timestamp: TimeInterval
    let priority: MessagePriority
}

