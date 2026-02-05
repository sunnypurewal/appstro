import AppstroCore
import Foundation

public final class FilePreferenceService: PreferenceService {
	private let configURL: URL

	public init() {
		let home = FileManager.default.homeDirectoryForCurrentUser
		self.configURL = home.appendingPathComponent(".appstro.json")
	}

	public func loadPreferences() -> AppPreferences {
		guard let data = try? Data(contentsOf: configURL),
			  let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
			return AppPreferences()
		}
		return prefs
	}

	public func savePrefix(_ prefix: String) {
		var prefs = loadPreferences()
		prefs.lastUsedPrefix = prefix
		if let data = try? JSONEncoder().encode(prefs) {
			try? data.write(to: configURL)
		}
	}
}
