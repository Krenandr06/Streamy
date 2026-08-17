import AppKit
import SwiftUI
import Combine

public final class StreamyWindowController: NSWindowController {
    public let model: StreamyModel
    private var cancellables = Set<AnyCancellable>()
    private var currentTargetScreen: NSScreen?
    
    public init(model: StreamyModel) {
        self.model = model
        
        let panel = CustomPanel(
            contentRect: NSRect(x: 0, y: 0, width: model.windowWidth, height: model.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        super.init(window: panel)
        
        let contentView = ContentView(model: model) { [weak self] in
            self?.toggleFullscreenMode()
        }
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView


        
        panel.delegate = self
        setupSubscriptions()
        repositionWindow(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubscriptions() {
        // Reposition when corner changes
        model.$pinnedCorner
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.model.isExpanded == false {
                    self?.repositionWindow(animated: true)
                }
            }
            .store(in: &cancellables)
        
        // Reposition when window size changes
        Publishers.CombineLatest(model.$windowWidth, model.$windowHeight)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (w, h) in
                if self?.model.isExpanded == false {
                    self?.updateWindowSize(width: w, height: h)
                }
            }
            .store(in: &cancellables)
            
        // Handle interaction state change for resizing mask
        model.$isInteracting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interacting in
                self?.updateResizableMask(isInteracting: interacting)
            }
            .store(in: &cancellables)
        
        // Handle Evasion Mode change to ensure ghost state is cleared if disabled
        model.$evasionMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                if mode != .ghost {
                    self?.setGhostState(isGhost: false, alpha: 1.0)
                }
                if mode == .disabled {
                    self?.repositionWindow(animated: true)
                }
            }
            .store(in: &cancellables)
            
        // Listen for HTML5 Fullscreen requests (e.g. YouTube fullscreen button)
        NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFullscreenRequested"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let shouldEnter = notification.object as? Bool {
                    if shouldEnter && !self.model.isExpanded {
                        self.toggleFullscreenMode()
                    } else if !shouldEnter && self.model.isExpanded {
                        self.toggleFullscreenMode()
                    }
                } else {
                    self.toggleFullscreenMode()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateResizableMask(isInteracting: Bool) {
        guard let window = window else { return }
        if isInteracting {
            window.styleMask.insert(.resizable)
        } else {
            window.styleMask.remove(.resizable)
        }
    }
    
    public func toggleFullscreenMode() {
        guard let window = window else { return }
        let screen = targetScreen()
        
        if model.isExpanded {
            // Collapse back to corner PIP
            model.isExpanded = false
            window.contentView?.layer?.cornerRadius = 12
            if let preFrame = model.preExpandedFrame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(preFrame, display: true)
                }
            } else {
                repositionWindow(animated: true)
            }
        } else {
            // Store pre-expanded frame
            model.preExpandedFrame = window.frame
            model.isExpanded = true
            window.contentView?.layer?.cornerRadius = 0
            
            // Screen visible frame leaves breathing room for macOS menu bar & dock
            let fullScreenFrame = screen.visibleFrame
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(fullScreenFrame, display: true)
            }
        }
    }

    
    public func targetScreen() -> NSScreen {

        if model.followActiveScreen {
            let mouseLocation = NSEvent.mouseLocation
            let screens = NSScreen.screens
            for screen in screens {
                if NSMouseInRect(mouseLocation, screen.frame, false) {
                    return screen
                }
            }
        }
        return currentTargetScreen ?? NSScreen.main ?? NSScreen.screens.first!
    }
    
    public func repositionWindow(animated: Bool = true, screen: NSScreen? = nil) {
        guard let window = window else { return }
        
        let activeScreen = screen ?? targetScreen()
        self.currentTargetScreen = activeScreen
        
        let screenFrame = activeScreen.visibleFrame
        let padding: CGFloat = 20.0
        let w = model.windowWidth
        let h = model.windowHeight
        
        var targetX: CGFloat = 0
        var targetY: CGFloat = 0
        
        switch model.pinnedCorner {
        case .topRight:
            targetX = screenFrame.maxX - w - padding
            targetY = screenFrame.maxY - h - padding
        case .topLeft:
            targetX = screenFrame.minX + padding
            targetY = screenFrame.maxY - h - padding
        case .bottomRight:
            targetX = screenFrame.maxX - w - padding
            targetY = screenFrame.minY + padding
        case .bottomLeft:
            targetX = screenFrame.minX + padding
            targetY = screenFrame.minY + padding
        }
        
        let targetFrame = NSRect(x: targetX, y: targetY, width: w, height: h)
        
        if abs(window.frame.origin.x - targetX) < 1 && abs(window.frame.origin.y - targetY) < 1 && abs(window.frame.width - w) < 1 && abs(window.frame.height - h) < 1 {
            return
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }
    
    public func updateWindowSize(width: CGFloat, height: CGFloat) {
        guard let window = window else { return }
        var frame = window.frame
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true, animate: true)
        repositionWindow(animated: true)
    }
    
    public func updateGhostAlpha(alpha: Double, isGhost: Bool) {
        guard let window = window else { return }
        window.ignoresMouseEvents = isGhost
        if abs(window.alphaValue - CGFloat(alpha)) > 0.01 {
            window.alphaValue = CGFloat(alpha)
        }
    }
    
    public func setGhostState(isGhost: Bool, alpha: Double) {
        guard let window = window else { return }
        
        if isGhost {
            window.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                window.animator().alphaValue = CGFloat(alpha)
            }
        } else {
            window.ignoresMouseEvents = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 1.0
            }
        }
    }
    
    public func setSlideState(isEvading: Bool) {
        guard let window = window else { return }
        guard isEvading else {
            repositionWindow(animated: true)
            return
        }
        
        // Evade to opposite corner frame
        let activeScreen = targetScreen()
        let screenFrame = activeScreen.visibleFrame
        let padding: CGFloat = 20.0
        let w = model.windowWidth
        let h = model.windowHeight
        
        var evadeCorner: CornerPosition = .bottomLeft
        switch model.pinnedCorner {
        case .topRight: evadeCorner = .bottomLeft
        case .topLeft: evadeCorner = .bottomRight
        case .bottomRight: evadeCorner = .topLeft
        case .bottomLeft: evadeCorner = .topRight
        }
        
        var targetX: CGFloat = 0
        var targetY: CGFloat = 0
        
        switch evadeCorner {
        case .topRight:
            targetX = screenFrame.maxX - w - padding
            targetY = screenFrame.maxY - h - padding
        case .topLeft:
            targetX = screenFrame.minX + padding
            targetY = screenFrame.maxY - h - padding
        case .bottomRight:
            targetX = screenFrame.maxX - w - padding
            targetY = screenFrame.minY + padding
        case .bottomLeft:
            targetX = screenFrame.minX + padding
            targetY = screenFrame.minY + padding
        }
        
        let targetFrame = NSRect(x: targetX, y: targetY, width: w, height: h)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
    
    public func setPeekState(isEvading: Bool) {
        guard let window = window else { return }
        guard isEvading else {
            repositionWindow(animated: true)
            return
        }
        
        let activeScreen = targetScreen()
        let screenFrame = activeScreen.visibleFrame
        let tabVisibleWidth: CGFloat = 24.0
        let w = model.windowWidth
        let currentFrame = window.frame
        
        var targetX: CGFloat = currentFrame.origin.x
        
        switch model.pinnedCorner {
        case .topRight, .bottomRight:
            // Tuck off right screen edge leaving left tab visible
            targetX = screenFrame.maxX - tabVisibleWidth
        case .topLeft, .bottomLeft:
            // Tuck off left screen edge leaving right tab visible
            targetX = screenFrame.minX - w + tabVisibleWidth
        }
        
        let targetFrame = NSRect(x: targetX, y: currentFrame.origin.y, width: w, height: currentFrame.height)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }

}

extension StreamyWindowController: NSWindowDelegate {
    public func windowDidResize(_ notification: Notification) {
        guard let window = window, !model.isExpanded else { return }
        model.windowWidth = window.frame.width
        model.windowHeight = window.frame.height
    }
}

// Custom Panel Subclass allowing borderless key window capabilities when modifier is pressed
private class CustomPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            if let windowController = windowController as? StreamyWindowController, windowController.model.isExpanded {
                windowController.toggleFullscreenMode()
                return
            }
        }
        super.keyDown(with: event)
    }
}
