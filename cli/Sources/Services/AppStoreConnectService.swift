import Foundation
import CryptoKit

enum AppStoreConnectError: Error {
    case invalidResponse
    case apiError(String)
    case missingCredentials
    case invalidPrivateKey
}

struct AppDetails {
    let name: String
    let bundleId: String
    let appStoreUrl: String
    let publishedVersion: String?
}

actor AppStoreConnectService {
    private let issuerId: String
    private let keyId: String
    private let privateKey: String

    init(issuerId: String, keyId: String, privateKey: String) {
        self.issuerId = issuerId
        self.keyId = keyId
        self.privateKey = privateKey
    }

    func fetchAppDetails(query: AppQuery) async throws -> AppDetails? {
        let token = try generateJWT()
        
        var urlComponents = URLComponents(string: "https://api.appstoreconnect.apple.com/v1/apps")!
        var queryItems = [
            URLQueryItem(name: "include", value: "appStoreVersions"),
            URLQueryItem(name: "limit[appStoreVersions]", value: "10"),
            URLQueryItem(name: "limit", value: "200")
        ]
        
        switch query.type {
        case .name:
            break
        case .bundleId(let bundleId):
            queryItems.append(URLQueryItem(name: "filter[bundleId]", value: bundleId))
        }
        
        urlComponents.queryItems = queryItems
        
        let apiResponse: AppResponse = try await performRequest(url: urlComponents.url!, token: token)
        
        let appData: AppData?
        switch query.type {
        case .name(let name):
            appData = apiResponse.data.first { $0.attributes.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        case .bundleId:
            appData = apiResponse.data.first
        }
        
        guard let app = appData else {
            return nil
        }
        
        let publishedVersion = findPublishedVersion(appData: app, included: apiResponse.included ?? [])
        
        return AppDetails(
            name: app.attributes.name,
            bundleId: app.attributes.bundleId,
            appStoreUrl: "https://apps.apple.com/app/id\(app.id)",
            publishedVersion: publishedVersion
        )
    }

    func deduceBundleIdPrefix(preferredPrefix: String?) async throws -> String? {
        // 0. Prioritize manually entered prefix from preferences
        if let preferredPrefix = preferredPrefix {
            return preferredPrefix
        }

        let token = try generateJWT()
        
        // 1. Try historical Bundle IDs
        let bundleIdsUrl = URL(string: "https://api.appstoreconnect.apple.com/v1/bundleIds?limit=200")!
        let bundleResponse: BundleIdResponse = try await performRequest(url: bundleIdsUrl, token: token)
        
        let identifiers = bundleResponse.data.map { $0.attributes.identifier }
        if let prefix = findMostFrequentPrefix(identifiers: identifiers) {
            return prefix
        }
        
        // 2. Try email domain fallback
        let usersUrl = URL(string: "https://api.appstoreconnect.apple.com/v1/users?limit=10")!
        let userResponse: UserResponse = try await performRequest(url: usersUrl, token: token)
        
        if let email = userResponse.data.first?.attributes.username {
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
        let token = try generateJWT()
        
        // 1. Check if identifier already exists
        let filterUrl = URL(string: "https://api.appstoreconnect.apple.com/v1/bundleIds?filter[identifier]=\(identifier)")!
        let existingBundleResponse: BundleIdResponse = try await performRequest(url: filterUrl, token: token)
        
        if let existing = existingBundleResponse.data.first {
            return existing.id
        }
        
        // 2. Register if it doesn't exist
        let registerBody = BundleIdCreateRequest(
            data: BundleIdCreateRequest.Data(
                attributes: BundleIdCreateRequest.Data.Attributes(
                    identifier: identifier,
                    name: name,
                    platform: "IOS"
                )
            )
        )
        let registerUrl = URL(string: "https://api.appstoreconnect.apple.com/v1/bundleIds")!
        let newBundle: BundleIdData = try await performPostRequest(url: registerUrl, token: token, body: registerBody)
        return newBundle.id
    }

    func listApps() async throws -> [AppData] {
        let token = try generateJWT()
        let url = URL(string: "https://api.appstoreconnect.apple.com/v1/apps?limit=100")!
        let response: AppResponse = try await performRequest(url: url, token: token)
        return response.data
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

    private func performRequest<T: Codable>(url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try await validateResponse(data: data, response: response)
        
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func performPostRequest<T: Codable, B: Codable>(url: URL, token: String, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try await validateResponse(data: data, response: response)
        
        let wrapper = try JSONDecoder().decode(DataWrapper<T>.self, from: data)
        return wrapper.data
    }

    private func validateResponse(data: Data, response: URLResponse) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStoreConnectError.invalidResponse
        }
        
        if httpResponse.statusCode == 409 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let msg = errorResponse?.errors.first?.detail ?? "Conflict"
            if msg.contains("name") {
                throw AppStoreConnectError.apiError("The app name is already in use by another developer on the App Store. App names must be unique globally.")
            } else if msg.contains("identifier") {
                throw AppStoreConnectError.apiError("The bundle ID is already registered in your developer account.")
            }
            throw AppStoreConnectError.apiError(msg)
        }
        
        if httpResponse.statusCode == 403 {
            throw AppStoreConnectError.apiError("Your API key lacks the 'Admin' or 'App Manager' role required to create apps. Also, please ensure you have accepted all pending legal agreements in the 'Agreements, Tax, and Banking' section of App Store Connect.")
        }
        
        if httpResponse.statusCode >= 400 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppStoreConnectError.apiError("HTTP \(httpResponse.statusCode): \(errorMsg)")
        }
    }

    private func findPublishedVersion(appData: AppData, included: [Included]) -> String? {
        guard let versionIds = appData.relationships?.appStoreVersions?.data?.map({ $0.id }) else {
            return nil
        }
        
        for versionId in versionIds {
            if let version = included.first(where: { $0.type == "appStoreVersions" && $0.id == versionId }),
               let attributes = version.attributes,
               attributes.appStoreState == "READY_FOR_SALE" {
                return attributes.versionString
            }
        }
        
        return nil
    }

    private func generateJWT() throws -> String {
        let header = ["alg": "ES256", "kid": keyId, "typ": "JWT"]
        let headerBase64 = try jsonToBase64Url(header)
        
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": issuerId,
            "exp": now + 1200, 
            "aud": "appstoreconnect-v1"
        ]
        let payloadBase64 = try jsonToBase64Url(payload)
        
        let message = "\(headerBase64).\(payloadBase64)"
        let signature = try sign(message: message)
        
        return "\(message).\(signature)"
    }

    private func jsonToBase64Url(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func sign(message: String) throws -> String {
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: privateKey)
        } catch {
            throw AppStoreConnectError.invalidPrivateKey
        }
        
        let signature = try key.signature(for: Data(message.utf8))
        return signature.rawRepresentation.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// Additional Models
