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
    
    // Runtime state
    @Published public var isInteracting: Bool = false
    @Published public var isEvading: Bool = false
    @Published public var isExpanded: Bool = false
    public var preExpandedSize: NSSize?
    
    private init() {
        self.currentURL = UserDefaults.standard.string(forKey: "currentURL") ?? "https://www.youtube.com"
        
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
        self.ghostOpacity = gOpacity > 0 ? gOpacity : 0.15
        
        let distance = UserDefaults.standard.double(forKey: "evasionDistance")
        self.evasionDistance = distance > 10 ? CGFloat(distance) : 70.0
    }
}
