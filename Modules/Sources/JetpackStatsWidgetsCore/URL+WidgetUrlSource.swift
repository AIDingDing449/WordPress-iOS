import Foundation

public extension URL {

    func appendingSource(_ source: WidgetUrlSource) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        let sourceQuery = URLQueryItem(name: "source", value: source.rawValue)
        queryItems.append(sourceQuery)
        components?.queryItems = queryItems
        return components?.url ?? self
    }
}
