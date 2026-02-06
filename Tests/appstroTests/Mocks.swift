import Foundation
import AppstroCore
import AppstroASC

final class MockBuildUploader: BuildUploader, @unchecked Sendable {
    var uploadIPAHandler: ((URL, String, String, String) async throws -> Void)?
    func uploadIPA(ipaURL: URL, issuerId: String, keyId: String, privateKey: String) async throws {
        try await uploadIPAHandler?(ipaURL, issuerId, keyId, privateKey)
    }
}

final class MockUserInterface: UserInterface, @unchecked Sendable {
    var promptHandler: ((String, String?) -> String)?
    func prompt(_ text: String, defaultValue: String?) -> String {
        promptHandler?(text, defaultValue) ?? defaultValue ?? ""
    }
    
    var infoHandler: ((String, String?) -> Void)?
    func info(_ message: String, emoji: String?) {
        infoHandler?(message, emoji)
    }
    
    var successHandler: ((String) -> Void)?
    func success(_ message: String) {
        successHandler?(message)
    }
    
    var errorHandler: ((String) -> Void)?
    func error(_ message: String) {
        errorHandler?(message)
    }

    var openURLHandler: ((URL) -> Void)?
    func openURL(_ url: URL) {
        openURLHandler?(url)
    }

    var openFileHandler: ((URL) -> Void)?
    func openFile(_ url: URL) {
        openFileHandler?(url)
    }

    var closeFileHandler: ((URL) -> Void)?
    func closeFile(_ url: URL) {
        closeFileHandler?(url)
    }
}

final class MockAIService: AIService, @unchecked Sendable {
    var generateMetadataHandler: ((String, String, String?) async throws -> GeneratedMetadata)?
    func generateMetadata(appName: String, codeContext: String, userPitch: String?) async throws -> GeneratedMetadata {
        try await generateMetadataHandler?(appName, codeContext, userPitch) ?? GeneratedMetadata(description: "", keywords: "", promotionalText: "", reviewNotes: "", whatsNew: nil)
    }
    
    var describeScreenshotHandler: ((URL, String, String) async throws -> ScreenshotDescription)?
    func describeScreenshot(imageURL: URL, appName: String, appDescription: String) async throws -> ScreenshotDescription {
        try await describeScreenshotHandler?(imageURL, appName, appDescription) ?? ScreenshotDescription(keyword: "", title: "")
    }
    
    var analyzeContentRightsHandler: ((String, String) async throws -> ContentRightsAnalysis?)?
    func analyzeContentRights(appName: String, description: String) async throws -> ContentRightsAnalysis? {
        try await analyzeContentRightsHandler?(appName, description)
    }
    
    var suggestAgeRatingsHandler: ((String, String, String) async throws -> SuggestedAgeRatings?)?
    func suggestAgeRatings(appName: String, description: String, codeContext: String) async throws -> SuggestedAgeRatings? {
        try await suggestAgeRatingsHandler?(appName, description, codeContext)
    }
    
    var analyzeDataCollectionHandler: ((String, String) async throws -> DataCollectionAnalysis?)?
    func analyzeDataCollection(appName: String, codeContext: String) async throws -> DataCollectionAnalysis? {
        try await analyzeDataCollectionHandler?(appName, codeContext)
    }
}

final class MockProjectService: ProjectService, @unchecked Sendable {
    var findProjectRootHandler: (() -> URL?)?
    func findProjectRoot() -> URL? {
        findProjectRootHandler?()
    }
    
    var loadConfigHandler: ((URL) throws -> AppstroConfig)?
    func loadConfig(at root: URL) throws -> AppstroConfig {
        try loadConfigHandler?(root) ?? AppstroConfig(name: "", description: "", keywords: [], bundleIdentifier: nil, appPath: nil, teamID: nil)
    }
    
    var saveConfigHandler: ((AppstroConfig, URL) throws -> Void)?
    func saveConfig(_ config: AppstroConfig, at root: URL) throws {
        try saveConfigHandler?(config, root)
    }
    
    var containsXcodeProjectHandler: ((URL) -> String?)?
    func containsXcodeProject(at url: URL) -> String? {
        containsXcodeProjectHandler?(url)
    }
    
    var getBundleIdentifierHandler: ((URL) -> String?)?
    func getBundleIdentifier(at url: URL) -> String? {
        getBundleIdentifierHandler?(url)
    }
    