struct BundleIdResponse: Codable {
    let data: [BundleIdData]
}

struct BundleIdData: Codable {
    let id: String
    let attributes: BundleIdAttributes
}

struct BundleIdAttributes: Codable {
    let identifier: String
    let name: String
}

struct UserResponse: Codable {
    let data: [UserData]
}

struct UserData: Codable {
    let attributes: UserAttributes
}

struct UserAttributes: Codable {
    let username: String
    let roles: [String]
}

struct BundleIdCreateRequest: Codable {
    struct Data: Codable {
        struct Attributes: Codable {
            let identifier: String
            let name: String
            let platform: String
        }
        let attributes: Attributes
        let type: String
        
        init(attributes: Attributes) {
            self.attributes = attributes
            self.type = "bundleIds"
        }
    }
    let data: Data
}

struct AppCreateRequest: Codable {
    struct Data: Codable {
        struct Attributes: Codable {
            let name: String
            let primaryLocale: String
            let sku: String
        }
        struct Relationships: Codable {
            struct BundleId: Codable {
                struct Data: Codable {
                    let id: String
                    let type: String
                    
                    init(id: String) {
                        self.id = id
                        self.type = "bundleIds"
                    }
                }
                let data: Data
            }
            let bundleId: BundleId
        }
        let attributes: Attributes
        let relationships: Relationships
        let type: String
        
        init(attributes: Attributes, relationships: Relationships) {
            self.attributes = attributes
            self.relationships = relationships
            self.type = "apps"
        }
    }
    let data: Data
}

struct APIErrorResponse: Codable {
    struct Error: Codable {
        let detail: String
    }
    let errors: [Error]
}

struct DataWrapper<T: Codable>: Codable {
    let data: T
}

// API Models
struct AppResponse: Codable {
    let data: [AppData]
    let included: [Included]?
}

struct AppData: Codable {
    let id: String
    let attributes: AppAttributes
    let relationships: AppRelationships?
}

struct AppAttributes: Codable {
    let name: String
    let bundleId: String
}

struct AppRelationships: Codable {
    let appStoreVersions: AppStoreVersions?
}

struct AppStoreVersions: Codable {
    let data: [AppStoreVersionData]?
}

struct AppStoreVersionData: Codable {
    let id: String
    let type: String
}

struct Included: Codable {
    let type: String
    let id: String
    let attributes: IncludedAttributes?
}

struct IncludedAttributes: Codable {
    let versionString: String?
    let appStoreState: String?
}

