import SwiftUI
import AppKit

public struct ContentView: View {
    @ObservedObject var model: StreamyModel
    @State private var isShowingOverlay: Bool = false
    
    // Callback to trigger window controller expand/fullscreen
    var onToggleExpand: (() -> Void)?
    
    public init(model: StreamyModel, onToggleExpand: (() -> Void)? = nil) {
        self.model = model
        self.onToggleExpand = onToggleExpand
    }
    
    // Middle-most corner alignment facing the screen center
    private var innerCornerAlignment: Alignment {
        switch model.pinnedCorner {
        case .topRight: return .bottomLeading
        case .topLeft: return .bottomTrailing
        case .bottomRight: return .topLeading
        case .bottomLeft: return .topTrailing
        }
    }
    
    public var body: some View {
        ZStack {
            Color.black
            
            WebViewContainer(model: model)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Subtle top banner when holding interaction key (⌘)
            if model.isInteracting {
                VStack {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(model.modifierKey.rawValue) Active — Resizable & Interactive")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(8)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Single Prominent Enlarge/Fullscreen Icon in the Middle-Most Corner
            if model.isInteracting || isShowingOverlay || model.isExpanded {
                VStack {
                    if innerCornerAlignment == .bottomLeading || innerCornerAlignment == .bottomTrailing {
                        Spacer()
                    }
                    
                    HStack {
                        if innerCornerAlignment == .bottomTrailing || innerCornerAlignment == .topTrailing {
                            Spacer()
                        }
                        
                        Button(action: {
                            onToggleExpand?()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: model.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .bold))
                                Text(model.isExpanded ? "Exit Fullscreen" : "Fullscreen")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(model.isExpanded ? Color.blue.opacity(0.9) : Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.5), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        
                        if innerCornerAlignment == .bottomLeading || innerCornerAlignment == .topLeading {
                            Spacer()
                        }
                    }
                    
                    if innerCornerAlignment == .topLeading || innerCornerAlignment == .topTrailing {
                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingOverlay = hovering
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}
