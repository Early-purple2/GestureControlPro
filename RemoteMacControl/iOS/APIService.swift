import Foundation

// MARK: - API Data Structures

struct ServerStatus: Decodable {
    let status: String
    let version: String
    let uptime: Double
    let performance: PerformanceMetrics
    let connected_clients: ConnectedClients

    struct PerformanceMetrics: Decodable {
        let commands_per_second: Double
        let avg_latency_ms: Double
    }

    struct ConnectedClients: Decodable {
        let websocket: Int
    }
}

struct ServerConfig: Decodable {
    let websocket_port: Int
    let udp_port: Int
    let tcp_port: Int
    let host: String
    let gesture_smoothing: Double
    let enable_prediction: Bool
}


// MARK: - APIService Class

class APIService {
    enum APIError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingError(Error)
    }

    /// Fetches the server status from the /api/v1/status endpoint.
    /// - Parameters:
    ///   - serverAddress: The base WebSocket address (e.g., "ws://192.168.1.10:8081"). The service will convert it to an HTTP address.
    ///   - completion: A closure to be called with the result.
    func fetchStatus(webSocketAddress: String, completion: @escaping (Result<ServerStatus, APIError>) -> Void) {
        guard let url = makeApiUrl(from: webSocketAddress, path: "/api/v1/status") else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(with: url, completion: completion)
    }

    /// Fetches the server configuration from the /api/v1/config endpoint.
    func fetchConfig(webSocketAddress: String, completion: @escaping (Result<ServerConfig, APIError>) -> Void) {
        guard let url = makeApiUrl(from: webSocketAddress, path: "/api/v1/config") else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(with: url, completion: completion)
    }

    private func performRequest<T: Decodable>(with url: URL, completion: @escaping (Result<T, APIError>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.requestFailed(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    completion(.failure(.invalidResponse))
                    return
                }

                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }

                do {
                    let decodedObject = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedObject))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }.resume()
    }

    /// Converts a WebSocket address to an HTTP API address.
    /// Example: "ws://192.168.1.10:8081" -> "http://192.168.1.10:8000/api/v1/status"
    private func makeApiUrl(from webSocketAddress: String, path: String) -> URL? {
        guard let wsUrl = URL(string: webSocketAddress), let host = wsUrl.host else {
            return nil
        }
        // The API server runs on port 8000 as per gesture_server.py
        let apiPort = 8000
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = apiPort
        components.path = path
        return components.url
    }
}
