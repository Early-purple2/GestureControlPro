import Foundation
import Combine

// MARK: - Data Structures for Server Communication

/// Represents the top-level command sent to the server.
struct GestureCommand: Encodable {
    let id: String
    let type: String = "gesture_command"
    let timestamp: TimeInterval
    let payload: Payload

    init(payload: Payload) {
        self.id = UUID().uuidString
        self.timestamp = Date().timeIntervalSince1970
        self.payload = payload
    }
}

/// The actual action and its parameters.
struct Payload: Encodable {
    let action: String
    let position: [Double]
    let metadata: [String: String]?
}

// MARK: - iOSClient Class

class iOSClient: ObservableObject {
    @Published var connectionStatus: String = "Disconnected"
    @Published var serverAddress: String = "ws://192.168.1.10:8081" // Default, user-configurable

    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe changes to the server address to auto-reconnect
        $serverAddress
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // If we are connected, changing the address should trigger a reconnect
                if self?.connectionStatus == "Connected" {
                    self?.disconnect()
                    self?.connect()
                }
            }
            .store(in: &cancellables)
    }

    func connect() {
        guard let url = URL(string: serverAddress) else {
            self.connectionStatus = "Invalid URL"
            return
        }

        // Disconnect any existing session
        disconnect()

        self.connectionStatus = "Connecting..."
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()

        updateConnectionStatus()
        listenForMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        self.connectionStatus = "Disconnected"
    }

    private func updateConnectionStatus() {
        // Note: URLSessionWebSocketTask doesn't have a direct state publisher.
        // We infer state by trying to send a ping and listening for close events.
        // For this implementation, we'll optimistically set to Connected and handle errors.
        // A more robust solution might involve a ping/pong mechanism.
        guard webSocketTask != nil else {
            self.connectionStatus = "Disconnected"
            return
        }
        self.connectionStatus = "Connected"
        print("WebSocket connection established.")
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.connectionStatus = "Error: \(error.localizedDescription)"
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received string: \(text)")
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    fatalError()
                }
                // Continue listening for the next message
                self?.listenForMessages()
            }
        }
    }

    /// Sends a gesture command to the server.
    /// - Parameters:
    ///   - action: The gesture action (e.g., "move", "click").
    ///   - position: Normalized [x, y] coordinates (0.0 to 1.0).
    ///   - metadata: Optional dictionary for extra data (e.g., click button type).
    func send(action: String, position: [Double], metadata: [String: String]? = nil) {
        guard webSocketTask != nil else {
            print("Cannot send command, not connected.")
            return
        }

        let payload = Payload(action: action, position: position, metadata: metadata)
        let command = GestureCommand(payload: payload)

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                 webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("WebSocket send error: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.connectionStatus = "Send Error"
                        }
                    }
                }
            }
        } catch {
            print("Failed to encode GestureCommand: \(error)")
        }
    }
}
