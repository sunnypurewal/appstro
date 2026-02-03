import ArgumentParser
import Foundation

struct Submission: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "submission",
        abstract: "Manage App Store submissions.",
        subcommands: [Screenshots.self, Metadata.self, Upload.self, Submit.self]
    )
}
