import Foundation

struct AppQuery {
    enum QueryType {
        case name(String)
        case bundleId(String)
    }
    let type: QueryType
}

struct AppQueryInterpreter {
    func interpret(_ parameter: String) -> AppQuery {
        // Simple heuristic: if it contains a dot and doesn't have spaces, it's likely a bundle ID
        if parameter.contains(".") && !parameter.contains(" ") {
            return AppQuery(type: .bundleId(parameter))
        } else {
            return AppQuery(type: .name(parameter))
        }
    }
}