    var getTeamIDHandler: ((URL) -> String?)?
    func getTeamID(at url: URL) -> String? {
        getTeamIDHandler?(url)
    }
    
    var ensureAppstroDirectoryHandler: ((URL) async throws -> URL)?
    func ensureAppstroDirectory(at root: URL) async throws -> URL {
        try await ensureAppstroDirectoryHandler?(root) ?? root
    }
    
    var ensureReleaseDirectoryHandler: ((URL, String) async throws -> URL)?
    func ensureReleaseDirectory(at root: URL, version: String) async throws -> URL {
        try await ensureReleaseDirectoryHandler?(root, version) ?? root
    }
    
    var setupGitIgnoreHandler: ((URL) async throws -> Void)?
    func setupGitIgnore(at root: URL) async throws {
        try await setupGitIgnoreHandler?(root)
    }
    
    var buildHandler: ((URL, AppstroConfig, String, String) async throws -> URL)?
    func build(at root: URL, config: AppstroConfig, version: String, buildNumber: String) async throws -> URL {
        try await buildHandler?(root, config, version, buildNumber) ?? root
    }
}

final class MockBezelService: BezelService, @unchecked Sendable {
    func bezelInfo(for deviceType: String, isLandscape: Bool) -> DeviceBezelInfo? { nil }
    func downloadBezelIfNeeded(for info: DeviceBezelInfo) async throws -> URL { URL(fileURLWithPath: "") }
}

final class MockImageProcessor: ImageProcessor, @unchecked Sendable {
    func process(
        screenshotURL: URL,
        bezelURL: URL,
        bezelInfo: DeviceBezelInfo,
        config: ScreenshotConfig,
        defaultConfig: ScreenshotConfig,
        keywordText: String,
        titleText: String,
        outputURL: URL
    ) throws {}
}

final class MockAppQueryInterpreter: AppQueryInterpreter, @unchecked Sendable {
    var interpretHandler: ((String) -> AppQuery)?
    func interpret(_ query: String) -> AppQuery {
        interpretHandler?(query) ?? AppQuery(type: .name(""))
    }
}

final class MockPreferenceService: PreferenceService, @unchecked Sendable {
    func loadPreferences() -> AppPreferences { AppPreferences() }
    func savePrefix(_ prefix: String) {}
}

final class MockAppStoreConnectService: AppStoreConnectService, @unchecked Sendable {
    let apps: any AppService
    let versions: any VersionService
    let metadata: any MetadataService
    let reviews: any ReviewService
    let screenshots: any ScreenshotService
    let pricing: any PricingService
    let ageRatings: any AgeRatingService
    let appClips: any AppClipService
    let certificates: any CertificateService
    let bundleIds: any BundleIdService

    init(
        apps: any AppService = MockAppService(),
        versions: any VersionService = MockVersionService(),
        metadata: any MetadataService = MockMetadataService(),
        reviews: any ReviewService = MockReviewService(),
        screenshots: any ScreenshotService = MockScreenshotService(),
        pricing: any PricingService = MockPricingService(),
        ageRatings: any AgeRatingService = MockAgeRatingService(),
        appClips: any AppClipService = MockAppClipService(),
        certificates: any CertificateService = MockCertificateService(),
        bundleIds: any BundleIdService = MockBundleIdService()
    ) {
        self.apps = apps
        self.versions = versions
        self.metadata = metadata
        self.reviews = reviews
        self.screenshots = screenshots
        self.pricing = pricing
        self.ageRatings = ageRatings
        self.appClips = appClips
        self.certificates = certificates
        self.bundleIds = bundleIds
    }
}

final class MockAppService: AppService, @unchecked Sendable {
    var fetchAppDetailsHandler: ((AppQuery) async throws -> AppDetails?)?
    func fetchAppDetails(query: AppQuery) async throws -> AppDetails? {
        try await fetchAppDetailsHandler?(query)
    }
    
    var listAppsHandler: (() async throws -> [AppInfo])?
    func listApps() async throws -> [AppInfo] { 
        try await listAppsHandler?() ?? []
    }
    
    var updateContentRightsHandler: ((String, Bool) async throws -> Void)?
    func updateContentRights(appId: String, usesThirdPartyContent: Bool) async throws {
        try await updateContentRightsHandler?(appId, usesThirdPartyContent)
    }
}

final class MockVersionService: VersionService, @unchecked Sendable {
    var findDraftVersionHandler: ((String) async throws -> DraftVersion?)?
    func findDraftVersion(for appId: String) async throws -> DraftVersion? {
        try await findDraftVersionHandler?(appId)
    }
    
