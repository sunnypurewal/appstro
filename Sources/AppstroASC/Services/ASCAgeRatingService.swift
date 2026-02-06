import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCAgeRatingService: AgeRatingService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func updateAgeRatingDeclaration(versionId: String, ratings: SuggestedAgeRatings) async throws {
		var params = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
		params.include = [.ageRatingDeclaration]
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: params)
		let response = try await provider.request(versionEndpoint)
		
		let existingId = response.included?.compactMap { item -> String? in
			if case .ageRatingDeclaration(let decl) = item { return decl.id }
			return nil
		}.first

		guard let id = existingId else {
			throw AppStoreConnectError.apiError("Age rating declaration not found for version \(versionId)")
		}

		typealias Attrs = AgeRatingDeclarationUpdateRequest.Data.Attributes

		func mapLevel<T: RawRepresentable>(_ level: String) -> T? where T.RawValue == String {
			let mappedValue = switch level {
				case "INFREQUENT_MILD": "INFREQUENT_OR_MILD"
				case "FREQUENT_INTENSE": "FREQUENT_OR_INTENSE"
				default: level
			}
			return T(rawValue: mappedValue)
		}

		let attributes = Attrs(
			isAdvertising: ratings.advertising,
			alcoholTobaccoOrDrugUseOrReferences: mapLevel(ratings.alcoholTobaccoOrDrugUseOrReference),
			contests: ratings.gamblingAndContests ? .infrequentOrMild : Attrs.Contests.none,
			isGambling: ratings.gamblingAndContests,
			gamblingSimulated: mapLevel(ratings.gamblingSimulated),
			gunsOrOtherWeapons: mapLevel(ratings.gunsOrOtherWeapons),
			isHealthOrWellnessTopics: ratings.healthOrWellnessTopics,
			kidsAgeBand: mapLevel(ratings.kidsAgeBand ?? ""),
			isLootBox: ratings.isLootBox,
			medicalOrTreatmentInformation: mapLevel(ratings.medicalOrTreatmentInformation),
			isMessagingAndChat: ratings.messagingAndChat != "NONE",
			isParentalControls: ratings.parentalControls,
			profanityOrCrudeHumor: mapLevel(ratings.profanityOrCrudeHumor),
			isAgeAssurance: ratings.ageAssurance,
			sexualContentGraphicAndNudity: mapLevel(ratings.sexualContentGraphicOrNudity),
			sexualContentOrNudity: mapLevel(ratings.sexualContentOrNudity),
			horrorOrFearThemes: mapLevel(ratings.horrorOrFearThemes),
			matureOrSuggestiveThemes: mapLevel(ratings.matureOrSuggestiveThemes),
			isUnrestrictedWebAccess: ratings.unrestrictedWebAccess,
			isUserGeneratedContent: ratings.userGeneratedContent,
			violenceCartoonOrFantasy: mapLevel(ratings.violenceCartoonOrFantasy),
			violenceRealisticProlongedGraphicOrSadistic: mapLevel(ratings.violenceRealisticProlongedGraphicOrSadistic),
			violenceRealistic: mapLevel(ratings.violenceRealistic),
		)

		let updateRequest = AgeRatingDeclarationUpdateRequest(data: .init(type: .ageRatingDeclarations, id: id, attributes: attributes))
		_ = try await provider.request(APIEndpoint.v1.ageRatingDeclarations.id(id).patch(updateRequest))
	}
}
