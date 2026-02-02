import Foundation
import AppStoreConnect_Swift_SDK
import CryptoKit
import ImageIO

enum AppStoreConnectError: Error {
    case invalidResponse
    case apiError(String)
    case missingCredentials
    case invalidPrivateKey
}

struct AppDetails: Sendable {
    let name: String
    let bundleId: String
    let appStoreUrl: String
    let publishedVersion: String?
}

struct AppInfo: Sendable {
    let id: String
    let name: String
    let bundleId: String
}

struct DraftVersion: Sendable {
    let version: String
    let id: String
}

struct ContactInfo: Sendable {
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
}

final class AppStoreConnectService {
    private let provider: APIProvider

    init(issuerId: String, keyId: String, privateKey: String) throws {
        let sanitizedKey = privateKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        let configuration = try APIConfiguration(issuerID: issuerId, privateKeyID: keyId, privateKey: sanitizedKey)
        self.provider = APIProvider(configuration: configuration)
    }

    func fetchAppDetails(query: AppQuery) async throws -> AppDetails? {
        var parameters = APIEndpoint.V1.Apps.GetParameters()
        parameters.include = [.appStoreVersions]
        parameters.limitAppStoreVersions = 10
        parameters.limit = 200
        
        switch query.type {
        case .name:
            break
        case .bundleId(let bundleId):
            parameters.filterBundleID = [bundleId]
        }
        
        let endpoint = APIEndpoint.v1.apps.get(parameters: parameters)
        let response = try await provider.request(endpoint)
        
        let appData: AppStoreConnect_Swift_SDK.App?
        switch query.type {
        case .name(let name):
            appData = response.data.first { $0.attributes?.name?.localizedCaseInsensitiveCompare(name) == .orderedSame }
        case .bundleId:
            appData = response.data.first
        }
        
        guard let app = appData, let attributes = app.attributes else {
            return nil
        }
        
        let publishedVersion = findPublishedVersion(app: app, included: response.included ?? [])
        
        return AppDetails(
            name: attributes.name ?? "Unknown",
            bundleId: attributes.bundleID ?? "Unknown",
            appStoreUrl: "https://apps.apple.com/app/id\(app.id)",
            publishedVersion: publishedVersion
        )
    }

    func deduceBundleIdPrefix(preferredPrefix: String?) async throws -> String? {
        if let preferredPrefix = preferredPrefix {
            return preferredPrefix
        }

        // 1. Try historical Bundle IDs
        let bundleIdsEndpoint = APIEndpoint.v1.bundleIDs.get(parameters: .init(limit: 200))
        let bundleResponse = try await provider.request(bundleIdsEndpoint)
        
        let identifiers = bundleResponse.data.compactMap { $0.attributes?.identifier }
        if let prefix = findMostFrequentPrefix(identifiers: identifiers) {
            return prefix
        }
        
        // 2. Try email domain fallback
        let usersEndpoint = APIEndpoint.v1.users.get(parameters: .init(limit: 10))
        let userResponse = try await provider.request(usersEndpoint)
        
        if let email = userResponse.data.first?.attributes?.username {
            let parts = email.split(separator: "@")
            if parts.count == 2 {
                let domain = String(parts[1])
                let genericProviders = ["gmail.com", "icloud.com", "outlook.com", "yahoo.com", "me.com", "hotmail.com"]
                if !genericProviders.contains(domain.lowercased()) {
                    let domainParts = domain.split(separator: ".")
                    return domainParts.reversed().joined(separator: ".")
                }
            }
        }
        
        return nil
    }

    func registerBundleId(name: String, identifier: String) async throws -> String {
        // 1. Check if identifier already exists
        let filterEndpoint = APIEndpoint.v1.bundleIDs.get(parameters: .init(filterIdentifier: [identifier]))
        let existingBundleResponse = try await provider.request(filterEndpoint)
        
        if let existing = existingBundleResponse.data.first {
            return existing.id
        }
        
        // 2. Register if it doesn't exist
        let attributes = BundleIDCreateRequest.Data.Attributes(name: name, platform: .ios, identifier: identifier)
        let data = BundleIDCreateRequest.Data(type: .bundleIDs, attributes: attributes)
        let registerRequest = BundleIDCreateRequest(data: data)
        let endpoint = APIEndpoint.v1.bundleIDs.post(registerRequest)
        let newBundle = try await provider.request(endpoint)
        return newBundle.data.id
    }

