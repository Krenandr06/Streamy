import Foundation
import Combine
import SwiftUI
import AppKit

public enum CornerPosition: String, CaseIterable, Codable, Identifiable {
    case topRight = "Top Right"
    case topLeft = "Top Left"
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    
    public var id: String { rawValue }
}

public enum EvasionMode: String, CaseIterable, Codable, Identifiable {
    case ghost = "Ghost (Fade & Click-Through)"
    case slide = "Slide (Dodge to Corner)"
    case peek = "Edge Tuck (Slide off-screen tab)"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}


public enum IntersectModifierKey: String, CaseIterable, Codable, Identifiable {
    case command = "Command (⌘)"
    case option = "Option (⌥)"
    case control = "Control (⌃)"
    case shift = "Shift (⇧)"
    
    public var id: String { rawValue }
    
    public var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}

public final class StreamyModel: ObservableObject {
    public static let shared = StreamyModel()
    
    @Published public var currentURL: String {
        didSet { UserDefaults.standard.set(currentURL, forKey: "currentURL") }
    }
    
    @Published public var pinnedCorner: CornerPosition {
        didSet { UserDefaults.standard.set(pinnedCorner.rawValue, forKey: "pinnedCorner") }
    }
    
    @Published public var evasionMode: EvasionMode {
        didSet { UserDefaults.standard.set(evasionMode.rawValue, forKey: "evasionMode") }
    }
    
    @Published public var modifierKey: IntersectModifierKey {
        didSet { UserDefaults.standard.set(modifierKey.rawValue, forKey: "modifierKey") }
    }
    
    @Published public var followActiveScreen: Bool {
        didSet { UserDefaults.standard.set(followActiveScreen, forKey: "followActiveScreen") }
    }
    
