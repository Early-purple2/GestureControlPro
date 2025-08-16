
# ðŸ“š API Reference - GestureControl Pro

RÃ©fÃ©rence complÃ¨te de l'API pour l'intÃ©gration et le dÃ©veloppement avec GestureControl Pro.

## ðŸš€ Vue d'Ensemble

GestureControl Pro expose plusieurs APIs pour diffÃ©rents cas d'usage :

- **Swift API** : IntÃ©gration native macOS/visionOS
- **Network API** : Communication rÃ©seau multi-protocole  
- **REST API** : Interface web et intÃ©gration tierce
- **Plugin API** : Extensions et customisation

## ðŸ“± Swift API

### Core Classes

#### GestureManager

```swift
@MainActor
@Observable
class GestureManager: ObservableObject {
    
    // MARK: - Properties
    var currentGesture: DetectedGesture?
    var handLandmarks: [HandLandmark] = []
    var isTracking: Bool = false
    
    // MARK: - Configuration
    var gestureThreshold: Float = 0.05
    var smoothingFactor: Float = 0.7
    var predictionEnabled: Bool = true
    
    // MARK: - Methods
    func initialize() async throws
    func startTracking() async throws
    func stopTracking()
    func resetCalibration()
    
    // MARK: - Streaming
    var gestureStream: AsyncThrowingStream<DetectedGesture, Error>
}
```

**Usage Example:**
```swift
let gestureManager = GestureManager()

// Initialisation
try await gestureManager.initialize()

// Configuration
gestureManager.gestureThreshold = 0.08
gestureManager.smoothingFactor = 0.6

// Tracking des gestes
for await gesture in gestureManager.gestureStream {
    print("Geste dÃ©tectÃ©: \(gesture.type)")
    
    // Traitement du geste
    switch gesture.type {
    case .leftClick:
        handleLeftClick(at: gesture.position)
    case .drag:
        handleDrag(from: gesture.startPosition, to: gesture.endPosition)
    }
}
```

#### NetworkService

```swift
@MainActor
@Observable 
class NetworkService: ObservableObject {
    
    // MARK: - Properties
    var targetIP: String = "192.168.1.100"
    var targetPort: Int = 8080
    var `protocol`: NetworkProtocol = .websocket
    var isConnected: Bool = false
    var latency: TimeInterval = 0.0
    
    // MARK: - Methods
    func startService() async throws
    func stopService() async
    func sendGestureCommand(_ command: GestureCommand) async throws
    func discoverDevices() async
}
```

**Usage Example:**
```swift
let networkService = NetworkService()

// Configuration
networkService.targetIP = "192.168.1.100"
networkService.protocol = .websocket

// Connexion
try await networkService.startService()

// Envoi de commande
let command = GestureCommand(
    action: .click(.left),
    position: CGPoint(x: 500, y: 300),
    timestamp: CACurrentMediaTime()
)

try await networkService.sendGestureCommand(command)
```

### Data Models

#### GestureType

```swift
enum GestureType: String, CaseIterable, Codable {
    case leftClick = "left_click"
    case rightClick = "right_click"
    case doubleClick = "double_click"
    case drag = "drag"
    case scroll = "scroll"
    case zoom = "zoom"
    case move = "move"
    case pinch = "pinch"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case openHand = "open_hand"
    case closedFist = "closed_fist"
    case peace = "peace"
    case thumbsUp = "thumbs_up"
    case point = "point"
    
    var displayName: String { /* ... */ }
    var systemImage: String { /* ... */ }
}
```

#### HandLandmark

```swift
struct HandLandmark: Identifiable, Codable {
    let id: UUID
    let jointName: VNHumanHandPoseObservation.JointName
    let position: CGPoint
    let confidence: Float
    let timestamp: TimeInterval
    let handedness: Handedness
    
    // Position 3D si disponible (Vision Pro)
    var position3D: SIMD3<Float>?
    
    // Vitesse calculÃ©e
    var velocity: CGVector?
    
    // DonnÃ©es brutes pour ML
    var rawData: [Float] {
        return [
            Float(position.x),
            Float(position.y), 
            confidence,
            Float(timestamp),
            handedness == .left ? 0.0 : 1.0
        ]
    }
}
```

#### GestureCommand

