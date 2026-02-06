import Foundation

public protocol AgeRatingService: Sendable {
	func updateAgeRatingDeclaration(versionId: String, ratings: SuggestedAgeRatings) async throws
}
