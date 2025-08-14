import SwiftUI

struct ContentView: View {
    @StateObject private var client = iOSClient()

    // UI & Gesture State
    @State private var isScrollMode = false
    @State private var nextClickIsRight = false
    @State private var lastDragPosition: CGPoint?

    // Visual Feedback State
    @State private var tapLocation: CGPoint?
    @State private var showTapHighlight = false

    var body: some View {
        TabView {
            // MARK: - Trackpad Tab
            trackpadAndControlsView
                .tabItem {
                    Label("Trackpad", systemImage: "cursorarrow")
                }

            // MARK: - Dashboard Tab
            ServerDashboardView(client: client)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.medium")
                }
        }
    }

    // Extracted the main view into a computed property for cleanliness
    private var trackpadAndControlsView: some View {
        VStack(spacing: 0) {
            // MARK: - Connection Bar
            HStack {
                TextField("Server Address (e.g., ws://192.168.1.10:8081)", text: $client.serverAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if client.connectionStatus != "Connected" {
                    Button("Connect") {
                        hideKeyboard()
                        client.connect()
                    }
                } else {
                    Button("Disconnect") {
                        hideKeyboard()
                        client.disconnect()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))

            Text("Status: \(client.connectionStatus)")
                .font(.caption)
                .foregroundColor(statusColor)
                .padding(5)

            // MARK: - Trackpad Area
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isScrollMode ? Color.blue : Color.gray, lineWidth: 2)
                        )

                    Text(trackpadInstructionText)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    if showTapHighlight, let location = tapLocation {
                        Circle()
                            .fill(nextClickIsRight ? Color.red.opacity(0.6) : Color.blue.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .position(location)
                            .transition(.opacity)
                    }
                }
                .gesture(trackpadDragGesture(trackpadSize: geometry.size))
            }
            .padding()


            // MARK: - Control Bar
            VStack {
                HStack(spacing: 15) {
                    Toggle(isOn: $isScrollMode) {
                        Label("Scroll Mode", systemImage: "arrow.up.and.down.circle.fill")
                    }
                    .toggleStyle(.button)
                    .tint(isScrollMode ? .blue : .gray)

                    Button(action: { nextClickIsRight.toggle() }) {
                        Label("Right-Click", systemImage: "cursorarrow.and.square.on.square.dashed")
                    }
                    .tint(nextClickIsRight ? .red : .gray)
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 15) {
                    Button(action: {
                        client.send(action: "key_combo", position: [], metadata: ["keys": ["ctrl", "up"]])
                    }) {
                        Label("Mission Control", systemImage: "square.grid.2x2.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button(action: {
                        // F11 is a common shortcut for showing the desktop
                        client.send(action: "key_press", position: [], metadata: ["key": "f11"])
                    }) {
                        Label("Show Desktop", systemImage: "desktopcomputer")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    // MARK: - Computed Properties & Helper Functions

    private var statusColor: Color {
        switch client.connectionStatus {
        case "Connected":
            return .green
        case "Disconnected", "Error":
            return .red
        default:
            return .orange
        }
    }

    private var trackpadInstructionText: String {
        if isScrollMode {
            return "Drag with one finger to SCROLL"
        }
        if nextClickIsRight {
            return "Tap with one finger for RIGHT-CLICK"
        }
        return "Drag to MOVE\nTap for LEFT-CLICK"
    }

    private func trackpadDragGesture(trackpadSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isScrollMode {
                    handleScroll(value: value, trackpadSize: trackpadSize)
                } else {
                    // For move, we send the absolute normalized position
                    let normalizedPosition = normalize(point: value.location, in: trackpadSize)
                    client.send(action: "move", position: normalizedPosition)
                }
            }
            .onEnded { value in
                // Reset drag position for scroll mode
                self.lastDragPosition = nil

                // Check if the gesture was a tap (very little movement)
                if value.translation.width < 10 && value.translation.height < 10 {
                    handleTap(location: value.location, trackpadSize: trackpadSize)
                }
            }
    }

    private func handleScroll(value: DragGesture.Value, trackpadSize: CGSize) {
        let currentPos = value.location
        guard let lastPos = self.lastDragPosition else {
            self.lastDragPosition = currentPos
            return
        }

        let deltaY = currentPos.y - lastPos.y
        let normalizedPosition = normalize(point: currentPos, in: trackpadSize)

        // Send a scroll command only if the vertical movement is significant
        if abs(deltaY) > 5 {
            let direction = deltaY < 0 ? "up" : "down"
            // The amount can be tuned for sensitivity
            client.send(action: "scroll", position: normalizedPosition, metadata: ["direction": direction, "amount": "3"])
            self.lastDragPosition = currentPos // Update position after a successful scroll event
        }
    }

    private func handleTap(location: CGPoint, trackpadSize: CGSize) {
        let normalizedPosition = normalize(point: location, in: trackpadSize)
        let metadata: [String: String]?

        if nextClickIsRight {
            metadata = ["button": "right"]
            nextClickIsRight = false // Reset after use
        } else {
            metadata = ["button": "left"]
        }

        client.send(action: "click", position: normalizedPosition, metadata: metadata)
        triggerTapHighlight(at: location)
    }

    private func normalize(point: CGPoint, in size: CGSize) -> [Double] {
        // Clamp the values between 0 and 1 to prevent sending out-of-bounds coordinates
        let x = max(0, min(1, point.x / size.width))
        let y = max(0, min(1, point.y / size.height))
        return [x, y]
    }

    private func triggerTapHighlight(at location: CGPoint) {
        self.tapLocation = location
        self.showTapHighlight = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showTapHighlight = false
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
