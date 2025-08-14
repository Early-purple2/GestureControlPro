import SwiftUI

struct SettingsView: View {

    /// The shared configuration manager, injected as an environment object.
    @StateObject private var configManager = ConfigurationManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Détection des Gestes")) {
                    Toggle(isOn: $configManager.settings.isKalmanFilterEnabled) {
                        Text("Lissage Avancé (Filtre de Kalman)")
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Sensibilité des gestes: \(configManager.settings.gestureSensitivity, specifier: "%.2f")")
                        Slider(value: $configManager.settings.gestureSensitivity, in: 0.1...1.0)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Seuil de confiance: \(configManager.settings.confidenceThreshold, specifier: "%.2f")")
                        Slider(value: $configManager.settings.confidenceThreshold, in: 0.5...1.0)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Réseau")) {
                    HStack {
                        Text("Adresse IP du Serveur")
                        Spacer()
                        TextField("IP Address", text: $configManager.settings.serverIPAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 350)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ConfigurationManager.shared)
    }
}
