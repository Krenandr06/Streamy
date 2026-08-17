import Foundation
import SwiftUI

public struct AppPreset: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let urlString: String
    public let iconSymbol: String
    public let accentColorHex: String
    public let category: String
    
    public var accentColor: Color {
        Color(hex: accentColorHex) ?? .purple
    }
    
    public init(id: String, name: String, urlString: String, iconSymbol: String, accentColorHex: String, category: String) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.iconSymbol = iconSymbol
        self.accentColorHex = accentColorHex
        self.category = category
    }
    
    public static let defaults: [AppPreset] = [
        AppPreset(id: "youtube", name: "YouTube", urlString: "https://www.youtube.com", iconSymbol: "play.tv.fill", accentColorHex: "#FF0000", category: "Video"),
        AppPreset(id: "twitch", name: "Twitch", urlString: "https://www.twitch.tv", iconSymbol: "gamecontroller.fill", accentColorHex: "#9146FF", category: "Live Streams"),
        AppPreset(id: "netflix", name: "Netflix", urlString: "https://www.netflix.com", iconSymbol: "film.fill", accentColorHex: "#E50914", category: "Movies & TV"),
        AppPreset(id: "hulu", name: "Hulu", urlString: "https://www.hulu.com", iconSymbol: "popcorn.fill", accentColorHex: "#1CE783", category: "Movies & TV"),
        AppPreset(id: "disney", name: "Disney+", urlString: "https://www.disneyplus.com", iconSymbol: "sparkles", accentColorHex: "#113CCF", category: "Movies & TV"),
        AppPreset(id: "max", name: "Max", urlString: "https://www.max.com", iconSymbol: "tv.fill", accentColorHex: "#002BE7", category: "Movies & TV"),
        AppPreset(id: "prime", name: "Prime Video", urlString: "https://www.primevideo.com", iconSymbol: "play.rectangle.fill", accentColorHex: "#00A8E1", category: "Movies & TV"),
        AppPreset(id: "spotify", name: "Spotify", urlString: "https://open.spotify.com", iconSymbol: "music.note.list", accentColorHex: "#1DB954", category: "Audio"),
        AppPreset(id: "applemusic", name: "Apple Music", urlString: "https://music.apple.com", iconSymbol: "music.quaver", accentColorHex: "#FA243C", category: "Audio"),
        AppPreset(id: "crunchyroll", name: "Crunchyroll", urlString: "https://www.crunchyroll.com", iconSymbol: "flame.fill", accentColorHex: "#F47521", category: "Anime")
    ]
}

extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.remove(at: cleanHex.startIndex)
        }
        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else { return nil }
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
