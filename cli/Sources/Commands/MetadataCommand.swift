import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Metadata: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "metadata",
		abstract: "Manage, generate, and upload app metadata.",
		subcommands: [
			Generate.self,
			All.self,
			Description.self,
			Keywords.self,
			WhatsNew.self,
			PromotionalText.self,
			ReviewNotes.self,
			Copyright.self,
			SupportURL.self,
			MarketingURL.self,
			Contact.self
		]
	)
}

// MARK: - Utilities

enum MetadataUtils {
	static func fetchDraft(service: any AppStoreConnectService, bundleIdentifier: String? = nil) async throws -> (app: AppInfo, version: String, id: String) {
		print("DEBUG: fetchDraft called with bundleId: \(bundleIdentifier ?? "nil")")
		let eligibleStates: Set<AppVersionState> = [.prepareForSubmission, .rejected, .metadataRejected, .developerRejected]

		if let bundleId = bundleIdentifier {
			let query = AppQuery(type: .bundleId(bundleId))
			print("DEBUG: Fetching app details for \(bundleId)...")
			if let app = try await service.apps.fetchAppDetails(query: query) {
				print("DEBUG: Found app: \(app.name)")
				let info = AppInfo(id: app.id, name: app.name, bundleId: app.bundleId)
				print("DEBUG: Finding draft version for \(app.id)...")
				if let draft = try await service.versions.findDraftVersion(for: app.id) {
					print("DEBUG: Found draft version \(draft.version) in state \(draft.state)")
					if eligibleStates.contains(draft.state) {
						if let root = Environment.live.project.findProjectRoot() {
							_ = try? Environment.live.project.ensureReleaseDirectory(at: root, version: draft.version)
						}
						return (app: info, version: draft.version, id: draft.id)
					} else {
						print("DEBUG: Version state \(draft.state) is not eligible.")
					}
				} else {
					print("DEBUG: No draft version found for app.")
				}
			} else {
				print("DEBUG: fetchAppDetails returned nil for \(bundleId)")
			}
		}

		print("DEBUG: Falling back to listApps()...")
		let apps = try await service.apps.listApps()
		print("DEBUG: listApps() returned \(apps.count) apps")
		for app in apps {
			print("DEBUG: Checking app: \(app.name)")
			if let draft = try await service.versions.findDraftVersion(for: app.id), eligibleStates.contains(draft.state) {
				if let root = Environment.live.project.findProjectRoot() {
					_ = try? Environment.live.project.ensureReleaseDirectory(at: root, version: draft.version)
				}
				return (app: app, version: draft.version, id: draft.id)
			}
		}

		UI.error("No editable app version found. (Looking for versions in Prepare for Submission, Rejected, or Metadata Rejected states)")
		throw ExitCode.failure
	}
}

// MARK: - Subcommands

