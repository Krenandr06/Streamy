import AppKit
import SwiftUI
import Combine

public final class StreamyWindowController: NSWindowController {
    public let model: StreamyModel
    private var cancellables = Set<AnyCancellable>()
    private var currentTargetScreen: NSScreen?

    // Set for the duration of any frame change WE initiate, so the NSWindowDelegate
    // callbacks below can tell "the user moved/resized this" apart from "we did it
    // ourselves" and only feed genuine user actions back into the model. Without this,
    // our own animated repositioning was mistaken for user input, which fed back into
    // the model and re-triggered another reposition — a self-sustaining jitter loop.
    private var isProgrammaticFrameUpdate: Bool = false
    
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
                setProgrammaticFrame(preFrame, on: window, animated: true, timingFunction: .easeInEaseOut, duration: 0.3)
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
            setProgrammaticFrame(fullScreenFrame, on: window, animated: true, timingFunction: .easeInEaseOut)
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
    
    public func basePinnedFrame(for screen: NSScreen? = nil) -> NSRect {
        let activeScreen = screen ?? targetScreen()
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
        
        return NSRect(x: targetX, y: targetY, width: w, height: h)
    }
    
    public func repositionWindow(animated: Bool = true, screen: NSScreen? = nil) {
        guard let window = window else { return }
        guard !model.isExpanded, !model.isUserDraggingWindow, window.inLiveResize == false else { return }

        let activeScreen = screen ?? targetScreen()
        self.currentTargetScreen = activeScreen

        let targetFrame = basePinnedFrame(for: activeScreen)

        if abs(window.frame.origin.x - targetFrame.origin.x) < 1 && abs(window.frame.origin.y - targetFrame.origin.y) < 1 && abs(window.frame.width - targetFrame.width) < 1 && abs(window.frame.height - targetFrame.height) < 1 {
            return
        }

        setProgrammaticFrame(targetFrame, on: window, animated: animated, timingFunction: .easeInEaseOut)
    }

    // Sizing is model-driven (menu presets, persisted defaults) but the on-screen home
    // position always depends on the current size + pinned corner, so just recompute
    // and animate straight to that combined frame in one pass. Doing a separate resize
    // animation first (as this used to) collides with the reposition animation right
    // after it and shows up as a visible double-jump.
    public func updateWindowSize(width: CGFloat, height: CGFloat) {
        repositionWindow(animated: true)
    }

    // Runs a single programmatic frame change, flagging it so the NSWindowDelegate
    // callbacks below know not to treat it as user input.
    private func setProgrammaticFrame(_ frame: NSRect, on window: NSWindow, animated: Bool, timingFunction name: CAMediaTimingFunctionName, duration: CFTimeInterval = 0.35) {
        isProgrammaticFrameUpdate = true
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: name)
                window.animator().setFrame(frame, display: true)
            }, completionHandler: { [weak self] in
                self?.isProgrammaticFrameUpdate = false
            })
        } else {
            window.setFrame(frame, display: true)
            isProgrammaticFrameUpdate = false
        }
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
        guard !model.isExpanded, !model.isUserDraggingWindow else { return }
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

        if abs(window.frame.origin.x - targetFrame.origin.x) < 1 && abs(window.frame.origin.y - targetFrame.origin.y) < 1 {
            return
        }

        setProgrammaticFrame(targetFrame, on: window, animated: true, timingFunction: .easeOut)
    }

    public func setPeekState(isEvading: Bool) {
        guard let window = window else { return }
        guard !model.isExpanded, !model.isUserDraggingWindow else { return }
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

        if abs(window.frame.origin.x - targetFrame.origin.x) < 1 && abs(window.frame.origin.y - targetFrame.origin.y) < 1 {
            return
        }

        setProgrammaticFrame(targetFrame, on: window, animated: true, timingFunction: .easeInEaseOut)
    }

}

extension StreamyWindowController: NSWindowDelegate {
    // NSWindow sends will/did-move and did-resize for ANY frame change, including the
    // ones this controller makes itself (repositionWindow, setSlideState, etc). Bailing
    // out while isProgrammaticFrameUpdate is set is what keeps those from being read
    // back as user input and re-triggering another reposition.
    public func windowWillMove(_ notification: Notification) {
        guard !isProgrammaticFrameUpdate else { return }
        model.isUserDraggingWindow = true
    }

    public func windowDidMove(_ notification: Notification) {
        guard !isProgrammaticFrameUpdate else { return }
        model.isUserDraggingWindow = false

        guard let window = window, !model.isExpanded else { return }

        let activeScreen = targetScreen()
        let screenFrame = activeScreen.visibleFrame
        let windowCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let isRight = windowCenter.x > screenFrame.midX
        let isTop = windowCenter.y > screenFrame.midY

        let newCorner: CornerPosition
        switch (isTop, isRight) {
        case (true, true): newCorner = .topRight
        case (true, false): newCorner = .topLeft
        case (false, true): newCorner = .bottomRight
        case (false, false): newCorner = .bottomLeft
        }

        if model.pinnedCorner != newCorner {
            model.pinnedCorner = newCorner
        }
    }

    public func windowDidResize(_ notification: Notification) {
        guard !isProgrammaticFrameUpdate else { return }
        guard let window = window, !model.isExpanded, !model.isUserDraggingWindow else { return }
        if abs(model.windowWidth - window.frame.width) > 1 || abs(model.windowHeight - window.frame.height) > 1 {
            model.windowWidth = window.frame.width
            model.windowHeight = window.frame.height
        }
    }

    // repositionWindow skips while the user is actively dragging a resize handle (so it
    // doesn't fight their live drag); once they let go, snap back into the pinned
    // corner at the new size.
    public func windowDidEndLiveResize(_ notification: Notification) {
        repositionWindow(animated: true)
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
