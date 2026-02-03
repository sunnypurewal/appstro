import ArgumentParser
import Foundation

@main
struct Appstro: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility for creating and submitting iOS apps from the command line.",
        subcommands: [Init.self, App.self, Login.self, Create.self, Submission.self, Info.self, Build.self, Profile.self],
        defaultSubcommand: Init.self
    )
}