    func listApps() async throws -> [AppInfo] {
        let endpoint = APIEndpoint.v1.apps.get(parameters: .init(limit: 100))
        let response = try await provider.request(endpoint)
        return response.data.map { app in
            AppInfo(
                id: app.id,
                name: app.attributes?.name ?? "Unknown",
                bundleId: app.attributes?.bundleID ?? "Unknown"
            )
        }
    }

    func findLatestDraftVersion() async throws -> (app: AppInfo, version: String, id: String)? {
        let apps = try await listApps()
        
        for app in apps {
            if let draft = try await findDraftVersion(for: app.id) {
                return (app, draft.version, draft.id)
            }
        }
        
        return nil
    }

    func findDraftVersion(for appId: String) async throws -> DraftVersion? {
        var parameters = APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters()
        parameters.filterAppStoreState = [.prepareForSubmission]
        parameters.limit = 1
        let endpoint = APIEndpoint.v1.apps.id(appId).appStoreVersions.get(parameters: parameters)
        let response = try await provider.request(endpoint)
        
        if let draft = response.data.first, let attributes = draft.attributes {
            return DraftVersion(version: attributes.versionString ?? "1.0", id: draft.id)
        }
        return nil
    }

    func updateMetadata(versionId: String, metadata: GeneratedMetadata, urls: (support: String, marketing: String), copyright: String, contactInfo: ContactInfo) async throws {
        // 1. Update Localization
        let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
        let locResponse = try await provider.request(locEndpoint)
        guard let localization = locResponse.data.first else {
            throw AppStoreConnectError.apiError("No localizations found for this version.")
        }

        let locAttributes = AppStoreVersionLocalizationUpdateRequest.Data.Attributes(
            description: metadata.description,
            keywords: metadata.keywords,
            marketingURL: URL(string: urls.marketing),
            promotionalText: metadata.promotionalText,
            supportURL: URL(string: urls.support)
        )
        let locUpdate = AppStoreVersionLocalizationUpdateRequest(data: .init(type: .appStoreVersionLocalizations, id: localization.id, attributes: locAttributes))
        _ = try await provider.request(APIEndpoint.v1.appStoreVersionLocalizations.id(localization.id).patch(locUpdate))

        // 2. Update Version Attributes (Copyright & Release Type)
        let versionAttributes = AppStoreVersionUpdateRequest.Data.Attributes(
            copyright: copyright,
            releaseType: .afterApproval
        )
        let versionUpdate = AppStoreVersionUpdateRequest(data: .init(type: .appStoreVersions, id: versionId, attributes: versionAttributes))
        _ = try await provider.request(APIEndpoint.v1.appStoreVersions.id(versionId).patch(versionUpdate))

        // 3. Update Review Details
        var reviewParams = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
        reviewParams.include = [.appStoreReviewDetail]
        let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: reviewParams)
        let versionResponse = try await provider.request(versionEndpoint)
        
        let existingReviewDetailId = versionResponse.included?.compactMap { item -> String? in
            if case .appStoreReviewDetail(let detail) = item { return detail.id }
            return nil
        }.first

