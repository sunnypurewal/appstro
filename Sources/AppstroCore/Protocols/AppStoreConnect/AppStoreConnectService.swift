import Foundation

public protocol AppStoreConnectService: Sendable {
	var apps: any AppService { get }
	var bundleIds: any BundleIdService { get }
	var versions: any VersionService { get }
	var metadata: any MetadataService { get }
	var reviews: any ReviewService { get }
	var ageRatings: any AgeRatingService { get }
	var pricing: any PricingService { get }
	var screenshots: any ScreenshotService { get }
	var certificates: any CertificateService { get }
	var appClips: any AppClipService { get }
}
