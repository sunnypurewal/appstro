import Foundation

struct GeneratedMetadata: Codable {
    let description: String
    let keywords: String
    let promotionalText: String
    let reviewNotes: String
}

struct ContentRightsAnalysis: Codable {
    let usesThirdPartyContent: Bool
    let reasoning: String
}

struct SuggestedAgeRatings: Codable {
    let alcoholTobaccoOrDrugUseOrReference: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let gamblingAndContests: Bool
    let gamblingSimulated: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let horrorOrFearThemes: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let matureOrSuggestiveThemes: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let medicalOrTreatmentInformation: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let profanityOrCrudeHumor: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let sexualContentOrNudity: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let sexualContentGraphicOrNudity: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let violenceCartoonOrFantasy: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let violenceRealistic: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let violenceRealisticProlongedGraphicOrSadistic: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let gunsOrOtherWeapons: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let parentalControls: Bool
    let userGeneratedContent: Bool
    let ageAssurance: Bool
    let advertising: Bool
    let healthOrWellnessTopics: Bool
    let messagingAndChat: String // NONE, INFREQUENT_MILD, FREQUENT_INTENSE
    let unrestrictedWebAccess: Bool
    let kids17Plus: Bool
    let isLootBox: Bool
    let kidsAgeBand: String? // FIVE_AND_UNDER, SIX_TO_EIGHT, NINE_TO_ELEVEN, or nil
    let koreaAgeRatingOverride: String // NONE, FIFTEEN_PLUS, NINETEEN_PLUS
    let reasoning: String
}

struct DataCollectionAnalysis: Codable {
    let collectsData: Bool
    let dataTypes: CollectedDataTypes
    let reasoning: String
}

struct CollectedDataTypes: Codable {
    let location: Bool
    let contactInfo: Bool
    let healthAndFitness: Bool
    let financialInfo: Bool
    let userContent: Bool
    let browsingHistory: Bool
    let searchHistory: Bool
    let identifiers: Bool
    let usageData: Bool
    let diagnostics: Bool
    let otherData: Bool
}

