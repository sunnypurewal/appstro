import Foundation

public protocol AppQueryInterpreter: Sendable {
	func interpret(_ parameter: String) -> AppQuery
}
