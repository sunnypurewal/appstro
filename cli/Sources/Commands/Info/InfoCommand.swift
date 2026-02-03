import ArgumentParser
import Foundation

struct Info: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Manage app-level information and declarations.",
        subcommands: [
            ContentRights.self,
            AgeRatings.self,
            Privacy.self,
            DataCollection.self,
            Pricing.self
        ]
    )
}
