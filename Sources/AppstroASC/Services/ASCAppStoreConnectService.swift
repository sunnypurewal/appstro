import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCAppStoreConnectService: AppStoreConnectService {
	public let apps: any AppService
	public let bundleIds: any BundleIdService
	public let versions: any VersionService
	public let metadata: any MetadataService
	public let reviews: any ReviewService
	public let ageRatings: any AgeRatingService
		public let pricing: any PricingService
		public let screenshots: any ScreenshotService
		public let certificates: any CertificateService
		public let appClips: any AppClipService
	
		public init(issuerId: String, keyId: String, privateKey: String, bezelService: any BezelService) throws {
			let provider = try AppStoreConnectProvider(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
			let requestProvider = provider.requestProvider
			
			let apps = ASCAppService(provider: requestProvider)
			let bundleIds = ASCBundleIdService(provider: requestProvider)
			
			self.apps = apps
			self.bundleIds = bundleIds
			self.versions = ASCVersionService(provider: requestProvider)
			self.metadata = ASCMetadataService(provider: requestProvider)
			self.reviews = ASCReviewService(provider: requestProvider, appService: apps)
			self.ageRatings = ASCAgeRatingService(provider: requestProvider)
			self.pricing = ASCPricingService(provider: requestProvider)
			self.screenshots = ASCScreenshotService(provider: requestProvider, bezelService: bezelService)
			self.certificates = ASCCertificateService(provider: requestProvider)
			self.appClips = ASCAppClipService(provider: requestProvider)
		}
	}
	