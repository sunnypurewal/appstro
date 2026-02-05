import Foundation

public struct SuggestedAgeRatings: Codable, Sendable {
	public let alcoholTobaccoOrDrugUseOrReference: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let gamblingAndContests: Bool
	public let gamblingSimulated: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let horrorOrFearThemes: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let matureOrSuggestiveThemes: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let medicalOrTreatmentInformation: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let profanityOrCrudeHumor: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let sexualContentOrNudity: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let sexualContentGraphicOrNudity: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let violenceCartoonOrFantasy: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let violenceRealistic: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let violenceRealisticProlongedGraphicOrSadistic: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let gunsOrOtherWeapons: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let parentalControls: Bool
	public let userGeneratedContent: Bool
	public let ageAssurance: Bool
	public let advertising: Bool
	public let healthOrWellnessTopics: Bool
	public let messagingAndChat: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
	public let unrestrictedWebAccess: Bool
	public let kids17Plus: Bool
	public let isLootBox: Bool
	public let kidsAgeBand: String? // FIVE_AND_UNDER, SIX_TO_EIGHT, NINE_TO_ELEVEN, or nil
	public let koreaAgeRatingOverride: String // NONE, FIFTEEN_PLUS, NINETEEN_PLUS
	public let reasoning: String

	public init(
		alcoholTobaccoOrDrugUseOrReference: String,
		gamblingAndContests: Bool,
		gamblingSimulated: String,
		horrorOrFearThemes: String,
		matureOrSuggestiveThemes: String,
		medicalOrTreatmentInformation: String,
		profanityOrCrudeHumor: String,
		sexualContentOrNudity: String,
		sexualContentGraphicOrNudity: String,
		violenceCartoonOrFantasy: String,
		violenceRealistic: String,
		violenceRealisticProlongedGraphicOrSadistic: String,
		gunsOrOtherWeapons: String,
		parentalControls: Bool,
		userGeneratedContent: Bool,
		ageAssurance: Bool,
		advertising: Bool,
		healthOrWellnessTopics: Bool,
		messagingAndChat: String,
		unrestrictedWebAccess: Bool,
		kids17Plus: Bool,
		isLootBox: Bool,
		kidsAgeBand: String?,
		koreaAgeRatingOverride: String,
		reasoning: String
	) {
		self.alcoholTobaccoOrDrugUseOrReference = alcoholTobaccoOrDrugUseOrReference
		self.gamblingAndContests = gamblingAndContests
		self.gamblingSimulated = gamblingSimulated
		self.horrorOrFearThemes = horrorOrFearThemes
		self.matureOrSuggestiveThemes = matureOrSuggestiveThemes
		self.medicalOrTreatmentInformation = medicalOrTreatmentInformation
		self.profanityOrCrudeHumor = profanityOrCrudeHumor
		self.sexualContentOrNudity = sexualContentOrNudity
		self.sexualContentGraphicOrNudity = sexualContentGraphicOrNudity
		self.violenceCartoonOrFantasy = violenceCartoonOrFantasy
		self.violenceRealistic = violenceRealistic
		self.violenceRealisticProlongedGraphicOrSadistic = violenceRealisticProlongedGraphicOrSadistic
		self.gunsOrOtherWeapons = gunsOrOtherWeapons
		self.parentalControls = parentalControls
		self.userGeneratedContent = userGeneratedContent
		self.ageAssurance = ageAssurance
		self.advertising = advertising
		self.healthOrWellnessTopics = healthOrWellnessTopics
		self.messagingAndChat = messagingAndChat
		self.unrestrictedWebAccess = unrestrictedWebAccess
		self.kids17Plus = kids17Plus
		self.isLootBox = isLootBox
		self.kidsAgeBand = kidsAgeBand
		self.koreaAgeRatingOverride = koreaAgeRatingOverride
		self.reasoning = reasoning
	}
}
