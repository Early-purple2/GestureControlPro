import Foundation
import Network
import CoreGraphics

class MacServer {
    let listener: NWListener

    // Define the Bonjour service
    init() {
        let parameters = NWParameters.tcp
        // Using a custom service type "_remotemac._tcp"
        let service = NWListener.Service(name: "RemoteMac", type: "_remotemac._tcp")

        do {
            listener = try NWListener(using: parameters, service: service)
            print("Server: Bonjour service created.")
        } catch {
            fatalError("Server: Failed to create listener: \(error)")
        }
    }

    func start() {
        listener.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("Server: Listener ready on port \(self.listener.port?.debugDescription ?? "N/A").")
            case .failed(let error):
                print("Server: Listener failed with error: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { newConnection in
            print("Server: New connection received from \(newConnection.endpoint).")
            let handler = ConnectionHandler(connection: newConnection)
            handler.start()
        }

        // Start listening for connections.
        listener.start(queue: .main)
        print("Server: Listener started.")
    }
}

// Simple structure to decode control data from the client
struct ControlData: Codable {
    let dx: Double       // Change in x
    let dy: Double       // Change in y
    let click: Bool      // Is it a click event?
}

class ConnectionHandler {
    let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("Connection: Ready to receive data.")
                self.receive()
            case .failed(let error):
                print("Connection: Failed with error: \(error)")
                self.connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                do {
                    let controlData = try JSONDecoder().decode(ControlData.self, from: data)
                    self.handleControlData(controlData)
                } catch {
                    print("Connection: Error decoding data: \(error)")
                }
            }

            if isComplete {
                print("Connection: Connection closed.")
            } else if error == nil {
                // If there's no error and the connection isn't complete, keep listening.
                self.receive()
            }
        }
    }

    private func handleControlData(_ data: ControlData) {
        // Get the current mouse location
        guard let currentLocationCG = CGEvent(source: nil)?.location else {
            print("Error: Could not get current mouse location.")
            return
        }
        let currentLocation = NSPointToCGPoint(currentLocationCG)


        let newLocation = CGPoint(x: currentLocation.x + CGFloat(data.dx), y: currentLocation.y + CGFloat(data.dy))

        // Create a mouse move event
        let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: newLocation,
            mouseButton: .left
        )
        moveEvent?.post(tap: .cgSessionEventTap)
        // print("Moved mouse to \(newLocation.x), \(newLocation.y)") // For debugging

        if data.click {
            print("Executing click.")
            // Create a mouse down event
            let downEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: newLocation,
                mouseButton: .left
            )
            // Create a mouse up event
            let upEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: newLocation,
                mouseButton: .left
            )

            downEvent?.post(tap: .cgSessionEventTap)
            upEvent?.post(tap: .cgSessionEventTap)
        }
    }
}


// --- Main Execution ---
print("Starting Remote Mac server...")
let server = MacServer()
server.start()

// Keep the application running to listen for connections.
RunLoop.main.run()
