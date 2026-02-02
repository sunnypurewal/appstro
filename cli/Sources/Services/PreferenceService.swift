import Foundation

struct AppPreferences: Codable {
    var lastUsedPrefix: String?
}

struct PreferenceService {
    private let configURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configURL = home.appendingPathComponent(".appstro.json")
    }

    func loadPreferences() -> AppPreferences {
        guard let data = try? Data(contentsOf: configURL),
              let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return prefs
    }

    func savePrefix(_ prefix: String) {
        var prefs = loadPreferences()
        prefs.lastUsedPrefix = prefix
        if let data = try? JSONEncoder().encode(prefs) {
            try? data.write(to: configURL)
        }
    }
}