    @Published public var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowWidth), forKey: "windowWidth") }
    }
    
    @Published public var windowHeight: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowHeight), forKey: "windowHeight") }
    }
    
    @Published public var ghostOpacity: Double {
        didSet { UserDefaults.standard.set(ghostOpacity, forKey: "ghostOpacity") }
    }
    
    @Published public var evasionDistance: CGFloat {
        didSet { UserDefaults.standard.set(Double(evasionDistance), forKey: "evasionDistance") }
    }
    
    @Published public var watchHistory: [WatchHistoryItem] = [] {
        didSet { saveWatchHistory() }
    }
    
    @Published public var isHomeScreenActive: Bool {
        didSet { UserDefaults.standard.set(isHomeScreenActive, forKey: "isHomeScreenActive") }
    }
    
    // Runtime state
    @Published public var isInteracting: Bool = false
    @Published public var isEvading: Bool = false
    @Published public var isExpanded: Bool = false
    @Published public var isUserDraggingWindow: Bool = false
    @Published public var mousePositionInWindow: CGPoint? = nil
    public var preExpandedSize: NSSize?
    public var preExpandedFrame: NSRect?
    
    private init() {
        self.currentURL = UserDefaults.standard.string(forKey: "currentURL") ?? "https://www.youtube.com"
        
        self.isHomeScreenActive = UserDefaults.standard.object(forKey: "isHomeScreenActive") != nil ? UserDefaults.standard.bool(forKey: "isHomeScreenActive") : true
        
        if let rawCorner = UserDefaults.standard.string(forKey: "pinnedCorner"),
           let corner = CornerPosition(rawValue: rawCorner) {
            self.pinnedCorner = corner
        } else {
            self.pinnedCorner = .topRight
        }
        
        if let rawEvasion = UserDefaults.standard.string(forKey: "evasionMode"),
           let evasion = EvasionMode(rawValue: rawEvasion) {
            self.evasionMode = evasion
        } else {
            self.evasionMode = .ghost
        }
        
        if let rawKey = UserDefaults.standard.string(forKey: "modifierKey"),
           let key = IntersectModifierKey(rawValue: rawKey) {
            self.modifierKey = key
        } else {
            self.modifierKey = .command
        }
        
        self.followActiveScreen = UserDefaults.standard.object(forKey: "followActiveScreen") != nil ? UserDefaults.standard.bool(forKey: "followActiveScreen") : true
        
        let width = UserDefaults.standard.double(forKey: "windowWidth")
        self.windowWidth = width > 100 ? CGFloat(width) : 480.0
        
        let height = UserDefaults.standard.double(forKey: "windowHeight")
        self.windowHeight = height > 50 ? CGFloat(height) : 270.0
        
        let gOpacity = UserDefaults.standard.double(forKey: "ghostOpacity")
        self.ghostOpacity = gOpacity > 0 ? gOpacity : 0.65
        
        let distance = UserDefaults.standard.double(forKey: "evasionDistance")
        self.evasionDistance = distance > 0 ? CGFloat(distance) : 10.0
        
        loadWatchHistory()
    }
    
    public func recordWatchHistory(title: String, urlString: String) {
        guard !urlString.isEmpty, urlString != "about:blank" else { return }
        
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else { return }
        let cleanHost = host.replacingOccurrences(of: "www.", with: "")
        let path = url.path.lowercased()
        
        // Filter out generic landing pages / search results
        let isRoot = path.isEmpty || path == "/" || path == "/index.html"
        let isGenericSearch = path.contains("/results") || path.contains("/search")
        if isRoot || isGenericSearch {
            return
        }
        
        // Additional video specific filter for YouTube & Twitch
        if cleanHost.contains("youtube") {
            let isVideoPage = path.contains("/watch") || path.contains("/shorts") || path.contains("/live") || urlString.contains("v=")
            if !isVideoPage { return }
        } else if cleanHost.contains("twitch") {
            if path.count <= 1 || path.contains("/directory") { return }
        }
        
        var cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { return }
        
        // Remove common site suffix headers to display clean video title
        let suffixesToRemove = [
            " - YouTube", " - Twitch", " | Netflix", " - Hulu",
            " - Disney+", " | Spotify", " | Apple Music", " - Crunchyroll",
            " | Max", " | Prime Video", " - Google Search"
        ]
        for suffix in suffixesToRemove {
            if cleanTitle.hasSuffix(suffix) {
                cleanTitle = String(cleanTitle.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Skip if title is just generic site name
        let genericNames = ["YouTube", "Twitch", "Netflix", "Hulu", "Disney+", "Spotify", "Apple Music", "Max", "Prime Video"]
        if genericNames.contains(cleanTitle) {
            return
        }
        
        let appName: String
        if cleanHost.contains("youtube") { appName = "YouTube" }
        else if cleanHost.contains("twitch") { appName = "Twitch" }
        else if cleanHost.contains("netflix") { appName = "Netflix" }
        else if cleanHost.contains("hulu") { appName = "Hulu" }
        else if cleanHost.contains("disney") { appName = "Disney+" }
        else if cleanHost.contains("max") { appName = "Max" }
        else if cleanHost.contains("primevideo") { appName = "Prime Video" }
        else if cleanHost.contains("spotify") { appName = "Spotify" }
        else if cleanHost.contains("music.apple") { appName = "Apple Music" }
        else if cleanHost.contains("crunchyroll") { appName = "Crunchyroll" }
        else { appName = cleanHost.capitalized }
        
        // Move to top if already exists
        watchHistory.removeAll { $0.urlString == urlString }
        
        let newItem = WatchHistoryItem(
            title: cleanTitle,
            urlString: urlString,
            domain: cleanHost,
            dateWatched: Date(),
            appName: appName
        )
        
        watchHistory.insert(newItem, at: 0)
        
        if watchHistory.count > 50 {
            watchHistory = Array(watchHistory.prefix(50))
        }
    }
    
    public func removeWatchHistoryItem(id: UUID) {
        watchHistory.removeAll { $0.id == id }
    }
    
    public func clearWatchHistory() {
        watchHistory.removeAll()
    }
    
    private func saveWatchHistory() {
        do {
            let data = try JSONEncoder().encode(watchHistory)
            UserDefaults.standard.set(data, forKey: "watchHistory")
        } catch {
            print("Failed to save watch history locally: \(error)")
        }
    }
    
    private func loadWatchHistory() {
        guard let data = UserDefaults.standard.data(forKey: "watchHistory") else { return }
        do {
            let items = try JSONDecoder().decode([WatchHistoryItem].self, from: data)
            self.watchHistory = items
        } catch {
            print("Failed to load watch history: \(error)")
        }
    }
}

