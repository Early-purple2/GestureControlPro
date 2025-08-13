import Foundation

class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()
    @Published var currentFPS: Double = 0
    @Published var networkLatency: TimeInterval = 0
    func startMonitoring() async { /*...*/ }
    func updateGestureDetectionMetrics(fps: Double, processingTime: TimeInterval) { /*...*/ }
    func updateNetworkMetrics(latency: TimeInterval, bytesSent: Int, bytesReceived: Int) { /*...*/ }
}

