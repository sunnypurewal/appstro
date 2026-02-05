import Foundation

public protocol PreferenceService: Sendable {
	func loadPreferences() -> AppPreferences
	func savePrefix(_ prefix: String)
}
