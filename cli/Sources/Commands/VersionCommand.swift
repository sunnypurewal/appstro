import ArgumentParser
import Foundation

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the version of appstro."
    )

    func run() async throws {
        print("appstro version \(AppstroVersion.current) (build \(AppstroVersion.build))")
    }
}
