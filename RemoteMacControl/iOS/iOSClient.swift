import Foundation
import Network

class iOSClient: ObservableObject {
    @Published var connectionStatus: String = "Disconnected"

    private var browser: NWBrowser?
    private var connection: NWConnection?

    func startBrowsing() {
        // Define the Bonjour service we are looking for. This must match the server.
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_remotemac._tcp", domain: "local")
        browser = NWBrowser(for: descriptor, using: .tcp)

        browser?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                self.connectionStatus = "Searching..."
                print("Browser is ready and searching.")
            case .failed(let error):
                self.connectionStatus = "Search failed: \(error.localizedDescription)"
                self.browser?.cancel()
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { results, changes in
            if let firstResult = results.first {
                // We found a service, now let's connect to it.
                self.connect(to: firstResult.endpoint)
                // Stop browsing once we've found one.
                self.browser?.cancel()
            }
        }

        print("Starting Bonjour browser...")
        browser?.start(queue: .main)
    }

    private func connect(to endpoint: NWEndpoint) {
        // Avoid creating multiple connections
        guard connection == nil else { return }

        print("Connecting to endpoint: \(endpoint)")
        connection = NWConnection(to: endpoint, using: .tcp)

        connection?.stateUpdateHandler = { newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self.connectionStatus = "Connected"
                    print("Connection ready.")
                case .failed(let error):
                    self.connectionStatus = "Connection failed: \(error.localizedDescription)"
                    self.connection?.cancel()
                    self.connection = nil
                case .cancelled:
                    self.connectionStatus = "Disconnected"
                    self.connection = nil
                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    func send(dx: Double, dy: Double, click: Bool) {
        guard let connection = connection else {
            print("Cannot send data, no connection.")
            return
        }

        let controlData = ControlData(dx: dx, dy: dy, click: click)
        do {
            let data = try JSONEncoder().encode(controlData)
            connection.send(content: data, completion: .idempotent)
        } catch {
            print("Failed to encode and send data: \(error)")
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
