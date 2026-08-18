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
    
    private var cornerRadius: CGFloat {
        model.isExpanded ? 0 : 12
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if model.isExpanded {
                // Top breathing room bar so content doesn't hit macOS menu bar or notch
                Color.black
                    .frame(height: 20)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1),
                        alignment: .bottom
                    )
            }
            
            ZStack {
                Color.black
                
                if model.isHomeScreenActive {
                    HomeScreenView(model: model)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    WebViewContainer(model: model)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            
            
            
            // Action Overlay Buttons (Home & Fullscreen controls)
            if isShowingOverlay && model.isInteracting {
                VStack {
                    if innerCornerAlignment == .bottomLeading || innerCornerAlignment == .bottomTrailing {
                        Spacer()
                    }
                    
                    HStack {
                        if innerCornerAlignment == .bottomTrailing || innerCornerAlignment == .topTrailing {
                            Spacer()
                        }
                        
                        HStack(spacing: 8) {
                            // Return Home Button (when viewing a stream)
                            if !model.isHomeScreenActive {
                                Button(action: {
                                    model.isHomeScreenActive = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "house.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Home")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.5), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                            
                            // Fullscreen Button
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
                            .focusable(false)
                        }
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
                .animation(.easeInOut(duration: 0.2), value: isShowingOverlay && model.isInteracting)
            }
        }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingOverlay = hovering
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .mask(GhostSpotlightMaskView(model: model))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(model.isExpanded ? 0 : 0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(model.isExpanded ? 0 : 0.4), radius: 10, x: 0, y: 5)
    }
}

struct GhostSpotlightMaskView: View {
    @ObservedObject var model: StreamyModel

    var body: some View {
        if model.isEvading && model.evasionMode == .ghost, let pos = model.mousePositionInWindow {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)
                let centerPoint = UnitPoint(x: pos.x / w, y: pos.y / h)
                let stops: [Gradient.Stop] = [
                    .init(color: Color.black.opacity(0.15), location: 0.0),
                    .init(color: Color.black.opacity(0.15), location: 0.25),
                    .init(color: Color.black.opacity(0.65), location: 0.85),
                    .init(color: Color.black.opacity(0.65), location: 1.0)
                ]
                
                RadialGradient(
                    gradient: Gradient(stops: stops),
                    center: centerPoint,
                    startRadius: 0,
                    endRadius: 40
                )
            }
        } else if model.isEvading && model.evasionMode == .ghost {
            Color.black.opacity(0.65)
        } else {
            Color.black
        }
    }
}