extension Metadata {
	struct All: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Fetch and display all current metadata.")

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			try await UI.step("Fetching all metadata", emoji: "🔍") {
				let loc = try await service.metadata.fetchLocalization(versionId: draft.id)
				let ver = try await service.metadata.fetchVersionAttributes(versionId: draft.id)
				let review = try await service.metadata.fetchReviewDetail(versionId: draft.id)

				print("\n--- CURRENT METADATA ---")
				print("📝 Description: \(loc.description ?? "None")")
				print("🔑 Keywords: \(loc.keywords ?? "None")")
				print("🆕 What's New: \(loc.whatsNew ?? "None")")
				print("📣 Promotional Text: \(loc.promotionalText ?? "None")")
				print("🗒️ Review Notes: \(review.notes ?? "None")")
				print("©️ Copyright: \(ver.copyright ?? "None")")
				print("🛠️ Support URL: \(loc.supportURL ?? "None")")
				print("📈 Marketing URL: \(loc.marketingURL ?? "None")")
				print("👤 Contact: \(review.contactInfo.firstName ?? "") \(review.contactInfo.lastName ?? "") (\(review.contactInfo.email ?? ""), \(review.contactInfo.phone ?? ""))")
				print("------------------------\n")
			}
		}
	}

	struct Generate: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Generate and upload app metadata using AI.")

		@Option(name: .long, help: "A short pitch or description of the app.")
		var pitch: String?

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)

			var contextName: String?
			var contextPitch: String?
			var contextAppPath: String?
			
			let projectRoot: URL? = Environment.live.project.findProjectRoot()

			if let root = projectRoot,
			   let config = try? Environment.live.project.loadConfig(at: root) {
				contextName = config.name
				contextPitch = config.description
				contextAppPath = config.appPath
				UI.info("Loaded context from appstro.json", emoji: "📖")
			}

			let draft = try await UI.step("Fetching draft version", emoji: "🔍") {
				let config = try? Environment.live.project.loadConfig(at: projectRoot ?? URL(fileURLWithPath: "."))
				return try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)
			}

			let codeContext: String = try await UI.step("Reading project context", emoji: "📄") {
				let baseDir = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
				let rootDir = contextAppPath.map { baseDir.appendingPathComponent($0) } ?? baseDir
				let sourcesDir = rootDir.appendingPathComponent("Sources")
				
				var context = ""
				let fileManager = FileManager.default
				if let files = try? fileManager.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil) {
					for file in files where file.pathExtension == "swift" {
						if let content = try? String(contentsOf: file, encoding: .utf8) {
							context += "\n--- \(file.lastPathComponent) ---\n\(content)\n"
						}
					}
				}
				return context
			}

			if codeContext.isEmpty {
				UI.info("No Swift files found in Sources directory. Metadata might be generic.", emoji: "⚠️")
			}

			let metadata = try await UI.step("Generating metadata", emoji: "🤖") {
				try await Environment.live.ai.generateMetadata(
					appName: contextName ?? draft.app.name,
					codeContext: codeContext,
					userPitch: pitch ?? contextPitch
				)
			}

			print("\n--- PROPOSED METADATA ---")
			print("📝 Description: \(metadata.description.prefix(100))...")
			print("🔑 Keywords: \(metadata.keywords)")
			print("🆕 What's New: \(metadata.whatsNew ?? "None")")
			print("📣 Promotional Text: \(metadata.promotionalText)")
			print("🗒️ Review Notes: \(metadata.reviewNotes)")
			print("------------------------\n")

			print("Do you want to upload this metadata? [y/N]")
			if let answer = readLine()?.lowercased(), answer == "y" {
				var contactInfo = try await service.reviews.fetchContactInfo()
				
				if contactInfo.firstName == nil {
					print("👤 Enter App Review Contact First Name:")
					contactInfo.firstName = readLine()
				}
				if contactInfo.lastName == nil {
					print("👤 Enter App Review Contact Last Name:")
					contactInfo.lastName = readLine()
				}
				if contactInfo.email == nil {
					print("📧 Enter App Review Contact Email:")
					contactInfo.email = readLine()
				}
				if contactInfo.phone == nil {
					print("📱 Enter App Review Contact Phone (e.g., +1 555-555-5555):")
					contactInfo.phone = readLine()
				}

				let domain = contactInfo.email?.split(separator: "@").last.map(String.init) ?? "example.com"
				let urls = (support: "https://\(domain)/support", marketing: "https://\(domain)")
				let teamName = (contactInfo.firstName ?? "") + " " + (contactInfo.lastName ?? "")
				let copyright = "© \(Calendar.current.component(.year, from: Date())) \(teamName.trimmingCharacters(in: .whitespaces))"

				try await UI.step("Uploading metadata to App Store Connect", emoji: "🚀") {
					try await service.metadata.updateMetadata(
						versionId: draft.id,
						metadata: metadata,
						urls: urls,
						copyright: copyright,
						contactInfo: contactInfo
					)
				}
				UI.success("Metadata updated successfully!")
			} else {
				UI.info("Upload cancelled.", emoji: "❌")
			}
		}
	}

	struct Description: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch app description.")
		@Option(name: .long, help: "The new description.") var set: String?
		@Flag(name: .long, help: "Fetch the current description.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching description", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.description ?? "No description found.")
			} else if let set = set {
				try await UI.step("Updating description", emoji: "📝") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: set, keywords: nil, promotionalText: nil, marketingURL: nil, supportURL: nil, whatsNew: nil)
				}
				UI.success("Description updated.")
			}
		}
	}

	struct Keywords: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch app keywords.")
		@Option(name: .long, help: "The new keywords (comma-separated).") var set: String?
		@Flag(name: .long, help: "Fetch the current keywords.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching keywords", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.keywords ?? "No keywords found.")
			} else if let set = set {
				try await UI.step("Updating keywords", emoji: "🔑") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: nil, keywords: set, promotionalText: nil, marketingURL: nil, supportURL: nil, whatsNew: nil)
				}
				UI.success("Keywords updated.")
			}
		}
	}

	struct WhatsNew: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch 'What's New in this Version'.")
		@Option(name: .long, help: "The new release notes.") var set: String?
		@Flag(name: .long, help: "Fetch the current release notes.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching What's New", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.whatsNew ?? "No release notes found.")
			} else if let set = set {
				try await UI.step("Updating What's New", emoji: "🆕") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: nil, keywords: nil, promotionalText: nil, marketingURL: nil, supportURL: nil, whatsNew: set)
				}
				UI.success("What's New updated.")
			}
		}
	}

	struct PromotionalText: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch promotional text.")
		@Option(name: .long, help: "The new promotional text.") var set: String?
		@Flag(name: .long, help: "Fetch the current promotional text.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching promotional text", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.promotionalText ?? "No promotional text found.")
			} else if let set = set {
				try await UI.step("Updating promotional text", emoji: "📣") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: nil, keywords: nil, promotionalText: set, marketingURL: nil, supportURL: nil, whatsNew: nil)
				}
				UI.success("Promotional text updated.")
			}
		}
	}

	struct ReviewNotes: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch app review notes.")
		@Option(name: .long, help: "The new review notes.") var set: String?
		@Flag(name: .long, help: "Fetch the current review notes.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let review = try await UI.step("Fetching review notes", emoji: "🔍") {
					try await service.metadata.fetchReviewDetail(versionId: draft.id)
				}
				print(review.notes ?? "No review notes found.")
			} else if let set = set {
				try await UI.step("Updating review notes", emoji: "🗒️") {
					try await service.metadata.updateReviewDetail(versionId: draft.id, contactInfo: nil, notes: set)
				}
				UI.success("Review notes updated.")
			}
		}
	}

	struct Copyright: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch copyright info.")
		@Option(name: .long, help: "The new copyright string.") var set: String?
		@Flag(name: .long, help: "Fetch the current copyright info.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let ver = try await UI.step("Fetching copyright", emoji: "🔍") {
					try await service.metadata.fetchVersionAttributes(versionId: draft.id)
				}
				print(ver.copyright ?? "No copyright info found.")
			} else if let set = set {
				try await UI.step("Updating copyright", emoji: "©️") {
					try await service.metadata.updateVersionAttributes(versionId: draft.id, copyright: set)
				}
				UI.success("Copyright updated.")
			}
		}
	}

	struct SupportURL: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch support URL.")
		@Option(name: .long, help: "The new support URL.") var set: String?
		@Flag(name: .long, help: "Fetch the current support URL.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching support URL", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.supportURL ?? "No support URL found.")
			} else if let set = set {
				try await UI.step("Updating support URL", emoji: "🛠️") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: nil, keywords: nil, promotionalText: nil, marketingURL: nil, supportURL: set, whatsNew: nil)
				}
				UI.success("Support URL updated.")
			}
		}
	}

	struct MarketingURL: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch marketing URL.")
		@Option(name: .long, help: "The new marketing URL.") var set: String?
		@Flag(name: .long, help: "Fetch the current marketing URL.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let loc = try await UI.step("Fetching marketing URL", emoji: "🔍") {
					try await service.metadata.fetchLocalization(versionId: draft.id)
				}
				print(loc.marketingURL ?? "No marketing URL found.")
			} else if let set = set {
				try await UI.step("Updating marketing URL", emoji: "📈") {
					try await service.metadata.updateLocalization(versionId: draft.id, description: nil, keywords: nil, promotionalText: nil, marketingURL: set, supportURL: nil, whatsNew: nil)
				}
				UI.success("Marketing URL updated.")
			}
		}
	}

	struct Contact: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Update or fetch app review contact info.")
		
		@Option(name: .long, help: "First name.") var first: String?
		@Option(name: .long, help: "Last name.") var last: String?
		@Option(name: .long, help: "Email address.") var email: String?
		@Option(name: .long, help: "Phone number.") var phone: String?
		@Flag(name: .long, help: "Fetch current contact info.") var get: Bool = false

		func run() async throws {
			let service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
			let config = try? Environment.live.project.loadConfig(at: Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: "."))
			let draft = try await MetadataUtils.fetchDraft(service: service, bundleIdentifier: config?.bundleIdentifier)

			if get {
				let review = try await UI.step("Fetching contact info", emoji: "🔍") {
					try await service.metadata.fetchReviewDetail(versionId: draft.id)
				}
				let c = review.contactInfo
				print("Name: \(c.firstName ?? "") \(c.lastName ?? "")")
				print("Email: \(c.email ?? "")")
				print("Phone: \(c.phone ?? "")")
			} else {
				let contact = ContactInfo(firstName: first, lastName: last, email: email, phone: phone)
				try await UI.step("Updating contact info", emoji: "👤") {
					try await service.metadata.updateReviewDetail(versionId: draft.id, contactInfo: contact, notes: nil)
				}
				UI.success("Contact info updated.")
			}
		}
	}
}