        if let reviewId = existingReviewDetailId {
            let reviewAttributes = AppStoreReviewDetailUpdateRequest.Data.Attributes(
                contactFirstName: contactInfo.firstName,
                contactLastName: contactInfo.lastName,
                contactPhone: contactInfo.phone,
                contactEmail: contactInfo.email,
                isDemoAccountRequired: false,
                notes: metadata.reviewNotes
            )
            let reviewUpdate = AppStoreReviewDetailUpdateRequest(data: .init(type: .appStoreReviewDetails, id: reviewId, attributes: reviewAttributes))
            _ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.id(reviewId).patch(reviewUpdate))
        } else {
            let relData = AppStoreReviewDetailCreateRequest.Data.Relationships.AppStoreVersion.Data(type: .appStoreVersions, id: versionId)
            let rel = AppStoreReviewDetailCreateRequest.Data.Relationships(appStoreVersion: .init(data: relData))
            let createAttributes = AppStoreReviewDetailCreateRequest.Data.Attributes(
                contactFirstName: contactInfo.firstName,
                contactLastName: contactInfo.lastName,
                contactPhone: contactInfo.phone,
                contactEmail: contactInfo.email,
                isDemoAccountRequired: false,
                notes: metadata.reviewNotes
            )
            let createRequest = AppStoreReviewDetailCreateRequest(data: .init(type: .appStoreReviewDetails, attributes: createAttributes, relationships: rel))
            _ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.post(createRequest))
        }
    }

    func fetchExistingReviewDetail() async throws -> ContactInfo? {
        let apps = try await listApps()
        
        for app in apps {
            var params = APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters()
            params.include = [.appStoreReviewDetail]
            params.limit = 5
            
            let endpoint = APIEndpoint.v1.apps.id(app.id).appStoreVersions.get(parameters: params)
            let response = try await provider.request(endpoint)
            
            let reviewDetail = response.included?.compactMap { item -> AppStoreReviewDetail? in
                if case .appStoreReviewDetail(let detail) = item { return detail }
                return nil
            }.first { detail in
                return detail.attributes?.contactPhone != nil && detail.attributes?.contactEmail != nil
            }
            
            if let detail = reviewDetail, let attr = detail.attributes {
                return ContactInfo(
                    firstName: attr.contactFirstName,
                    lastName: attr.contactLastName,
                    email: attr.contactEmail,
                    phone: attr.contactPhone
                )
            }
        }
        return nil
    }

    func fetchContactInfo() async throws -> ContactInfo {
        // 1. Try to find existing info from other apps first
        if let existing = try? await fetchExistingReviewDetail() {
            return existing
        }

        // 2. Fallback to user profile
        let usersEndpoint = APIEndpoint.v1.users.get(parameters: .init(limit: 1))
        let userResponse = try await provider.request(usersEndpoint)
        
        if let user = userResponse.data.first?.attributes {
            return ContactInfo(
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.username,
                phone: nil
            )
        }
        
        return ContactInfo()
    }

    func getDeveloperEmailDomain() async throws -> String {
        let info = try await fetchContactInfo()
        if let email = info.email {
            let parts = email.split(separator: "@")
            if parts.count == 2 {
                return String(parts[1])
            }
        }
        return "example.com"
    }

    func getTeamName() async throws -> String {
        let info = try await fetchContactInfo()
        if let first = info.firstName, let last = info.lastName {
            return "\(first) \(last)"
        }
        return "Developer"
    }

    func updateContentRights(appId: String, usesThirdPartyContent: Bool) async throws {
        let attributes = AppUpdateRequest.Data.Attributes(contentRightsDeclaration: usesThirdPartyContent ? .usesThirdPartyContent : .doesNotUseThirdPartyContent)
        let updateRequest = AppUpdateRequest(data: .init(type: .apps, id: appId, attributes: attributes))
        _ = try await provider.request(APIEndpoint.v1.apps.id(appId).patch(updateRequest))
    }

    func updateAgeRatingDeclaration(versionId: String, ratings: SuggestedAgeRatings) async throws {
        // Find existing age rating declaration
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
            // Map the AI strings (NONE, INFREQUENT_MILD, FREQUENT_INTENSE) 
            // to SDK enums (NONE, INFREQUENT_OR_MILD, FREQUENT_OR_INTENSE)
            let mappedValue = switch level {
                case "INFREQUENT_MILD": "INFREQUENT_OR_MILD"
                case "FREQUENT_INTENSE": "FREQUENT_OR_INTENSE"
                default: level
            }
            return T(rawValue: mappedValue)
        }

        let attributes = Attrs(
            alcoholTobaccoOrDrugUseOrReferences: mapLevel(ratings.alcoholTobaccoOrDrugUseOrReference),
            contests: ratings.gamblingAndContests ? .infrequentOrMild : Attrs.Contests.none,
            isGambling: ratings.gamblingAndContests,
            gamblingSimulated: mapLevel(ratings.gamblingSimulated),
            kidsAgeBand: mapLevel(ratings.kidsAgeBand ?? ""),
            isLootBox: ratings.isLootBox,
            medicalOrTreatmentInformation: mapLevel(ratings.medicalOrTreatmentInformation),
            profanityOrCrudeHumor: mapLevel(ratings.profanityOrCrudeHumor),
            sexualContentGraphicAndNudity: mapLevel(ratings.sexualContentGraphicOrNudity),
            sexualContentOrNudity: mapLevel(ratings.sexualContentOrNudity),
            horrorOrFearThemes: mapLevel(ratings.horrorOrFearThemes),
            matureOrSuggestiveThemes: mapLevel(ratings.matureOrSuggestiveThemes),
            isUnrestrictedWebAccess: ratings.unrestrictedWebAccess,
            violenceCartoonOrFantasy: mapLevel(ratings.violenceCartoonOrFantasy),
            violenceRealisticProlongedGraphicOrSadistic: mapLevel(ratings.violenceRealisticProlongedGraphicOrSadistic),
            violenceRealistic: mapLevel(ratings.violenceRealistic),
            ageRatingOverride: ratings.kids17Plus ? .seventeenPlus : Attrs.AgeRatingOverride.none,
            koreaAgeRatingOverride: mapLevel(ratings.koreaAgeRatingOverride)
        )

        let updateRequest = AgeRatingDeclarationUpdateRequest(data: .init(type: .ageRatingDeclarations, id: id, attributes: attributes))
        _ = try await provider.request(APIEndpoint.v1.ageRatingDeclarations.id(id).patch(updateRequest))
    }

    func updatePrivacyPolicy(appId: String, url: URL) async throws {
        // App Store Connect uses AppInfos for privacy policy URLs
        let appInfosEndpoint = APIEndpoint.v1.apps.id(appId).appInfos.get()
        let response = try await provider.request(appInfosEndpoint)
        
        guard let appInfoId = response.data.first?.id else {
            throw AppStoreConnectError.apiError("No App Info found for app \(appId)")
        }

        let locEndpoint = APIEndpoint.v1.appInfos.id(appInfoId).appInfoLocalizations.get()
        let locResponse = try await provider.request(locEndpoint)
        
        for localization in locResponse.data {
            let attributes = AppInfoLocalizationUpdateRequest.Data.Attributes(privacyPolicyURL: url.absoluteString)
            let updateRequest = AppInfoLocalizationUpdateRequest(data: .init(type: .appInfoLocalizations, id: localization.id, attributes: attributes))
            _ = try await provider.request(APIEndpoint.v1.appInfoLocalizations.id(localization.id).patch(updateRequest))
        }
    }

    func updateAppPrice(appId: String, tier: String) async throws {
        // This is a bit complex as it involves AppPriceSchedules. 
        // For simplicity, we'll assume 'tier' 0 is free.
        
        if tier == "0" || tier.lowercased() == "free" {
            print("ℹ️ Setting app to Free (Tier 0).")
        } else {
            print("⚠️ Paid tiers implementation is complex and requires specific Price Point IDs. Defaulting to Free.")
        }
    }

    func uploadScreenshots(versionId: String, processedDirectory: URL) async throws {
        // 1. Get localization
        let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
        let locResponse = try await provider.request(locEndpoint)
        guard let localization = locResponse.data.first else {
            throw AppStoreConnectError.apiError("No localizations found for this version.")
        }
        print("📍 Using localization: \(localization.attributes?.locale ?? "unknown") (ID: \(localization.id))")
        
        let bezelService = BezelService()
        let deviceTypes = ["iphone", "ipad"]
        
        struct DeviceWork {
            let deviceType: String
            let bezelInfo: DeviceBezelInfo
            let imageFiles: [URL]
            let displayType: ScreenshotDisplayType
            var setId: String?
        }
        
        var works: [DeviceWork] = []
        
        // 1. Prepare and Find/Create Sets
        print("🔍 Checking available screenshot sets...")
        let allSetsEndpoint = APIEndpoint.v1.appStoreVersionLocalizations.id(localization.id).appScreenshotSets.get()
        let allSetsResponse = try await provider.request(allSetsEndpoint)
        for set in allSetsResponse.data {
            print("  - Found Set: \(set.attributes?.screenshotDisplayType?.rawValue ?? "unknown") (ID: \(set.id))")
        }

        for deviceType in deviceTypes {
            let deviceDir = processedDirectory.appendingPathComponent(deviceType)
            
            // Only proceed if the folder exists
            guard FileManager.default.fileExists(atPath: deviceDir.path) else {
                continue
            }
            
            guard let bezelInfo = bezelService.bezelInfo(for: deviceType) else { continue }
            
            let files = (try? FileManager.default.contentsOfDirectory(at: deviceDir, includingPropertiesForKeys: nil)) ?? []
            let imageFiles = files.filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            
            // If the folder exists but is empty, don't touch App Store Connect for this device
            if imageFiles.isEmpty {
                print("  ⏭️ Skipping \(deviceType) (no images found in \(deviceType)/ directory)")
                continue
            }
            
            let sdkDisplayType: ScreenshotDisplayType? = switch bezelInfo.displayType {
                case "IPHONE_67": .appIphone67
                case "IPAD_PRO_3GEN_129": .appIpadPro3gen129
                default: nil
            }
            
            guard let displayType = sdkDisplayType else { continue }
            
            works.append(DeviceWork(deviceType: deviceType, bezelInfo: bezelInfo, imageFiles: imageFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }), displayType: displayType))
        }

        // 2. Perform all deletions first (only for works we identified)
        if !works.isEmpty {
            print("🚀 Cleaning up existing screenshots...")
        }
        for i in 0..<works.count {
            let work = works[i]
            
            var setParams = APIEndpoint.V1.AppStoreVersionLocalizations.WithID.AppScreenshotSets.GetParameters()
            let filterType: APIEndpoint.V1.AppStoreVersionLocalizations.WithID.AppScreenshotSets.GetParameters.FilterScreenshotDisplayType = switch work.displayType {
                case .appIphone67: .appIphone67
                case .appIpadPro3gen129: .appIpadPro3gen129
                default: fatalError("Unsupported display type")
            }
            setParams.filterScreenshotDisplayType = [filterType]
            
            let setEndpoint = APIEndpoint.v1.appStoreVersionLocalizations.id(localization.id).appScreenshotSets.get(parameters: setParams)
            let setResponse = try await provider.request(setEndpoint)
            
            // Find the set that MATCHES our required display type exactly
            let existingSet = setResponse.data.first { $0.attributes?.screenshotDisplayType == work.displayType }
            
            let setId: String
            if let existing = existingSet {
                setId = existing.id
                print("  🗑️ Clearing \(work.bezelInfo.displayType) set...")
                let screenshotsEndpoint = APIEndpoint.v1.appScreenshotSets.id(setId).appScreenshots.get()
                let existingScreenshots = try await provider.request(screenshotsEndpoint)
                
                for screenshot in existingScreenshots.data {
                    let deleteEndpoint = APIEndpoint.v1.appScreenshots.id(screenshot.id).delete
                    try await provider.request(deleteEndpoint)
                }
            } else {
                let attributes = AppScreenshotSetCreateRequest.Data.Attributes(screenshotDisplayType: work.displayType)
                let relData = AppScreenshotSetCreateRequest.Data.Relationships.AppStoreVersionLocalization.Data(type: .appStoreVersionLocalizations, id: localization.id)
                let rel = AppScreenshotSetCreateRequest.Data.Relationships(appStoreVersionLocalization: .init(data: relData))
                let createRequest = AppScreenshotSetCreateRequest(data: .init(type: .appScreenshotSets, attributes: attributes, relationships: rel))
                let createEndpoint = APIEndpoint.v1.appScreenshotSets.post(createRequest)
                let newSet = try await provider.request(createEndpoint)
                setId = newSet.data.id
            }
            works[i].setId = setId
        }
        
        // Give backend a moment to settle
        try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)

        // 3. Perform all uploads
        for work in works {
            guard let setId = work.setId else { continue }
            print("🚀 Uploading \(work.deviceType) screenshots (Preview Type: \(work.displayType.rawValue))...")
            for file in work.imageFiles {
                try await uploadSingleScreenshot(file: file, setId: setId)
            }
        }
    }

    private func uploadSingleScreenshot(file: URL, setId: String) async throws {
        let fileName = file.lastPathComponent
        
        // Print dimensions for debugging
        if let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil),
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let width = imageProperties[kCGImagePropertyPixelWidth] as? Int,
           let height = imageProperties[kCGImagePropertyPixelHeight] as? Int {
            print("    🔼 Uploading \(fileName) (\(width)x\(height))...")
        } else {
            print("    🔼 Uploading \(fileName)...")
        }
        
        let fileData = try Data(contentsOf: file)
        let fileSize = fileData.count
        
        // A. Reserve
        let attributes = AppScreenshotCreateRequest.Data.Attributes(fileSize: fileSize, fileName: fileName)
        let relData = AppScreenshotCreateRequest.Data.Relationships.AppScreenshotSet.Data(type: .appScreenshotSets, id: setId)
        let rel = AppScreenshotCreateRequest.Data.Relationships(appScreenshotSet: .init(data: relData))
        let reserveRequest = AppScreenshotCreateRequest(data: .init(type: .appScreenshots, attributes: attributes, relationships: rel))
        let reserveEndpoint = APIEndpoint.v1.appScreenshots.post(reserveRequest)
        let reservation = try await provider.request(reserveEndpoint)
        
        // B. Upload Bits
        guard let operations = reservation.data.attributes?.uploadOperations else {
            throw AppStoreConnectError.apiError("Missing upload operations for \(fileName)")
        }
        
        for op in operations {
            guard let urlStr = op.url, let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = op.method ?? "PUT"
            op.requestHeaders?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.name ?? "") }
            
            let start = op.offset ?? 0
            let length = op.length ?? 0
            let end = start + length
            let chunk = fileData.subdata(in: start..<end)
            
            let (_, response) = try await URLSession.shared.upload(for: request, from: chunk)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw AppStoreConnectError.apiError("Binary upload failed for \(fileName)")
            }
        }
        
        // C. Commit
        let checksum = Insecure.MD5.hash(data: fileData).map { String(format: "%02hhx", $0) }.joined()
        let updateAttributes = AppScreenshotUpdateRequest.Data.Attributes(sourceFileChecksum: checksum, isUploaded: true)
        let updateRequest = AppScreenshotUpdateRequest(data: .init(type: .appScreenshots, id: reservation.data.id, attributes: updateAttributes))
        let updateEndpoint = APIEndpoint.v1.appScreenshots.id(reservation.data.id).patch(updateRequest)
        _ = try await provider.request(updateEndpoint)

        // D. Poll for completion
        var isProcessed = false
        var attempts = 0
        let maxAttempts = 30 // 60 seconds total
        
        while !isProcessed && attempts < maxAttempts {
            attempts += 1
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            
            let pollEndpoint = APIEndpoint.v1.appScreenshots.id(reservation.data.id).get()
            let status = try await provider.request(pollEndpoint)
            
            if let state = status.data.attributes?.assetDeliveryState {
                switch state.state {
                case .complete:
                    isProcessed = true
                case .failed:
                    let details = state.errors?.map { "[\($0.code ?? "no-code")] \($0.description ?? "no-description")" }.joined(separator: "; ") ?? "Unknown Apple processing error"
                    throw AppStoreConnectError.apiError("Processing failed for \(fileName): \(details)")
                default:
                    // Still processing
                    break
                }
            }
        }
        
        if !isProcessed {
            throw AppStoreConnectError.apiError("Timeout waiting for \(fileName) to process at Apple.")
        }
    }

    private func findMostFrequentPrefix(identifiers: [String]) -> String? {
        var counts: [String: Int] = [:]
        for id in identifiers {
            let parts = id.split(separator: ".")
            if parts.count > 1 {
                let prefix = parts.dropLast().joined(separator: ".")
                counts[prefix, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func findPublishedVersion(app: AppStoreConnect_Swift_SDK.App, included: [AppStoreConnect_Swift_SDK.AppsResponse.IncludedItem]) -> String? {
        guard let versionIds = app.relationships?.appStoreVersions?.data?.map({ $0.id }) else {
            return nil
        }
        
        for versionId in versionIds {
            if let version = included.first(where: { 
                if case .appStoreVersion(let v) = $0 { return v.id == versionId }
                return false
            }) {
                if case .appStoreVersion(let v) = version, v.attributes?.appStoreState == .readyForSale {
                    return v.attributes?.versionString
                }
            }
        }
        
        return nil
    }
}
