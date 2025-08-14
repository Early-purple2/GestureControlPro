import SwiftUI

// This data structure must exactly match the one on the macOS server application.
struct ControlData: Codable {
    let dx: Double
    let dy: Double
    let click: Bool
}

struct ContentView: View {
    // Create and manage the lifecycle of our network client.
    @StateObject private var client = iOSClient()

    // State to track the drag gesture for calculating movement deltas.
    @State private var lastDragPosition: CGPoint?

    var body: some View {
        VStack(spacing: 20) {
            Text("Remote Mac Control")
                .font(.largeTitle)

            // Display the live connection status from the client.
            Text("Status: \(client.connectionStatus)")
                .foregroundColor(client.connectionStatus == "Connected" ? .green : .red)
                .padding()
                .background(Color.black.opacity(0.1))
                .cornerRadius(10)

            // The main area for gestures (the "trackpad").
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))

                Text("Use this area as a trackpad")
                    .foregroundColor(.gray)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let currentPosition = value.location

                        // Calculate the delta from the last known position.
                        let dx = currentPosition.x - (lastDragPosition ?? currentPosition).x
                        let dy = currentPosition.y - (lastDragPosition ?? currentPosition).y

                        // Send move data over the network via the client.
                        client.send(dx: dx, dy: dy, click: false)

                        // Update the last position for the next event.
                        self.lastDragPosition = currentPosition
                    }
                    .onEnded { _ in
                        // Reset when the user lifts their finger.
                        self.lastDragPosition = nil
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        // Send click data over the network via the client.
                        client.send(dx: 0, dy: 0, click: true)
                        print("Tap detected! Sending click.")
                    }
            )

            Spacer()
        }
        .padding()
        .onAppear {
            // Start searching for the Mac server when the view appears.
            client.startBrowsing()
        }
        .onDisappear {
            // Disconnect gracefully when the view is closed.
            client.disconnect()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
