import Foundation

public struct WatchHistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let urlString: String
    public let domain: String
    public let dateWatched: Date
    public let appName: String
    
    public init(id: UUID = UUID(), title: String, urlString: String, domain: String, dateWatched: Date = Date(), appName: String) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.domain = domain
        self.dateWatched = dateWatched
        self.appName = appName
    }
}
