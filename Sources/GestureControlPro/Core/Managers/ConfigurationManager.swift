import Foundation
import SwiftUI

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

    private init() {
        // Load saved settings on initialization, or use defaults.
        self.settings = Self.loadSettings()
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
