import AppKit
import Combine

public final class EvasionEngine {
    private let model: StreamyModel
    private weak var windowController: StreamyWindowController?
    
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    
    private var lastActiveScreen: NSScreen?
    private var isCurrentlyEvading: Bool = false
    private var isDispatchPending: Bool = false
    
    public init(model: StreamyModel, windowController: StreamyWindowController) {
        self.model = model
        self.windowController = windowController
    }
    
    public func startMonitoring() {
        // Monitor global mouse moves
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved(event.locationInWindow)
        }
        
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved(event.locationInWindow)
            return event
        }
        
        // Monitor modifier flags changed (Command, Option, Ctrl, Shift)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event.modifierFlags)
        }
        
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event.modifierFlags)
            return event
        }
        
        lastActiveScreen = windowController?.targetScreen()
    }
    
    public func stopMonitoring() {
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalFlagsMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localFlagsMonitor { NSEvent.removeMonitor(monitor) }
        
        globalMouseMonitor = nil
        localMouseMonitor = nil
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
    }
    
    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard !model.isUserDraggingWindow else { return }
        let isPressed = flags.contains(model.modifierKey.eventFlag)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.model.isInteracting != isPressed {
                self.model.isInteracting = isPressed
            }

            // Re-evaluate mouse position with new modifier key state
            self.updateEvasionState(mouseLocationInScreen: NSEvent.mouseLocation, modifierHeld: isPressed)
        }
    }
    
    private func handleMouseMoved(_ location: NSPoint) {
        guard !model.isUserDraggingWindow else { return }
        guard !isDispatchPending else { return }
        isDispatchPending = true
        
        let screenMouseLocation = NSEvent.mouseLocation
        let modifierHeld = NSEvent.modifierFlags.contains(model.modifierKey.eventFlag)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isDispatchPending = false
            guard !self.model.isUserDraggingWindow else { return }
            
            // Check display change
            if self.model.followActiveScreen, let wc = self.windowController {
                let currentScreen = wc.targetScreen()
                if let last = self.lastActiveScreen, last != currentScreen {
                    self.lastActiveScreen = currentScreen
                    wc.repositionWindow(animated: true, screen: currentScreen)
                }
            }
            
            self.updateEvasionState(mouseLocationInScreen: screenMouseLocation, modifierHeld: modifierHeld)
        }
    }
    
    private func updateEvasionState(mouseLocationInScreen: NSPoint, modifierHeld: Bool) {
        guard let wc = windowController, let window = wc.window else { return }
        guard !model.isUserDraggingWindow else { return }
        
        // If window is in expanded mode, bypass evasion completely
        if model.isExpanded {
            if isCurrentlyEvading {
                isCurrentlyEvading = false
                model.isEvading = false
                wc.setGhostState(isGhost: false, alpha: 1.0)
            }
            return
        }
        
        // If modifier key is held, ALWAYS allow direct interaction & never evade
        if modifierHeld {
            if !model.isInteracting { model.isInteracting = true }
            if isCurrentlyEvading {
                isCurrentlyEvading = false
                model.isEvading = false
                wc.setGhostState(isGhost: false, alpha: 1.0)
                if model.evasionMode == .slide {
                    wc.repositionWindow(animated: true)
                }
            }
            return
        }
        
        if model.isInteracting { model.isInteracting = false }

        // If evasion is disabled, make sure ghost/slide state is reset
        if model.evasionMode == .disabled {
            if isCurrentlyEvading {
                isCurrentlyEvading = false
                model.isEvading = false
                wc.setGhostState(isGhost: false, alpha: 1.0)
                wc.repositionWindow(animated: true)
            }
            return
        }
        
        let windowFrame = window.frame
        
        if model.evasionMode == .ghost {
            let isInside = NSPointInRect(mouseLocationInScreen, windowFrame)
            if isInside {
                if !isCurrentlyEvading {
                    isCurrentlyEvading = true
                    model.isEvading = true

                    // The window is about to stop receiving mouse events entirely, so the
                    // page will never see the cursor leave on its own — force-clear whatever
                    // it's currently showing on hover (e.g. a player's control bar) now,
                    // while we can still reach it.
                    NowPlayingController.shared.webView?.evaluateJavaScript("window.streamyClearHover && window.streamyClearHover()")
                }
                window.ignoresMouseEvents = true
                window.alphaValue = 1.0
                
                let localPt = window.convertPoint(fromScreen: mouseLocationInScreen)
                let swiftUIPt = CGPoint(x: localPt.x, y: windowFrame.height - localPt.y)
                model.mousePositionInWindow = swiftUIPt
            } else {
                if isCurrentlyEvading {
                    isCurrentlyEvading = false
                    model.isEvading = false
                    model.mousePositionInWindow = nil
                    window.ignoresMouseEvents = false
                    window.alphaValue = 1.0
                }
            }
            return
        }
        
        // Other Evasion Modes (.slide, .peek)
        let homeFrame = wc.basePinnedFrame()
        let buffer = model.evasionDistance
        let expandedHomeFrame = homeFrame.insetBy(dx: -buffer, dy: -buffer)
        let isMouseNear = NSPointInRect(mouseLocationInScreen, expandedHomeFrame)
        
        if isMouseNear {
            if !isCurrentlyEvading {
                isCurrentlyEvading = true
                model.isEvading = true
                
                switch model.evasionMode {
                case .slide:
                    wc.setSlideState(isEvading: true)
                case .peek:
                    wc.setPeekState(isEvading: true)
                default:
                    break
                }
            }
        } else {
            if isCurrentlyEvading {
                isCurrentlyEvading = false
                model.isEvading = false
                
                switch model.evasionMode {
                case .slide:
                    wc.setSlideState(isEvading: false)
                case .peek:
                    wc.setPeekState(isEvading: false)
                default:
                    break
                }
            }
        }
    }
    
    private func distanceToRect(point: NSPoint, rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
