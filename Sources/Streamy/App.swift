import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: StreamyModel!
    private var windowController: StreamyWindowController!
    private var menuBarController: MenuBarController!
    private var evasionEngine: EvasionEngine!
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular) // Shows Streamy icon in the macOS Dock (bottom bar) for full transparency
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = StreamyModel.shared
        
        // Dynamically load custom app icon if present in bundle or module resources
        if let moduleURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.module.url(forResource: "icon", withExtension: "png"),
           let image = NSImage(contentsOf: moduleURL) {
            NSApplication.shared.applicationIconImage = image
        } else if let mainPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? Bundle.main.path(forResource: "icon", ofType: "png"),
                  let image = NSImage(contentsOfFile: mainPath) {
            NSApplication.shared.applicationIconImage = image
        }
        
        windowController = StreamyWindowController(model: model)
        menuBarController = MenuBarController(model: model, windowController: windowController)
        evasionEngine = EvasionEngine(model: model, windowController: windowController)
        
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        
        evasionEngine.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        evasionEngine?.stopMonitoring()
    }
}
