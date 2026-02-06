import AppstroCore
import ArgumentParser
import Foundation

struct Submission: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "submission",
		abstract: "Manage App Store submissions.",
		subcommands: [CreateSubmission.self, Screenshots.self, Metadata.self, Upload.self, Submit.self, Attach.self, Cancel.self, AddBuild.self, AppClipCommand.self]
	)
}
