import SwiftUI

struct ContentView: View {
    @StateObject private var client = iOSClient()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // UI & Gesture State
    @State private var isScrollMode = false
    @State private var nextClickIsRight = false
    @State private var lastDragPosition: CGPoint?

    // Visual Feedback State
    @State private var tapLocation: CGPoint?
    @State private var showTapHighlight = false

    // Keyboard State
    @State private var keyboardText: String = ""

    var body: some View {
        if horizontalSizeClass == .compact {
            tabView
        } else {
            navigationView
        }
    }

    private var tabView: some View {
        TabView {
            trackpadAndControlsView
                .tabItem {
                    Label("Trackpad", systemImage: "cursorarrow")
                }

            keyboardView
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }

            ServerDashboardView(client: client)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.medium")
                }
        }
    }

    private var navigationView: some View {
        NavigationView {
            List {
                NavigationLink(destination: trackpadAndControlsView) {
                    Label("Trackpad", systemImage: "cursorarrow")
                }
                NavigationLink(destination: keyboardView) {
                    Label("Keyboard", systemImage: "keyboard")
                }
                NavigationLink(destination: ServerDashboardView(client: client)) {
                    Label("Dashboard", systemImage: "gauge.medium")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Remote Control")

            trackpadAndControlsView
        }
    }

    // MARK: - Keyboard View
    private var keyboardView: some View {
        VStack {
            Spacer(minLength: 20)
            TextEditor(text: $keyboardText)
                .frame(minHeight: 150, idealHeight: 200, maxHeight: 400)
                .padding(4)
                .background(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding(.horizontal)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            HStack {
                Button(action: {
                    if !keyboardText.isEmpty {
                        client.send(action: "type_text", metadata: ["text": keyboardText])
                        keyboardText = "" // Clear after sending
                    }
                }) {
                    Label("Send", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyboardText.isEmpty)

                Button(action: {
                    hideKeyboard()
                }) {
                    Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
            .padding([.horizontal, .top])


            HStack(spacing: 10) {
                Button(action: { client.send(action: "key_press", metadata: ["key": "enter"]) }) {
                    Label("Enter", systemImage: "return")
                }.buttonStyle(.bordered).tint(.gray)

                Button(action: { client.send(action: "key_press", metadata: ["key": "delete"]) }) {
                    Label("Delete", systemImage: "delete.left.fill")
                }.buttonStyle(.bordered).tint(.gray)

                Button(action: { client.send(action: "key_press", metadata: ["key": "escape"]) }) {
                    Text("Esc")
                }.buttonStyle(.bordered).tint(.gray)
            }
            .padding()

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onTapGesture {
            hideKeyboard()
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
                HStack(spacing: 15) {
                    Button(action: {
                        client.send(action: "copy")
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button(action: {
                        if let pasteboardString = UIPasteboard.general.string {
                            client.send(action: "paste", metadata: ["text": pasteboardString])
                        }
                    }) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button(action: {
                        client.send(action: "translate")
                    }) {
                        Label("Translate", systemImage: "character.bubble")
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
                    handleMove(value: value)
                }
            }
            .onEnded { value in
                // Reset drag position for both modes
                self.lastDragPosition = nil

                // Check if the gesture was a tap (very little movement)
                if !isScrollMode && value.translation.width < 10 && value.translation.height < 10 {
                    handleTap(location: value.location, trackpadSize: trackpadSize)
                }
            }
    }

    private func handleMove(value: DragGesture.Value) {
        let currentPos = value.location
        guard let lastPos = self.lastDragPosition else {
            // First touch event in a drag, just record position
            self.lastDragPosition = currentPos
            return
        }

        // Calculate delta
        let dx = currentPos.x - lastPos.x
        let dy = currentPos.y - lastPos.y

        // Send relative move command if movement is significant enough
        if abs(dx) > 0.1 || abs(dy) > 0.1 {
            // The sensitivity can be tuned
            let sensitivity: CGFloat = 1.5
            client.send(
                action: "move_relative",
                metadata: ["dx": dx * sensitivity, "dy": dy * sensitivity]
            )
            self.lastDragPosition = currentPos // Update position
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