```swift
struct GestureCommand: Codable {
    let id: UUID
    let action: GestureAction
    let position: CGPoint
    let timestamp: TimeInterval
    let metadata: [String: String]
    
    init(action: GestureAction, position: CGPoint, timestamp: TimeInterval)
    
    // SÃ©rialisation optimisÃ©e pour rÃ©seau
    var networkData: Data?
}

enum GestureAction: Codable {
    case click(MouseButton)
    case doubleClick(MouseButton)
    case drag(from: CGPoint, to: CGPoint)
    case scroll(direction: ScrollDirection)
    case zoom(factor: Float)
    case move
    case keyPress(key: KeyCode)
    case keyCombo(keys: [KeyCode])
}
```

### Extensions

#### CGPoint Extensions

```swift
extension CGPoint {
    /// Distance euclidienne vers un autre point
    func distance(to point: CGPoint) -> CGFloat
    
    /// Interpolation linÃ©aire vers un autre point
    func lerp(to point: CGPoint, factor: CGFloat) -> CGPoint
    
    /// Normalisation dans l'Ã©cran
    func normalized(screenSize: CGSize) -> CGPoint
}
```

#### Array Extensions

```swift
extension Array where Element == HandLandmark {
    /// Filtrage par confiance minimum
    func filtered(minimumConfidence: Float) -> [HandLandmark]
    
    /// Groupement par main
    func grouped(by handedness: Handedness) -> [HandLandmark]
    
    /// Conversion vers format ML
    var mlInputVector: [Float]
}
```

## ðŸŒ Network API

### Protocoles SupportÃ©s

#### WebSocket

**Endpoint:** `ws://host:port/`

**Message Format:**
```json
{
  "id": "uuid-v4",
  "type": "gesture_command|translate_command|heartbeat|status|configuration",
  "payload": "base64-encoded-data",
  "timestamp": 1640995200.123,
  "priority": 0-3
}
```

**Examples:**

```json
// Commande de geste
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "gesture_command", 
  "payload": "eyJhY3Rpb24iOiJjbGljayIsInBvc2l0aW9uIjpbNTAwLDMwMF19",
  "timestamp": 1640995200.123,
  "priority": 3
}

// Heartbeat
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "type": "heartbeat",
  "payload": "",
  "timestamp": 1640995201.456,
  "priority": 1
}

// Commande de traduction
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "type": "translate_command",
  "payload": {
    "text": "Hello",
    "to_language": "fr"
  },
  "timestamp": 1640995202.789,
  "priority": 2
}
```

#### UDP

**Format:** Binary Protocol

```
Header (8 bytes):
â”œâ”€â”€ Magic Number (2 bytes): 0xGC01
â”œâ”€â”€ Message Type (1 byte): 0x01=Gesture, 0x02=Heartbeat
â”œâ”€â”€ Payload Length (2 bytes): Network byte order
â”œâ”€â”€ Sequence Number (2 bytes): For ordering
â””â”€â”€ Checksum (1 byte): Simple XOR checksum

Payload (Variable):
â””â”€â”€ JSON data (UTF-8 encoded)
```

**Python Example:**
```python
import struct
import json
import socket

def send_udp_command(sock, command):
    payload = json.dumps(command).encode('utf-8')
    header = struct.pack('>HBBHHB', 
                        0x4743,  # Magic 'GC'
                        0x01,    # Gesture command
                        len(payload),
                        0,       # Sequence
                        sum(payload) & 0xFF)  # Checksum
    
    sock.send(header + payload)
```

#### TCP

**Format:** Length-Prefixed JSON

```
Frame Format:
â”œâ”€â”€ Length (4 bytes): Network byte order, payload length
â””â”€â”€ Payload (Variable): JSON message
```

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| 1000 | SUCCESS | Commande exÃ©cutÃ©e avec succÃ¨s |
| 4000 | BAD_REQUEST | Format de message invalide |
| 4001 | INVALID_GESTURE | Geste non reconnu |
| 4002 | INVALID_POSITION | CoordonnÃ©es hors limites |
| 5000 | INTERNAL_ERROR | Erreur serveur interne |
| 5001 | EXECUTION_FAILED | Ã‰chec d'exÃ©cution de commande |
| 5002 | PERMISSION_DENIED | Permissions insuffisantes |

## ðŸ”Œ REST API

### Base URL
```
http://host:port/api/v1/
```

### Authentication
```http
Authorization: Bearer <api-token>
Content-Type: application/json
```

### Endpoints

#### Status
```http
GET /status
```

