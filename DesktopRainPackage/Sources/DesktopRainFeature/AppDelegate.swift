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
        
        // Intensity Submenu
        let intensityMenuItem = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        intensityMenuItem.submenu = createIntensityMenu()
        menu.addItem(intensityMenuItem)
        
        // Direction Submenu
        let directionMenuItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        directionMenuItem.submenu = createDirectionMenu()
        menu.addItem(directionMenuItem)
        
        // Bounce Submenu
        let bounceMenuItem = NSMenuItem(title: "Bounce", action: nil, keyEquivalent: "")
        bounceMenuItem.submenu = createBounceMenu()
        menu.addItem(bounceMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Desktop Rain", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    private func createIntensityMenu() -> NSMenu {
        let menu = NSMenu()
        let options: [(String, Float)] = [("Light", 0.5), ("Medium", 1.0), ("Heavy", 2.0), ("Extreme", 4.0)]
        for (title, value) in options {
            let item = NSMenuItem(title: title, action: #selector(setIntensity(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = RainSettings.shared.intensity == value ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
    
    private func createDirectionMenu() -> NSMenu {
        let menu = NSMenu()
        let options: [(String, Float)] = [("From Left", 15), ("Straight Down", 0), ("From Right", -15)]
        for (title, value) in options {
            let item = NSMenuItem(title: title, action: #selector(setDirection(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = RainSettings.shared.direction == value ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
    
    private func createBounceMenu() -> NSMenu {
        let menu = NSMenu()
        let options: [(String, Float)] = [("None", 0), ("Minimal", 0.5), ("Normal", 1.0), ("Bouncy", 2.0)]
        for (title, value) in options {
            let item = NSMenuItem(title: title, action: #selector(setBounce(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = RainSettings.shared.bounceIntensity == value ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
    
    @objc private func setIntensity(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Float {
            RainSettings.shared.intensity = value
            updateMenuStates(sender.menu)
        }
    }
    
    @objc private func setDirection(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Float {
            RainSettings.shared.direction = value
            updateMenuStates(sender.menu)
        }
    }
    
    @objc private func setBounce(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Float {
            RainSettings.shared.bounceIntensity = value
            updateMenuStates(sender.menu)
        }
    }
    
    private func updateMenuStates(_ menu: NSMenu?) {
        menu?.items.forEach { item in
            if let value = item.representedObject as? Float {
                if menu?.title == "Intensity" { item.state = RainSettings.shared.intensity == value ? .on : .off }
                else if menu?.title == "Direction" { item.state = RainSettings.shared.direction == value ? .on : .off }
                else if menu?.title == "Bounce" { item.state = RainSettings.shared.bounceIntensity == value ? .on : .off }
                
                // Also handle the case where the submenu itself doesn't have a title set by us
                // We'll just check all shared settings
                if RainSettings.shared.intensity == value && item.action == #selector(setIntensity(_:)) { item.state = .on }
                else if RainSettings.shared.direction == value && item.action == #selector(setDirection(_:)) { item.state = .on }
                else if RainSettings.shared.bounceIntensity == value && item.action == #selector(setBounce(_:)) { item.state = .on }
                else { item.state = .off }
            }
        }
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
