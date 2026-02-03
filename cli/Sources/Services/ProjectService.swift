import Foundation

struct ProjectConfig: Codable {
    let name: String
    let description: String
    let appPath: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case appPath = "app_path"
    }
}

final class ProjectService: Sendable {
    static let shared = ProjectService()
    
    func findProjectRoot() -> URL? {
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        
        for _ in 0...5 {
            let checkURL = currentDir.appendingPathComponent("appstro.json")
            if fileManager.fileExists(atPath: checkURL.path) {
                return currentDir
            }
            let parentDir = currentDir.deletingLastPathComponent()
            if parentDir == currentDir { break }
            currentDir = parentDir
        }
        
        return nil
    }
    
    func loadConfig(at root: URL) throws -> ProjectConfig {
        let configURL = root.appendingPathComponent("appstro.json")
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(ProjectConfig.self, from: data)
    }
}