**Response:**
```json
{
  "status": "running|stopped|error",
  "version": "1.0.0",
  "uptime": 3600.5,
  "performance": {
    "commands_per_second": 45.2,
    "avg_latency": 0.0068,
    "error_rate": 0.001
  },
  "connections": {
    "websocket": 2,
    "udp": 1, 
    "tcp": 0
  }
}
```

#### Configuration
```http
GET /config
PUT /config
```

**GET Response:**
```json
{
  "gesture_threshold": 0.05,
  "smoothing_factor": 0.7,
  "prediction_enabled": true,
  "supported_gestures": [
    "left_click", "right_click", "drag", "scroll", "zoom"
  ],
  "network": {
    "protocols": ["websocket", "udp", "tcp"],
    "ports": {
      "websocket": 8080,
      "udp": 9090,
      "tcp": 7070
    }
  }
}
```

**PUT Request:**
```json
{
  "gesture_threshold": 0.08,
  "smoothing_factor": 0.6,
  "prediction_enabled": false
}
```

#### Commands (Execute Gesture)
```http
POST /commands
```

**Request:**
```json
{
  "gesture": "left_click",
  "position": [500, 300],
  "metadata": {
    "confidence": 0.95,
    "source": "manual_api"
  }
}
```

**Response:**
```json
{
  "id": "cmd-123456",
  "status": "executed|failed",
  "execution_time": 0.0025,
  "error": null
}
```

#### Translate
```http
POST /api/v1/translate
```

**Request:**
```json
{
  "text": "Hello, world",
  "to_language": "fr"
}
```

**Response:**
```json
{
  "status": "ok",
  "translated_text": "Bonjour le monde"
}
```

#### Metrics
```http
GET /metrics
GET /metrics/export?format=prometheus
```

**Response:**
```json
{
  "timestamp": 1640995200.123,
  "performance": {
    "fps": 118.5,
    "detection_latency": 0.0032,
    "network_latency": 0.0085,
    "ml_inference_time": 0.0015,
    "cpu_usage": 24.5,
    "memory_usage": 512000000,
    "gpu_usage": 31.2,
    "neural_engine_usage": 45.8
  },
  "gesture_accuracy": {
    "left_click": 0.985,
    "right_click": 0.962,
    "drag": 0.948,
    "scroll": 0.971,
    "zoom": 0.935,
    "move": 0.992
  },
  "network_stats": {
    "messages_sent": 15420,
    "messages_received": 1205,
    "bytes_sent": 2048576,
    "bytes_received": 65536,
    "connection_errors": 3
  }
}
```

#### Devices
```http
GET /devices
POST /devices/scan
DELETE /devices/{device_id}
```

**GET Response:**
```json
{
  "devices": [
    {
      "id": "device-001",
      "name": "PC-Gaming",
      "ip_address": "192.168.1.100",
      "type": "windows",
      "status": "connected",
      "latency": 0.0085,
      "last_seen": "2025-08-13T20:15:30Z",
      "capabilities": ["mouse", "keyboard", "scroll"]
    }
  ]
}
```

## ðŸ”§ Plugin API

### Plugin Interface

```swift
protocol GesturePlugin {
    var name: String { get }
    var version: String { get }
    var description: String { get }
    
    func initialize(context: PluginContext) async throws
    func processGesture(_ gesture: DetectedGesture) async -> GestureResult?
    func cleanup() async
}
```

### Custom Gesture Registration

```swift
// Enregistrement d'un geste personnalisÃ©
let customGesture = CustomGestureDefinition(
    name: "victory_sign",
    description: "V-shape with index and middle finger",
    recognitionFunction: { landmarks in
        // Logique de reconnaissance personnalisÃ©e
        return recognizeVictorySign(landmarks)
    }
)

GestureRegistry.shared.register(customGesture)
```

### Event Hooks

```swift
// Hook sur dÃ©tection de geste
GestureManager.shared.onGestureDetected { gesture in
    print("Geste dÃ©tectÃ©: \(gesture.type)")
    
    // Logique personnalisÃ©e
    if gesture.type == .customGesture {
        handleCustomGesture(gesture)
    }
}

// Hook sur erreur rÃ©seau
NetworkService.shared.onNetworkError { error in
    logger.error("Erreur rÃ©seau: \(error)")
    
    // Tentative de reconnexion
    Task {
        try await NetworkService.shared.reconnect()
    }
}
```

