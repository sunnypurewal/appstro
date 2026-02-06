import AppstroCore
import Foundation

public struct DefaultAppQueryInterpreter: AppQueryInterpreter {
	
	public init() {}
	
	public func interpret(_ parameter: String) -> AppQuery {
		if parameter.contains(".") && !parameter.contains(" ") {
			return AppQuery(type: .bundleId(parameter))
		} else {
			return AppQuery(type: .name(parameter))
		}
	}
}