import AppKit

/// Transparent, click-through overlay window covering the entire screen for rain rendering
public class RainOverlayWindow: NSWindow {
    
    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
    }
    
    private func configureWindow() {
        // Transparent background
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        
        // Window level: above desktop, below normal windows
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        
        // Collection behavior for proper screen handling
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Allow clicks to pass through
        ignoresMouseEvents = true
        
        // Don't show in exposé or window lists
        isExcludedFromWindowsMenu = true
        
        // Prevent activation
        styleMask.insert(.nonactivatingPanel)
    }
    
    // Prevent the window from becoming key
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
