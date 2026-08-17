import AppKit
import SwiftUI
import Combine

public final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let model: StreamyModel
    private weak var windowController: StreamyWindowController?
    private var cancellables = Set<AnyCancellable>()
    
    public init(model: StreamyModel, windowController: StreamyWindowController) {
        self.model = model
        self.windowController = windowController
        super.init()
        
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "play.tv.fill", accessibilityDescription: "Streamy")
            button.toolTip = "Streamy - Floating Web Player"
        }
        
        rebuildMenu()
    }
    
    public func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        // Header item
        let headerItem = NSMenuItem(title: "Streamy Video Player", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // Open URL...
        let openURLItem = NSMenuItem(title: "Open Web URL...", action: #selector(promptForURL), keyEquivalent: "u")
        openURLItem.target = self
        menu.addItem(openURLItem)
        
        // Presets Submenu
        let presetsMenu = NSMenu()
        let presetsItem = NSMenuItem(title: "Streaming Presets", action: nil, keyEquivalent: "")
        presetsItem.submenu = presetsMenu
        
        let presets = [
            ("YouTube", "https://www.youtube.com"),
            ("Twitch", "https://www.twitch.tv"),
            ("Netflix", "https://www.netflix.com"),
            ("Hulu", "https://www.hulu.com"),
            ("Disney+", "https://www.disneyplus.com"),
            ("Spotify", "https://open.spotify.com"),
            ("Apple Music", "https://music.apple.com")
        ]
        
        for (name, url) in presets {
            let item = NSMenuItem(title: name, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            if model.currentURL == url {
                item.state = .on
            }
            presetsMenu.addItem(item)
        }
        menu.addItem(presetsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Pin Corner Submenu
        let cornerMenu = NSMenu()
        let cornerItem = NSMenuItem(title: "Pin Corner Position", action: nil, keyEquivalent: "")
        cornerItem.submenu = cornerMenu
        
        for corner in CornerPosition.allCases {
            let item = NSMenuItem(title: corner.rawValue, action: #selector(selectCorner(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = corner.rawValue
            if model.pinnedCorner == corner {
                item.state = .on
            }
            cornerMenu.addItem(item)
        }
        menu.addItem(cornerItem)
        
        // Evasion Mode Submenu
        let evasionMenu = NSMenu()
        let evasionItem = NSMenuItem(title: "Mouse Evasion Mode", action: nil, keyEquivalent: "")
        evasionItem.submenu = evasionMenu
        
        for mode in EvasionMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(selectEvasionMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            if model.evasionMode == mode {
                item.state = .on
            }
            evasionMenu.addItem(item)
        }
        menu.addItem(evasionItem)
        
        // Interaction Key Submenu
        let keyMenu = NSMenu()
        let keyItem = NSMenuItem(title: "Interaction Key (Hold to Click)", action: nil, keyEquivalent: "")
        keyItem.submenu = keyMenu
        
        for key in IntersectModifierKey.allCases {
            let item = NSMenuItem(title: key.rawValue, action: #selector(selectModifierKey(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key.rawValue
            if model.modifierKey == key {
                item.state = .on
            }
            keyMenu.addItem(item)
        }
        menu.addItem(keyItem)
        
        // Window Size Submenu
        let sizeMenu = NSMenu()
        let sizeItem = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        
        let sizes: [(String, CGFloat, CGFloat)] = [
            ("Small (360×202)", 360, 202),
            ("Medium (480×270)", 480, 270),
            ("Large (640×360)", 640, 360),
            ("Extra Large (800×450)", 800, 450)
        ]
        
        for (label, width, height) in sizes {
            let item = NSMenuItem(title: label, action: #selector(selectWindowSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSSize(width: width, height: height)
            if Int(model.windowWidth) == Int(width) {
                item.state = .on
            }
            sizeMenu.addItem(item)
        }
        menu.addItem(sizeItem)
        
        // Follow Active Display toggle
        let followDisplayItem = NSMenuItem(title: "Follow Active Screen", action: #selector(toggleFollowScreen), keyEquivalent: "")
        followDisplayItem.target = self
        followDisplayItem.state = model.followActiveScreen ? .on : .off
        menu.addItem(followDisplayItem)
        
        // Fullscreen toggle
        let expandItem = NSMenuItem(title: "Fullscreen (85%×90%)", action: #selector(toggleFullscreen), keyEquivalent: "f")
        expandItem.target = self
        expandItem.state = model.isExpanded ? .on : .off
        menu.addItem(expandItem)

        
        menu.addItem(NSMenuItem.separator())

        
        // Reset Position & Reload
        let reloadItem = NSMenuItem(title: "Reload Web Page", action: #selector(reloadPage), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)
        
        let toggleVisItem = NSMenuItem(title: "Toggle Window Visibility", action: #selector(toggleVisibility), keyEquivalent: "h")
        toggleVisItem.target = self
        menu.addItem(toggleVisItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Streamy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func promptForURL() {
        let alert = NSAlert()
        alert.messageText = "Open Web Video URL"
        alert.informativeText = "Enter or paste any URL (e.g. YouTube, Twitch, Netflix video link):"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        inputTextField.stringValue = model.currentURL
        alert.accessoryView = inputTextField
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let input = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !input.isEmpty {
                model.currentURL = input
                rebuildMenu()
            }
        }
    }
    
    @objc private func selectPreset(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? String {
            model.currentURL = url
            rebuildMenu()
        }
    }
    
    @objc private func selectCorner(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let corner = CornerPosition(rawValue: raw) {
            model.pinnedCorner = corner
            rebuildMenu()
        }
    }
    
    @objc private func selectEvasionMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = EvasionMode(rawValue: raw) {
            model.evasionMode = mode
            rebuildMenu()
        }
    }
    
    @objc private func selectModifierKey(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let key = IntersectModifierKey(rawValue: raw) {
            model.modifierKey = key
            rebuildMenu()
        }
    }
    
    @objc private func selectWindowSize(_ sender: NSMenuItem) {
        if let size = sender.representedObject as? NSSize {
            model.windowWidth = size.width
            model.windowHeight = size.height
            rebuildMenu()
        }
    }
    
    @objc private func toggleFollowScreen() {
        model.followActiveScreen.toggle()
        rebuildMenu()
    }
    
    @objc private func toggleFullscreen() {
        windowController?.toggleFullscreenMode()
        rebuildMenu()
    }


    
    @objc private func reloadPage() {
        let current = model.currentURL
        model.currentURL = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.model.currentURL = current
        }
    }
    
    @objc private func toggleVisibility() {
        if let window = windowController?.window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
