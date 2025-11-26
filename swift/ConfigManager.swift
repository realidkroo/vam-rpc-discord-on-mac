import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    private let configPath: URL
    
    var settings: Settings
    
    init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VAM-RPC").appendingPathComponent("data")
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
        self.configPath = supportDir.appendingPathComponent("config.json")
        
        // Load existing or default
        if let data = try? Data(contentsOf: configPath),
           let loaded = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = loaded
        } else {
            self.settings = Settings.defaultSettings()
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: configPath)
        }
        // Notify system to reload (optional, usually agent watches file or we restart it)
    }
}