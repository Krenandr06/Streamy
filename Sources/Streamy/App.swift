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
        app.setActivationPolicy(.accessory) // Menu bar agent app mode
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = StreamyModel.shared
        
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
