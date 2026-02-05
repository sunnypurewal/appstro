import Foundation

public struct BuildInfo: Sendable {
	public let id: String
	public let version: String
	public let processingState: BuildProcessingState

	public init(id: String, version: String, processingState: BuildProcessingState) {
		self.id = id
		self.version = version
		self.processingState = processingState
	}
}

public enum BuildProcessingState: String, Sendable {
	case valid = "VALID"
	case invalid = "INVALID"
	case processing = "PROCESSING"
	case failed = "FAILED"
	case unknown = "UNKNOWN"
}

public enum AppVersionState: String, Sendable {
	case prepareForSubmission = "PREPARE_FOR_SUBMISSION"
	case readyForSale = "READY_FOR_SALE"
	case rejected = "REJECTED"
	case developerRejected = "DEVELOPER_REJECTED"
	case waitingForReview = "WAITING_FOR_REVIEW"
	case inReview = "IN_REVIEW"
	case metadataRejected = "METADATA_REJECTED"
	case other = "OTHER"
}