## ðŸ“Š Performance API

### Benchmarking

```swift
class PerformanceBenchmark {
    static func measureGestureDetection(
        duration: TimeInterval = 60.0
    ) async -> BenchmarkResult {
        
        let startTime = CACurrentMediaTime()
        var detectionCount = 0
        var totalLatency: TimeInterval = 0
        
        while CACurrentMediaTime() - startTime < duration {
            let gestureStartTime = CACurrentMediaTime()
            
            // Simulation dÃ©tection de geste
            let gesture = await simulateGestureDetection()
            
            let latency = CACurrentMediaTime() - gestureStartTime
            totalLatency += latency
            detectionCount += 1
            
            // Attente frame suivante (120 FPS)
            try await Task.sleep(nanoseconds: 8_333_333) // ~8.33ms
        }
        
        return BenchmarkResult(
            duration: duration,
            gesturesDetected: detectionCount,
            averageLatency: totalLatency / Double(detectionCount),
            averageFPS: Double(detectionCount) / duration
        )
    }
}
```

### Profiling

```swift
@discardableResult
func profile<T>(
    operation: String,
    _ block: () async throws -> T
) async rethrows -> T {
    let startTime = CACurrentMediaTime()
    let result = try await block()
    let duration = CACurrentMediaTime() - startTime
    
    PerformanceProfiler.shared.record(
        operation: operation,
        duration: duration
    )
    
    return result
}

// Usage
let gesture = await profile("gesture_detection") {
    await gestureManager.detectCurrentGesture()
}
```

## âš ï¸ Error Handling

### Swift Errors

```swift
enum GestureControlError: LocalizedError {
    case cameraNotAvailable
    case permissionDenied
    case networkConnectionFailed
    case invalidGestureData
    case calibrationRequired
    case hardwareNotSupported
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "CamÃ©ra non disponible ou dÃ©jÃ  utilisÃ©e"
        case .permissionDenied:
            return "Permissions camÃ©ra non accordÃ©es"
        case .networkConnectionFailed:
            return "Impossible de se connecter au serveur"
        case .invalidGestureData:
            return "DonnÃ©es de geste invalides"
        case .calibrationRequired:
            return "Calibrage requis avant utilisation"
        case .hardwareNotSupported:
            return "Hardware non supportÃ©"
        }
    }
}
```

### Error Recovery

```swift
func handleGestureError(_ error: Error) async {
    switch error {
    case GestureControlError.cameraNotAvailable:
        await showCameraUnavailableAlert()
        await attemptCameraRecovery()
        
    case GestureControlError.networkConnectionFailed:
        await showNetworkErrorAlert()
        await attemptReconnection()
        
    case GestureControlError.calibrationRequired:
        await showCalibrationScreen()
        
    default:
        await showGenericErrorAlert(error)
    }
}
```

## ðŸ” Security

### API Authentication

```swift
class APIAuthentication {
    static func generateAPIToken() -> String {
        let uuid = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970
        let signature = HMAC.sha256(data: "\(uuid):\(timestamp)", key: secretKey)
        
        return "\(uuid):\(timestamp):\(signature)"
    }
    
    static func validateAPIToken(_ token: String) -> Bool {
        let components = token.split(separator: ":")
        guard components.count == 3 else { return false }
        
        let uuid = String(components[0])
        let timestamp = TimeInterval(components[1]) ?? 0
        let providedSignature = String(components[2])
        
        // VÃ©rification timeout (1 heure)
        guard Date().timeIntervalSince1970 - timestamp < 3600 else { return false }
        
        // VÃ©rification signature
        let expectedSignature = HMAC.sha256(data: "\(uuid):\(timestamp)", key: secretKey)
        return providedSignature == expectedSignature
    }
}
```

### Rate Limiting

```swift
actor RateLimiter {
    private var requests: [Date] = []
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    
    init(maxRequests: Int = 100, timeWindow: TimeInterval = 60.0) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func allowRequest() -> Bool {
        let now = Date()
        
        // Nettoyage des anciennes requÃªtes
        requests = requests.filter { 
            now.timeIntervalSince($0) < timeWindow 
        }
        
        guard requests.count < maxRequests else {
            return false
        }
        
        requests.append(now)
        return true
    }
}
```

---

**Cette API complÃ¨te permet une intÃ©gration flexible et performante avec GestureControl Pro pour tous vos besoins de dÃ©veloppement.**
