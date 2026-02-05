import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Pricing: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "pricing",
		abstract: "Update the app's pricing."
	)

	@Option(name: [.short, .long], help: "The price point (e.g., '0' for Free, '0.99', '1.99', etc.).")
	var price: String = "0"

	@Flag(name: .shortAndLong, help: "List all available price points for the app.")
	var list: Bool = false

	func run() async throws {
		// 1. Find project root and config
		guard let root = Environment.live.project.findProjectRoot() else {
			UI.error("Not in an Appstro project. Run 'appstro init' first.")
			return
		}
		
		let config = try Environment.live.project.loadConfig(at: root)
		
		// 2. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}
		
		// 3. Find App
		let app: AppDetails
		do {
			app = try await UI.step("Fetching app details", emoji: "🔍") {
				let query = Environment.live.queryInterpreter.interpret(config.name)
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "PricingError", code: 404, userInfo: [NSLocalizedDescriptionKey: "App '\(config.name)' not found on App Store Connect."])
				}
				return app
			}
		} catch {
			return
		}

		if list {
			let points: [String]
			do {
				points = try await UI.step("Fetching available price points", emoji: "🔍") {
					return try await service.pricing.fetchAppPricePoints(appId: app.id)
				}
			} catch {
				return
			}
			UI.info("Available price tiers (first 20):", emoji: "📋")
			print(points.prefix(20).joined(separator: ", "))
			return
		}

		if price != "0" {
			do {
				try await UI.step("Updating price to \(price)", emoji: "🚀") {
					try await service.pricing.updateAppPrice(appId: app.id, tier: price)
				}
				UI.success("Price updated successfully!")
			} catch {
				return
			}
		} else {
			let currentPrice: String?
			do {
				currentPrice = try await UI.step("Fetching current price for \(app.name)", emoji: "🔍") {
					return try await service.pricing.fetchCurrentPriceDescription(appId: app.id)
				}
			} catch {
				return
			}
			
			if let currentPrice = currentPrice {
				UI.info("Current Price: \(currentPrice)", emoji: "💰")
			} else {
				UI.info("Current Price: Unknown (Likely not set)", emoji: "💰")
			}
			
			print("\nTo update the price, provide a price, e.g.:")
			print("appstro info pricing --price 0.99")
		}
	}
}
