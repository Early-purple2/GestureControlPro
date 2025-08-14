import SwiftUI

struct ServerDashboardView: View {
    // Passed from the parent view, which manages the connection.
    @ObservedObject var client: iOSClient

    private let apiService = APIService()

    @State private var serverStatus: ServerStatus?
    @State private var serverConfig: ServerConfig?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                // Section for Connection Status
                Section(header: Text("Connection")) {
                    LabeledContent("WebSocket", value: client.connectionStatus)
                        .foregroundColor(client.connectionStatus == "Connected" ? .green : .red)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                // Section for Server Status
                Section(header: Text("Server Status")) {
                    if let status = serverStatus {
                        LabeledContent("Status", value: status.status)
                        LabeledContent("Version", value: status.version)
                        LabeledContent("Uptime", value: formatUptime(status.uptime))
                        LabeledContent("WebSocket Clients", value: "\(status.connected_clients.websocket)")
                    } else {
                        Text("No status data available.")
                    }
                }

                // Section for Performance Metrics
                Section(header: Text("Real-time Performance")) {
                    if let status = serverStatus {
                        LabeledContent("Commands/sec", value: String(format: "%.1f", status.performance.commands_per_second))
                        LabeledContent("Avg. Latency", value: String(format: "%.2f ms", status.performance.avg_latency_ms))
                    } else {
                        Text("No performance data available.")
                    }
                }

                // Section for Server Configuration
                Section(header: Text("Server Configuration")) {
                    if let config = serverConfig {
                        LabeledContent("Host", value: config.host)
                        LabeledContent("WebSocket Port", value: "\(config.websocket_port)")
                        Labeled-Content("Prediction Enabled", value: config.enable_prediction ? "Yes" : "No")
                        LabeledContent("Gesture Smoothing", value: String(format: "%.2f", config.gesture_smoothing))
                    } else {
                        Text("No configuration data available.")
                    }
                }
            }
            .navigationTitle("Server Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: fetchData) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear(perform: fetchData)
        }
    }

    private func fetchData() {
        isLoading = true
        errorMessage = nil

        let address = client.serverAddress

        // Create a dispatch group to wait for both API calls
        let group = DispatchGroup()

        group.enter()
        apiService.fetchStatus(webSocketAddress: address) { result in
            switch result {
            case .success(let status):
                self.serverStatus = status
            case .failure(let error):
                self.errorMessage = "Failed to fetch status: \(error.localizedDescription)"
            }
            group.leave()
        }

        group.enter()
        apiService.fetchConfig(webSocketAddress: address) { result in
            switch result {
            case .success(let config):
                self.serverConfig = config
            case .failure(let error):
                if self.errorMessage == nil {
                     self.errorMessage = "Failed to fetch config: \(error.localizedDescription)"
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    private func formatUptime(_ totalSeconds: Double) -> String {
        let seconds = Int(totalSeconds)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// LabeledContent is available in iOS 16+. This is a fallback for older versions.
struct LabeledContent<Content: View>: View {
    let label: Text
    let content: Content

    init(_ title: String, value: String) where Content == Text {
        self.label = Text(title)
        self.content = Text(value) as! Content
    }

    init(@ViewBuilder label: () -> Text, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }

    var body: some View {
        HStack {
            label
            Spacer()
            content.foregroundColor(.gray)
        }
    }
}

struct ServerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy client for the preview
        let client = iOSClient()
        client.connectionStatus = "Connected"

        return ServerDashboardView(client: client)
    }
}
