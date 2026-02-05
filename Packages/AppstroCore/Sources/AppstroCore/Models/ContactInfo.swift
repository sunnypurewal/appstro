import Foundation

public struct ContactInfo: Sendable {
	public var firstName: String?
	public var lastName: String?
	public var email: String?
	public var phone: String?

	public init(firstName: String? = nil, lastName: String? = nil, email: String? = nil, phone: String? = nil) {
		self.firstName = firstName
		self.lastName = lastName
		self.email = email
		self.phone = phone
	}
}
