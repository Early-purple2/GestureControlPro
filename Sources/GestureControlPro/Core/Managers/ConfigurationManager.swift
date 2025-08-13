import Foundation

class ConfigurationManager: ObservableObject {
    @Published var settings = GestureSettings()
    func saveConfiguration() async { /*...*/ }
    func loadConfiguration() async { /*...*/ }
}
