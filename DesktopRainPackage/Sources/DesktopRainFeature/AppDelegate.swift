import AppKit
import SwiftUI

/// Main application delegate handling menu bar status item and rain overlay window
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var rainWindow: RainOverlayWindow?
    private var rainViewController: RainViewController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupRainOverlay()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.rain.fill", accessibilityDescription: "Desktop Rain")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Desktop Rain", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    private func setupRainOverlay() {
        guard let screen = NSScreen.main else {
            print("❌ No main screen found")
            return
        }
        
        let screenFrame = screen.frame
        print("✅ Setting up rain overlay on screen: \(screenFrame)")
        
        rainWindow = RainOverlayWindow(screen: screen)
        rainViewController = RainViewController(screenFrame: screenFrame)
        
        if let viewController = rainViewController {
            rainWindow?.contentViewController = viewController
        }
        
        // Force window to front
        DispatchQueue.main.async {
            self.rainWindow?.orderFrontRegardless()
            self.rainWindow?.setIsVisible(true)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
