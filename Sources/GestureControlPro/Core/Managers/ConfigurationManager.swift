import Foundation
import SwiftUI
import Yams // Import the YAML library

@MainActor
class ConfigurationManager: ObservableObject {

    /// A shared singleton instance for easy access throughout the app.
    static let shared = ConfigurationManager()

    /// The key used to save settings in UserDefaults.
    private let settingsKey = "GestureControlPro.GestureSettings"

    /// Published property that holds the current settings. SwiftUI views can subscribe to this to update automatically.
    @Published var settings: GestureSettings {
        didSet {
            // Save settings whenever they are changed.
            saveSettings()
        }
    }

    /// Holds the gesture definitions loaded from the YAML configuration file.
    /// It's publicly readable but can only be set privately within this class.
    public private(set) var gestureConfig: GestureConfig?

    private init() {
        // Load saved settings on initialization, or use defaults.
        self.settings = Self.loadSettings()
        // Load the gesture configuration from the YAML file.
        loadGestureConfig()
    }

    /// Loads the gesture configurations from the `gestures.yaml` file in the app's main bundle.
    private func loadGestureConfig() {
        // Find the path to the YAML file.
        guard let url = Bundle.main.url(forResource: "gestures", withExtension: "yaml") else {
            print("Error: gestures.yaml not found in bundle.")
            // In a real app, you might want to handle this more gracefully,
            // perhaps by loading a default built-in configuration.
            return
        }

        do {
            // Read the file's contents into a string.
            let yamlString = try String(contentsOf: url)
            // Create a YAML decoder and decode the string into our Swift structs.
            let decoder = YAMLDecoder()
            self.gestureConfig = try decoder.decode(GestureConfig.self, from: yamlString)
            print("✅ Successfully loaded \(gestureConfig?.gestures.count ?? 0) gestures from config.")
        } catch {
            // Handle file reading or YAML parsing errors.
            print("Error loading or parsing gestures.yaml: \(error)")
        }
    }

    /// Saves the current settings to UserDefaults by encoding them to JSON.
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    /// Loads settings from UserDefaults.
    /// - Returns: The saved `GestureSettings` object, or a default one if none is found.
    private static func loadSettings() -> GestureSettings {
        if let data = UserDefaults.standard.data(forKey: "GestureControlPro.GestureSettings") {
            if let decodedSettings = try? JSONDecoder().decode(GestureSettings.self, from: data) {
                return decodedSettings
            }
        }
        // Return default settings if loading fails.
        return GestureSettings()
    }

}
