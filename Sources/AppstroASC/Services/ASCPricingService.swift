import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCPricingService: PricingService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func fetchCurrentPriceDescription(appId: String) async throws -> String? {
		var parameters = APIEndpoint.V1.Apps.WithID.AppPriceSchedule.GetParameters()
		parameters.include = [.baseTerritory, .manualPrices]
		parameters.fieldsAppPriceSchedules = [.baseTerritory, .manualPrices]
		parameters.fieldsAppPrices = [.appPricePoint, .territory]
		let endpoint = APIEndpoint.v1.apps.id(appId).appPriceSchedule.get(parameters: parameters)
		
		do {
			let response = try await provider.request(endpoint)
			
			var pricePointId: String?
			var territoryId: String?
			
			pricePointId = response.data.relationships?.manualPrices?.data?.first?.id
			territoryId = response.data.relationships?.baseTerritory?.data?.id
			
			if let pricePointId, let territoryId {
				let ppEndpoint = APIEndpoint.v1.apps.id(appId).appPricePoints.get(parameters: .init(filterTerritory: [territoryId], limit: 200))
				let ppResponse = try await provider.request(ppEndpoint)
				if let priceStr = ppResponse.data.first(where: { $0.id == pricePointId })?.attributes?.customerPrice {
					return priceStr == "0.0" ? "Free" : "$\(priceStr)"
				}
			}
			return nil
		} catch {
			return nil
		}
	}

	public func fetchCurrentPriceSchedule(appId: String) async throws -> Set<String> {
		var parameters = APIEndpoint.V1.Apps.WithID.AppPriceSchedule.GetParameters()
		parameters.include = [.manualPrices]
		parameters.limitManualPrices = 100
		let endpoint = APIEndpoint.v1.apps.id(appId).appPriceSchedule.get(parameters: parameters)
		
		do {
			let response = try await provider.request(endpoint)
			let ids = response.data.relationships?.manualPrices?.data?.compactMap { $0.id } ?? []
			return Set(ids)
		} catch {
			return []
		}
	}

	public func fetchAppPricePoints(appId: String) async throws -> [String] {
		let endpoint = APIEndpoint.v1.apps.id(appId).appPricePoints.get(parameters: .init(limit: 200))
		let response = try await provider.request(endpoint)
		return response.data.compactMap { $0.attributes?.customerPrice }.sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }
	}

	public func updateAppPrice(appId: String, tier: String) async throws {
		let territory = "CAN"
		let targetPrice = (tier == "0" || tier.lowercased() == "free") ? "0.0" : tier
		
		let endpoint = APIEndpoint.v1.apps.id(appId).appPricePoints.get(parameters: .init(filterTerritory: [territory], limit: 200))
		let response = try await provider.request(endpoint)
		
		guard response.data.contains(where: { 
			if let cp = $0.attributes?.customerPrice {
				return Double(cp) == Double(targetPrice)
			}
			return false
		}) else {
			let available = response.data.compactMap { $0.attributes?.customerPrice }.prefix(10).joined(separator: ", ")
			throw AppStoreConnectError.apiError("Price point for '\(targetPrice)' not found for this app. Available examples: \(available)")
		}
		
		let manualPriceId = "\(territory)-\(Int.random(in: 1...1000000))"
		let appRelationship = AppPriceScheduleCreateRequest.Data.Relationships.App(
			data: .init(type: .apps, id: appId)
		)
		let territoryRelationship = AppPriceScheduleCreateRequest.Data.Relationships.BaseTerritory(
			data: .init(type: .territories, id: territory)
		)
		let manualPricesRelationship = AppPriceScheduleCreateRequest.Data.Relationships.ManualPrices(
			data: [.init(type: .appPrices, id: manualPriceId)]
		)
		
		let relationships = AppPriceScheduleCreateRequest.Data.Relationships(
			app: appRelationship,
			baseTerritory: territoryRelationship,
			manualPrices: manualPricesRelationship
		)
		
		let appTerritory = TerritoryInlineCreate(type: .territories, id: "\(territory)-\(Int.random(in: 1...10000))")
		
		let createRequest = AppPriceScheduleCreateRequest(
			data: .init(type: .appPriceSchedules, relationships: relationships),
			included: [.territoryInlineCreate(appTerritory)]
		)
		
		let createEndpoint = APIEndpoint.v1.appPriceSchedules.post(createRequest)
		_ = try await provider.request(createEndpoint)
	}
}