    var fetchBuildsHandler: ((String, String?) async throws -> [BuildInfo])?
    func fetchBuilds(appId: String, version: String?) async throws -> [BuildInfo] {
        try await fetchBuildsHandler?(appId, version) ?? []
    }
    
    var attachBuildToVersionHandler: ((String, String) async throws -> Void)?
    func attachBuildToVersion(versionId: String, buildId: String) async throws {
        try await attachBuildToVersionHandler?(versionId, buildId)
    }

    func createVersion(appId: String, versionString: String, platform: String) async throws -> DraftVersion {
        DraftVersion(version: versionString, id: "v1", state: .prepareForSubmission)
    }
    func fetchAttachedBuildId(versionId: String) async throws -> String? { nil }
}

final class MockMetadataService: MetadataService, @unchecked Sendable {
    func updateMetadata(versionId: String, metadata: GeneratedMetadata, urls: (support: String, marketing: String), copyright: String, contactInfo: ContactInfo) async throws {}
    func updatePrivacyPolicy(appId: String, url: URL) async throws {}
    func updateLocalization(versionId: String, description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?) async throws {}
    func updateVersionAttributes(versionId: String, copyright: String?) async throws {}
    func updateReviewDetail(versionId: String, contactInfo: ContactInfo?, notes: String?) async throws {}

    func fetchLocalization(versionId: String) async throws -> (description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?) { (nil, nil, nil, nil, nil, nil) }
    func fetchVersionAttributes(versionId: String) async throws -> (copyright: String?, releaseType: String?) { (nil, nil) }
    func fetchReviewDetail(versionId: String) async throws -> (contactInfo: ContactInfo, notes: String?) { (ContactInfo(), nil) }
}

final class MockReviewService: ReviewService, @unchecked Sendable {
    func fetchContactInfo() async throws -> ContactInfo { ContactInfo() }
    func submitForReview(appId: String, versionId: String) async throws {}
    func cancelReviewSubmission(appId: String) async throws {}
    func uploadReviewAttachment(versionId: String, fileURL: URL) async throws {}
    func getDeveloperEmailDomain() async throws -> String { "" }
    func getTeamName() async throws -> String { "" }
}

final class MockScreenshotService: ScreenshotService, @unchecked Sendable {
    func uploadScreenshots(versionId: String, processedDirectory: URL, deviceTypes: [String]?) async throws {}
}

final class MockPricingService: PricingService, @unchecked Sendable {
    func fetchCurrentPriceDescription(appId: String) async throws -> String? { nil }
    func fetchCurrentPriceSchedule(appId: String) async throws -> Set<String> { [] }
    func fetchAppPricePoints(appId: String) async throws -> [String] { [] }
    func updateAppPrice(appId: String, tier: String) async throws {}
}

final class MockAgeRatingService: AgeRatingService, @unchecked Sendable {
    func updateAgeRatingDeclaration(versionId: String, ratings: SuggestedAgeRatings) async throws {}
}

final class MockAppClipService: AppClipService, @unchecked Sendable {
    func fetchDefaultExperienceId(versionId: String) async throws -> String? { nil }
    func fetchAdvancedExperienceIds(appId: String) async throws -> [String] { [] }
    func deleteDefaultExperience(id: String) async throws {}
    func deactivateAdvancedExperience(id: String) async throws {}
}

final class MockCertificateService: CertificateService, @unchecked Sendable {
    func findDistributionCertificateId() async throws -> String { "" }
    func createProvisioningProfile(name: String, bundleIdRecordId: String, certificateId: String) async throws -> Data { Data() }
}

final class MockBundleIdService: BundleIdService, @unchecked Sendable {
    var deduceBundleIdPrefixHandler: ((String?) async throws -> String?)?
    func deduceBundleIdPrefix(preferredPrefix: String?) async throws -> String? { 
        try await deduceBundleIdPrefixHandler?(preferredPrefix) ?? nil
    }
    
    var registerBundleIdHandler: ((String, String) async throws -> String)?
    func registerBundleId(name: String, identifier: String) async throws -> String { 
        try await registerBundleIdHandler?(name, identifier) ?? ""
    }
    
    var findBundleIdRecordIdHandler: ((String) async throws -> String)?
    func findBundleIdRecordId(identifier: String) async throws -> String { 
        try await findBundleIdRecordIdHandler?(identifier) ?? ""
    }
}
