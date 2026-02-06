import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK
import CryptoKit
import ImageIO

public final class ASCScreenshotService: ScreenshotService {
	private let provider: any RequestProvider
	private let bezelService: any BezelService

	public init(provider: any RequestProvider, bezelService: any BezelService) {
		self.provider = provider
		self.bezelService = bezelService
	}

	public func uploadScreenshots(versionId: String, processedDirectory: URL, deviceTypes: [String]? = nil) async throws {
		// 1. Get localization
		let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
		let locResponse = try await provider.request(locEndpoint)
		guard let localization = locResponse.data.first else {
			throw AppStoreConnectError.apiError("No localizations found for this version.")
		}
		
		let devicesToProcess = deviceTypes ?? ["iphone", "ipad"]
		
		struct DeviceWork {
			let deviceType: String
			let bezelInfo: DeviceBezelInfo
			let imageFiles: [URL]
			let displayType: ScreenshotDisplayType
			var setId: String?
		}
		
		var works: [DeviceWork] = []
		
		for deviceType in devicesToProcess {
			let deviceDir = processedDirectory.appendingPathComponent(deviceType)
			
			guard FileManager.default.fileExists(atPath: deviceDir.path) else {
				continue
			}
			
			guard let bezelInfo = bezelService.bezelInfo(for: deviceType, isLandscape: false) else { continue }
			
			let files = (try? FileManager.default.contentsOfDirectory(at: deviceDir, includingPropertiesForKeys: nil)) ?? []
			let imageFiles = files.filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
			
			if imageFiles.isEmpty {
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

		// 2. Perform cleanup and prepare sets
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
			
			let existingSet = setResponse.data.first { $0.attributes?.screenshotDisplayType == work.displayType }
			
			let setId: String
			if let existing = existingSet {
				setId = existing.id
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
		
		try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)

		// 3. Upload
		for work in works {
			guard let setId = work.setId else { continue }
			for file in work.imageFiles {
				try await uploadSingleScreenshot(file: file, setId: setId)
			}
		}
	}

	private func uploadSingleScreenshot(file: URL, setId: String) async throws {
		let fileName = file.lastPathComponent
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

		// D. Poll
		var isProcessed = false
		var attempts = 0
		let maxAttempts = 30
		
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
					break
				}
			}
		}
		
		if !isProcessed {
			throw AppStoreConnectError.apiError("Timeout waiting for \(fileName) to process at Apple.")
		}
	}
}
