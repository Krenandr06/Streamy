import SwiftUI

public struct HomeScreenView: View {
    @ObservedObject var model: StreamyModel
    @State private var searchText: String = ""
    @State private var hoveredAppId: String? = nil
    
    public init(model: StreamyModel) {
        self.model = model
    }
    
    private let appPresets = AppPreset.defaults
    
    public var body: some View {
        ZStack {
            // Background theme
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.04, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header & Apps Section
                VStack(alignment: .leading, spacing: 12) {
                    // Header Title
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Streamy")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 14)
                    
                    // Apps Section: Compact Horizontal Long Rounded Rectangle Chips
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APPS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(1.0)
                            .padding(.horizontal, 14)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(appPresets) { preset in
                                    Button(action: {
                                        launchApp(preset.urlString)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.iconSymbol)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(preset.accentColor)
                                            
                                            Text(preset.name)
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            hoveredAppId == preset.id ?
                                            preset.accentColor.opacity(0.25) : Color.white.opacity(0.06)
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    hoveredAppId == preset.id ?
                                                    preset.accentColor.opacity(0.7) : Color.white.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        )
                                        .scaleEffect(hoveredAppId == preset.id ? 1.03 : 1.0)
                                        .animation(.easeInOut(duration: 0.15), value: hoveredAppId)
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .onHover { hovering in
                                        hoveredAppId = hovering ? preset.id : nil
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Recently Watched Section (Middle Scroll Area)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RECENTLY WATCHED")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .tracking(1.0)
                            
                            Spacer()
                            
                            if !model.watchHistory.isEmpty {
                                Button(action: {
                                    model.clearWatchHistory()
                                }) {
                                    Text("Clear")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                        }
                        .padding(.top, 10)
                        
                        if model.watchHistory.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("No recent media yet")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(10)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(model.watchHistory) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: iconForApp(item.appName))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.blue)
                                            .frame(width: 24, height: 24)
                                            .background(Color.blue.opacity(0.15))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title)
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            
                                            HStack(spacing: 4) {
                                                Text(item.appName)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.gray)
                                                
                                                Text("•")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray.opacity(0.5))
                                                
                                                Text(timeAgoDisplay(date: item.dateWatched))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray.opacity(0.8))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Play Button
                                        Button(action: {
                                            launchApp(item.urlString)
                                        }) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(Color.blue.opacity(0.8))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                        
                                        // Delete Button
                                        Button(action: {
                                            model.removeWatchHistoryItem(id: item.id)
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.gray)
                                                .padding(4)
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                
                // Bottom Bar: Search & Custom URL Input
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                            .font(.system(size: 11, weight: .semibold))
                        
                        TextField("Enter URL or search term...", text: $searchText, onCommit: launchCustomURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white)
                            .focusable(false)
                        
                        if !searchText.isEmpty {
                            Button(action: launchCustomURL) {
                                Text("Open")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                }
            }
        }
    }
    
    private func launchApp(_ urlString: String) {
        model.currentURL = urlString
        model.isHomeScreenActive = false
    }
    
    private func launchCustomURL() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        launchApp(trimmed)
    }
    
    private func iconForApp(_ name: String) -> String {
        switch name.lowercased() {
        case "youtube": return "play.tv.fill"
        case "twitch": return "gamecontroller.fill"
        case "netflix", "hulu", "disney+", "max", "prime video": return "film.fill"
        case "spotify", "apple music": return "music.note"
        default: return "globe"
        }
    }
    
    private func timeAgoDisplay(date: Date) -> String {
        let secondsAgo = Int(Date().timeIntervalSince(date))
        if secondsAgo < 60 { return "Just now" }
        let minutes = secondsAgo / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
