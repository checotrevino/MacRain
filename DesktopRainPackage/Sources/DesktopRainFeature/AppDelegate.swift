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
        
        // Presets Submenu
        let presetsMenuItem = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        presetsMenuItem.submenu = createPresetsMenu()
        menu.addItem(presetsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Sound Toggle
        let soundItem = NSMenuItem(title: "Sound Effects", action: #selector(toggleSound(_:)), keyEquivalent: "s")
        soundItem.state = RainSettings.shared.isSoundEnabled ? .on : .off
        menu.addItem(soundItem)
        
        menu.addItem(NSMenuItem.separator())
        
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
    
    private func createPresetsMenu() -> NSMenu {
        let menu = NSMenu()
        for preset in RainSettings.RainPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(setPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            menu.addItem(item)
        }
        return menu
    }
    
    @objc private func setPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? RainSettings.RainPreset {
            RainSettings.shared.applyPreset(preset)
            
            // Update ALL menus to reflect the new state
            statusItem?.menu?.items.forEach { mainItem in
                if let submenu = mainItem.submenu {
                    updateMenuStates(submenu)
                }
            }
        }
    }
    
    @objc private func toggleSound(_ sender: NSMenuItem) {
        RainSettings.shared.isSoundEnabled.toggle()
        statusItem?.menu?.items.forEach { updateMenuStates($0.submenu ?? NSMenu()) }
        // Also update the item itself if it's not in a submenu
        sender.state = RainSettings.shared.isSoundEnabled ? .on : .off
    }
    
    private func updateMenuStates(_ menu: NSMenu?) {
        menu?.items.forEach { item in
            // Handle Sound Toggle
            if item.action == #selector(toggleSound(_:)) {
                item.state = RainSettings.shared.isSoundEnabled ? .on : .off
            }
            
            // Handle Presets checkmarks (by name matching)
            if item.representedObject is RainSettings.RainPreset {
                // For simplicity, we'll just clear preset checkmarks when any setting is manually changed,
                // or just leave them off unless we want to track the "active" preset.
                item.state = .off 
            }
            
            if let value = item.representedObject as? Float {
                let action = item.action
                if action == #selector(setIntensity(_:)) {
                    item.state = RainSettings.shared.intensity == value ? .on : .off
                } else if action == #selector(setDirection(_:)) {
                    item.state = RainSettings.shared.direction == value ? .on : .off
                } else if action == #selector(setBounce(_:)) {
                    item.state = RainSettings.shared.bounceIntensity == value ? .on : .off
                }
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
