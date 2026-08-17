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
        let isPressed = flags.contains(model.modifierKey.eventFlag)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.model.isInteracting = isPressed
            
            // Re-evaluate mouse position with new modifier key state
            self.updateEvasionState(mouseLocationInScreen: NSEvent.mouseLocation, modifierHeld: isPressed)
        }
    }
    
    private func handleMouseMoved(_ location: NSPoint) {
        let screenMouseLocation = NSEvent.mouseLocation
        let modifierHeld = NSEvent.modifierFlags.contains(model.modifierKey.eventFlag)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
        
        // If window is in expanded "Theater / Queue Inspect" mode, bypass evasion completely
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
            model.isInteracting = true
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
        
        model.isInteracting = false
        
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
        
        // Measure proximity to window frame
        let windowFrame = window.frame
        let buffer = model.evasionDistance
        let expandedFrame = windowFrame.insetBy(dx: -buffer, dy: -buffer)
        
        let isMouseNear = NSPointInRect(mouseLocationInScreen, expandedFrame)
        
        if isMouseNear {
            if !isCurrentlyEvading {
                isCurrentlyEvading = true
                model.isEvading = true
                
                switch model.evasionMode {
                case .ghost:
                    wc.setGhostState(isGhost: true, alpha: model.ghostOpacity)
                case .slide:
                    wc.setSlideState(isEvading: true)
                case .peek:
                    wc.setPeekState(isEvading: true)
                case .disabled:
                    wc.setGhostState(isGhost: false, alpha: 1.0)
                }
            }
        } else {
            if isCurrentlyEvading {
                isCurrentlyEvading = false
                model.isEvading = false
                
                switch model.evasionMode {
                case .ghost:
                    wc.setGhostState(isGhost: false, alpha: 1.0)
                case .slide:
                    wc.setSlideState(isEvading: false)
                case .peek:
                    wc.setPeekState(isEvading: false)
                case .disabled:
                    wc.setGhostState(isGhost: false, alpha: 1.0)
                }
            }
        }

    }

}
